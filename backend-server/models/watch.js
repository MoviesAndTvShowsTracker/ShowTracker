const mongoose = require('mongoose');
const Schema = mongoose.Schema;

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
    }
});

module.exports = mongoose.model('Watch', Watch);