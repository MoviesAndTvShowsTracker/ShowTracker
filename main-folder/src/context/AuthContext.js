import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import api from '../api/axios';

const AuthContext = createContext(null);

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
    localStorage.removeItem('token');
    localStorage.removeItem('userId');
    localStorage.removeItem('username');
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
    const username = localStorage.getItem('username');

    if (!token || !userId) {
      setLoading(false);
      return;
    }

    api
      .get(`/users/getUser/${userId}`)
      .then(() => {
        setUser({ id: userId, token, username: username || '' });
      })
      .catch(() => {
        clearSession();
      })
      .finally(() => setLoading(false));
  }, [clearSession]);

  const login = async (credentials) => {
    try {
      const response = await api.post('/users/login', credentials);
      if (response.data.status === 200 && response.data.token) {
        localStorage.setItem('token', response.data.token);
        localStorage.setItem('userId', response.data.userId);
        localStorage.setItem('username', credentials.username);
        setUser({
          id: response.data.userId,
          token: response.data.token,
          username: credentials.username,
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
          'Invalid username or password',
      };
    }
  };

  const register = async (userData) => {
    try {
      const response = await api.post('/users/signup', userData);
      if (response.data.status === 200) {
        return { success: true };
      }
      return { success: false, message: response.data.err || 'Registration failed' };
    } catch (error) {
      return {
        success: false,
        message: error.response?.data?.err?.message || error.message || 'Registration failed',
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

  const value = {
    user,
    loading,
    isAuthenticated: Boolean(user),
    login,
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
