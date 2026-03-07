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
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('Only image files are allowed'));
    }
    cb(null, true);
  },
});

// POST /api/uploads  — upload an image (authenticated)
router.post('/', authenticate, upload.single('image'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image provided' });
  }
  res.status(201).json({ filename: req.file.filename });
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
