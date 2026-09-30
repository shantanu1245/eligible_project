const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');

// GET /api/notifications - List notifications
router.get('/', notificationController.getNotifications);

// PATCH /api/notifications/:id/read - Mark one as read
router.patch('/:id/read', notificationController.markAsRead);

// POST /api/notifications/read-all - Mark all as read
router.post('/read-all', notificationController.markAllRead);

// POST /api/notifications/register-token - Register device FCM token
router.post('/register-token', notificationController.registerToken);

// POST /api/notifications/test - Trigger test notification for Admin/Sales Agents
router.post('/test', notificationController.sendTest);

// GET /api/notifications/logs - Live notification audit log
router.get('/logs', notificationController.getNotificationLogs);

// GET /api/notifications/devices - View registered devices
router.get('/devices', notificationController.getRegisteredDevices);

module.exports = router;
