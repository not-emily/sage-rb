# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Sage
  module Providers
    class OpenAI < Base
      DEFAULT_BASE_URL = "https://api.openai.com/v1"

      def complete(model:, prompt:, system: nil, **params)
        body = build_request_body(model, prompt, system, stream: false, **params)
        response = post(body)

        parsed = JSON.parse(response.body)
        content = parsed.dig("choices", 0, "message", "content") || ""
        usage = parsed.fetch("usage", {})

        Response.new(
          content: content,
          model: model,
          usage: {
            prompt_tokens: usage["prompt_tokens"] || 0,
            completion_tokens: usage["completion_tokens"] || 0
          }
        )
      end

      def stream(model:, prompt:, system: nil, **params, &block)
        body = build_request_body(model, prompt, system, stream: true, **params)
        uri = endpoint_uri

        ssl = uri.scheme == "https"
        Net::HTTP.start(uri.host, uri.port, use_ssl: ssl) do |http|
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER if ssl
          request = build_http_request(uri, body)

          http.request(request) do |response|
            handle_error_response(response) unless response.is_a?(Net::HTTPSuccess)

            response.read_body do |chunk_data|
              chunk_data.each_line do |line|
                line = line.strip
                next if line.empty?
                next unless line.start_with?("data: ")

                data = line.delete_prefix("data: ")

                if data == "[DONE]"
                  block.call(Chunk.new(content: "", done: true))
                  return
                end

                parsed = JSON.parse(data)
                content = parsed.dig("choices", 0, "delta", "content")
                next if content.nil? || content.empty?

                block.call(Chunk.new(content: content))
              end
            end
          end
        end
      end

      private

      def build_request_body(model, prompt, system, stream:, **params)
        messages = []
        messages << { role: "system", content: system } if system
        messages << { role: "user", content: prompt }

        body = {
          model: model,
          messages: messages,
          stream: stream
        }

        if params[:max_tokens]
          if use_max_completion_tokens?(model)
            body[:max_completion_tokens] = params.delete(:max_tokens)
          else
            body[:max_tokens] = params.delete(:max_tokens)
          end
        end

        body.merge!(params.except(:max_tokens))
        body
      end

      def use_max_completion_tokens?(model)
        model.start_with?("o1", "o3") ||
          model.include?("gpt-4o") ||
          model.include?("gpt-5")
      end

      def post(body)
        uri = endpoint_uri
        http = Net::HTTP.new(uri.host, uri.port)
        ssl = uri.scheme == "https"
        http.use_ssl = ssl
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER if ssl
        http.read_timeout = 300

        request = build_http_request(uri, body)
        response = http.request(request)

        handle_error_response(response) unless response.is_a?(Net::HTTPSuccess)

        response
      end

      def build_http_request(uri, body)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{config[:api_key]}"
        request.body = JSON.generate(body)
        request
      end

      def endpoint_uri
        base = config[:base_url]
        base = DEFAULT_BASE_URL if base.nil? || base.empty?
        URI("#{base.chomp("/")}/chat/completions")
      end

      def handle_error_response(response)
        message = extract_error_message(response)

        case response.code.to_i
        when 401
          raise AuthenticationError, "Invalid API key: #{message}"
        when 429
          raise ProviderError, "Rate limited: #{message}"
        else
          raise ProviderError, "API error (#{response.code}): #{message}"
        end
      end

      def extract_error_message(response)
        parsed = JSON.parse(response.body)
        parsed.dig("error", "message") || response.body
      rescue JSON::ParserError
        response.body
      end
    end
  end
end
