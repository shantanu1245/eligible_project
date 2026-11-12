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

router.patch('/:id', async (req, res) => {
  try {
    const member = await firebaseService.updateTeamMember(req.params.id, req.body);
    if (!member) return res.status(404).json({ success: false, message: 'Member not found' });
    res.json({ success: true, data: member });
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

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password are required' });
    }
    const cleanEmail = email.trim().toLowerCase();
    const cleanPass = password.trim();

    // Check administrator
    if (cleanEmail === 'admin@theligible.in' && cleanPass === 'eligible@098') {
      return res.json({
        success: true,
        user: {
          id: 'U-001',
          name: 'Admin',
          email: 'admin@theligible.in',
          role: 'Administrator',
          initial: 'A',
        },
      });
    }

    // Check registered team members / agents
    const team = await firebaseService.getTeam();
    const match = team.find(
      (m) =>
        m.email &&
        m.email.trim().toLowerCase() === cleanEmail &&
        m.password &&
        m.password.trim() === cleanPass
    );

    if (match) {
      return res.json({
        success: true,
        user: {
          id: match.id || `user_${Date.now()}`,
          name: match.name,
          email: match.email,
          role: match.role || 'Sales Executive',
          initial: match.initial || (match.name ? match.name[0].toUpperCase() : 'A'),
        },
      });
    }

    return res.status(401).json({ success: false, message: 'Invalid email or password' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
