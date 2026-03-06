const express = require('express');
const router = express.Router();
const { pool } = require('../database');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// GET /api/settings
router.get('/', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT * FROM user_settings WHERE user_id = ?',
      [req.userId]
    );
    if (rows.length === 0) {
      // Create default settings
      await pool.execute(
        'INSERT INTO user_settings (user_id, auto_delete_enabled, auto_delete_hours, contacts_enabled) VALUES (?, 1, 24, 0)',
        [req.userId]
      );
      return res.json({
        autoDeleteEnabled: true,
        autoDeleteHours: 24,
        contactsEnabled: false,
      });
    }
    const s = rows[0];
    res.json({
      autoDeleteEnabled: !!s.auto_delete_enabled,
      autoDeleteHours: s.auto_delete_hours,
      contactsEnabled: !!s.contacts_enabled,
    });
  } catch (err) {
    console.error('[Settings] Get error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /api/settings
router.put('/', async (req, res) => {
  try {
    const { autoDeleteEnabled, autoDeleteHours, contactsEnabled } = req.body;

    await pool.execute(
      `INSERT INTO user_settings (user_id, auto_delete_enabled, auto_delete_hours, contacts_enabled)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         auto_delete_enabled = VALUES(auto_delete_enabled),
         auto_delete_hours = VALUES(auto_delete_hours),
         contacts_enabled = VALUES(contacts_enabled)`,
      [
        req.userId,
        autoDeleteEnabled ? 1 : 0,
        autoDeleteHours || 24,
        contactsEnabled ? 1 : 0,
      ]
    );

    res.json({ success: true });
  } catch (err) {
    console.error('[Settings] Update error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/settings/auto-delete-now  — immediately delete old messages
router.post('/auto-delete-now', async (req, res) => {
  try {
    const { hours } = req.body;
    const deleteHours = hours || 24;
    const [result] = await pool.execute(
      `DELETE FROM messages
       WHERE (sender_id = ? OR recipient_id = ?)
       AND created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)`,
      [req.userId, req.userId, deleteHours]
    );
    res.json({ success: true, deletedCount: result.affectedRows });
  } catch (err) {
    console.error('[Settings] Auto-delete now error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
