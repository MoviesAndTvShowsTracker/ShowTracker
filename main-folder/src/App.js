import React, { Component } from 'react';
import './App.css';
import { Navbar, NavbarBrand } from 'reactstrap';
import Main from './components/MainComponent';
import { BrowserRouter } from 'react-router-dom';

class App extends Component {
  render() {
    return(
      <BrowserRouter>
        <Main />
      </BrowserRouter>
      
    );
  }
}

export default App;
