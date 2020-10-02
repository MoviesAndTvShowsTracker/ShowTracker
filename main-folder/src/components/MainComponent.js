import React, { Component } from 'react';
import Header from './HeaderComponent';
import Footer from './FooterComponent';
import Home from './HomeComponent';
import { Switch, Route, Redirect } from 'react-router-dom';
import Signup from './SignupComponent';
import Signin from './SigninComponent';
import Profile from './ProfileComponent';

class Main extends Component {

    render() {

        return(
            <div>
                <Header />
                <Switch>
                    <Route path='/home' component={Home} />
                    <Route path='/signup' component={Signup} />
                    <Route path='/login' component={Signin} />
                    <Route path='/profile' component={Profile} />
                    <Redirect to="/home" />
                </Switch>
                <Footer />
            </div>
        );
    }
}

export default Main;