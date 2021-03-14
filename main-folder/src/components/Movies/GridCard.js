import React from 'react';
import { Col } from 'reactstrap';
function GridCard(props) {

        return (
            <Col lg={3} md={4} sm={6} xs={12} className="mb-3">
                <div>
                    <a href={`/movie/${props.movieId}`}>
                        <img style={{ width: '100%', height: '320px' }} alt="img" src={props.image} />
                        <div className="text-center text-dark font-weight-bold">
                            <div>{props.movieTitle}</div>
                        </div>
                    </a>
                </div>
            </Col>
        )
    }


export default GridCard;