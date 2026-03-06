const cron = require('node-cron');
const { pool } = require('../database');
const config = require('../config');

function startCronJobs() {
  // ========================================
  // Auto-delete messages based on user settings
  // Runs every 10 minutes
  // ========================================
  cron.schedule('*/10 * * * *', async () => {
    try {
      const [users] = await pool.execute(
        'SELECT user_id, auto_delete_hours FROM user_settings WHERE auto_delete_enabled = 1'
      );

      for (const user of users) {
        await pool.execute(
          `DELETE FROM messages
           WHERE (sender_id = ? OR recipient_id = ?)
           AND created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)`,
          [user.user_id, user.user_id, user.auto_delete_hours]
        );
      }
      console.log(`[Cron] Auto-delete scan complete for ${users.length} users`);
    } catch (err) {
      console.error('[Cron] Auto-delete error:', err.message);
    }
  });

  // ========================================
  // Zero-Knowledge: Wipe IP logs every 60 minutes
  // ========================================
  const logWipeInterval = config.logWipe.intervalMinutes;
  cron.schedule(`*/${logWipeInterval} * * * *`, async () => {
    try {
      const [result] = await pool.execute('DELETE FROM ip_logs');
      console.log(`[Cron] IP logs wiped: ${result.affectedRows} entries removed`);
    } catch (err) {
      console.error('[Cron] IP log wipe error:', err.message);
    }
  });

  // ========================================
  // Terminate stale sessions older than 30 days
  // Runs every hour
  // ========================================
  cron.schedule('0 * * * *', async () => {
    try {
      const [result] = await pool.execute(
        'DELETE FROM sessions WHERE last_active < DATE_SUB(NOW(), INTERVAL 30 DAY)'
      );
      if (result.affectedRows > 0) {
        console.log(`[Cron] Terminated ${result.affectedRows} stale sessions`);
      }
    } catch (err) {
      console.error('[Cron] Stale session cleanup error:', err.message);
    }
  });

  console.log('[Cron] All scheduled jobs started');
}

module.exports = { startCronJobs };
