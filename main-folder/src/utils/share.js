import { BRAND_NAME } from '../config/brand';

function appUrl(path = '') {
  const base = window.location.origin;
  return path ? `${base}${path.startsWith('/') ? path : `/${path}`}` : base;
}

export async function shareWatching({ title, subtitle, path, progress }) {
  const url = appUrl(path);
  let text = subtitle || `I'm watching ${title} on ${BRAND_NAME}`;
  if (progress != null && progress > 0) {
    text = `I'm watching ${title} on ${BRAND_NAME} — ${Math.round(progress)}% through!`;
  }

  if (navigator.share) {
    try {
      await navigator.share({ title, text, url });
      return { ok: true, method: 'share' };
    } catch (err) {
      if (err?.name === 'AbortError') return { ok: false, cancelled: true };
    }
  }

  try {
    await navigator.clipboard.writeText(`${text}\n${url}`);
    return { ok: true, method: 'clipboard' };
  } catch {
    return { ok: false };
  }
}
