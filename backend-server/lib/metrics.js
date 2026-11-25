const { monitorEventLoopDelay } = require('perf_hooks');

/**
 * Times every request: adds `Server-Timing: app;dur=<ms>` and logs requests slower
 * than `slowMs`. Logs the path only, never the query string (it can carry tokens).
 */
function requestTimer({ slowMs = 500, log = console.log, now = () => performance.now() } = {}) {
  return function timeRequest(req, res, next) {
    const started = now();
    const path = String(req.originalUrl || req.url || '').split('?')[0];

    const writeHead = res.writeHead;
    res.writeHead = function timedWriteHead(...args) {
      if (!res.getHeader('server-timing')) {
        res.setHeader('Server-Timing', `app;dur=${Math.round(now() - started)}`);
      }
      return writeHead.apply(this, args);
    };

    res.once('finish', () => {
      const ms = Math.round(now() - started);
      if (ms > slowMs) log(`[slow] ${req.method} ${path} ${res.statusCode} ${ms}ms`);
    });
    next();
  };
}

/** Event-loop delay in ms: how long other users wait while one request holds the CPU. */
function startLoopMonitor({ resolution = 20 } = {}) {
  const histogram = monitorEventLoopDelay({ resolution });
  histogram.enable();
  const ms = (ns) => Math.round((ns / 1e6) * 10) / 10;
  return {
    snapshot() {
      const snap = {
        p50: ms(histogram.percentile(50)),
        p99: ms(histogram.percentile(99)),
        max: ms(histogram.max),
      };
      histogram.reset();
      return snap;
    },
    stop() {
      histogram.disable();
    },
  };
}

module.exports = { requestTimer, startLoopMonitor };
