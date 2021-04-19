import React from 'react';
import { Link } from 'react-router-dom';
import { Col } from 'reactstrap';

function GridCard(props) {

    if(props.actor) {
        return(
            <Col lg={3} md={4} sm={6} xs={6} className="mb-3 mt-3">
                <div>
                        <img className="card card-img border-0" style={{ width: '100%', height: '300px' }} alt="img" src={props.image} />
                        <div className="text-center text-dark font-weight-bold card-footer">
                            <div>{props.actor} as {props.character}</div>
                        </div>
                </div>
            </Col>
        )
    }
    else {
        return(
            <Col lg={3} md={4} sm={6} xs={6} className="mb-3">
                <div>
                    <Link to={`/movie/${props.movieId}`} className="text-decoration-none">
                        <img className="card border-0" style={{ width: '100%', height: '330px' }} alt="img" src={props.image} />
                    </Link>
                </div>
            </Col>
        )
    }
}


export default GridCard;