# frozen_string_literal: true

require "sage"

RSpec.configure do |config|
  config.after do
    Sage.instance_variable_set(:@configuration, nil)
  end
end
