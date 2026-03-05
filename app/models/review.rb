class Review < ApplicationRecord
  belongs_to :user
  belongs_to :movie

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { scope: :movie_id, message: "can only rate each movie once" }
end
