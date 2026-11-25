const mongoose = require('mongoose');
const Schema = mongoose.Schema;

/**
 * One document = one film play (diary log).
 * Multiple rows per user+movieId are intentional so rewatches keep distinct dates.
 */
var Watch = new Schema({
    userFrom: {
        type: Schema.ObjectId,
        ref: 'User'
    },
    movieId: {
        type: String
    },
    movieTitle: {
        type: String
    },
    movieImage: {
        type: String
    },
    moviePosterImage: {
        type: String
    },
    movieRuntime: {
        type: String
    },
    watchedAt: {
        type: Date
    },
    /** The user's note about this watch (up to 500 characters). */
    note: {
        type: String,
        // The 500-character rule (in visible characters) is enforced by lib/diaryInput.js.
        maxlength: 4000,
        default: ''
    },
    /** True when this play is not the user's first log of the film. */
    isRewatch: {
        type: Boolean,
        default: false,
    },
    rating: {
        type: Number,
        min: 1,
        max: 10,
        default: null,
    }
}, {
    timestamps: true
});

Watch.index({ userFrom: 1, movieId: 1, watchedAt: -1 });
Watch.index({ userFrom: 1, watchedAt: -1 });

module.exports = mongoose.model('Watch', Watch);