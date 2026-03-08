const mysql = require('mysql2/promise');
const config = require('./config');

const pool = mysql.createPool(config.db);

async function initializeDatabase() {
  const conn = await pool.getConnection();
  try {
    // Users table
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(36) PRIMARY KEY,
        username VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        public_key TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);

    // Sessions / device management
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS sessions (
        id VARCHAR(36) PRIMARY KEY,
        user_id VARCHAR(36) NOT NULL,
        device_name VARCHAR(255) NOT NULL DEFAULT 'Unknown Device',
        device_type VARCHAR(50) DEFAULT 'unknown',
        ip_address VARCHAR(45),
        location VARCHAR(255),
        token_hash VARCHAR(255) NOT NULL,
        last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `);

    // Contacts
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS contacts (
        id VARCHAR(36) PRIMARY KEY,
        owner_id VARCHAR(36) NOT NULL,
        contact_user_id VARCHAR(36) NOT NULL,
        display_name VARCHAR(255),
        is_blocked TINYINT(1) DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (contact_user_id) REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE KEY unique_contact (owner_id, contact_user_id)
      )
    `);

    // Messages (encrypted at rest — body is PGP ciphertext)
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS messages (
        id VARCHAR(36) PRIMARY KEY,
        sender_id VARCHAR(36) NOT NULL,
        recipient_id VARCHAR(36) NOT NULL,
        encrypted_body LONGTEXT NOT NULL,
        signature TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE,
        INDEX idx_recipient_created (recipient_id, created_at),
        INDEX idx_sender_created (sender_id, created_at)
      )
    `);

    // User settings
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS user_settings (
        user_id VARCHAR(36) PRIMARY KEY,
        auto_delete_enabled TINYINT(1) DEFAULT 1,
        auto_delete_hours INT DEFAULT 24,
        contacts_enabled TINYINT(1) DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `);

    // IP access log (wiped every 60 min by cron)
    await conn.execute(`
      CREATE TABLE IF NOT EXISTS ip_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(36),
        ip_address VARCHAR(45),
        action VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('[DB] All tables initialized successfully');

    // Migrations — safe to run on every startup
    try {
      await conn.execute(
        `ALTER TABLE contacts ADD COLUMN last_read_at TIMESTAMP NULL DEFAULT NULL`
      );
      console.log('[DB] Migration: added last_read_at to contacts');
    } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }

    try {
      await conn.execute(
        `ALTER TABLE users ADD COLUMN recovery_token_hash VARCHAR(255) NULL DEFAULT NULL`
      );
      console.log('[DB] Migration: added recovery_token_hash to users');
    } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }

    try {
      await conn.execute(
        `ALTER TABLE users ADD COLUMN recovery_token_expires TIMESTAMP NULL DEFAULT NULL`
      );
      console.log('[DB] Migration: added recovery_token_expires to users');
    } catch (e) {
      if (e.code !== 'ER_DUP_FIELDNAME') throw e;
    }
  } finally {
    conn.release();
  }
}

module.exports = { pool, initializeDatabase };
