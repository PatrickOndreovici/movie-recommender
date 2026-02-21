class LikesController < ApplicationController
  before_action :set_movie

  def create
    current_user.likes.find_or_create_by!(movie: @movie)
    render partial: "movies/likes/like_button", locals: { movie: @movie }
  end

  def destroy
    current_user.likes.find_by(movie: @movie)&.destroy
    render partial: "movies/likes/like_button", locals: { movie: @movie }
  end

  private

  def set_movie
    @movie = Movie.find(params[:movie_id])
  end
end
