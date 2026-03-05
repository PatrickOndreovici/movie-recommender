require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  test "rating must be between 1 and 5" do
    review = Review.new(user: users(:one), movie: movies(:one), rating: 3)
    assert review.valid?

    review.rating = 0
    assert_not review.valid?

    review.rating = 6
    assert_not review.valid?

    review.rating = 1
    assert review.valid?

    review.rating = 5
    assert review.valid?
  end

  test "user can only have one review per movie" do
    user = users(:one)
    movie = movies(:one)
    Review.create!(user: user, movie: movie, rating: 3)
    duplicate = Review.new(user: user, movie: movie, rating: 5)
    assert_not duplicate.valid?
  end
end
