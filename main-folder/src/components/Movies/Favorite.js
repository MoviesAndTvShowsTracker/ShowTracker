import React, { useEffect, useState } from 'react'
import axios from 'axios';

function Favorite(props) {

    const [FavoriteNumber, setFavoriteNumber] = useState(0);
    const [Favorited, setFavorited] = useState(false);
    const [Watched, setWatched] = useState(false);

    const variable = {
        userFrom: props.userFrom,
        movieId: props.movieId,
        movieTitle: props.movieInfo.original_title,
        movieImage: props.movieInfo.backdrop_path,
        movieRuntime: props.movieInfo.runtime
    }

    useEffect(() => {

        axios.post('http://localhost:5000/api/favorite/favoriteNumber', variable)
        .then(response => {
            if(response.data.success) {
                setFavoriteNumber(response.data.favoriteNumber);
            }
            else {
                alert('Failed to perform operation')
            }
        })

        axios.post('http://localhost:5000/api/favorite/favorited', variable)
        .then(response => {
            if(response.data.success) {
                setFavorited(response.data.favorited);
            }
            else {
                alert('Failed to perform operation');
            }
        })

        axios.post('http://localhost:5000/api/watch/watched', variable)
        .then(response => {
            if(response.data.success) {
                setWatched(response.data.watched);
            }
            else {
                alert('Failed to perform operation');
            }
        })
    }, [])

    const onClickFavorite = () => {
        if(Favorited) {
            axios.post('http://localhost:5000/api/favorite/removeFromFavorite', variable)
            .then(response => {
                if(response.data.success) {
                    setFavoriteNumber(FavoriteNumber - 1);
                    setFavorited(!Favorited);
                }
                else {
                    alert('Failed to remove from Favorites');
                }
            })
        }
        else {
            axios.post('http://localhost:5000/api/favorite/addToFavorite', variable)
            .then(response => {
                if(response.data.success) {
                    setFavoriteNumber(FavoriteNumber + 1);
                    setFavorited(!Favorited);
                }
                else {
                    alert('Failed to add to Favorites');
                }
            })
        }
    }

    const onClickWatched = () => {
        if(Watched) {
            axios.post('http://localhost:5000/api/watch/removeFromWatched', variable)
            .then(response => {
                if(response.data.success) {
                    setWatched(!Watched);
                }
                else {
                    alert('Failed to remove from Watched');
                }
            })
        }
        else {
            axios.post('http://localhost:5000/api/watch/addToWatch', variable)
            .then(response => {
                if(response.data.success) {
                    setWatched(!Watched);
                }
                else {
                    alert('Failed to add to Watched');
                }
            })
        }
    }

    return (
        <div>
            <button className="btn btn-primary" onClick={onClickFavorite}> {Favorited ? "Remove from Favorites" : "Add to Favorites"} <span className="badge badge-light"> {FavoriteNumber} </span></button>
            <button className={Watched ? "btn btn-success ml-3" : "btn btn-primary ml-3"}  onClick={onClickWatched}> {Watched ? "Watched!" : "Watched?"} </button>
        </div>
    )
}

export default Favorite;
