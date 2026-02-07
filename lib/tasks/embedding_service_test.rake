namespace :embedding do
  desc "Test the EmbeddingService with sample text"
  task test: :environment do
    puts "=" * 60
    puts "Testing EmbeddingService"
    puts "=" * 60
    puts

    # Test 1: Normal embedding
    puts "Test 1: Generating embedding for sample text..."
    test_text = "The Matrix is a science fiction action film"
    
    begin
      embedding = EmbeddingService.embed(test_text)
      
      puts "✓ Successfully generated embedding"
      puts "  Input text: #{test_text}"
      puts "  Embedding dimensions: #{embedding.length}" if embedding.respond_to?(:length)
      puts "  Expected dimensions: #{EmbeddingService::DIMENSION}"
      puts "  First 5 values: #{embedding.first(5).map { |v| v.round(6) }.join(', ')}" if embedding.is_a?(Array) && embedding.any?
      puts "  Dimensions match: #{embedding.length == EmbeddingService::DIMENSION ? '✓' : '✗'}" if embedding.respond_to?(:length)
      puts
    rescue => e
      puts "✗ Error: #{e.class} - #{e.message}"
      puts e.backtrace.first(3).join("\n") if e.backtrace
      puts
    end

    # Test 2: Error handling - blank text
    puts "Test 2: Testing error handling with blank text..."
    begin
      EmbeddingService.embed("")
      puts "✗ Should have raised ArgumentError"
    rescue ArgumentError => e
      puts "✓ Correctly raised ArgumentError: #{e.message}"
    rescue => e
      puts "✗ Unexpected error: #{e.class} - #{e.message}"
    end
    puts

    # Test 3: Error handling - nil text
    puts "Test 3: Testing error handling with nil text..."
    begin
      EmbeddingService.embed(nil)
      puts "✗ Should have raised ArgumentError"
    rescue ArgumentError => e
      puts "✓ Correctly raised ArgumentError: #{e.message}"
    rescue => e
      puts "✗ Unexpected error: #{e.class} - #{e.message}"
    end
    puts

    # Test 4: Longer text
    puts "Test 4: Testing with longer text..."
    longer_text = "Inception is a 2010 science fiction action film written and directed by Christopher Nolan. The film stars Leonardo DiCaprio as a professional thief who steals information by infiltrating the subconscious of his targets."
    
    begin
      embedding = EmbeddingService.embed(longer_text)
      puts "✓ Successfully generated embedding for longer text"
      puts "  Input text length: #{longer_text.length} characters"
      puts "  Embedding dimensions: #{embedding.length}" if embedding.respond_to?(:length)
      puts
    rescue => e
      puts "✗ Error: #{e.class} - #{e.message}"
      puts e.backtrace.first(3).join("\n") if e.backtrace
      puts
    end

    puts "=" * 60
    puts "Testing complete!"
    puts "=" * 60
  end
end
