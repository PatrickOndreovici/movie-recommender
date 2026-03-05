class Movie < ApplicationRecord
  TMDB_IMAGE_BASE = "https://image.tmdb.org/t/p/w500".freeze

  has_many :movie_genres, dependent: :destroy
  has_many :genres, through: :movie_genres
  has_many :likes, dependent: :destroy
  has_many :liked_by_users, through: :likes, source: :user
  has_many :reviews, dependent: :destroy
  has_many :reviewers, through: :reviews, source: :user

  has_neighbors :embedding_vec, dimensions: 384

  # Average star rating (1–5) from all reviews. Returns nil if no reviews.
  def average_rating
    reviews.average(:rating)&.round(1)
  end

  # Full poster URL for display. Returns nil if no poster_path. Some older TMDB paths may 404; use img onerror for placeholder.
  def poster_url
    return nil if poster_path.blank?
    return poster_path if poster_path.start_with?("http")
    path = poster_path.start_with?("/") ? poster_path : "/#{poster_path}"
    "#{TMDB_IMAGE_BASE}#{path}"
  end
end
