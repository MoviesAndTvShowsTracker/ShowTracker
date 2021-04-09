import React, { Component, useState } from 'react'
import { API_KEY, API_URL, IMAGE_URL } from '../config/keys';
import { Link } from 'react-router-dom';
import GridCard from './Movies/GridCard';
import { Row } from 'reactstrap';
import TvGridCard from './TV/TvGridCard';
import swal from 'sweetalert';

class SearchBox extends Component {

    constructor(props) {
        super(props);
    
        this.state = {
          searchQuery: "",
          results: []
        }
    
        this.handleChange = this.handleChange.bind(this);
        this.handleSubmit = this.handleSubmit.bind(this);
        this.onChangeValue = this.onChangeValue.bind(this);
      }

    handleChange = (e) => {
        e.preventDefault();
        const { name, value } = e.target;
        this.setState({ [name]: value });
    }

    handleSubmit = (e) => {
        e.preventDefault();
        
        if(this.state.selectedOption) {
        var data = this.state.searchQuery;
        const url = `${API_URL}search/${this.state.selectedOption}?api_key=${API_KEY}&language=en-US&query=${encodeURI(data)}&page=1&include_adult=false`;
        console.log(url);
        fetch(url)
        .then(response => response.json())
        .then(response => {
            console.log(response);
            const result = response.results;
            this.setState({results: result});
        }) }
        else {
            swal("please select movies or tv show");
        }
    }

    onChangeValue(event) {
        this.setState({
            selectedOption: event.target.value
          });
    }

    render() {
    return (
        <>
        <div className="mt-3">
        {/* Breadcrumb */}
            <div style={{ width: '95%', margin: '1rem auto' }}>
                <nav aria-label="breadcrumb">
                    <ol className="breadcrumb">
                        <li className="breadcrumb-item"><Link to='/'>Home</Link></li>
                        <li className="breadcrumb-item active" aria-current="page">Search</li>
                    </ol>
                </nav>
            </div>

            <div className="row">
                <div className="col-6 offset-3">
                    <form className="form-group">
                        <div className="input-group">
                            <input 
                            className="form-control"
                            type="text"
                            placeholder= 'Search...'
                            onChange={this.handleChange}
                            name= 'searchQuery'
                            value={this.state.searchQuery} /> 
                            <button onClick={this.handleSubmit} type="submit" className="btn btn-primary input-group-addon" ><span className="fa fa-search fa-lg"></span></button>
                        </div>
                        {/* radio buttons */}
                        <div className="mt-2">
                            <div class="form-check">
                                <input 
                                class="form-check-input" 
                                type="radio" 
                                name="movie" 
                                value="movie"
                                checked={this.state.selectedOption === "movie"}
                                onChange={this.onChangeValue}
                                />
                                <span class="form-check-label font-weight-bold">
                                    Movies
                                </span>
                            </div>
                            <div class="form-check">
                                <input 
                                class="form-check-input" 
                                type="radio" 
                                value="tv" 
                                name="tvshow" 
                                checked={this.state.selectedOption === "tv"}
                                onChange={this.onChangeValue}
                                />
                                <span class="form-check-label font-weight-bold">
                                    TV Shows
                                </span>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div>

        {/* search results */}
        <div style={{ width: '95%', margin: '1rem auto' }}>
            <div className="text-center">
                <div className="font-weight-lighter h2"> Search Results </div>
                <div className="results">
                    {this.state.selectedOption === 'movie' ? 
                        <Row>
                            {this.state.results && this.state.results.map((movie, index) => (
                                <React.Fragment key={index}>
                                    {movie.poster_path && <GridCard 
                                        image={movie.poster_path && `${IMAGE_URL}w500${movie.poster_path}`}
                                        movieId={movie.id} movieTitle={movie.title} name={movie.original_title}
                                    />}
                                </React.Fragment>
                            ))}
                        </Row> 
                    :
                        <Row>
                            {this.state.results && this.state.results.map((tvshow, index) => (
                                <React.Fragment key={index}>
                                    {tvshow.poster_path && <TvGridCard 
                                        image={tvshow.poster_path && `${IMAGE_URL}w500${tvshow.poster_path}`}
                                        tvShowId={tvshow.id} tvShowTitle={tvshow.title} name={tvshow.original_title}
                                    />}
                                </React.Fragment>
                            ))}
                        </Row>   
                    }
                    
                </div>
            </div>
        </div>
        </>
    )
    }
}

export default SearchBox;
