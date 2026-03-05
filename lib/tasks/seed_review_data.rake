# frozen_string_literal: true

namespace :seed do
  desc "Generate 400 users and have them rate a random subset of movies (for matrix factorization / collaborative filtering testing)"
  task review_data: :environment do
    NUM_USERS = 400
    REVIEWS_PER_USER_MIN = 8
    REVIEWS_PER_USER_MAX = 50
    DEFAULT_PASSWORD = "seed_password_123"

    movie_ids = Movie.pluck(:id)
    raise "No movies in DB. Run movies:index or seed movies first." if movie_ids.empty?

    puts "Creating #{NUM_USERS} users..."
    created = 0
    NUM_USERS.times do |i|
      email = "mf_seed_#{i + 1}@example.com"
      next if User.exists?(email: email)

      User.create!(
        email: email,
        password: DEFAULT_PASSWORD,
        password_confirmation: DEFAULT_PASSWORD,
        name: "Seed User #{i + 1}"
      )
      created += 1
      print "." if (created % 50).zero?
    end
    puts " Done. Created #{created} users."

    users = User.where("email LIKE ?", "mf_seed_%@example.com")
    puts "Assigning random ratings for #{users.count} users..."

    total_reviews = 0
    users.find_each do |user|
      n_reviews = rand(REVIEWS_PER_USER_MIN..REVIEWS_PER_USER_MAX)
      sample_ids = movie_ids.sample(n_reviews)
      sample_ids.each do |movie_id|
        next if user.reviews.exists?(movie_id: movie_id)

        user.reviews.create!(movie_id: movie_id, rating: rand(1..5))
        total_reviews += 1
      end
    end

    puts "Created #{total_reviews} reviews."
    puts "Done."
  end
end
