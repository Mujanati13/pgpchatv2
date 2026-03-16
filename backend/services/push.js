const fs = require('fs');
const admin = require('firebase-admin');
const config = require('../config');
const { pool } = require('../database');

let initialized = false;
let disabled = false;

function _readServiceAccount() {
  const { serviceAccountJson, serviceAccountPath } = config.firebase;

  if (serviceAccountJson) {
    return JSON.parse(serviceAccountJson);
  }

  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    const raw = fs.readFileSync(serviceAccountPath, 'utf8');
    return JSON.parse(raw);
  }

  return null;
}

function _initFirebaseIfNeeded() {
  if (initialized || disabled) return;

  try {
    const serviceAccount = _readServiceAccount();
    if (!serviceAccount) {
      disabled = true;
      console.warn('[Push] Firebase disabled: no service account configured');
      return;
    }

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    initialized = true;
    console.log('[Push] Firebase initialized');
  } catch (err) {
    disabled = true;
    console.error('[Push] Firebase init failed:', err.message);
  }
}

async function sendNewMessagePush({ recipientId, senderId, senderUsername }) {
  _initFirebaseIfNeeded();
  if (!initialized) return;

  try {
    const [rows] = await pool.execute(
      `SELECT DISTINCT push_token
       FROM sessions
       WHERE user_id = ? AND push_token IS NOT NULL AND push_token != ''`,
      [recipientId]
    );

    const tokens = rows.map((r) => r.push_token).filter(Boolean);
    if (!tokens.length) return;

    const payload = {
      notification: {
        title: senderUsername || 'New message',
        body: 'You received a new message',
      },
      data: {
        type: 'new_message',
        senderId: String(senderId),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'messages',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
      tokens,
    };

    const result = await admin.messaging().sendEachForMulticast(payload);

    if (result.failureCount > 0) {
      const invalidTokens = [];
      result.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const code = resp.error?.code || '';
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            invalidTokens.push(tokens[idx]);
          }
        }
      });

      if (invalidTokens.length) {
        await Promise.all(
          invalidTokens.map((token) =>
            pool.execute(
              'UPDATE sessions SET push_token = NULL WHERE push_token = ?',
              [token]
            )
          )
        );
      }
    }
  } catch (err) {
    console.error('[Push] Send error:', err.message);
  }
}

module.exports = {
  sendNewMessagePush,
};
