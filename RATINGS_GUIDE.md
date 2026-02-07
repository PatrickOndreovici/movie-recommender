# Adding Ratings to the Movie Recommender

## Important: Ratings vs Embeddings

**Key Principle:** Keep embeddings and ratings separate!

- **Embeddings** = Movie content (title, description, genre) → Represents what the movie IS
- **Ratings** = User opinions (1-5 stars) → Represents what users THINK about it

**Why keep them separate?**
- Embeddings should be objective content representation
- Ratings are subjective and user-specific
- Mixing them would pollute the semantic meaning
- You can use ratings to WEIGHT embeddings in recommendations

---

## Step 1: Create Rating Model

### 1.1 Generate Rating Model

```bash
rails generate model Rating user:references movie:references rating:integer
rails db:migrate
```

### 1.2 Add Validation to Migration

Edit the migration file to add constraints:

```ruby
class CreateRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :ratings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :movie, null: false, foreign_key: true
      t.integer :rating, null: false

      t.timestamps
    end
    
    # Prevent duplicate ratings (one rating per user per movie)
    add_index :ratings, [:user_id, :movie_id], unique: true
    
    # Ensure rating is between 1 and 5
    add_check_constraint :ratings, "rating >= 1 AND rating <= 5", name: "rating_range"
  end
end
```

**Note:** SQLite doesn't support check constraints, so add validation in the model instead.

---

## Step 2: Update Models

### 2.1 Update User Model

Edit `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  has_many :likes
  has_many :movies, through: :likes
  
  has_many :ratings
  has_many :rated_movies, through: :ratings, source: :movie
  
  has_secure_password
end
```

**Ruby concept:** `source:` tells Rails which association to use when the name differs

### 2.2 Update Movie Model

Edit `app/models/movie.rb`:

```ruby
class Movie < ApplicationRecord
  has_many :likes
  has_many :users, through: :likes
  
  has_many :ratings
  has_many :rated_by_users, through: :ratings, source: :user
  
  # Calculate average rating
  def average_rating
    ratings.average(:rating)&.round(2) || 0.0
  end
  
  # Helper methods for embeddings (keep these!)
  def embedding_array
    return [] if embedding.blank?
    JSON.parse(embedding)
  end
  
  def embedding_array=(array)
    self.embedding = array.to_json
  end
end
```

**Ruby concept:** 
- `&.round(2)` safely calls round only if average exists
- `average(:rating)` is an ActiveRecord method

### 2.3 Create Rating Model

Edit `app/models/rating.rb`:

```ruby
class Rating < ApplicationRecord
  belongs_to :user
  belongs_to :movie
  
  # Validation: one rating per user per movie
  validates :user_id, uniqueness: { scope: :movie_id }
  
  # Validation: rating must be between 1 and 5
  validates :rating, presence: true, 
                     numericality: { 
                       only_integer: true, 
                       greater_than_or_equal_to: 1, 
                       less_than_or_equal_to: 5 
                     }
end
```

**Ruby concept:** `validates` ensures data integrity before saving

---

## Step 3: Update Recommendation Service (Use Ratings to Weight Embeddings)

### 3.1 Weighted Average Approach

Edit `app/services/recommendation_service.rb`:

```ruby
class RecommendationService
  def self.recommend_for_user(user, limit: 10)
    # Get user's rated movies (with ratings)
    user_ratings = Rating.where(user_id: user.id).includes(:movie)
    return [] if user_ratings.empty?
    
    # Get embeddings weighted by rating
    weighted_embeddings = user_ratings.map do |rating|
      movie_embedding = rating.movie.embedding_array
      next if movie_embedding.empty?
      
      # Weight by rating (5-star = full weight, 1-star = 0.2 weight)
      weight = rating.rating / 5.0
      weighted_embedding = movie_embedding.map { |value| value * weight }
      
      { embedding: weighted_embedding, weight: weight }
    end.compact
    
    return [] if weighted_embeddings.empty?
    
    # Calculate weighted average
    total_weight = weighted_embeddings.sum { |item| item[:weight] }
    preference_vector = weighted_embeddings.first[:embedding].length.times.map do |i|
      sum = weighted_embeddings.sum { |item| item[:embedding][i] }
      sum / total_weight
    end
    
    # Find similar movies
    rated_movie_ids = user_ratings.pluck(:movie_id)
    candidate_movies = Movie.where.not(id: rated_movie_ids)
    
    scored_movies = candidate_movies.map do |movie|
      movie_embedding = movie.embedding_array
      next if movie_embedding.empty?
      
      similarity = cosine_similarity(preference_vector, movie_embedding)
      { movie: movie, score: similarity }
    end.compact
    
    # Sort and return top N
    scored_movies
      .sort_by { |item| -item[:score] }
      .first(limit)
      .map { |item| item[:movie] }
  end
  
  private
  
  def self.cosine_similarity(vec1, vec2)
    dot_product = vec1.zip(vec2).map { |a, b| a * b }.sum
    magnitude1 = Math.sqrt(vec1.map { |x| x**2 }.sum)
    magnitude2 = Math.sqrt(vec2.map { |x| x**2 }.sum)
    
    return 0.0 if magnitude1.zero? || magnitude2.zero?
    
    dot_product / (magnitude1 * magnitude2)
  end
end
```

