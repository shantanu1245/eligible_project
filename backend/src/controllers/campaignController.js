const firebaseService = require('../services/firebase');
const metaService = require('../services/metaService');

const CampaignController = {
  /**
   * GET /api/campaigns
   * List all campaigns from Firebase (and reconciles with Meta API insights if live)
   */
  async getCampaigns(req, res) {
    try {
      const dbCampaigns = await firebaseService.getCampaigns();

      // If Meta credentials are live, optionally fetch latest insights and sync
      if (metaService.isConfigured()) {
        try {
          const metaCampaigns = await metaService.getCampaigns();
          if (metaCampaigns && metaCampaigns.length > 0) {
            for (const mc of metaCampaigns) {
              const existing = dbCampaigns.find((c) => c.meta_campaign_id === mc.id || c.id === mc.id);
              if (existing) {
                const spend = mc.insights?.data?.[0]?.spend ? parseFloat(mc.insights.data[0].spend) : existing.spend;
                await firebaseService.updateCampaign(existing.id, {
                  status: mc.status,
                  spend,
                });
              }
            }
          }
        } catch (syncErr) {
          console.warn('Could not sync live Meta campaign insights:', syncErr.message);
        }
      }

      const refreshed = await firebaseService.getCampaigns();
      res.json({
        success: true,
        count: refreshed.length,
        data: refreshed,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/campaigns
   * Creates a brand new Meta Ads Campaign from Eligible CRM
   * Orchestrates Campaign -> Ad Set -> Ad Creative -> Ad on Meta Marketing API,
   * then records in Firebase Firestore.
   */
  async createCampaign(req, res) {
    try {
      const {
        name,
        dailyBudget,
        platform = 'Facebook & Instagram',
        targetLocations = ['IN'],
        pageId,
        formId,
        headline,
        bodyText,
        status = 'ACTIVE',
      } = req.body;

      if (!name) {
        return res.status(400).json({ success: false, message: 'Campaign name is required' });
      }

      console.log(`✨ [CampaignController] Creating new Meta Ads Campaign: "${name}"`);

      // Execute Meta Marketing API creation pipeline
      const metaResult = await metaService.createFullLeadCampaign({
        name,
        dailyBudget: Number(dailyBudget) || 1000,
        platform,
        targetLocations: Array.isArray(targetLocations) ? targetLocations : ['IN'],
        pageId,
        formId,
        headline: headline || `${name} - Exclusive Enquiries`,
        bodyText: bodyText || 'Book your site visit today. Fast response guaranteed.',
        status: status || 'ACTIVE',
      });

      // Save directly to Firebase Firestore
      const savedToFirebase = await firebaseService.saveCampaign(metaResult);

      res.status(201).json({
        success: true,
        message: 'Campaign created successfully on Meta Ads and recorded in Firebase',
        data: savedToFirebase,
      });
    } catch (err) {
      console.error('❌ [Campaign Creation Error]:', err.message);
      res.status(err.statusCode || 500).json({
        success: false,
        error: err.message,
        details: err.metaError || null,
      });
    }
  },

  /**
   * PATCH /api/campaigns/:id/status
   * Pause or Activate campaign on Meta Ads & Firebase
   */
  async toggleCampaignStatus(req, res) {
    try {
      const { id } = req.params;
      const { status } = req.body; // 'ACTIVE' or 'PAUSED'

      if (!['ACTIVE', 'PAUSED'].includes(status)) {
        return res.status(400).json({ success: false, message: "Status must be 'ACTIVE' or 'PAUSED'" });
      }

      const campaign = await firebaseService.getCampaigns().then((list) => list.find((c) => c.id === id || c.meta_campaign_id === id));
      if (!campaign) {
        return res.status(404).json({ success: false, message: 'Campaign not found' });
      }

      // Update on Meta Ads
      if (campaign.meta_campaign_id) {
        try {
          await metaService.updateCampaignStatus(campaign.meta_campaign_id, status);
        } catch (mErr) {
          console.warn(`Could not update Meta campaign ${campaign.meta_campaign_id} status:`, mErr.message);
        }
      }

      // Update in Firebase
      const updated = await firebaseService.updateCampaign(campaign.id, { status });

      res.json({
        success: true,
        message: `Campaign status updated to ${status}`,
        data: updated,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },
};

module.exports = CampaignController;
