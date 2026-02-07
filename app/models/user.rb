class User < ApplicationRecord
  has_many :likes, dependent: :destroy
  has_many :liked_movies, through: :likes, source: :movie

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable



  # Average of liked movies' embedding vectors (for recommendation). Returns nil if no likes or no embeddings.
  def average_liked_embedding
    vectors = liked_movies.where.not(embedding_vec: nil).pluck(:embedding_vec)
    return nil if vectors.empty?

    dim = vectors.first.size
    dim.times.map { |i| vectors.map { |v| v[i].to_f }.sum / vectors.size }
  end

  # Movies recommended by similarity to the user's liked movies (embedding-based). Excludes already liked.
  def recommended_movies
    avg = average_liked_embedding
    if avg.present?
      Movie.nearest_neighbors(:embedding_vec, avg, distance: "euclidean")
           .where.not(id: liked_movies.select(:id))
           .where.not(embedding_vec: nil)
    else
      Movie.where.not(id: liked_movies.select(:id)).order(:id)
    end
  end
end
