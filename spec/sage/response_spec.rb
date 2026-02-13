# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sage::Response do
  it "holds content, model, and usage" do
    response = Sage::Response.new(
      content: "Hello world",
      model: "gpt-4o",
      usage: { prompt_tokens: 10, completion_tokens: 5 }
    )

    expect(response.content).to eq("Hello world")
    expect(response.model).to eq("gpt-4o")
    expect(response.usage).to eq(prompt_tokens: 10, completion_tokens: 5)
  end

  it "defaults usage to empty hash" do
    response = Sage::Response.new(content: "Hi", model: "gpt-4o")

    expect(response.usage).to eq({})
  end
end
