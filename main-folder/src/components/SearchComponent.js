import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Search } from 'lucide-react';
import { API_KEY, API_URL, IMAGE_URL } from '../config/keys';
import GridCard from './Movies/GridCard';
import TvGridCard from './TV/TvGridCard';
import PageTitle from '../utils/PageTitle';

export default function SearchBox() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedOption, setSelectedOption] = useState('');
  const [results, setResults] = useState([]);
  const [error, setError] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    setError('');

    if (!selectedOption) {
      setError('Please select Movies or TV Shows.');
      return;
    }
    if (!searchQuery.trim()) {
      setError('Please enter a search term.');
      return;
    }

    const url = `${API_URL}search/${selectedOption}?api_key=${API_KEY}&language=en-US&query=${encodeURI(searchQuery)}&page=1&include_adult=false`;
    fetch(url)
      .then((response) => response.json())
      .then((response) => {
        setResults(response.results || []);
        if (!response.results?.length) {
          setError('No results found.');
        }
      });
  };

  return (
    <>
      <PageTitle title={searchQuery ? `Search ${searchQuery}` : 'Search Movies and TV Shows'} />

      <div className="mx-auto max-w-content px-4 py-6 sm:px-6 md:py-8">
        <nav aria-label="Breadcrumb" className="mb-4 hidden text-xs text-muted md:mb-6 md:block">
          <Link to="/" className="hover:text-ink-bright cursor-pointer">Home</Link>
          <span className="mx-1.5">/</span>
          <span className="text-ink">Search</span>
        </nav>

        <h1 className="page-title mb-5 md:hidden">Search</h1>

        <form onSubmit={handleSubmit} className="mx-auto max-w-xl space-y-4">
          <div className="flex gap-2">
            <input
              className="input-field min-h-[44px] text-base"
              type="search"
              placeholder="Movies or TV shows…"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              name="searchQuery"
            />
            <button type="submit" className="btn-primary shrink-0 !px-4" aria-label="Search">
              <Search className="h-5 w-5" />
            </button>
          </div>

          <div className="flex gap-4">
            <label className="flex min-h-[44px] flex-1 cursor-pointer items-center justify-center gap-2 rounded-sm border border-border bg-surface text-sm transition-colors has-[:checked]:border-accent has-[:checked]:bg-accent/10">
              <input
                type="radio"
                name="type"
                value="movie"
                checked={selectedOption === 'movie'}
                onChange={(e) => setSelectedOption(e.target.value)}
                className="sr-only"
              />
              <span className={selectedOption === 'movie' ? 'font-semibold text-accent' : 'text-muted'}>Films</span>
            </label>
            <label className="flex min-h-[44px] flex-1 cursor-pointer items-center justify-center gap-2 rounded-sm border border-border bg-surface text-sm transition-colors has-[:checked]:border-accent has-[:checked]:bg-accent/10">
              <input
                type="radio"
                name="type"
                value="tv"
                checked={selectedOption === 'tv'}
                onChange={(e) => setSelectedOption(e.target.value)}
                className="sr-only"
              />
              <span className={selectedOption === 'tv' ? 'font-semibold text-accent' : 'text-muted'}>TV</span>
            </label>
          </div>

          {error && (
            <p className="rounded-sm border border-accent/30 bg-accent/10 px-4 py-3 text-sm text-accent">
              {error}
            </p>
          )}
        </form>

        {results.length > 0 && (
          <div className="mt-8 md:mt-12">
            <h2 className="section-title mb-4">Results</h2>
            <div className="poster-grid">
              {selectedOption === 'movie'
                ? results.map(
                    (movie) =>
                      movie.poster_path && (
                        <GridCard
                          key={movie.id}
                          image={`${IMAGE_URL}w500${movie.poster_path}`}
                          movieId={movie.id}
                          movieTitle={movie.title}
                        />
                      )
                  )
                : results.map(
                    (tvshow) =>
                      tvshow.poster_path && (
                        <TvGridCard
                          key={tvshow.id}
                          image={`${IMAGE_URL}w500${tvshow.poster_path}`}
                          tvShowId={tvshow.id}
                          tvShowTitle={tvshow.name}
                        />
                      )
                  )}
            </div>
          </div>
        )}
      </div>
    </>
  );
}
