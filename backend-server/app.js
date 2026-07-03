require('dotenv').config();

var createError = require('http-errors');
var express = require('express');
var path = require('path');
var logger = require('morgan');
const config = require('./config/keys');
var indexRouter = require('./routes/index');
var usersRouter = require('./routes/users');
const mongoose = require('mongoose');
var passport = require('passport');
require('./authenticate');
const favorite = require('./routes/favorites');
const watch = require('./routes/watch');
const favoritefortv = require('./routes/favoritefortv');
const moviewatchlist = require('./routes/moviewatchlist');
const tvwatchlist = require('./routes/tvwatchlist');
const tvwatch = require('./routes/tvwatch');
const tvtracking = require('./routes/tvtracking');
const tvepisodes = require('./routes/tvepisodes');
const importRouter = require('./routes/import');
const statsRouter = require('./routes/stats');

const url = config.mongoURL;
mongoose
  .connect(url)
  .then(() => console.log('mongo connection successful'))
  .catch((err) => console.log('no connection to mongodb', err.message));

var app = express();

var cors = require('cors');

function parseCorsOrigins() {
  const raw = process.env.CORS_ORIGINS || process.env.FRONTEND_URL || '';
  const fromEnv = raw
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (fromEnv.length) return fromEnv;
  return ['http://localhost:3000', 'http://127.0.0.1:3000'];
}

const corsOptions = {
  origin: parseCorsOrigins(),
  credentials: true,
  methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With'],
};

// CORS must run before any routes or body parsers so preflight OPTIONS succeeds
app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

app.use(passport.initialize());

app.get('/health', (req, res) => {
  res.status(200).json({ ok: true, service: 'marquee-api' });
});

app.use('/', indexRouter);
app.use('/users', usersRouter);
app.use('/api/tv/favorite', favoritefortv);
app.use('/api/tv/watchlist', tvwatchlist);
app.use('/api/tv/watch', tvwatch);
app.use('/api/tv/tracking', tvtracking);
app.use('/api/tv/episodes', tvepisodes);
app.use('/api/favorite', favorite);
app.use('/api/watch', watch);
app.use('/api/watchlist', moviewatchlist);
app.use('/api/import', importRouter);
app.use('/api/stats', statsRouter);

app.use(express.static(path.join(__dirname, 'public')));

app.use(function (req, res, next) {
  next(createError(404));
});

app.use(function (err, req, res, next) {
  res.status(err.status || 500);
  if (req.path.startsWith('/users') || req.path.startsWith('/api')) {
    return res.json({ success: false, message: err.message });
  }
  res.json({ success: false, message: err.message });
});

module.exports = app;
