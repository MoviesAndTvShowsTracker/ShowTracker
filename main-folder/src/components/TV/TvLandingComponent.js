import React, { useEffect, useState } from 'react';
import { Helmet } from 'react-helmet';
import { Link } from 'react-router-dom';
import { Row } from 'reactstrap';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import MainTvImage from './MainTvImage';
import TvGridCard from './TvGridCard';

function TvLandingPage() {
    const [TvShows, setTvShows] = useState([]);
    const [CurrentPage, setCurrentPage] = useState(0);

    useEffect(() => {
        const endpoint = `${API_URL}tv/popular?api_key=${API_KEY}&language=en-US&page=1`;
        fetchTvShows(endpoint);
    }, [])
    
    const fetchTvShows = (path) => {
        fetch(path)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setTvShows([...TvShows, ...response.results]);
            setCurrentPage(response.page);
        })
    }

    const handleClick = () => {
        const endpoint = `${API_URL}tv/popular?api_key=${API_KEY}&language=en-US&page=${CurrentPage + 1}`;
        fetchTvShows(endpoint);
    }

    return (
        <> 
        {/* title of the page */}
        <Helmet>
            <title>Explore TV Shows</title>
        </Helmet>
            <div style={{ width: '100%', margin: 0 }}>
                {TvShows[0] &&
                    <MainTvImage 
                        image={`${IMAGE_URL}w1280${TvShows[0].backdrop_path}`}
                        title={TvShows[0].original_name} 
                        text={TvShows[0].overview} 
                        tvshowid={TvShows[0].id}
                        
                        image1={`${IMAGE_URL}w1280${TvShows[1].backdrop_path}`}
                        title1={TvShows[1].original_name} 
                        text1={TvShows[1].overview} 
                        tvshowid1={TvShows[1].id}

                        image2={`${IMAGE_URL}w1280${TvShows[2].backdrop_path}`}
                        title2={TvShows[2].original_name} 
                        text2={TvShows[2].overview} 
                        tvshowid2={TvShows[2].id}
                    />}
            </div>

            <div style={{ width: '95%', margin: '1rem auto' }}>
                {/* Breadcrumbs */}
                <nav aria-label="breadcrumb">
                    <ol className="breadcrumb">
                        <li className="breadcrumb-item"><Link to='/'>Home</Link></li>
                        <li className="breadcrumb-item active" aria-current="page">TV</li>
                    </ol>
                </nav>
                <div className="font-weight-bold h2"> Latest TV Shows </div>
                <hr style={{borderColor:'black'}}/>

                <Row>
                        {TvShows && TvShows.map((tvshow, index) => (
                            <React.Fragment key={index}>
                                <TvGridCard 
                                    image={tvshow.poster_path && `${IMAGE_URL}w500${tvshow.poster_path}`}
                                    tvShowId={tvshow.id} tvShowTitle={tvshow.title} name={tvshow.original_title}
                                />
                            </React.Fragment>
                        ))}
                </Row>

                <br />
                <div className="text-center">
                    <button className="btn btn-primary" onClick={handleClick}> Load More </button>
                </div>

            </div>
        </>
    )
}

export default TvLandingPage;
