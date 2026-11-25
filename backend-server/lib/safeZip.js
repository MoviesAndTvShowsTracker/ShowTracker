const fs = require('fs');
const path = require('path');
const yauzl = require('yauzl');

/** The TV Time GDPR files the importer reads. Nothing else in the zip is ever written. */
const NEEDED_FILES = [
  'tracking-prod-records-v2.csv',
  'tracking-prod-records.csv',
  'user_tv_show_data.csv',
  'lists-prod-lists.csv',
];

const DEFAULTS = {
  maxEntries: 2000, // the real export has a few dozen files
  maxEntryBytes: 100 * 1024 * 1024, // per CSV, uncompressed
  maxTotalBytes: 300 * 1024 * 1024, // all CSVs together, uncompressed
};

function isSymlink(entry) {
  // Unix mode lives in the top 16 bits of the external attributes; 0o120000 = symbolic link.
  return ((entry.externalFileAttributes >>> 16) & 0o170000) === 0o120000;
}

function fail(message) {
  const err = new Error(message);
  err.status = 400;
  return err;
}

/**
 * Reads the CSVs we need from a TV Time zip straight into `outDir` (which must be empty), by base
 * name only. Never extracts anything else, never follows or creates links, and stops at size and
 * entry-count caps, so a crafted zip can't write outside `outDir` or exhaust memory or disk.
 * Resolves with the file names written.
 */
function readImportZip(zipPath, outDir, options = {}) {
  const limits = { ...DEFAULTS, ...options };
  return new Promise((resolve, reject) => {
    // yauzl refuses absolute paths and ".." in names, and checks each entry's real size against its header.
    yauzl.open(zipPath, { lazyEntries: true, validateEntrySizes: true, strictFileNames: true }, (openErr, zip) => {
      if (openErr) return reject(fail('That file is not a readable zip.'));
      if (zip.entryCount > limits.maxEntries) {
        zip.close();
        return reject(fail('That zip has too many files to be a TV Time export.'));
      }

      const written = [];
      let total = 0;
      let settled = false;
      const done = (err) => {
        if (settled) return;
        settled = true;
        zip.close();
        if (err) reject(err.status ? err : fail(`Could not read that zip: ${err.message}`));
        else resolve(written);
      };

      zip.on('error', done);
      zip.on('end', () => done(null));
      zip.on('entry', (entry) => {
        const name = path.posix.basename(entry.fileName);
        const wanted = !entry.fileName.endsWith('/') && NEEDED_FILES.includes(name) && !written.includes(name);
        if (!wanted) return zip.readEntry();
        if (isSymlink(entry)) return done(fail('That zip contains a link where a CSV should be.'));
        if (entry.uncompressedSize > limits.maxEntryBytes) return done(fail(`${name} is too large.`));

        zip.openReadStream(entry, (streamErr, stream) => {
          if (streamErr) return done(streamErr);
          // 'wx': create only, never overwrite or follow an existing file.
          const out = fs.createWriteStream(path.join(outDir, name), { flags: 'wx' });
          let bytes = 0;
          stream.on('data', (chunk) => {
            bytes += chunk.length;
            total += chunk.length;
            if (bytes > limits.maxEntryBytes || total > limits.maxTotalBytes) {
              stream.destroy();
              out.destroy();
              done(fail(`${name} is too large.`));
            }
          });
          stream.on('error', done);
          out.on('error', done);
          out.on('finish', () => {
            written.push(name);
            zip.readEntry();
          });
          stream.pipe(out);
        });
      });
      zip.readEntry();
    });
  });
}

module.exports = { readImportZip, NEEDED_FILES };
