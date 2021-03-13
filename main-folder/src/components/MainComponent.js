import React, { Component } from 'react';
import Header from './HeaderComponent';
import Footer from './FooterComponent';
import Home from './HomeComponent';
import { Switch, Route, BrowserRouter, Redirect } from 'react-router-dom';
import Signup from './SignupComponent';
import Signin from './SigninComponent';
import Profile from './ProfileComponent';
import LandingPage from './Movies/LandingComponent';

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
        <Route path='/home' component={Home} />
        <SecuredRoute path='/profile' component={Profile} />
        <Route path='/movies' component={LandingPage} />
        <Redirect to='/home' />
    </div>
);

class Main extends Component {

    render() {
        return(
            <div>
                <Switch>
                    <Route exact path="/login" component={LoginContainer}/>
                    <Route exact path="/signup" component={SignupContainer}/>
                    <Route component={DefaultContainer}/>  
                </Switch>
                <Footer />
            </div>
        );
    }
}

export default Main;