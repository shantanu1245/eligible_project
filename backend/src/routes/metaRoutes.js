const express = require('express');
const router = express.Router();
const metaController = require('../controllers/metaController');

// Status, Diagnostics, and Active Configuration
router.get('/status', metaController.getStatus);
router.get('/diagnostics', metaController.getDiagnostics);
router.get('/config', metaController.getConfig);
router.post('/config', metaController.saveConfig);

// Token Discovery & Connection
router.post('/discover', metaController.discover);
router.post('/test-connection', metaController.testConnection);
router.post('/extend-token', metaController.extendToken);
router.get('/lead-forms', metaController.getLeadForms);

// Meta Marketing API Assets (Ad Accounts, Campaigns, Ad Sets, Ads)
router.get('/accounts', metaController.getAccounts);
router.get('/campaigns', metaController.getCampaigns);
router.get('/adsets', metaController.getAdSets);
router.get('/ads', metaController.getAds);

// Performance Insights & Reporting
router.get('/insights', metaController.getInsights);
router.get('/sync-status', metaController.getSyncStatus);
router.post('/clear-cache', metaController.clearCache);

module.exports = router;
