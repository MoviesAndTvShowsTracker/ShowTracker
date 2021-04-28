import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import MainImageforDetail from './MainImageforDetail';
import SimilarTvShows from './SimilarTvShows';

function TvDetail(props) {

    const tvShowId = props.match.params.Id;
    const [TvShow, setTvShow] = useState([]);
    const [CreatedBy, setCreatedBy] = useState([]);
    const [Genres, setGenres] = useState([]);
    const [Seasons, setSeasons] = useState([]);
    const [WatchProviders, setWatchProviders] = useState([]);
    
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

        fetch(`${API_URL}tv/${tvShowId}/watch/providers?api_key=${API_KEY}`)
            .then(response => response.json())
            .then(response => {
                console.log(response.results);
                const ott = response.results.IN.flatrate;
                setWatchProviders(ott ? ott : response.results.IN.buy)
            })
            .catch(() => console.log('error in fetching providers, do nothing'))
    }, [])

    function airdate(prop) {
        const date = new Date(prop);
        const month = date.toLocaleString('default', { month: 'long' });
        return `${month} ${date.getFullYear()}`;
    }
    
    return (
        <>
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
                        <div className="h2"> Information</div>
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
                                        <img style={{height:"30px", width:"30px"}} className="img-responsive mr-2" src={`${IMAGE_URL}w500${result.logo_path}`} />
                                    </React.Fragment>
                                ))}
                                </td>
                            </tr>
                        }
                        </tbody>
                    </table>
            </div>
            {/* Seasons */}
            <div className="mt-3">
                <div className="h2"><span className="fa fa-list-alt"></span> Seasons</div>
                {Seasons.slice(0).reverse().map((results, index) => (
                    <React.Fragment key={index}>
                        {results.poster_path && 
                            <div className="p-0 mb-3 col-12">
                                <div className="card">
                                    <div className="card-header font-weight-bold text-primary">{results.name} <div className="text-secondary">{`${new Date(results.air_date).getFullYear()} | ${results.episode_count} Episodes`}</div></div>
                                    <div className="card-body row">
                                        <div className="col-4 col-md-2">
                                            <img style={{height:"200px", width:"150px"}} className="img-responsive" src={`${IMAGE_URL}w500${results.poster_path}`} />
                                        </div>
                                        <div className="col-8 col-md-10">
                                            {results.overview}
                                        </div>
                                    </div>
                                </div>
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
