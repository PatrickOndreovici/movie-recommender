# Data Model for Movie Recommendation System

## Overview

For an embedding-based recommendation system, you need to store:
1. Movie metadata (title, description, etc.)
2. Embedding vectors for each movie
3. User information
4. User likes/preferences

## Database Schema

### 1. Movies Table

**Essential fields:**
- `id` (primary key)
- `title` (string) - Movie title
- `description` (text) - Movie plot/description (used for embedding generation)
- `genre` (string or array) - Genre(s) of the movie
- `year` (integer) - Release year
- `embedding` (text/json or separate table) - The 384-dimensional embedding vector
- `created_at`, `updated_at` (timestamps)

**Optional but useful fields:**
- `director` (string)
- `rating` (decimal) - Average rating
- `poster_url` (string) - URL to movie poster
- `runtime` (integer) - Movie length in minutes

**Embedding Storage Options:**

**Option A: JSON column (simpler, good for SQLite)**
```ruby
# Migration
add_column :movies, :embedding, :text  # Store as JSON string
# Or use json column type if your DB supports it
```

**Option B: Separate embeddings table (more normalized)**
```ruby
# movies table - no embedding column
# embeddings table with: movie_id, vector (as JSON/text)
```

**Recommendation: Use Option A (JSON column) for simplicity with SQLite**

### 2. Users Table

**Essential fields:**
- `id` (primary key)
- `email` (string) - For authentication
- `password_digest` (string) - For authentication (if using has_secure_password)
- `created_at`, `updated_at` (timestamps)

**Optional fields:**
- `name` (string)
- `username` (string)

### 3. Likes Table (Junction Table)

**Essential fields:**
- `id` (primary key)
- `user_id` (integer, foreign key) - References users
- `movie_id` (integer, foreign key) - References movies
- `created_at`, `updated_at` (timestamps)

**Indexes:**
- Index on `user_id` for fast lookup of user's liked movies
- Index on `movie_id` for fast lookup of who liked a movie
- Unique index on `[user_id, movie_id]` to prevent duplicate likes

## What Data to Collect for Movies

### For Embedding Generation (Most Important):

1. **Description/Plot** - This is the primary text used to generate embeddings
   - Full plot summary
   - Or short synopsis
   - This text will be passed to EmbeddingService

2. **Title** - Can be combined with description for richer embeddings

3. **Genre** - Can be included in the embedding text

### Recommended Embedding Text Format:

Combine multiple fields for better embeddings:
```
"#{title}. #{description}. Genre: #{genre}. Year: #{year}"
```

Example:
```
"The Matrix. A computer hacker learns about the true nature of reality. Genre: Science Fiction, Action. Year: 1999"
```

## Database Migrations Needed

1. Create movies table
2. Create users table  
3. Create likes table
4. Add indexes for performance

## How It Works

1. **When adding a movie:**
   - Store movie metadata (title, description, genre, etc.)
   - Generate embedding from combined text (title + description + genre)
   - Store embedding vector in the `embedding` column

2. **When user likes a movie:**
   - Create a record in the `likes` table linking user_id and movie_id

3. **For recommendations:**
   - Get all movies the user has liked
   - Get embeddings for those movies
   - Calculate average embedding (or use other similarity methods)
   - Find movies with similar embeddings (cosine similarity)
   - Exclude movies the user has already liked
   - Return top N recommendations

## Example Movie Data Structure

```ruby
{
  title: "The Matrix",
  description: "A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.",
  genre: "Science Fiction, Action",
  year: 1999,
  embedding: [0.123, -0.456, 0.789, ...] # 384 numbers
}
```

## Storage Considerations

- **Embedding size**: 384 dimensions × 4 bytes (float) = ~1.5 KB per movie
- **1000 movies**: ~1.5 MB of embedding data (very manageable)
- **SQLite JSON**: Can store embeddings as JSON string in text column
- **Alternative**: Use PostgreSQL with vector extension (pgvector) for better performance at scale
