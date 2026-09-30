const axios = require('axios');
const crypto = require('crypto');
const config = require('../config/config');

class MetaService {
  constructor() {
    this.baseUrl = config.meta.baseUrl;
    this.accessToken = config.meta.accessToken;
    this.adAccountId = config.meta.adAccountId;
    this.pageId = config.meta.pageId;
    this.appSecret = config.meta.appSecret;
    this.verifyToken = config.meta.webhookVerifyToken;
    this.pageName = '';
    this.adAccountName = '';
  }

  setCredentials({ accessToken, adAccountId, pageId, appSecret, pageName, adAccountName }) {
    if (accessToken) this.accessToken = accessToken.trim();
    if (adAccountId) this.adAccountId = adAccountId.trim().startsWith('act_') ? adAccountId.trim() : `act_${adAccountId.trim()}`;
    if (pageId) this.pageId = pageId.trim();
    if (appSecret !== undefined) this.appSecret = appSecret.trim();
    if (pageName) this.pageName = pageName.trim();
    if (adAccountName) this.adAccountName = adAccountName.trim();
    console.log(`🔄 [MetaService] Credentials updated: Page="${this.pageName || this.pageId}", AdAccount="${this.adAccountName || this.adAccountId}"`);
  }

  isConfigured() {
    return Boolean(this.accessToken && (this.adAccountId || this.pageId));
  }

  getStatus() {
    const maskedToken = this.accessToken
      ? `${this.accessToken.substring(0, 7)}...${this.accessToken.slice(-4)}`
      : null;

    return {
      configured: this.isConfigured(),
      apiVersion: config.meta.apiVersion,
      hasAccessToken: Boolean(this.accessToken),
      maskedToken,
      hasAdAccountId: Boolean(this.adAccountId),
      adAccountId: this.adAccountId || 'Not set',
      adAccountName: this.adAccountName || null,
      hasPageId: Boolean(this.pageId),
      pageId: this.pageId || 'Not set',
      pageName: this.pageName || null,
      hasAppSecret: Boolean(this.appSecret),
    };
  }

  /**
   * Helper to perform axios requests against Meta Graph API
   */
  async _request(method, endpoint, data = null, customParams = {}) {
    const url = endpoint.startsWith('http') ? endpoint : `${this.baseUrl}/${endpoint.replace(/^\//, '')}`;
    const params = {
      access_token: this.accessToken,
      ...customParams,
    };

    try {
      const response = await axios({
        method,
        url,
        params: method === 'GET' ? params : undefined,
        data: method !== 'GET' ? { ...data, access_token: this.accessToken } : undefined,
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
      });
      return response.data;
    } catch (err) {
      const fbError = err.response?.data?.error;
      const message = fbError ? `[Meta API ${fbError.code}] ${fbError.message}` : err.message;
      const errorObj = new Error(message);
      errorObj.metaError = fbError || null;
      errorObj.statusCode = err.response?.status || 500;
      throw errorObj;
    }
  }

  /**
   * Verifies incoming webhook X-Hub-Signature-256 header
   */
  verifyWebhookSignature(rawBody, signatureHeader) {
    if (!this.appSecret) return true; // If secret not configured in dev, skip or warn
    if (!signatureHeader) return false;

    const [scheme, signature] = signatureHeader.split('=');
    if (scheme !== 'sha256') return false;

    const expectedHash = crypto
      .createHmac('sha256', this.appSecret)
      .update(rawBody)
      .digest('hex');

    return crypto.timingSafeEqual(Buffer.from(signature, 'hex'), Buffer.from(expectedHash, 'hex'));
  }

  /**
   * Validates webhook challenge during Meta webhook subscription setup
   */
  verifyWebhookChallenge(mode, token, challenge) {
    if (mode === 'subscribe' && token === this.verifyToken) {
      return challenge;
    }
    return null;
  }

