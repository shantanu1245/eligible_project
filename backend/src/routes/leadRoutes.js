const express = require('express');
const router = express.Router();
const leadController = require('../controllers/leadController');

// Leads CRUD
router.get('/', leadController.getLeads);
router.post('/', leadController.createLead);
router.get('/:id', leadController.getLeadById);
router.patch('/:id', leadController.updateLead);
router.post('/:id/allot', leadController.allotLead);

// Manual Sync from Meta Lead Forms to Firebase
router.post('/sync', leadController.syncMetaLeads);

module.exports = router;
