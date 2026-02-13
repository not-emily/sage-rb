# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Sage
  module Providers
    class Ollama < Base
      DEFAULT_BASE_URL = "http://localhost:11434"

      def complete(model:, prompt:, system: nil, **params)
        body = build_request_body(model, prompt, system, stream: false)
        response = post(body)

        parsed = JSON.parse(response.body)

        raise ProviderError, "Ollama error: #{parsed["error"]}" if parsed["error"] && !parsed["error"].empty?

        content = parsed.dig("message", "content") || ""

        Response.new(
          content: content,
          model: model,
          usage: {
            prompt_tokens: parsed["prompt_eval_count"] || 0,
            completion_tokens: parsed["eval_count"] || 0
          }
        )
      rescue Errno::ECONNREFUSED
        raise ConnectionError, "Could not connect to Ollama at #{endpoint_uri}. Is Ollama running?"
      end

      def stream(model:, prompt:, system: nil, **params, &block)
        body = build_request_body(model, prompt, system, stream: true)
        uri = endpoint_uri

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          request = build_http_request(uri, body)

          http.request(request) do |response|
            handle_error_response(response) unless response.is_a?(Net::HTTPSuccess)

            response.read_body do |chunk_data|
              chunk_data.each_line do |line|
                line = line.strip
                next if line.empty?

                parsed = JSON.parse(line)

                if parsed["done"]
                  block.call(Chunk.new(content: "", done: true))
                  return
                end

                content = parsed.dig("message", "content")
                next if content.nil? || content.empty?

                block.call(Chunk.new(content: content))
              end
            end
          end
        end
      rescue Errno::ECONNREFUSED
        raise ConnectionError, "Could not connect to Ollama at #{endpoint_uri}. Is Ollama running?"
      end

      private

      def build_request_body(model, prompt, system, stream:)
        messages = []
        messages << { role: "system", content: system } if system
        messages << { role: "user", content: prompt }

        {
          model: model,
          messages: messages,
          stream: stream
        }
      end

      def post(body)
        uri = endpoint_uri
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.read_timeout = 300

        request = build_http_request(uri, body)
        response = http.request(request)

        handle_error_response(response) unless response.is_a?(Net::HTTPSuccess)

        response
      end

      def build_http_request(uri, body)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"

        api_key = config[:api_key]
        request["Authorization"] = "Bearer #{api_key}" if api_key && !api_key.empty?

        request.body = JSON.generate(body)
        request
      end

      def endpoint_uri
        base = config[:endpoint]
        base = DEFAULT_BASE_URL if base.nil? || base.empty?
        URI("#{base.chomp("/")}/api/chat")
      end

      def handle_error_response(response)
        message = extract_error_message(response)
        raise ProviderError, "Ollama error (#{response.code}): #{message}"
      end

      def extract_error_message(response)
        parsed = JSON.parse(response.body)
        parsed["error"] || response.body
      rescue JSON::ParserError
        response.body
      end
    end
  end
end
