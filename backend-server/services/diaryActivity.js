const Watch = require('../models/watch');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const TvShowTracking = require('../models/tvShowTracking');
const { recentRewatchActivity } = require('./tvRewatchService');

/** Newest films and episodes the user logged, newest first. */
async function buildActivity(userId, limit) {
  const [films, episodes, rewatchEpisodes] = await Promise.all([
    Watch.find({ userFrom: userId })
      .sort({ watchedAt: -1, updatedAt: -1 })
      .limit(limit)
      .lean(),
    TvEpisodeWatch.find({ userFrom: userId })
      .sort({ watchedAt: -1, updatedAt: -1 })
      .limit(limit)
      .lean(),
    recentRewatchActivity(userId, limit),
  ]);

  const tvIds = [
    ...new Set(
      [...episodes, ...rewatchEpisodes].map((e) => e.tvId).filter(Boolean)
    ),
  ];
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
      isRewatch: false,
      watchedAt: e.watchedAt || e.updatedAt || e.createdAt,
      rating: e.rating ?? null,
    })),
    ...rewatchEpisodes.map((e) => ({
      kind: 'episode',
      id: `rewatch-${String(e._id)}`,
      mediaId: e.tvId,
      title: titleByTv[String(e.tvId)] || 'Show',
      posterPath: posterByTv[String(e.tvId)] || null,
      subtitle: `Rewatch · S${e.seasonNumber}E${e.episodeNumber}${
        e.episodeName ? ` · ${e.episodeName}` : ''
      }`,
      isRewatch: true,
      watchedAt: e.watchedAt || e.updatedAt || e.createdAt,
      rating: e.rating ?? null,
    })),
  ]
    .filter((item) => item.watchedAt)
    .sort((a, b) => new Date(b.watchedAt) - new Date(a.watchedAt))
    .slice(0, limit);
  return items;
}

module.exports = { buildActivity };
