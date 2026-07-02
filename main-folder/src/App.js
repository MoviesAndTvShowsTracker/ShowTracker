import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import Main from './components/MainComponent';

function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Main />
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;
