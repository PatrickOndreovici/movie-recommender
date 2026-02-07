require "net/http"
require "json"
require "uri"

class EmbeddingService
  # Using Ollama locally with all-minilm:l6-v2 model
  # Make sure Ollama is running locally and the model is pulled:
  #   ollama pull all-minilm:l6-v2
  MODEL = "all-minilm:l6-v2"
  DIMENSION = 384
  OLLAMA_URL = ENV.fetch("OLLAMA_URL", "http://localhost:11434")

  def self.embed(text)
    raise ArgumentError, "Text cannot be blank" if text.blank?

    uri = URI("#{OLLAMA_URL}/api/embed")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = false

    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = {
      model: MODEL,
      input: text
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Ollama API error: #{response.code} - #{response.body}"
    end
    result = JSON.parse(response.body)

    result["embeddings"]&.first
  end
end