**What this does:**
- Movies with 5-star ratings have full influence
- Movies with 1-star ratings have 20% influence
- Creates a preference vector that reflects both what user likes AND how much

### 3.2 Alternative: Only Use High Ratings

If you want to only consider movies rated 4+ stars:

```ruby
def self.recommend_for_user(user, limit: 10)
  # Only use movies rated 4 or 5 stars
  high_ratings = Rating.where(user_id: user.id)
                       .where("rating >= ?", 4)
                       .includes(:movie)
  
  return [] if high_ratings.empty?
  
  # Rest of the code same as before...
  liked_embeddings = high_ratings.map { |rating| rating.movie.embedding_array }
  # ...
end
```

---

## Step 4: Create Ratings Controller

```bash
rails generate controller Ratings create update destroy
```

Edit `app/controllers/ratings_controller.rb`:

```ruby
class RatingsController < ApplicationController
  def create
    @rating = Rating.find_or_initialize_by(
      user_id: params[:user_id],
      movie_id: params[:movie_id]
    )
    @rating.rating = params[:rating]
    
    if @rating.save
      render json: @rating, status: :created
    else
      render json: { errors: @rating.errors }, status: :unprocessable_entity
    end
  end
  
  def update
    @rating = Rating.find_by(
      user_id: params[:user_id],
      movie_id: params[:movie_id]
    )
    
    if @rating&.update(rating: params[:rating])
      render json: @rating
    else
      render json: { errors: @rating&.errors || "Rating not found" }, 
             status: :unprocessable_entity
    end
  end
  
  def destroy
    @rating = Rating.find_by(
      user_id: params[:user_id],
      movie_id: params[:movie_id]
    )
    @rating&.destroy
    head :no_content
  end
end
```

**Ruby concept:** `find_or_initialize_by` finds existing or creates new record

---

## Step 5: Update Routes

Edit `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  resources :movies, only: [:index, :show, :create]
  resources :likes, only: [:create, :destroy]
  resources :ratings, only: [:create, :update, :destroy]
  resources :recommendations, only: [:index]
end
```

---

## How Ratings Improve Recommendations

### Without Ratings (Just Likes):
- All liked movies have equal weight
- Can't distinguish between "loved it" vs "it was okay"

### With Ratings:
- 5-star movies have more influence on recommendations
- 1-2 star movies have less influence (or can be ignored)
- System learns user's preferences more accurately

### Example:

**User rates:**
- "The Matrix" = 5 stars (loves it)
- "Inception" = 5 stars (loves it)
- "Blade Runner" = 3 stars (it was okay)

**Result:**
- Preference vector is heavily influenced by Matrix and Inception
- Blade Runner has less influence
- Recommendations will be more similar to Matrix/Inception style

---

## Hybrid Approach: Ratings + Likes

You can use both! Some users might like movies without rating them:

```ruby
def self.recommend_for_user(user, limit: 10)
  # Get rated movies (weighted by rating)
  rated_movies = Rating.where(user_id: user.id).includes(:movie)
  
  # Get liked movies (no rating, treat as 3.5 stars)
  liked_movies = Like.where(user_id: user.id)
                     .where.not(movie_id: rated_movies.pluck(:movie_id))
                     .includes(:movie)
  
  # Combine both
  all_preferences = []
  
  rated_movies.each do |rating|
    weight = rating.rating / 5.0
    all_preferences << {
      embedding: rating.movie.embedding_array,
      weight: weight
    }
  end
  
  liked_movies.each do |like|
    # Treat likes as 3.5/5.0 = 0.7 weight
    all_preferences << {
      embedding: like.movie.embedding_array,
      weight: 0.7
    }
  end
  
  # Continue with weighted average...
end
```

---

## Summary

✅ **DO:**
- Keep embeddings pure (only movie content)
- Use ratings to weight embeddings in recommendations
- Store ratings in a separate table
- Validate ratings (1-5 range)

❌ **DON'T:**
- Include ratings in embedding text
- Mix ratings with movie content in embeddings
- Use ratings to generate embeddings

**Best Practice:** 
- Embeddings = What the movie IS (objective)
- Ratings = What users THINK (subjective)
- Use ratings to weight how much influence each movie has on recommendations
