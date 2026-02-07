# Movie Recommender App Overview

## General Idea

This is a movie recommendation application that helps users discover movies based on their preferences.

## Core Features

### Users
- Users can create accounts and sign in
- Users can like movies from the catalog

### Movie Catalog
- The app contains a database of 1000 movies
- Each movie has information such as title, description, genre, etc.

### Recommendations
- Users receive personalized movie recommendations
- Recommendations are generated based on the movies a user has liked
- The system uses embedding similarity to find movies similar to the ones the user likes

## How It Works

1. User signs up and creates an account
2. User browses the movie catalog and likes movies they enjoy
3. The system analyzes the user's liked movies using embeddings
4. The system finds similar movies in the catalog based on embedding similarity
5. User receives personalized recommendations

## Technical Approach

The app uses text embeddings to understand movie content and user preferences. When a user likes a movie, the system:
- Generates an embedding vector for that movie's content
- Compares it with embeddings of other movies in the catalog
- Recommends movies with similar embedding vectors
