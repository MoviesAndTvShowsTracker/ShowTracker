import React, { useEffect, useState } from 'react'
import {API_URL, API_KEY, IMAGE_URL} from '../../config/keys';
import {Row} from 'reactstrap';
import GridCard from './GridCard';
import Favorite from './Favorite';
import MainImageforDetail from './MainImageforDetail';
import { Link } from 'react-router-dom';
import SimilarMoviesData from './ShowSimilarMovies';

function MovieDetail(props) {

    const movieId = props.match.params.Id;
    const [Movie, setMovie] = useState([]);
    const [Crews, setCrews] = useState([]);
    const [WatchProviders, setWatchProviders] = useState([]);
    const [ActorToggle, setActorToggle] = useState(false);

    useEffect(() => {

        fetch(`${API_URL}movie/${movieId}?api_key=${API_KEY}&language=en-US`)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setMovie(response);

            fetch(`${API_URL}movie/${movieId}/credits?api_key=${API_KEY}`)
            .then(response => response.json())
            .then(response => {
                console.log(response);
                setCrews(response.cast)
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
    return (
        <>
            <div>
                {Movie &&
                    <MainImageforDetail image={`${IMAGE_URL}w1280${Movie.backdrop_path && Movie.backdrop_path}`}
                    title={Movie.original_title} text={Movie.overview} />
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
                </div>

                {/* movie info part */}
                <div className="row">
                    <div className="d-none d-sm-block col-3">
                    <div className="d-none d-sm-block">
                        <img className="img-rounded img-responsive" style={{height:'295px'}} src={Movie.poster_path && `${IMAGE_URL}w500${Movie.poster_path}`} alt="movie poster"/>
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
                            <td className="">{Movie.release_date}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Revenue</td>
                            <td className="">${convertToReadable(Movie.revenue)}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Runtime</td>
                            <td className="">{Movie.runtime} Minutes</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Rating</td>
                            <td><div className="fa fa-imdb fa-lg"></div> {Movie.vote_average}/10 ({Movie.vote_count} Votes)</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Status</td>
                            <td className="">{Movie.status}</td>
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

                {/* Similar movies */}
                <SimilarMoviesData movieId={movieId} />

                {/* actor button */}
                <div className="text-center mt-2">
                    <button className="btn btn-primary" onClick={handleClick}> View Actors</button>
                </div>

                {/* actors grid */}
                {ActorToggle &&
                <Row>
                    {Crews && Crews.map((crew, index) => (
                        <React.Fragment key={index}>
                            {crew.profile_path &&
                            <GridCard 
                                actor={crew.name} character={crew.character} image={`${IMAGE_URL}original${crew.profile_path}`}
                            />}
                        </React.Fragment>
                    ))}
                </Row>}
            </div>
        </>
    )
}

export default MovieDetail;
