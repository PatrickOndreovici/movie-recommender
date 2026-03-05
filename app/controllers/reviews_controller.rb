class ReviewsController < ApplicationController
  before_action :set_movie

  def create
    @review = current_user.reviews.find_or_initialize_by(movie: @movie)
    @review.rating = review_params[:rating].to_i
    if @review.save
      render partial: "movies/reviews/rating_widget", locals: { movie: @movie }, status: :ok
    else
      render partial: "movies/reviews/rating_widget", locals: { movie: @movie }, status: :unprocessable_entity
    end
  end

  def update
    create
  end

  private

  def set_movie
    @movie = Movie.find(params[:movie_id])
  end

  def review_params
    params.require(:review).permit(:rating)
  end
end
