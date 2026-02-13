# frozen_string_literal: true

module Sage
  module Providers
    class Base
      def initialize(config)
        @config = config
      end

      def complete(model:, prompt:, system: nil, **params)
        raise NotImplementedError, "#{self.class}#complete is not implemented"
      end

      def stream(model:, prompt:, system: nil, **params, &block)
        raise NotImplementedError, "#{self.class}#stream is not implemented"
      end

      private

      attr_reader :config
    end
  end
end
