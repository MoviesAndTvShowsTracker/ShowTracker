const express = require('express');
const authenticate = require('../authenticate');
const { buildActivity } = require('../services/diaryActivity');

const router = express.Router();

router.get('/activity', authenticate.verifyUser, async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 60, 120);
    const items = await buildActivity(req.user._id, limit);
    res.status(200).json({ success: true, items });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
