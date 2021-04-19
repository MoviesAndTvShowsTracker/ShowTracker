import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom';
import { Col } from 'reactstrap';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';

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
                <div class="container-fluid overflow-auto">
                    <div class="row flex-row flex-nowrap">
                    {SimilarMovies && SimilarMovies.map((similarmovie, index) => (
                            <React.Fragment key={index}>
                                <Col lg={3} md={4} sm={6} xs={6} className="mb-3">
                                <div>
                                    <Link to={`/movie/${similarmovie.id}`} className="text-decoration-none" >
                                        <img className="card border-0" style={{ width: '100%', height: '330px' }} alt="img" src={similarmovie.poster_path && `${IMAGE_URL}w500${similarmovie.poster_path}`} />
                                        <div className="text-center font-weight-bold">{similarmovie.title}</div>
                                    </Link>
                                </div>
                            </Col>
                            </React.Fragment>
                    ))}
                    </div>
                </div>
        </>
    )
}

export default SimilarMoviesData;
