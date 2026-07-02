import { useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import PageTitle from '../utils/PageTitle';
import { useAuth } from '../context/AuthContext';
import BackNav from './ui/BackNav';
import MarqueeLogo from './brand/MarqueeLogo';
import { BRAND_NAME } from '../config/brand';

export default function Signin() {
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  if (isAuthenticated) return <Navigate to="/profile" replace />;

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!username || !password) {
      setError('Please enter your username and password.');
      return;
    }
    setSubmitting(true);
    const result = await login({ username, password });
    setSubmitting(false);
    if (result.success) navigate('/profile');
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
          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label htmlFor="username" className="section-title mb-2 block normal-case tracking-wide">
                Username
              </label>
              <input
                id="username"
                className="input-field"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                autoComplete="username"
              />
            </div>
            <div>
              <label htmlFor="password" className="section-title mb-2 block normal-case tracking-wide">
                Password
              </label>
              <input
                id="password"
                type="password"
                className="input-field"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password"
              />
            </div>
            {error && <p className="text-sm text-red-400">{error}</p>}
            <button type="submit" disabled={submitting} className="btn-primary w-full disabled:opacity-50">
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
