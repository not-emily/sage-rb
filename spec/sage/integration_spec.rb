# frozen_string_literal: true

require "spec_helper"

# Mock provider for integration tests
class IntegrationMockProvider < Sage::Providers::Base
  def complete(model:, prompt:, system: nil, **params)
    Sage::Response.new(
      content: "#{model} says: #{prompt}",
      model: model,
      usage: { prompt_tokens: 5, completion_tokens: 10 }
    )
  end

  def stream(model:, prompt:, system: nil, **params)
    yield Sage::Chunk.new(content: "#{model} ")
    yield Sage::Chunk.new(content: "streaming")
    yield Sage::Chunk.new(content: "", done: true)
  end
end

RSpec.describe "Sage end-to-end" do
  before do
    Sage::Client.register_provider(:mock, IntegrationMockProvider)
  end

  after do
    Sage::Client::PROVIDERS.delete(:mock)
  end

  describe "Sage.complete with profiles" do
    before do
      Sage.configure do |config|
        config.provider :mock, api_key: "test"
        config.profile :fast, provider: :mock, model: "small-model"
        config.profile :smart, provider: :mock, model: "big-model", temperature: 0.2
        config.default_profile :fast
      end
    end

    it "completes with a named profile (blocking)" do
      response = Sage.complete(:smart, prompt: "hello")

      expect(response.content).to eq("big-model says: hello")
      expect(response.model).to eq("big-model")
    end

    it "completes with a named profile (streaming)" do
      chunks = []
      Sage.complete(:smart, prompt: "hello") { |c| chunks << c }

      expect(chunks.length).to eq(3)
      expect(chunks[0].content).to eq("big-model ")
      expect(chunks[1].content).to eq("streaming")
      expect(chunks[2].done?).to be true
    end

    it "uses default profile when no name given" do
      response = Sage.complete(prompt: "hello")

      expect(response.content).to eq("small-model says: hello")
    end

    it "uses default profile for streaming when no name given" do
      chunks = []
      Sage.complete(prompt: "hello") { |c| chunks << c }

      expect(chunks[0].content).to eq("small-model ")
    end

    it "allows per-call parameter overrides" do
      # Should not raise — temperature from profile is overridden
      response = Sage.complete(:smart, prompt: "hello", temperature: 0.9)

      expect(response).to be_a(Sage::Response)
    end
  end

  describe "error cases" do
    it "raises ProfileNotFound for unknown profiles" do
      Sage.configure do |config|
        config.provider :mock, api_key: "test"
        config.profile :only, provider: :mock, model: "test"
        config.default_profile :only
      end

      expect { Sage.complete(:nonexistent, prompt: "hello") }
        .to raise_error(Sage::ProfileNotFound, /nonexistent/)
    end

    it "raises NoDefaultProfile when no profile name and no default set" do
      Sage.configure do |config|
        config.provider :mock, api_key: "test"
        config.profile :only, provider: :mock, model: "test"
        # no default_profile set
      end

      expect { Sage.complete(prompt: "hello") }
        .to raise_error(Sage::NoDefaultProfile)
    end

    it "raises ProviderNotConfigured when provider config is missing" do
      Sage.configure do |config|
        # no provider registered
        config.profile :orphan, provider: :mock, model: "test"
        config.default_profile :orphan
      end

      expect { Sage.complete(prompt: "hello") }
        .to raise_error(Sage::ProviderNotConfigured, /mock/)
    end
  end

  describe "multiple profiles, same provider" do
    it "routes to correct model based on profile" do
      Sage.configure do |config|
        config.provider :mock, api_key: "test"
        config.profile :small, provider: :mock, model: "tiny"
        config.profile :large, provider: :mock, model: "huge"
        config.default_profile :small
      end

      small_response = Sage.complete(:small, prompt: "hi")
      large_response = Sage.complete(:large, prompt: "hi")

      expect(small_response.content).to eq("tiny says: hi")
      expect(large_response.content).to eq("huge says: hi")
    end
  end

  describe "conditional default profile" do
    it "supports dynamic default profile selection" do
      env = "production"

      Sage.configure do |config|
        config.provider :mock, api_key: "test"
        config.profile :cheap, provider: :mock, model: "small"
        config.profile :quality, provider: :mock, model: "large"
        config.default_profile(env == "production" ? :quality : :cheap)
      end

      response = Sage.complete(prompt: "hi")
      expect(response.content).to eq("large says: hi")
    end
  end
end
