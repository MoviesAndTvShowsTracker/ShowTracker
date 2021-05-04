import React from 'react';
import Fade from 'react-reveal/Fade';


function MainImageforDetail(props) {
    return (
        <Fade top>
        <div style={{
            background:
            `linear-gradient(to bottom, rgba(0,0,0,0)
            39%,rgba(0,0,0,0)
            41%,rgba(0,0,0,0.65)
            100%),
            url('${props.image}')`,
            height: '75vh',
            position: 'relative',
            backgroundSize:'cover'
        }}>
            <div>
                <div style={{ position: 'absolute', maxWidth: '500px', bottom: '2rem', marginLeft: '2rem' }}>
                    <div style={{ color: 'white' }} className="h2 font-weight-bolder" > {props.title}</div>
                    <p className="giveMeEllipsis" style={{ color: 'white', fontSize: '1rem' }}>{props.text}</p>
                </div>
            </div>
        </div>
        </Fade>
    )
}

export default MainImageforDetail
