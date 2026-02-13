# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Sage
  module Providers
    class Anthropic < Base
      DEFAULT_BASE_URL = "https://api.anthropic.com/v1"
      ANTHROPIC_VERSION = "2023-06-01"
      DEFAULT_MAX_TOKENS = 1024

      def complete(model:, prompt:, system: nil, **params)
        body = build_request_body(model, prompt, system, stream: false, **params)
        response = post(body)

        parsed = JSON.parse(response.body)
        content = extract_content(parsed)
        usage = parsed.fetch("usage", {})

        Response.new(
          content: content,
          model: model,
          usage: {
            prompt_tokens: usage["input_tokens"] || 0,
            completion_tokens: usage["output_tokens"] || 0
          }
        )
      end

      def stream(model:, prompt:, system: nil, **params, &block)
        body = build_request_body(model, prompt, system, stream: true, **params)
        uri = endpoint_uri

        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          request = build_http_request(uri, body)

          http.request(request) do |response|
            handle_error_response(response) unless response.is_a?(Net::HTTPSuccess)

            current_event = nil

            response.read_body do |chunk_data|
              chunk_data.each_line do |line|
                line = line.strip

                if line.start_with?("event: ")
                  current_event = line.delete_prefix("event: ")
                  next
                end

                next if line.empty?
                next unless line.start_with?("data: ")

                if current_event == "message_stop"
                  block.call(Chunk.new(content: "", done: true))
                  return
                end

                next unless current_event == "content_block_delta"

                data = line.delete_prefix("data: ")
                parsed = JSON.parse(data)
                delta = parsed["delta"]

                next unless delta && delta["type"] == "text_delta" && !delta["text"].empty?

                block.call(Chunk.new(content: delta["text"]))
              end
            end
          end
        end
      end

      private

      def build_request_body(model, prompt, system, stream:, **params)
        max_tokens = params.delete(:max_tokens) || DEFAULT_MAX_TOKENS

        body = {
          model: model,
          messages: [{ role: "user", content: prompt }],
          max_tokens: max_tokens
        }

        body[:system] = system if system
        body[:stream] = true if stream
        body.merge!(params)
        body
      end

      def extract_content(parsed)
        content_blocks = parsed["content"] || []
        text_block = content_blocks.find { |block| block["type"] == "text" }
        text_block ? text_block["text"] : ""
      end

      def endpoint_uri
        base = config[:base_url]
        base = DEFAULT_BASE_URL if base.nil? || base.empty?
        URI("#{base.chomp("/")}/messages")
      end

      def post(body)
        uri = endpoint_uri
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 300

        request = build_http_request(uri, body)
        response = http.request(request)

        handle_error_response(response) unless response.is_a?(Net::HTTPSuccess)

        response
      end

      def build_http_request(uri, body)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["x-api-key"] = config[:api_key]
        request["anthropic-version"] = ANTHROPIC_VERSION
        request.body = JSON.generate(body)
        request
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
