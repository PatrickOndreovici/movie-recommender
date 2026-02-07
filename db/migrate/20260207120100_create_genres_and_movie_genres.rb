class CreateGenresAndMovieGenres < ActiveRecord::Migration[8.1]
  def change
    create_table :genres do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :genres, :name, unique: true

    create_table :movie_genres do |t|
      t.references :movie, null: false, foreign_key: true
      t.references :genre, null: false, foreign_key: true

      t.timestamps
    end

    add_index :movie_genres, [:movie_id, :genre_id], unique: true

    remove_column :movies, :genre
  end
end
