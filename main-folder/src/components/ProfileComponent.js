import React from 'react';

const Profile = (props) => {

    function logout() {
        localStorage.removeItem('user');
        localStorage.removeItem('myuser');
        window.location.reload();
    }

    return( 
        
        <div> 
            {!localStorage.getItem('user') &&
           <h1 style={{color: "black"}}>Please Login to view this page</h1>
        }
        {!localStorage.getItem('user') ||
        <h1 style={{color: "black"}}> Welcome {localStorage.getItem('myuser')}
            </h1>        }
            
            <div className="container col-1">
            {localStorage.getItem('user') &&
                <button class="btn btn-primary" onClick= {logout}>Logout</button>
            }
              </div>
        </div>
    );
}
export default Profile;