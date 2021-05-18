import React, { Component } from 'react';
import { Navbar, NavbarBrand, Nav, NavbarToggler, Collapse, NavItem, UncontrolledDropdown, DropdownToggle, DropdownMenu, DropdownItem} from 'reactstrap';
import { NavLink } from 'react-router-dom';
import swal from 'sweetalert';
import logo from '../logo.png';

function logout() {
    swal("Do you want to Logout?", "", "warning", {
      buttons: {
        cancel: true,
        sure: {
          text: "I'm, Sure",
          value: "logout",
          className: "swal-confirm"
        }
      }
    }).then(value => {
      switch (value) {
        case "logout":
          swal("", "", 'success', {
            buttons: {
                Done: {
                  className: "swal-confirm"
                }
            }
          })
          .then(val => {
            localStorage.clear();
            return window.history.go('/');
          });
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

    mobileToggle = () => {
        if( /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) ) {
         this.toggleNav()
        };
    };

    render() {
        
        return(
            <React.Fragment>
                <Navbar dark expand="md" color="primary" sticky="top">
                    <div className="container">
                        <NavbarBrand href="/" className="mr-auto" >
                            <img src={logo} height="30" width="41" alt="Show Tracker" />  Show Tracker
                        </NavbarBrand>
                        <NavbarToggler onClick={this.toggleNav} className="ml-auto" />
                        
                        <Collapse isOpen={this.state.isNavOpen} navbar>
                            <Nav navbar className="ml-auto">
                                <NavItem>
                                    <NavLink className="nav-link" to='/tv' onClick={() => this.mobileToggle()}><span className="fa fa-tv fa-lg"></span> TV</NavLink>
                                </NavItem>
                                <NavItem>
                                    <NavLink className="nav-link" to='/movies' onClick={() => this.mobileToggle()}><span className="fa fa-film fa-lg"></span> Movies</NavLink>
                                </NavItem>
                                <NavItem>
                                    <NavLink className="nav-link" to='/search' onClick={() => this.mobileToggle()}><span className="fa fa-search fa-lg"></span> Search</NavLink>
                                </NavItem>
                                {!localStorage.getItem('user') &&
                                    <NavItem>
                                        <NavLink className="nav-link" to='/login' onClick={() => this.mobileToggle()}><span className="fa fa-sign-in fa-lg"></span>  Login</NavLink>
                                    </NavItem>
                                }
                                {!localStorage.getItem('user') ||
                                    <UncontrolledDropdown nav inNavbar>
                                        <DropdownToggle nav caret>
                                            {localStorage.getItem('myuser')}
                                        </DropdownToggle>
                                        <DropdownMenu right>
                                            <NavItem>
                                                <NavLink to='/profile' className="text-decoration-none" style={{color: 'black'}} onClick={() => this.mobileToggle()}>
                                                    <DropdownItem> <span className="fa fa-user-circle-o"></span> Profile</DropdownItem>
                                                </NavLink>
                                            </NavItem>
                                            <DropdownItem onClick={logout}> <span className="fa fa-sign-out"></span> Logout</DropdownItem>
                                        </DropdownMenu>
                                  </UncontrolledDropdown>
                                }
                            </Nav>
                        </Collapse>
                    </div>
                </Navbar>
                </React.Fragment>
        );
    }
}

export default Header;
