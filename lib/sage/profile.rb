# frozen_string_literal: true

module Sage
  class Profile
    attr_reader :name, :provider, :model, :params

    def initialize(name:, provider:, model:, **params)
      @name = name.to_sym
      @provider = provider.to_sym
      @model = model.to_s
      @params = params
    end
  end
end
