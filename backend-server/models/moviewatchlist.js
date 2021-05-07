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
});

module.exports = mongoose.model('Watchlist', Watchlist);