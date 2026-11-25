const mongoose = require('mongoose');
const Schema = mongoose.Schema;

var Watchlist = new Schema({
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
    }
}, {
    timestamps: true
});

Watchlist.index({ userFrom: 1, movieId: 1 });

module.exports = mongoose.model('Watchlist', Watchlist);