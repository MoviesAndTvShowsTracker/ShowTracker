import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext';
import Main from './components/MainComponent';

function App() {
  return (
    <BrowserRouter>
      <ThemeProvider>
        <AuthProvider>
          <Main />
        </AuthProvider>
      </ThemeProvider>
    </BrowserRouter>
  );
}

export default App;
