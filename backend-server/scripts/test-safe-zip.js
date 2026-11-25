/* TV Time zips are read entry by entry: no symlinks, no traversal, no bombs, only the CSVs we need. */
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { readImportZip, NEEDED_FILES } = require('../lib/safeZip');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'safezip-'));
const zip = (name, cwd, args) => {
  const out = path.join(tmp, name);
  execFileSync('zip', ['-q', ...args, out, ...(args.includes('-r') ? [] : [])], { cwd });
  return out;
};
const dir = (name) => { const d = path.join(tmp, name); fs.mkdirSync(d, { recursive: true }); return d; };

(async () => {
  // A valid export (nested folder like the real GDPR zip) plus files we don't need.
  const ok = dir('ok/gdpr-data');
  for (const f of NEEDED_FILES) fs.writeFileSync(path.join(ok, f), 'id,name\n1,x\n');
  fs.writeFileSync(path.join(ok, 'unrelated.json'), '{}');
  const okZip = path.join(tmp, 'ok.zip');
  execFileSync('zip', ['-q', '-r', okZip, 'gdpr-data'], { cwd: path.join(tmp, 'ok') });
  const outDir = dir('out-ok');
  const written = await readImportZip(okZip, outDir);
  assert.deepStrictEqual(written.sort(), [...NEEDED_FILES].sort());
  assert.deepStrictEqual(fs.readdirSync(outDir).sort(), [...NEEDED_FILES].sort(), 'only the CSVs we need');

  // A symlink entry named like a CSV is refused (it could point anywhere on the server).
  const sl = dir('sl');
  fs.symlinkSync('/etc/passwd', path.join(sl, 'tracking-prod-records-v2.csv'));
  const slZip = path.join(tmp, 'sl.zip');
  execFileSync('zip', ['-q', '-y', slZip, 'tracking-prod-records-v2.csv'], { cwd: sl });
  await assert.rejects(readImportZip(slZip, dir('out-sl')), /link/i);

  // Traversal names are refused before anything is written.
  const tr = dir('tr/a');
  fs.writeFileSync(path.join(tr, 'user_tv_show_data.csv'), 'x');
  const trZip = path.join(tmp, 'tr.zip');
  execFileSync('python3', ['-c', `import zipfile;z=zipfile.ZipFile(${JSON.stringify(trZip)},'w');z.writestr('../../evil/user_tv_show_data.csv','x');z.close()`]);
  await assert.rejects(readImportZip(trZip, dir('out-tr')), /invalid|relative|path/i);

  // A bomb: a tiny zip that inflates past the per-file cap.
  const bombZip = path.join(tmp, 'bomb.zip');
  execFileSync('python3', ['-c', `import zipfile;z=zipfile.ZipFile(${JSON.stringify(bombZip)},'w',zipfile.ZIP_DEFLATED);z.writestr('tracking-prod-records-v2.csv',b'0'*(3*1024*1024));z.close()`]);
  assert.ok(fs.statSync(bombZip).size < 50 * 1024, 'bomb is tiny on disk');
  await assert.rejects(readImportZip(bombZip, dir('out-bomb'), { maxEntryBytes: 1024 * 1024 }), /too large/i);

  // The total cap trips mid-way through a second file: refused, and no partial file is left.
  const twoZip = path.join(tmp, 'two.zip');
  execFileSync('python3', ['-c', `import zipfile;z=zipfile.ZipFile(${JSON.stringify(twoZip)},'w',zipfile.ZIP_DEFLATED);z.writestr('user_tv_show_data.csv',b'1'*600000);z.writestr('tracking-prod-records.csv',b'2'*600000);z.close()`]);
  const twoOut = dir('out-two');
  await assert.rejects(readImportZip(twoZip, twoOut, { maxEntryBytes: 1024 * 1024, maxTotalBytes: 1000000 }), /too large/i);
  await new Promise((r) => setTimeout(r, 50));
  assert.ok(!fs.existsSync(path.join(twoOut, 'tracking-prod-records.csv')), 'the partial file is removed');

  // Too many entries.
  const manyZip = path.join(tmp, 'many.zip');
  execFileSync('python3', ['-c', `import zipfile;z=zipfile.ZipFile(${JSON.stringify(manyZip)},'w');[z.writestr(f'f{i}.txt','') for i in range(60)];z.close()`]);
  await assert.rejects(readImportZip(manyZip, dir('out-many'), { maxEntries: 50 }), /too many/i);

  // Not a zip at all.
  const junk = path.join(tmp, 'junk.zip');
  fs.writeFileSync(junk, 'not a zip');
  await assert.rejects(readImportZip(junk, dir('out-junk')));

  fs.rmSync(tmp, { recursive: true, force: true });
  console.log('safe zip: all passed');
})().catch((err) => {
  console.error(err);
  fs.rmSync(tmp, { recursive: true, force: true });
  process.exit(1);
});
