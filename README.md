# sage-rb

A lightweight, provider-agnostic Ruby gem for calling LLM APIs. One interface for OpenAI, Anthropic, and Ollama — with profiles to switch between models without changing your code.

## Installation

Add to your Gemfile:

```ruby
gem "sage-rb"
```

Or install directly:

```bash
gem install sage-rb
```

## Quick Start (Rails)

Generate the initializer:

```bash
rails generate sage:install
```

Edit `config/initializers/sage.rb`:

```ruby
Sage.configure do |config|
  config.provider :openai, api_key: Rails.application.credentials.dig(:openai, :api_key)

  config.profile :default, provider: :openai, model: "gpt-4o"
  config.default_profile :default
end
```

Use it anywhere in your app:

```ruby
response = Sage.complete(prompt: "Summarize this article")
response.content  # => "The article discusses..."
```

## Quick Start (Ruby)

```ruby
require "sage"

Sage.configure do |config|
  config.provider :openai, api_key: ENV["OPENAI_API_KEY"]

  config.profile :default, provider: :openai, model: "gpt-4o"
  config.default_profile :default
end

response = Sage.complete(prompt: "Hello!")
puts response.content
```

## Configuration

### Providers

Register providers with their credentials. sage-rb never stores credentials — it receives API keys as strings and passes them to the provider API.

```ruby
Sage.configure do |config|
  # OpenAI (or any OpenAI-compatible API)
  config.provider :openai,
    api_key: ENV["OPENAI_API_KEY"],
    base_url: "https://api.openai.com/v1"  # optional, this is the default

  # Anthropic
  config.provider :anthropic,
    api_key: ENV["ANTHROPIC_API_KEY"]

  # Ollama (local, no API key required)
  config.provider :ollama,
    endpoint: "http://localhost:11434"  # optional, this is the default

  # Ollama with authentication (remote deployment)
  config.provider :ollama,
    endpoint: "https://ollama.example.com",
    api_key: ENV["OLLAMA_API_KEY"]
end
```

### Profiles

Profiles are named combinations of provider + model + default parameters. Define them once, use them everywhere.

```ruby
Sage.configure do |config|
  config.provider :openai, api_key: ENV["OPENAI_API_KEY"]
  config.provider :ollama, endpoint: "http://localhost:11434"

  config.profile :small_brain, provider: :ollama, model: "hermes3"
  config.profile :code_expert, provider: :openai, model: "gpt-4o",
                 temperature: 0.2, max_tokens: 4096
  config.profile :creative,    provider: :openai, model: "gpt-4o",
                 temperature: 0.9

  config.default_profile :small_brain
end
```

Use different profiles for different tasks:

```ruby
Sage.complete(:code_expert, prompt: "Review this function")
Sage.complete(:creative, prompt: "Write a haiku about Ruby")
Sage.complete(prompt: "Hello")  # uses default profile (:small_brain)
```

### Environment-based defaults

```ruby
config.default_profile Rails.env.production? ? :code_expert : :small_brain
```

## Usage

### Blocking completion

Returns a `Sage::Response` with the full response:

```ruby
response = Sage.complete(:code_expert, prompt: "Explain recursion", system: "You are a teacher")

response.content       # => "Recursion is when a function calls itself..."
response.model         # => "gpt-4o"
response.usage         # => { prompt_tokens: 15, completion_tokens: 42 }
```

### Streaming completion

Pass a block to stream chunks as they arrive:

```ruby
Sage.complete(:code_expert, prompt: "Explain recursion") do |chunk|
  if chunk.done?
    puts "\n[Done]"
  else
    print chunk.content
  end
end
```

### Per-call parameter overrides

Override profile defaults for a single call:

```ruby
# Profile has temperature: 0.2, but this call uses 0.9
Sage.complete(:code_expert, prompt: "Be creative", temperature: 0.9)
```

### System prompts

```ruby
Sage.complete(:default,
  prompt: "What is 2+2?",
  system: "You are a math tutor. Show your work."
)
```

## Providers Reference

| Provider | Config key | Required fields | Optional fields |
|----------|-----------|----------------|-----------------|
| OpenAI | `:openai` | `api_key` | `base_url` |
| Anthropic | `:anthropic` | `api_key` | `base_url` |
| Ollama | `:ollama` | — | `endpoint`, `api_key` |

### Provider notes

**OpenAI** — Newer models (o1, o3, gpt-4o, gpt-5) automatically use `max_completion_tokens` instead of `max_tokens`. The `base_url` option supports OpenAI-compatible APIs (Azure, local proxies).

**Anthropic** — System prompts are sent as a separate field (not in the messages array), matching the Anthropic API spec. `max_tokens` defaults to 1024 if not specified (Anthropic requires this field).

**Ollama** — Runs locally by default at `http://localhost:11434`. API key is optional — only needed for authenticated remote deployments.

## Error Handling

```ruby
begin
  Sage.complete(prompt: "Hello")
rescue Sage::AuthenticationError => e
  # Invalid API key (401)
rescue Sage::ProviderError => e
  # Rate limited (429), server error (500), or other provider issues
rescue Sage::ConnectionError => e
  # Could not connect (e.g., Ollama not running)
rescue Sage::ProfileNotFound => e
  # Referenced a profile that doesn't exist
rescue Sage::ProviderNotConfigured => e
  # Profile references a provider that isn't configured
rescue Sage::NoDefaultProfile => e
  # Called Sage.complete without a profile name and no default is set
rescue Sage::Error => e
  # Catch-all for any sage-rb error
end
```

## Response Objects

### Sage::Response

Returned by blocking `Sage.complete` calls.

```ruby
response.content       # String — the generated text
response.model         # String — the model that generated it
response.usage         # Hash — { prompt_tokens: Integer, completion_tokens: Integer }
```

### Sage::Chunk

Yielded during streaming `Sage.complete` calls.

```ruby
chunk.content          # String — text fragment
chunk.done?            # Boolean — true for the final chunk
```

## Relationship to sage

sage-rb is a companion to [sage](https://github.com/not-emily/sage), the Go CLI and library. They share the same core concepts:

| Concept | sage (Go CLI) | sage-rb (Ruby gem) |
|---------|--------------|-------------------|
| **Providers** | Configured via `sage provider add` | Configured in initializer |
| **Profiles** | Configured via `sage profile add` | Configured in initializer |
| **Complete** | `sage complete --profile name` | `Sage.complete(:name, ...)` |
| **Credentials** | Encrypted in `~/.config/sage/` | From ENV vars or Rails credentials |
| **Streaming** | Default behavior | Pass a block to `Sage.complete` |

Both make HTTP calls directly to provider APIs. They are independent implementations — sage-rb does not require or wrap the sage Go binary.

## License

MIT
