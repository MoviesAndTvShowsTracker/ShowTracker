import axios from 'axios';
import React, { useEffect, useState } from 'react';

function TvFavorites(props) {

    const [FavoriteNumber, setFavoriteNumber] = useState(0);
    const [Favorited, setFavorited] = useState(false);

    const variable = {
        userFrom: props.userFrom,
        tvId: props.tvId,
        tvTitle: props.tvInfo.name,
        tvImage: props.tvInfo.backdrop_path,
        tvPosterImage: props.tvInfo.poster_path,
        tvRuntime: props.tvInfo.episode_run_time
    }
    
    useEffect(() => {

        axios.post('http://localhost:5000/api/tv/favorite/favoriteNumber', variable)
        .then(response => {
            if(response.data.success) {
                setFavoriteNumber(response.data.favoriteNumber);
            }
            else {
                alert('Failed to perform operation')
            }
        })

        axios.post('http://localhost:5000/api/tv/favorite/favorited', variable)
        .then(response => {
            if(response.data.success) {
                setFavorited(response.data.favorited);
            }
            else {
                alert('Failed to perform operation');
            }
        })
    }, [])

    const onClickFavorite = () => {
        if(Favorited) {
            axios.post('http://localhost:5000/api/tv/favorite/removeFromFavorite', variable)
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
            axios.post('http://localhost:5000/api/tv/favorite/addToFavorite', variable)
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

    return (
        <div>
            <button className={Favorited ? "btn btn-danger" : "btn btn-primary"} onClick={onClickFavorite}> {Favorited ? "Remove from Favorites" : "Add to Favorites"} <span className="badge badge-light"> {FavoriteNumber} </span></button>
        </div>
    )
}

export default TvFavorites;
