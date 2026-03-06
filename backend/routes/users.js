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

module.exports = router;
