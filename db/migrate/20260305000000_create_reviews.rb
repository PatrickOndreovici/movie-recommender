class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :movie, null: false, foreign_key: true
      t.integer :rating, null: false

      t.timestamps
    end

    add_index :reviews, [:user_id, :movie_id], unique: true
  end
end
