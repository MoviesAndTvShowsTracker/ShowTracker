import React from 'react';
import { Row} from 'reactstrap';


function MainImage(props) {
    return (
        <div style={{
            background:`url('${props.image}'), #1c1c1c`,
            height: '60vh',
            backgroundPosition: 'center',
            width: '100%',
            position: 'relative'
        }}>
            <div>
                <div style={{ position: 'absolute', maxWidth: '500px', bottom: '2rem', marginLeft: '2rem' }}>
                    <div style={{ color: 'white' }} className="h2 font-weight-bolder" > {props.title}</div>
                    <p style={{ color: 'white', fontSize: '1rem' }}>{props.text}</p>
                </div>
            </div>

        </div>
    )
}

export default MainImage
