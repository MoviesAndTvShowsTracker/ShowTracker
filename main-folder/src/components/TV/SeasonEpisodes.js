import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import Fade from 'react-reveal/Fade';
import { Helmet } from 'react-helmet';

function SeasonEpisodes(props) {

    const seasonNum = parseInt(props.match.params.seasonNumber);
    const tvShowId = props.match.params.Id;
    const [Seasons, setSeasons] = useState([]);
    const [Episodes, setEpisodes] = useState([]);
    const [TvShow, setTvShow] = useState([]);

    useEffect(() => {

        fetch(`${API_URL}tv/${tvShowId}/season/${seasonNum}?api_key=${API_KEY}&language=en-US`)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setSeasons(response);
            setEpisodes(response.episodes);
        })

        fetch(`${API_URL}tv/${tvShowId}?api_key=${API_KEY}&language=en-US`)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setTvShow(response);
        })
    }, [])

    function airdate(prop) {
        const date = new Date(prop);
        const month = date.toLocaleString('default', { month: 'long' });
        return `${date.getDate()} ${month} ${date.getFullYear()}`;
    }

    return (
        <>
        {/* title of the page */}
        <Helmet>
            <title> {TvShow.name ? `Episodes S${Seasons.season_number} | ${TvShow.name}` : "TV Shows"}</title>
        </Helmet>
            <div style={{ width: '95%', margin: '1rem auto'}}>
                {/* breadcrumbs */}
                <nav aria-label="breadcrumb">
                    <ol className="breadcrumb">
                        <li className="breadcrumb-item"><Link to='/'>Home</Link></li>
                        <li className="breadcrumb-item"><Link to='/tv'>TV</Link></li>
                        <li className="breadcrumb-item"><Link to={`/tv/${TvShow.id}`}>{TvShow.name}</Link></li>
                        <li className="breadcrumb-item">{Seasons.name}</li>
                        <li className="breadcrumb-item active" aria-current="page">Episodes</li>
                    </ol>
                </nav>
                <div className="row mb-3">
                    <div className="col-6 col-md-3">
                        <img className="img-responsive card" style={{height:'250px', width:'100%'}} src={TvShow.poster_path && `${IMAGE_URL}w500${Seasons.poster_path}`} />
                    </div>
                    <div className="col-6 col-md-9">
                        <div className="h2">{TvShow.name}</div>
                        <div className="font-smaller text-secondary">{Seasons.name}</div>
                        <div className="font-smaller text-secondary">{Episodes.length} Episodes</div>
                    </div>
                </div>
                {Episodes.map((results, index) => (
                    <React.Fragment key={index}>
                        <Fade>
                            <div className="p-0 mb-3 col-12">
                                <div className="card">
                                    <div className="card-header font-weight-bold text-primary">{results.episode_number}. {results.name} <div className="text-secondary">{results.air_date ? `${airdate(results.air_date)} |` : "-"}  <span className="fa fa-star mr-1"></span>{results.vote_average ? results.vote_average : "-"}/10</div></div>
                                    <div className="card-body row m-0">
                                        {/* <div className="col-4 col-md-2">
                                            <img style={{height:"200px", width:"150px"}} className="img-responsive" src={`${IMAGE_URL}w500${results.still_path}`} />
                                        </div> */}
                                        <div className="col-12 col-md-10 pl-0">
                                            <div className="giveMeEllipsis">{results.overview ? results.overview : "No Information Available"}</div> 

                                            {results.crew.length > 0 && 
                                                <div className="mt-3 text-info font-weight-bold">Director:
                                                    {results.crew.filter(value => value.job === "Director").map((val) => (<span> {val.name}. </span>))}
                                                </div>
                                            }
                                            {results.crew.length > 0 && 
                                                <div className="mt-3 text-info font-weight-bold">Writer:
                                                    {results.crew.filter(value => value.job === "Writer").map((val) => (<span> {val.name}. </span>))}
                                                </div>
                                            }
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </Fade>
                    </React.Fragment>
                ))
                }
            </div>
        </>
    )
}

export default SeasonEpisodes
