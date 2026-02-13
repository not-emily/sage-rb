# Claude Context - sage-rb

This file provides context for Claude Code sessions.

## Project Overview
sage-rb is a Ruby gem that provides a unified interface for calling multiple LLM providers (OpenAI, Anthropic, Ollama) from any Ruby application. It is a companion to [sage](https://github.com/pxp/sage), the Go CLI/library, sharing the same concepts (providers, profiles, complete) but implemented natively in Ruby.

## Tech Stack
- Ruby 3.0+ (stdlib only, no runtime dependencies)
- `net/http` for provider HTTP calls
- `json` for request/response parsing
- RSpec for testing

## Key Patterns & Conventions
- **No credential management** — the gem receives API keys as strings, never stores them
- **Block detection for streaming** — `Sage.complete` with block = streaming, without = blocking
- **Provider adapter pattern** — each provider is a class under `Sage::Providers::` implementing `complete` and `stream`
- **Configuration DSL** — `Sage.configure` with `config.provider`, `config.profile`, `config.default_profile`
- **Rails optional** — Railtie loads conditionally via `if defined?(Rails::Railtie)`

## Important Context
- This is a separate codebase from the sage Go project — they share concepts but no code
- Provider HTTP call logic is the only "duplicated" part between Go and Ruby
- The gem's security posture: never touch credentials, just pass them through to HTTP headers

## Project Structure
```
sage-rb/
├── lib/
│   ├── sage.rb                 # Entry point
│   └── sage/
│       ├── version.rb
│       ├── configuration.rb    # Sage.configure DSL
│       ├── profile.rb          # Profile data object
│       ├── client.rb           # Request dispatch (Phase 2)
│       ├── response.rb         # Response object (Phase 2)
│       ├── chunk.rb            # Streaming chunk (Phase 2)
│       ├── providers/
│       │   ├── base.rb         # Provider interface (Phase 2)
│       │   ├── openai.rb       # Phase 3
│       │   ├── anthropic.rb    # Phase 4
│       │   └── ollama.rb       # Phase 5
│       └── railtie.rb          # Rails integration (Phase 7)
├── spec/                       # RSpec tests
├── docs/plan/                  # Project plan and phases
├── sage-rb.gemspec
├── Gemfile
└── Rakefile
```

## Development
```bash
bundle exec rake          # Run tests
bundle exec rspec         # Run tests (direct)
gem build sage-rb.gemspec # Build gem
```
