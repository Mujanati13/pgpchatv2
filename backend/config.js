module.exports = {
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'simo1234',
    database: process.env.DB_NAME || 'pgpchatv2',
    waitForConnections: true,
    connectionLimit: 10,
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'CHANGE_ME_TO_A_RANDOM_64_CHAR_SECRET',
    expiresIn: '7d',
  },
  server: {
    port: parseInt(process.env.PORT, 10) || 3000,
  },
  // Auto-delete: default timer in hours
  autoDelete: {
    defaultHours: 24,
  },
  // Backup sync interval in seconds
  backup: {
    syncIntervalSeconds: 60,
  },
};
