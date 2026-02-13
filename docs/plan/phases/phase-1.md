# Phase 1: Project Scaffold

> **Depends on:** None
> **Enables:** All subsequent phases
>
> See: [Full Plan](../plan.md)

## Goal

Set up the gem structure, gemspec, and configuration DSL so that `Sage.configure` works and the gem is loadable.

## Key Deliverables

- Gem directory structure matching the plan
- Valid gemspec with metadata (name, version, authors, Ruby version requirement)
- `Sage.configure` block DSL for registering providers and setting defaults
- `Sage::Configuration` class that stores provider configs and profile definitions
- Basic test setup with RSpec
- Gemfile with development dependencies only (rspec, rubocop)

## Files to Create

- `sage-rb.gemspec` — gem metadata, Ruby 3.0+ requirement, no runtime dependencies
- `Gemfile` — development dependencies (rspec, rake)
- `lib/sage.rb` — entry point, `Sage.configure` and `Sage.configuration`
- `lib/sage/configuration.rb` — configuration DSL (provider registration, profile definition, default_profile)
- `lib/sage/version.rb` — version constant
- `spec/spec_helper.rb` — RSpec setup
- `spec/sage/configuration_spec.rb` — tests for the configuration DSL
- `Rakefile` — default task runs specs

## Dependencies

**Internal:** None — this is the foundation.

**External:** None at runtime. Development only:
- `rspec` — testing
- `rake` — task runner

## Implementation Notes

The configuration DSL should support:

```ruby
Sage.configure do |config|
  config.provider :openai, api_key: "sk-..."
  config.provider :ollama, endpoint: "http://localhost:11434"
  config.profile :fast, provider: :ollama, model: "hermes3"
  config.default_profile :fast
end
```

At this phase, `config.provider` just stores the options hash keyed by provider name. It doesn't validate that the provider exists yet — that happens in Phase 2 when provider classes are introduced.

`config.profile` stores a `Sage::Profile` struct (or simple data object) with name, provider, model, and extra params.

`Sage.configure` should be callable multiple times (last write wins) and `Sage.configuration` should return the current config.

## Validation

- [ ] `bundle exec rake` runs and passes
- [ ] `require "sage"` works without error
- [ ] `Sage.configure` accepts providers and profiles
- [ ] `Sage.configuration` returns stored providers and profiles
- [ ] gemspec is valid (`gem build sage-rb.gemspec` succeeds)
