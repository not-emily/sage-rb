# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sage::Profile do
  it "stores name, provider, model, and params" do
    profile = Sage::Profile.new(name: :creative, provider: :openai, model: "gpt-4o", temperature: 0.9, max_tokens: 4096)

    expect(profile.name).to eq(:creative)
    expect(profile.provider).to eq(:openai)
    expect(profile.model).to eq("gpt-4o")
    expect(profile.params).to eq(temperature: 0.9, max_tokens: 4096)
  end

  it "converts name and provider to symbols" do
    profile = Sage::Profile.new(name: "test", provider: "anthropic", model: "claude-sonnet-4-5-20250929")

    expect(profile.name).to eq(:test)
    expect(profile.provider).to eq(:anthropic)
  end

  it "converts model to string" do
    profile = Sage::Profile.new(name: :test, provider: :ollama, model: :hermes3)

    expect(profile.model).to eq("hermes3")
  end

  it "defaults params to empty hash" do
    profile = Sage::Profile.new(name: :basic, provider: :ollama, model: "hermes3")

    expect(profile.params).to eq({})
  end
end
