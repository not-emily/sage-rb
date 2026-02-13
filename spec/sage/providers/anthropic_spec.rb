# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sage::Providers::Anthropic do
  let(:provider) { Sage::Providers::Anthropic.new(api_key: "sk-ant-test") }

  def stub_completion_response(content: "Hello!", input_tokens: 10, output_tokens: 5)
    body = {
      content: [{ type: "text", text: content }],
      usage: { input_tokens: input_tokens, output_tokens: output_tokens }
    }.to_json

    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return(body)
    response
  end

  def stub_streaming_response(text_chunks)
    body_data = ""
    text_chunks.each do |text|
      body_data += "event: content_block_delta\n"
      body_data += "data: #{{ type: "content_block_delta", delta: { type: "text_delta", text: text } }.to_json}\n\n"
    end
    body_data += "event: message_stop\n"
    body_data += "data: {\"type\":\"message_stop\"}\n\n"

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
    it "returns a Response with content, model, and normalized usage" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_completion_response)

      response = provider.complete(model: "claude-sonnet-4-5-20250929", prompt: "Hi")

      expect(response).to be_a(Sage::Response)
      expect(response.content).to eq("Hello!")
      expect(response.model).to eq("claude-sonnet-4-5-20250929")
      expect(response.usage).to eq(prompt_tokens: 10, completion_tokens: 5)
    end

    it "sends system as a separate field, not in messages" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)

      captured_body = nil
      allow(http).to receive(:request) do |req|
        captured_body = JSON.parse(req.body)
        stub_completion_response
      end

      provider.complete(model: "claude-sonnet-4-5-20250929", prompt: "Hi", system: "You are helpful")

      expect(captured_body["system"]).to eq("You are helpful")
      expect(captured_body["messages"]).to eq([
        { "role" => "user", "content" => "Hi" }
      ])
    end

    it "omits system field when not provided" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)

      captured_body = nil
      allow(http).to receive(:request) do |req|
        captured_body = JSON.parse(req.body)
        stub_completion_response
      end

      provider.complete(model: "claude-sonnet-4-5-20250929", prompt: "Hi")

      expect(captured_body).not_to have_key("system")
    end

    it "uses correct auth headers" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)

      captured_headers = nil
      allow(http).to receive(:request) do |req|
        captured_headers = {
          "x-api-key" => req["x-api-key"],
          "anthropic-version" => req["anthropic-version"]
        }
        stub_completion_response
      end

      provider.complete(model: "claude-sonnet-4-5-20250929", prompt: "Hi")

      expect(captured_headers["x-api-key"]).to eq("sk-ant-test")
      expect(captured_headers["anthropic-version"]).to eq("2023-06-01")
    end
  end

  describe "max_tokens handling" do
    def capture_request_body
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)

      captured_body = nil
      allow(http).to receive(:request) do |req|
        captured_body = JSON.parse(req.body)
        stub_completion_response
      end

      yield

      captured_body
    end

    it "defaults max_tokens to 1024" do
      body = capture_request_body do
        provider.complete(model: "claude-sonnet-4-5-20250929", prompt: "Hi")
      end

      expect(body["max_tokens"]).to eq(1024)
    end

    it "uses provided max_tokens" do
      body = capture_request_body do
        provider.complete(model: "claude-sonnet-4-5-20250929", prompt: "Hi", max_tokens: 4096)
      end

      expect(body["max_tokens"]).to eq(4096)
    end
  end

  describe "#stream" do
    it "yields chunks from event-based SSE stream" do
      response = stub_streaming_response(["Hello", " world"])

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request).and_yield(response)

      chunks = []
      provider.stream(model: "claude-sonnet-4-5-20250929", prompt: "Hi") { |c| chunks << c }

      expect(chunks.length).to eq(3)
      expect(chunks[0].content).to eq("Hello")
      expect(chunks[1].content).to eq(" world")
      expect(chunks[2].done?).to be true
    end

    it "ignores non-content_block_delta events" do
      body_data = ""
      body_data += "event: message_start\n"
      body_data += "data: {\"type\":\"message_start\"}\n\n"
      body_data += "event: content_block_start\n"
      body_data += "data: {\"type\":\"content_block_start\"}\n\n"
      body_data += "event: content_block_delta\n"
      body_data += "data: #{{ type: "content_block_delta", delta: { type: "text_delta", text: "Hi" } }.to_json}\n\n"
      body_data += "event: message_stop\n"
      body_data += "data: {\"type\":\"message_stop\"}\n\n"

      response = Net::HTTPSuccess.new("1.1", "200", "OK")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(response).to receive(:read_body).and_yield(body_data)

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request).and_yield(response)

      chunks = []
      provider.stream(model: "claude-sonnet-4-5-20250929", prompt: "Hi") { |c| chunks << c }

      expect(chunks.length).to eq(2)
      expect(chunks[0].content).to eq("Hi")
      expect(chunks[1].done?).to be true
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_error_response(401, message: "Invalid API key"))

      expect { provider.complete(model: "claude-sonnet-4-5-20250929", prompt: "Hi") }
        .to raise_error(Sage::AuthenticationError, /Invalid API key/)
    end

    it "raises ProviderError on 429 rate limit" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_error_response(429, message: "Rate limit exceeded"))

      expect { provider.complete(model: "claude-sonnet-4-5-20250929", prompt: "Hi") }
        .to raise_error(Sage::ProviderError, /Rate limited/)
    end

    it "raises ProviderError on 500" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_error_response(500, message: "Server error"))

      expect { provider.complete(model: "claude-sonnet-4-5-20250929", prompt: "Hi") }
        .to raise_error(Sage::ProviderError, /API error \(500\)/)
    end
  end
end
