# Step-by-Step Guide to Build the Movie Recommender

This guide will help you build the system step by step while learning Ruby and Rails.

## Prerequisites

- Rails app is set up (you have this)
- Ollama is running locally with `all-minilm:l6-v2` model
- Basic understanding of what you want to build

---

## Step 1: Create the Database Models

### 1.1 Create User Model

**What you'll learn:** Rails generators, ActiveRecord models, migrations

```bash
rails generate model User email:string password_digest:string name:string
rails db:migrate
```

**What this does:**
- Creates `app/models/user.rb` (the User class)
- Creates a migration file in `db/migrate/`
- `password_digest` is for password hashing (we'll add authentication later)

**Ruby concept:** Models are Ruby classes that represent database tables

### 1.2 Create Movie Model

```bash
rails generate model Movie title:string description:text genre:string year:integer rating:decimal embedding:text
rails db:migrate
```

**What this does:**
- Creates the Movie model with all necessary fields
- `embedding` will store the JSON array as text
- `rating` stores the movie's rating (e.g., 4.5 out of 5)

**Ruby concept:** `text` type is for longer strings, `string` is for shorter ones. `decimal` is for precise decimal numbers (good for ratings like 4.5)

### 1.3 Create Like Model (Junction Table)

```bash
rails generate model Like user:references movie:references
rails db:migrate
```

**What this does:**
- Creates a join table linking users and movies
- `references` creates foreign keys automatically

**Ruby concept:** `references` is a shortcut that creates `user_id` and `movie_id` columns

### 1.4 Add Indexes for Performance

Edit the migration file (or create a new one):

```bash
rails generate migration AddIndexesToLikes
```

Then edit `db/migrate/XXXXXX_add_indexes_to_likes.rb`:

```ruby
class AddIndexesToLikes < ActiveRecord::Migration[8.1]
  def change
    add_index :likes, :user_id
    add_index :likes, :movie_id
    add_index :likes, [:user_id, :movie_id], unique: true
  end
end
```

Run: `rails db:migrate`

**What you'll learn:** Database indexes speed up queries

---

## Step 2: Set Up Model Associations

### 2.1 Edit User Model

Open `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  has_many :likes
  has_many :movies, through: :likes
  
  # For password hashing (add this gem to Gemfile: gem 'bcrypt')
  has_secure_password
end
```

**Ruby concept:** 
- `has_many` creates a one-to-many relationship
- `through:` creates a many-to-many relationship
- `has_secure_password` adds password encryption

### 2.2 Edit Movie Model

Open `app/models/movie.rb`:

```ruby
class Movie < ApplicationRecord
  has_many :likes
  has_many :users, through: :likes
  
  # Validate rating is between 0 and 5
  validates :rating, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 5 
  }, allow_nil: true
  
  # Helper method to get embedding as array
  def embedding_array
    return [] if embedding.blank?
    JSON.parse(embedding)
  end
  
  # Helper method to set embedding from array
  def embedding_array=(array)
    self.embedding = array.to_json
  end
end
```

**Ruby concept:**
- `validates` ensures data integrity
- `allow_nil: true` allows rating to be blank (optional field)
- `numericality` validates that rating is a number within range

**Ruby concept:**
- Custom methods in models are called "instance methods"
- `self.` refers to the current object (the movie)
- `JSON.parse` converts JSON string to Ruby array

### 2.3 Edit Like Model

Open `app/models/like.rb`:

```ruby
class Like < ApplicationRecord
  belongs_to :user
  belongs_to :movie
  
  # Prevent duplicate likes
  validates :user_id, uniqueness: { scope: :movie_id }
end
```

**Ruby concept:**
- `belongs_to` creates the "many" side of a relationship
- `validates` ensures data integrity


---

## Step 3: Create a Service to Generate Movie Embeddings

### 3.1 Create MovieEmbeddingService

Create `app/services/movie_embedding_service.rb`:

```ruby
class MovieEmbeddingService
  def self.generate_for(movie)
    # Combine movie info into text for embedding
    text = "#{movie.title}. #{movie.description}. Genre: #{movie.genre}. Year: #{movie.year}"
    
    # Generate embedding
    embedding = EmbeddingService.embed(text)
    
    # Save to movie
    movie.update(embedding: embedding.to_json)
    
    embedding
  end
end
```

**Ruby concept:**
- Class methods (using `self.`) can be called without creating an instance
- `update` saves changes to the database

**What you'll learn:** Service objects organize business logic

---

## Step 4: Create the Recommendation Service

### 4.1 Create RecommendationService

Create `app/services/recommendation_service.rb`:

```ruby
class RecommendationService
  def self.recommend_for_user(user, limit: 10)
    # Step 1: Get user's liked movies
    liked_movie_ids = user.liked_movie_ids
    return [] if liked_movie_ids.empty?
    
    # Step 2: Get embeddings of liked movies
    liked_embeddings = user.movies.map(&:embedding_array)
    
    # Step 3: Calculate average embedding (preference vector)
    preference_vector = average_embeddings(liked_embeddings)
    
    # Step 4: Find similar movies
    candidate_movies = Movie.where.not(id: liked_movie_ids)
    
    scored_movies = candidate_movies.map do |movie|
      movie_embedding = movie.embedding_array
      next if movie_embedding.empty?
      
      similarity = cosine_similarity(preference_vector, movie_embedding)
      { movie: movie, score: similarity }
    end.compact
    
    # Step 5: Sort and return top N
    scored_movies
      .sort_by { |item| -item[:score] }
      .first(limit)
      .map { |item| item[:movie] }
  end
  
  private
  
  def self.average_embeddings(embeddings)
    return [] if embeddings.empty?
    
    embeddings.transpose.map do |dimension_values|
      dimension_values.sum.to_f / dimension_values.length
    end
  end
  
  def self.cosine_similarity(vec1, vec2)
  
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

**Ruby concepts you'll learn:**
- `&:method_name` is shorthand for `{ |item| item.method_name }`
- `.map` transforms each element in an array
- `.compact` removes nil values
- `.sort_by` sorts by a value
- `.transpose` flips rows and columns in a 2D array
- `.zip` combines two arrays element by element
- `private` methods can only be called from within the class

---

## Step 5: Create Controllers (API Endpoints)

### 5.1 Create Movies Controller

```bash
rails generate controller Movies index show create
```

Edit `app/controllers/movies_controller.rb`:

```ruby
class MoviesController < ApplicationController
  def index
    @movies = Movie.all
    render json: @movies
  end
  
  def show
    @movie = Movie.find(params[:id])
    render json: @movie
  end
  
  def create
    @movie = Movie.new(movie_params)
    
    if @movie.save
      # Generate embedding after saving
      MovieEmbeddingService.generate_for(@movie)
      render json: @movie, status: :created
    else
      render json: { errors: @movie.errors }, status: :unprocessable_entity
    end
  end
  
  private
  
  def movie_params
    params.require(:movie).permit(:title, :description, :genre, :year, :rating)
  end
end
```

**Ruby concepts:**
- `params` contains data from the HTTP request
- `require` and `permit` are security features (strong parameters)
- `status:` sets the HTTP status code

### 5.2 Create Likes Controller

```bash
rails generate controller Likes create destroy
```

Edit `app/controllers/likes_controller.rb`:

```ruby
class LikesController < ApplicationController
  def create
    @like = Like.new(user_id: params[:user_id], movie_id: params[:movie_id])
    
    if @like.save
      render json: @like, status: :created
    else
      render json: { errors: @like.errors }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @like = Like.find_by(user_id: params[:user_id], movie_id: params[:movie_id])
    @like&.destroy
    head :no_content
  end
end
```

**Ruby concept:** `&.` is the "safe navigation operator" - only calls the method if the object exists

### 5.3 Create Recommendations Controller

```bash
rails generate controller Recommendations index
```

Edit `app/controllers/recommendations_controller.rb`:

```ruby
class RecommendationsController < ApplicationController
  def index
    user = User.find(params[:user_id])
    @recommendations = RecommendationService.recommend_for_user(user, limit: 10)
    render json: @recommendations
  end
end
```

---

## Step 6: Set Up Routes

Edit `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  resources :movies, only: [:index, :show, :create]
  resources :likes, only: [:create, :destroy]
  resources :recommendations, only: [:index]
  
  # Or use nested routes:
  # resources :users do
  #   resources :likes, only: [:create, :destroy]
  #   resources :recommendations, only: [:index]
  # end
end
```

**Ruby concept:** `resources` creates RESTful routes automatically

---

## Step 7: Test Your System

### 7.1 Create a Rake Task to Seed Movies

Create `lib/tasks/movies.rake`:

```ruby
namespace :movies do
  desc "Seed sample movies"
  task seed: :environment do
    movies = [
      {
        title: "The Matrix",
        description: "A computer hacker learns about the true nature of reality",
        genre: "Science Fiction, Action",
        year: 1999,
        rating: 4.7
      },
      {
        title: "Inception",
        description: "A thief who steals corporate secrets through dream-sharing technology",
        genre: "Science Fiction, Thriller",
        year: 2010,
        rating: 4.8
      },
      # Add more movies...
    ]
    
    movies.each do |movie_data|
      movie = Movie.create!(movie_data)
      MovieEmbeddingService.generate_for(movie)
      puts "Created: #{movie.title}"
    end
  end
end
```

Run: `rake movies:seed`

### 7.2 Test Recommendations

Create `lib/tasks/test_recommendations.rake`:

```ruby
namespace :recommendations do
  desc "Test recommendation system"
  task test: :environment do
    user = User.first || User.create!(email: "test@example.com", password: "password", name: "Test User")
    
    # Like some movies
    liked_movies = Movie.limit(3)
    liked_movies.each do |movie|
      Like.create!(user: user, movie: movie)
      puts "User liked: #{movie.title} (Rating: #{movie.rating})"
    end
    
    # Get recommendations
    recommendations = RecommendationService.recommend_for_user(user, limit: 5)
    
    puts "\nRecommendations:"
    recommendations.each do |movie|
      puts "- #{movie.title}"
    end
  end
end
```

Run: `rake recommendations:test`

---

## Step 8: Add Authentication (Optional but Recommended)

### 8.1 Add bcrypt gem

Add to `Gemfile`:
```ruby
gem 'bcrypt', '~> 3.1.7'
```

Run: `bundle install`

### 8.2 Create Sessions Controller

```bash
rails generate controller Sessions create destroy
```

Edit `app/controllers/sessions_controller.rb`:

```ruby
class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])
    
    if user&.authenticate(params[:password])
      render json: { user: user, message: "Logged in" }
    else
      render json: { error: "Invalid credentials" }, status: :unauthorized
    end
  end
  
  def destroy
    head :no_content
  end
