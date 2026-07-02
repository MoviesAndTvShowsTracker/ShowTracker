import { Routes, Route, Navigate, Outlet } from 'react-router-dom';
import Header from './HeaderComponent';
import Footer from './FooterComponent';
import Home from './HomeComponent';
import HomeDashboard from './HomeDashboard';
import Signup from './SignupComponent';
import Signin from './SigninComponent';
import Profile from './ProfileComponent';
import LandingPage from './Movies/LandingComponent';
import MovieDetail from './Movies/MovieDetail';
import TvDetail from './TV/TvShowDetail';
import TvLandingPage from './TV/TvLandingComponent';
import SearchBox from './SearchComponent';
import SeasonEpisodes from './TV/SeasonEpisodes';
import TvContinue from './TV/TvContinue';
import ScrollToTop from './ScrollToTop';
import { useAuth } from '../context/AuthContext';

function ProtectedRoute() {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? <Outlet /> : <Navigate to="/login" replace />;
}

function AppLayout() {
  return (
    <>
      <Header />
      <main className="page-content min-h-[calc(100vh-3.5rem)] pb-[calc(5.75rem+env(safe-area-inset-bottom))] md:min-h-screen md:pb-0">
        <Outlet />
      </main>
      <Footer />
    </>
  );
}

export default function Main() {
  return (
    <>
      <ScrollToTop />
      <Routes>
        <Route element={<AppLayout />}>
          <Route path="/" element={<Home />} />
          <Route path="/login" element={<Signin />} />
          <Route path="/signup" element={<Signup />} />
          <Route path="/search" element={<SearchBox />} />

          <Route element={<ProtectedRoute />}>
            <Route path="/home" element={<HomeDashboard />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="/movies" element={<LandingPage />} />
            <Route path="/movies/:Id" element={<MovieDetail />} />
            <Route path="/tv" element={<TvLandingPage />} />
            <Route path="/tv/:Id/continue" element={<TvContinue />} />
            <Route path="/tv/:Id" element={<TvDetail />} />
            <Route path="/tv/:Id/:seasonNumber/episodes" element={<SeasonEpisodes />} />
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </>
  );
}
