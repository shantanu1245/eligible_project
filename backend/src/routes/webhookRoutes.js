const express = require('express');
const router = express.Router();
const webhookController = require('../controllers/webhookController');

// Meta Webhook Verification (Handshake)
router.get('/meta', webhookController.verifyWebhook);

// Meta Real-time Event Receiver
router.post('/meta', webhookController.handleWebhook);

// Webhook Audit Logs
router.get('/logs', webhookController.getLogs);

module.exports = router;
