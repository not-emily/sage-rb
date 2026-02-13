# Phase 3: OpenAI Provider

> **Depends on:** Phase 2
> **Enables:** Phase 6 (Profiles — needs at least one working provider)
>
> See: [Full Plan](../plan.md)

## Goal

Implement the OpenAI provider adapter with both blocking and streaming completion support.

## Key Deliverables

- `Sage::Providers::OpenAI` class implementing `complete` and `stream`
- SSE (Server-Sent Events) streaming parser for OpenAI's response format
- Model-specific parameter handling (`max_tokens` vs `max_completion_tokens`)
- Error handling for common HTTP status codes (401, 429, 500)
- Integration-style tests (can be run against real API with env var, skipped otherwise)

## Files to Create

- `lib/sage/providers/openai.rb` — OpenAI provider implementation
- `spec/sage/providers/openai_spec.rb` — unit tests with stubbed HTTP responses

## Dependencies

**Internal:** Phase 2 (Base provider class, Response/Chunk objects)

**External:**
- `net/http` (stdlib) — HTTP requests
- `json` (stdlib) — request/response parsing

## Implementation Notes

### Request Format

```ruby
# POST https://api.openai.com/v1/chat/completions
{
  model: "gpt-4o",
  messages: [
    { role: "system", content: system_prompt },
    { role: "user", content: prompt }
  ],
  max_tokens: 1024,       # older models
  max_completion_tokens: 1024,  # newer models (o1, o3, gpt-4o, gpt-5)
  stream: false           # or true for streaming
}
```

### Model-Specific Logic

Newer OpenAI models (o1, o3, gpt-4o, gpt-5 and later) use `max_completion_tokens` instead of `max_tokens`. The provider should detect the model name and use the correct parameter. Reference the sage Go implementation for the exact model detection logic.

### SSE Streaming

OpenAI streams responses as Server-Sent Events:
```
data: {"choices":[{"delta":{"content":"Hello"}}]}
data: {"choices":[{"delta":{"content":" world"}}]}
data: [DONE]
```

Read the response body line by line, parse lines starting with `data: `, skip `[DONE]`, yield `Sage::Chunk` objects.

### Error Handling

Map HTTP status codes to meaningful errors:
- 401 → authentication error (bad API key)
- 429 → rate limited
- 500+ → provider error

### Custom Base URL

Support `base_url` config option for OpenAI-compatible APIs (Azure, local proxies, etc.):
```ruby
config.provider :openai, api_key: "...", base_url: "https://my-proxy.example.com/v1"
```

## Validation

- [ ] Blocking completion returns a `Sage::Response` with content, model, and usage
- [ ] Streaming completion yields `Sage::Chunk` objects with content
- [ ] Final streaming chunk has `done? == true`
- [ ] System prompt is correctly placed in the messages array
- [ ] Model-specific parameter (`max_completion_tokens`) is used for newer models
- [ ] Custom `base_url` is respected
- [ ] Auth errors raise a clear exception
- [ ] Tests pass with `bundle exec rspec`
