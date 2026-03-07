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

  def recommended
    @movies = current_user.recommended_movies.includes(:genres).paginate(page: params[:page], per_page: 20)
    @liked_movie_ids = current_user.likes.where(movie_id: @movies.pluck(:id)).pluck(:movie_id)
    render :index
  end

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


  # POST /movies/complete-upload
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

  def initiate_upload_params
    params.permit(:movie_title, :movie_description, :movie_genre, :movie_release_year, :file_size, :upload_id, :parts)
  end
end
