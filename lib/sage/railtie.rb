# frozen_string_literal: true

module Sage
  class Railtie < Rails::Railtie
    generators do
      require "generators/sage/install_generator"
    end
  end
end
