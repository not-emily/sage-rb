# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sage::Providers::Base do
  let(:provider) { Sage::Providers::Base.new(api_key: "test") }

  it "raises NotImplementedError for complete" do
    expect { provider.complete(model: "test", prompt: "hello") }.to raise_error(NotImplementedError)
  end

  it "raises NotImplementedError for stream" do
    expect { provider.stream(model: "test", prompt: "hello") }.to raise_error(NotImplementedError)
  end
end
