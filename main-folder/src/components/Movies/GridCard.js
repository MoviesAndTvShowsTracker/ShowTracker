import React from 'react';
import { Link } from 'react-router-dom';
import { Col } from 'reactstrap';
import Fade from 'react-reveal/Fade';

function GridCard(props) {
        return(
            <Col lg={3} md={4} sm={6} xs={6} className="mb-3">
                <Fade>
                <div>
                    <Link to={`/movies/${props.movieId}`} className="text-decoration-none">
                        <img className="card border-0" style={{ width: '100%', height: '330px' }} alt="img" src={props.image} />
                    </Link>
                </div>
                </Fade>
            </Col>
        )
}



export default GridCard;