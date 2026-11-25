/** Shares one in-flight promise per key, so concurrent callers don't repeat the same work. */
const inFlight = new Map();

function singleFlight(key, fn) {
  if (inFlight.has(key)) return inFlight.get(key);
  const promise = Promise.resolve()
    .then(fn)
    .finally(() => inFlight.delete(key));
  inFlight.set(key, promise);
  return promise;
}

module.exports = { singleFlight };
