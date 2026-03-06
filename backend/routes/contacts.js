const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../database');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// GET /api/contacts
router.get('/', async (req, res) => {
  try {
    const [contacts] = await pool.execute(
      `SELECT c.id, c.contact_user_id, c.display_name, c.is_blocked, c.created_at,
              u.username AS contact_username, u.public_key
       FROM contacts c
       JOIN users u ON c.contact_user_id = u.id
       WHERE c.owner_id = ?
       ORDER BY c.created_at DESC`,
      [req.userId]
    );
    res.json({ contacts });
  } catch (err) {
    console.error('[Contacts] List error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/contacts  — add a contact
router.post('/', async (req, res) => {
  try {
    const { contactUserId, username, displayName } = req.body;
    if (!contactUserId && !username) {
      return res.status(400).json({ error: 'contactUserId or username required' });
    }

    // Resolve user: look up by username if provided, otherwise by UUID
    let resolvedId = contactUserId;
    if (username) {
      const [found] = await pool.execute(
        'SELECT id FROM users WHERE username = ?',
        [username]
      );
      if (found.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }
      resolvedId = found[0].id;
    } else {
      // Validate by UUID
      const [users] = await pool.execute('SELECT id FROM users WHERE id = ?', [
        resolvedId,
      ]);
      if (users.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }
    }

    if (resolvedId === req.userId) {
      return res.status(400).json({ error: 'Cannot add yourself as a contact' });
    }

    const contactId = uuidv4();
    await pool.execute(
      'INSERT INTO contacts (id, owner_id, contact_user_id, display_name) VALUES (?, ?, ?, ?)',
      [contactId, req.userId, resolvedId, displayName || null]
    );

    res.status(201).json({ id: contactId });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'Contact already exists' });
    }
    console.error('[Contacts] Add error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /api/contacts/:contactId
router.delete('/:contactId', async (req, res) => {
  try {
    const [result] = await pool.execute(
      'DELETE FROM contacts WHERE id = ? AND owner_id = ?',
      [req.params.contactId, req.userId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Contact not found' });
    }
    res.json({ success: true });
  } catch (err) {
    console.error('[Contacts] Delete error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /api/contacts/:contactId/block
router.put('/:contactId/block', async (req, res) => {
  try {
    const { blocked } = req.body; // true or false
    const [result] = await pool.execute(
      'UPDATE contacts SET is_blocked = ? WHERE id = ? AND owner_id = ?',
      [blocked ? 1 : 0, req.params.contactId, req.userId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Contact not found' });
    }
    res.json({ success: true, isBlocked: !!blocked });
  } catch (err) {
    console.error('[Contacts] Block error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/contacts/block-key  — block by PGP public key fingerprint
router.post('/block-key', async (req, res) => {
  try {
    const { publicKeyFragment } = req.body;
    if (!publicKeyFragment) {
      return res.status(400).json({ error: 'publicKeyFragment required' });
    }

    // Find users matching the public key fragment
    const [users] = await pool.execute(
      'SELECT id FROM users WHERE public_key LIKE ?',
      [`%${publicKeyFragment}%`]
    );

    let blockedCount = 0;
    for (const user of users) {
      if (user.id === req.userId) continue;
      // Upsert contact as blocked
      await pool.execute(
        `INSERT INTO contacts (id, owner_id, contact_user_id, is_blocked)
         VALUES (?, ?, ?, 1)
         ON DUPLICATE KEY UPDATE is_blocked = 1`,
        [uuidv4(), req.userId, user.id]
      );
      blockedCount++;
    }

    res.json({ success: true, blockedCount });
  } catch (err) {
    console.error('[Contacts] Block by key error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
