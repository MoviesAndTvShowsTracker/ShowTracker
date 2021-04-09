import React, { Component } from 'react';
import { Link, Redirect } from 'react-router-dom';

import axios from 'axios';
import swal from 'sweetalert';

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
      username: "",
      password: "",
      successFlag : null ,
      userName: "",
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

  componentWillMount() {
    this.setState({
        successFlag : false
    })
  }

  componentDidMount() {
    if (localStorage.getItem("user") != null) {
        return this.props.history.goBack();
     }
   }

  handleSubmit = e => {
    e.preventDefault();
   
    
    this.setState({
      username: "",
      password: "",
      userName: this.state.username
   });


    if (formValid(this.state)) {

      var data = {
        username : this.state.username,
        password : this.state.password,
      }

      axios.defaults.withCredentials = true;
      axios.post('http://localhost:5000/users/login', data)
      .then(res => {
        console.log("Sent from back-end : " , res.data.status , "    "  , res.data.token);

        if(res.data.status === 200){
          localStorage.setItem('myuser', this.state.userName);
          localStorage.setItem("user",res.data.token);
          localStorage.setItem('userId', res.data.userId);
          alert("Successfully logged in");         
          this.setState({
            successFlag: true
          });
        }
      })
      console.log(`
        --SUBMITTING--
        Username: ${this.state.username}
        Password: ${this.state.password}
      `); //TODO: above is only for experiment purposes. 
    } else {
      swal("FORM INVALID - Fill up the detais first");
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
        var redirectVar = null;

        if(this.state.successFlag){
            return(
              <Redirect to="/profile" />
              );  
        }
        
        const { formErrors } = this.state;

        return (
          
          <div className="wrapper">
            <div>
              {/* Breadcrumbs */}
              <nav aria-label="breadcrumb" className="position-absolute" style={{top: '2rem', right: '2rem'}}>
                        <ol className="breadcrumb">
                            <li className="breadcrumb-item"><Link to='/'>Home</Link></li>
                            <li className="breadcrumb-item active" aria-current="page">Sign-in</li>
                        </ol>
              </nav>
            </div>
          <div className="form-wrapper">
            {redirectVar}

            <h1 className="font-weight-lighter" style={{color: "black"}}> Login</h1>
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
