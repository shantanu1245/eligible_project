const admin = require('firebase-admin');

function withTimeout(promise, ms = 2500) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('FCM request timeout')), ms)),
  ]);
}

class NotificationService {
  constructor() {
    this.firebaseService = null;
  }

  setFirebaseService(service) {
    this.firebaseService = service;
  }

  /**
   * Dispatches new lead notification to both Admins and Sales Agents via:
   * 1. Firebase Cloud Messaging (FCM) Topic broadcast ('admin_leads' & 'sales_agents')
   * 2. Targeted FCM Device push to registered Admin & Sales Agent tokens
   * 3. Realtime Database persistent notification record in /notifications
   */
  async notifyNewLead(lead) {
    const timestamp = new Date().toISOString();
    const notifId = `notif_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;

    const leadName = lead.name || 'New Prospect';
    const propertyInterest = lead.propertyInterest || lead.campaign || 'Premium Property';
    const budget = lead.budget || 'Flexible Budget';
    const source = lead.source || 'Meta Ads';
    const phone = lead.phone || 'Phone not provided';
    const assignedTo = lead.assignedTo || '';

    // Notification payload for Admin
    const adminNotification = {
      id: `${notifId}_admin`,
      type: 'NEW_LEAD_ADMIN',
      title: `🎯 New Meta Lead: ${leadName}`,
      body: `${propertyInterest} • Budget: ${budget} • 📞 ${phone}`,
      leadId: lead.id,
      leadName,
      leadPhone: phone,
      budget,
      source,
      assignedTo: assignedTo || 'Unassigned',
      targetRole: 'admin',
      read: false,
      createdAt: timestamp,
    };

    // Notification payload for Sales Agents
    const salesNotification = {
      id: `${notifId}_sales`,
      type: assignedTo ? 'LEAD_ASSIGNED' : 'NEW_LEAD_AVAILABLE',
      title: assignedTo
        ? `⚡ Lead Assigned: ${leadName}`
        : `🔥 New Lead Available: ${leadName}`,
      body: `${propertyInterest} • ${budget} • Source: ${source}`,
      leadId: lead.id,
      leadName,
      leadPhone: phone,
      budget,
      source,
      assignedTo: assignedTo || 'Available for Claim',
      targetRole: 'sales_agent',
      read: false,
      createdAt: timestamp,
    };

    console.log(`🔔 [Notification] Preparing new lead alerts for Admin & Sales Team: "${leadName}"`);

    // 1. Save both notifications into Firebase Realtime Database
    if (this.firebaseService) {
      await this.firebaseService.saveNotification(adminNotification);
      await this.firebaseService.saveNotification(salesNotification);
    }

    // 2. Dispatch FCM Push Notifications
    let fcmAdminSent = false;
    let fcmSalesSent = false;
    let fcmError = null;

    if (admin && admin.apps && admin.apps.length > 0) {
      // 2a. Broadcast to 'admin_leads' topic
      try {
        await withTimeout(
          admin.messaging().send({
            topic: 'admin_leads',
            notification: {
              title: adminNotification.title,
              body: adminNotification.body,
            },
            data: {
              type: 'NEW_LEAD',
              role: 'admin',
              leadId: String(lead.id || ''),
              leadName: String(leadName),
              phone: String(phone),
              source: String(source),
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
          }),
          2500
        );
        fcmAdminSent = true;
        console.log(`✅ [FCM] Push sent to topic 'admin_leads'`);
      } catch (err) {
        console.warn(`⚠️ [FCM] Could not send to topic 'admin_leads': ${err.message}`);
        fcmError = err.message;
      }

      // 2b. Broadcast to 'sales_agents' topic
      try {
        await withTimeout(
          admin.messaging().send({
            topic: 'sales_agents',
            notification: {
              title: salesNotification.title,
              body: salesNotification.body,
            },
            data: {
              type: 'NEW_LEAD',
              role: 'sales_agent',
              leadId: String(lead.id || ''),
              leadName: String(leadName),
              assignedTo: String(assignedTo),
              source: String(source),
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
          }),
          2500
        );
        fcmSalesSent = true;
        console.log(`✅ [FCM] Push sent to topic 'sales_agents'`);
      } catch (err) {
        console.warn(`⚠️ [FCM] Could not send to topic 'sales_agents': ${err.message}`);
      }

      // 2c. Direct push to registered device tokens
      try {
        const tokens = await this.getRegisteredTokens();
        if (tokens.length > 0) {
          const directMessage = {
            notification: {
              title: adminNotification.title,
              body: adminNotification.body,
            },
            data: {
              leadId: String(lead.id || ''),
              type: 'NEW_LEAD',
            },
            tokens,
          };
          const multResponse = await withTimeout(admin.messaging().sendEachForMulticast(directMessage), 2500);
          console.log(`📱 [FCM] Sent direct push to ${multResponse.successCount} registered devices`);
        }
      } catch (tokenErr) {
        console.warn(`⚠️ [FCM] Multicast direct push note: ${tokenErr.message}`);
      }
    }

    return {
      success: true,
      notifications: [adminNotification, salesNotification],
      fcm: {
        adminTopicSent: fcmAdminSent,
        salesTopicSent: fcmSalesSent,
        note: fcmError,
      },
    };
  }

  /**
   * Registers an FCM Device Token for a user and subscribes to role-based topics
   */
  async registerToken({ userId, token, role = 'sales_agent', name = 'App User' }) {
    if (!token) throw new Error('FCM token is required');

    const cleanRole = role.toLowerCase().includes('admin') ? 'admin' : 'sales_agent';
    const targetTopic = cleanRole === 'admin' ? 'admin_leads' : 'sales_agents';

    // 1. Subscribe token to the relevant topic in Firebase Cloud Messaging
    let topicSubscribed = false;
    if (admin && admin.apps && admin.apps.length > 0) {
      try {
        await withTimeout(admin.messaging().subscribeToTopic([token], targetTopic), 2500);
        topicSubscribed = true;
        console.log(`✅ [FCM] Token for ${name} (${cleanRole}) subscribed to topic '${targetTopic}'`);
      } catch (err) {
        console.warn(`⚠️ [FCM] Failed to subscribe token to topic: ${err.message}`);
      }
    }

    // 2. Persist token in Firebase Realtime Database
    if (this.firebaseService) {
      await this.firebaseService.saveDeviceToken({
        userId: userId || `user_${Date.now()}`,
        token,
        role: cleanRole,
        name,
        updatedAt: new Date().toISOString(),
      });
    }

    return {
      success: true,
      userId,
      role: cleanRole,
      topic: targetTopic,
      topicSubscribed,
    };
  }

  async getRegisteredTokens(role) {
    if (!this.firebaseService) return [];
    return await this.firebaseService.getDeviceTokens(role);
  }

  /**
   * Send a test notification to verify setup for Admin and Sales Agents
   */
  async sendTestNotification({ role = 'both', customTitle, customBody } = {}) {
    const fakeLead = {
      id: `lead_test_${Date.now()}`,
      name: 'Rahul Sharma (Test Lead)',
      phone: '+91 98765 43210',
      budget: '₹1.50 Cr - ₹2.00 Cr',
      propertyInterest: 'Lodha Kharadi 3BHK Penthouse',
      source: 'Meta Lead Ad Test',
      assignedTo: role === 'sales_agent' ? 'Sales Agent' : '',
    };

    if (customTitle) fakeLead.name = customTitle;
    if (customBody) fakeLead.propertyInterest = customBody;

    return await this.notifyNewLead(fakeLead);
  }
}

module.exports = new NotificationService();
