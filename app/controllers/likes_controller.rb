class LikesController < ApplicationController
  before_action :set_movie

  def create
    current_user.likes.find_or_create_by!(movie: @movie)
    redirect_back fallback_location: movies_path, notice: "Liked!"
  end

  def destroy
    current_user.likes.find_by(movie: @movie)&.destroy
    redirect_back fallback_location: movies_path, notice: "Unliked."
  end

  private

  def set_movie
    @movie = Movie.find(params[:movie_id])
  end
end
