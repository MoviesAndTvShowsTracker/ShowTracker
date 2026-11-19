const express = require('express');
const bodyParser = require('body-parser');
const authenticate = require('../authenticate');
const Device = require('../models/device');

const router = express.Router();
router.use(bodyParser.json());

router.post('/register', authenticate.verifyUser, async (req, res, next) => {
  try {
    const token = String(req.body.token || '').trim();
    if (!token) {
      return res.status(400).json({ success: false, message: 'token required' });
    }
    const platform = req.body.platform || 'ios';
    const appVersion = req.body.appVersion || '';
    const doc = await Device.findOneAndUpdate(
      { userFrom: req.user._id, token },
      {
        userFrom: req.user._id,
        token,
        platform,
        appVersion,
        lastSeenAt: new Date(),
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    res.status(200).json({ success: true, deviceId: doc._id });
  } catch (err) {
    next(err);
  }
});

router.post('/unregister', authenticate.verifyUser, async (req, res, next) => {
  try {
    const token = String(req.body.token || '').trim();
    if (!token) {
      return res.status(400).json({ success: false, message: 'token required' });
    }
    await Device.deleteOne({ userFrom: req.user._id, token });
    res.status(200).json({ success: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
