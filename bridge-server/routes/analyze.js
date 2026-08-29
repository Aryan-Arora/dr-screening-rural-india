const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const config = require('../config');
const { runPipeline } = require('../matlabRunner');

const router = express.Router();

/**
 * MATLAB's jsonencode has no null type -- an empty MATLAB value ([])
 * always serializes as JSON [], never null. In this pipeline's contract
 * an empty array never carries real meaning (it's always MATLAB's way of
 * saying "not implemented" or "not applicable"), so it's safe to
 * normalize every [] into a real null after parsing.
 */
function nullifyEmptyArrays(value) {
  if (Array.isArray(value)) {
    return value.length === 0 ? null : value.map(nullifyEmptyArrays);
  }
  if (value && typeof value === 'object') {
    const out = {};
    for (const key of Object.keys(value)) {
      out[key] = nullifyEmptyArrays(value[key]);
    }
    return out;
  }
  return value;
}

const upload = multer({
  storage: multer.diskStorage({
    destination: config.UPLOADS_DIR,
    filename: (req, file, cb) => {
      const id = crypto.randomUUID();
      cb(null, `${id}${path.extname(file.originalname) || '.jpg'}`);
    },
  }),
  limits: { fileSize: 25 * 1024 * 1024 }, // 25MB, generous for a single fundus photo
  fileFilter: (req, file, cb) => {
    const ok = /^image\/(jpeg|png)$/.test(file.mimetype);
    cb(ok ? null : new Error('Only JPEG/PNG images are accepted'), ok);
  },
});

// POST /api/analyze  (multipart/form-data, field name "image")
router.post('/analyze', upload.single('image'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image uploaded (expected multipart field "image")' });
  }

  const jobId = path.parse(req.file.filename).name;
  const outputDir = path.join(config.OUTPUTS_DIR, jobId);
  fs.mkdirSync(outputDir, { recursive: true });

  try {
    const { result: rawResult } = await runPipeline(req.file.path, outputDir);
    const result = nullifyEmptyArrays(rawResult);

    // Rewrite relative image filenames (written by MATLAB) into URLs the
    // frontend can fetch directly.
    if (result.images) {
      for (const key of Object.keys(result.images)) {
        if (result.images[key]) {
          result.images[key] = `/api/outputs/${jobId}/${result.images[key]}`;
        }
      }
    }
    result.report_url = result.report_url ? `/api/outputs/${jobId}/${result.report_url}` : null;

    // Overwrite MATLAB's raw result.json with the normalized version (real
    // nulls instead of [], full /api/outputs/... image URLs) so a later
    // direct fetch of this file (GET /api/outputs/:jobId/result.json,
    // served statically) returns exactly what this response just did --
    // used by the frontend's /screening/result/:id revisit page.
    fs.writeFile(path.join(outputDir, 'result.json'), JSON.stringify({ ...result, jobId }), () => {});

    res.json({ ...result, jobId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
