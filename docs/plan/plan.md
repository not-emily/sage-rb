# sage-rb: Unified LLM Adapter for Ruby

> **Status:** Planning complete | Last updated: 2026-02-13
>
> Phase files: [phases/](phases/)

## Overview

sage-rb is a Ruby gem that provides a unified interface for calling multiple LLM providers (OpenAI, Anthropic, Ollama) from any Ruby application. It is a companion to [sage](https://github.com/pxp/sage), the Go CLI and library that serves the same purpose for Go and command-line users.

sage-rb shares the same core concepts as sage — providers, profiles, and complete — but implements them natively in Ruby with idiomatic configuration. It does not depend on or wrap the sage Go binary. Instead, it makes HTTP calls directly to provider APIs using Ruby's stdlib.

The gem is designed to feel natural in Rails (initializer-based config, Rails credentials for API keys) while working in any Ruby environment (plain scripts, Sinatra, background workers) using ENV vars or direct configuration.

## Core Vision

- **Rails-native, Ruby-first**: Feels like a first-class Rails gem, but works anywhere Ruby runs. Configuration follows the conventions of each environment.
- **Lightweight**: Just the adapter layer. No credential storage, no encryption, no CLI. The gem receives API keys as strings and makes HTTP calls. Nothing more.
- **Provider-agnostic**: One interface regardless of backend. Switch from OpenAI to Ollama by changing a profile, not your application code.
- **Consistent with sage**: Same concepts (providers, profiles, complete), same mental model. A developer who uses the sage CLI should immediately understand sage-rb, and vice versa.

## Requirements

### Must Have
- Provider adapters for OpenAI, Anthropic, and Ollama
- Profiles: named bundles of provider + model + default parameters
- `Sage.complete` for blocking completion (returns full response)
- `Sage.complete` with block for streaming completion (yields chunks)
- `Sage.configure` DSL for providers, profiles, and defaults
- Normalized response objects (consistent shape across providers)
- Default profile support

### Nice to Have
- Rails generator (`rails generate sage:install`) to scaffold the initializer
- Per-call parameter overrides (temperature, max_tokens)
- Additional providers (Gemini, Mistral)

### Out of Scope
- Credential storage or encryption — delegated to the host environment (Rails credentials, ENV vars)
- CLI tooling — that's what sage (Go) is for
- Conversation history / multi-turn management — application-level concern
- Function calling / tool use — future consideration
- Embeddings / vision — future consideration
- Retry logic / rate limiting — application-level concern
- Hosting or running as a service — sage-rb is a library, not a server

## Constraints

- **stdlib only** — no third-party dependencies (`net/http`, `json`, `openssl` only). Mirrors sage's Go stdlib-only philosophy.
- **Ruby 3.0+** — reasonable baseline for modern Ruby features
- **No native extensions** — pure Ruby for maximum portability
- **Separate repo** — lives at `sage-rb/`, independent of the sage Go repo

## Success Metrics

- **Setup time**: `bundle add sage-rb`, configure, call `Sage.complete` — working in under 5 minutes
- **Zero external requirements**: No binary install, no service, no database
- **Streaming works out of the box**: Block form of `Sage.complete` streams chunks in real-time
- **Rails and non-Rails**: Works identically in both contexts, differing only in how credentials are provided

## Architecture Decisions

### 1. stdlib Only — No Third-Party Dependencies
**Choice:** Use only Ruby stdlib (`net/http`, `json`, `openssl`)
**Rationale:** Matches sage's Go philosophy. Provider HTTP calls are straightforward REST requests that don't need a heavy HTTP library. Fewer dependencies = fewer supply chain risks and version conflicts.
**Trade-offs:** Slightly more verbose HTTP code than using Faraday. Acceptable for the small number of providers.

### 2. Separate Repo, Parallel Implementation
**Choice:** sage-rb is a new repo with its own Ruby implementation of provider logic, not a wrapper around the Go binary.
**Rationale:** Wrapping the binary would require Rails developers to install Go or bundle a binary, which isn't natural for the ecosystem. The provider HTTP calls are simple enough (~150-250 lines per provider) that parallel implementation is less maintenance burden than FFI or subprocess wrappers.
**Trade-offs:** Provider logic exists in both Go and Ruby. Adding a new provider means updating both repos. Mitigated by documenting shared provider contracts and having consistent test suites.

### 3. No Credential Management
**Choice:** The gem never stores, encrypts, or manages credentials. It receives API keys as strings.
**Rationale:** Every Ruby environment already has a secure credential solution (Rails credentials, ENV vars, Vault, etc.). Implementing another one adds complexity and attack surface for zero benefit. The gem's security posture is strong precisely because it never touches credentials.
**Trade-offs:** None meaningful. This is strictly simpler and more secure.

### 4. Ruby-First with Optional Rails Extras
**Choice:** Core gem works in any Ruby environment. Rails integration (Railtie, generators) loads conditionally when Rails is detected.
**Rationale:** One `if defined?(Rails)` check is the only cost. Rails developers get auto-loading and generators for free. Non-Rails users aren't burdened with Rails dependencies.
**Trade-offs:** Negligible complexity increase for significantly wider audience.

### 5. Block Detection for Streaming
**Choice:** `Sage.complete` with a block streams (yields chunks); without a block it blocks and returns the full response.
**Rationale:** Maps directly to the sage CLI mental model (streaming by default, `--json` for full response). Also follows established Ruby patterns (`File.open` with/without block). Keeps the API surface minimal — one method, two behaviors.
**Trade-offs:** Implicit behavior based on block presence. Mitigated by clear documentation and the fact that this is a well-known Ruby pattern.

## Project Structure

```
sage-rb/
├── lib/
│   ├── sage.rb                 # Entry point, Sage.configure/complete
│   └── sage/
│       ├── configuration.rb    # Configure DSL (providers, profiles, defaults)
│       ├── client.rb           # Request routing, provider dispatch
│       ├── profile.rb          # Profile data object
│       ├── response.rb         # Normalized response object
│       ├── chunk.rb            # Streaming chunk object
│       ├── providers/
│       │   ├── base.rb         # Common provider interface
│       │   ├── openai.rb       # OpenAI adapter
│       │   ├── anthropic.rb    # Anthropic adapter
│       │   └── ollama.rb       # Ollama adapter
│       └── railtie.rb          # Rails integration (conditional)
├── spec/                       # RSpec tests
├── sage-rb.gemspec
├── Gemfile
└── README.md
```

### Key Files
- `lib/sage.rb` — Entry point. Defines `Sage.configure` and `Sage.complete`. Conditionally requires `railtie.rb`.
- `lib/sage/configuration.rb` — The DSL for `Sage.configure`: registering providers, defining profiles, setting defaults.
- `lib/sage/client.rb` — Resolves a profile to a provider, builds the request, dispatches to the provider adapter.
- `lib/sage/providers/base.rb` — Abstract base class defining the provider interface (`complete`, `stream`).

## Core Interfaces

### Configuration DSL

```ruby
Sage.configure do |config|
  # Register providers with credentials
  config.provider :openai, api_key: ENV["OPENAI_API_KEY"]
  config.provider :anthropic, api_key: ENV["ANTHROPIC_API_KEY"]
  config.provider :ollama, endpoint: "http://localhost:11434"

  # Define profiles (named provider + model + params)
  config.profile :small_brain, provider: :ollama, model: "hermes3"
  config.profile :code_expert, provider: :openai, model: "gpt-5-codex",
                 temperature: 0.2, max_tokens: 4096
  config.profile :creative, provider: :anthropic, model: "claude-sonnet-4-5-20250929",
                 temperature: 0.9

  # Set default profile
  config.default_profile :small_brain
end
```

### Completion API

```ruby
# Blocking — returns Response
response = Sage.complete(:code_expert, prompt: "explain recursion", system: "You are a teacher")
response.content       # => "Recursion is..."
response.model         # => "gpt-5-codex"
response.usage         # => { prompt_tokens: 12, completion_tokens: 85 }

# Streaming — yields Chunks
Sage.complete(:code_expert, prompt: "explain recursion") do |chunk|
  print chunk.content  # prints as it arrives
end

# Default profile
Sage.complete(prompt: "hello")  # uses :small_brain
```

### Provider Interface

```ruby
module Sage
  module Providers
    class Base
      def complete(request)
        # Returns Sage::Response
        raise NotImplementedError
      end

      def stream(request, &block)
        # Yields Sage::Chunk objects
        raise NotImplementedError
      end
    end
  end
end
```

### Data Objects

```ruby
Sage::Response
  #content        => String
  #model          => String
  #usage          => Hash { prompt_tokens:, completion_tokens: }

Sage::Chunk
  #content        => String
  #done?          => Boolean

Sage::Profile
  #name           => Symbol
  #provider       => Symbol
  #model          => String
  #params         => Hash (temperature, max_tokens, etc.)
```

## Implementation Phases

| Phase | Name | Scope | Depends On | Key Outputs |
|-------|------|-------|------------|-------------|
| 1 | Project scaffold | Gem structure, gemspec, configuration DSL | — | Loadable gem with `Sage.configure` |
| 2 | Provider foundation | Base provider, request/response objects | Phase 1 | Provider interface, data objects |
| 3 | OpenAI provider | Complete + streaming for OpenAI | Phase 2 | Working OpenAI calls |
| 4 | Anthropic provider | Complete + streaming for Anthropic | Phase 2 | Working Anthropic calls |
| 5 | Ollama provider | Complete + streaming for Ollama | Phase 2 | Working Ollama calls |
| 6 | Profiles | Profile DSL, default profile, routing | Phase 3 | `Sage.complete(:profile_name)` works |
| 7 | Rails integration | Railtie, generator | Phase 6 | `rails generate sage:install` |
| 8 | Documentation | README, quickstart guides | Phase 7 | Publish-ready docs |

### Critical Path
Phases 1→2→3→6 is the minimum for a usable gem (configure + complete with OpenAI via profiles). Phases 4 and 5 (Anthropic and Ollama) can be built in parallel after Phase 2. Phases 7 and 8 are sequential at the end.

### Phase Details
- [Phase 1: Project Scaffold](phases/phase-1.md)
- [Phase 2: Provider Foundation](phases/phase-2.md)
- [Phase 3: OpenAI Provider](phases/phase-3.md)
- [Phase 4: Anthropic Provider](phases/phase-4.md)
- [Phase 5: Ollama Provider](phases/phase-5.md)
- [Phase 6: Profiles](phases/phase-6.md)
- [Phase 7: Rails Integration](phases/phase-7.md)
- [Phase 8: Documentation](phases/phase-8.md)

## Tech Stack

| Category | Choice | Notes |
|----------|--------|-------|
| Language | Ruby 3.0+ | Modern Ruby baseline |
| HTTP | net/http (stdlib) | No third-party dependencies |
| JSON | json (stdlib) | Standard Ruby JSON library |
| Testing | RSpec | Ruby testing standard |
| Linting | RuboCop (optional) | Code style consistency |

## Future Considerations

Items explicitly deferred from scope but architecturally supported:

- **Additional providers** (Gemini, Mistral) — provider adapter pattern makes this straightforward
- **Function calling / tool use** — would extend the request/response objects
- **Embeddings** — new method on providers, same pattern
- **Vision / multimodal** — extends request to include images
- **Retry logic / rate limiting** — could be added as middleware or configuration options
- **Conversation history** — application concern, but could offer a convenience wrapper
- **sage-py, sage-go** — same naming convention, same concepts, language-native implementations
