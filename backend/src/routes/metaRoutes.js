const express = require('express');
const router = express.Router();
const metaController = require('../controllers/metaController');

// Status & active configuration
router.get('/status', metaController.getStatus);
router.get('/config', metaController.getConfig);
router.post('/config', metaController.saveConfig);

// Token Discovery & Connection
router.post('/discover', metaController.discover);
router.post('/test-connection', metaController.testConnection);
router.get('/lead-forms', metaController.getLeadForms);

module.exports = router;
