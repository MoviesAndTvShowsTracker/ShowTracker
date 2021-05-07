import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import Fade from 'react-reveal/Fade';

function SimilarMoviesData(props) {

    const [SimilarMovies, setSimilarMovies] = useState([]);

    useEffect(() => {

            fetch(`${API_URL}movie/${props.movieId}/similar?api_key=${API_KEY}&language=en-US&page=1`)
            .then(response => response.json())
            .then(response => {
                console.log(response);
                setSimilarMovies(response.results);
            })
    }, [])

    return (
        <>
            <div className="h2 mt-4">More Like This</div>
            <div className="container-fluid scrollbar-custom">
                <div className="row flex-row flex-nowrap">
                {SimilarMovies && SimilarMovies.map((similarmovie, index) => (
                    <React.Fragment key={index}>
                        {similarmovie.poster_path &&
                        <div className="col-6 col-sm-6 col-md-4 col-lg-3 col-xl-3">
                            <Fade>
                            <div>
                                <Link to={`/movies/${similarmovie.id}`} className="text-decoration-none" >
                                    <img className="card border-0" style={{ width: '100%', height: '330px' }} alt="img" src={similarmovie.poster_path && `${IMAGE_URL}w500${similarmovie.poster_path}`} loading="lazy" />
                                    <div className="font-weight-bold mt-1" style={{overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{similarmovie.title}</div>
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

export default SimilarMoviesData;
