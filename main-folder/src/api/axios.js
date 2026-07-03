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
      url.includes('/users/google');
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
    const hadToken = Boolean(localStorage.getItem('token'));
    const isAuthRoute =
      url.includes('/users/login') ||
      url.includes('/users/signup') ||
      url.includes('/users/google');

    if (status === 401 && hadToken && !isAuthRoute) {
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
