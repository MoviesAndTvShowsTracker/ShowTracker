import React from 'react';

const Profile = (props) => {
    console.log("Props = ", props.data);
    return( 
        <div>
            <h1> Welcome { props.data.userName }</h1>
        </div>
    );
}
export default Profile;