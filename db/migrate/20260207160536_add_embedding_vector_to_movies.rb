class AddEmbeddingVectorToMovies < ActiveRecord::Migration[8.1]
  def change
    # Add the column with Postgres vector type (384 = all-minilm:l6-v2 from Ollama)
    execute <<-SQL
      ALTER TABLE movies
      ADD COLUMN embedding_vec vector(384);
    SQL
  end
end
