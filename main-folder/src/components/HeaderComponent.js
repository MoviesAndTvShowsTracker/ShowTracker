import React, { Component } from 'react';
import { Navbar, NavbarBrand, Nav, NavbarToggler, Collapse, NavItem} from 'reactstrap';
import { NavLink } from 'react-router-dom';
import swal from 'sweetalert';
import logo from '../logo.png';

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
          swal("", "", 'success')
          .then(val => {
            localStorage.clear();
            return window.history.go('/home');
          });
          break;
        default:
            swal("Nothing happened");
            break;
      }
    });
  };

class Header extends Component {

    constructor(props) {
        super(props);
        this.state = {
            isNavOpen: false,
        };
        this.toggleNav = this.toggleNav.bind(this);
    }

    toggleNav() {
        this.setState({
            isNavOpen: !this.state.isNavOpen
        });
    }

    render() {
        
        return(
            <React.Fragment>
                <div className="header">
                <Navbar dark expand="md" color="primary">
                    <div className="container">
                        <NavbarToggler onClick={this.toggleNav} />
                        <NavbarBrand href="/" className="mr-auto" >
                            <img src={logo} height="30" width="41" alt="Show Tracker" />  Show Tracker
                        </NavbarBrand>
                        
                        <Collapse isOpen={this.state.isNavOpen} navbar>
                            <Nav navbar className="ml-auto">
                                <NavItem>
                                    <NavLink className="nav-link"  to='/tv'><span className="fa fa-tv fa-lg"></span> TV</NavLink>
                                </NavItem>
                                <NavItem>
                                    <NavLink className="nav-link" to='/movies'><span className="fa fa-film fa-lg"></span> Movies</NavLink>
                                </NavItem>
                                <NavItem>
                                    <NavLink className="nav-link"  to='/profile'><span className="fa fa-user-circle-o fa-lg"></span> Profile</NavLink>
                                </NavItem>
                                {!localStorage.getItem('user') &&
                                    <NavItem>
                                        <NavLink className="nav-link" to='/login'><span className="fa fa-sign-in fa-lg"></span>  Login</NavLink>
                                    </NavItem>
                                }
                                {!localStorage.getItem('user') ||
                                    <button class="btn btn-primary" onClick= {logout}>Logout</button>
                                }
                            </Nav>
                        </Collapse>
                    </div>
                </Navbar>
                </div>
                </React.Fragment>
        );
    }
}

export default Header;
