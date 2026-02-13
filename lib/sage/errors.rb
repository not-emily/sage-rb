# frozen_string_literal: true

module Sage
  class Error < StandardError; end
  class ProfileNotFound < Error; end
  class ProviderNotConfigured < Error; end
  class NoDefaultProfile < Error; end
  class ConnectionError < Error; end
  class AuthenticationError < Error; end
  class ProviderError < Error; end
end
