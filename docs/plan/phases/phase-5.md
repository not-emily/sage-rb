# Phase 5: Ollama Provider

> **Depends on:** Phase 2
> **Enables:** Subsequent phases (parallel with Phase 3 and 4)
>
> See: [Full Plan](../plan.md)

## Goal

Implement the Ollama provider adapter with both blocking and streaming completion support for local model inference.

## Key Deliverables

- `Sage::Providers::Ollama` class implementing `complete` and `stream`
- JSON-line streaming parser for Ollama's response format
- Optional authentication support (API key not required for local deployments)
- Connection error handling with helpful messages (e.g., "Is Ollama running?")

## Files to Create

- `lib/sage/providers/ollama.rb` — Ollama provider implementation
- `spec/sage/providers/ollama_spec.rb` — unit tests with stubbed HTTP responses

## Dependencies

**Internal:** Phase 2 (Base provider class, Response/Chunk objects)

**External:**
- `net/http` (stdlib) — HTTP requests
- `json` (stdlib) — request/response parsing

## Implementation Notes

### Request Format

```ruby
# POST http://localhost:11434/api/chat
{
  model: "hermes3",
  messages: [
    { role: "system", content: system_prompt },
    { role: "user", content: prompt }
  ],
  stream: false   # or true
}
```

### Key Differences from Cloud Providers

- **Default endpoint:** `http://localhost:11434` (not HTTPS)
- **No auth required** by default (local deployment). API key is optional.
- **Configurable endpoint:** Users may run Ollama on a different host/port

### Streaming Format

Ollama streams newline-delimited JSON (not SSE):
```
{"message":{"content":"Hello"},"done":false}
{"message":{"content":" world"},"done":false}
{"message":{"content":""},"done":true}
```

Read response body line by line, parse each line as JSON, yield `Sage::Chunk`. The `done` field indicates the final chunk.

### Connection Error Handling

Since Ollama runs locally, connection refused is a common error (Ollama isn't running). Catch `Errno::ECONNREFUSED` and raise a clear error:

```ruby
rescue Errno::ECONNREFUSED
  raise Sage::ConnectionError, "Could not connect to Ollama at #{endpoint}. Is Ollama running?"
```

### Usage Extraction

Ollama returns usage in the final response:
```json
{
  "prompt_eval_count": 12,
  "eval_count": 85
}
```

Map to `prompt_tokens`/`completion_tokens` for the normalized response.

## Validation

- [ ] Blocking completion returns a `Sage::Response` with content, model, and usage
- [ ] Streaming completion yields `Sage::Chunk` objects
- [ ] Works without an API key (local Ollama)
- [ ] Works with a custom endpoint
- [ ] Connection refused raises a helpful error message
- [ ] Usage tokens are normalized correctly
- [ ] Tests pass with `bundle exec rspec`
