class AddPosterPathToMovies < ActiveRecord::Migration[8.1]
  def change
    add_column :movies, :poster_path, :string
  end
end
