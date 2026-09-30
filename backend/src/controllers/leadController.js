const firebaseService = require('../services/firebase');
const metaService = require('../services/metaService');
const notificationService = require('../services/notificationService');

const LeadController = {
  /**
   * GET /api/leads
   * Returns leads from Firebase Firestore / Realtime Database
   */
  async getLeads(req, res) {
    try {
      const { status, assignedTo } = req.query;
      const leads = await firebaseService.getLeads({ status, assignedTo });
      res.json({
        success: true,
        count: leads.length,
        data: leads,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * GET /api/leads/:id
   */
  async getLeadById(req, res) {
    try {
      const lead = await firebaseService.getLeadById(req.params.id);
      if (!lead) {
        return res.status(404).json({ success: false, message: 'Lead not found' });
      }
      res.json({ success: true, data: lead });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/leads
   * When an Admin adds a new lead:
   * - If unassigned: broadcast notification to ALL users
   * - If assigned on creation: notify that respective user only
   */
  async createLead(req, res) {
    try {
      const leadData = req.body;
      const created = await firebaseService.saveLead(leadData);

      // Trigger targeted or broadcast notifications
      if (leadData.assignedTo && leadData.assignedTo.trim().length > 0) {
        notificationService.notifyLeadAllotment(created, leadData.assignedTo, leadData.addedBy || 'Admin').catch(() => {});
      } else {
        notificationService.notifyNewLeadAddedByAdmin(created, leadData.addedBy || 'Admin').catch(() => {});
      }

      res.status(201).json({ success: true, data: created });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * PATCH /api/leads/:id
   * Updates lead; if assignedTo changed, triggers allotment alert to that user only
   */
  async updateLead(req, res) {
    try {
      const existing = await firebaseService.getLeadById(req.params.id);
      const updated = await firebaseService.updateLead(req.params.id, req.body);
      if (!updated) {
        return res.status(404).json({ success: false, message: 'Lead not found' });
      }

      // Check if lead was newly allotted
      if (req.body.assignedTo && (!existing || existing.assignedTo !== req.body.assignedTo)) {
        notificationService.notifyLeadAllotment(
          updated,
          req.body.assignedTo,
          req.body.allottedBy || 'Admin'
        ).catch(() => {});
      }

      res.json({ success: true, data: updated });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/leads/:id/allot
   * Explicit endpoint for Admin to allot a lead to a sales executive
   */
  async allotLead(req, res) {
    try {
      const { assignedTo, allottedBy = 'Admin' } = req.body;
      if (!assignedTo) {
        return res.status(400).json({ success: false, error: 'assignedTo is required' });
      }

      const updated = await firebaseService.updateLead(req.params.id, {
        assignedTo,
        status: 'qualified',
      });

      if (!updated) {
        return res.status(404).json({ success: false, message: 'Lead not found' });
      }

      // Notify THAT respective user only across all his logged-in devices
      const alertResult = await notificationService.notifyLeadAllotment(
        updated,
        assignedTo,
        allottedBy
      );

      res.json({
        success: true,
        message: `Lead successfully allotted to ${assignedTo}`,
        data: updated,
        notification: alertResult,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/leads/sync
   * Manually syncs leads from a specific Meta Lead Form into Firebase Firestore
   */
  async syncMetaLeads(req, res) {
    try {
      const { formId } = req.body;
      const targetFormId = formId || 'default';
      console.log(`🔄 [Sync] Starting manual lead sync from Meta Form: ${targetFormId}...`);

      const rawLeads = await metaService.fetchFormLeads(targetFormId);
      let newCount = 0;

      for (const item of rawLeads) {
        const fields = {};
        for (const f of item.field_data || []) {
          fields[f.name] = Array.isArray(f.values) && f.values.length > 0 ? f.values[0] : '';
        }

        const name = fields.full_name || fields.first_name || 'Meta Sync Lead';
        const email = fields.email || '';
        const phone = fields.phone_number || fields.phone || '';

        const record = {
          id: `meta_${item.id}`,
          meta_leadgen_id: item.id,
          meta_form_id: formId,
          name,
          email,
          phone,
          source: 'Meta Ads',
          campaign: item.campaign_name || 'Meta Lead Gen Campaign',
          status: 'newLead',
          assignedTo: '',
          createdAt: item.created_time || new Date().toISOString(),
          note: `Synced from Meta Form ${targetFormId}`,
          activities: [
            {
              id: `act_${Date.now()}`,
              title: 'Synced from Meta Lead Form',
              description: `Batch sync from Form ${targetFormId}`,
              timestamp: new Date().toISOString(),
            },
          ],
          followUps: [],
        };

        await firebaseService.saveLead(record);
        newCount++;
      }

      const allLeads = await firebaseService.getLeads();
      res.json({
        success: true,
        message: `Successfully synced ${newCount} leads from Meta to Firebase`,
        syncedCount: newCount,
        totalLeadsInDb: allLeads.length,
      });
    } catch (err) {
      console.error('❌ [Sync Error]:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  },
};

module.exports = LeadController;
