var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
const config = require('./config/keys');
var indexRouter = require('./routes/index');
var usersRouter = require('./routes/users');
const mongoose = require('mongoose');
var session = require('express-session');
var FileStore = require('session-file-store')(session);
var passport = require('passport');
var authenticate = require('./authenticate');
const favorite = require('./routes/favorites');
const watch = require('./routes/watch');
const favoritefortv = require('./routes/favoritefortv');
const moviewatchlist = require('./routes/moviewatchlist');

const url = config.mongoURL;
const connect = mongoose.connect(url, { useNewUrlParser: true, useUnifiedTopology: true});
mongoose.set('useCreateIndex', true);

connect.then( (db) => {
  console.log("mongo connection successful");
}, (err) => { console.log("no connection to mongodb"); });

var app = express();

var cors = require('cors');
var bodyParser = require('body-parser');

app.use(bodyParser.json());

app.use(cors({
    origin      : 'http://localhost:3000',
    credentials : true
}));
app.use(function(req,res,next){
    res.setHeader('Access-Control-Allow-Origin','http://localhost:3000'),
    res.setHeader('Access-Control-Allow-Credentials', 'true'),
    res.setHeader('Access-Control-Allow-Methods','GET,HEAD,OPTIONS,POST,PUT,DELETE'),
    res.setHeader('Access-Control-Allow-Headers','Access-Control-Allow-Headers,Origin,Accept, X-Requested-With, Content-Type, Access-Control-Request-Method, Access-Control-Request-Headers'),
    res.setHeader('Cache-Control','no-cache'), 
    
    next()
});


// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');


app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));


app.use(passport.initialize());

app.use('/', indexRouter);
app.use('/users', usersRouter);
app.use('/api/tv/favorite', favoritefortv);
app.use('/api/favorite', favorite);
app.use('/api/watch', watch);
app.use('/api/watchlist', moviewatchlist)

app.use(express.static(path.join(__dirname, 'public')));



// catch 404 and forward to error handler
app.use(function(req, res, next) {
  next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.render('error');
});

module.exports = app;
