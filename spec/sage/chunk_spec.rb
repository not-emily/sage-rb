# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sage::Chunk do
  it "holds content and done status" do
    chunk = Sage::Chunk.new(content: "Hello", done: false)

    expect(chunk.content).to eq("Hello")
    expect(chunk.done?).to be false
  end

  it "defaults done to false" do
    chunk = Sage::Chunk.new(content: "Hi")

    expect(chunk.done?).to be false
  end

  it "can be marked done" do
    chunk = Sage::Chunk.new(content: "", done: true)

    expect(chunk.done?).to be true
  end
end
