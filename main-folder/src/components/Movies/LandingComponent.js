import React, { useEffect, useState } from 'react';
import axios from 'axios';
import {API_URL, API_KEY, IMAGE_URL} from '../../config/keys';
import {Typography, Row} from 'antd';
import MainImage from './MainImage';
import GridCard from './GridCard';

const {Title} = Typography;

function LandingPage() {

    const [Movies, setMovies] = useState([])
    useEffect( () => {

        fetch(`${API_URL}movie/popular?api_key=${API_KEY}&language=en-US&page=1`)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setMovies(response.results);
        })
    }, [])


    return (
        <div style={{ width: '100%', margin: 0 }}  >

            {Movies[0] &&
                <MainImage image={`${IMAGE_URL}original${Movies[0].backdrop_path && Movies[0].backdrop_path}`}
                    title={Movies[0].original_title} text={Movies[0].overview} />
            }

            <div style={{ width: '85%', margin: '1rem auto' }}>
                <Title level={2} > Movies by latest</Title>
                <hr />

                <Row gutter={[16, 16]}>
                        {Movies && Movies.map((movie, index) => (
                            <React.Fragment key={index}>
                                <GridCard 
                                    image={movie.poster_path && `${IMAGE_URL}w500${movie.poster_path}`}
                                    movieId={movie.id}
                                />
                            </React.Fragment>
                        ))}

                </Row>

                <br />
                <div className="btn btn-primary">
                    <button onClick> Load More </button>
                </div>

            </div>

        </div>
    )
}

export default LandingPage
