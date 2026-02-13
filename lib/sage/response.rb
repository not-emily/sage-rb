# frozen_string_literal: true

module Sage
  class Response
    attr_reader :content, :model, :usage

    def initialize(content:, model:, usage: {})
      @content = content
      @model = model
      @usage = usage
    end
  end
end
