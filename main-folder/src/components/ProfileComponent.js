import React, { useEffect, useState } from 'react';
import axios from 'axios';
import Popover from 'react-bootstrap/Popover';
import OverlayTrigger from 'react-bootstrap/OverlayTrigger';
import { IMAGE_URL } from '../config/keys';
import { Link } from 'react-router-dom';

const Profile = (props) => {

  const variable = { userFrom: localStorage.getItem('userId') }
  const [FavoritedMovies, setFavoritedMovies] = useState([]);
  const [WatchedMovies, setWatchedMovies] = useState([]);

  const fetchFavoriteMovies = () => {
    axios.post('http://localhost:5000/api/favorite/getFavoriteMovie', variable)
    .then(response => {
      if(response.data.success) {
        console.log(response.data.favorites);
        setFavoritedMovies(response.data.favorites);
      }
      else {
        alert("failed to fetch favorites");
      }
    })
  }

  const fetchWatchedMovies = () => {
    
    axios.post('http://localhost:5000/api/watch/getWatchMovie', variable)
    .then(response => {
      if(response.data.success) {
        console.log(response.data.watch);
        setWatchedMovies(response.data.watch);
      }
      else {
        alert("failed to fetch Watched movies");
      }
    })
  }

  const onClickRemove = (movieId) => {

    const variable = {
      movieId: movieId,
      userFrom: localStorage.getItem('userId')
    }

    axios.post('http://localhost:5000/api/favorite/removeFromFavorite', variable)
          .then(response => {
              if(response.data.success) {
                  fetchFavoriteMovies();
              }
              else {
                  alert('Failed to remove from Favorites');
              }
          })
  }

  const removeWatched = (movieId) => {

    const variable = {
      movieId: movieId,
      userFrom: localStorage.getItem('userId')
    }

    axios.post('http://localhost:5000/api/watch/removeFromWatched', variable)
          .then(response => {
              if(response.data.success) {
                  fetchWatchedMovies();
              }
              else {
                  alert('Failed to remove from Watched movies');
              }
          })
  }

  useEffect(() => {
    fetchFavoriteMovies();
    fetchWatchedMovies();
  }, []);

  

  const renderTableBody = FavoritedMovies.map((movie, index) => {
    
    const popover = (
      <Popover id="popover-basic">
        <Link to={`movie/${movie.movieId}`} className="text-decoration-none"><Popover.Title as="h3" alt="Favorites movies">{movie.movieTitle}</Popover.Title></Link>
        <Popover.Content>
          <img className="img-responsive" src={`${IMAGE_URL}w500/${movie.movieImage}`} alt="Movie img"/>
        </Popover.Content>
      </Popover>
    );

    return(
      <tr>
        <OverlayTrigger trigger="click" rootClose placement="bottom" overlay={popover}>
          <td>{movie.movieTitle}</td>
        </OverlayTrigger>
        <td>{movie.movieRuntime} Minutes</td>
        <td><button className="btn btn-danger" onClick={() => onClickRemove(movie.movieId)}> Remove </button></td>
      </tr>
    );
  });

  const renderWatchedMovie = WatchedMovies.map((movie, index) => {
    
    const popover = (
      <Popover id="popover-basic">
        <Link to={`movie/${movie.movieId}`} className="text-decoration-none"><Popover.Title as="h3" alt="Favorites movies">{movie.movieTitle}</Popover.Title></Link>
        <Popover.Content>
          <img className="img-responsive" src={`${IMAGE_URL}w500/${movie.movieImage}`} alt="Movie img"/>
        </Popover.Content>
      </Popover>
    );

    return(
      <tr>
        <OverlayTrigger trigger="click" rootClose placement="bottom" overlay={popover}>
          <td>{movie.movieTitle}</td>
        </OverlayTrigger>
        <td>{movie.movieRuntime} Minutes</td>
        <td><button className="btn btn-danger" onClick={() => removeWatched(movie.movieId)}> Remove </button></td>
      </tr>
    );
  });


    return( 
      <>
        <div className="mt-3" style={{width:'95%', margin:'3rem auto'}}>
          {/* Breadcrumbs */}
            <nav aria-label="breadcrumb">
                      <ol className="breadcrumb">
                          <li className="breadcrumb-item"><Link to='/'>Home</Link></li>
                          <li className="breadcrumb-item active" aria-current="page">Profile</li>
                      </ol>
            </nav>
          <div className="h1 mb-3"><div className="fa fa-thumbs-o-up"></div> My Favorites</div>

          {/* table */}
          { FavoritedMovies.length === 0 
          ? <div className="h3 font-weight-lighter ml-5 mt-4"><Link to="/movies" className="text-decoration-none">Find latest movies</Link></div> 
            : <div className="row">
              <table className="table table-hover table-responsive-xs">
                  <thead>
                      <tr>
                          <th>Movie Title</th>
                          <th>Movie Runtime</th>
                          <th>Remove from Favorites</th>
                      </tr>
                  </thead>
                  <tbody>
                      {renderTableBody}
                  </tbody>
              </table>
            </div>
          }
        </div>

        {/* watched table */}
        <div className="mt-3" style={{width:'95%', margin:'3rem auto'}}>
          <div className="h1 mb-3"><div className="fa fa-history"></div> Watched Movies</div>

          {/* table */}
          { WatchedMovies.length === 0 
          ? <div className="h3 font-weight-lighter ml-5 mt-4"><Link to="/movies" className="text-decoration-none">Find latest movies</Link></div> 
            : <div className="row">
              <table className="table table-hover table-responsive-xs">
                  <thead>
                      <tr>
                          <th>Movie Title</th>
                          <th>Movie Runtime</th>
                          <th>Remove from Watched</th>
                      </tr>
                  </thead>
                  <tbody>
                      {renderWatchedMovie}
                  </tbody>
              </table>
            </div>
          }
        </div>
      </>
    );
}
export default Profile;