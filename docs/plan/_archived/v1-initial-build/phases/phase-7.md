# Phase 7: Rails Integration

> **Depends on:** Phase 6 (core gem must be fully functional)
> **Enables:** Phase 8 (Documentation)
>
> See: [Full Plan](../plan.md)

## Goal

Add optional Rails integration via a Railtie and an install generator, so Rails developers get a smooth setup experience.

## Key Deliverables

- `Sage::Railtie` that loads conditionally when Rails is present
- `rails generate sage:install` generator that scaffolds the initializer
- Generated initializer with commented examples for all providers and profiles

## Files to Create

- `lib/sage/railtie.rb` — Rails Railtie (conditional auto-loading)
- `lib/generators/sage/install_generator.rb` — install generator
- `lib/generators/sage/templates/initializer.rb.tt` — initializer template
- `spec/sage/railtie_spec.rb` — Railtie loading tests

## Files to Modify

- `lib/sage.rb` — add `require "sage/railtie" if defined?(Rails::Railtie)`

## Dependencies

**Internal:** Phase 6 (complete working gem)

**External:**
- `rails` (optional, not a runtime dependency) — Railtie and generator conventions

## Implementation Notes

### Railtie

```ruby
# lib/sage/railtie.rb
module Sage
  class Railtie < Rails::Railtie
    generators do
      require "generators/sage/install_generator"
    end
  end
end
```

The Railtie is minimal — sage-rb doesn't need Rails hooks for initialization (the user writes the initializer). Its main purpose is registering the generator.

### Conditional Loading

```ruby
# lib/sage.rb (at the bottom)
require "sage/railtie" if defined?(Rails::Railtie)
```

This ensures the Railtie is never loaded in non-Rails environments. Use `Rails::Railtie` (not `Rails`) for the check, as it's more precise.

### Install Generator

```bash
$ rails generate sage:install
    create  config/initializers/sage.rb
```

### Generated Initializer Template

```ruby
# config/initializers/sage.rb

Sage.configure do |config|
  # === Providers ===
  # Register your LLM providers with their credentials.
  # API keys should come from Rails credentials or environment variables.

  # config.provider :openai, api_key: Rails.application.credentials.dig(:openai, :api_key)
  # config.provider :anthropic, api_key: Rails.application.credentials.dig(:anthropic, :api_key)
  # config.provider :ollama, endpoint: "http://localhost:11434"

  # === Profiles ===
  # Profiles are named combinations of provider + model + parameters.
  # Use them to switch between models without changing application code.

  # config.profile :default, provider: :openai, model: "gpt-4o"
  # config.profile :fast, provider: :ollama, model: "hermes3"
  # config.profile :creative, provider: :anthropic, model: "claude-sonnet-4-5-20250929",
  #                temperature: 0.9

  # === Default Profile ===
  # config.default_profile :default
end
```

The template should be helpful but not overwhelming. All lines commented out so it doesn't error on first load.

## Validation

- [ ] `require "sage"` works without Rails (no error)
- [ ] `require "sage"` in a Rails app loads the Railtie
- [ ] `rails generate sage:install` creates `config/initializers/sage.rb`
- [ ] Generated initializer is valid Ruby (loads without error)
- [ ] Tests pass with `bundle exec rspec`
