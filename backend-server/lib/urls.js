/** An https URL whose host is rottentomatoes.com or a subdomain of it — nothing else. */
function isRottenTomatoesUrl(raw) {
  try {
    const url = new URL(String(raw));
    const host = url.hostname.toLowerCase();
    return url.protocol === 'https:' && (host === 'rottentomatoes.com' || host.endsWith('.rottentomatoes.com'));
  } catch {
    return false;
  }
}

module.exports = { isRottenTomatoesUrl };
