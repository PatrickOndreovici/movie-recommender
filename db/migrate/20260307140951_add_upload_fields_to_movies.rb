class AddUploadFieldsToMovies < ActiveRecord::Migration[8.1]
  def change
    add_column :movies, :upload_status, :string, default: 'pending', null: false
    add_column :movies, :upload_id, :string   
  end
end
