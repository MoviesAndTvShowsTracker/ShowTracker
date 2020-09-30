import React, { Component } from 'react';
import { Link } from 'react-router-dom';

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

class Signin extends Component {
  constructor(props) {
    super(props);

    this.state = {
      username: null,
      password: null,
      formErrors: {
        username: "",
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

    this.setState({
      username: "",
      password: "" });

    if (formValid(this.state)) {
      console.log(`
        --SUBMITTING--
        Username: ${this.state.username}
        Password: ${this.state.password}
      `); //above is only for experiment purposes. 
    } else {
      console.error("FORM INVALID - Fill up the form first");
      alert("Please fill the form correctly.");
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

    render() {
      const { formErrors } = this.state;

        return (
          <div className="wrapper">
          <div className="form-wrapper">
            <h1>Create Account</h1>
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
                />
                {formErrors.password.length > 0 && (
                  <span className="errorMessage">{formErrors.password}</span>
                )}
              </div>
              <div className="createAccount">
                <button type="submit" onClick = { this.handleSubmit } >Login</button>
                <small><Link to= '/signup'> Don't have an account? </Link></small>
              </div>
            </form>
          </div>
        </div>
        );
    }
}

export default Signin;
