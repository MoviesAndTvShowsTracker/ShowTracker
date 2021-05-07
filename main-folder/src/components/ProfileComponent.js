import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { IMAGE_URL } from '../config/keys';
import { Link } from 'react-router-dom';
import { Modal, ModalHeader, ModalBody, ModalFooter } from 'reactstrap';
import swal from 'sweetalert';
import Fade from 'react-reveal/Fade';
import { Helmet } from 'react-helmet';

const Profile = (props) => {

  const variable = { userFrom: localStorage.getItem('userId') }
  const [FavoritedMovies, setFavoritedMovies] = useState([]);
  const [FavoritedShows, setFavoritedShows] = useState([]);
  const [WatchedMovies, setWatchedMovies] = useState([]);
  const [UserInfo, setUserInfo] = useState([]);
  const [modal, setModal] = useState(false);
  const [inputValue, setInputValue] = useState("");

  {/*adding or updating phone Number functions*/}
  const onChangeHandler = event => {
    setInputValue(event.target.value);
  };

  const submitValue = (e) => {
    e.preventDefault();
    {/*if condition checks length=10 and no alphabets or no alphanumeric chars*/}
    if(!/^\d{10}$/.test(inputValue)) {
      swal("Please enter the valid number", "", "warning")
    }
    else {
    const data ={
      inputValue: inputValue,
      userId: localStorage.getItem('userId')
    };
    console.log(data);
    axios.post("http://localhost:5000/users/updateOrAddPhone", data)
    .then(response => {
      if(response.data.success) {
        console.log(response.data.docs);
        setInputValue("");
        toggle();
        swal("", "", "success", {
          buttons: {
              sure: {
                text: "Okay",
                className: "swal-confirm"
              }
            }
      });
      fetchUserInfo();
      }
      else {
        swal("failed to get user information");
      }
    });
    }
  }
  {/*end of phone number functions*/}

  const toggle = () => setModal(!modal);

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

  const fetchFavoriteShows = () => {
    axios.post('http://localhost:5000/api/tv/favorite/getFavoriteMovie', variable)
    .then(response => {
      if(response.data.success) {
        console.log(response.data.favorites);
        setFavoritedShows(response.data.favorites);
      }
      else {
        alert("failed to fetch favorites");
      }
    })
  }

  {/*below get request is require user to authenticate first. auth only shown in this request
  just to show that it works you can apply this in all requests*/}
  const fetchUserInfo = () => {
    axios.get(`http://localhost:5000/users/getUser/${localStorage.getItem("userId")}`, {
      headers: {
        Authorization: 'Bearer ' + localStorage.getItem('user')
      }
    })
    .then(response => {
      if(response.data.success) {
        console.log(response.data.found);
        setUserInfo(response.data.found);
      }
      else {
        alert("failed to get user information");
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

  const removeFavoriteShow = (tvId) => {

    const variable = {
      tvId: tvId,
      userFrom: localStorage.getItem('userId')
    }

    axios.post('http://localhost:5000/api/tv/favorite/removeFromFavorite', variable)
          .then(response => {
              if(response.data.success) {
                  fetchFavoriteShows();
              }
              else {
                  alert('Failed to remove from Watched movies');
              }
          })
  }

  useEffect(() => {
    fetchUserInfo();
    fetchFavoriteMovies();
    fetchWatchedMovies();
    fetchFavoriteShows();

    window.scrollTo(0,0);
  }, []);
    
  {/* Joined date of the account*/}
  const date = new Date(`${UserInfo.createdAt}`);
  const month = date.toLocaleString('default', { month: 'long' });
  const joinDate = `${month} ${date.getFullYear()}`;

  return( 
    <>
      <Helmet>
          <title>{UserInfo.username ? `Profile - ${UserInfo.username}` : "Profile"}</title>
      </Helmet>
      <div className="mt-3" style={{width:'95%', margin:'3rem auto'}}>
          {/* Breadcrumbs */}
          <nav aria-label="breadcrumb">
                    <ol className="breadcrumb">
                        <li className="breadcrumb-item"><Link to='/'>Home</Link></li>
                        <li className="breadcrumb-item active" aria-current="page">Profile</li>
                    </ol>
          </nav>
      </div>

        {/* Profile Info */}
        {UserInfo && <div style={{width:'95%', margin:'3rem auto'}}>
          <div className="row gutters-sm">
            <div className="col-md-4 mb-3">
              <div className="card">
                <div className="card-body">
                  <div className="d-flex flex-column align-items-center text-center">
                    <img src="https://bootdey.com/img/Content/avatar/avatar7.png" alt="User" className="rounded-circle" width="150" />
                    <div>
                      <h4>{UserInfo.username}</h4>
                      {WatchedMovies.length < 20 ? <p className="mb-1 badge badge-danger badge-pill">Newbie</p>
                        : <p className="mb-1 badge badge-primary badge-pill">Intermediate</p> }
                      <p className="text-secondary mb-1">Joined since {joinDate}</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            {/*  */}
            <div className="col-md-8">
              <div className="card mb-3">
                <div className="card-body">
                  <div className="row">
                    <div className="col-sm-3">
                      <h6 className="mb-0">Full Name</h6>
                    </div>
                    <div className="col-sm-9 text-secondary">
                    {UserInfo.firstName + " " + UserInfo.lastName}
                    </div>
                  </div>
                  <hr />
                  <div className="row">
                    <div className="col-sm-3">
                      <h6 className="mb-0">Email</h6>
                    </div>
                    <div className="col-sm-9 text-secondary">
                      {UserInfo.email}
                    </div>
                  </div>
                  <hr />
                  <div className="row">
                    <div className="col-sm-3">
                      <h6 className="mb-0">Phone</h6>
                    </div>
                    <div className="col-sm-9 text-secondary">
                      {UserInfo.phonenumber 
                      ?
                      <div> {/*edit modal*/}
                        {UserInfo.phonenumber}
                        <div className="float-right">
                          <button className="btn text-primary p-0" onClick={toggle}><span className="fa fa-edit fa-lg"></span> Edit</button>
                          <Modal isOpen={modal} toggle={toggle} centered="true">
                            <ModalHeader toggle={toggle}>Enter New Number</ModalHeader>
                            <ModalBody>
                              <input className="col-12" type="tel" placeholder="Phone" maxLength="10" onChange={onChangeHandler} value={inputValue}/>
                            </ModalBody>
                            <ModalFooter>
                              <button className="btn btn-secondary" onClick={toggle}>Cancel</button>
                              <button className="btn btn-primary" type="submit" onClick={submitValue}>Submit</button>{' '}
                            </ModalFooter>
                          </Modal>
                        </div>
                      </div>
                      :
                      <div> {/*Add number modal*/}
                          <button className="btn btn-primary" onClick={toggle}><span className="fa fa-phone"></span> Add Phone</button>
                          <Modal isOpen={modal} toggle={toggle} centered="true">
                            <ModalHeader toggle={toggle}>Enter Number</ModalHeader>
                            <ModalBody>
                              <input className="col-12" type="tel" placeholder="Phone" maxLength="10" onChange={onChangeHandler} value={inputValue}/>
                            </ModalBody>
                            <ModalFooter>
                              <button className="btn btn-secondary" onClick={toggle}>Cancel</button>
                              <button className="btn btn-primary" type="submit" onClick={submitValue}>Submit</button>{' '}
                            </ModalFooter>
                          </Modal>
                        </div>
                      }
                    </div>
                  </div>
                  <hr />
                  <div className="row">
                    <div className="col-sm-3">
                      <h6 className="mb-0">Country</h6>
                    </div>
                    <div className="col-sm-9 text-secondary">
                      India
                    </div>
                  </div>
                  <hr />
                  <div className="row">
                    <div className="col-sm-3">
                      <h6 className="mb-0">Watched Movies</h6>
                    </div>
                    <div className="col-sm-9 text-secondary">
                      {WatchedMovies.length}
                    </div>
                  </div>
                </div>
              </div>
            </div>
            {/*  */}
          </div>
        </div>}

      {/* Favorites movies flexbox */}
      <div className="mt-3" style={{width:'95%', margin:'3rem auto'}}>
        <div className="h2 mb-3"><div className="fa fa-thumbs-o-up"></div> My Favorites</div>
        { FavoritedMovies.length === 0 
        ? <div className="h3 font-weight-lighter ml-5 mt-4"><Link to="/movies" className="text-decoration-none">Find latest movies</Link></div> 
          :
          <div className="container-fluid scrollbar-custom">
            <div className="row flex-row flex-nowrap">
              {FavoritedMovies && FavoritedMovies.map((favoritemovie, index) => (
                <React.Fragment key={index}>
                    <div className="col-6 col-sm-6 col-md-4 col-lg-3 col-xl-3">
                      <Fade>
                      <div className="position-relative">
                        <Link to={`/movies/${favoritemovie.movieId}`} className="text-decoration-none">
                          <img className="card border-0" style={{ width: '100%', height: '330px' }} alt="img" src={`${IMAGE_URL}w500${favoritemovie.moviePosterImage}`} />
                          <div className="mt-1 font-weight-bold text-decoration-none" style={{overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{favoritemovie.movieTitle}</div>
                        </Link>
                        <div style={{position: "absolute", top: '1rem', right: '1rem'}}>
                          <button className="btn btn-danger" onClick={() => onClickRemove(favoritemovie.movieId)}> Remove </button>
                        </div>
                      </div>
                      </Fade>
                    </div>
                </React.Fragment>
              ))}
            </div>
          </div>}
      </div>


      {/* watched movies flexbox */}
      <div className="mt-3" style={{width:'95%', margin:'3rem auto'}}>
        <div className="h2 mb-3"><div className="fa fa-history"></div> Watched Movies</div>
        { WatchedMovies.length === 0 
        ? <div className="h3 font-weight-lighter ml-5 mt-4"><Link to="/movies" className="text-decoration-none">Find latest movies</Link></div> 
          :
          <div className="container-fluid scrollbar-custom">
            <div className="row flex-row flex-nowrap">
              {/* the array is in reverse so user can find his latest watched movies */}
              {WatchedMovies && WatchedMovies.slice(0).reverse().map((watchedmovie, index) => (
                <React.Fragment key={index}>
                    <div className="col-6 col-sm-6 col-md-4 col-lg-3 col-xl-3">
                    <Fade>
                      <div className="position-relative">
                        <Link to={`/movies/${watchedmovie.movieId}`} className="text-decoration-none">
                          <img className="card border-0" style={{ width: '100%', height: '330px' }} alt="img" src={`${IMAGE_URL}w500${watchedmovie.moviePosterImage}`} />
                          <div className="mt-1 font-weight-bold text-decoration-none" style={{overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{watchedmovie.movieTitle}</div>
                        </Link>
                        <div style={{position: "absolute", top: '1rem', right: '1rem'}}>
                          <button className="btn btn-danger" onClick={() => removeWatched(watchedmovie.movieId)}> Remove </button>
                        </div>
                      </div>
                      </Fade>
                    </div>
                </React.Fragment>
              ))}
            </div>
          </div>}
      </div>

      {/* Favorite shows flexbox */}
      <div className="mt-3" style={{width:'95%', margin:'3rem auto'}}>
        <div className="h2 mb-3"><div className="fa fa-history"></div> Favorite Shows</div>
        { FavoritedShows.length === 0 
        ? <div className="h3 font-weight-lighter ml-5 mt-4"><Link to="/tv" className="text-decoration-none">Find latest TV Shows</Link></div> 
          :
          <div className="container-fluid scrollbar-custom">
            <div className="row flex-row flex-nowrap">
              {/* the array is in reverse so user can find his latest watched movies */}
              {FavoritedShows && FavoritedShows.map((favoriteshow, index) => (
                <React.Fragment key={index}>
                    <div className="col-6 col-sm-6 col-md-4 col-lg-3 col-xl-3">
                      <Fade>
                      <div className="position-relative">
                        <Link to={`/tv/${favoriteshow.tvId}`} className="text-decoration-none">
                          <img className="card border-0" style={{ width: '100%', height: '330px' }} alt="img" src={`${IMAGE_URL}w500${favoriteshow.tvPosterImage}`} />
                          <div className="mt-1 font-weight-bold text-decoration-none" style={{overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{favoriteshow.tvTitle}</div>
                        </Link>
                        <div style={{position: "absolute", top: '1rem', right: '1rem'}}>
                          <button className="btn btn-danger" onClick={() => removeFavoriteShow(favoriteshow.tvId)}> Remove </button>
                        </div>
                      </div>
                      </Fade>
                    </div>
                </React.Fragment>
              ))}
            </div>
          </div>}
      </div>
    </>
  );
}
export default Profile;