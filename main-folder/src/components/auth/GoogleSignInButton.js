import { useEffect, useRef, useState } from 'react';
import { GoogleLogin } from '@react-oauth/google';

const clientId = process.env.REACT_APP_GOOGLE_CLIENT_ID;
const MIN_BTN_WIDTH = 200;

export default function GoogleSignInButton({ onSuccess, onError, mode = 'signin' }) {
  const containerRef = useRef(null);
  const [btnWidth, setBtnWidth] = useState(0);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return undefined;

    const update = () => {
      const w = Math.floor(el.getBoundingClientRect().width);
      setBtnWidth(Math.max(MIN_BTN_WIDTH, w));
    };

    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    window.addEventListener('resize', update);

    return () => {
      ro.disconnect();
      window.removeEventListener('resize', update);
    };
  }, []);

  if (!clientId) return null;

  return (
    <div className="space-y-4">
      <div ref={containerRef} className="google-signin-container w-full max-w-full">
        {btnWidth > 0 && (
          <GoogleLogin
            onSuccess={onSuccess}
            onError={onError}
            text={mode === 'signup' ? 'signup_with' : 'signin_with'}
            theme="outline"
            size="large"
            width={String(btnWidth)}
          />
        )}
      </div>
      <div className="relative py-1">
        <div className="absolute inset-0 flex items-center">
          <div className="w-full border-t border-border" />
        </div>
        <div className="relative flex justify-center">
          <span className="bg-surface px-3 text-xs font-medium uppercase tracking-wider text-muted">
            or
          </span>
        </div>
      </div>
    </div>
  );
}

export function isGoogleAuthEnabled() {
  return Boolean(clientId);
}
