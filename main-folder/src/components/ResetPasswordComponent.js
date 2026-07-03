import { useState } from 'react';
import { Link, Navigate, useSearchParams } from 'react-router-dom';
import api from '../api/axios';
import PageTitle from '../utils/PageTitle';
import BackNav from './ui/BackNav';
import MarqueeLogo from './brand/MarqueeLogo';
import { BRAND_NAME } from '../config/brand';

export default function ResetPassword() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get('token') || '';

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  if (!token) {
    return (
      <div className="mx-auto max-w-content px-4 py-10 sm:px-6 md:py-16">
        <PageTitle title="Reset password" />
        <div className="mx-auto max-w-md text-center">
          <p className="text-sm text-red-400">This reset link is missing or invalid.</p>
          <Link to="/forgot-password" className="mt-4 inline-block text-sm font-semibold text-link hover:text-ink-bright">
            Request a new link
          </Link>
        </div>
      </div>
    );
  }

  if (success) return <Navigate to="/login" replace state={{ passwordReset: true }} />;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }

    setSubmitting(true);
    try {
      const r = await api.post('/users/reset-password', { token, newPassword: password });
      if (r.data.success) {
        setSuccess(true);
      } else {
        setError(r.data.message || 'Could not reset password.');
      }
    } catch (err) {
      setError(err.response?.data?.message || 'Could not reset password.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="mx-auto max-w-content px-4 py-10 sm:px-6 md:py-16">
      <PageTitle title="Choose new password" />
      <div className="mx-auto max-w-md">
        <BackNav fallback="/login" label="Back to sign in" className="mb-6" />
        <div className="mb-5 flex items-center gap-2.5">
          <MarqueeLogo className="h-9 w-9 text-ink-bright" />
          <span className="font-serif text-2xl font-semibold text-ink-bright">{BRAND_NAME}</span>
        </div>
        <p className="text-xs font-bold uppercase tracking-[0.15em] text-accent">Almost there</p>
        <h1 className="page-title mt-2">Choose a new password</h1>
        <p className="mt-2 text-sm text-muted">Enter a new password for your account.</p>

        <div className="auth-card mt-8">
          <form onSubmit={handleSubmit} className="space-y-5">
            <div>
              <label htmlFor="password" className="section-title mb-2 block normal-case tracking-wide">
                New password
              </label>
              <input
                id="password"
                type="password"
                className="input-field"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
                disabled={submitting}
              />
            </div>
            <div>
              <label htmlFor="confirmPassword" className="section-title mb-2 block normal-case tracking-wide">
                Confirm password
              </label>
              <input
                id="confirmPassword"
                type="password"
                className="input-field"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                autoComplete="new-password"
                disabled={submitting}
              />
            </div>
            {error && <p className="text-sm text-red-400">{error}</p>}
            <button type="submit" disabled={submitting} className="btn-primary w-full disabled:opacity-50">
              {submitting ? 'Updating…' : 'Update password'}
            </button>
          </form>
        </div>

        <p className="mt-6 text-center text-sm text-muted">
          Link expired?{' '}
          <Link to="/forgot-password" className="font-semibold text-link hover:text-ink-bright cursor-pointer">
            Request a new one
          </Link>
        </p>
      </div>
    </div>
  );
}
