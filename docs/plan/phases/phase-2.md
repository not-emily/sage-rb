# Phase 2: Provider Foundation

> **Depends on:** Phase 1
> **Enables:** Phases 3, 4, 5 (individual provider implementations)
>
> See: [Full Plan](../plan.md)

## Goal

Define the provider interface (base class), request/response data objects, and the client that dispatches requests to providers.

## Key Deliverables

- `Sage::Providers::Base` abstract class with `complete` and `stream` methods
- `Sage::Response` data object (content, model, usage)
- `Sage::Chunk` data object (content, done?)
- `Sage::Client` that resolves provider config and dispatches to provider adapters
- Provider registry so `Sage.complete` can look up the right provider class by name

## Files to Create

- `lib/sage/providers/base.rb` — abstract provider interface
- `lib/sage/response.rb` — normalized response object
- `lib/sage/chunk.rb` — streaming chunk object
- `lib/sage/client.rb` — request dispatch logic
- `lib/sage/profile.rb` — profile data object (if not created in Phase 1)
- `spec/sage/client_spec.rb` — client dispatch tests (with a mock provider)
- `spec/sage/response_spec.rb` — response object tests

## Dependencies

**Internal:** Phase 1 (configuration DSL must exist)

**External:** None

## Implementation Notes

### Provider Base Class

```ruby
module Sage
  module Providers
    class Base
      def initialize(config)
        # config is the hash from Sage.configure (api_key, endpoint, etc.)
      end

      def complete(model:, prompt:, system: nil, **params)
        raise NotImplementedError
      end

      def stream(model:, prompt:, system: nil, **params, &block)
        raise NotImplementedError
      end
    end
  end
end
```

### Provider Registry

A simple mapping from symbol to class:

```ruby
PROVIDERS = {
  openai: Sage::Providers::OpenAI,
  anthropic: Sage::Providers::Anthropic,
  ollama: Sage::Providers::Ollama,
}
```

This can live in `client.rb` or `providers/base.rb`. When `Sage.complete(:code_expert, ...)` is called, the client:
1. Looks up the profile → gets provider name + model
2. Looks up the provider config from configuration
3. Instantiates the provider class with the config
4. Calls `complete` or `stream` on it

### Response Object

Keep it simple — a data object with attribute readers, not an ActiveModel or anything heavy.

```ruby
Sage::Response.new(content: "...", model: "gpt-4o", usage: { prompt_tokens: 10, completion_tokens: 50 })
```

## Validation

- [ ] `Sage::Providers::Base` defines the interface with `NotImplementedError`
- [ ] `Sage::Response` and `Sage::Chunk` hold their data correctly
- [ ] `Sage::Client` can resolve a provider from configuration
- [ ] A mock provider (subclass of Base) can be wired through the full flow
- [ ] Tests pass with `bundle exec rspec`
