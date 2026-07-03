import { useState } from 'react';
import { Link, Navigate, useLocation, useNavigate } from 'react-router-dom';
import PageTitle from '../utils/PageTitle';
import { useAuth } from '../context/AuthContext';
import BackNav from './ui/BackNav';
import MarqueeLogo from './brand/MarqueeLogo';
import { BRAND_NAME } from '../config/brand';
import GoogleSignInButton from './auth/GoogleSignInButton';

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function Signin() {
  const { login, loginWithGoogle, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const passwordReset = location.state?.passwordReset;
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [googleSubmitting, setGoogleSubmitting] = useState(false);

  if (isAuthenticated) return <Navigate to="/home" replace />;

  const handleGoogleSuccess = async (credentialResponse) => {
    if (!credentialResponse?.credential) {
      setError('Google sign-in failed. Try again.');
      return;
    }
    setError('');
    setGoogleSubmitting(true);
    const result = await loginWithGoogle(credentialResponse.credential);
    setGoogleSubmitting(false);
    if (result.success) navigate('/home');
    else setError(result.message || 'Google sign-in failed');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!emailRegex.test(email) || !password) {
      setError('Please enter your email and password.');
      return;
    }
    setSubmitting(true);
    const result = await login({ email: email.trim(), password });
    setSubmitting(false);
    if (result.success) navigate('/home');
    else setError(result.message || 'Sign in failed');
  };

  return (
    <div className="mx-auto max-w-content px-4 py-10 sm:px-6 md:py-16">
      <PageTitle title="Sign in" />
      <div className="mx-auto max-w-md">
        <BackNav fallback="/" label="Back to home" className="mb-6" />
        <div className="mb-5 flex items-center gap-2.5">
          <MarqueeLogo className="h-9 w-9 text-ink-bright" />
          <span className="font-serif text-2xl font-semibold text-ink-bright">{BRAND_NAME}</span>
        </div>
        <p className="text-xs font-bold uppercase tracking-[0.15em] text-accent">Welcome back</p>
        <h1 className="page-title mt-2">Sign in to your diary</h1>
        <p className="mt-2 text-sm text-muted">
          Access your watched list, favorites, and watchlists.
        </p>

        <div className="auth-card mt-8">
          <GoogleSignInButton
            mode="signin"
            onSuccess={handleGoogleSuccess}
            onError={() => setError('Google sign-in failed. Try again.')}
          />

          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label htmlFor="email" className="section-title mb-2 block normal-case tracking-wide">
                Email
              </label>
              <input
                id="email"
                type="email"
                className="input-field"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
                disabled={googleSubmitting}
              />
            </div>
            <div>
              <div className="mb-2 flex items-center justify-between gap-2">
                <label htmlFor="password" className="section-title block normal-case tracking-wide">
                  Password
                </label>
                <Link
                  to="/forgot-password"
                  className="text-xs font-semibold text-link hover:text-ink-bright"
                >
                  Forgot password?
                </Link>
              </div>
              <input
                id="password"
                type="password"
                className="input-field"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
                disabled={googleSubmitting}
              />
            </div>
            {passwordReset && (
              <p className="text-sm text-accent">Password updated. Sign in with your new password.</p>
            )}
            {error && <p className="text-sm text-red-400">{error}</p>}
            <button
              type="submit"
              disabled={submitting || googleSubmitting}
              className="btn-primary w-full disabled:opacity-50"
            >
              {submitting ? 'Signing in…' : 'Sign in'}
            </button>
          </form>
        </div>

        <p className="mt-6 text-center text-sm text-muted">
          New here?{' '}
          <Link to="/signup" className="font-semibold text-link hover:text-ink-bright cursor-pointer">
            Create a free account
          </Link>
        </p>
      </div>
    </div>
  );
}
