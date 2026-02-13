# frozen_string_literal: true

require_relative "lib/sage/version"

Gem::Specification.new do |spec|
  spec.name = "sage-rb"
  spec.version = Sage::VERSION
  spec.authors = ["Emily"]
  spec.summary = "Unified LLM adapter for Ruby"
  spec.description = "A lightweight, provider-agnostic interface for calling LLM APIs (OpenAI, Anthropic, Ollama) from any Ruby application."
  spec.homepage = "https://github.com/pxp/sage-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
end
