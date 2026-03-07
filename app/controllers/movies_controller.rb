class MoviesController < ApplicationController
  def show
    @movie = Movie.includes(:genres).find(params[:id])
  end

  def index
    @movies = Movie.includes(:genres).order(:id).paginate(page: params[:page], per_page: 20)
    @liked_movie_ids = current_user.likes.where(movie_id: @movies.pluck(:id)).pluck(:movie_id)
  end

  def liked
    @movies = current_user.liked_movies.includes(:genres).order("likes.created_at DESC").paginate(page: params[:page], per_page: 20)
    @liked_movie_ids = current_user.likes.where(movie_id: @movies.pluck(:id)).pluck(:movie_id)
    render :index
  end

  ##
  # Loads recommended movies for the current user, including genres, paginates them, sets liked IDs, and renders the index view.
  #
  # Populates @movies with the current user's recommended Movie records (includes associated genres), paginated 20 per page using params[:page]. Populates @liked_movie_ids with the IDs of those movies that the current user has liked. Renders the :index template.
  def recommended
    @movies = current_user.recommended_movies.includes(:genres).paginate(page: params[:page], per_page: 20)
    @liked_movie_ids = current_user.likes.where(movie_id: @movies.pluck(:id)).pluck(:movie_id)
    render :index
  end

  ##
  # Starts a multipart upload for a new Movie and returns presigned URLs for each upload part.
  # 
  # Creates a Movie record with upload_status set to "uploading" (associating the provided genre if present), initiates an S3 multipart upload, stores the resulting upload_id on the Movie, calculates the number of 5 MB parts from `file_size`, generates presigned upload URLs for each part, and renders JSON containing `upload_id` and `presigned_urls`.
  # @param [String] movie_title - The title of the movie.
  # @param [String, nil] movie_description - The movie description.
  # @param [String, nil] movie_genre - The genre name to associate with the movie.
  # @param [Integer, String, nil] movie_release_year - The release year (will be converted to integer if present).
  # @param [Integer, String] file_size - The size of the file in bytes; used to compute number of 5 MB parts.
  def initiate_upload
    movie_title        = params[:movie_title]
    movie_description  = params[:movie_description]
    movie_genre        = params[:movie_genre]
    movie_release_year = params[:movie_release_year]
    file_size          = params[:file_size]

    s3_client = Aws::S3::Client.new(region: 'us-east-1')

    movie = ActiveRecord::Base.transaction do
      record = Movie.unscoped.create!(
        title: movie_title,
        description: movie_description,
        year: movie_release_year&.to_i,
        upload_status: "uploading"
      )
      if movie_genre.present?
        genre = Genre.find_or_create_by!(name: movie_genre.to_s.strip)
        record.genres << genre unless record.genres.include?(genre)
      end
      record
    end

    resp = s3_client.create_multipart_upload(bucket: 'movies', key: "movies/#{movie_title}")
    upload_id = resp.upload_id
    movie.update!(upload_id: upload_id)

    part_count = (file_size.to_f / (5 * 1024 * 1024)).ceil
    presigned_urls = part_count.times.map do |i|
      part_number = i + 1
      url = Aws::S3::Presigner.new(client: s3_client).presigned_url(
        :upload_part,
        bucket: 'movies',
        key: "movies/#{movie_title}",
        upload_id: upload_id,
        part_number: part_number,
        expires_in: 3600
      )
      { part_number: part_number, url: url }
    end

    render json: { upload_id: upload_id, presigned_urls: presigned_urls }
  end


  ##
  # Completes a multipart upload for a movie on S3 and marks the corresponding Movie as processing.
  #
  # Accepts an upload identifier and per-part ETags, completes the S3 multipart upload for the given movie key,
  # updates the Movie record's upload_status to "processing", and renders a JSON confirmation message.
  # @param [String] movie_title - The title of the movie used to build the S3 object key (key: "movies/{movie_title}").
  # @param [String] upload_id - The S3 multipart upload ID previously returned by initiate_upload.
  # @param [Array<Hash>] parts - An array of hashes describing uploaded parts; each element must include:
  #   - `partNumber` (Integer or string convertible to integer) and `etag` (String).
  #   The method normalizes these to `{ part_number: Integer, etag: String }` before completing the upload.
  def complete_upload
    movie_title = params[:movie_title]
    upload_id   = params[:upload_id]
    parts       = Array(params[:parts]).map do |p|
      permitted = p.permit(:partNumber, :etag).to_h
      { part_number: permitted['partNumber'].to_i, etag: permitted['etag'] }
    end

    s3_client = Aws::S3::Client.new(region: 'us-east-1')

    s3_client.complete_multipart_upload(
      bucket: 'movies',
      key: "movies/#{movie_title}",
      upload_id: upload_id,
      multipart_upload: { parts: parts }
    )

    movie = Movie.unscoped.find_by!(upload_id: upload_id)
    movie.update!(upload_status: "processing")

    render json: { message: "Upload completed successfully! Video is being processed." }
  end

  private

  ##
  # Strong parameters whitelist for movie upload endpoints.
  # Permits `movie_title`, `movie_description`, `movie_genre`, `movie_release_year`, `file_size`, `upload_id`, and `parts` from the request parameters.
  # @return [ActionController::Parameters] The filtered parameters with the listed keys permitted.
  def initiate_upload_params
    params.permit(:movie_title, :movie_description, :movie_genre, :movie_release_year, :file_size, :upload_id, :parts)
  end
end
