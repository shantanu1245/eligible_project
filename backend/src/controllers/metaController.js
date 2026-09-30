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
          webhookEndpoint: `${req.protocol}://${req.get('host') || 'eligible-backend.onrender.com'}/api/webhooks/meta`,
          verifyToken: config.meta.webhookVerifyToken,
        },
      },
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
   * Saves dynamic Meta account configuration to Firebase Realtime Database
   */
  async saveConfig(req, res) {
    try {
      const { accessToken, adAccountId, pageId, appSecret, pageName, adAccountName } = req.body;

      if (!accessToken) {
        return res.status(400).json({ success: false, message: 'Access Token is required.' });
      }

      // Update runtime service
      metaService.setCredentials({
        accessToken,
        adAccountId,
        pageId,
        appSecret,
        pageName,
        adAccountName,
      });

      // Save to Firebase RTDB
      const saved = await firebaseService.saveMetaConfig({
        accessToken,
        adAccountId: adAccountId || metaService.adAccountId,
        pageId: pageId || metaService.pageId,
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
   * GET /api/meta/lead-forms
   * Get available Lead Generation forms for campaign creation & sync
   */
  async getLeadForms(req, res) {
    try {
      const pageId = req.query.pageId || metaService.pageId;
      const forms = await metaService.getLeadForms(pageId);
      res.json({
        success: true,
        count: forms.length,
        data: forms,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },
};

module.exports = MetaController;
