const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const Device = new Schema(
  {
    userFrom: { type: Schema.ObjectId, ref: 'User', required: true },
    token: { type: String, required: true },
    platform: { type: String, default: 'ios' },
    appVersion: { type: String, default: '' },
    lastSeenAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

Device.index({ userFrom: 1, token: 1 }, { unique: true });
Device.index({ token: 1 });

module.exports = mongoose.model('Device', Device);
