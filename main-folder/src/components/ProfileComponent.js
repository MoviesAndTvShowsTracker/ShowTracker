import React from 'react';
import { Link, NavLink, Redirect } from 'react-router-dom';
import swal from 'sweetalert';
import { withRouter} from "react-router-dom";

function logout() {
    swal("Do you want to Logout?", {
      buttons: {
        nope: {
          text: "No",
          value: "no"
        },
        sure: {
          text: "I'm, Sure",
          value: "logout"
        }
      }
    }).then(value => {
      switch (value) {
        case "logout":
          swal(" Logged out Successfully")
          .then(val => {
            localStorage.clear();
            return window.history.go('/home');
          });
          break;
        case "no":
          swal("Ok", "success");
          break;
        default:
          swal("Got away safely!");
      }
    });
  };

const Profile = (props) => {

    return( 
        
        <div> 
            {!localStorage.getItem('user') &&
           <Link to="/login">
            <h1 style={{color: "black"}}>Please Login to view this page</h1>
            <button className="mt-2 mb-2 offset-6 btn btn-primary">Login</button>
           </Link>
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