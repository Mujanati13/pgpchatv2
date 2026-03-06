const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const config = require('../config');
const { pool } = require('../database');
const { authenticate } = require('../middleware/auth');

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const { username, password, publicKey, deviceName, deviceType } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'username and password required' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    const userId = uuidv4();
    const passwordHash = await bcrypt.hash(password, 12);

    await pool.execute(
      'INSERT INTO users (id, username, password_hash, public_key) VALUES (?, ?, ?, ?)',
      [userId, username, passwordHash, publicKey || null]
    );

    // Create default settings (auto-delete ON, contacts OFF)
    await pool.execute(
      'INSERT INTO user_settings (user_id, auto_delete_enabled, auto_delete_hours, contacts_enabled) VALUES (?, 1, 24, 0)',
      [userId]
    );

    // Create session
    const sessionId = uuidv4();
    const token = jwt.sign({ userId, sessionId }, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn,
    });
    const tokenHash = await bcrypt.hash(token.slice(-20), 10);

    await pool.execute(
      'INSERT INTO sessions (id, user_id, device_name, device_type, token_hash) VALUES (?, ?, ?, ?, ?)',
      [sessionId, userId, deviceName || 'Unknown Device', deviceType || 'unknown', tokenHash]
    );

    res.status(201).json({
      userId,
      token,
      sessionId,
    });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Username already taken' });
    }
    console.error('[Auth] Register error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { username, password, deviceName, deviceType } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'username and password required' });
    }

    const [users] = await pool.execute(
      'SELECT id, password_hash, public_key FROM users WHERE username = ?',
      [username]
    );
    if (users.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = users[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const sessionId = uuidv4();
    const token = jwt.sign({ userId: user.id, sessionId }, config.jwt.secret, {
      expiresIn: config.jwt.expiresIn,
    });
    const tokenHash = await bcrypt.hash(token.slice(-20), 10);

    await pool.execute(
      'INSERT INTO sessions (id, user_id, device_name, device_type, token_hash) VALUES (?, ?, ?, ?, ?)',
      [sessionId, user.id, deviceName || 'Unknown Device', deviceType || 'unknown', tokenHash]
    );

    res.json({
      userId: user.id,
      token,
      sessionId,
      publicKey: user.public_key,
    });
  } catch (err) {
    console.error('[Auth] Login error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/auth/logout  — logout current session
router.post('/logout', authenticate, async (req, res) => {
  try {
    await pool.execute('DELETE FROM sessions WHERE id = ?', [req.sessionId]);
    res.json({ success: true });
  } catch (err) {
    console.error('[Auth] Logout error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /api/auth/public-key  — update user's public key
router.put('/public-key', authenticate, async (req, res) => {
  try {
    const { publicKey } = req.body;
    if (!publicKey) {
      return res.status(400).json({ error: 'publicKey required' });
    }
    await pool.execute('UPDATE users SET public_key = ? WHERE id = ?', [
      publicKey,
      req.userId,
    ]);
    res.json({ success: true });
  } catch (err) {
    console.error('[Auth] Public key update error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/auth/reset-pgp  — PGP reset protocol: wipe chats, contacts, keys
router.post('/reset-pgp', authenticate, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // 1. Wipe all chat history
    await conn.execute(
      'DELETE FROM messages WHERE sender_id = ? OR recipient_id = ?',
      [req.userId, req.userId]
    );

    // 2. Wipe all contact data
    await conn.execute('DELETE FROM contacts WHERE owner_id = ?', [req.userId]);

    // 3. Remove old PGP key
    await conn.execute('UPDATE users SET public_key = NULL WHERE id = ?', [
      req.userId,
    ]);

    await conn.commit();
    res.json({ success: true, message: 'PGP reset complete. Generate a new key pair now.' });
  } catch (err) {
    await conn.rollback();
    console.error('[Auth] PGP reset error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    conn.release();
  }
});

module.exports = router;
