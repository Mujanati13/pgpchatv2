const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { authenticate } = require('../middleware/auth');

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Configure multer storage
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    const allowed = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    if (!allowed.includes(ext)) {
      return cb(new Error('Invalid file type'));
    }
    const name = crypto.randomBytes(20).toString('hex') + ext;
    cb(null, name);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  // Extension check in filename() callback is sufficient; skip mime filter
  // because some HTTP clients send application/octet-stream for image files.
});

// POST /api/uploads  — upload an image (authenticated)
router.post('/', authenticate, (req, res) => {
  upload.single('image')(req, res, (err) => {
    if (err) {
      console.error('[Uploads] Multer error:', err.message);
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({ error: 'File too large (max 10 MB)' });
      }
      return res.status(400).json({ error: err.message });
    }
    if (!req.file) {
      return res.status(400).json({ error: 'No image provided' });
    }
    console.log('[Uploads] Saved:', req.file.filename);
    res.status(201).json({ filename: req.file.filename });
  });
});

// GET /api/uploads/:filename  — serve an image (authenticated)
router.get('/:filename', authenticate, (req, res) => {
  // Sanitize filename to prevent directory traversal
  const filename = path.basename(req.params.filename);
  const filePath = path.join(uploadsDir, filename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File not found' });
  }

  res.sendFile(filePath);
});

module.exports = router;
