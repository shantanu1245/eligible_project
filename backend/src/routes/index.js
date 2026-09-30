const express = require('express');
const router = express.Router();

const webhookRoutes = require('./webhookRoutes');
const leadRoutes = require('./leadRoutes');
const campaignRoutes = require('./campaignRoutes');
const metaRoutes = require('./metaRoutes');
const taskRoutes = require('./taskRoutes');
const teamRoutes = require('./teamRoutes');
const notificationRoutes = require('./notificationRoutes');
const firebaseService = require('../services/firebase');

// Root health check
router.get('/health', (req, res) => {
  res.json({
    status: 'online',
    service: 'Eligible CRM Backend',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

// Seed all dummy data to Firebase Realtime Database
router.post('/seed', async (req, res) => {
  try {
    const result = await firebaseService.seedAllDummyData();
    res.json(result);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Sub-routers
router.use('/webhooks', webhookRoutes);
router.use('/leads', leadRoutes);
router.use('/campaigns', campaignRoutes);
router.use('/meta', metaRoutes);
router.use('/tasks', taskRoutes);
router.use('/team', teamRoutes);
router.use('/notifications', notificationRoutes);

module.exports = router;
