class MoviesController < ApplicationController
  def show
    @movie = Movie.includes(:genres).find(params[:id])
  end

  def index
    @movies = Movie.includes(:genres).order(:id).paginate(page: params[:page], per_page: 20)
    @liked_movie_ids = current_user.likes.where(movie_id: @movies.pluck(:id)).pluck(:movie_id)
  end

  def liked
    @movies = current_user.liked_movies.includes(:genres).order("likes.created_at DESC").paginate(page: params[:page], per_page: 20)
    @liked_movie_ids = current_user.likes.where(movie_id: @movies.pluck(:id)).pluck(:movie_id)
    render :index
  end

  def recommended
    @movies = current_user.recommended_movies.includes(:genres).paginate(page: params[:page], per_page: 20)
    @liked_movie_ids = current_user.likes.where(movie_id: @movies.pluck(:id)).pluck(:movie_id)
    render :index
  end

end
