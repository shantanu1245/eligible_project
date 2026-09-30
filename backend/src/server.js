const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const config = require('./config/config');
const routes = require('./routes');
const errorHandler = require('./middlewares/errorHandler');
const firebaseService = require('./services/firebase');
const metaService = require('./services/metaService');

const app = express();
app.set('trust proxy', 1);

// Security and Logging middlewares
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: '*' })); // Allow Flutter web, mobile emulators, and local origins
app.use(morgan('dev'));

// JSON parser with rawBody preservation for Meta HMAC verification
app.use(
  express.json({
    verify: (req, res, buf) => {
      req.rawBody = buf;
    },
  })
);
app.use(express.urlencoded({ extended: true }));

// Root welcome endpoint
app.get('/', (req, res) => {
  res.json({
    name: 'Eligible CRM Backend API',
    description: 'Bridge for Meta Ads (Marketing API, Lead Webhooks) and Firebase Cloud Firestore',
    version: '1.0.0',
    documentation: '/api/health',
    endpoints: {
      health: 'GET /api/health',
      integration_status: 'GET /api/meta/status',
      meta_webhook: 'GET & POST /api/webhooks/meta',
      webhook_logs: 'GET /api/webhooks/logs',
      leads: 'GET & POST /api/leads',
      lead_sync: 'POST /api/leads/sync',
      campaigns: 'GET & POST /api/campaigns',
      lead_forms: 'GET /api/meta/lead-forms',
    },
  });
});

// API Routes
app.use('/api', routes);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

// Error handling middleware
app.use(errorHandler);

// Start Server
const server = app.listen(config.port, () => {
  console.log('\n======================================================');
  console.log(`🚀 ELIGIBLE CRM BACKEND RUNNING ON PORT ${config.port}`);
  console.log(`🌐 Base URL:          http://localhost:${config.port}`);
  console.log(`📡 Health Check:      http://localhost:${config.port}/api/health`);
  console.log(`🔗 Meta Status:       http://localhost:${config.port}/api/meta/status`);
  console.log(`📥 Meta Webhook URL:  http://localhost:${config.port}/api/webhooks/meta`);
  console.log(`🔑 Webhook Verify:    "${config.meta.webhookVerifyToken}"`);
  console.log('======================================================\n');

  // Load dynamically saved Meta credentials from Firebase Realtime Database
  firebaseService.getMetaConfig().then((saved) => {
    if (saved && saved.accessToken) {
      metaService.setCredentials(saved);
      console.log('✨ [Bootstrap] Loaded dynamic Meta credentials from Firebase Realtime Database.');
    }
  }).catch((err) => {
    console.warn('Could not load dynamic Meta credentials:', err.message);
  });
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nGracefully shutting down backend server...');
  server.close(() => {
    console.log('Backend server closed.');
    process.exit(0);
  });
});

module.exports = app;
