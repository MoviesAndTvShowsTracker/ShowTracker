import React from 'react'
import { Link } from 'react-router-dom';
import Fade from 'react-reveal/Fade';

function TvGridCard(props) {
    
        return(
            <div className="col-6 col-sm-4 col-md-4 col-lg-3">
                <Fade>
                <div className="mb-2">
                    <Link to={`/tv/${props.tvShowId}`} className="text-decoration-none">
                        <img className="card border-0 image-responsive" alt="img" src={props.image} />
                        <div className="mt-1 font-weight-bold" style={{ whiteSpace:'nowrap', textOverflow:'ellipsis', overflow:'hidden' }}>{props.tvShowTitle}</div>
                    </Link>
                </div>
                </Fade>
            </div>
        )
}

export default TvGridCard;
