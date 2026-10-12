import { useLocation, useNavigationType } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useActiveMobileTab } from '../utils/mobileTabs';

export default function PageTransition({ children }) {
  const location = useLocation();
  const navigationType = useNavigationType();
  const { isAuthenticated } = useAuth();
  const tabId = useActiveMobileTab(isAuthenticated);
  // Skip the opacity flash when the user hits Back/Forward.
  const animate = navigationType !== 'POP';

  return (
    <div
      key={tabId || location.pathname}
      className={animate ? 'page-tab-enter' : undefined}
    >
      {children}
    </div>
  );
}
