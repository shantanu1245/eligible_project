const config = require('../config/config');
const metaService = require('../services/metaService');
const firebaseService = require('../services/firebase');

/**
 * Normalizes Meta's field_data array into key-value pairs
 */
function parseMetaFieldData(fieldData = []) {
  const fields = {};
  for (const item of fieldData) {
    const val = Array.isArray(item.values) && item.values.length > 0 ? item.values[0] : '';
    fields[item.name] = val;
  }

  // Attempt to resolve name, email, phone from standard or customized field keys
  const name =
    fields.full_name ||
    fields.first_name ||
    (fields.first_name && fields.last_name ? `${fields.first_name} ${fields.last_name}` : '') ||
    'Meta Lead';

  const email = fields.email || '';
  const phone = fields.phone_number || fields.phone || '';

  // Consolidate extra fields into notes
  const extraNotes = Object.entries(fields)
    .filter(([k]) => !['full_name', 'first_name', 'last_name', 'email', 'phone_number', 'phone'].includes(k))
    .map(([k, v]) => `${k}: ${v}`)
    .join(', ');

  return { name, email, phone, fields, extraNotes };
}

const WebhookController = {
  /**
   * GET /api/webhooks/meta
   * Meta Webhook Subscription Verification (Handshake)
   */
  verifyWebhook(req, res) {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    console.log('📡 [Webhook] Meta verification request received:');
    console.log(`   mode: ${mode}, token: ${token}`);

    const verifiedChallenge = metaService.verifyWebhookChallenge(mode, token, challenge);

    if (verifiedChallenge) {
      console.log('✅ [Webhook] Meta webhook verified successfully! Responding with challenge.');
      return res.status(200).send(challenge);
    } else {
      console.warn('❌ [Webhook] Webhook verification failed. Tokens did not match.');
      return res.status(403).json({ error: 'Verification token mismatch' });
    }
  },

  /**
   * POST /api/webhooks/meta
   * Meta Real-time Lead Event Receiver
   */
  async handleWebhook(req, res) {
    try {
      const payload = req.body;
      console.log('📥 [Webhook] Incoming Meta webhook event received');

      // Always acknowledge receipt to Meta immediately (must respond within 20s)
      res.status(200).send('EVENT_RECEIVED');

      // Async logging to Firebase/Local store
      await firebaseService.logWebhook(payload);

      if (payload.object !== 'page') {
        console.log(`ℹ️ [Webhook] Non-page object received: ${payload.object}, skipping.`);
        return;
      }

      // Process entries
      if (Array.isArray(payload.entry)) {
        for (const entry of payload.entry) {
          const changes = entry.changes || [];
          for (const change of changes) {
            if (change.field === 'leadgen') {
              const leadgenValue = change.value || {};
              const leadgenId = leadgenValue.leadgen_id;
              const formId = leadgenValue.form_id;
              const adId = leadgenValue.ad_id;
              const createdTime = leadgenValue.created_time
                ? new Date(leadgenValue.created_time * 1000).toISOString()
                : new Date().toISOString();

              console.log(`🎯 [Webhook] Leadgen event detected: Lead ID ${leadgenId} from Form ${formId}`);

              // Fetch detailed lead information from Meta Graph API
              try {
                const leadDetails = await metaService.fetchLeadById(leadgenId);
                const { name, email, phone, extraNotes } = parseMetaFieldData(leadDetails.field_data);

                const newLeadRecord = {
                  id: `meta_${leadgenId}`,
                  meta_leadgen_id: leadgenId,
                  meta_form_id: formId,
                  meta_ad_id: adId || leadDetails.ad_id || null,
                  meta_ad_name: leadDetails.ad_name || null,
                  campaign: leadDetails.campaign_name || 'Meta Ad Campaign',
                  name,
                  email,
                  phone,
                  source: 'Meta Ads',
                  status: 'newLead',
                  assignedTo: '', // Initially unassigned for allotment
                  createdAt: createdTime,
                  note: extraNotes ? `Form details: ${extraNotes}` : 'Captured via Meta Lead Ad',
                  activities: [
                    {
                      id: `act_${Date.now()}`,
                      title: 'Lead Captured via Meta Ads',
                      description: `Captured from Meta Form #${formId}`,
                      timestamp: createdTime,
                    },
                  ],
                  followUps: [],
                };

                // Persist into Firebase Firestore
                await firebaseService.saveLead(newLeadRecord);
                console.log(`✅ [Webhook] Lead saved to Firebase: "${name}" (${email || phone})`);
              } catch (fetchErr) {
                console.error(`⚠️ [Webhook] Could not fetch/save lead ${leadgenId}:`, fetchErr.message);
              }
            }
          }
        }
      }
    } catch (err) {
      console.error('❌ [Webhook Error]:', err.message);
    }
  },

  /**
   * GET /api/webhooks/logs
   * Inspect recent webhook events
   */
  async getLogs(req, res) {
    try {
      const logs = await firebaseService.getWebhookLogs(50);
      res.json({ success: true, count: logs.length, logs });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },
};

module.exports = WebhookController;
