/* Account deletion covers every per-user collection, including ones added later. No DB. */
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { perUserModels, deleteAccountData } = require('../services/accountDeletion');

// Every model file that declares a userFrom field must be covered.
const modelsDir = path.join(__dirname, '../models');
const declaring = fs.readdirSync(modelsDir)
  .filter((f) => f.endsWith('.js'))
  .filter((f) => /userFrom\s*:/.test(fs.readFileSync(path.join(modelsDir, f), 'utf8')))
  .map((f) => require(path.join(modelsDir, f)).modelName)
  .sort();
const covered = perUserModels().map((m) => m.modelName).sort();
assert.deepStrictEqual(covered, declaring);
for (const name of ['TvRewatchSession', 'TvRewatchEpisode', 'Device', 'UserStatsCache', 'ImportJob']) {
  assert.ok(covered.includes(name), `${name} is deleted with the account`);
}

(async () => {
  // Deletes each per-user collection for that user only, then the user.
  const calls = [];
  const fakeModels = [
    { modelName: 'A', deleteMany: async (f) => { calls.push(['A', f]); return { deletedCount: 2 }; } },
    { modelName: 'B', deleteMany: async (f) => { calls.push(['B', f]); return { deletedCount: 0 }; } },
  ];
  const fakeUser = { findByIdAndDelete: async (id) => { calls.push(['User', id]); } };
  const os = require('os');
  const uploadRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'uploads-'));
  fs.mkdirSync(path.join(uploadRoot, 'u1', 'job-1'), { recursive: true });
  fs.writeFileSync(path.join(uploadRoot, 'u1', 'job-1', 'tracking.csv'), 'x');
  fs.mkdirSync(path.join(uploadRoot, 'u2'));
  const summary = await deleteAccountData('u1', { models: fakeModels, User: fakeUser, uploadRoot });
  assert.ok(!fs.existsSync(path.join(uploadRoot, 'u1')), 'uploaded TV Time files are removed');
  assert.ok(fs.existsSync(path.join(uploadRoot, 'u2')), "other users' uploads stay");
  fs.rmSync(uploadRoot, { recursive: true, force: true });
  assert.deepStrictEqual(calls, [['A', { userFrom: 'u1' }], ['B', { userFrom: 'u1' }], ['User', 'u1']]);
  assert.deepStrictEqual(summary, { A: 2, B: 0 });
  console.log('account deletion: all passed');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
