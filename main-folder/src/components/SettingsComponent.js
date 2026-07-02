import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../api/axios';
import { useAuth } from '../context/AuthContext';
import PageTitle from '../utils/PageTitle';
import BackNav from './ui/BackNav';
import TvTimeImportSection from './settings/TvTimeImportSection';

export default function Settings() {
  const { user } = useAuth();
  const [profile, setProfile] = useState({
    firstName: '',
    lastName: '',
    email: '',
    phonenumber: '',
  });
  const [profileSaving, setProfileSaving] = useState(false);
  const [profileMessage, setProfileMessage] = useState('');
  const [profileError, setProfileError] = useState('');

  const [passwords, setPasswords] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });
  const [passwordSaving, setPasswordSaving] = useState(false);
  const [passwordMessage, setPasswordMessage] = useState('');
  const [passwordError, setPasswordError] = useState('');

  useEffect(() => {
    if (!user?.id) return;
    api
      .get(`/users/getUser/${user.id}`)
      .then((r) => {
        if (r.data.success && r.data.found) {
          const u = r.data.found;
          setProfile({
            firstName: u.firstName || '',
            lastName: u.lastName || '',
            email: u.email || '',
            phonenumber: u.phonenumber ? String(u.phonenumber) : '',
          });
        }
      })
      .catch(() => setProfileError('Could not load your profile.'));
    window.scrollTo(0, 0);
  }, [user?.id]);

  const saveProfile = async (e) => {
    e.preventDefault();
    setProfileError('');
    setProfileMessage('');

    if (!profile.firstName.trim() || !profile.lastName.trim() || !profile.email.trim()) {
      setProfileError('First name, last name, and email are required.');
      return;
    }
    if (profile.phonenumber && !/^\d{10}$/.test(profile.phonenumber)) {
      setProfileError('Phone must be 10 digits or left empty.');
      return;
    }

    setProfileSaving(true);
    try {
      const r = await api.post('/users/updateProfile', {
        firstName: profile.firstName.trim(),
        lastName: profile.lastName.trim(),
        email: profile.email.trim(),
        phonenumber: profile.phonenumber.trim(),
      });
      if (r.data.success) {
        setProfileMessage('Profile updated.');
      } else {
        setProfileError(r.data.message || 'Could not update profile.');
      }
    } catch (err) {
      setProfileError(err.response?.data?.message || 'Could not update profile.');
    } finally {
      setProfileSaving(false);
    }
  };

  const changePassword = async (e) => {
    e.preventDefault();
    setPasswordError('');
    setPasswordMessage('');

    if (!passwords.currentPassword || !passwords.newPassword) {
      setPasswordError('Enter your current and new password.');
      return;
    }
    if (passwords.newPassword.length < 6) {
      setPasswordError('New password must be at least 6 characters.');
      return;
    }
    if (passwords.newPassword !== passwords.confirmPassword) {
      setPasswordError('New passwords do not match.');
      return;
    }

    setPasswordSaving(true);
    try {
      const r = await api.post('/users/changePassword', {
        currentPassword: passwords.currentPassword,
        newPassword: passwords.newPassword,
      });
      if (r.data.success) {
        setPasswordMessage('Password updated.');
        setPasswords({ currentPassword: '', newPassword: '', confirmPassword: '' });
      } else {
        setPasswordError(r.data.message || 'Could not change password.');
      }
    } catch (err) {
      setPasswordError(err.response?.data?.message || 'Could not change password.');
    } finally {
      setPasswordSaving(false);
    }
  };

  return (
    <>
      <PageTitle title="Settings" />

      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-10">
        <BackNav fallback="/profile" label="Back to profile" className="mb-4" />

        <header className="mb-8">
          <p className="text-xs font-bold uppercase tracking-[0.15em] text-accent">Account</p>
          <h1 className="page-title mt-2">Settings</h1>
          <p className="mt-2 text-sm text-muted">
            Signed in as <span className="font-medium text-ink">{user?.username}</span>
          </p>
        </header>

        <div className="mx-auto max-w-lg space-y-8">
          <section className="glass-card p-5 sm:p-6">
            <h2 className="section-title mb-4 normal-case tracking-wide">Profile</h2>
            <form onSubmit={saveProfile} className="space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="firstName" className="section-title mb-2 block normal-case tracking-wide">
                    First name
                  </label>
                  <input
                    id="firstName"
                    className="input-field"
                    value={profile.firstName}
                    onChange={(e) => setProfile({ ...profile, firstName: e.target.value })}
                    autoComplete="given-name"
                  />
                </div>
                <div>
                  <label htmlFor="lastName" className="section-title mb-2 block normal-case tracking-wide">
                    Last name
                  </label>
                  <input
                    id="lastName"
                    className="input-field"
                    value={profile.lastName}
                    onChange={(e) => setProfile({ ...profile, lastName: e.target.value })}
                    autoComplete="family-name"
                  />
                </div>
              </div>
              <div>
                <label htmlFor="email" className="section-title mb-2 block normal-case tracking-wide">
                  Email
                </label>
                <input
                  id="email"
                  type="email"
                  className="input-field"
                  value={profile.email}
                  onChange={(e) => setProfile({ ...profile, email: e.target.value })}
                  autoComplete="email"
                />
              </div>
              <div>
                <label htmlFor="phone" className="section-title mb-2 block normal-case tracking-wide">
                  Phone
                </label>
                <input
                  id="phone"
                  type="tel"
                  className="input-field"
                  placeholder="10-digit number"
                  maxLength={10}
                  value={profile.phonenumber}
                  onChange={(e) => setProfile({ ...profile, phonenumber: e.target.value.replace(/\D/g, '') })}
                  autoComplete="tel"
                />
              </div>
              {profileError && <p className="text-sm text-red-400">{profileError}</p>}
              {profileMessage && <p className="text-sm text-accent">{profileMessage}</p>}
              <button type="submit" disabled={profileSaving} className="btn-primary w-full sm:w-auto">
                {profileSaving ? 'Saving…' : 'Save profile'}
              </button>
            </form>
          </section>

          <section className="glass-card p-5 sm:p-6">
            <h2 className="section-title mb-4 normal-case tracking-wide">Password</h2>
            <form onSubmit={changePassword} className="space-y-4">
              <div>
                <label htmlFor="currentPassword" className="section-title mb-2 block normal-case tracking-wide">
                  Current password
                </label>
                <input
                  id="currentPassword"
                  type="password"
                  className="input-field"
                  value={passwords.currentPassword}
                  onChange={(e) => setPasswords({ ...passwords, currentPassword: e.target.value })}
                  autoComplete="current-password"
                />
              </div>
              <div>
                <label htmlFor="newPassword" className="section-title mb-2 block normal-case tracking-wide">
                  New password
                </label>
                <input
                  id="newPassword"
                  type="password"
                  className="input-field"
                  value={passwords.newPassword}
                  onChange={(e) => setPasswords({ ...passwords, newPassword: e.target.value })}
                  autoComplete="new-password"
                />
              </div>
              <div>
                <label htmlFor="confirmPassword" className="section-title mb-2 block normal-case tracking-wide">
                  Confirm new password
                </label>
                <input
                  id="confirmPassword"
                  type="password"
                  className="input-field"
                  value={passwords.confirmPassword}
                  onChange={(e) => setPasswords({ ...passwords, confirmPassword: e.target.value })}
                  autoComplete="new-password"
                />
              </div>
              {passwordError && <p className="text-sm text-red-400">{passwordError}</p>}
              {passwordMessage && <p className="text-sm text-accent">{passwordMessage}</p>}
              <button type="submit" disabled={passwordSaving} className="btn-primary w-full sm:w-auto">
                {passwordSaving ? 'Updating…' : 'Change password'}
              </button>
            </form>
          </section>

          <TvTimeImportSection />

          <p className="text-center text-sm text-muted">
            <Link to="/profile" className="text-link hover:text-ink-bright cursor-pointer">
              View your diary
            </Link>
          </p>
        </div>
      </div>
    </>
  );
}
