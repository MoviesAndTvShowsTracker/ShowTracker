import React, { Component } from 'react';
import Header from './HeaderComponent';
import Footer from './FooterComponent';
import Home from './HomeComponent';
import { Switch, Route, Redirect, BrowserRouter, withRouter } from 'react-router-dom';
import Signup from './SignupComponent';
import Signin from './SigninComponent';
import Profile from './ProfileComponent';
import LandingPage from './Movies/LandingComponent';
import MovieDetail from './Movies/MovieDetail';
import TvDetail from './TV/TvShowDetail';
import TvLandingPage from './TV/TvLandingComponent';
import SearchBox from './SearchComponent';
import SeasonEpisodes from './TV/SeasonEpisodes';

const isLoggedIn = () => {
    return localStorage.getItem('user') != null;
  };

const SecuredRoute = ({ component: Component, ...rest }) => (
    <Route
        {...rest}
        render={props =>
        
        isLoggedIn() === true ? (
            <Component {...props} />
        ) : (
            <Redirect to="/login" />
        )
        }
    />
)

const LoginContainer = () => (
    <div>
      <Route path="/login" component={Signin} />
    </div>
  );

const SignupContainer = () => (
    <div>
        <Route path="/signup" component={Signup} />
    </div>
);

const DefaultContainer = () => (
    <div>
        <Header />
        <Switch>
            <Route exact path='/' component={Home} />
            <SecuredRoute exact path='/profile' component={Profile} />
            <SecuredRoute exact path='/movies/:Id' component={withRouter(MovieDetail)} />
            <SecuredRoute exact path='/movies' component={LandingPage} />
            <Route path='/search' component={SearchBox} />
            <SecuredRoute exact path='/tv' component={TvLandingPage} />
            <SecuredRoute exact path='/tv/:Id' component={withRouter(TvDetail)} />
            <SecuredRoute exact path='/tv/:Id/:seasonNumber/episodes' component={withRouter(SeasonEpisodes)} />
            <Redirect to={Home}/>
        </Switch>
    </div>
);

class Main extends Component {

    render() {
        return(
            <div>
                <BrowserRouter>
                <Switch>
                    <Route exact path="/login" component={LoginContainer}/>
                    <Route exact path="/signup" component={SignupContainer}/>
                    <Route component={DefaultContainer}/>  
                </Switch>
                <Footer />
                </BrowserRouter>
            </div>
        );
    }
}

export default Main;