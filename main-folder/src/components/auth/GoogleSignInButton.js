import { GoogleLogin } from '@react-oauth/google';

const clientId = process.env.REACT_APP_GOOGLE_CLIENT_ID;

export default function GoogleSignInButton({ onSuccess, onError, mode = 'signin' }) {
  if (!clientId) return null;

  return (
    <div className="space-y-4">
      <div className="flex justify-center [&>div]:!w-full">
        <GoogleLogin
          onSuccess={onSuccess}
          onError={onError}
          text={mode === 'signup' ? 'signup_with' : 'signin_with'}
          theme="outline"
          size="large"
          width="384"
        />
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
