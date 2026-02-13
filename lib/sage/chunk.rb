# frozen_string_literal: true

module Sage
  class Chunk
    attr_reader :content

    def initialize(content:, done: false)
      @content = content
      @done = done
    end

    def done?
      @done
    end
  end
end
