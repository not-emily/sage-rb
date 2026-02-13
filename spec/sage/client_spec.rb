# frozen_string_literal: true

require "spec_helper"

class MockProvider < Sage::Providers::Base
  def complete(model:, prompt:, system: nil, **params)
    Sage::Response.new(
      content: "mock response to: #{prompt}",
      model: model,
      usage: { prompt_tokens: 5, completion_tokens: 10 }
    )
  end

  def stream(model:, prompt:, system: nil, **params)
    yield Sage::Chunk.new(content: "mock ")
    yield Sage::Chunk.new(content: "stream")
    yield Sage::Chunk.new(content: "", done: true)
  end
end

RSpec.describe Sage::Client do
  before do
    Sage::Client.register_provider(:mock, MockProvider)
  end

  after do
    Sage::Client::PROVIDERS.delete(:mock)
  end

  let(:configuration) do
    config = Sage::Configuration.new
    config.provider :mock, api_key: "test-key"
    config.profile :test, provider: :mock, model: "mock-model"
    config.default_profile :test
    config
  end

  let(:client) { Sage::Client.new(configuration) }

  describe "#complete (blocking)" do
    it "dispatches to the correct provider and returns a response" do
      response = client.complete(:test, prompt: "hello")

      expect(response).to be_a(Sage::Response)
      expect(response.content).to eq("mock response to: hello")
      expect(response.model).to eq("mock-model")
    end

    it "uses the default profile when no profile name given" do
      response = client.complete(prompt: "hello")

      expect(response.content).to eq("mock response to: hello")
    end

    it "merges profile params with per-call params" do
      config = Sage::Configuration.new
      config.provider :mock, api_key: "test-key"
      config.profile :with_params, provider: :mock, model: "mock-model", temperature: 0.5
      config.default_profile :with_params

      client = Sage::Client.new(config)
      # Should not raise — params are passed through
      response = client.complete(prompt: "hello", temperature: 0.9)

      expect(response).to be_a(Sage::Response)
    end
  end

  describe "#complete (streaming)" do
    it "yields chunks when a block is given" do
      chunks = []
      client.complete(:test, prompt: "hello") { |chunk| chunks << chunk }

      expect(chunks.length).to eq(3)
      expect(chunks[0].content).to eq("mock ")
      expect(chunks[1].content).to eq("stream")
      expect(chunks[2].done?).to be true
    end
  end

  describe "error handling" do
    it "raises NoDefaultProfile when no profile name and no default" do
      config = Sage::Configuration.new
      config.provider :mock, api_key: "test-key"
      client = Sage::Client.new(config)

      expect { client.complete(prompt: "hello") }.to raise_error(Sage::NoDefaultProfile)
    end

    it "raises ProfileNotFound for unknown profiles" do
      expect { client.complete(:unknown, prompt: "hello") }.to raise_error(Sage::ProfileNotFound, /unknown/)
    end

    it "raises ProviderNotConfigured when provider is not registered" do
      config = Sage::Configuration.new
      config.provider :unregistered, api_key: "test"
      config.profile :bad, provider: :unregistered, model: "test"
      client = Sage::Client.new(config)

      expect { client.complete(:bad, prompt: "hello") }.to raise_error(Sage::ProviderNotConfigured, /unregistered/)
    end

    it "raises ProviderNotConfigured when provider config is missing" do
      config = Sage::Configuration.new
      config.profile :orphan, provider: :mock, model: "test"
      client = Sage::Client.new(config)

      expect { client.complete(:orphan, prompt: "hello") }.to raise_error(Sage::ProviderNotConfigured, /mock/)
    end
  end
end
