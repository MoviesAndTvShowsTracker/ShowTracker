import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import api from '../api/axios';

const AuthContext = createContext(null);

function persistUser(session) {
  localStorage.setItem('token', session.token);
  localStorage.setItem('userId', session.id);
  localStorage.setItem('email', session.email || '');
  if (session.firstName) localStorage.setItem('firstName', session.firstName);
  else localStorage.removeItem('firstName');
}

function clearStoredUser() {
  localStorage.removeItem('token');
  localStorage.removeItem('userId');
  localStorage.removeItem('email');
  localStorage.removeItem('firstName');
  localStorage.removeItem('username');
}

function userFromApi(userId, token, u) {
  return {
    id: userId,
    token,
    email: u.email || '',
    firstName: u.firstName || '',
    username: u.username || '',
  };
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const clearSession = useCallback(() => {
    clearStoredUser();
    setUser(null);
  }, []);

  useEffect(() => {
    const onSessionExpired = () => setUser(null);
    window.addEventListener('auth:session-expired', onSessionExpired);
    return () => window.removeEventListener('auth:session-expired', onSessionExpired);
  }, []);

  useEffect(() => {
    const token = localStorage.getItem('token');
    const userId = localStorage.getItem('userId');

    if (!token || !userId) {
      setLoading(false);
      return;
    }

    api
      .get(`/users/getUser/${userId}`)
      .then((r) => {
        if (r.data.success && r.data.found) {
          const session = userFromApi(userId, token, r.data.found);
          setUser(session);
          persistUser(session);
        } else {
          clearSession();
        }
      })
      .catch(() => {
        clearSession();
      })
      .finally(() => setLoading(false));
  }, [clearSession]);

  const applySession = (userId, token, profile = {}) => {
    const session = {
      id: userId,
      token,
      email: profile.email || '',
      firstName: profile.firstName || '',
      username: profile.username || '',
    };
    persistUser(session);
    setUser(session);
    return session;
  };

  const login = async (credentials) => {
    try {
      const response = await api.post('/users/login', credentials);
      if (response.data.status === 200 && response.data.token) {
        applySession(response.data.userId, response.data.token, {
          email: response.data.email || credentials.email,
          firstName: response.data.firstName,
        });
        return { success: true };
      }
      return { success: false, message: response.data.message || 'Login failed' };
    } catch (error) {
      return {
        success: false,
        message:
          error.response?.data?.message ||
          error.response?.data?.err?.message ||
          'Invalid email or password',
      };
    }
  };

  const register = async (userData) => {
    try {
      const response = await api.post('/users/signup', userData);
      if (response.data.status === 200) {
        return { success: true };
      }
      return { success: false, message: response.data.err || response.data.message || 'Registration failed' };
    } catch (error) {
      const data = error.response?.data;
      return {
        success: false,
        message:
          (typeof data?.err === 'string' ? data.err : data?.err?.message) ||
          data?.message ||
          error.message ||
          'Registration failed',
      };
    }
  };

  const logout = async () => {
    try {
      await api.get('/users/logout');
    } catch (err) {
      console.error('Logout error', err);
    } finally {
      clearSession();
    }
  };

  const loginWithGoogle = async (idToken) => {
    try {
      const response = await api.post('/users/google', { idToken });
      if (response.data.success && response.data.token) {
        applySession(response.data.userId, response.data.token, {
          email: response.data.email,
          firstName: response.data.firstName,
          username: response.data.username,
        });
        return { success: true };
      }
      return { success: false, message: response.data.message || 'Google sign-in failed' };
    } catch (error) {
      return {
        success: false,
        message: error.response?.data?.message || 'Google sign-in failed',
      };
    }
  };

  const value = {
    user,
    loading,
    isAuthenticated: Boolean(user),
    login,
    loginWithGoogle,
    register,
    logout,
  };

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-canvas">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-border border-t-accent" />
      </div>
    );
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
