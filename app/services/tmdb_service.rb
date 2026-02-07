# Fetches movie details from TMDB API. Requires TMDB_API_KEY in ENV.
# Get your key: https://www.themoviedb.org/settings/api
require "net/http"
require "openssl"
require "json"
require "uri"

class TmdbService
  BASE_URL = "https://api.themoviedb.org/3"
  IMAGE_BASE = "https://image.tmdb.org/t/p/w500"

  class Error < StandardError; end

  def self.poster_url_for_movie_id(tmdb_movie_id)
    path = fetch_poster_path(tmdb_movie_id)
    return nil if path.blank?
    path = path.start_with?("/") ? path : "/#{path}"
    "#{IMAGE_BASE}#{path}"
  end

  # Returns the poster_path from TMDB (e.g. "/abc123.jpg") or nil
  def self.fetch_poster_path(tmdb_movie_id)
    data = get_json("#{BASE_URL}/movie/#{tmdb_movie_id}", api_key: ENV["TMDB_API_KEY"])
    data["poster_path"]
  end

  # Full movie details from TMDB (title, overview, poster_path, release_date, etc.)
  def self.movie_details(tmdb_movie_id)
    get_json("#{BASE_URL}/movie/#{tmdb_movie_id}", api_key: ENV["TMDB_API_KEY"])
  end

  def self.get_json(url, params = {})
    raise Error, "Set TMDB_API_KEY in your environment" if params[:api_key].blank?

    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params.any?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # avoids CRL cert error on some systems
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    raise Error, "TMDB API error: #{response.code} - #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
