const express = require('express');
const router = express.Router();
const leadController = require('../controllers/leadController');

// Leads CRUD
router.get('/', leadController.getLeads);
router.post('/', leadController.createLead);
router.post('/bulk-allot', leadController.bulkAllotLeads);
router.post('/bulk-delete', leadController.deleteLeadsBulk);
router.post('/delete-by-category', leadController.deleteLeadsByCategory);

// Recycle Bin routes (registered before /:id to prevent wildcard collision)
router.get('/bin', leadController.getBinLeads);
router.post('/bin/:id/restore', leadController.restoreLead);
router.delete('/bin/:id', leadController.permanentDeleteLead);
router.delete('/bin', leadController.emptyBin);

router.get('/:id', leadController.getLeadById);
router.patch('/:id', leadController.updateLead);
router.patch('/:id/status', leadController.updateLeadStatus);
router.delete('/:id', leadController.deleteLead);
router.post('/:id/allot', leadController.allotLead);

// Manual Sync from Meta Lead Forms to Firebase
router.post('/sync', leadController.syncMetaLeads);

module.exports = router;
