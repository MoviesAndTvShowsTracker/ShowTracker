import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import Fade from 'react-reveal/Fade';

function SimilarTvShows(props) {

    const [SimilarShows, setSimilarShows] = useState([]);

    useEffect(() => {

            fetch(`${API_URL}tv/${props.showId}/recommendations?api_key=${API_KEY}&language=en-US&page=1`)
            .then(response => response.json())
            .then(response => {
                console.log(response);
                setSimilarShows(response.results);
            })
    }, [])
    
    return (
        <>
            <div className="h2 mt-4">More Like This</div>
            <div className="container-fluid scrollbar-custom">
                <div className="row flex-row flex-nowrap">
                {SimilarShows && SimilarShows.map((shows, index) => (
                    <React.Fragment key={index}>
                        {shows.poster_path &&
                        <div className="col-6 col-sm-6 col-md-4 col-lg-3 col-xl-3">
                            <Fade>
                            <div>
                                <Link to={`/tv/${shows.id}`} className="text-decoration-none" >
                                    <img className="card border-0" style={{ width: '100%', height: '330px' }} alt="img" src={shows.poster_path && `${IMAGE_URL}w500${shows.poster_path}`} loading="lazy" />
                                    <div className="font-weight-bold" style={{overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{shows.name}</div>
                                </Link>
                            </div>
                            </Fade>
                        </div>}
                    </React.Fragment>
                ))}
                </div>
            </div>
        </>
    )
}

export default SimilarTvShows
