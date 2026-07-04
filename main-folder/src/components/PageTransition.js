import { useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useActiveMobileTab } from '../utils/mobileTabs';

export default function PageTransition({ children }) {
  const location = useLocation();
  const { isAuthenticated } = useAuth();
  const tabId = useActiveMobileTab(isAuthenticated);

  return (
    <div key={tabId || location.pathname} className="page-tab-enter">
      {children}
    </div>
  );
}
