const mongoose = require('mongoose');
const Schema = mongoose.Schema;
var passportLocalMongoose = require('passport-local-mongoose');

var User = new Schema({
    username: {
        type: String, 
        unique: true,
        required: true
    },
    phonenumber:{
        type: Number,
        default: "",
        maxlength: 10
    },
    firstName: {
        type: String,
        default: ''
    },
    lastName: {
        type: String,
        default: ''
    },
    email: {
        type: String,
        required: true,
        unique: true
    },
    googleId: {
        type: String,
        unique: true,
        sparse: true
    },
    resetPasswordToken: {
        type: String,
        select: false
    },
    resetPasswordExpires: {
        type: Date,
        select: false
    },
    admin: {
        type: Boolean,
        default: false
    }
}, {
    timestamps: true
});
User.plugin(passportLocalMongoose, { usernameField: 'email' });

module.exports = mongoose.model('User', User);