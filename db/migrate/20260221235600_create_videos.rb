class CreateVideos < ActiveRecord::Migration[8.1]
  def change

    create_table :videos, id: :uuid do |t|
      t.references :movie, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'uploading'
      t.string :original_key
      t.string :hls_prefix
      t.integer :duration

      t.timestamps
    end
  end
end
