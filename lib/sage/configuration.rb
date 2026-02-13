# frozen_string_literal: true

require_relative "profile"

module Sage
  class Configuration
    attr_reader :providers, :profiles

    def initialize
      @providers = {}
      @profiles = {}
      @default_profile_name = nil
    end

    def provider(name, **options)
      @providers[name.to_sym] = options
    end

    def profile(name, provider:, model:, **params)
      @profiles[name.to_sym] = Profile.new(name: name, provider: provider, model: model, **params)
    end

    def default_profile(name = nil)
      if name.nil?
        @default_profile_name
      else
        @default_profile_name = name.to_sym
      end
    end
  end
end
