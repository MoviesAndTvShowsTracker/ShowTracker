const CA_TIMEZONES = new Set([
  'America/Toronto',
  'America/Vancouver',
  'America/Edmonton',
  'America/Winnipeg',
  'America/Halifax',
  'America/St_Johns',
  'America/Regina',
  'America/Whitehorse',
  'America/Yellowknife',
]);

/** Prefer US or CA for streaming / certification data. */
export function detectWatchRegion() {
  try {
    const langs = navigator.languages?.length ? navigator.languages : [navigator.language];
    if (langs.some((l) => /-CA\b/i.test(l || ''))) return 'CA';

    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (CA_TIMEZONES.has(tz)) return 'CA';
  } catch {
    /* ignore */
  }
  return 'US';
}

export function watchRegionsInOrder() {
  const primary = detectWatchRegion();
  return primary === 'CA' ? ['CA', 'US'] : ['US', 'CA'];
}

export function regionLabel(code) {
  if (code === 'CA') return 'Canada';
  if (code === 'US') return 'US';
  return code;
}

function dedupeProviders(list) {
  const seen = new Set();
  return (list || []).filter((p) => {
    if (!p?.provider_id || seen.has(p.provider_id)) return false;
    seen.add(p.provider_id);
    return true;
  });
}

/** Pick flatrate / free / ads providers for US or CA (location-first, then fallback). */
export function pickWatchProviders(tmdbResults) {
  if (!tmdbResults) return { providers: [], region: null };

  for (const code of watchRegionsInOrder()) {
    const entry = tmdbResults[code];
    if (!entry) continue;

    const providers = dedupeProviders([
      ...(entry.flatrate || []),
      ...(entry.free || []),
      ...(entry.ads || []),
    ]);

    if (providers.length) return { providers, region: code };
  }

  return { providers: [], region: null };
}

function pickMovieCert(releaseDates) {
  if (!releaseDates?.length) return null;
  const priority = [3, 4, 2, 1, 6, 5];
  for (const type of priority) {
    const match = releaseDates.find((d) => d.type === type && d.certification);
    if (match?.certification) return match.certification;
  }
  const any = releaseDates.find((d) => d.certification);
  return any?.certification || null;
}

export function formatCertifications(parts) {
  if (!parts.length) return null;
  if (parts.length === 1) return parts[0].cert;
  return parts.map((p) => `${p.cert} (${p.code})`).join(' · ');
}

export function movieCertification(releaseDatesData) {
  const results = releaseDatesData?.results || [];
  const parts = [];

  for (const code of watchRegionsInOrder()) {
    const country = results.find((r) => r.iso_3166_1 === code);
    const cert = pickMovieCert(country?.release_dates);
    if (cert) parts.push({ code, cert });
  }

  return formatCertifications(parts);
}

export function tvCertification(contentRatingsData) {
  const results = contentRatingsData?.results || [];
  const parts = [];

  for (const code of watchRegionsInOrder()) {
    const entry = results.find((r) => r.iso_3166_1 === code);
    if (entry?.rating) parts.push({ code, cert: entry.rating });
  }

  return formatCertifications(parts);
}
