const express = require('express');
const router = express.Router();
const firebaseService = require('../services/firebase');

router.get('/', async (req, res) => {
  try {
    const team = await firebaseService.getTeam();
    res.json({ success: true, count: team.length, data: team });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const member = await firebaseService.saveTeamMember(req.body);
    res.status(201).json({ success: true, data: member });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const success = await firebaseService.deleteTeamMember(req.params.id);
    if (!success) return res.status(404).json({ success: false, message: 'Member not found' });
    res.json({ success: true, message: 'Team member removed' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
