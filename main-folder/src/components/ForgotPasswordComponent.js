import { useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../api/axios';
import PageTitle from '../utils/PageTitle';
import BackNav from './ui/BackNav';
import MarqueeLogo from './brand/MarqueeLogo';
import { BRAND_NAME } from '../config/brand';

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function ForgotPassword() {
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [sentTo, setSentTo] = useState('');
  const [emailDispatched, setEmailDispatched] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    const trimmed = email.trim();
    if (!emailRegex.test(trimmed)) {
      setError('Enter a valid email address.');
      return;
    }

    setSubmitting(true);
    try {
      const r = await api.post('/users/forgot-password', { email: trimmed });
      if (r.data.success) {
        setSentTo(trimmed);
        setEmailDispatched(Boolean(r.data.emailDispatched));
      } else {
        setError(r.data.message || 'Something went wrong. Try again.');
      }
    } catch (err) {
      setError(err.response?.data?.message || 'Something went wrong. Try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const resetForm = () => {
    setSentTo('');
    setEmailDispatched(false);
    setError('');
  };

  return (
    <div className="mx-auto max-w-content px-4 py-10 sm:px-6 md:py-16">
      <PageTitle title="Forgot password" />
      <div className="mx-auto max-w-md">
        <BackNav fallback="/login" label="Back to sign in" className="mb-6" />
        <div className="mb-5 flex items-center gap-2.5">
          <MarqueeLogo className="h-9 w-9 text-ink-bright" />
          <span className="font-serif text-2xl font-semibold text-ink-bright">{BRAND_NAME}</span>
        </div>

        {sentTo ? (
          <div className="auth-card mt-8 text-center">
            <div
              className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-accent/15 text-2xl text-accent"
              aria-hidden
            >
              ✓
            </div>
            <h1 className="page-title text-xl sm:text-2xl">
              {emailDispatched ? 'Reset link sent' : 'Request received'}
            </h1>
            {emailDispatched ? (
              <>
                <p className="mt-3 text-sm text-muted">
                  We emailed a password reset link to{' '}
                  <span className="font-semibold text-ink-bright">{sentTo}</span>.
                </p>
                <p className="mt-2 text-sm text-muted">
                  The link expires in 1 hour. Check your spam folder if you don&apos;t see it within a few minutes.
                </p>
                <p className="mt-2 text-xs text-muted-dim">
                  Signed up with Google? This link lets you set a password so you can sign in with email too.
                </p>
              </>
            ) : (
              <p className="mt-3 text-sm text-muted">
                If an account exists for{' '}
                <span className="font-semibold text-ink-bright">{sentTo}</span>, we&apos;ll send a reset link shortly.
                Check your inbox and spam folder.
              </p>
            )}
            <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:justify-center">
              <Link to="/login" className="btn-primary inline-block text-center">
                Back to sign in
              </Link>
              <button type="button" onClick={resetForm} className="btn-secondary w-full sm:w-auto">
                Try another email
              </button>
            </div>
          </div>
        ) : (
          <>
            <p className="text-xs font-bold uppercase tracking-[0.15em] text-accent">Account recovery</p>
            <h1 className="page-title mt-2">Reset your password</h1>
            <p className="mt-2 text-sm text-muted">
              Enter your email and we&apos;ll send you a link to choose a new password.
            </p>

            <div className="auth-card mt-8">
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
                    disabled={submitting}
                  />
                </div>
                {error && <p className="text-sm text-red-400">{error}</p>}
                <button type="submit" disabled={submitting} className="btn-primary w-full disabled:opacity-50">
                  {submitting ? 'Sending…' : 'Send reset link'}
                </button>
              </form>
            </div>
          </>
        )}

        {!sentTo && (
          <p className="mt-6 text-center text-sm text-muted">
            Remember your password?{' '}
            <Link to="/login" className="font-semibold text-link hover:text-ink-bright cursor-pointer">
              Sign in
            </Link>
          </p>
        )}
      </div>
    </div>
  );
}
