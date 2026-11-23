const express = require('express');
const authenticate = require('../authenticate');
const Watch = require('../models/watch');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const TvShowTracking = require('../models/tvShowTracking');

const router = express.Router();

router.get('/activity', authenticate.verifyUser, async (req, res, next) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 60, 120);
    const userId = req.user._id;

    const [films, episodes] = await Promise.all([
      Watch.find({ userFrom: userId })
        .sort({ watchedAt: -1, updatedAt: -1 })
        .limit(limit)
        .lean(),
      TvEpisodeWatch.find({ userFrom: userId })
        .sort({ watchedAt: -1, updatedAt: -1 })
        .limit(limit)
        .lean(),
    ]);

    const tvIds = [...new Set(episodes.map((e) => e.tvId).filter(Boolean))];
    const tracks = tvIds.length
      ? await TvShowTracking.find({ userFrom: userId, tvId: { $in: tvIds } }).lean()
      : [];
    const titleByTv = Object.fromEntries(
      tracks.map((t) => [String(t.tvId), t.tvTitle || t.tvName || null])
    );
    const posterByTv = Object.fromEntries(
      tracks.map((t) => [String(t.tvId), t.tvPosterImage || t.tvPost || null])
    );

    const items = [
      ...films.map((f) => ({
        kind: 'film',
        id: String(f._id),
        mediaId: f.movieId,
        title: f.movieTitle || 'Film',
        posterPath: f.moviePosterImage || f.movieImage || null,
        subtitle: f.isRewatch ? 'Rewatch' : null,
        isRewatch: Boolean(f.isRewatch),
        watchedAt: f.watchedAt || f.updatedAt || f.createdAt,
        rating: f.rating ?? null,
      })),
      ...episodes.map((e) => ({
        kind: 'episode',
        id: String(e._id),
        mediaId: e.tvId,
        title: titleByTv[String(e.tvId)] || 'Show',
        posterPath: posterByTv[String(e.tvId)] || null,
        subtitle: `S${e.seasonNumber}E${e.episodeNumber}${e.episodeName ? ` · ${e.episodeName}` : ''}`,
        watchedAt: e.watchedAt || e.updatedAt || e.createdAt,
        rating: e.rating ?? null,
      })),
    ]
      .filter((item) => item.watchedAt)
      .sort((a, b) => new Date(b.watchedAt) - new Date(a.watchedAt))
      .slice(0, limit);

    res.status(200).json({ success: true, items });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
