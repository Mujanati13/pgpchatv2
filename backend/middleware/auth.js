const jwt = require('jsonwebtoken');
const config = require('../config');
const { pool } = require('../database');

async function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid token' });
  }

  const token = authHeader.slice(7);
  try {
    const payload = jwt.verify(token, config.jwt.secret);
    req.userId = payload.userId;
    req.sessionId = payload.sessionId;

    // Verify session still exists
    const [rows] = await pool.execute(
      'SELECT id FROM sessions WHERE id = ? AND user_id = ?',
      [payload.sessionId, payload.userId]
    );
    if (rows.length === 0) {
      return res.status(401).json({ error: 'Session expired or revoked' });
    }

    // Update last_active
    await pool.execute(
      'UPDATE sessions SET last_active = NOW() WHERE id = ?',
      [payload.sessionId]
    );

    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

module.exports = { authenticate };
