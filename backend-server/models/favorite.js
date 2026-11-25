const mongoose = require('mongoose');
const Schema = mongoose.Schema;

var Favorite = new Schema({
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
    favoritedAt: {
        type: Date
    }
}, {
    timestamps: true
});

Favorite.index({ userFrom: 1, movieId: 1 });

module.exports = mongoose.model('Favorite', Favorite);