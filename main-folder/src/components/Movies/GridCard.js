import React from 'react';
import { Link } from 'react-router-dom';
import Fade from 'react-reveal/Fade';

function GridCard(props) {
        return(
            <div className="col-6 col-md-4 col-lg-3 ">
                <Fade>
                <div className="mb-3">
                    <Link to={`/movies/${props.movieId}`} className="text-decoration-none">
                        <img className="rounded img-responsive" style={{width:'100%', height:'19rem' }} alt={props.movieTitle} src={props.image} />
                        <div className="mt-1 font-weight-bold" style={{ whiteSpace:'nowrap', textOverflow:'ellipsis', overflow:'hidden' }}>{props.movieTitle}</div>
                    </Link>
                </div>
                </Fade>
            </div>
        )
}



export default GridCard;