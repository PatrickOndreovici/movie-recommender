# frozen_string_literal: true

namespace :export do
  desc "Export all ratings (reviews) to CSV for matrix factorization"
  task ratings: :environment do
    require "csv"

    out_path = ENV.fetch("OUT", "ratings.csv")

    reviews_count = Review.count
    raise "No reviews in DB." if reviews_count.zero?

    puts "Exporting #{reviews_count} ratings to #{out_path}..."

    CSV.open(out_path, "w", write_headers: true, headers: %w[user_id movie_id rating]) do |csv|
      Review.order(:user_id, :movie_id).find_each do |r|
        csv << [r.user_id, r.movie_id, r.rating]
      end
    end

    puts "Done."
  end
end
