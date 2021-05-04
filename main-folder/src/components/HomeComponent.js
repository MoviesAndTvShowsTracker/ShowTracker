import React from "react";
import { Helmet } from "react-helmet";
import { Link } from "react-router-dom";
import { Button } from "reactstrap";
import '../homepage.css';

function Home(props) {
    return ( 
		<>
		<Helmet>
            <title>Show Tracker - Track your favorite Movies and TV Shows</title>
        </Helmet>
		<div className="our-story-container" dir="ltr">
		<div className="our-story-header-wrapper">
		</div>
		<div className="our-story-cards" data-uia-our-story="our-story-cards">
			<div className="our-story-card hero-card vlv" style={{height:'92vh'}}>
				<div className="our-story-card-background">
					<div>
						<div className="concord-img-wrapper" data-uia="concord-img-wrapper">
							<img className="concord-img vlv-creative" src="https://assets.nflxext.com/ffe/siteui/vlv3/0f67308d-db59-4393-9502-8e475c69a0b5/7de023fa-e7bc-44ef-a9c3-2e6a18b9ba3c/IN-en-20200928-popsignuptwoweeks-perspective_alpha_website_small.jpg" srcSet="https://assets.nflxext.com/ffe/siteui/vlv3/0f67308d-db59-4393-9502-8e475c69a0b5/7de023fa-e7bc-44ef-a9c3-2e6a18b9ba3c/IN-en-20200928-popsignuptwoweeks-perspective_alpha_website_small.jpg 1000w, https://assets.nflxext.com/ffe/siteui/vlv3/0f67308d-db59-4393-9502-8e475c69a0b5/7de023fa-e7bc-44ef-a9c3-2e6a18b9ba3c/IN-en-20200928-popsignuptwoweeks-perspective_alpha_website_medium.jpg 1500w, https://assets.nflxext.com/ffe/siteui/vlv3/0f67308d-db59-4393-9502-8e475c69a0b5/7de023fa-e7bc-44ef-a9c3-2e6a18b9ba3c/IN-en-20200928-popsignuptwoweeks-perspective_alpha_website_large.jpg 1800w" alt=""/>
							<div className="concord-img-gradient">
							</div>
						</div>
					</div>
				</div>
				<div className="our-story-card-text">
					<h1 id="" className="our-story-card-title font-weight-bolder" data-uia="hero-title">Track Your favorite TV Shows and Movies</h1>
					<h2 id="" className="our-story-card-subtitle" data-uia="our-story-card-subtitle">All in one place.</h2>
					<form className="cta-form email-form" data-uia="email-form" method="GET">
						<h3 className="email-form-title">Find where to watch TV &amp; movies and discover what's hot.</h3>
						<div className="email-form-lockup">
							{!localStorage.getItem('user') &&
							<div className="our-story-cta-container cta-link-wrapper">
								<Link to="/signup">
								<button className="btn btn-primary nmhp-cta" >
								<span id="" className="cta-btn-txt" data-uia=""> Join ShowTracker</span>
								</button>
								</Link>
							</div> }
							{localStorage.getItem('user') &&
							<div className="our-story-cta-container cta-link-wrapper">
								
								<button className="btn btn-primary nmhp-cta" >
								<span id="" className="cta-btn-txt" data-uia=""><a href="#explore" style={{textDecoration:'none', color:'white'}}>Explore The Features </a></span>
								</button>
								
							</div> }
						</div>
					</form>
				</div>
			</div>
			<div className="our-story-card animation-card watchOnTv" data-uia-our-story="watchOnTv" data-uia="our-story-card" id="explore">
				<div className="animation-card-container">
					<div className="our-story-card-text">
						<h1 className="d-none d-sm-block our-story-card-title" data-uia="animation-card-title">Let us be your Guide.</h1>
						<h3 className="our-story-card-subtitle" data-uia="our-story-card-subtitle"><span className="fa fa-search-plus"></span> Discover something new</h3>
						<h3 className="our-story-card-subtitle" data-uia="our-story-card-subtitle"><span className="fa fa-bell-o"></span> Keep tabs on your TV and Movies</h3>
					</div>
					<div className="our-story-card-img-container">
						<div className="our-story-card-animation-container">
							<img alt="" className="our-story-card-img" src="https://assets.nflxext.com/ffe/siteui/acquisition/ourStory/fuji/desktop/tv.png" data-uia="our-story-card-img"/>
							<div className="our-story-card-animation">
								<video className="our-story-card-video" autoplay="" playsinline="" muted="" loop="">
									<source src="htps://assets.nflxext.com/ffe/siteui/acquisition/ourStory/fuji/desktop/video-tv-in-0819.m4v" type="video/mp4"/>
								</video>
								<div className="our-story-card-animation-text">
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
			<div className="d-none d-sm-block">
				<div className="our-story-card animation-card downloadAndWatch flipped" data-uia-our-story="downloadAndWatch" data-uia="our-story-card">
					<div className="animation-card-container">
						<div className="our-story-card-text">
							<h1 id="" className="our-story-card-title" data-uia="animation-card-title">Save Your Shows and Movies</h1>
							<h3 id="" className="our-story-card-subtitle" data-uia="our-story-card-subtitle"><span className="fa fa-check-circle-o"></span> With Show Tracker never forget where you were. </h3>
							<h3 id="" className="our-story-card-subtitle" data-uia="our-story-card-subtitle"><span className="fa fa-bookmark-o"></span> Make your Watchlist, Favorites and many more . . . </h3>
						</div>
						<div className="d-none d-sm-block our-story-card-img-container">
							<div className="our-story-card-animation-container">
								<img alt="" className="our-story-card-img" src="images/Shows.png" data-uia="our-story-card-img"/>
							</div>
						</div>
					</div>
				</div>
			</div>
			{!localStorage.getItem('user') &&
				<div className="our-story-card animation-card watchOnTv" data-uia-our-story="watchOnTv" data-uia="our-story-card">
					<div className="animation-card-container">
						<div className="our-story-card-text">
							<h1 id="" className="d-none d-sm-block our-story-card-title" data-uia="animation-card-title">Now Let's get you going</h1>
							<h4 id="" className="our-story-card-subtitle mb-2" data-uia="our-story-card-subtitle">Make Your Profile and start Tracking! </h4>
							<div className="row">
								<div className="col mb-2">
									<Link to="/signup">
										<Button className="btn btn-red btn-block">Signup</Button>
									</Link>
								</div>
								<div className="col">
									<Link to="/login">
										<Button className="btn btn-blue btn-block">Login</Button>
									</Link>
								</div>
							</div>
						</div>
						<div className="our-story-card-img-container">
							<div className="our-story-card-animation-container">
								<img alt="" className="our-story-card-img" src="images/Demoss.png" style={{marginTop: "15px"}} data-uia="our-story-card-img"/>
								<div className="our-story-card-animation">

									<div className="our-story-card-animation-text">
									</div>
								</div>
							</div>
						</div>
					</div>
				</div> }
			</div>
	</div>
	</>
    );
}

export default Home;