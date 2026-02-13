# frozen_string_literal: true

module Sage
  class Client
    PROVIDERS = {}

    def self.register_provider(name, klass)
      PROVIDERS[name.to_sym] = klass
    end

    def initialize(configuration)
      @configuration = configuration
    end

    def complete(profile_name = nil, prompt:, system: nil, **params, &block)
      profile = resolve_profile(profile_name)
      provider = build_provider(profile)
      merged_params = profile.params.merge(params)

      if block
        provider.stream(model: profile.model, prompt: prompt, system: system, **merged_params, &block)
      else
        provider.complete(model: profile.model, prompt: prompt, system: system, **merged_params)
      end
    end

    private

    attr_reader :configuration

    def resolve_profile(name)
      name = name&.to_sym || configuration.default_profile

      raise NoDefaultProfile, "No default profile configured. Call Sage.configure { |c| c.default_profile :name }" if name.nil?

      profile = configuration.profiles[name]

      raise ProfileNotFound, "Profile '#{name}' is not configured" if profile.nil?

      profile
    end

    def build_provider(profile)
      provider_config = configuration.providers[profile.provider]

      raise ProviderNotConfigured, "Provider '#{profile.provider}' referenced by profile '#{profile.name}' is not configured" if provider_config.nil?

      provider_class = PROVIDERS[profile.provider]

      raise ProviderNotConfigured, "No provider adapter registered for '#{profile.provider}'" if provider_class.nil?

      provider_class.new(provider_config)
    end
  end
end