  /**
   * Discovers user profile, linked ad accounts, pages, and forms using a provided token
   */
  async discoverAssets(token) {
    if (!token || token.trim() === '') {
      throw new Error('Access Token is required to discover Meta assets.');
    }

    const t = token.trim();

    try {
      // 1. User Profile
      const userRes = await axios.get(`${this.baseUrl}/me`, {
        params: { access_token: t, fields: 'id,name' },
        timeout: 8000,
      });
      const user = userRes.data;

      // 2. Ad Accounts
      let adAccounts = [];
      try {
        const adAccRes = await axios.get(`${this.baseUrl}/me/adaccounts`, {
          params: { access_token: t, fields: 'id,name,account_id,currency,account_status' },
          timeout: 8000,
        });
        adAccounts = (adAccRes.data.data || []).map((a) => ({
          id: a.id.startsWith('act_') ? a.id : `act_${a.id}`,
          name: a.name || `Ad Account ${a.account_id || a.id}`,
          currency: a.currency || 'INR',
          status: a.account_status === 1 ? 'ACTIVE' : 'INACTIVE',
        }));
      } catch (adErr) {
        console.warn('Could not discover ad accounts:', adErr.message);
      }

      // 3. Pages
      let pages = [];
      try {
        const pagesRes = await axios.get(`${this.baseUrl}/me/accounts`, {
          params: { access_token: t, fields: 'id,name,category,access_token' },
          timeout: 8000,
        });
        pages = (pagesRes.data.data || []).map((p) => ({
          id: p.id,
          name: p.name,
          category: p.category,
          pageAccessToken: p.access_token,
        }));
      } catch (pageErr) {
        console.warn('Could not discover pages:', pageErr.message);
      }

      // 4. Lead Forms for first page
      let forms = [];
      if (pages.length > 0) {
        try {
          const targetPage = pages[0];
          const formsRes = await axios.get(`${this.baseUrl}/${targetPage.id}/leadgen_forms`, {
            params: {
              access_token: targetPage.pageAccessToken || t,
              fields: 'id,name,status,leads_count',
            },
            timeout: 8000,
          });
          forms = (formsRes.data.data || []).map((f) => ({
            id: f.id,
            name: f.name,
            status: f.status,
            leadsCount: f.leads_count || 0,
            pageId: targetPage.id,
          }));
        } catch (_) {}
      }

      return {
        success: true,
        user,
        adAccounts,
        pages,
        forms,
      };
    } catch (err) {
      const fbError = err.response?.data?.error;
      const message = fbError ? `[Meta ${fbError.code}] ${fbError.message}` : err.message;
      const errorObj = new Error(message);
      errorObj.metaError = fbError || null;
      throw errorObj;
    }
  }

  /**
   * Fetches full lead payload given a leadgen_id
   */
  async fetchLeadById(leadgenId) {
    if (!this.isConfigured()) {
      console.log(`[MetaService:Simulation] fetchLeadById: ${leadgenId}`);
      return {
        id: leadgenId,
        created_time: new Date().toISOString(),
        field_data: [
          { name: 'full_name', values: ['Rahul Sharma'] },
          { name: 'email', values: ['rahul.sharma@example.com'] },
          { name: 'phone_number', values: ['+91 98765 43210'] },
          { name: 'city', values: ['Pune'] },
          { name: 'property_type', values: ['2 BHK Apartment'] },
        ],
      };
    }

    return await this._request('GET', `/${leadgenId}`, null, {
      fields: 'id,created_time,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,is_organic,field_data',
    });
  }

  /**
   * Fetches leads from a specific Lead Form
   */
  async fetchFormLeads(formId, limit = 50) {
    if (!this.isConfigured()) {
      return [
        {
          id: `sim_lead_${Date.now()}_1`,
          created_time: new Date().toISOString(),
          field_data: [
            { name: 'full_name', values: ['Vikram Deshmukh'] },
            { name: 'email', values: ['vikram.d@example.com'] },
            { name: 'phone_number', values: ['+91 98220 11223'] },
            { name: 'budget_range', values: ['₹50L - ₹80L'] },
          ],
        },
        {
          id: `sim_lead_${Date.now()}_2`,
          created_time: new Date().toISOString(),
          field_data: [
            { name: 'full_name', values: ['Sneha Kulkarni'] },
            { name: 'email', values: ['sneha.k@example.com'] },
            { name: 'phone_number', values: ['+91 97654 88990'] },
            { name: 'preferred_location', values: ['Baner, Pune'] },
          ],
        },
      ];
    }

    const res = await this._request('GET', `/${formId}/leads`, null, {
      fields: 'id,created_time,field_data,ad_id,ad_name,campaign_id,campaign_name,form_id',
      limit,
    });
    return res.data || [];
  }

