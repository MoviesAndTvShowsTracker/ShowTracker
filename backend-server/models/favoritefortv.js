const mongoose = require('mongoose');
const Schema = mongoose.Schema;

var FavoriteTv = new Schema({
    userFrom: {
        type: Schema.ObjectId,
        ref: 'User'
    },
    tvId: {
        type: String
    },
    tvTitle: {
        type: String
    },
    tvImage: {
        type: String
    },
    tvPosterImage: {
        type: String
    },
    tvRuntime: {
        type: Array
    }
});

module.exports = mongoose.model('FavoriteTv', FavoriteTv);