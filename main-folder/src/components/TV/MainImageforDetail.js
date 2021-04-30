import React from 'react';
import Fade from 'react-reveal/Fade';


function MainImageforDetail(props) {
    return (
        <Fade top>
        <div style={{
            backgroundImage:`url('${props.image}')`,
            height: '75vh',
            position: 'relative',
            backgroundSize:'cover'
        }}>
            <div>
                <div style={{ position: 'absolute', maxWidth: '500px', bottom: '2rem', marginLeft: '2rem' }}>
                    <div style={{ color: 'white' }} className="h2 font-weight-bolder" > {props.title}</div>
                    <p style={{ color: 'white', fontSize: '1rem' }}>{props.text}</p>
                </div>
            </div>
        </div>
        </Fade>
    )
}

export default MainImageforDetail
