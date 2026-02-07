# How the Recommendation System Works

## Overview

The system uses **embedding similarity** to find movies similar to the ones a user has liked. Here's the step-by-step process:

## Step-by-Step Process

### 1. Initial Setup (One-time per movie)

When a movie is added to the database:
- Combine movie information into a text string:
  ```
  "The Matrix. A computer hacker learns about the true nature of reality. Genre: Science Fiction, Action. Year: 1999"
  ```
- Generate an embedding vector (384 numbers) using `EmbeddingService.embed(text)`
- Store the embedding in the `movies.embedding` column as JSON

**Result**: Every movie has a 384-dimensional vector representing its content

### 2. User Likes Movies

When a user likes a movie:
- Create a record in the `likes` table: `user_id` + `movie_id`
- No embedding calculation needed (already stored with the movie)

### 3. Generating Recommendations

When a user requests recommendations:

#### Step 3.1: Get User's Liked Movies
```ruby
liked_movie_ids = Like.where(user_id: user.id).pluck(:movie_id)
liked_movies = Movie.where(id: liked_movie_ids)
```

#### Step 3.2: Get Embeddings of Liked Movies
```ruby
liked_embeddings = liked_movies.map { |movie| JSON.parse(movie.embedding) }
# Result: Array of arrays, e.g. [[0.1, -0.2, ...], [0.3, 0.1, ...], ...]
```

#### Step 3.3: Calculate User's Preference Vector

**Option A: Average Embedding (Simple)**
- Average all the liked movie embeddings to get one "preference vector"
```ruby
# Average each dimension across all liked movies
preference_vector = liked_embeddings.transpose.map { |dimension_values| 
  dimension_values.sum.to_f / dimension_values.length 
}
```

**Option B: Weighted Average (Better)**
- Give more weight to recently liked movies
- Or weight by user's rating if you have ratings

**Option C: Find Most Similar to Each Liked Movie (More Complex)**
- For each liked movie, find similar movies
- Combine and rank results

**Recommendation: Start with Option A (simple average)**

#### Step 3.4: Find Similar Movies

For each movie in the database (excluding already liked ones):
1. Get the movie's embedding vector
2. Calculate **cosine similarity** between the movie's embedding and the user's preference vector
3. Store the similarity score

```ruby
def cosine_similarity(vec1, vec2)
  dot_product = vec1.zip(vec2).map { |a, b| a * b }.sum
  magnitude1 = Math.sqrt(vec1.map { |x| x**2 }.sum)
  magnitude2 = Math.sqrt(vec2.map { |x| x**2 }.sum)
  dot_product / (magnitude1 * magnitude2)
end
```

**Cosine similarity returns:**
- `1.0` = Identical (same direction)
- `0.0` = Orthogonal (no similarity)
- `-1.0` = Opposite (completely different)

#### Step 3.5: Rank and Return Top Recommendations

- Sort movies by similarity score (highest first)
- Take top N (e.g., top 10 or 20)
- Return these movies as recommendations

## Complete Algorithm Example

```ruby
class RecommendationService
  def self.recommend_for_user(user, limit: 10)
    # Step 1: Get user's liked movies
    liked_movie_ids = Like.where(user_id: user.id).pluck(:movie_id)
    return [] if liked_movie_ids.empty?
    
    liked_movies = Movie.where(id: liked_movie_ids)
    
    # Step 2: Get embeddings
    liked_embeddings = liked_movies.map do |movie|
      JSON.parse(movie.embedding)
    end
    
    # Step 3: Calculate user preference vector (average)
    preference_vector = liked_embeddings.transpose.map do |dimension_values|
      dimension_values.sum.to_f / dimension_values.length
    end
    
    # Step 4: Find similar movies
    candidate_movies = Movie.where.not(id: liked_movie_ids)
    
    scored_movies = candidate_movies.map do |movie|
      movie_embedding = JSON.parse(movie.embedding)
      similarity = cosine_similarity(preference_vector, movie_embedding)
      { movie: movie, score: similarity }
    end
    
    # Step 5: Sort by similarity and return top N
    scored_movies
      .sort_by { |item| -item[:score] }  # Negative for descending
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

## Why This Works

1. **Embeddings capture semantic meaning**: Movies with similar plots/genres will have similar embedding vectors
2. **Cosine similarity measures direction**: Two vectors pointing in the same direction (similar content) have high similarity
3. **Averaging finds common themes**: If a user likes multiple sci-fi movies, the average embedding will point toward "sci-fi space" in the vector space
4. **Similar movies cluster together**: Movies with similar embeddings are close in the 384-dimensional space

## Example Scenario

**User likes:**
- "The Matrix" (sci-fi, action)
- "Inception" (sci-fi, thriller)
- "Blade Runner" (sci-fi, noir)

**What happens:**
1. System averages the 3 embeddings → preference vector points toward "sci-fi, complex plots, action"
2. System finds movies with similar embeddings:
   - "The Matrix Reloaded" (high similarity - same series)
   - "Interstellar" (high similarity - sci-fi, complex)
   - "The Terminator" (medium similarity - sci-fi, action)
   - "Titanic" (low similarity - different genre)
3. Returns top matches as recommendations

## Performance Considerations

**For 1000 movies:**
- Calculate similarity: 1000 cosine similarity calculations
- Each calculation: ~384 multiplications + additions
- Total: ~384,000 operations (very fast, < 1 second)

**Optimizations for larger datasets:**
- Cache similarity calculations
- Use approximate nearest neighbor search (ANN)
- Pre-compute similarity matrix (if movies don't change often)
- Use vector databases (e.g., pgvector, Pinecone) for faster search

## Edge Cases

1. **New user (no likes)**: Return popular movies or random movies
2. **User with very few likes**: Recommendations may be less accurate
3. **User with diverse likes**: Average embedding might be less meaningful (consider clustering)
4. **Movies without embeddings**: Skip them or generate on-the-fly

## Alternative Approaches

### Approach 1: Item-to-Item Similarity
- Pre-compute similarity between all movie pairs
- When user likes a movie, recommend its most similar movies
- Simpler but less personalized

### Approach 2: Collaborative Filtering
- Find users with similar tastes
- Recommend movies they liked
- Doesn't use embeddings, uses user behavior

### Approach 3: Hybrid
- Combine embedding similarity + collaborative filtering
- Best results but more complex

**For your use case, embedding-based similarity is ideal** because:
- Works well with limited user data
- Captures content similarity
- Easy to implement
- Good performance
