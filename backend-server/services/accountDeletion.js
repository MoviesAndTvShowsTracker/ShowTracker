const fs = require('fs');
const path = require('path');

const MODELS_DIR = path.join(__dirname, '../models');
const UPLOAD_ROOT = path.join(__dirname, '../tmp/imports');

/** Every model whose documents belong to a user (has a `userFrom` path), found by scanning models/. */
function perUserModels() {
  return fs.readdirSync(MODELS_DIR)
    .filter((f) => f.endsWith('.js'))
    .map((f) => require(path.join(MODELS_DIR, f)))
    .filter((model) => model && model.schema && model.schema.path('userFrom'));
}

/**
 * Deletes everything the user owns, then the user. Collections run one after another so a
 * failure stops before the account itself is removed (the user can retry).
 * Returns { modelName: deletedCount }.
 */
async function deleteAccountData(userId, { models = perUserModels(), User = require('../models/user'), uploadRoot = UPLOAD_ROOT } = {}) {
  const summary = {};
  for (const model of models) {
    const res = await model.deleteMany({ userFrom: userId });
    summary[model.modelName] = res.deletedCount || 0;
  }
  // TV Time uploads kept on disk for this user.
  fs.rmSync(path.join(uploadRoot, String(userId)), { recursive: true, force: true });
  await User.findByIdAndDelete(userId);
  return summary;
}

module.exports = { perUserModels, deleteAccountData };
