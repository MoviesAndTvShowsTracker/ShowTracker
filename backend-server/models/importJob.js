const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const ImportJob = new Schema(
  {
    userFrom: { type: Schema.ObjectId, ref: 'User', required: true, index: true },
    status: {
      type: String,
      enum: ['queued', 'processing', 'completed', 'failed'],
      default: 'queued',
    },
    phase: { type: String, default: 'queued' },
    report: { type: Schema.Types.Mixed },
    errorMessage: { type: String },
    startedAt: { type: Date },
    finishedAt: { type: Date },
  },
  { timestamps: true }
);

ImportJob.index({ userFrom: 1, createdAt: -1 });

module.exports = mongoose.model('ImportJob', ImportJob);
