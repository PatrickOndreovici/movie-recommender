class VideosController < ApplicationController
  before_action :authenticate_user!

  def new
    # Render the upload page
  end

  def create
    # Just a placeholder to accept the upload form submission.
    # The prompt explicitly asked to "don't do anything else" other than the upload page.
    flash[:notice] = "Upload submitted!"
    redirect_to new_video_path
  end
end
