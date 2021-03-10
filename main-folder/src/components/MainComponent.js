import React, { Component } from 'react';
import Header from './HeaderComponent';
import Footer from './FooterComponent';
import Home from './HomeComponent';
import { Switch, Route, BrowserRouter, Redirect } from 'react-router-dom';
import Signup from './SignupComponent';
import Signin from './SigninComponent';
import Profile from './ProfileComponent';

const LoginContainer = () => (
    <div>
      <Route exact path="/" render={() => <Redirect to="/home" />} />
      <Route path="/login" component={Signin} />
    </div>
  );

const SignupContainer = () => (
<div>
    <Route exact path="/" render={() => <Redirect to="/home" />} />
    <Route path="/signup" component={Signup} />
</div>
);

const DefaultContainer = () => (
    <div>
        <Header />
        <Route path='/home' component={Home} />
        <Route path='/profile' component={Profile} />
        <Redirect to="/home" />
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