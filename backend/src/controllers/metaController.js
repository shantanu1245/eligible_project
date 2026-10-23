const config = require('../config/config');
const metaService = require('../services/metaService');
const firebaseService = require('../services/firebase');

const MetaController = {
  /**
   * GET /api/meta/status
   * Comprehensive status of Firebase & Meta Ads integrations
   */
  async getStatus(req, res) {
    const metaStatus = metaService.getStatus();
    const firebaseStatus = firebaseService.getStatus();

    res.json({
      success: true,
      data: {
        server: {
          port: config.port,
          environment: config.env,
          uptime: process.uptime(),
        },
        firebase: firebaseStatus,
        meta: {
          ...metaStatus,
          webhookEndpoint: `${req.protocol}://${req.get('host') || 'localhost:5000'}/api/webhooks/meta`,
          verifyToken: config.meta.webhookVerifyToken,
        },
      },
    });
  },

  /**
   * GET /api/meta/diagnostics
   * Validates token and reports granted permissions, expiration, and required permission checks
   */
  async getDiagnostics(req, res) {
    try {
      const forceRefresh = req.query.refresh === 'true' || req.query.forceRefresh === 'true';
      const diag = await metaService.getDiagnostics({ forceRefresh });
      res.json({
        success: diag.tokenValid,
        data: diag,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * GET /api/meta/accounts
   * Phase 3.A: Retrieve accessible Ad Accounts with status, currency, timezone, and spend
   */
  async getAccounts(req, res) {
    try {
      const forceRefresh = req.query.refresh === 'true' || req.query.forceRefresh === 'true';
      const accounts = await metaService.getAdAccounts({ forceRefresh });
      res.json({
        success: true,
        count: accounts.length,
        data: accounts,
        selectedAccountId: metaService.adAccountId || (accounts[0] ? accounts[0].id : null),
      });
    } catch (err) {
      console.error('❌ [MetaController:getAccounts] Error:', err.message);
      res.status(err.statusCode || 500).json({
        success: false,
        error: err.message,
        details: err.metaError || null,
      });
    }
  },

  /**
   * GET /api/meta/campaigns
   * Phase 3.B: Retrieve Campaigns from Meta with live metrics
   */
  async getCampaigns(req, res) {
    try {
      const { adAccountId, datePreset, status } = req.query;
      const forceRefresh = req.query.refresh === 'true' || req.query.forceRefresh === 'true';
      const targetAccount = adAccountId || metaService.adAccountId;

      const liveCampaigns = await metaService.getCampaigns(targetAccount, { datePreset, status, forceRefresh });

      if (liveCampaigns !== null) {
        return res.json({
          success: true,
          source: 'meta_live',
          adAccountId: targetAccount,
          count: liveCampaigns.length,
          data: liveCampaigns,
        });
      }

      // Fallback to database stored campaigns if live credentials not yet set
      const dbCampaigns = await firebaseService.getCampaigns();
      res.json({
        success: true,
        source: 'database_fallback',
        adAccountId: targetAccount || 'local',
        count: dbCampaigns.length,
        data: dbCampaigns,
      });
    } catch (err) {
      console.error('❌ [MetaController:getCampaigns] Error:', err.message);
      res.status(err.statusCode || 500).json({
        success: false,
        error: err.message,
        details: err.metaError || null,
      });
    }
  },

  /**
   * GET /api/meta/adsets
   * Phase 3.C: Retrieve Ad Sets with budget, schedule, targeting, and metrics
   */
  async getAdSets(req, res) {
    try {
      const { adAccountId, campaignId, datePreset, status } = req.query;
      const forceRefresh = req.query.refresh === 'true' || req.query.forceRefresh === 'true';
      const targetAccount = adAccountId || metaService.adAccountId;

      const adSets = await metaService.getAdSets(targetAccount, { campaignId, datePreset, status, forceRefresh });
      res.json({
        success: true,
        adAccountId: targetAccount,
        campaignId: campaignId || null,
        count: adSets.length,
        data: adSets,
      });
    } catch (err) {
      console.error('❌ [MetaController:getAdSets] Error:', err.message);
      res.status(err.statusCode || 500).json({
        success: false,
        error: err.message,
        details: err.metaError || null,
      });
    }
  },

  /**
   * GET /api/meta/ads
   * Phase 3.D: Retrieve Ads with creative metadata, destination, and metrics
   */
  async getAds(req, res) {
    try {
      const { adAccountId, campaignId, adSetId, datePreset, status } = req.query;
      const forceRefresh = req.query.refresh === 'true' || req.query.forceRefresh === 'true';
      const targetAccount = adAccountId || metaService.adAccountId;

      const ads = await metaService.getAds(targetAccount, { campaignId, adSetId, datePreset, status, forceRefresh });
      res.json({
        success: true,
        adAccountId: targetAccount,
        campaignId: campaignId || null,
        adSetId: adSetId || null,
        count: ads.length,
        data: ads,
      });
    } catch (err) {
      console.error('❌ [MetaController:getAds] Error:', err.message);
      res.status(err.statusCode || 500).json({
        success: false,
        error: err.message,
        details: err.metaError || null,
      });
    }
  },

  /**
   * GET /api/meta/insights
   * Phase 3.E: Retrieve aggregated or daily performance insights with date presets
   */
  async getInsights(req, res) {
    try {
      const { adAccountId, level, id, datePreset, timeIncrement, since, until } = req.query;
      const forceRefresh = req.query.refresh === 'true' || req.query.forceRefresh === 'true';
      const targetAccount = adAccountId || metaService.adAccountId;

      const timeRange = since && until ? { since, until } : null;

      const insights = await metaService.getInsights({
        adAccountId: targetAccount,
        level: level || 'account',
        id: id || null,
        datePreset: datePreset || 'last_30d',
        timeRange,
        timeIncrement: timeIncrement || null,
        forceRefresh,
      });

      res.json({
        success: true,
        data: insights,
      });
    } catch (err) {
      console.error('❌ [MetaController:getInsights] Error:', err.message);
      res.status(err.statusCode || 500).json({
        success: false,
        error: err.message,
        details: err.metaError || null,
      });
    }
  },

  /**
   * GET /api/meta/sync-status
   * Phase 4 / 5: Get status and metrics of last lead sync
   */
  async getSyncStatus(req, res) {
    res.json({
      success: true,
      data: metaService.lastSyncInfo,
    });
  },

  /**
   * POST /api/meta/discover
   * Validates token and auto-discovers User Profile, Ad Accounts, Pages, and Forms
   */
  async discover(req, res) {
    try {
      const { accessToken } = req.body;
      if (!accessToken) {
        return res.status(400).json({ success: false, message: 'Access Token is required.' });
      }

      console.log('🔍 [MetaController] Discovering assets for provided token...');
      const discovered = await metaService.discoverAssets(accessToken);
      res.json(discovered);
    } catch (err) {
      console.error('❌ [Discover Error]:', err.message);
      res.status(err.statusCode || 400).json({
        success: false,
        message: err.message,
        details: err.metaError || null,
      });
    }
  },

  /**
   * POST /api/meta/config
   * Saves dynamic Meta account configuration
   */
  async saveConfig(req, res) {
    try {
      const { accessToken, adAccountId, pageId, appSecret, pageName, adAccountName, appId } = req.body;

      if (!accessToken) {
        return res.status(400).json({ success: false, message: 'Access Token is required.' });
      }

      // Update runtime service
      metaService.setCredentials({
        accessToken,
        adAccountId,
        pageId,
        appId,
        appSecret,
        pageName,
        adAccountName,
      });

      // Save to Firebase RTDB
      const saved = await firebaseService.saveMetaConfig({
        accessToken,
        adAccountId: adAccountId || metaService.adAccountId,
        pageId: pageId || metaService.pageId,
        appId: appId || metaService.appId,
        appSecret: appSecret || metaService.appSecret,
        pageName: pageName || '',
        adAccountName: adAccountName || '',
      });

      res.json({
        success: true,
        message: 'Meta account configuration successfully connected and saved!',
        data: {
          ...metaService.getStatus(),
          savedAt: saved.updated_time,
        },
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * GET /api/meta/config
   * Retrieves active Meta configuration (with masked token)
   */
  async getConfig(req, res) {
    try {
      const savedConfig = await firebaseService.getMetaConfig();
      const status = metaService.getStatus();

      res.json({
        success: true,
        data: {
          ...status,
          config: savedConfig
            ? {
                adAccountId: savedConfig.adAccountId,
                pageId: savedConfig.pageId,
                pageName: savedConfig.pageName,
                adAccountName: savedConfig.adAccountName,
                updated_time: savedConfig.updated_time,
              }
            : null,
        },
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/meta/test-connection
   * Test live Meta access token against Graph API
   */
  async testConnection(req, res) {
    const result = await metaService.testConnection();
    res.json(result);
  },

  /**
   * POST /api/meta/extend-token
   * Exchanges a short-lived User token for a 60-day Long-Lived Token
   */
  async extendToken(req, res) {
    try {
      const { accessToken } = req.body;
      const result = await metaService.exchangeForLongLivedToken(accessToken);
      if (result.success && result.accessToken) {
        metaService.setCredentials({ accessToken: result.accessToken });
      }
      res.json(result);
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * GET /api/meta/lead-forms
   * Get available Lead Generation forms for campaign creation & sync
   */
  async getLeadForms(req, res) {
    try {
      const pageId = req.query.pageId || metaService.pageId;
      const forceRefresh = req.query.refresh === 'true' || req.query.forceRefresh === 'true';
      const forms = await metaService.getLeadForms(pageId, { forceRefresh });
      res.json({
        success: true,
        count: forms.length,
        data: forms,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/meta/clear-cache
   * Invalidate in-memory Meta cache
   */
  async clearCache(req, res) {
    metaService.clearCache();
    res.json({ success: true, message: 'Meta cache cleared successfully' });
  },
};

module.exports = MetaController;
