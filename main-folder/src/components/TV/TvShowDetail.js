import React, { useEffect, useState } from 'react'
import { Link } from 'react-router-dom';
import { API_KEY, API_URL, IMAGE_URL } from '../../config/keys';
import MainImageforDetail from './MainImageforDetail';

function TvDetail(props) {

    const tvShowId = props.match.params.Id;
    const [TvShow, setTvShow] = useState([]);

    useEffect(() => {

        fetch(`${API_URL}tv/${tvShowId}?api_key=${API_KEY}&language=en-US`)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            setTvShow(response);
        })
    }, [])

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
        </div>
        </>
    )
}

export default TvDetail;
