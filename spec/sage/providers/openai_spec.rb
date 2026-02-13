# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sage::Providers::OpenAI do
  let(:provider) { Sage::Providers::OpenAI.new(api_key: "sk-test") }

  def stub_completion_response(content: "Hello!", model: "gpt-4o", prompt_tokens: 10, completion_tokens: 5)
    body = {
      choices: [{ message: { content: content } }],
      usage: { prompt_tokens: prompt_tokens, completion_tokens: completion_tokens }
    }.to_json

    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return(body)
    response
  end

  def stub_streaming_response(chunks)
    body_data = chunks.map { |c| "data: #{c}\n\n" }.join
    body_data += "data: [DONE]\n\n"

    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(response).to receive(:read_body).and_yield(body_data)
    response
  end

  def stub_error_response(code, message: "error")
    status_messages = { "401" => "Unauthorized", "429" => "Too Many Requests", "500" => "Internal Server Error" }
    response = Net::HTTPResponse.new("1.1", code.to_s, status_messages[code.to_s] || "Error")
    body = { error: { message: message } }.to_json
    allow(response).to receive(:body).and_return(body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    response
  end

  describe "#complete" do
    it "returns a Response with content, model, and usage" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_completion_response)

      response = provider.complete(model: "gpt-4o", prompt: "Hi")

      expect(response).to be_a(Sage::Response)
      expect(response.content).to eq("Hello!")
      expect(response.model).to eq("gpt-4o")
      expect(response.usage).to eq(prompt_tokens: 10, completion_tokens: 5)
    end

    it "includes system message when provided" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)

      captured_body = nil
      allow(http).to receive(:request) do |req|
        captured_body = JSON.parse(req.body)
        stub_completion_response
      end

      provider.complete(model: "gpt-4o", prompt: "Hi", system: "You are helpful")

      expect(captured_body["messages"]).to eq([
        { "role" => "system", "content" => "You are helpful" },
        { "role" => "user", "content" => "Hi" }
      ])
    end

    it "omits system message when not provided" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)

      captured_body = nil
      allow(http).to receive(:request) do |req|
        captured_body = JSON.parse(req.body)
        stub_completion_response
      end

      provider.complete(model: "gpt-4o", prompt: "Hi")

      expect(captured_body["messages"]).to eq([
        { "role" => "user", "content" => "Hi" }
      ])
    end
  end

  describe "model-specific max_tokens handling" do
    def capture_request_body
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)

      captured_body = nil
      allow(http).to receive(:request) do |req|
        captured_body = JSON.parse(req.body)
        stub_completion_response
      end

      yield

      captured_body
    end

    it "uses max_completion_tokens for o1 models" do
      body = capture_request_body do
        provider.complete(model: "o1-preview", prompt: "Hi", max_tokens: 1024)
      end

      expect(body["max_completion_tokens"]).to eq(1024)
      expect(body).not_to have_key("max_tokens")
    end

    it "uses max_completion_tokens for o3 models" do
      body = capture_request_body do
        provider.complete(model: "o3-mini", prompt: "Hi", max_tokens: 1024)
      end

      expect(body["max_completion_tokens"]).to eq(1024)
      expect(body).not_to have_key("max_tokens")
    end

    it "uses max_completion_tokens for gpt-4o models" do
      body = capture_request_body do
        provider.complete(model: "gpt-4o-mini", prompt: "Hi", max_tokens: 1024)
      end

      expect(body["max_completion_tokens"]).to eq(1024)
      expect(body).not_to have_key("max_tokens")
    end

    it "uses max_completion_tokens for gpt-5 models" do
      body = capture_request_body do
        provider.complete(model: "gpt-5-codex", prompt: "Hi", max_tokens: 1024)
      end

      expect(body["max_completion_tokens"]).to eq(1024)
      expect(body).not_to have_key("max_tokens")
    end

    it "uses max_tokens for older models" do
      body = capture_request_body do
        provider.complete(model: "gpt-3.5-turbo", prompt: "Hi", max_tokens: 1024)
      end

      expect(body["max_tokens"]).to eq(1024)
      expect(body).not_to have_key("max_completion_tokens")
    end
  end

  describe "#stream" do
    it "yields chunks from SSE stream" do
      chunk1 = { choices: [{ delta: { content: "Hello" } }] }.to_json
      chunk2 = { choices: [{ delta: { content: " world" } }] }.to_json
      response = stub_streaming_response([chunk1, chunk2])

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:request).and_yield(response)

      chunks = []
      provider.stream(model: "gpt-4o", prompt: "Hi") { |c| chunks << c }

      expect(chunks.length).to eq(3)
      expect(chunks[0].content).to eq("Hello")
      expect(chunks[1].content).to eq(" world")
      expect(chunks[2].done?).to be true
    end

    it "skips empty content deltas" do
      chunk1 = { choices: [{ delta: { content: "Hi" } }] }.to_json
      chunk2 = { choices: [{ delta: {} }] }.to_json
      response = stub_streaming_response([chunk1, chunk2])

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:request).and_yield(response)

      chunks = []
      provider.stream(model: "gpt-4o", prompt: "Hi") { |c| chunks << c }

      expect(chunks.length).to eq(2)
      expect(chunks[0].content).to eq("Hi")
      expect(chunks[1].done?).to be true
    end
  end

  describe "base_url" do
    it "uses custom base_url when configured" do
      provider = Sage::Providers::OpenAI.new(api_key: "sk-test", base_url: "https://custom.api.com/v1")

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).with("custom.api.com", 443).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_completion_response)

      response = provider.complete(model: "gpt-4o", prompt: "Hi")
      expect(response.content).to eq("Hello!")
    end

    it "strips trailing slash from base_url" do
      provider = Sage::Providers::OpenAI.new(api_key: "sk-test", base_url: "https://custom.api.com/v1/")

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).with("custom.api.com", 443).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)

      captured_uri = nil
      allow(http).to receive(:request) do |req|
        captured_uri = req.path
        stub_completion_response
      end

      provider.complete(model: "gpt-4o", prompt: "Hi")
      expect(captured_uri).to eq("/v1/chat/completions")
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_error_response(401, message: "Invalid API key"))

      expect { provider.complete(model: "gpt-4o", prompt: "Hi") }
        .to raise_error(Sage::AuthenticationError, /Invalid API key/)
    end

    it "raises ProviderError on 429 rate limit" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_error_response(429, message: "Rate limit exceeded"))

      expect { provider.complete(model: "gpt-4o", prompt: "Hi") }
        .to raise_error(Sage::ProviderError, /Rate limited/)
    end

    it "raises ProviderError on 500" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_error_response(500, message: "Server error"))

      expect { provider.complete(model: "gpt-4o", prompt: "Hi") }
        .to raise_error(Sage::ProviderError, /API error \(500\)/)
    end
  end
end
