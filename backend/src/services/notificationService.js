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
  async registerToken({ userId, token, role = 'sales_agent', name = 'App User', deviceName = 'Mobile Device', platform = 'android' }) {
    if (!token) throw new Error('FCM token is required');

    const cleanRole = role.toLowerCase().includes('admin') ? 'admin' : 'sales_agent';
    const targetTopic = cleanRole === 'admin' ? 'admin_leads' : 'sales_agents';

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📲 [FCM REGISTRATION] User: "${name}" (ID: ${userId}, Role: ${cleanRole})`);
    console.log(`   ├─ Device: ${deviceName} [${platform}]`);
    console.log(`   ├─ Token Preview: ${token.substring(0, 24)}...`);

    // 1. Subscribe token to the relevant topic in Firebase Cloud Messaging
    let topicSubscribed = false;
    let topicError = null;
    if (admin && admin.apps && admin.apps.length > 0) {
      try {
        await withTimeout(admin.messaging().subscribeToTopic([token], targetTopic), 2500);
        topicSubscribed = true;
        console.log(`   ├─ Topic Subscription: ✅ Subscribed to '${targetTopic}'`);
      } catch (err) {
        topicError = err.message;
        console.warn(`   ├─ Topic Subscription: ⚠️ ${err.message}`);
      }
    } else {
      console.warn(`   ├─ Topic Subscription: ⚠️ Firebase Admin SDK not live. Local storage registration only.`);
    }

    // 2. Persist token in Firebase Realtime Database
    if (this.firebaseService) {
      await this.firebaseService.saveDeviceToken({
        userId: userId || `user_${Date.now()}`,
        token,
        role: cleanRole,
        name,
        deviceName,
        platform,
        updatedAt: new Date().toISOString(),
      });
      console.log(`   └─ Status: ✅ Registered in Multi-Device Map for user ${userId}`);
    }
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return {
      success: true,
      userId,
      role: cleanRole,
      topic: targetTopic,
      topicSubscribed,
      topicError,
    };
  }

  async getRegisteredTokens(role) {
    if (!this.firebaseService) return [];
    return await this.firebaseService.getDeviceTokens(role);
  }

  /**
   * 1. When a new lead is added by Admin (unassigned):
   * Dispatches notifications to ALL users (Admins & all Sales Agents) across ALL their logged-in devices.
   */
  async notifyNewLeadAddedByAdmin(lead, addedBy = 'Admin') {
    const timestamp = new Date().toISOString();
    const notifId = `notif_new_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const leadName = lead.name || 'New Lead';
    const propertyInterest = lead.propertyInterest || lead.campaign || 'General Inquiry';
    const budget = lead.budget || 'Flexible Budget';
    const phone = lead.phone || '';

    const notification = {
      id: notifId,
      type: 'NEW_LEAD_ALL_USERS',
      title: `🎯 New Lead Added: ${leadName}`,
      body: `${propertyInterest} • Budget: ${budget} • Added by ${addedBy}`,
      leadId: lead.id,
      leadName,
      leadPhone: phone,
      budget,
      source: lead.source || 'Admin Created',
      assignedTo: lead.assignedTo || 'Unassigned',
      targetRole: 'all',
      read: false,
      createdAt: timestamp,
    };

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`📢 [NOTIFICATION: NEW LEAD BROADCAST]`);
    console.log(`   ├─ Lead: "${leadName}" (ID: ${lead.id || 'N/A'}, Phone: ${phone})`);
    console.log(`   ├─ Added By: "${addedBy}" | Status: Unassigned (Alerting ALL Users)`);

    // 1. Save in Firebase Realtime Database
    if (this.firebaseService) {
      await this.firebaseService.saveNotification(notification);
      console.log(`   ├─ In-App Alert: 💾 Saved to database (ID: ${notification.id})`);
    }

    // 2. Push to all topics & all user device tokens
    const topicResults = {};
    let multicastResult = { totalTokens: 0, successCount: 0, failureCount: 0, errors: [] };

    if (!admin || !admin.apps || admin.apps.length === 0) {
      console.warn(`   ├─ FCM Push: ⚠️ Firebase Admin SDK is NOT initialized (Local mode active). Push not sent to Google FCM.`);
    } else {
      // 2a. Broadcast to FCM Topics
      const topics = ['all_leads', 'admin_leads', 'sales_agents'];
      for (const topic of topics) {
        try {
          const res = await withTimeout(
            admin.messaging().send({
              topic,
              notification: { title: notification.title, body: notification.body },
              data: { type: 'NEW_LEAD', leadId: String(lead.id || ''), role: 'all', click_action: 'FLUTTER_NOTIFICATION_CLICK' },
            }),
            2500
          );
          topicResults[topic] = { success: true, messageId: res };
          console.log(`   ├─ FCM Topic [${topic}]: ✅ SENT (Message ID: ${res})`);
        } catch (err) {
          topicResults[topic] = { success: false, error: err.message, code: err.code || 'UNKNOWN' };
          console.error(`   ├─ FCM Topic [${topic}]: ❌ FAILED (${err.code || 'ERR'}: ${err.message})`);
        }
      }

      // 2b. Direct Push to all registered device tokens across all users
      try {
        const allTokens = await this.getRegisteredTokens();
        multicastResult.totalTokens = allTokens.length;

        if (allTokens.length === 0) {
          console.warn(`   ├─ Direct Device Push: ⚠️ 0 registered device tokens found in database!`);
          console.info(`   │   ℹ️ No mobile devices have registered their FCM token yet. Tokens register automatically when users open the app.`);
        } else {
          console.log(`   ├─ Direct Device Push: Sending multicast to ${allTokens.length} active device token(s)...`);
          const directMessage = {
            notification: { title: notification.title, body: notification.body },
            data: { leadId: String(lead.id || ''), type: 'NEW_LEAD' },
            tokens: allTokens,
          };
          const res = await withTimeout(admin.messaging().sendEachForMulticast(directMessage), 3500);
          multicastResult.successCount = res.successCount || 0;
          multicastResult.failureCount = res.failureCount || 0;

          console.log(`   ├─ Direct Multicast Result: ${res.successCount} delivered, ${res.failureCount} failed`);
          if (res.responses) {
            res.responses.forEach((resp, i) => {
              const preview = allTokens[i] ? `${allTokens[i].substring(0, 16)}...` : `Device #${i + 1}`;
              if (resp.success) {
                console.log(`   │   ├─ ${preview}: ✅ DELIVERED (ID: ${resp.messageId})`);
              } else {
                const errDetail = `${resp.error?.code || 'UNKNOWN'}: ${resp.error?.message}`;
                multicastResult.errors.push({ tokenPreview: preview, error: errDetail });
                console.error(`   │   ├─ ${preview}: ❌ FAILED (${errDetail})`);
              }
            });
          }
        }
      } catch (err) {
        console.error(`   ├─ Direct Device Push Error: ❌ ${err.message}`);
        multicastResult.errors.push({ error: err.message });
      }
    }

    // 3. Log event into audit buffer
    if (this.firebaseService && this.firebaseService.logNotificationEvent) {
      this.firebaseService.logNotificationEvent({
        type: 'NEW_LEAD_BROADCAST',
        leadId: lead.id,
        leadName,
        addedBy,
        topicResults,
        multicastResult,
      });
    }

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return {
      success: true,
      notification,
      fcm: {
        topics: topicResults,
        multicast: multicastResult,
      },
    };
  }

  /**
   * 2. When Admin allots a lead to an executive:
   * Dispatches notification ONLY to that respective user, delivered to ALL devices where he is logged in!
   */
  async notifyLeadAllotment(lead, assignedTo, allottedBy = 'Admin') {
    if (!assignedTo) return { success: false, message: 'No assignee provided' };

    const timestamp = new Date().toISOString();
    const notifId = `notif_allot_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const leadName = lead.name || 'Assigned Lead';
    const propertyInterest = lead.propertyInterest || lead.campaign || 'Property Inquiry';
    const budget = lead.budget || 'Flexible Budget';

    const notification = {
      id: notifId,
      type: 'LEAD_ALLOTTED_TO_YOU',
      title: `⚡ Lead Allotted to You: ${leadName}`,
      body: `Allotted by ${allottedBy}. ${propertyInterest} • Budget: ${budget} • Tap to view & contact`,
      leadId: lead.id,
      leadName,
      leadPhone: lead.phone || '',
      budget,
      source: lead.source || 'Meta Ads',
      assignedTo,
      targetUserId: assignedTo,
      targetUserName: assignedTo,
      targetRole: 'sales_agent',
      read: false,
      createdAt: timestamp,
    };

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`🎯 [NOTIFICATION: TARGETED LEAD ALLOTMENT]`);
    console.log(`   ├─ Lead: "${leadName}" (ID: ${lead.id || 'N/A'})`);
    console.log(`   ├─ Allotted To: "${assignedTo}" | Allotted By: "${allottedBy}"`);

    // 1. Save in Firebase Realtime Database
    if (this.firebaseService) {
      await this.firebaseService.saveNotification(notification);
      console.log(`   ├─ In-App Alert: 💾 Saved to database for user "${assignedTo}" (ID: ${notification.id})`);
    }

    // 2. Look up ALL devices where THIS user is logged in
    let userTokens = [];
    if (this.firebaseService) {
      userTokens = await this.firebaseService.getUserDeviceTokens(assignedTo);
    }

    console.log(`   ├─ Device Lookup: Found ${userTokens.length} active device token(s) registered for "${assignedTo}"`);

    let devicesNotified = 0;
    const directErrors = [];
    let topicResult = null;

    if (!admin || !admin.apps || admin.apps.length === 0) {
      console.warn(`   ├─ FCM Push: ⚠️ Firebase Admin SDK is NOT initialized (Local mode active).`);
    } else {
      if (userTokens.length > 0) {
        try {
          const directMessage = {
            notification: { title: notification.title, body: notification.body },
            data: {
              type: 'LEAD_ALLOTTED',
              leadId: String(lead.id || ''),
              assignedTo: String(assignedTo),
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            tokens: userTokens,
          };
          const res = await withTimeout(admin.messaging().sendEachForMulticast(directMessage), 3500);
          devicesNotified = res.successCount || 0;
          console.log(`   ├─ Direct Multicast: ${res.successCount} delivered, ${res.failureCount} failed`);

          if (res.responses) {
            res.responses.forEach((resp, i) => {
              const preview = userTokens[i] ? `${userTokens[i].substring(0, 16)}...` : `Device #${i + 1}`;
              if (resp.success) {
                console.log(`   │   ├─ ${preview} [${assignedTo}]: ✅ DELIVERED (ID: ${resp.messageId})`);
              } else {
                const errDetail = `${resp.error?.code || 'UNKNOWN'}: ${resp.error?.message}`;
                directErrors.push({ tokenPreview: preview, error: errDetail });
                console.error(`   │   ├─ ${preview} [${assignedTo}]: ❌ FAILED (${errDetail})`);
              }
            });
          }
        } catch (err) {
          console.error(`   ├─ Targeted Device Push Error: ❌ ${err.message}`);
          directErrors.push({ error: err.message });
        }
      } else {
        console.warn(`   ├─ Direct Device Push: ⚠️ User "${assignedTo}" has NO registered device tokens!`);
        console.info(`   │   ℹ️ When "${assignedTo}" logs into the app, their device token will be added to the registry.`);
      }

      // Also dispatch to user-specific topic (e.g. user_amit_patil)
      const cleanUserTopic = `user_${assignedTo.replace(/[^a-zA-Z0-9]/g, '_').toLowerCase()}`;
      try {
        const topicRes = await withTimeout(
          admin.messaging().send({
            topic: cleanUserTopic,
            notification: { title: notification.title, body: notification.body },
            data: { type: 'LEAD_ALLOTTED', leadId: String(lead.id || ''), assignedTo: String(assignedTo) },
          }),
          2500
        );
        topicResult = { success: true, messageId: topicRes };
        console.log(`   ├─ User Topic [${cleanUserTopic}]: ✅ SENT (Message ID: ${topicRes})`);
      } catch (err) {
        topicResult = { success: false, error: err.message };
        console.log(`   ├─ User Topic [${cleanUserTopic}]: ℹ️ Note: ${err.message}`);
      }
    }

    // 3. Log event into audit buffer
    if (this.firebaseService && this.firebaseService.logNotificationEvent) {
      this.firebaseService.logNotificationEvent({
        type: 'LEAD_ALLOTTED',
        leadId: lead.id,
        leadName,
        assignedTo,
        allottedBy,
        deviceTokensFound: userTokens.length,
        devicesNotified,
        errors: directErrors,
        topicResult,
      });
    }

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return {
      success: true,
      notification,
      targetUser: assignedTo,
      deviceTokensFound: userTokens.length,
      devicesNotified,
      directErrors,
      topicResult,
    };
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
