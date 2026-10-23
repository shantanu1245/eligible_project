const axios = require('axios');
const crypto = require('crypto');
const config = require('../config/config');

class MetaService {
  constructor() {
    this.baseUrl = config.meta.baseUrl;
    this.accessToken = config.meta.accessToken;
    this.adAccountId = config.meta.adAccountId;
    this.pageId = config.meta.pageId;
    this.appId = config.meta.appId;
    this.appSecret = config.meta.appSecret;
    this.verifyToken = config.meta.webhookVerifyToken;
    this.pageName = '';
    this.adAccountName = '';
    this.lastSyncInfo = {
      lastSyncTime: null,
      syncedCount: 0,
      totalLeads: 0,
      status: 'idle',
      lastError: null,
    };
    this._cache = new Map();
    this.cacheTtlMs = 180000; // 3 minutes TTL for lightning speed
  }

  setCredentials({ accessToken, adAccountId, pageId, appSecret, pageName, adAccountName, appId }) {
    if (accessToken) this.accessToken = accessToken.trim();
    if (adAccountId) this.adAccountId = adAccountId.trim().startsWith('act_') ? adAccountId.trim() : `act_${adAccountId.trim()}`;
    if (pageId) this.pageId = pageId.trim();
    if (appId) this.appId = appId.trim();
    if (appSecret !== undefined) this.appSecret = appSecret.trim();
    if (pageName) this.pageName = pageName.trim();
    if (adAccountName) this.adAccountName = adAccountName.trim();
    this.clearCache();
    console.log(`🔄 [MetaService] Credentials updated: Page="${this.pageName || this.pageId}", AdAccount="${this.adAccountName || this.adAccountId}"`);
  }

