const express = require('express');
const router = express.Router();
const { pool } = require('../database');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// PUT /api/sessions/push-token  — register/unregister push token for current session
router.put('/push-token', async (req, res) => {
  try {
    const { token, platform } = req.body;

    await pool.execute(
      'UPDATE sessions SET push_token = ?, push_platform = ? WHERE id = ? AND user_id = ?',
      [token || null, platform || null, req.sessionId, req.userId]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('[Sessions] Push token update error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/sessions  — list all sessions for current user
router.get('/', async (req, res) => {
  try {
    const [sessions] = await pool.execute(
      `SELECT id, device_name, device_type, last_active, created_at
       FROM sessions
       WHERE user_id = ?
       ORDER BY last_active DESC`,
      [req.userId]
    );

    const result = sessions.map((s) => ({
      ...s,
      isCurrent: s.id === req.sessionId,
    }));

    res.json({ sessions: result });
  } catch (err) {
    console.error('[Sessions] List error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/sessions/:sessionId  — logout/terminate a specific session
router.delete('/:sessionId', async (req, res) => {
  try {
    const [result] = await pool.execute(
      'DELETE FROM sessions WHERE id = ? AND user_id = ?',
      [req.params.sessionId, req.userId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }
    res.json({ success: true });
  } catch (err) {
    console.error('[Sessions] Delete error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/sessions  — terminate ALL sessions except current
router.delete('/', async (req, res) => {
  try {
    await pool.execute(
      'DELETE FROM sessions WHERE user_id = ? AND id != ?',
      [req.userId, req.sessionId]
    );
    res.json({ success: true, message: 'All sessions terminated' });
  } catch (err) {
    console.error('[Sessions] Terminate all error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
