# frozen_string_literal: true

require_relative "sage/version"
require_relative "sage/errors"
require_relative "sage/configuration"
require_relative "sage/response"
require_relative "sage/chunk"
require_relative "sage/providers/base"
require_relative "sage/providers/openai"
require_relative "sage/providers/anthropic"
require_relative "sage/client"

module Sage
  class << self
    def configure
      @configuration = Configuration.new
      yield(@configuration)
      @configuration
    end

    def configuration
      @configuration
    end

    def complete(profile_name = nil, **params, &block)
      client = Client.new(configuration)
      client.complete(profile_name, **params, &block)
    end
  end
end

Sage::Client.register_provider(:openai, Sage::Providers::OpenAI)
Sage::Client.register_provider(:anthropic, Sage::Providers::Anthropic)

require_relative "sage/railtie" if defined?(Rails::Railtie)
