import { GoogleOAuthProvider } from '@react-oauth/google';
import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext';
import Main from './components/MainComponent';

const googleClientId = process.env.REACT_APP_GOOGLE_CLIENT_ID || '';

function App() {
  const app = (
    <BrowserRouter>
      <ThemeProvider>
        <AuthProvider>
          <Main />
        </AuthProvider>
      </ThemeProvider>
    </BrowserRouter>
  );

  if (!googleClientId) return app;

  return <GoogleOAuthProvider clientId={googleClientId}>{app}</GoogleOAuthProvider>;
}

export default App;
