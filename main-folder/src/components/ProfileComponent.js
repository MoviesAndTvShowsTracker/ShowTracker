import React, { useEffect, useState } from 'react';
import axios from 'axios';
import Popover from 'react-bootstrap/Popover';
import OverlayTrigger from 'react-bootstrap/OverlayTrigger';
import { IMAGE_URL } from '../config/keys';
import { Link } from 'react-router-dom';

const Profile = (props) => {

  const variable = { userFrom: localStorage.getItem('userId') }
  const [FavoritedMovies, setFavoritedMovies] = useState([]);

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

  useEffect(() => {
    fetchFavoriteMovies();
  }, []);

  

  const renderTableBody = FavoritedMovies.map((movie, index) => {
    
    const popover = (
      <Popover id="popover-basic">
        <a href={`movie/${movie.movieId}`}><Popover.Title as="h3" alt="Favorites movies">{movie.movieTitle}</Popover.Title></a>
        <Popover.Content>
          <img className="img-rounded img-responsive" src={`${IMAGE_URL}w500/${movie.movieImage}`} alt="Movie img"/>
        </Popover.Content>
      </Popover>
    );

    return(
      <tr>
        <OverlayTrigger trigger="click" placement="bottom" overlay={popover}>
          <td>{movie.movieTitle}</td>
        </OverlayTrigger>
        <td>{movie.movieRuntime} Minutes</td>
        <td><button className="btn btn-danger" onClick={() => onClickRemove(movie.movieId)}> Remove </button></td>
      </tr>
    );
  });


    return( 
      <>
        <div className="float-right">
          <h3 className="card border-0 mr-3 "> Username: {localStorage.getItem('myuser')}</h3> 
        </div>
        <br />
        <div className="mt-3" style={{width:'95%', margin:'3rem auto'}}>
          <div className="h1 mb-3"><div className="fa fa-thumbs-o-up"></div> My Favorites</div>

          {/* table */}
          { FavoritedMovies.length === 0 
          ? <div className="h3 font-weight-lighter ml-5 mt-4"><Link to="/movies" className="text-decoration-none">Please add favorite movies</Link></div> 
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
      </>
    );
}
export default Profile;