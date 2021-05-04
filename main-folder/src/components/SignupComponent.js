import React, { Component } from 'react';
import { Link } from 'react-router-dom';

import axios from 'axios';
import Signin from './SigninComponent';
import swal from 'sweetalert';
import { Helmet } from 'react-helmet';

const emailRegex = RegExp(
  /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
);

const formValid = ({ formErrors, ...rest }) => {
  let valid = true;

  // validate form errors being empty
  Object.values(formErrors).forEach(val => {
    val.length > 0 && (valid = false);
  });

  // validate the form was filled out
  Object.values(rest).forEach(val => {
    val === null && (valid = false);
  });

  return valid;
};

class Signup extends Component {
  constructor(props) {
    super(props);

    this.state = {
      username: "",
      firstName: "",
      lastName: "",
      email: "",
      password: "",
      successFlag: false,
      formErrors: {
        username:"",
        firstName: "",
        lastName: "",
        email: "",
        password: ""
      }
    };

    this.handleChange = this.handleChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }

  handleSubmit = e => {
    e.preventDefault();
    {/* isempty checks if all field contain value */}
    const isempty = this.state.username && this.state.firstName && this.state.lastName && this.state.email && this.state.password
    if (formValid(this.state) && isempty) {

      var data = {
        username: this.state.username,
        firstName: this.state.firstName,
        lastName: this.state.lastName,
        email: this.state.email,
        password: this.state.password
      }

      this.setState({
        username:"",
        firstName: "",
        lastName: "",
        email: "",
        password: "" 
      });
      
      axios.defaults.withCredentials = true;
        axios.post('http://localhost:5000/users/signup', data)
         .then(res => {
            console.log("From Back-end : " + res.data.status);
            
            if(res.data.status === 200){
              this.setState({
                  successFlag: true
              })
              alert("Registration Successful!");
            }
        })
    } 
    else {
      swal("Fill up the detais first", "", "warning",  {
        buttons: {
            sure: {
              text: "Okay",
              className: "swal-confirm"
            }
          }
        });
      }
  };

  handleChange = e => {
    e.preventDefault();
    const { name, value } = e.target;
    let formErrors = { ...this.state.formErrors };

    switch (name) {
      case "username":
        formErrors.username =
          value.length < 3 ? "minimum 3 characaters required" : "";
        break;
      case "firstName":
        formErrors.firstName =
          value.length < 3 ? "minimum 3 characaters required" : "";
        break;
      case "lastName":
        formErrors.lastName =
          value.length < 3 ? "minimum 3 characaters required" : "";
        break;
      case "email":
        formErrors.email = emailRegex.test(value)
          ? ""
          : "invalid email address";
        break;
      case "password":
        formErrors.password =
          value.length < 6 ? "minimum 6 characaters required" : "";
        break;
      default:
        break;
    }

    this.setState({ formErrors, [name]: value });
  };

  componentDidMount() {
    if (localStorage.getItem("user") != null) {
        return this.props.history.goBack();
     }
   }

  render() {
    var redirectVar = null;

    if(this.state.successFlag){
      return <Signin />
    }
    const { formErrors } = this.state;

    return (
      <>
      <Helmet>
            <title>Create an account</title>
      </Helmet>
      <div className="wrapper">
          {/* Breadcrumbs */}
          <nav aria-label="breadcrumb" className="position-absolute" style={{top: '2rem', right: '2rem'}}>
              <ol className="breadcrumb">
                  <li className="breadcrumb-item"><Link to='/'>Home</Link></li>
                  <li className="breadcrumb-item active" aria-current="page">Sign-up</li>
              </ol>
          </nav>
        <div className="form-wrapper col-sm-6 col-md-4">
          {redirectVar}
          
          <h1 style={{color: "black"}}>Create Account</h1>

          <form onSubmit={this.handleSubmit} noValidate>
          <div className="email">
              <label htmlFor="username">Username</label>
              <input
                className={formErrors.username.length > 0 ? "error" : null}
                placeholder="Username"
                type="text"
                name="username"
                value={this.state.username}
                noValidate
                onChange={this.handleChange}
              />
              {formErrors.username.length > 0 && (
                <span className="errorMessage">{formErrors.username}</span>
              )}
            </div>
            <div className="firstName">
              <label htmlFor="firstName">First Name</label>
              <input
                className={formErrors.firstName.length > 0 ? "error" : null}
                placeholder="First Name"
                type="text"
                name="firstName"
                value={this.state.firstName}
                noValidate
                onChange={this.handleChange}
              />
              {formErrors.firstName.length > 0 && (
                <span className="errorMessage">{formErrors.firstName}</span>
              )}
            </div>
            <div className="email">
              <label htmlFor="lastName">Last Name</label>
              <input
                className={formErrors.lastName.length > 0 ? "error" : null}
                placeholder="Last Name"
                type="text"
                name="lastName"
                value={this.state.lastName}
                noValidate
                onChange={this.handleChange}
              />
              {formErrors.lastName.length > 0 && (
                <span className="errorMessage">{formErrors.lastName}</span>
              )}
            </div>
            <div className="email">
              <label htmlFor="email">Email</label>
              <input
                className={formErrors.email.length > 0 ? "error" : null}
                placeholder="Email"
                type="email"
                name="email"
                value={this.state.email}
                noValidate
                onChange={this.handleChange}
              />
              {formErrors.email.length > 0 && (
                <span className="errorMessage">{formErrors.email}</span>
              )}
            </div>
            <div className="password">
              <label htmlFor="password">Password</label>
              <input
                className={formErrors.password.length > 0 ? "error" : null}
                placeholder="Password"
                type="password"
                name="password"
                value={this.state.password}
                noValidate
                onChange={this.handleChange}
                autoComplete="on"
              />
              {formErrors.password.length > 0 && (
                <span className="errorMessage">{formErrors.password}</span>
              )}
            </div>
            <div className="createAccount">
              <button type="submit" onClick = { this.handleSubmit } >Create Account</button>
              <small><Link to= '/login'> Already Have an Account? </Link></small>
            </div>
          </form>
        </div>
      </div>
      </>
    );
  }
}

export default Signup;