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
                      <ul class="social-network social-circle">
                       <li><a href="https://www.facebook.com/" class="icoFacebook" title="Facebook"><i class="fa fa-facebook"></i></a></li>
                       <li><a href="https://www.instagram.com/" class="icoInstagram" title="Instagram"><i class="fa fa-instagram"></i></a></li>
                       <li><a href="https://www.twitter.com/" class="icoTwitter" title="Twitter"><i class="fa fa-twitter"></i></a></li>
                       <li><a href="https://www.github.com/" class="icoGithub" title="Github"><i class="fa fa-github"></i></a></li>
                      </ul>				
                    </div>
                </div>
            </div>
            <div className="row justify-content-center">             
                <div className="col-auto">
                    For Any Queries or further Informataion please<a href="mailto:prajapatijimil@yahoo.com"> Contact Us. </a>
                     &copy; Copyright 2020 Show Tracker 
                </div>
            </div>
        </div>
    </div>
    );
}

export default Footer;