end
```

**Ruby concept:** `&.authenticate` safely calls authenticate if user exists

---

## Learning Path Summary

**Week 1: Models & Database**
- Step 1: Create models
- Step 2: Set up associations
- Learn: ActiveRecord, migrations, relationships

**Week 2: Services & Logic**
- Step 3: Embedding service
- Step 4: Recommendation service
- Learn: Service objects, algorithms, Ruby array methods

**Week 3: API & Controllers**
- Step 5: Create controllers
- Step 6: Set up routes
- Learn: REST APIs, HTTP, Rails controllers

**Week 4: Testing & Polish**
- Step 7: Test everything
- Step 8: Add authentication
- Learn: Testing, security, authentication

---

## Key Ruby Concepts to Learn

1. **Classes & Objects**: Everything in Ruby is an object
2. **Methods**: Functions that belong to objects
3. **Arrays & Hashes**: Data structures
4. **Blocks**: `{ }` or `do...end` - chunks of code
5. **Symbols**: `:name` - lightweight strings
6. **ActiveRecord**: Database ORM (Object-Relational Mapping)

---

## Tips for Learning

1. **Read error messages carefully** - They tell you exactly what's wrong
2. **Use `rails console`** - Test code interactively: `rails c`
3. **Read the Rails guides** - https://guides.rubyonrails.org
4. **Experiment** - Try changing code and see what happens
5. **Use `puts` or `p`** - Print values to debug: `puts variable.inspect`

---

## Next Steps After Basics

1. Add user authentication with JWT tokens
2. Add movie ratings (not just likes)
3. Add pagination for movie lists
4. Add caching for recommendations
5. Add movie search functionality
6. Create a frontend (React, Vue, or plain HTML)

Good luck! Start with Step 1 and work through them one by one.
