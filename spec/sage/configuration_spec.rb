# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sage::Configuration do
  describe "provider registration" do
    it "stores provider config by name" do
      Sage.configure do |config|
        config.provider :openai, api_key: "sk-test"
      end

      expect(Sage.configuration.providers[:openai]).to eq(api_key: "sk-test")
    end

    it "stores multiple providers" do
      Sage.configure do |config|
        config.provider :openai, api_key: "sk-test"
        config.provider :ollama, endpoint: "http://localhost:11434"
      end

      expect(Sage.configuration.providers.keys).to contain_exactly(:openai, :ollama)
    end

    it "accepts string provider names and converts to symbols" do
      Sage.configure do |config|
        config.provider "openai", api_key: "sk-test"
      end

      expect(Sage.configuration.providers[:openai]).to eq(api_key: "sk-test")
    end
  end

  describe "profile registration" do
    it "stores profiles with provider and model" do
      Sage.configure do |config|
        config.provider :ollama, endpoint: "http://localhost:11434"
        config.profile :fast, provider: :ollama, model: "hermes3"
      end

      profile = Sage.configuration.profiles[:fast]
      expect(profile).to be_a(Sage::Profile)
      expect(profile.name).to eq(:fast)
      expect(profile.provider).to eq(:ollama)
      expect(profile.model).to eq("hermes3")
    end

    it "stores extra params on profiles" do
      Sage.configure do |config|
        config.provider :openai, api_key: "sk-test"
        config.profile :creative, provider: :openai, model: "gpt-4o",
                       temperature: 0.9, max_tokens: 4096
      end

      profile = Sage.configuration.profiles[:creative]
      expect(profile.params).to eq(temperature: 0.9, max_tokens: 4096)
    end

    it "stores multiple profiles" do
      Sage.configure do |config|
        config.provider :openai, api_key: "sk-test"
        config.provider :ollama, endpoint: "http://localhost:11434"
        config.profile :fast, provider: :ollama, model: "hermes3"
        config.profile :smart, provider: :openai, model: "gpt-4o"
      end

      expect(Sage.configuration.profiles.keys).to contain_exactly(:fast, :smart)
    end
  end

  describe "default profile" do
    it "sets and retrieves the default profile" do
      Sage.configure do |config|
        config.provider :ollama, endpoint: "http://localhost:11434"
        config.profile :fast, provider: :ollama, model: "hermes3"
        config.default_profile :fast
      end

      expect(Sage.configuration.default_profile).to eq(:fast)
    end

    it "returns nil when no default is set" do
      Sage.configure do |config|
        config.provider :ollama, endpoint: "http://localhost:11434"
      end

      expect(Sage.configuration.default_profile).to be_nil
    end
  end

  describe "Sage.configure" do
    it "replaces configuration on subsequent calls" do
      Sage.configure do |config|
        config.provider :openai, api_key: "first"
      end

      Sage.configure do |config|
        config.provider :ollama, endpoint: "http://localhost:11434"
      end

      expect(Sage.configuration.providers.keys).to contain_exactly(:ollama)
      expect(Sage.configuration.providers[:openai]).to be_nil
    end
  end
end
