# Phase 6: Profiles

> **Depends on:** Phase 3 (needs at least one working provider)
> **Enables:** Phase 7 (Rails integration), Phase 8 (Documentation)
>
> See: [Full Plan](../plan.md)

## Goal

Wire up the profile system so that `Sage.complete(:profile_name, ...)` resolves the profile, dispatches to the correct provider with the configured model and default parameters, and supports a default profile.

## Key Deliverables

- `Sage.complete` top-level method that accepts a profile name (or uses default)
- Profile resolution: name → provider + model + default params
- Per-call parameter overrides (e.g., override temperature for a single call)
- Default profile fallback when no profile name is given
- Clear error messages for missing profiles and unconfigured providers

## Files to Create

- `spec/sage/profile_spec.rb` — profile resolution tests
- `spec/sage/integration_spec.rb` — end-to-end tests with mock providers

## Files to Modify

- `lib/sage.rb` — add `Sage.complete` class method
- `lib/sage/client.rb` — add profile resolution and parameter merging
- `lib/sage/profile.rb` — finalize profile data object (if needed)

## Dependencies

**Internal:** Phase 3 (at least one provider must work for end-to-end validation)

**External:** None

## Implementation Notes

### Sage.complete Flow

```ruby
Sage.complete(:code_expert, prompt: "hello", temperature: 0.5) do |chunk|
  print chunk.content
end
```

1. Look up profile `:code_expert` from configuration
2. Profile says: provider `:openai`, model `"gpt-5-codex"`, default params `{ temperature: 0.2, max_tokens: 4096 }`
3. Per-call params (`temperature: 0.5`) override profile defaults
4. Look up provider `:openai` config from configuration (api_key, base_url, etc.)
5. Instantiate `Sage::Providers::OpenAI` with provider config
6. Block given? → call `provider.stream(...)` yielding chunks
7. No block? → call `provider.complete(...)` returning response

### Default Profile

```ruby
# Profile name omitted — use default
Sage.complete(prompt: "hello")

# Equivalent to:
Sage.complete(Sage.configuration.default_profile, prompt: "hello")
```

The first argument is the profile name if it's a Symbol, otherwise it's treated as a keyword argument and the default profile is used.

### Error Cases

- Profile not found: `Sage::ProfileNotFound, "Profile ':unknown' is not configured"`
- Provider not configured: `Sage::ProviderNotConfigured, "Provider ':openai' referenced by profile ':code_expert' is not configured"`
- No default profile set and no profile name given: `Sage::NoDefaultProfile, "No default profile configured. Call Sage.configure { |c| c.default_profile :name }"`

### Custom Error Classes

Define a simple error hierarchy:

```ruby
module Sage
  class Error < StandardError; end
  class ProfileNotFound < Error; end
  class ProviderNotConfigured < Error; end
  class NoDefaultProfile < Error; end
  class ConnectionError < Error; end
  class AuthenticationError < Error; end
  class ProviderError < Error; end
end
```

These may be created in an earlier phase if needed by providers (e.g., `AuthenticationError` in Phase 3). Finalize the full set here.

## Validation

- [ ] `Sage.complete(:profile_name, prompt: "...")` works end-to-end
- [ ] `Sage.complete(prompt: "...")` uses the default profile
- [ ] Per-call params override profile defaults
- [ ] Missing profile raises `ProfileNotFound`
- [ ] Unconfigured provider raises `ProviderNotConfigured`
- [ ] No default profile raises `NoDefaultProfile`
- [ ] Streaming (block) and blocking (no block) both work through profiles
- [ ] Tests pass with `bundle exec rspec`
