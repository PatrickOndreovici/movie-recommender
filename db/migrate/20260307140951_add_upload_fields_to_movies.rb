class AddUploadFieldsToMovies < ActiveRecord::Migration[8.1]
  ##
  # Adds upload_status and upload_id columns to the movies table.
  # upload_status is a string column with default 'pending' and NOT NULL constraint.
  # upload_id is a nullable string column.
  def change
    add_column :movies, :upload_status, :string, default: 'pending', null: false
    add_column :movies, :upload_id, :string   
  end
end
