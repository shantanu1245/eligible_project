const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const config = require('./config/config');
const routes = require('./routes');
const errorHandler = require('./middlewares/errorHandler');
const firebaseService = require('./services/firebase');
const metaService = require('./services/metaService');
const keepAliveService = require('./services/keepAliveService');

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
  console.log(`🔍 Meta Diagnostics:  http://localhost:${config.port}/api/meta/diagnostics`);
  console.log(`📥 Meta Webhook URL:  http://localhost:${config.port}/api/webhooks/meta`);
  console.log(`🔔 Notifications:     http://localhost:${config.port}/api/notifications`);
  console.log('--- Meta Credentials Status ---');
  console.log(`   App ID:            ${config.meta.appId ? '✅ Configured' : '⚠️ Missing (Set in .env)'}`);
  console.log(`   App Secret:        ${config.meta.appSecret ? '✅ Configured' : '⚠️ Missing (Set in .env)'}`);
  console.log(`   Access Token:      ${config.meta.accessToken ? '✅ Configured' : '⚠️ Missing (Set in .env)'}`);
  console.log(`   API Version:       ${config.meta.apiVersion}`);
  console.log(`   Verify Token:      ${config.meta.webhookVerifyToken ? '✅ Configured' : '⚠️ Missing'}`);
  console.log('======================================================\n');

  // Load dynamically saved Meta credentials from Firebase Realtime Database only if not already set in .env
  if (!config.meta.accessToken) {
    firebaseService.getMetaConfig().then((saved) => {
      if (saved && saved.accessToken) {
        metaService.setCredentials(saved);
        console.log('✨ [Bootstrap] Loaded dynamic Meta credentials from Firebase Realtime Database.');
      }
    }).catch((err) => {
      console.warn('Could not load dynamic Meta credentials:', err.message);
    });
  } else {
    console.log('🔒 [Bootstrap] Prioritizing environment variables (.env) for Meta credentials.');
  }

  // Setup Real-time Firebase RTDB listener for incoming leads
  const serverStartTime = Date.now();
  const rtdb = firebaseService.getRtdb();
  if (rtdb) {
    const notificationService = require('./services/notificationService');
    const processedLeadIds = new Set();
    let initialSyncComplete = false;

    // Snapshot existing historical leads on startup so we don't alert for old data
    rtdb.ref(config.firebase.paths.leads).limitToLast(20).once('value')
      .then((snapshot) => {
        if (snapshot.exists()) {
          snapshot.forEach((child) => {
            const l = child.val();
            if (l && l.id) processedLeadIds.add(l.id);
            processedLeadIds.add(child.key);
          });
        }
        initialSyncComplete = true;
      })
      .catch((err) => {
        console.warn('⚠️ [Realtime Listener] Pre-sync note:', err.message);
        initialSyncComplete = true;
      });

    // Real-time child_added listener for all new incoming leads
    rtdb.ref(config.firebase.paths.leads).limitToLast(10).on('child_added', (snapshot) => {
      const lead = snapshot.val();
      if (!lead) return;
      const leadId = lead.id || snapshot.key;
      if (processedLeadIds.has(leadId)) return;
      processedLeadIds.add(leadId);

      // If initial historical sync is complete, this is a fresh real-time lead
      const leadCreatedAt = lead.createdAt ? new Date(lead.createdAt).getTime() : 0;
      const isFresh = initialSyncComplete || (!isNaN(leadCreatedAt) && leadCreatedAt >= serverStartTime - 5000);

      if (isFresh) {
        console.log(`📡 [Realtime DB Event] New lead detected in Firebase RTDB: ${lead.name || leadId}`);
        notificationService.notifyNewLead({ ...lead, id: leadId }).catch((err) => {
          console.warn('⚠️ Realtime lead alert note:', err.message);
        });
      }
    });
    console.log('🔔 [Realtime Listener] Active for incoming leads in Firebase Realtime Database.');
  }

  // Start Live Server Keep-Alive Pinger to keep Render instance awake
  keepAliveService.start();
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nGracefully shutting down backend server...');
  keepAliveService.stop();
  server.close(() => {
    console.log('Backend server closed.');
    process.exit(0);
  });
});

module.exports = app;