  /**
   * Fetches Lead Generation Forms attached to a Page
   */
  async getLeadForms(pageId = this.pageId) {
    if (!pageId || !this.isConfigured()) {
      return [
        { id: '102938475601', name: 'Pune Luxury Housing 2026 Form', status: 'ACTIVE', leads_count: 142 },
        { id: '102938475602', name: 'Mumbai Express Booking Form', status: 'ACTIVE', leads_count: 88 },
        { id: '102938475603', name: 'General Consultation Form', status: 'ACTIVE', leads_count: 45 },
      ];
    }

    const res = await this._request('GET', `/${pageId}/leadgen_forms`, null, {
      fields: 'id,name,status,leads_count,created_time',
    });
    return res.data || [];
  }

  /**
   * Fetches campaigns from Meta Ad Account
   */
  async getCampaigns() {
    if (!this.isConfigured() || !this.adAccountId) {
      console.log('[MetaService:Simulation] getCampaigns (Live token/account not configured)');
      return null; // Signals controller to fallback to database campaigns
    }

    try {
      const res = await this._request('GET', `/${this.adAccountId}/campaigns`, null, {
        fields: 'id,name,status,objective,daily_budget,budget_remaining,insights{spend,impressions,clicks,actions}',
      });
      return res.data || [];
    } catch (err) {
      console.warn('⚠️  Could not fetch live Meta campaigns:', err.message);
      return null;
    }
  }

  /**
   * STEP 1: Create Meta Ads Campaign
   */
  async createCampaign({ name, objective = 'OUTCOME_LEADS', status = 'ACTIVE', specialAdCategories = [] }) {
    if (!this.isConfigured()) {
      return { id: `sim_camp_${Date.now()}`, name, objective, status };
    }

    return await this._request('POST', `/${this.adAccountId}/campaigns`, {
      name,
      objective,
      status,
      special_ad_categories: specialAdCategories.length ? specialAdCategories : ['NONE'],
    });
  }

  /**
   * STEP 2: Create Meta Ads Ad Set
   */
  async createAdSet({
    campaignId,
    name,
    dailyBudget = 1000,
    countries = ['IN'],
    cities = [],
    pageId = this.pageId,
    status = 'ACTIVE',
  }) {
    if (!this.isConfigured()) {
      return { id: `sim_adset_${Date.now()}`, campaignId, name, dailyBudget, status };
    }

    // Daily budget in Meta Marketing API is in cents/sub-units (e.g. ₹1000 = 100000 paise or 100000 cents)
    const budgetInSubunits = Math.round(dailyBudget * 100);

    const geoLocations = {
      countries,
    };
    if (cities && cities.length > 0) {
      geoLocations.cities = cities.map((c) => (typeof c === 'string' ? { key: c } : c));
    }

    const payload = {
      name: `${name} - Ad Set`,
      campaign_id: campaignId,
      daily_budget: budgetInSubunits,
      billing_event: 'IMPRESSIONS',
      optimization_goal: 'LEAD_GENERATION',
      bid_strategy: 'LOWEST_COST_WITHOUT_CAP',
      promoted_object: { page_id: pageId },
      targeting: {
        geo_locations: geoLocations,
      },
      status,
    };

    return await this._request('POST', `/${this.adAccountId}/adsets`, payload);
  }

  /**
   * STEP 3: Create Meta Ad Creative with Lead Form
   */
  async createAdCreative({ name, pageId = this.pageId, leadFormId, headline, bodyText, imageUrl }) {
    if (!this.isConfigured()) {
      return { id: `sim_creative_${Date.now()}`, name };
    }

    const payload = {
      name: `${name} - Creative`,
      object_story_spec: {
        page_id: pageId,
        link_data: {
          call_to_action: {
            type: 'SIGN_UP',
            value: {
              lead_gen_form_id: leadFormId,
            },
          },
          link: `http://facebook.com/${pageId}`,
          message: bodyText || 'Discover premier residential and commercial properties with Eligible CRM.',
          name: headline || 'Exclusive Property Enquiries & Tours',
          picture: imageUrl || 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800',
        },
      },
    };

    return await this._request('POST', `/${this.adAccountId}/adcreatives`, payload);
  }

