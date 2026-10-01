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
const keepAliveService = require('../services/keepAliveService');

// Root health check
router.get('/health', (req, res) => {
  res.json({
    status: 'online',
    service: 'Eligible CRM Backend',
    timestamp: new Date().toISOString(),
    uptime: Math.round(process.uptime()),
    version: '1.0.0',
  });
});

// Fast ping endpoint for keep-alive bots and heartbeat
router.get('/ping', (req, res) => {
  res.json({
    status: 'awake',
    service: 'Eligible CRM Render Service',
    message: 'Instance kept active and awake',
    uptimeSeconds: Math.round(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

// Keep-alive status & history
router.get('/keep-alive', (req, res) => {
  res.json({
    success: true,
    data: keepAliveService.getStatus(),
  });
});

// Manual trigger for keep-alive ping
router.post('/keep-alive/ping', async (req, res) => {
  const result = await keepAliveService.ping();
  res.json({
    success: true,
    message: 'Manual keep-alive ping executed',
    data: result,
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
