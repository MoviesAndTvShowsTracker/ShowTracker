import React, { useEffect, useState } from 'react';
import axios from 'axios';
import {API_URL, API_KEY, IMAGE_URL} from '../../config/keys';
import { Row } from 'reactstrap';
import MainImage from './MainImage';
import GridCard from './GridCard';


function LandingPage() {

    const [Movies, setMovies] = useState([]);

    useEffect( () => {

        fetch(`${API_URL}movie/popular?api_key=${API_KEY}&language=en-US&page=1`)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setMovies(response.results);
        })
    }, []);

    return (
        <div style={{ width: '100%', margin: 0 }}  >

            {Movies[0] &&
                <MainImage image={`${IMAGE_URL}original${Movies[0].backdrop_path && Movies[0].backdrop_path}`}
                    title={Movies[0].original_title} text={Movies[0].overview} />
            }

            <div style={{ width: '95%', margin: '1rem auto' }}>
                <div className="font-weight-bold h2" > Latest Movies </div>
                <hr style={{borderColor:'black'}}/>

                <Row>
                        {Movies && Movies.map((movie, index) => (
                            <React.Fragment key={index}>
                                <GridCard 
                                    image={movie.poster_path && `${IMAGE_URL}w500${movie.poster_path}`}
                                    movieId={movie.id} movieTitle={movie.title}
                                />
                            </React.Fragment>
                        ))}
                </Row>

                <br />
                <div className="text-center">
                    <button className="btn btn-primary" onClick> Load More </button>
                </div>

            </div>

        </div>
    )
}

export default LandingPage