  /**
   * STEP 4: Create Meta Ad
   */
  async createAd({ name, adsetId, creativeId, status = 'ACTIVE' }) {
    if (!this.isConfigured()) {
      return { id: `sim_ad_${Date.now()}`, name, adsetId, creativeId, status };
    }

    const payload = {
      name: `${name} - Ad`,
      adset_id: adsetId,
      creative: { creative_id: creativeId },
      status,
    };

    return await this._request('POST', `/${this.adAccountId}/ads`, payload);
  }

  /**
   * Orchestrates the complete Meta Lead Ads Campaign Creation Pipeline
   */
  async createFullLeadCampaign(params) {
    const {
      name,
      dailyBudget = 1000,
      platform = 'Facebook & Instagram',
      targetLocations = ['IN'],
      headline,
      bodyText,
      pageId = this.pageId,
      formId,
      status = 'ACTIVE',
    } = params;

    console.log(`🚀 [MetaService] Initiating campaign creation: "${name}" (Budget: ₹${dailyBudget}/day)`);

    // 1. Create Campaign
    const campaignResult = await this.createCampaign({
      name,
      objective: 'OUTCOME_LEADS',
      status,
    });
    const campaignId = campaignResult.id;
    console.log(`✅ Campaign created on Meta: ${campaignId}`);

    // 2. Create Ad Set
    let adSetResult = null;
    try {
      adSetResult = await this.createAdSet({
        campaignId,
        name,
        dailyBudget,
        countries: targetLocations,
        pageId,
        status,
      });
      console.log(`✅ Ad Set created on Meta: ${adSetResult.id}`);
    } catch (err) {
      console.warn(`⚠️  Ad Set step note: ${err.message}`);
    }

    // 3. Create Creative (if formId and pageId provided)
    let creativeResult = null;
    let adResult = null;
    if (pageId && formId) {
      try {
        creativeResult = await this.createAdCreative({
          name,
          pageId,
          leadFormId: formId,
          headline,
          bodyText,
        });
        console.log(`✅ Creative created on Meta: ${creativeResult.id}`);

        if (adSetResult?.id) {
          adResult = await this.createAd({
            name,
            adsetId: adSetResult.id,
            creativeId: creativeResult.id,
            status,
          });
          console.log(`✅ Ad created on Meta: ${adResult.id}`);
        }
      } catch (err) {
        console.warn(`⚠️  Ad / Creative step note: ${err.message}`);
      }
    }

    return {
      meta_campaign_id: campaignId,
      meta_adset_id: adSetResult?.id || null,
      meta_creative_id: creativeResult?.id || null,
      meta_ad_id: adResult?.id || null,
      name,
      objective: 'OUTCOME_LEADS',
      platform,
      daily_budget: dailyBudget,
      status,
      leads_count: 0,
      spend: 0,
      created_time: new Date().toISOString(),
      raw_meta_response: {
        campaign: campaignResult,
        adSet: adSetResult,
        creative: creativeResult,
        ad: adResult,
      },
    };
  }

  /**
   * Pause or Activate Campaign
   */
  async updateCampaignStatus(campaignId, status) {
    if (!this.isConfigured()) {
      return { id: campaignId, status };
    }
    return await this._request('POST', `/${campaignId}`, { status });
  }

  /**
   * Test Meta credentials
   */
  async testConnection() {
    if (!this.accessToken) {
      return { success: false, message: 'Meta Access Token is missing.' };
    }
    try {
      const user = await this._request('GET', '/me', null, { fields: 'id,name' });
      let adAccountInfo = null;
      if (this.adAccountId) {
        adAccountInfo = await this._request('GET', `/${this.adAccountId}`, null, {
          fields: 'id,name,account_status,currency,timezone_name',
        });
      }
      return {
        success: true,
        user,
        adAccount: adAccountInfo,
        message: 'Successfully connected to Meta Graph API.',
      };
    } catch (err) {
      return {
        success: false,
        message: err.message,
        details: err.metaError,
      };
    }
  }
}

module.exports = new MetaService();