  isConfigured() {
    return Boolean(
      this.accessToken &&
      !this.accessToken.includes('mock') &&
      !this.accessToken.includes('test_token')
    );
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
      hasAppId: Boolean(this.appId),
      hasAppSecret: Boolean(this.appSecret),
      hasAdAccountId: Boolean(this.adAccountId),
      adAccountId: this.adAccountId || 'Not set',
      adAccountName: this.adAccountName || null,
      hasPageId: Boolean(this.pageId),
      pageId: this.pageId || 'Not set',
      pageName: this.pageName || null,
      lastSync: this.lastSyncInfo,
    };
  }

  /**
   * Exchanges a short-lived User token for a 60-day Long-Lived User Access Token
   */
  async exchangeForLongLivedToken(shortToken) {
    const token = shortToken || this.accessToken;
    if (!token || !this.appId || !this.appSecret) {
      throw new Error('App ID, App Secret, and Access Token are required to extend token.');
    }

    try {
      const res = await axios.get(`${this.baseUrl}/oauth/access_token`, {
        params: {
          grant_type: 'fb_exchange_token',
          client_id: this.appId,
          client_secret: this.appSecret,
          fb_exchange_token: token.trim(),
        },
        timeout: 10000,
      });

      if (res.data?.access_token) {
        console.log('✅ [MetaService] Successfully exchanged token for 60-day Long-Lived Token!');
        return {
          success: true,
          accessToken: res.data.access_token,
          tokenType: res.data.token_type,
          expiresIn: res.data.expires_in,
        };
      }
    } catch (err) {
      const fbError = err.response?.data?.error;
      console.warn('⚠️ [MetaService] Token extension failed:', fbError?.message || err.message);
      return {
        success: false,
        error: fbError?.message || err.message,
      };
    }
  }

  /**
   * Clear in-memory Meta API cache (whole cache or matching a keyword)
   */
  clearCache(pattern = null) {
    if (!pattern) {
      this._cache.clear();
      console.log('🧹 [MetaService] All Meta API cache entries cleared.');
    } else {
      for (const key of this._cache.keys()) {
        if (key.includes(pattern)) {
          this._cache.delete(key);
        }
      }
      console.log(`🧹 [MetaService] Cleared Meta API cache matching "${pattern}".`);
    }
  }

  /**
   * Helper to perform axios requests against Meta Graph API with in-memory caching & rate limit protection
   */
  async _request(method, endpoint, data = null, customParams = {}, retries = 2, options = {}) {
    const isGet = method.toUpperCase() === 'GET';
    const forceRefresh = Boolean(options.forceRefresh || customParams?.forceRefresh);
    const ttl = options.ttl || this.cacheTtlMs || 180000;

    // Fast cache lookup for GET requests
    const cacheKey = isGet ? `${endpoint}::${JSON.stringify(customParams || {})}` : null;
    if (isGet && !forceRefresh && cacheKey && this._cache.has(cacheKey)) {
      const cached = this._cache.get(cacheKey);
      if (Date.now() - cached.timestamp < ttl) {
        return cached.data;
      }
    }

    const url = endpoint.startsWith('http') ? endpoint : `${this.baseUrl}/${endpoint.replace(/^\//, '')}`;
    const params = {
      access_token: this.accessToken,
      ...customParams,
    };
    delete params.forceRefresh;

    for (let attempt = 0; attempt <= retries; attempt++) {
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
          timeout: 15000,
        });

        // Store successful GET response in high-speed cache
        if (isGet && cacheKey) {
          this._cache.set(cacheKey, {
            data: response.data,
            timestamp: Date.now(),
          });
        }

        return response.data;
      } catch (err) {
        const fbError = err.response?.data?.error;
        const statusCode = err.response?.status || 500;
        const errorCode = fbError?.code;

        // Check if rate limited (code 17, 4, 32, 613, or HTTP 429) - wait and retry
        const isRateLimit = statusCode === 429 || [4, 17, 32, 613, 80004].includes(errorCode);
        const isTransient = [500, 502, 503, 504].includes(statusCode);

        if ((isRateLimit || isTransient) && attempt < retries) {
          const delay = (attempt + 1) * 2000;
          console.warn(`⚠️ [MetaService] API temporary delay (${fbError?.message || err.message}). Retrying in ${delay}ms...`);
          await new Promise((r) => setTimeout(r, delay));
          continue;
        }

        const message = fbError ? `[Meta API ${fbError.code}] ${fbError.message}` : err.message;
        const errorObj = new Error(message);
        errorObj.metaError = fbError || null;
        errorObj.statusCode = statusCode;
        throw errorObj;
      }
    }
  }

  /**
   * Phase 1 / Phase 2: Identify Meta Permissions and Validate Token Diagnostics
   */
  async getDiagnostics() {
    if (!this.accessToken) {
      return {
        configured: false,
        tokenValid: false,
        message: 'Meta Access Token is not configured in backend environment variables.',
        grantedPermissions: [],
        declinedPermissions: [],
      };
    }

    try {
      // 1. Get Me profile
      const user = await this._request('GET', '/me', null, { fields: 'id,name' });

      // 2. Query permissions granted to this token
      let permissions = [];
      try {
        const permRes = await this._request('GET', '/me/permissions');
        permissions = permRes.data || [];
      } catch (pErr) {
        console.warn('⚠️ Could not inspect /me/permissions:', pErr.message);
      }

      const granted = permissions.filter((p) => p.status === 'granted').map((p) => p.permission);
      const declined = permissions.filter((p) => p.status !== 'granted').map((p) => p.permission);

      // 3. Optional debug_token inspection
      let debugInfo = null;
      if (this.appId && this.appSecret) {
        try {
          const debugRes = await axios.get(`${this.baseUrl}/debug_token`, {
            params: {
              input_token: this.accessToken,
              access_token: `${this.appId}|${this.appSecret}`,
            },
            timeout: 6000,
          });
          debugInfo = debugRes.data?.data || null;
        } catch (_) {}
      }

      // 4. Query Page & Instagram Business details
      let page = null;
      let instagram = null;
      try {
        const pagesRes = await this._request('GET', '/me/accounts', null, {
          fields: 'id,name,category,is_published,instagram_business_account{id,username,name,profile_picture_url}',
        });
        if (pagesRes.data && pagesRes.data.length > 0) {
          const firstPage = pagesRes.data[0];
          page = {
            id: firstPage.id,
            name: firstPage.name,
            category: firstPage.category || 'Loan service',
            isPublished: firstPage.is_published,
          };
          if (firstPage.instagram_business_account) {
            instagram = {
              id: firstPage.instagram_business_account.id,
              username: firstPage.instagram_business_account.username,
              name: firstPage.instagram_business_account.name,
              profilePictureUrl: firstPage.instagram_business_account.profile_picture_url,
            };
          }
        }
      } catch (pErr) {
        console.warn('⚠️ Could not inspect /me/accounts for diagnostics:', pErr.message);
      }

      return {
        configured: true,
        tokenValid: true,
        user,
        page,
        instagram,
        type: debugInfo?.type || 'USER',
        appId: debugInfo?.app_id || this.appId || null,
        expiresAt: debugInfo?.expires_at ? new Date(debugInfo.expires_at * 1000).toISOString() : 'Never / Long-Lived System User',
        dataAccessExpiresAt: debugInfo?.data_access_expires_at ? new Date(debugInfo.data_access_expires_at * 1000).toISOString() : null,
        grantedPermissions: granted,
        declinedPermissions: declined,
        permissionChecks: {
          ads_read: granted.includes('ads_read') || granted.includes('ads_management'),
          leads_retrieval: granted.includes('leads_retrieval'),
          pages_read_engagement: granted.includes('pages_read_engagement') || granted.includes('pages_manage_ads'),
          pages_manage_ads: granted.includes('pages_manage_ads'),
        },
      };
    } catch (err) {
      return {
        configured: true,
        tokenValid: false,
        error: err.message,
        metaError: err.metaError || null,
        grantedPermissions: [],
        declinedPermissions: [],
      };
    }
  }

  /**
   * Phase 3.A: Retrieve accessible Ad Accounts with full metadata, balance, and spend
   */
  async getAdAccounts() {
    if (!this.isConfigured()) {
      return [];
    }

    try {
      const res = await this._request('GET', '/me/adaccounts', null, {
        fields: 'id,account_id,name,account_status,currency,timezone_name,spend_cap,amount_spent,balance,created_time,business_name',
        limit: 50,
      });

      const accounts = (res.data || []).map((a) => {
        const statusMap = {
          1: 'ACTIVE',
          2: 'DISABLED',
          3: 'UNSETTLED',
          7: 'PENDING_RISK_REVIEW',
          8: 'PENDING_SETTLEMENT',
          9: 'IN_GRACE_PERIOD',
          100: 'PENDING_CLOSURE',
          101: 'CLOSED',
        };

        const id = a.id.startsWith('act_') ? a.id : `act_${a.id}`;
        return {
          id,
          accountId: a.account_id,
          name: a.name || `Ad Account ${a.account_id}`,
          status: statusMap[a.account_status] || 'UNKNOWN',
          rawStatus: a.account_status,
          currency: a.currency || 'INR',
          timezone: a.timezone_name || 'UTC',
          amountSpent: a.amount_spent ? parseFloat(a.amount_spent) / 100 : 0, // In currency units
          spendCap: a.spend_cap ? parseFloat(a.spend_cap) / 100 : null,
          balance: a.balance ? parseFloat(a.balance) / 100 : 0,
          businessName: a.business_name || null,
          createdTime: a.created_time || null,
        };
      });

      return accounts;
    } catch (err) {
      console.error('❌ [MetaService] getAdAccounts error:', err.message);
      throw err;
    }
  }

  /**
   * Phase 3.B: Retrieve Campaigns from Ad Account
   */
  async getCampaigns(adAccountId = this.adAccountId, options = {}) {
    const targetAccountId = (adAccountId || this.adAccountId || '').trim();
    if (!this.isConfigured() || !targetAccountId) {
      return null;
    }

    const formattedAccountId = targetAccountId.startsWith('act_') ? targetAccountId : `act_${targetAccountId}`;
    const datePreset = options.datePreset || 'last_30d';

    try {
      const params = {
        fields: [
          'id',
          'name',
          'objective',
          'status',
          'effective_status',
          'start_time',
          'stop_time',
          'daily_budget',
          'lifetime_budget',
          'budget_remaining',
          'created_time',
          'updated_time',
          `insights.date_preset(${datePreset}){spend,impressions,clicks,reach,frequency,cpc,cpm,ctr,actions,cost_per_action_type}`,
        ].join(','),
        limit: 100,
      };

      if (options.status) {
        params.effective_status = JSON.stringify([options.status]);
      }

      const res = await this._request('GET', `/${formattedAccountId}/campaigns`, null, params);
      const campaigns = (res.data || []).map((c) => {
        const insights = c.insights?.data?.[0] || {};
        const actions = insights.actions || [];
        const costPerAction = insights.cost_per_action_type || [];

        // Extract lead count from actions array
        const leadAction = actions.find(
          (a) => a.action_type === 'lead' || a.action_type === 'onsite_conversion.lead_grouped' || a.action_type === 'offsite_conversion.fb_pixel_lead'
        );
        const leadsCount = leadAction ? parseInt(leadAction.value, 10) : 0;

        // Extract cost per lead
        const cplAction = costPerAction.find(
          (a) => a.action_type === 'lead' || a.action_type === 'onsite_conversion.lead_grouped'
        );
        const costPerLead = cplAction ? parseFloat(cplAction.value) : 0;

        // Format budget in main currency (Meta reports budget in cents/sub-units)
        const dailyBudget = c.daily_budget ? parseFloat(c.daily_budget) / 100 : null;
        const lifetimeBudget = c.lifetime_budget ? parseFloat(c.lifetime_budget) / 100 : null;

        return {
          id: c.id,
          name: c.name,
          objective: c.objective || 'OUTCOME_LEADS',
          status: c.status,
          effectiveStatus: c.effective_status,
          startTime: c.start_time || null,
          stopTime: c.stop_time || null,
          dailyBudget,
          lifetimeBudget,
          budgetType: dailyBudget ? 'DAILY' : lifetimeBudget ? 'LIFETIME' : 'UNKNOWN',
          budgetRemaining: c.budget_remaining ? parseFloat(c.budget_remaining) / 100 : null,
          createdTime: c.created_time || null,
          updatedTime: c.updated_time || null,
          // Performance metrics
          spend: insights.spend ? parseFloat(insights.spend) : 0,
          impressions: insights.impressions ? parseInt(insights.impressions, 10) : 0,
          clicks: insights.clicks ? parseInt(insights.clicks, 10) : 0,
          reach: insights.reach ? parseInt(insights.reach, 10) : 0,
          frequency: insights.frequency ? parseFloat(insights.frequency) : 0,
          ctr: insights.ctr ? parseFloat(insights.ctr) : 0,
          cpc: insights.cpc ? parseFloat(insights.cpc) : 0,
          cpm: insights.cpm ? parseFloat(insights.cpm) : 0,
          leadsCount,
          costPerLead,
        };
      });

      return campaigns;
    } catch (err) {
      console.warn(`⚠️ [MetaService] getCampaigns error on ${formattedAccountId}:`, err.message);
      return null;
    }
  }

  /**
   * Phase 3.C: Retrieve Ad Sets from Ad Account or specific Campaign
   */
  async getAdSets(adAccountId = this.adAccountId, options = {}) {
    const targetAccountId = (adAccountId || this.adAccountId || '').trim();
    if (!this.isConfigured() || !targetAccountId) return [];

    const formattedAccountId = targetAccountId.startsWith('act_') ? targetAccountId : `act_${targetAccountId}`;
    const datePreset = options.datePreset || 'last_30d';

    try {
      const endpoint = options.campaignId ? `/${options.campaignId}/adsets` : `/${formattedAccountId}/adsets`;
      const params = {
        fields: [
          'id',
          'name',
          'campaign_id',
          'status',
          'effective_status',
          'daily_budget',
          'lifetime_budget',
          'start_time',
          'end_time',
          'targeting',
          'optimization_goal',
          'billing_event',
          `insights.date_preset(${datePreset}){spend,impressions,clicks,reach,frequency,cpc,cpm,ctr,actions,cost_per_action_type}`,
        ].join(','),
        limit: 100,
      };

      const res = await this._request('GET', endpoint, null, params);
      return (res.data || []).map((as) => {
        const insights = as.insights?.data?.[0] || {};
        const actions = insights.actions || [];
        const leadAction = actions.find(
          (a) => a.action_type === 'lead' || a.action_type === 'onsite_conversion.lead_grouped'
        );

        // Summarize geo targeting
        const geo = as.targeting?.geo_locations || {};
        const countries = geo.countries || [];
        const cities = (geo.cities || []).map((c) => c.name || c.key);
        const targetSummary = cities.length ? cities.join(', ') : countries.join(', ') || 'Global';

        return {
          id: as.id,
          name: as.name,
          campaignId: as.campaign_id,
          status: as.status,
          effectiveStatus: as.effective_status,
          dailyBudget: as.daily_budget ? parseFloat(as.daily_budget) / 100 : null,
          lifetimeBudget: as.lifetime_budget ? parseFloat(as.lifetime_budget) / 100 : null,
          startTime: as.start_time || null,
          endTime: as.end_time || null,
          optimizationGoal: as.optimization_goal || null,
          targetingSummary: targetSummary,
          targeting: as.targeting || {},
          spend: insights.spend ? parseFloat(insights.spend) : 0,
          impressions: insights.impressions ? parseInt(insights.impressions, 10) : 0,
          clicks: insights.clicks ? parseInt(insights.clicks, 10) : 0,
          reach: insights.reach ? parseInt(insights.reach, 10) : 0,
          ctr: insights.ctr ? parseFloat(insights.ctr) : 0,
          cpc: insights.cpc ? parseFloat(insights.cpc) : 0,
          leadsCount: leadAction ? parseInt(leadAction.value, 10) : 0,
        };
      });
    } catch (err) {
      console.warn('⚠️ [MetaService] getAdSets error:', err.message);
      return [];
    }
  }

  /**
   * Phase 3.D: Retrieve Ads from Ad Account, Campaign, or Ad Set
   */
  async getAds(adAccountId = this.adAccountId, options = {}) {
    const targetAccountId = (adAccountId || this.adAccountId || '').trim();
    if (!this.isConfigured() || !targetAccountId) return [];

    const formattedAccountId = targetAccountId.startsWith('act_') ? targetAccountId : `act_${targetAccountId}`;
    const datePreset = options.datePreset || 'last_30d';

    try {
      let endpoint = `/${formattedAccountId}/ads`;
      if (options.adSetId) {
        endpoint = `/${options.adSetId}/ads`;
      } else if (options.campaignId) {
        endpoint = `/${options.campaignId}/ads`;
      }

      const params = {
        fields: [
          'id',
          'name',
          'campaign_id',
          'adset_id',
          'status',
          'effective_status',
          'created_time',
          'creative{id,name,title,body,image_url,thumbnail_url,object_story_spec}',
          `insights.date_preset(${datePreset}){spend,impressions,clicks,reach,cpc,cpm,ctr,actions,cost_per_action_type}`,
        ].join(','),
        limit: 100,
      };

      const res = await this._request('GET', endpoint, null, params);
      return (res.data || []).map((ad) => {
        const insights = ad.insights?.data?.[0] || {};
        const creative = ad.creative || {};
        const storySpec = creative.object_story_spec || {};
        const linkData = storySpec.link_data || {};

        const actions = insights.actions || [];
        const leadAction = actions.find(
          (a) => a.action_type === 'lead' || a.action_type === 'onsite_conversion.lead_grouped'
        );

        return {
          id: ad.id,
          name: ad.name,
          campaignId: ad.campaign_id,
          adSetId: ad.adset_id,
          status: ad.status,
          effectiveStatus: ad.effective_status,
          createdTime: ad.created_time || null,
          creative: {
            id: creative.id,
            name: creative.name,
            title: creative.title || linkData.name || null,
            body: creative.body || linkData.message || null,
            imageUrl: creative.image_url || creative.thumbnail_url || linkData.picture || null,
            callToAction: linkData.call_to_action?.type || null,
            leadFormId: linkData.call_to_action?.value?.lead_gen_form_id || null,
          },
          spend: insights.spend ? parseFloat(insights.spend) : 0,
          impressions: insights.impressions ? parseInt(insights.impressions, 10) : 0,
          clicks: insights.clicks ? parseInt(insights.clicks, 10) : 0,
          reach: insights.reach ? parseInt(insights.reach, 10) : 0,
          ctr: insights.ctr ? parseFloat(insights.ctr) : 0,
          cpc: insights.cpc ? parseFloat(insights.cpc) : 0,
          leadsCount: leadAction ? parseInt(leadAction.value, 10) : 0,
        };
      });
    } catch (err) {
      console.warn('⚠️ [MetaService] getAds error:', err.message);
      return [];
    }
  }

  /**
   * Phase 3.E: Retrieve Performance Insights for any reporting level with configurable date ranges
   */
  async getInsights({
    adAccountId = this.adAccountId,
    level = 'account',
    id = null,
    datePreset = 'last_30d',
    timeRange = null,
    timeIncrement = null,
  }) {
    if (!this.isConfigured()) {
      return {
        summary: {},
        breakdowns: [],
      };
    }

    let targetId = id;
    if (!targetId) {
      const formattedAccountId = (adAccountId || this.adAccountId || '').trim();
      targetId = formattedAccountId.startsWith('act_') ? formattedAccountId : `act_${formattedAccountId}`;
    }

    const params = {
      level,
      fields: [
        'spend',
        'impressions',
        'reach',
        'frequency',
        'clicks',
        'inline_link_clicks',
        'cpc',
        'cost_per_inline_link_click',
        'cpm',
        'ctr',
        'inline_link_click_ctr',
        'actions',
        'cost_per_action_type',
        'date_start',
        'date_stop',
      ].join(','),
    };

    if (timeRange && timeRange.since && timeRange.until) {
      params.time_range = JSON.stringify(timeRange);
    } else {
      params.date_preset = datePreset;
    }

    if (timeIncrement) {
      params.time_increment = timeIncrement;
    }

    try {
      const res = await this._request('GET', `/${targetId}/insights`, null, params);
      const dataList = res.data || [];

      // Parse individual rows
      const parsedRows = dataList.map((row) => {
        const actions = row.actions || [];
        const costPerAction = row.cost_per_action_type || [];

        const leadAction = actions.find(
          (a) => a.action_type === 'lead' || a.action_type === 'onsite_conversion.lead_grouped' || a.action_type === 'offsite_conversion.fb_pixel_lead'
        );
        const cplAction = costPerAction.find(
          (a) => a.action_type === 'lead' || a.action_type === 'onsite_conversion.lead_grouped'
        );
        const landingPageView = actions.find((a) => a.action_type === 'landing_page_view');

        return {
          dateStart: row.date_start,
          dateStop: row.date_stop,
          spend: row.spend ? parseFloat(row.spend) : 0,
          impressions: row.impressions ? parseInt(row.impressions, 10) : 0,
          reach: row.reach ? parseInt(row.reach, 10) : 0,
          frequency: row.frequency ? parseFloat(row.frequency) : 0,
          clicks: row.clicks ? parseInt(row.clicks, 10) : 0,
          linkClicks: row.inline_link_clicks ? parseInt(row.inline_link_clicks, 10) : 0,
          cpc: row.cpc ? parseFloat(row.cpc) : 0,
          costPerLinkClick: row.cost_per_inline_link_click ? parseFloat(row.cost_per_inline_link_click) : 0,
          cpm: row.cpm ? parseFloat(row.cpm) : 0,
          ctr: row.ctr ? parseFloat(row.ctr) : 0,
          linkCtr: row.inline_link_click_ctr ? parseFloat(row.inline_link_click_ctr) : 0,
          leads: leadAction ? parseInt(leadAction.value, 10) : 0,
          costPerLead: cplAction ? parseFloat(cplAction.value) : 0,
          landingPageViews: landingPageView ? parseInt(landingPageView.value, 10) : 0,
        };
      });

      // Overall Summary
      let summary = {
        spend: 0,
        impressions: 0,
        reach: 0,
        frequency: 0,
        clicks: 0,
        linkClicks: 0,
        leads: 0,
        cpc: 0,
        cpm: 0,
        ctr: 0,
        costPerLead: 0,
      };

      if (parsedRows.length === 1 && !timeIncrement) {
        summary = { ...parsedRows[0] };
      } else if (parsedRows.length > 0) {
        summary.spend = parsedRows.reduce((sum, r) => sum + r.spend, 0);
        summary.impressions = parsedRows.reduce((sum, r) => sum + r.impressions, 0);
        summary.reach = parsedRows.reduce((sum, r) => Math.max(sum, r.reach), 0);
        summary.clicks = parsedRows.reduce((sum, r) => sum + r.clicks, 0);
        summary.linkClicks = parsedRows.reduce((sum, r) => sum + r.linkClicks, 0);
        summary.leads = parsedRows.reduce((sum, r) => sum + r.leads, 0);
        summary.cpc = summary.clicks > 0 ? summary.spend / summary.clicks : 0;
        summary.cpm = summary.impressions > 0 ? (summary.spend / summary.impressions) * 1000 : 0;
        summary.ctr = summary.impressions > 0 ? (summary.clicks / summary.impressions) * 100 : 0;
        summary.costPerLead = summary.leads > 0 ? summary.spend / summary.leads : 0;
      }

      return {
        level,
        targetId,
        datePreset,
        summary,
        breakdowns: parsedRows,
      };
    } catch (err) {
      console.warn('⚠️ [MetaService] getInsights error:', err.message);
      return {
        level,
        targetId,
        datePreset,
        summary: {},
        breakdowns: [],
        error: err.message,
      };
    }
  }

  /**
   * Resolves Page Access Token for a specific Page ID
   */
  async getPageAccessToken(pageId) {
    if (!pageId) return null;
    try {
      const res = await this._request('GET', '/me/accounts', null, {
        fields: 'id,name,access_token',
        limit: 100,
      });
      const page = (res.data || []).find((p) => p.id === pageId);
      return page?.access_token || null;
    } catch (_) {
      return null;
    }
  }

  /**
   * Phase 4: Fetch Lead Generation Forms
   */
  async getLeadForms(pageId = this.pageId) {
    if (!this.isConfigured() || !pageId) {
      return [];
    }

    try {
      const pageToken = await this.getPageAccessToken(pageId);
      const params = {
        fields: 'id,name,status,leads_count,created_time',
        limit: 50,
      };
      if (pageToken) {
        params.access_token = pageToken;
      }

      const res = await this._request('GET', `/${pageId}/leadgen_forms`, null, params);
      return (res.data || []).map((f) => ({
        id: f.id,
        name: f.name,
        status: f.status,
        leadsCount: f.leads_count || 0,
        createdTime: f.created_time || null,
        pageId,
      }));
    } catch (err) {
      console.warn(`⚠️ [MetaService] getLeadForms error for page ${pageId}:`, err.message);
      return [];
    }
  }

  /**
   * Phase 4: Fetch Paginated Leads from a Lead Form
   */
  async fetchFormLeads(formId, options = {}) {
    const limit = options.limit || 50;
    const after = options.afterCursor || null;
    const pageToken = options.pageToken || null;

    if (!this.isConfigured() || !formId) {
      return { data: [], paging: {} };
    }

    const params = {
      fields: 'id,created_time,field_data,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,is_organic,platform',
      limit,
    };
    if (after) {
      params.after = after;
    }
    if (pageToken) {
      params.access_token = pageToken;
    }

    try {
      const res = await this._request('GET', `/${formId}/leads`, null, params);
      return {
        data: res.data || [],
        paging: res.paging || {},
      };
    } catch (err) {
      console.warn(`⚠️ [MetaService] fetchFormLeads error for form ${formId}:`, err.message);
      return { data: [], paging: {}, error: err.message };
    }
  }

  /**
   * Phase 4: Fetch Lead Details by Leadgen ID
   */
  async fetchLeadById(leadgenId) {
    if (!this.isConfigured() || !leadgenId) {
      throw new Error('Access Token or Lead ID is missing');
    }

    return await this._request('GET', `/${leadgenId}`, null, {
      fields: 'id,created_time,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,is_organic,platform,field_data',
    });
  }

  /**
   * Phase 4: Paginated Lead Import & Deduplication Orchestrator
   */
  async syncAllLeads({ formId, pageId = this.pageId, firebaseService }) {
    if (!firebaseService) {
      throw new Error('Database service reference required for sync');
    }

    this.lastSyncInfo.status = 'syncing';
    console.log(`🔄 [MetaService:syncAllLeads] Starting lead synchronization...`);

    let targetForms = [];
    if (formId) {
      targetForms = [{ id: formId, name: `Form ${formId}` }];
    } else if (pageId) {
      targetForms = await this.getLeadForms(pageId);
    }

    let totalImported = 0;
    let totalDuplicatesSkipped = 0;

    try {
      for (const form of targetForms) {
        let hasNext = true;
        let afterCursor = null;

        while (hasNext) {
          const pageResult = await this.fetchFormLeads(form.id, { limit: 50, afterCursor });
          const rawLeads = pageResult.data || [];

          // High-speed parallel batch persistence
          const BATCH_SIZE = 10;
          for (let i = 0; i < rawLeads.length; i += BATCH_SIZE) {
            const batch = rawLeads.slice(i, i + BATCH_SIZE);
            const savePromises = batch.map(async (item) => {
              const fields = {};
              for (const f of item.field_data || []) {
                fields[f.name] = Array.isArray(f.values) && f.values.length > 0 ? f.values[0] : '';
              }

              const name = fields.full_name || fields.first_name || (fields.first_name && fields.last_name ? `${fields.first_name} ${fields.last_name}` : '') || 'Meta Lead';
              const email = fields.email || '';
              const phone = fields.phone_number || fields.phone || '';

              const extraNotes = Object.entries(fields)
                .filter(([k]) => !['full_name', 'first_name', 'last_name', 'email', 'phone_number', 'phone'].includes(k))
                .map(([k, v]) => `${k}: ${v}`)
                .join(', ');

              const record = {
                id: `meta_${item.id}`,
                meta_leadgen_id: item.id,
                meta_form_id: item.form_id || form.id,
                meta_ad_id: item.ad_id || null,
                meta_ad_name: item.ad_name || null,
                meta_adset_id: item.adset_id || null,
                meta_adset_name: item.adset_name || null,
                meta_campaign_id: item.campaign_id || null,
                campaign: item.campaign_name || form.name || 'Meta Ads Campaign',
                name,
                email,
                phone,
                source: 'Meta Ads',
                status: 'newLead',
                assignedTo: '',
                createdAt: item.created_time || new Date().toISOString(),
                syncedAt: new Date().toISOString(),
                note: extraNotes ? `Form details: ${extraNotes}` : `Synced from Meta Form "${form.name}"`,
                activities: [
                  {
                    id: `act_${Date.now()}_${Math.random().toString(36).substr(2, 4)}`,
                    title: 'Synced from Meta Lead Form',
                    description: `Imported from Form ${form.name || form.id}`,
                    timestamp: new Date().toISOString(),
                  },
                ],
                followUps: [],
              };

              const saved = await firebaseService.saveLead(record, { autoNotify: false });
              return saved ? 'saved' : 'skipped';
            });

            const results = await Promise.allSettled(savePromises);
            for (const r of results) {
              if (r.status === 'fulfilled') {
                if (r.value === 'saved') totalImported++;
                else totalDuplicatesSkipped++;
              }
            }
          }

          if (pageResult.paging?.cursors?.after && pageResult.paging?.next) {
            afterCursor = pageResult.paging.cursors.after;
          } else {
            hasNext = false;
          }
        }
      }

      this.lastSyncInfo = {
        lastSyncTime: new Date().toISOString(),
        syncedCount: totalImported,
        duplicatesSkipped: totalDuplicatesSkipped,
        status: 'success',
        lastError: null,
      };

      // Clear cache to reflect freshly synced leads immediately
      this.clearCache();

      // Dispatch alert to Admin when new leads are imported
      if (totalImported > 0) {
        try {
          const notificationService = require('./notificationService');
          notificationService.notifyNewLead({
            id: `batch_sync_${Date.now()}`,
            name: `${totalImported} New Meta Leads`,
            campaign: 'Meta Ads Sync',
            source: 'Meta Ads',
            phone: '',
            note: `Successfully imported ${totalImported} leads from Meta Ads.`,
          }).catch(() => {});
        } catch (_) {}
      }

      console.log(`✅ [MetaService:syncAllLeads] Sync completed: ${totalImported} leads imported/updated, ${totalDuplicatesSkipped} duplicates skipped.`);
      return this.lastSyncInfo;
    } catch (err) {
      this.lastSyncInfo = {
        lastSyncTime: new Date().toISOString(),
        syncedCount: totalImported,
        status: 'failed',
        lastError: err.message,
      };
      console.error(`❌ [MetaService:syncAllLeads] Error during sync:`, err.message);
      throw err;
    }
  }

  /**
   * Phase 5: Verifies incoming webhook X-Hub-Signature-256 header (HMAC-SHA256)
   */
  verifyWebhookSignature(rawBody, signatureHeader) {
    if (!this.appSecret) {
      console.warn('⚠️ [Webhook] META_APP_SECRET is not configured; skipping signature verification.');
      return true;
    }
    if (!signatureHeader) return false;

    const [scheme, signature] = signatureHeader.split('=');
    if (scheme !== 'sha256') return false;

    const expectedHash = crypto
      .createHmac('sha256', this.appSecret)
      .update(rawBody)
      .digest('hex');

    try {
      return crypto.timingSafeEqual(Buffer.from(signature, 'hex'), Buffer.from(expectedHash, 'hex'));
    } catch (_) {
      return false;
    }
  }

  /**
   * Phase 5: Validates webhook challenge during Meta webhook subscription setup
   */
  verifyWebhookChallenge(mode, token, challenge) {
    if (mode === 'subscribe' && token === this.verifyToken) {
      return challenge;
    }
    return null;
  }

  /**
   * Token Discovery Wizard: User Profile, Ad Accounts, Pages, Forms
   */
  async discoverAssets(token) {
    if (!token || token.trim() === '') {
      throw new Error('Access Token is required to discover Meta assets.');
    }
    const t = token.trim();

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
        params: { access_token: t, fields: 'id,name,account_id,currency,account_status,timezone_name' },
        timeout: 8000,
      });
      adAccounts = (adAccRes.data.data || []).map((a) => ({
        id: a.id.startsWith('act_') ? a.id : `act_${a.id}`,
        name: a.name || `Ad Account ${a.account_id || a.id}`,
        currency: a.currency || 'INR',
        status: a.account_status === 1 ? 'ACTIVE' : 'INACTIVE',
        timezone: a.timezone_name || 'UTC',
      }));
    } catch (adErr) {
      console.warn('⚠️ Could not discover ad accounts:', adErr.message);
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
      console.warn('⚠️ Could not discover pages:', pageErr.message);
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
  }

  /**
   * Test Meta Connection
   */
  async testConnection() {
    if (!this.accessToken) {
      return { success: false, message: 'Meta Access Token is not configured.' };
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

  /**
   * Backward Compatibility CRM Campaign Methods
   * Preserves existing CRM campaign creation and status toggle logic
   */
  async createCampaign(params) {
    if (!this.isConfigured()) {
      return { id: `sim_camp_${Date.now()}`, ...params };
    }
    const { name, objective = 'OUTCOME_LEADS', status = 'ACTIVE' } = params;
    return await this._request('POST', `/${this.adAccountId}/campaigns`, {
      name,
      objective,
      status,
      special_ad_categories: ['NONE'],
    });
  }

  async createAdSet(params) {
    if (!this.isConfigured()) {
      return { id: `sim_adset_${Date.now()}`, ...params };
    }
    const { campaignId, name, dailyBudget = 1000, countries = ['IN'], pageId = this.pageId, status = 'ACTIVE' } = params;
    const startTime = new Date(Date.now() + 60000).toISOString();
    return await this._request('POST', `/${this.adAccountId}/adsets`, {
      name: `${name} - Ad Set`,
      campaign_id: campaignId,
      daily_budget: Math.round(Number(dailyBudget) * 100),
      billing_event: 'IMPRESSIONS',
      optimization_goal: 'LEAD_GENERATION',
      bid_strategy: 'LOWEST_COST_WITHOUT_CAP',
      start_time: startTime,
      status,
      promoted_object: { page_id: pageId },
      targeting: { geo_locations: { countries } },
    });
  }

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
            value: { lead_gen_form_id: leadFormId },
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

    let campaignResult;
    try {
      campaignResult = await this.createCampaign({
        name,
        objective: 'OUTCOME_LEADS',
        status,
      });
    } catch (err) {
      console.warn(`⚠️ [MetaService] Live campaign creation fallback: ${err.message}`);
      campaignResult = { id: `sim_camp_${Date.now()}`, name, status };
    }
    const campaignId = campaignResult.id;

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
    } catch (err) {
      console.warn(`⚠️ Ad Set step note: ${err.message}`);
    }

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

        if (adSetResult?.id) {
          adResult = await this.createAd({
            name,
            adsetId: adSetResult.id,
            creativeId: creativeResult.id,
            status,
          });
        }
      } catch (err) {
        console.warn(`⚠️ Ad / Creative step note: ${err.message}`);
      }
    }

    this.clearCache();

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

  async updateCampaignStatus(campaignId, status) {
    if (!this.isConfigured()) {
      return { id: campaignId, status };
    }
    const res = await this._request('POST', `/${campaignId}`, { status });
    this.clearCache();
    return res;
  }
}

module.exports = new MetaService();
