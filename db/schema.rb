# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_21_235600) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "genres", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_genres_on_name", unique: true
  end

  create_table "likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "movie_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["movie_id"], name: "index_likes_on_movie_id"
    t.index ["user_id", "movie_id"], name: "index_likes_on_user_id_and_movie_id", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "movie_genres", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "genre_id", null: false
    t.bigint "movie_id", null: false
    t.datetime "updated_at", null: false
    t.index ["genre_id"], name: "index_movie_genres_on_genre_id"
    t.index ["movie_id", "genre_id"], name: "index_movie_genres_on_movie_id_and_genre_id", unique: true
    t.index ["movie_id"], name: "index_movie_genres_on_movie_id"
  end

  create_table "movies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "embedding"
    t.vector "embedding_vec", limit: 384
    t.string "poster_path"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "year"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "password_digest"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "videos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration"
    t.string "hls_prefix"
    t.bigint "movie_id", null: false
    t.string "original_key"
    t.string "status", default: "uploading", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["movie_id"], name: "index_videos_on_movie_id"
    t.index ["user_id"], name: "index_videos_on_user_id"
  end

  add_foreign_key "likes", "movies"
  add_foreign_key "likes", "users"
  add_foreign_key "movie_genres", "genres"
  add_foreign_key "movie_genres", "movies"
  add_foreign_key "videos", "movies"
  add_foreign_key "videos", "users"
end
