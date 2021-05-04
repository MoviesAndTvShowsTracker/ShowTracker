import React, { useEffect, useState } from 'react'
import {API_URL, API_KEY, IMAGE_URL} from '../../config/keys';
import Favorite from './Favorite';
import MainImageforDetail from './MainImageforDetail';
import { Link } from 'react-router-dom';
import SimilarMoviesData from './ShowSimilarMovies';
import Fade from 'react-reveal/Fade';
import { Helmet } from 'react-helmet';

function MovieDetail(props) {

    const movieId = props.match.params.Id;
    const [Movie, setMovie] = useState([]);
    const [Actors, setActors] = useState([]);
    const [Crews, setCrews] = useState([]);
    const [WatchProviders, setWatchProviders] = useState([]);
    const [Genres, setGenres] = useState([]);
    const [ActorToggle, setActorToggle] = useState(false);

    useEffect(() => {

        fetch(`${API_URL}movie/${movieId}?api_key=${API_KEY}&language=en-US`)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setMovie(response);
            setGenres(response.genres);

            fetch(`${API_URL}movie/${movieId}/credits?api_key=${API_KEY}`)
            .then(response => response.json())
            .then(response => {
                console.log(response);
                setActors(response.cast);
                setCrews(response.crew)
            })
        })

        fetch(`${API_URL}movie/${movieId}/watch/providers?api_key=${API_KEY}`)
            .then(response => response.json())
            .then(response => {
                console.log(response.results);
                const ott = response.results.IN.flatrate;
                setWatchProviders(ott ? ott : response.results.IN.buy)
            })
            .catch(() => console.log('error in fetching providers, do nothing'))

        window.scrollTo(0, 0);
    }, [])

    const handleClick = () => {
        setActorToggle(!ActorToggle);
    }

    function convertToReadable (labelValue) {

        // Nine Zeroes for Billions
        return Math.abs(Number(labelValue)) >= 1.0e+9
    
        ? (Math.abs(Number(labelValue)) / 1.0e+9).toFixed(2) + " Billion"
        // Six Zeroes for Millions 
        : Math.abs(Number(labelValue)) >= 1.0e+6
    
        ? (Math.abs(Number(labelValue)) / 1.0e+6).toFixed(2) + " Million"
        // Three Zeroes for Thousands
        : Math.abs(Number(labelValue)) >= 1.0e+3
    
        ? (Math.abs(Number(labelValue)) / 1.0e+3).toFixed(2) + " Thousand"
    
        : Math.abs(Number(labelValue));
    
    }

    function time_convert(num) {
        var hours = Math.floor(num / 60);  
        var minutes = num % 60;
        return `${hours}h ${minutes}m`; 
    }

    function airdate(prop) {
        const date = new Date(prop);
        const month = date.toLocaleString('default', { month: 'long' });
        return `${month} ${date.getFullYear()}`;
    }
    
    return (
        <>
        <Helmet>
            <title> {Movie.title ? `${Movie.title}` : "Loading..."}</title>
        </Helmet>
            <div>
                {Movie &&
                    <MainImageforDetail image={`${IMAGE_URL}w1280${Movie.backdrop_path && Movie.backdrop_path}`}
                    title={Movie.title} text={Movie.overview} />
                }
            </div>

            <div style={{ width: '95%', margin: '1rem auto'}}>
                {/* Breadcrumbs */}
                <nav aria-label="breadcrumb">
                    <ol className="breadcrumb">
                        <li className="breadcrumb-item"><Link to='/'>Home</Link></li>
                        <li className="breadcrumb-item"><Link to='/movies'>Movies</Link></li>
                        <li className="breadcrumb-item active" aria-current="page">{Movie.title}</li>
                    </ol>
                </nav>
                {/* basic info */}
                <div className="row mb-4">
                    <div className="d-none d-sm-block col-xs-12 col-sm-6 col-md-6 col-lg-6">
                        <div className="h2"> Movie Information</div>
                    </div>
                    <div className="d-block d-sm-none col-xs-12 col-sm-6 col-md-6 col-lg-6">
                        <div className="h2"> Movie Information</div>
                    </div>
                    <div className="col-xs-12 col-sm-6 col-md-6 col-lg-6">
                        <div className="float-right">
                            <Favorite userFrom= {localStorage.getItem('userId')} movieId={movieId} movieInfo={Movie} />
                        </div>
                    </div>
                    <div className="text-center card-footer col-12 mt-4 d-block d-sm-none"><span className="fa fa-imdb fa-lg"></span>{Movie.vote_average}/10 ({Movie.vote_count} Votes)</div>
                </div>

                {/* movie info part */}
                <div className="row">
                    <div className="d-none d-sm-block col-3 text-center">
                    <div className="d-none d-sm-block">
                        <Fade><img className="img-responsive card" style={{height:'295px', width:'100%'}} src={Movie.poster_path && `${IMAGE_URL}w500${Movie.poster_path}`} alt="movie poster"/>
                        <div className="card-footer"> <span className="fa fa-imdb fa-lg"></span>{Movie.vote_average}/10 ({Movie.vote_count} Votes)</div></Fade>
                    </div>
                    </div>
                    
                    <table className="col table table-hover table-responsive-xs">
                        <tbody>
                        <tr>
                            <td className="font-weight-bolder">Title</td>
                            <td className="">{Movie.title}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Release Date</td>
                            <td className="">{airdate(Movie.release_date)}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Director</td>
                            <td className="">{Crews.filter(value => value.job === 'Director').map((val, index) => (val.name + " "))}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Genre</td>
                            <td className="">{Genres.map((item, index) => (
                                <React.Fragment key={index}>
                                    {item.name + " "}
                                </React.Fragment>
                            ))}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Revenue</td>
                            <td className="">${convertToReadable(Movie.revenue)}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Runtime</td>
                            <td className="">{time_convert(Movie.runtime)}</td>
                        </tr>
                        {WatchProviders.length > 0 &&
                            <tr>
                                <td className="font-weight-bolder">Where to watch</td>
                                <td className="">{WatchProviders.map((result, index) => (
                                    <React.Fragment key={index}>
                                        <img style={{height:"30px", width:"30px"}} className="img-responsive mr-2" src={`${IMAGE_URL}w500${result.logo_path}`} />
                                    </React.Fragment>
                                ))}
                                </td>
                            </tr>
                        }
                        </tbody>
                    </table>
                </div>

                {/* actor button */}
                <div className="text-center mt-2">
                    <button className={ActorToggle ? "btn btn-danger" : "btn btn-primary"} onClick={handleClick}> { ActorToggle ? "Hide Cast" : "Show Cast" } </button>
                </div>

                {/* actors grid shown only if button clicked*/}
                {ActorToggle &&
                <>
                    <div className="h2">Cast</div>
                    <div className="container-fluid scrollbar-custom mt-3">
                        <div className="row flex-row flex-nowrap">
                            {Actors && Actors.map((crew, index) => (
                                <React.Fragment key={index}>
                                    {crew.profile_path &&
                                        <div className="col-6 col-sm-6 col-md-4 col-lg-3 col-xl-3">
                                            <img className="card card-img border-0" style={{ width: '100%', height: '300px' }} alt="img" src={`${IMAGE_URL}original${crew.profile_path}`} loading="lazy"/>
                                            <div className="text-center text-dark font-weight-bold card-footer">
                                                <div>{crew.name} as {crew.character}</div>
                                            </div>
                                        </div>
                                    }
                                </React.Fragment>
                            ))}
                        </div>
                    </div>
                </>
                }
                {/* Similar movies */}
                <SimilarMoviesData movieId={movieId} />
            </div>
        </>
    )
}

export default MovieDetail;
