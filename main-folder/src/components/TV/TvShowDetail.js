import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import MainImageforDetail from './MainImageforDetail';
import SimilarTvShows from './SimilarTvShows';
import TvFavorites from './TvFavorites';
import Fade from 'react-reveal/Fade';
import { Helmet } from 'react-helmet'

function TvDetail(props) {

    const tvShowId = props.match.params.Id;
    const [TvShow, setTvShow] = useState([]);
    const [CreatedBy, setCreatedBy] = useState([]);
    const [Genres, setGenres] = useState([]);
    const [Seasons, setSeasons] = useState([]);
    const [Crews, setCrews] = useState([]);
    const [WatchProviders, setWatchProviders] = useState([]);
    const [ActorToggle, setActorToggle] = useState(false);
    
    useEffect(() => {

        fetch(`${API_URL}tv/${tvShowId}?api_key=${API_KEY}&language=en-US`)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setTvShow(response);
            setCreatedBy(response.created_by);
            setGenres(response.genres);
            setSeasons(response.seasons)
        })

        fetch(`${API_URL}tv/${tvShowId}/credits?api_key=${API_KEY}`)
            .then(response => response.json())
            .then(response => {
                console.log(response);
                setCrews(response.cast)
        })

        fetch(`${API_URL}tv/${tvShowId}/watch/providers?api_key=${API_KEY}`)
            .then(response => response.json())
            .then(response => {
                console.log(response.results);
                const ott = response.results.IN.flatrate;
                const free = response.results.IN.free;
                setWatchProviders(ott ? ott : response.results.IN.buy || free)
            })
            .catch(() => console.log('error in fetching providers, do nothing'))
        
        window.scrollTo(0, 0); {/* scroll to top react router behavior to keep the next page on same position*/}
    }, [])

    function airdate(prop) {
        const date = new Date(prop);
        const month = date.toLocaleString('default', { month: 'long' });
        return `${month} ${date.getFullYear()}`;
    }

    const handleClick = () => {
        setActorToggle(!ActorToggle);
    }
    
    return (
        <>
        {/* title of the page */}
        <Helmet>
            <title> {TvShow.name ? `TV Show | ${TvShow.name}` : "TV Shows"}</title>
        </Helmet>
        <div>
            <MainImageforDetail tvShowId={tvShowId} image={`${IMAGE_URL}w1280${TvShow.backdrop_path && TvShow.backdrop_path}`} 
                title={TvShow.original_name} text={TvShow.overview}
            />
        </div>

        <div style={{ width: '95%', margin: '1rem auto'}}>
                {/* Breadcrumbs */}
                <nav aria-label="breadcrumb">
                    <ol className="breadcrumb">
                        <li className="breadcrumb-item"><Link to='/'>Home</Link></li>
                        <li className="breadcrumb-item"><Link to='/tv'>TV</Link></li>
                        <li className="breadcrumb-item active" aria-current="page">{TvShow.original_name}</li>
                    </ol>
                </nav>
                
            <div className="row">
                    <div className="col-xs-12 col-sm-6 col-md-6 col-lg-6">
                        <div className="h2"><span className="fa fa-info-circle"></span> Information</div>
                    </div>
                    <div className="col-xs-12 col-sm-6 col-md-6 col-lg-6">
                        <div className="float-right">
                            <TvFavorites userFrom={localStorage.getItem('userId')} tvId={tvShowId} tvInfo={TvShow} />
                        </div>
                    </div>
                    <div className=" mt-3 col-12 card-footer text-center d-block d-sm-none"> <span className="fa fa-imdb fa-lg"></span>{TvShow.vote_average}/10 ({TvShow.vote_count} Votes)</div>

            </div>
            <div className="row mt-3">
                <div className="d-none d-sm-block col-3 text-center">
                    <img className="img-responsive card" style={{height:'295px', width:'100%'}} src={TvShow.poster_path && `${IMAGE_URL}w500${TvShow.poster_path}`} alt="movie poster"/>
                    <div className="card-footer"> <span className="fa fa-imdb fa-lg"></span>{TvShow.vote_average}/10 ({TvShow.vote_count} Votes)</div>
                </div>
                <table className="col table table-hover table-responsive-xs">
                        <tbody>
                        <tr>
                            <td className="font-weight-bolder">Title</td>
                            <td className="">{TvShow.name}</td>
                        </tr>
                        {CreatedBy.length > 0 && <tr>
                            <td className="font-weight-bolder">Created By</td>
                            <td className="">{CreatedBy.map((item, index) => (
                                <React.Fragment key={index}>
                                    {item.name + " "}
                                </React.Fragment>
                            ))}</td>
                        </tr>}
                        <tr>
                            <td className="font-weight-bolder">Genre</td>
                            <td className="">{Genres.map((item, index) => (
                                <React.Fragment key={index}>
                                    {item.name + " "}
                                </React.Fragment>
                            ))}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Release Date</td>
                            <td className="">{airdate(TvShow.first_air_date)}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Seasons</td>
                            <td className="">{TvShow.number_of_seasons}</td>
                        </tr>
                        <tr>
                            <td className="font-weight-bolder">Status</td>
                            <td className="">{TvShow.status}</td>
                        </tr>
                        {WatchProviders.length > 0 &&
                            <tr>
                                <td className="font-weight-bolder">Where to watch</td>
                                <td className="">{WatchProviders.map((result, index) => (
                                    <React.Fragment key={index}>
                                        <img style={{height:"30px", width:"30px"}} className="img-responsive mr-2" src={`${IMAGE_URL}w92${result.logo_path}`} />
                                    </React.Fragment>
                                ))}
                                </td>
                            </tr>
                        }
                        </tbody>
                    </table>
            </div>

            {/* Show Cast button */}
            <div className="text-center mt-2">
                    <button className={ActorToggle ? "btn btn-danger" : "btn btn-primary"} onClick={handleClick}> { ActorToggle ? "Hide Cast" : "Show Cast" } </button>
            </div>

            {/* actors grid shown only if button clicked*/}
            {ActorToggle &&
                <>
                    <div className="h2">Cast and Crews</div>
                    <div className="container-fluid scrollbar-custom mt-3">
                        <div className="row flex-row flex-nowrap">
                            {Crews && Crews.map((crew, index) => (
                                <React.Fragment key={index}>
                                    {crew.profile_path &&
                                        <div className="col-6 col-sm-6 col-md-4 col-lg-3 col-xl-3 mb-2">
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

            {/* Seasons */}
            <div className="mt-3">
                <div className="h2"><span className="fa fa-list-alt"></span> Seasons</div>
                {Seasons.slice(0).reverse().map((results, index) => (
                    <React.Fragment key={index}>
                        {results.poster_path && 
                            <div className="p-0 mb-3 col-12">
                                <Fade>
                                <div className="card">
                                    <div className="card-header font-weight-bold text-primary"><Link to={`/tv/${tvShowId}/${results.season_number}/episodes`}>{results.name}</Link> <div className="text-secondary">{`${new Date(results.air_date).getFullYear()} | ${results.episode_count} Episodes`}</div></div>
                                    <div className="card-body row">
                                        <div className="col-4 col-md-3">
                                            <img style={{height:"10rem", width:"10rem"}} className="img-responsive rounded" src={`${IMAGE_URL}w500${results.poster_path}`} />
                                        </div>
                                        <div className="col-8 col-md-9">
                                            <div className="giveMeEllipsis">{results.overview ? results.overview : "No Information Available"}</div>
                                        </div>
                                    </div>
                                </div>
                                </Fade>
                            </div>
                        }
                    </React.Fragment>
                ))
                }
            </div>
            {/* similar shows */}
            <SimilarTvShows showId={tvShowId} />
        </div>
        </>
    )
}

export default TvDetail;
