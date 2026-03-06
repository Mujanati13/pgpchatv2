const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../database');
const { authenticate } = require('../middleware/auth');

// All routes require authentication
router.use(authenticate);

// GET /api/messages?contactId=xxx&before=timestamp&limit=50
router.get('/', async (req, res) => {
  try {
    const { contactId, before, limit } = req.query;
    if (!contactId) {
      return res.status(400).json({ error: 'contactId required' });
    }

    // Check if blocked
    const [blocked] = await pool.execute(
      'SELECT is_blocked FROM contacts WHERE owner_id = ? AND contact_user_id = ? AND is_blocked = 1',
      [req.userId, contactId]
    );
    if (blocked.length > 0) {
      return res.status(403).json({ error: 'User is blocked' });
    }

    const pageLimit = Math.min(parseInt(limit, 10) || 50, 100);
    let query = `
      SELECT id, sender_id, recipient_id, encrypted_body, signature, created_at
      FROM messages
      WHERE ((sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?))
    `;
    const params = [req.userId, contactId, contactId, req.userId];

    if (before) {
      query += ' AND created_at < ?';
      params.push(before);
    }

    query += ` ORDER BY created_at DESC LIMIT ${pageLimit}`;

    const [messages] = await pool.execute(query, params);
    res.json({ messages });
  } catch (err) {
    console.error('[Messages] Fetch error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/messages  — send encrypted message
router.post('/', async (req, res) => {
  try {
    const { recipientId, encryptedBody, signature } = req.body;
    if (!recipientId || !encryptedBody) {
      return res.status(400).json({ error: 'recipientId and encryptedBody required' });
    }

    // Check if sender is blocked by recipient
    const [blocked] = await pool.execute(
      'SELECT is_blocked FROM contacts WHERE owner_id = ? AND contact_user_id = ? AND is_blocked = 1',
      [recipientId, req.userId]
    );
    if (blocked.length > 0) {
      return res.status(403).json({ error: 'You are blocked by this user' });
    }

    const messageId = uuidv4();
    await pool.execute(
      'INSERT INTO messages (id, sender_id, recipient_id, encrypted_body, signature) VALUES (?, ?, ?, ?, ?)',
      [messageId, req.userId, recipientId, encryptedBody, signature || null]
    );

    // Auto-add to contacts if contacts are enabled for sender
    const [settings] = await pool.execute(
      'SELECT contacts_enabled FROM user_settings WHERE user_id = ?',
      [req.userId]
    );
    if (settings.length > 0 && settings[0].contacts_enabled) {
      await pool.execute(
        `INSERT IGNORE INTO contacts (id, owner_id, contact_user_id) VALUES (?, ?, ?)`,
        [uuidv4(), req.userId, recipientId]
      );
    }

    res.status(201).json({
      id: messageId,
      senderId: req.userId,
      recipientId,
      createdAt: new Date().toISOString(),
    });
  } catch (err) {
    console.error('[Messages] Send error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /api/messages/conversations  — list recent conversations
router.get('/conversations', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT
        CASE WHEN sender_id = ? THEN recipient_id ELSE sender_id END AS contact_id,
        MAX(created_at) AS last_message_at,
        COUNT(*) AS message_count
      FROM messages
      WHERE sender_id = ? OR recipient_id = ?
      GROUP BY contact_id
      ORDER BY last_message_at DESC`,
      [req.userId, req.userId, req.userId]
    );

    // Enrich with user info
    const enriched = [];
    for (const row of rows) {
      const [users] = await pool.execute(
        'SELECT id, username, public_key FROM users WHERE id = ?',
        [row.contact_id]
      );
      if (users.length > 0) {
        // Get last message
        const [lastMsg] = await pool.execute(
          `SELECT encrypted_body, sender_id, created_at FROM messages
           WHERE ((sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?))
           ORDER BY created_at DESC LIMIT 1`,
          [req.userId, row.contact_id, row.contact_id, req.userId]
        );

        // Count unread (messages from contact, not from self)
        const [unread] = await pool.execute(
          `SELECT COUNT(*) AS cnt FROM messages
           WHERE sender_id = ? AND recipient_id = ?
           AND created_at > COALESCE(
             (SELECT last_active FROM sessions WHERE user_id = ? ORDER BY last_active DESC LIMIT 1),
             '2000-01-01'
           )`,
          [row.contact_id, req.userId, req.userId]
        );

        enriched.push({
          other_user_id: users[0].id,
          other_username: users[0].username,
          other_public_key: users[0].public_key,
          last_message_at: row.last_message_at,
          message_count: row.message_count,
          unread_count: unread[0]?.cnt || 0,
          last_message: lastMsg[0] || null,
        });
      }
    }

    res.json({ conversations: enriched });
  } catch (err) {
    console.error('[Messages] Conversations error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
