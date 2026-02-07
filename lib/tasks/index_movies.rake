require 'csv'
require_relative '../../app/services/embedding_service'
require_relative '../../app/services/tmdb_service'

namespace :movies do
  desc 'Index movies from CSV and generate embeddings'
  task index: :environment do




    start = Time.now
    csv_text = File.read('./movies_metadata.csv')
    csv = CSV.parse(csv_text, :headers => true)
    cnt = 0
    csv.each do |row|
      title = row["title"].to_s.strip
      next if title.blank?

      id = row["id"].to_i

      poster_path = TmdbService.fetch_poster_path(id)


      description = row["overview"].to_s.strip.presence
      release_date = row["release_date"].to_s.strip.presence
      year = release_date.present? ? release_date[0, 4].to_i : nil

      genres_raw = row["genres"].to_s.strip
      genres_data = genres_raw.present? ? JSON.parse(genres_raw.gsub("'", '"')) : []

      movie = Movie.create!(title: title, poster_path: poster_path, description: description, year: year)
      genres_data.each do |g|
        genre = Genre.find_or_create_by!(name: g["name"])
        movie.genres << genre unless movie.genres.include?(genre)
      end

      genre_names = genres_data.map { |g| g["name"] }.join(", ")

      movie_text = [title, description, genre_names].compact.join(" ")

      embedding = EmbeddingService.embed(movie_text)
      movie.update!(embedding: embedding.to_json)

    end

    end_ = Time.now
    puts "Time taken: #{end_ - start} seconds"
  end
end