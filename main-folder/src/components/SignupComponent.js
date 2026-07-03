import { useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import PageTitle from '../utils/PageTitle';
import { useAuth } from '../context/AuthContext';
import { BRAND_NAME } from '../config/brand';
import BackNav from './ui/BackNav';
import MarqueeLogo from './brand/MarqueeLogo';
import GoogleSignInButton from './auth/GoogleSignInButton';

const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function Signup() {
  const { register, loginWithGoogle, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({
    email: '',
    password: '',
  });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [googleSubmitting, setGoogleSubmitting] = useState(false);

  if (isAuthenticated) return <Navigate to="/home" replace />;
  if (success) return <Navigate to="/login" replace />;

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
    if (!emailRegex.test(form.email) || form.password.length < 6) {
      setError('Enter a valid email and password (min. 6 characters).');
      return;
    }
    setSubmitting(true);
    const result = await register({
      email: form.email.trim(),
      password: form.password,
    });
    setSubmitting(false);
    if (result.success) setSuccess(true);
    else setError(result.message || 'Registration failed');
  };

  const fields = [
    { name: 'email', label: 'Email', type: 'email' },
    { name: 'password', label: 'Password', type: 'password' },
  ];

  return (
    <div className="mx-auto max-w-content px-4 py-10 sm:px-6 md:py-16">
      <PageTitle title="Create account" />
      <div className="mx-auto max-w-md">
        <BackNav fallback="/" label="Back to home" className="mb-6" />
        <div className="mb-5 flex items-center gap-2.5">
          <MarqueeLogo className="h-9 w-9 text-ink-bright" />
          <span className="font-serif text-2xl font-semibold text-ink-bright">{BRAND_NAME}</span>
        </div>
        <p className="text-xs font-bold uppercase tracking-[0.15em] text-accent">Join {BRAND_NAME}</p>
        <h1 className="page-title mt-2">Start your watch diary</h1>
        <p className="mt-2 text-sm text-muted">
          Track films, save favorites, and build watchlists — free forever.
        </p>

        <div className="auth-card mt-8">
          <GoogleSignInButton
            mode="signup"
            onSuccess={handleGoogleSuccess}
            onError={() => setError('Google sign-in failed. Try again.')}
          />

          <form onSubmit={handleSubmit} className="space-y-4">
            {fields.map(({ name, label, type = 'text' }) => (
              <div key={name}>
                <label htmlFor={name} className="section-title mb-2 block normal-case tracking-wide">
                  {label}
                </label>
                <input
                  id={name}
                  type={type}
                  className="input-field"
                  value={form[name]}
                  onChange={(e) => setForm((p) => ({ ...p, [name]: e.target.value }))}
                  autoComplete={name === 'email' ? 'email' : 'new-password'}
                  disabled={googleSubmitting}
                />
              </div>
            ))}
            {error && <p className="text-sm text-red-400">{error}</p>}
            <button
              type="submit"
              disabled={submitting || googleSubmitting}
              className="btn-primary w-full disabled:opacity-50"
            >
              {submitting ? 'Creating account…' : 'Create account'}
            </button>
          </form>
        </div>

        <p className="mt-6 text-center text-sm text-muted">
          Already tracking?{' '}
          <Link to="/login" className="font-semibold text-link hover:text-ink-bright cursor-pointer">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
