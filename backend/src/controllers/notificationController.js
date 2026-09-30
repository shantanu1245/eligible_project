const firebaseService = require('../services/firebase');
const notificationService = require('../services/notificationService');

const NotificationController = {
  /**
   * GET /api/notifications
   * Returns list of notifications, optionally filtered by role
   */
  async getNotifications(req, res) {
    try {
      const { role, limit = 50, leadId } = req.query;
      const notifications = await firebaseService.getNotifications({
        role,
        limit: parseInt(limit, 10) || 50,
        leadId,
      });

      const unreadCount = notifications.filter((n) => !n.read).length;

      res.json({
        success: true,
        count: notifications.length,
        unreadCount,
        data: notifications,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * PATCH /api/notifications/:id/read
   * Mark a single notification as read
   */
  async markAsRead(req, res) {
    try {
      const { id } = req.params;
      await firebaseService.markNotificationRead(id);
      res.json({ success: true, message: 'Notification marked as read', id });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/notifications/read-all
   * Mark all notifications as read (optionally for a specific role)
   */
  async markAllRead(req, res) {
    try {
      const { role } = req.body;
      await firebaseService.markAllNotificationsRead(role);
      res.json({ success: true, message: 'All notifications marked as read' });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/notifications/register-token
   * Register a user's FCM device token and subscribe to role topic
   */
  async registerToken(req, res) {
    try {
      const { userId, token, role = 'sales_agent', name = 'App User' } = req.body;

      if (!token) {
        return res.status(400).json({
          success: false,
          error: 'token field is required',
        });
      }

      const result = await notificationService.registerToken({
        userId,
        token,
        role,
        name,
      });

      res.json({
        success: true,
        message: `Device token registered and subscribed to '${result.topic}'`,
        data: result,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },

  /**
   * POST /api/notifications/test
   * Trigger a test notification to verify setup for Admin & Sales Agents
   */
  async sendTest(req, res) {
    try {
      const { role, customTitle, customBody } = req.body;
      const result = await notificationService.sendTestNotification({
        role,
        customTitle,
        customBody,
      });

      res.json({
        success: true,
        message: 'Test notification triggered for Admin and Sales Agents',
        data: result,
      });
    } catch (err) {
      res.status(500).json({ success: false, error: err.message });
    }
  },
};

module.exports = NotificationController;
