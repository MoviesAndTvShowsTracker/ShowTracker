import React from 'react';
import { Link } from 'react-router-dom';

function Footer(props) {
    return(
        <div className="footer">
        <div className="container">
            <div className="row justify-content-center">             
                <div className="col-4 offset-1 col-sm-2">
                    <h4>Links</h4>
                    <ul className="list-unstyled">
                        <li><Link to="/">Home</Link></li>
                        <li><Link to="/tv">TV</Link></li>
                        <li><Link to="/movies">Movies</Link></li>
                        <li><Link to="/profile">Profile</Link></li>
                        <li><Link to="/aboutus">About Us</Link></li>
                    </ul>
                </div>
                <div className="col-7 col-sm-5">
                    <h4>Reviews</h4>

                    
                </div>
                <div className="col-12 col-sm-4">
                    <div className="text-center">
                        <h4>Follow Us!</h4>
                      <ul className="social-network social-circle">
                       <li><a href="https://www.facebook.com/" className="icoFacebook" title="Facebook"><i className="fa fa-facebook"></i></a></li>
                       <li><a href="https://www.instagram.com/" className="icoInstagram" title="Instagram"><i className="fa fa-instagram"></i></a></li>
                       <li><a href="https://www.twitter.com/" className="icoTwitter" title="Twitter"><i className="fa fa-twitter"></i></a></li>
                       <li><a href="https://github.com/MoviesAndTvShowsTracker/ShowTracker" className="icoGithub" title="Github" target="_blank" rel="noopener noreferrer"><i className="fa fa-github"></i></a></li>
                      </ul>				
                    </div>
                </div>
            </div>
            <div className="row justify-content-center">             
                <div className="col-auto">
                    For any queries or further informataion please <a href="mailto:jprajapati2014@gmail.com" className="text-decoration-none">contact us. </a>
                    &copy; Copyright {(new Date().getFullYear())} Show Tracker 
                </div>
            </div>
        </div>
    </div>
    );
}

export default Footer;