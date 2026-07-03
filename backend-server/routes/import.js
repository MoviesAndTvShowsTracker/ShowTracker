const express = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const AdmZip = require('adm-zip');
const authenticate = require('../authenticate');
const ImportJob = require('../models/importJob');
const { runTvTimeImport } = require('../services/tvtimeImport');

const router = express.Router();

const UPLOAD_ROOT = path.join(__dirname, '../tmp/imports');
const CACHE_PATH = path.join(__dirname, '../scripts/.tvtime-import-cache.json');
const MAX_ZIP_BYTES = 50 * 1024 * 1024;

if (!fs.existsSync(UPLOAD_ROOT)) {
  fs.mkdirSync(UPLOAD_ROOT, { recursive: true });
}

const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => {
      const dir = path.join(UPLOAD_ROOT, String(req.user._id));
      fs.mkdirSync(dir, { recursive: true });
      cb(null, dir);
    },
    filename: (req, file, cb) => {
      cb(null, `upload-${Date.now()}.zip`);
    },
  }),
  limits: { fileSize: MAX_ZIP_BYTES },
  fileFilter: (req, file, cb) => {
    const ok =
      file.mimetype === 'application/zip' ||
      file.mimetype === 'application/x-zip-compressed' ||
      file.originalname.toLowerCase().endsWith('.zip');
    cb(ok ? null : new Error('Upload a .zip file from TV Time.'), ok);
  },
});

function extractZip(zipPath, destDir) {
  const zip = new AdmZip(zipPath);
  zip.extractAllTo(destDir, true);
}

/** Find folder containing required CSVs (zip root or gdpr-data subfolder). */
function resolveDataDir(extractRoot) {
  const direct = extractRoot;
  const nested = path.join(extractRoot, 'gdpr-data');
  if (fs.existsSync(path.join(nested, 'tracking-prod-records-v2.csv'))) return nested;
  if (fs.existsSync(path.join(direct, 'tracking-prod-records-v2.csv'))) return direct;
  const entries = fs.readdirSync(extractRoot, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const candidate = path.join(extractRoot, entry.name);
    if (fs.existsSync(path.join(candidate, 'tracking-prod-records-v2.csv'))) return candidate;
  }
  return null;
}

function rmDirSafe(dir) {
  if (dir && fs.existsSync(dir)) fs.rmSync(dir, { recursive: true, force: true });
}

async function processImportJob(jobId, userId, dataDir, workDir) {
  const apiKey = process.env.TMDB_API_KEY;
  if (!apiKey) {
    await ImportJob.findByIdAndUpdate(jobId, {
      status: 'failed',
      errorMessage: 'Server missing TMDB_API_KEY.',
      finishedAt: new Date(),
    });
    rmDirSafe(workDir);
    return;
  }

  try {
    await ImportJob.findByIdAndUpdate(jobId, {
      status: 'processing',
      startedAt: new Date(),
      phase: 'starting',
    });

    const report = await runTvTimeImport({
      userId,
      dataDir,
      apiKey,
      cachePath: CACHE_PATH,
      replace: true,
      dryRun: false,
      onProgress: async (phase, detail) => {
        const label = detail?.done
          ? `${phase} (${detail.done}/${detail.total})`
          : phase;
        await ImportJob.findByIdAndUpdate(jobId, { phase: label }).catch(() => {});
      },
    });

    await ImportJob.findByIdAndUpdate(jobId, {
      status: 'completed',
      phase: 'done',
      report,
      finishedAt: new Date(),
    });
    const { invalidateUserStats } = require('../services/statsCache');
    await invalidateUserStats(userId);
  } catch (err) {
    await ImportJob.findByIdAndUpdate(jobId, {
      status: 'failed',
      phase: 'failed',
      errorMessage: err.message || 'Import failed.',
      finishedAt: new Date(),
    });
  } finally {
    rmDirSafe(workDir);
  }
}

router.get('/tvtime/status', authenticate.verifyUser, async (req, res, next) => {
  try {
    const job = await ImportJob.findOne({ userFrom: req.user._id }).sort({ createdAt: -1 });
    res.status(200).json({ success: true, job: job || null });
  } catch (err) {
    next(err);
  }
});

router.post(
  '/tvtime',
  authenticate.verifyUser,
  upload.single('file'),
  async (req, res, next) => {
    let workDir = null;
    try {
      if (!req.file) {
        return res.status(400).json({ success: false, message: 'Choose a TV Time export .zip file.' });
      }

      const active = await ImportJob.findOne({
        userFrom: req.user._id,
        status: { $in: ['queued', 'processing'] },
      });
      if (active) {
        rmDirSafe(req.file.path);
        return res.status(409).json({
          success: false,
          message: 'An import is already running. Check back here for progress.',
          job: active,
        });
      }

      workDir = path.join(UPLOAD_ROOT, String(req.user._id), `job-${Date.now()}`);
      fs.mkdirSync(workDir, { recursive: true });

      extractZip(req.file.path, workDir);
      fs.unlinkSync(req.file.path);

      const dataDir = resolveDataDir(workDir);
      if (!dataDir) {
        rmDirSafe(workDir);
        return res.status(400).json({
          success: false,
          message:
            'Could not find TV Time CSV files in that zip. Upload the full GDPR export folder as a zip.',
        });
      }

      const job = await ImportJob.create({
        userFrom: req.user._id,
        status: 'queued',
        phase: 'queued',
      });

      res.status(202).json({
        success: true,
        message:
          'Import started. This usually takes 5–15 minutes. You can leave this page and check back here later.',
        job,
      });

      setImmediate(() => processImportJob(job._id, req.user._id, dataDir, workDir));
    } catch (err) {
      if (req.file?.path && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      rmDirSafe(workDir);
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ success: false, message: 'Zip file is too large (max 50 MB).' });
      }
      next(err);
    }
  }
);

module.exports = router;
