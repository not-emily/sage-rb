# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sage::Providers::Ollama do
  let(:provider) { Sage::Providers::Ollama.new(endpoint: "http://localhost:11434") }

  def stub_completion_response(content: "Hello!", prompt_eval_count: 10, eval_count: 5)
    body = {
      message: { role: "assistant", content: content },
      done: true,
      prompt_eval_count: prompt_eval_count,
      eval_count: eval_count
    }.to_json

    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    allow(response).to receive(:body).and_return(body)
    response
  end

  def stub_streaming_response(chunks)
    body_data = chunks.map { |c| "#{c.to_json}\n" }.join

    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(response).to receive(:read_body).and_yield(body_data)
    response
  end

  def stub_error_response(code, error_message: "something went wrong")
    response = Net::HTTPResponse.new("1.1", code.to_s, "Error")
    body = { error: error_message }.to_json
    allow(response).to receive(:body).and_return(body)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    response
  end

  describe "#complete" do
    it "returns a Response with content, model, and normalized usage" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_completion_response)

      response = provider.complete(model: "hermes3", prompt: "Hi")

      expect(response).to be_a(Sage::Response)
      expect(response.content).to eq("Hello!")
      expect(response.model).to eq("hermes3")
      expect(response.usage).to eq(prompt_tokens: 10, completion_tokens: 5)
    end

    it "includes system message in messages array" do
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

      provider.complete(model: "hermes3", prompt: "Hi", system: "You are helpful")

      expect(captured_body["messages"]).to eq([
        { "role" => "system", "content" => "You are helpful" },
        { "role" => "user", "content" => "Hi" }
      ])
    end

    it "raises ProviderError when response contains an error field" do
      body = { error: "model not found" }.to_json
      response = Net::HTTPSuccess.new("1.1", "200", "OK")
      allow(response).to receive(:body).and_return(body)

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(response)

      expect { provider.complete(model: "hermes3", prompt: "Hi") }
        .to raise_error(Sage::ProviderError, /model not found/)
    end
  end

  describe "#stream" do
    it "yields chunks from newline-delimited JSON stream" do
      chunks = [
        { message: { content: "Hello" }, done: false },
        { message: { content: " world" }, done: false },
        { message: { content: "" }, done: true }
      ]
      response = stub_streaming_response(chunks)

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:request).and_yield(response)

      received = []
      provider.stream(model: "hermes3", prompt: "Hi") { |c| received << c }

      expect(received.length).to eq(3)
      expect(received[0].content).to eq("Hello")
      expect(received[1].content).to eq(" world")
      expect(received[2].done?).to be true
    end

    it "skips empty content chunks" do
      chunks = [
        { message: { content: "Hi" }, done: false },
        { message: { content: "" }, done: false },
        { message: { content: "" }, done: true }
      ]
      response = stub_streaming_response(chunks)

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:request).and_yield(response)

      received = []
      provider.stream(model: "hermes3", prompt: "Hi") { |c| received << c }

      expect(received.length).to eq(2)
      expect(received[0].content).to eq("Hi")
      expect(received[1].done?).to be true
    end
  end

  describe "authentication" do
    it "does not send Authorization header when no API key" do
      provider = Sage::Providers::Ollama.new(endpoint: "http://localhost:11434")

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)

      captured_headers = nil
      allow(http).to receive(:request) do |req|
        captured_headers = req.to_hash
        stub_completion_response
      end

      provider.complete(model: "hermes3", prompt: "Hi")

      expect(captured_headers).not_to have_key("authorization")
    end

    it "sends Bearer token when API key is provided" do
      provider = Sage::Providers::Ollama.new(endpoint: "http://localhost:11434", api_key: "my-key")

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)

      captured_auth = nil
      allow(http).to receive(:request) do |req|
        captured_auth = req["Authorization"]
        stub_completion_response
      end

      provider.complete(model: "hermes3", prompt: "Hi")

      expect(captured_auth).to eq("Bearer my-key")
    end
  end

  describe "endpoint handling" do
    it "uses custom endpoint" do
      provider = Sage::Providers::Ollama.new(endpoint: "http://remote-server:8080")

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).with("remote-server", 8080).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_completion_response)

      response = provider.complete(model: "hermes3", prompt: "Hi")
      expect(response.content).to eq("Hello!")
    end

    it "strips trailing slash from endpoint" do
      provider = Sage::Providers::Ollama.new(endpoint: "http://localhost:11434/")

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)

      captured_path = nil
      allow(http).to receive(:request) do |req|
        captured_path = req.path
        stub_completion_response
      end

      provider.complete(model: "hermes3", prompt: "Hi")
      expect(captured_path).to eq("/api/chat")
    end

    it "defaults to localhost:11434 when no endpoint" do
      provider = Sage::Providers::Ollama.new({})

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).with("localhost", 11434).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_completion_response)

      response = provider.complete(model: "hermes3", prompt: "Hi")
      expect(response.content).to eq("Hello!")
    end
  end

  describe "connection error handling" do
    it "raises ConnectionError when Ollama is not running" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_raise(Errno::ECONNREFUSED)

      expect { provider.complete(model: "hermes3", prompt: "Hi") }
        .to raise_error(Sage::ConnectionError, /Could not connect to Ollama.*Is Ollama running/)
    end

    it "raises ConnectionError on stream when Ollama is not running" do
      allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)

      expect { provider.stream(model: "hermes3", prompt: "Hi") { |c| } }
        .to raise_error(Sage::ConnectionError, /Could not connect to Ollama/)
    end
  end

  describe "error handling" do
    it "raises ProviderError on non-200 response" do
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(stub_error_response(500, error_message: "internal error"))

      expect { provider.complete(model: "hermes3", prompt: "Hi") }
        .to raise_error(Sage::ProviderError, /Ollama error \(500\).*internal error/)
    end
  end
end
