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
      console.log(`📥 [LeadController:createLead] Incoming lead: "${leadData.name}" (Phone: ${leadData.phone}, AssignedTo: "${leadData.assignedTo || 'Unassigned'}")`);

      const created = await firebaseService.saveLead(leadData, { autoNotify: false });
      console.log(`💾 [LeadController:createLead] Saved in DB with ID: ${created.id}`);

      // Trigger targeted or broadcast notifications
      let notificationResult = null;
      try {
        if (leadData.assignedTo && leadData.assignedTo.trim().length > 0) {
          notificationResult = await notificationService.notifyLeadAllotment(created, leadData.assignedTo, leadData.addedBy || 'Admin');
        } else {
          notificationResult = await notificationService.notifyNewLeadAddedByAdmin(created, leadData.addedBy || 'Admin');
        }
      } catch (notifErr) {
        console.error(`❌ [LeadController:createLead] Notification dispatch error: ${notifErr.message}`);
        notificationResult = { success: false, error: notifErr.message };
      }

      res.status(201).json({
        success: true,
        data: created,
        notification: notificationResult,
      });
    } catch (err) {
      console.error(`❌ [LeadController:createLead] Error creating lead: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * PATCH /api/leads/:id
   * Updates lead; triggers allotment alert if assignedTo changed, or status alert to Admin if status changed
   */
  async updateLead(req, res) {
    try {
      const existing = await firebaseService.getLeadById(req.params.id);
      const updated = await firebaseService.updateLead(req.params.id, req.body);
      if (!updated) {
        return res.status(404).json({ success: false, message: 'Lead not found' });
      }

      // Check if lead was newly allotted by Admin
      if (req.body.assignedTo && (!existing || existing.assignedTo !== req.body.assignedTo)) {
        notificationService.notifyLeadAllotment(
          updated,
          req.body.assignedTo,
          req.body.allottedBy || 'Admin'
        ).catch((err) => console.warn('Allotment notification warning:', err.message));
      }

      // Check if status was changed by Sales Agent/user -> Notify Admin
      if (req.body.status && (!existing || existing.status !== req.body.status)) {
        notificationService.notifyLeadStatusChanged({
          lead: updated,
          previousStatus: existing ? existing.status : 'newLead',
          newStatus: req.body.status,
          updatedBy: req.body.updatedBy || req.body.agentName || updated.assignedTo || 'Sales Agent',
          note: req.body.note || '',
        }).catch((err) => console.warn('Status notification warning:', err.message));
      }

      res.json({ success: true, data: updated });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * PATCH /api/leads/:id/status
   * Dedicated endpoint when a sales agent updates the progress/status of a lead
   * Triggers an instant notification exclusively to Admin devices
   */
  async updateLeadStatus(req, res) {
    try {
      const { status, updatedBy = 'Sales Agent', previousStatus, note = '' } = req.body;
      console.log(`📥 [LeadController:updateLeadStatus] Lead "${req.params.id}" status update to "${status}" by "${updatedBy}"`);

      if (!status) {
        return res.status(400).json({ success: false, error: 'status is required' });
      }

      const existing = await firebaseService.getLeadById(req.params.id);
      const oldStatus = previousStatus || (existing ? existing.status : 'newLead');

      const updated = await firebaseService.updateLead(req.params.id, {
        status,
        updatedBy,
        ...(note ? { note } : {}),
      });

      if (!updated) {
        return res.status(404).json({ success: false, message: 'Lead not found' });
      }

      let notifResult = null;
      if (oldStatus !== status) {
        notifResult = await notificationService.notifyLeadStatusChanged({
          lead: updated,
          previousStatus: oldStatus,
          newStatus: status,
          updatedBy,
          note,
        });
      }

      res.json({
        success: true,
        message: `Lead status updated to ${status}`,
        data: updated,
        notification: notifResult,
      });
    } catch (err) {
      console.error(`❌ [LeadController:updateLeadStatus] Error: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/leads/bulk-allot
   * Explicit endpoint for Admin to allot multiple leads in bulk to a sales executive
   * Updates all leads and sends ONE consolidated summary notification to the agent
   */
  async bulkAllotLeads(req, res) {
    try {
      const { leadIds = [], assignedTo, allottedBy = 'Admin' } = req.body;
      console.log(`📥 [LeadController:bulkAllotLeads] Allotting ${leadIds.length} leads to "${assignedTo}" by "${allottedBy}"`);

      if (!assignedTo) {
        return res.status(400).json({ success: false, error: 'assignedTo is required' });
      }
      if (!Array.isArray(leadIds) || leadIds.length === 0) {
        return res.status(400).json({ success: false, error: 'leadIds array is required' });
      }

      const updatedLeads = [];
      const leadNames = [];

      for (const id of leadIds) {
        const updated = await firebaseService.updateLead(id, {
          assignedTo,
          status: 'qualified',
        });
        if (updated) {
          updatedLeads.push(updated);
          if (updated.name) leadNames.push(updated.name);
        }
      }

      console.log(`💾 [LeadController:bulkAllotLeads] Updated ${updatedLeads.length} leads. Sending consolidated notification...`);

      // Send ONE single summary notification stating the exact count of leads assigned
      const notifResult = await notificationService.notifyBulkLeadAllotment({
        leadCount: updatedLeads.length,
        leadNames,
        assignedTo,
        allottedBy,
      });

      res.json({
        success: true,
        message: `${updatedLeads.length} leads successfully allotted to ${assignedTo}`,
        count: updatedLeads.length,
        assignedTo,
        notification: notifResult,
      });
    } catch (err) {
      console.error(`❌ [LeadController:bulkAllotLeads] Error: ${err.message}`);
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
      console.log(`📥 [LeadController:allotLead] Alloting Lead "${req.params.id}" to "${assignedTo}" by "${allottedBy}"`);

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

      console.log(`💾 [LeadController:allotLead] Lead "${updated.name}" updated. Triggering allotment notification...`);
      // Notify THAT respective user only across all his logged-in devices
      const alertResult = await notificationService.notifyLeadAllotment(
        updated,
        assignedTo,
        allottedBy
      );
      console.log(`📋 [LeadController:allotLead] Allotment notification result:`, JSON.stringify(alertResult, null, 2));

      res.json({
        success: true,
        message: `Lead successfully allotted to ${assignedTo}`,
        data: updated,
        notification: alertResult,
      });
    } catch (err) {
      console.error(`❌ [LeadController:allotLead] Error: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/leads/sync
   * Manually syncs leads from a specific Meta Lead Form into Firebase Firestore
   */
  async syncMetaLeads(req, res) {
    try {
      const { formId, pageId } = req.body;
      console.log(`🔄 [Sync] Starting lead sync from Meta (Form: ${formId || 'all'}, Page: ${pageId || 'default'})...`);

      const syncResult = await metaService.syncAllLeads({
        formId,
        pageId,
        firebaseService,
      });

      const allLeads = await firebaseService.getLeads();
      res.json({
        success: true,
        message: `Successfully synced ${syncResult.syncedCount} leads from Meta Ads (${syncResult.duplicatesSkipped || 0} duplicates skipped)`,
        syncedCount: syncResult.syncedCount,
        duplicatesSkipped: syncResult.duplicatesSkipped || 0,
        totalLeadsInDb: allLeads.length,
        lastSyncTime: syncResult.lastSyncTime,
      });
    } catch (err) {
      console.error('❌ [Sync Error]:', err.message);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * DELETE /api/leads/:id
   * Moves a single lead to Recycle Bin (retained for 30 days)
   */
  async deleteLead(req, res) {
    try {
      const { id } = req.params;
      const deletedBy = req.body.deletedBy || req.user?.name || 'Admin';
      console.log(`🗑️ [LeadController:deleteLead] Moving lead "${id}" to bin by "${deletedBy}"`);
      const result = await firebaseService.deleteLead(id, deletedBy);
      res.json({
        success: true,
        message: 'Lead moved to Recycle Bin (kept for 30 days)',
        id,
        binRecord: result,
      });
    } catch (err) {
      console.error(`❌ [LeadController:deleteLead] Error: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/leads/bulk-delete
   * Bulk moves multiple leads to Recycle Bin by their IDs (retained for 30 days)
   */
  async deleteLeadsBulk(req, res) {
    try {
      const { leadIds = [], deletedBy = 'Admin' } = req.body;
      console.log(`🗑️ [LeadController:deleteLeadsBulk] Moving ${leadIds.length} leads to bin by "${deletedBy}"`);
      if (!Array.isArray(leadIds) || leadIds.length === 0) {
        return res.status(400).json({ success: false, error: 'leadIds array is required' });
      }

      const result = await firebaseService.deleteLeadsBulk(leadIds, deletedBy);
      res.json({
        success: true,
        message: `Successfully moved ${result.deletedCount} leads to Recycle Bin (kept for 30 days)`,
        deletedCount: result.deletedCount,
      });
    } catch (err) {
      console.error(`❌ [LeadController:deleteLeadsBulk] Error: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/leads/delete-by-category
   * Moves all leads matching a category (e.g., 'salary', 'home', 'business') to bin
   */
  async deleteLeadsByCategory(req, res) {
    try {
      const { category, deletedBy = 'Admin' } = req.body;
      console.log(`🗑️ [LeadController:deleteLeadsByCategory] Moving "${category}" leads to bin by "${deletedBy}"`);
      if (!category) {
        return res.status(400).json({ success: false, error: 'category is required' });
      }

      const result = await firebaseService.deleteLeadsByCategory(category, deletedBy);
      res.json({
        success: true,
        message: `Successfully moved ${result.deletedCount} ${category} leads to Recycle Bin`,
        deletedCount: result.deletedCount,
        category,
      });
    } catch (err) {
      console.error(`❌ [LeadController:deleteLeadsByCategory] Error: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  // ── RECYCLE BIN CONTROLLERS ──

  /**
   * GET /api/leads/bin
   * Fetch all leads currently in the Recycle Bin
   */
  async getBinLeads(req, res) {
    try {
      const leads = await firebaseService.getBinLeads();
      res.json({
        success: true,
        count: leads.length,
        data: leads,
      });
    } catch (err) {
      console.error(`❌ [LeadController:getBinLeads] Error: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/leads/bin/:id/restore
   * Restores a lead from the Recycle Bin back to active leads
   */
  async restoreLead(req, res) {
    try {
      const { id } = req.params;
      console.log(`♻️ [LeadController:restoreLead] Restoring lead "${id}" from bin`);
      const restored = await firebaseService.restoreLeadFromBin(id);
      if (!restored) {
        return res.status(404).json({ success: false, message: 'Lead not found in Recycle Bin' });
      }
      res.json({
        success: true,
        message: 'Lead restored successfully',
        data: restored,
      });
    } catch (err) {
      console.error(`❌ [LeadController:restoreLead] Error: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * DELETE /api/leads/bin/:id
   * Permanently deletes a lead from the Recycle Bin
   */
  async permanentDeleteLead(req, res) {
    try {
      const { id } = req.params;
      console.log(`💥 [LeadController:permanentDeleteLead] Permanently deleting lead "${id}" from bin`);
      await firebaseService.permanentDeleteLead(id);
      res.json({
        success: true,
        message: 'Lead permanently deleted',
        id,
      });
    } catch (err) {
      console.error(`❌ [LeadController:permanentDeleteLead] Error: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * DELETE /api/leads/bin
   * Empties the entire Recycle Bin permanently
   */
  async emptyBin(req, res) {
    try {
      console.log(`💥 [LeadController:emptyBin] Emptying entire Recycle Bin`);
      await firebaseService.emptyBin();
      res.json({
        success: true,
        message: 'Recycle Bin emptied successfully',
      });
    } catch (err) {
      console.error(`❌ [LeadController:emptyBin] Error: ${err.message}`);
      res.status(500).json({ success: false, error: err.message });
    }
  },
};

module.exports = LeadController;
