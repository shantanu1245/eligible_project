const express = require('express');
const router = express.Router();
const campaignController = require('../controllers/campaignController');

// Campaigns endpoints
router.get('/', campaignController.getCampaigns);
router.post('/', campaignController.createCampaign);
router.patch('/:id/status', campaignController.toggleCampaignStatus);

module.exports = router;
