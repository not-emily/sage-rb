# frozen_string_literal: true

module Sage
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    desc "Creates a sage-rb initializer at config/initializers/sage.rb"

    def create_initializer
      template "initializer.rb.tt", "config/initializers/sage.rb"
    end
  end
end
