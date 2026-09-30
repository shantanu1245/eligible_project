const express = require('express');
const router = express.Router();
const firebaseService = require('../services/firebase');

router.get('/', async (req, res) => {
  try {
    const tasks = await firebaseService.getTasks(req.query.status || 'All');
    res.json({ success: true, count: tasks.length, data: tasks });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const task = await firebaseService.saveTask(req.body);
    res.status(201).json({ success: true, data: task });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

router.patch('/:id', async (req, res) => {
  try {
    const updated = await firebaseService.updateTask(req.params.id, req.body);
    if (!updated) return res.status(404).json({ success: false, message: 'Task not found' });
    res.json({ success: true, data: updated });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;
