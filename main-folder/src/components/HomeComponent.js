import React from "react";
import '../homepage.css';

function Home(props) {
    return ( 
		<div className="our-story-container" dir="ltr">
		<div className="our-story-header-wrapper">
		</div>
		<div className="our-story-cards" data-uia-our-story="our-story-cards">
			<div className="our-story-card hero-card vlv" data-uia-our-story="hero_fuji" data-uia="our-story-card">
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
					<h1 id="" className="our-story-card-title" data-uia="hero-title">Track your movies, TV shows and more.</h1>
					<h2 id="" className="our-story-card-subtitle" data-uia="our-story-card-subtitle">Find anytime, anywhere.</h2>
					<form className="cta-form email-form" data-uia="email-form" method="GET">
						<h3 className="email-form-title">Ready to Track? Enter your email to create your watchlist.</h3>
						<div className="email-form-lockup">
							
							<div className="our-story-cta-container cta-link-wrapper">
								<button className="btn btn-red nmhp-cta btn-none btn-custom" type="submit" autoComplete="off" tabindex="0" role="link" data-uia="our-story-cta-hero_fuji">
								<span id="" className="cta-btn-txt" data-uia="">GET STARTED</span>
								<span id="" className="chevron-right-arrow" data-uia="">
									<svg viewBox="0 0 6 12" xmlns="http://www.w3.org/2000/svg">
										<desc>chevron</desc>
										<path d="M.61 1.312l.78-.624L5.64 6l-4.25 5.312-.78-.624L4.36 6z" fill="none" fill-rule="evenodd"></path>
									</svg>
								</span>
								</button>
							</div>
						</div>
					</form>
					<h3 id="" className="our-story-card-disclaimer" data-uia="our-story-card-disclaimer"></h3>
				</div>
			</div>
			<div className="our-story-card animation-card watchOnTv" data-uia-our-story="watchOnTv" data-uia="our-story-card">
				<div className="animation-card-container">
					<div className="our-story-card-text">
						<h1 id="" className="our-story-card-title" data-uia="animation-card-title">Enjoy on your TV.</h1>
						<h2 id="" className="our-story-card-subtitle" data-uia="our-story-card-subtitle">Watch on smart TVs, PlayStation, Xbox, Chromecast, Apple TV, Blu-ray players and more.</h2>
					</div>
					<div className="our-story-card-img-container">
						<div className="our-story-card-animation-container">
							<img alt="" className="our-story-card-img" src="https://assets.nflxext.com/ffe/siteui/acquisition/ourStory/fuji/desktop/tv.png" data-uia="our-story-card-img"/>
							<div className="our-story-card-animation">
								<video className="our-story-card-video" autoplay="" playsinline="" muted="" loop="">
									<source src="https://assets.nflxext.com/ffe/siteui/acquisition/ourStory/fuji/desktop/video-tv-in-0819.m4v" type="video/mp4"/>
								</video>
								<div className="our-story-card-animation-text">
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
			<div className="our-story-card animation-card downloadAndWatch flipped" data-uia-our-story="downloadAndWatch" data-uia="our-story-card">
				<div className="animation-card-container">
					<div className="our-story-card-text">
						<h1 id="" className="our-story-card-title" data-uia="animation-card-title">Download your shows to watch offline.</h1>
						<h2 id="" className="our-story-card-subtitle" data-uia="our-story-card-subtitle">Save your favourites easily and always have something to watch.</h2>
					</div>
					<div className="our-story-card-img-container">
						<div className="our-story-card-animation-container">
							<img alt="" className="our-story-card-img" src="https://assets.nflxext.com/ffe/siteui/acquisition/ourStory/fuji/desktop/mobile-0819.jpg" data-uia="our-story-card-img"/>
						</div>
					</div>
				</div>
			</div>
			<div className="our-story-card animation-card watchOnTv" data-uia-our-story="watchOnTv" data-uia="our-story-card">
				<div className="animation-card-container">
					<div className="our-story-card-text">
						<h1 id="" className="our-story-card-title" data-uia="animation-card-title">Enjoy on your TV.</h1>
						<h2 id="" className="our-story-card-subtitle" data-uia="our-story-card-subtitle">Watch on smart TVs, PlayStation, Xbox, Chromecast, Apple TV, Blu-ray players and more.</h2>
					</div>
					<div className="our-story-card-img-container">
						<div className="our-story-card-animation-container">
							<img alt="" className="our-story-card-img" src="https://assets.nflxext.com/ffe/siteui/acquisition/ourStory/fuji/desktop/tv.png" data-uia="our-story-card-img"/>
							<div className="our-story-card-animation">
								<video className="our-story-card-video" autoplay="" playsinline="" muted="" loop="">
									<source src="https://assets.nflxext.com/ffe/siteui/acquisition/ourStory/fuji/desktop/video-tv-in-0819.m4v" type="video/mp4"/>
								</video>
								<div className="our-story-card-animation-text">
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
	</div>
    );
}

export default Home;