const express = require('express');
const router = express.Router();
const { pool } = require('../database');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// GET /api/users/search?q=username
router.get('/search', async (req, res) => {
  try {
    const q = (req.query.q || '').trim();
    if (!q || q.length < 2) {
      return res.json({ users: [] });
    }
    const [users] = await pool.execute(
      `SELECT id, username, public_key
       FROM users
       WHERE username LIKE ? AND id != ?
       ORDER BY username ASC
       LIMIT 20`,
      [`%${q}%`, req.userId]
    );
    res.json({ users });
  } catch (err) {
    console.error('[Users] Search error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/users/:id/public-key  — get a user's current public key
router.get('/:id/public-key', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT public_key FROM users WHERE id = ?',
      [req.params.id]
    );
    if (!rows.length) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ publicKey: rows[0].public_key });
  } catch (err) {
    console.error('[Users] Public key fetch error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
