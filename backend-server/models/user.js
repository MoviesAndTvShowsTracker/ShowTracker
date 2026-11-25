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
    appleId: {
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
    // The address a pending reset link was sent to; the link proves only that address.
    resetPasswordEmail: {
        type: String,
        select: false
    },
    admin: {
        type: Boolean,
        default: false
    },
    // True once the owner proved the address: signed up through Google/Apple with a verified
    // email, or reset the password from an emailed link. Changing the email clears it.
    emailVerified: {
        type: Boolean,
        default: false
    },
    // Tokens issued before this moment are rejected (password changed, reset or account claimed).
    passwordChangedAt: {
        type: Date,
        default: null
    }
}, {
    timestamps: true
});
User.plugin(passportLocalMongoose, { usernameField: 'email' });

module.exports = mongoose.model('User', User);