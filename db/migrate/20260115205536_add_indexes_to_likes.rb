class AddIndexesToLikes < ActiveRecord::Migration[8.1]
  def change
    add_index :likes, [:user_id, :movie_id], unique: true
  end
end
