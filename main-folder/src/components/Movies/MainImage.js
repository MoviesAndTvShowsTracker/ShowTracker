import React from 'react';
import Carousel from 'react-bootstrap/Carousel'
import { Link } from 'react-router-dom';
import Fade from 'react-reveal/Fade';


function MainImage(props) {
    return (
        <Fade left>
        <Carousel>
            <Carousel.Item>
            <Link to={`/movies/${props.movieid}`}>
                <div style={{background:`url('${props.image}')`, height:'75vh', backgroundSize:'cover'}}></div>
                <Carousel.Caption>
                    <h2 className='font-weight-bolder'>{props.title}</h2>
                    <p>{props.text}</p>
                </Carousel.Caption>
            </Link>
            </Carousel.Item>
            <Carousel.Item>
            <Link to={`/movies/${props.movieid1}`}>
                <div style={{background:`url('${props.image1}')`, height:'75vh', backgroundSize:'cover'}}></div>
                    <Carousel.Caption>
                        <h2 className='font-weight-bolder'>{props.title1}</h2>
                        <p>{props.text1}</p>
                    </Carousel.Caption>
            </Link>
            </Carousel.Item>
            <Carousel.Item>
            <Link to={`/movies/${props.movieid2}`}>
                <div style={{background:`url('${props.image2}')`, height:'75vh', backgroundSize:'cover'}}></div>
                    <Carousel.Caption>
                        <h2 className='font-weight-bolder'>{props.title2}</h2>
                        <p>{props.text}</p>
                    </Carousel.Caption>
            </Link>
            </Carousel.Item>
        </Carousel>
        </Fade>
    )
}

export default MainImage;
