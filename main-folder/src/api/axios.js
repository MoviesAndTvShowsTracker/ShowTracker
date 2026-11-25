import axios from 'axios';

const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL || 'http://localhost:5001',
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use(
  (config) => {
    const url = config.url || '';
    const isAuthRoute =
      url.includes('/users/login') ||
      url.includes('/users/signup') ||
      url.includes('/users/google') ||
      url.includes('/users/forgot-password') ||
      url.includes('/users/reset-password');
    const token = localStorage.getItem('token');
    if (token && !isAuthRoute) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    if (config.data instanceof FormData) {
      delete config.headers['Content-Type'];
    }
    return config;
  },
  (error) => Promise.reject(error)
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status;
    const url = error.config?.url || '';
    const current = localStorage.getItem('token');
    const hadToken = Boolean(current);
    // Only a 401 for the token we hold now ends the session; one for an older token
    // (a request in flight while the password changed) doesn't.
    const sentAuth = error.config?.headers?.Authorization || error.config?.headers?.authorization;
    const forCurrentToken = !sentAuth || sentAuth === `Bearer ${current}`;
    const isAuthRoute =
      url.includes('/users/login') ||
      url.includes('/users/signup') ||
      url.includes('/users/google') ||
      url.includes('/users/forgot-password') ||
      url.includes('/users/reset-password');

    if (status === 401 && hadToken && forCurrentToken && !isAuthRoute) {
      localStorage.removeItem('token');
      localStorage.removeItem('userId');
      localStorage.removeItem('email');
      localStorage.removeItem('firstName');
      localStorage.removeItem('username');
      window.dispatchEvent(new Event('auth:session-expired'));
    }

    return Promise.reject(error);
  }
);

export default api;
