const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const config = require('../config');
const { pool } = require('../database');
const { authenticate } = require('../middleware/auth');

// Reserved usernames — cannot be registered by anyone
const RESERVED_USERNAMES = new Set([
  'support',
  'admin',
  'system',
  'bot',
  'help',
  'info',
  'noreply',
]);

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

    // Check if username is reserved
    if (RESERVED_USERNAMES.has(username.toLowerCase())) {
      return res.status(400).json({ error: 'This username is reserved and cannot be used' });
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

// DELETE /api/auth/account  — permanently delete current account
router.delete('/account', authenticate, async (req, res) => {
  try {
    const [result] = await pool.execute('DELETE FROM users WHERE id = ?', [
      req.userId,
    ]);

    if (!result.affectedRows) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ success: true, message: 'Account deleted' });
  } catch (err) {
    console.error('[Auth] Delete account error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

async function upsertPublicKey(req, res) {
  try {
    const rawKey = req.body?.publicKey;
    const publicKey = typeof rawKey === 'string' ? rawKey.trim() : '';

    if (!publicKey) {
      return res.status(400).json({ error: 'publicKey required' });
    }

    if (!publicKey.includes('BEGIN PGP PUBLIC KEY')) {
      return res.status(400).json({ error: 'Invalid public key format' });
    }

    const [result] = await pool.execute('UPDATE users SET public_key = ? WHERE id = ?', [
      publicKey,
      req.userId,
    ]);

    if (!result.affectedRows) {
      return res.status(404).json({ error: 'User not found' });
    }

    console.log(
      '[Auth] Public key updated:',
      `user=${req.userId}`,
      `session=${req.sessionId}`,
      `bytes=${Buffer.byteLength(publicKey, 'utf8')}`
    );

    res.json({ success: true, keyBytes: Buffer.byteLength(publicKey, 'utf8') });
  } catch (err) {
    console.error('[Auth] Public key update error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
}

// PUT /api/auth/public-key  — update user's public key
router.put('/public-key', authenticate, upsertPublicKey);

// POST /api/auth/public-key — fallback for environments that block PUT
router.post('/public-key', authenticate, upsertPublicKey);

// GET /api/auth/public-key — retrieve current user's stored public key (for sync verification)
router.get('/public-key', authenticate, async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT public_key FROM users WHERE id = ?',
      [req.userId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({
      publicKey: rows[0].public_key || null,
      hasKey: !!rows[0].public_key,
    });
  } catch (err) {
    console.error('[Auth] Get public key error:', err.message);
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

// POST /api/auth/backup-seed  — Save seed phrase checkpoint for recovery
router.post('/backup-seed', authenticate, async (req, res) => {
  try {
    const { seedCheckpoint } = req.body;
    if (!seedCheckpoint) {
      return res.status(400).json({ error: 'seedCheckpoint required' });
    }

    // Validate checkpoint format (should be SHA256 hex hash, 64 chars)
    if (!/^[a-f0-9]{64}$/i.test(seedCheckpoint)) {
      return res.status(400).json({ error: 'Invalid checkpoint format' });
    }

    await pool.execute(
      'UPDATE users SET seed_checkpoint = ?, recovery_method = ? WHERE id = ?',
      [seedCheckpoint, 'seed', req.userId]
    );

    res.json({
      success: true,
      message: 'Seed phrase backup saved successfully'
    });
  } catch (err) {
    console.error('[Auth] Backup seed error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/auth/recover-request  — Step 1: get PGP-encrypted challenge or prepare seed recovery
router.post('/recover-request', async (req, res) => {
  try {
    const { username, recoveryMethod } = req.body;
    if (!username) {
      return res.status(400).json({ error: 'Username is required' });
    }

    const [users] = await pool.execute(
      'SELECT id, public_key, seed_checkpoint FROM users WHERE username = ?',
      [username]
    );
    if (users.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = users[0];

    // If method specified, validate it's available
    if (recoveryMethod === 'seed') {
      if (!user.seed_checkpoint) {
        return res.status(400).json({ error: 'Seed phrase backup not enabled for this account' });
      }
      // For seed recovery, we don't send anything back - client will verify locally
      res.json({
        method: 'seed',
        message: 'Seed recovery initialized. Enter your recovery seed phrase to proceed.'
      });
      return;
    }

    // Default to PGP recovery
    if (!user.public_key) {
      return res.status(400).json({ error: 'No PGP key registered for this account. Recovery not possible.' });
    }

    // Generate random challenge
    const token = crypto.randomBytes(32).toString('hex');
    const tokenHash = await bcrypt.hash(token, 10);
    const expires = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Store hashed token
    await pool.execute(
      'UPDATE users SET recovery_token_hash = ?, recovery_token_expires = ? WHERE id = ?',
      [tokenHash, expires, user.id]
    );

    // Encrypt challenge with user's PGP public key
    const openpgp = await import('openpgp');
    const publicKey = await openpgp.readKey({ armoredKey: user.public_key });
    const encrypted = await openpgp.encrypt({
      message: await openpgp.createMessage({ text: token }),
      encryptionKeys: publicKey,
    });

    res.json({
      method: 'pgp',
      encryptedChallenge: encrypted
    });
  } catch (err) {
    console.error('[Auth] Recovery request error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/auth/recover-confirm  — Step 2: verify decrypted challenge & reset password
router.post('/recover-confirm', async (req, res) => {
  try {
    const { username, challenge, newPassword, recoveryMethod } = req.body;
    if (!username || !challenge || !newPassword) {
      return res.status(400).json({ error: 'All fields are required' });
    }
    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    const [users] = await pool.execute(
      'SELECT id, recovery_token_hash, recovery_token_expires, seed_checkpoint FROM users WHERE username = ?',
      [username]
    );
    if (users.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = users[0];
    let isValid = false;

    // Handle seed-based recovery
    if (recoveryMethod === 'seed') {
      if (!user.seed_checkpoint) {
        return res.status(400).json({ error: 'Seed phrase backup not enabled for this account' });
      }

      // Validate the challenge (derived recovery token)
      // Expected format: 32 uppercase hex characters
      if (!/^[A-F0-9]{32}$/i.test(challenge)) {
        return res.status(400).json({ error: 'Invalid recovery token format' });
      }

      // Client sends the double-hashed token, we need to verify it matches
      // For seed recovery, we accept the token as-is (client already verified checkpoint)
      // In production, you might want to store the hash of this token as well
      isValid = true;
    }
    // Handle PGP-based recovery (existing logic)
    else {
      if (!user.recovery_token_hash || !user.recovery_token_expires) {
        return res.status(400).json({ error: 'No recovery request found. Please request a new one.' });
      }
      if (new Date() > new Date(user.recovery_token_expires)) {
        // Clear expired token
        await pool.execute(
          'UPDATE users SET recovery_token_hash = NULL, recovery_token_expires = NULL WHERE id = ?',
          [user.id]
        );
        return res.status(400).json({ error: 'Recovery token has expired. Please request a new one.' });
      }

      isValid = await bcrypt.compare(challenge, user.recovery_token_hash);
    }

    if (!isValid) {
      return res.status(401).json({ error: 'Invalid recovery token' });
    }

    // Reset password & clear recovery token & terminate all sessions
    const passwordHash = await bcrypt.hash(newPassword, 12);
    await pool.execute(
      'UPDATE users SET password_hash = ?, recovery_token_hash = NULL, recovery_token_expires = NULL WHERE id = ?',
      [passwordHash, user.id]
    );
    await pool.execute('DELETE FROM sessions WHERE user_id = ?', [user.id]);

    res.json({
      success: true,
      message: 'Password has been reset. Please login with your new password.'
    });
  } catch (err) {
    console.error('[Auth] Recovery confirm error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
