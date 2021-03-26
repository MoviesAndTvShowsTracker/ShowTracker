import React, { useEffect, useState } from 'react';
import {API_URL, API_KEY, IMAGE_URL} from '../../config/keys';
import { Row } from 'reactstrap';
import MainImage from './MainImage';
import GridCard from './GridCard';


function LandingPage() {

    const [Movies, setMovies] = useState([]);
    const [CurrentPage, setCurrentPage] = useState(0);

    useEffect( () => {
        const endpoint = `${API_URL}movie/popular?api_key=${API_KEY}&language=en-US&page=1`;
        fetchMovies(endpoint);
    }, []);

    const fetchMovies = (path) => {
        fetch(path)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setMovies([...Movies, ...response.results]);
            setCurrentPage(response.page);
        })
    }

    const handleClick = () => {
        const endpoint = `${API_URL}movie/popular?api_key=${API_KEY}&language=en-US&page=${CurrentPage + 1}`
        fetchMovies(endpoint);
    }

    return (
        <div style={{ width: '100%', margin: 0 }}  >

            {Movies[0] &&
                <MainImage 
                    image={`${IMAGE_URL}w1280${Movies[0].backdrop_path && Movies[0].backdrop_path}`}
                    title={Movies[0].original_title}
                    text={Movies[0].overview} 
                    movieid={Movies[0].id}
                    
                    image1={`${IMAGE_URL}w1280${Movies[1].backdrop_path && Movies[1].backdrop_path}`}
                    title1={Movies[1].original_title}
                    text1={Movies[1].overview}
                    movieid1={Movies[1].id}

                    image2={`${IMAGE_URL}w1280${Movies[2].backdrop_path && Movies[2].backdrop_path}`}
                    title2={Movies[2].original_title}
                    text2={Movies[2].overview}
                    movieid2={Movies[2].id}
                />
            }

            <div style={{ width: '95%', margin: '1rem auto' }}>
                <div className="font-weight-bold h2" > Latest Movies </div>
                <hr style={{borderColor:'black'}}/>

                <Row>
                        {Movies && Movies.map((movie, index) => (
                            <React.Fragment key={index}>
                                <GridCard 
                                    image={movie.poster_path && `${IMAGE_URL}w500${movie.poster_path}`}
                                    movieId={movie.id} movieTitle={movie.title} name={movie.original_title}
                                />
                            </React.Fragment>
                        ))}
                </Row>

                <br />
                <div className="text-center">
                    <button className="btn btn-primary" onClick={handleClick}> Load More </button>
                </div>

            </div>

        </div>
    )
}

export default LandingPage
