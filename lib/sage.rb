# frozen_string_literal: true

require_relative "sage/version"
require_relative "sage/configuration"

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
  end
end

require_relative "sage/railtie" if defined?(Rails::Railtie)
