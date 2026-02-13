# Phase 4: Anthropic Provider

> **Depends on:** Phase 2
> **Enables:** Subsequent phases (parallel with Phase 3 and 5)
>
> See: [Full Plan](../plan.md)

## Goal

Implement the Anthropic provider adapter with both blocking and streaming completion support.

## Key Deliverables

- `Sage::Providers::Anthropic` class implementing `complete` and `stream`
- Anthropic-specific SSE streaming parser (event-based with `content_block_delta`)
- Anthropic-specific request formatting (system as separate field, not in messages)
- Default `max_tokens` enforcement (Anthropic requires this field)
- Error handling for common HTTP status codes

## Files to Create

- `lib/sage/providers/anthropic.rb` — Anthropic provider implementation
- `spec/sage/providers/anthropic_spec.rb` — unit tests with stubbed HTTP responses

## Dependencies

**Internal:** Phase 2 (Base provider class, Response/Chunk objects)

**External:**
- `net/http` (stdlib) — HTTP requests
- `json` (stdlib) — request/response parsing

## Implementation Notes

### Request Format

Anthropic's API differs from OpenAI in key ways:

```ruby
# POST https://api.anthropic.com/v1/messages
# Headers: x-api-key, anthropic-version

{
  model: "claude-sonnet-4-5-20250929",
  system: "You are a teacher",          # separate field, NOT in messages
  messages: [
    { role: "user", content: "explain recursion" }
  ],
  max_tokens: 1024,                     # required by Anthropic
  stream: false
}
```

Key differences from OpenAI:
- System prompt is a top-level field, not a message with role "system"
- Auth header is `x-api-key`, not `Authorization: Bearer`
- Requires `anthropic-version` header
- `max_tokens` is required (default to 1024 if not specified)

### Streaming Format

Anthropic uses an event-based SSE format:
```
event: content_block_delta
data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}

event: message_stop
data: {"type":"message_stop"}
```

Parse the `event:` line to determine type, then parse the corresponding `data:` line. Yield `Sage::Chunk` for `content_block_delta` events, mark done on `message_stop`.

### Usage Extraction

Anthropic returns usage in the final message:
```json
{
  "usage": {
    "input_tokens": 12,
    "output_tokens": 85
  }
}
```

Map `input_tokens` → `prompt_tokens` and `output_tokens` → `completion_tokens` to match the normalized `Sage::Response` format.

## Validation

- [ ] Blocking completion returns a `Sage::Response` with content, model, and usage
- [ ] Streaming completion yields `Sage::Chunk` objects
- [ ] System prompt is sent as a separate field (not in messages)
- [ ] `max_tokens` defaults to 1024 when not specified
- [ ] Auth uses `x-api-key` header with `anthropic-version`
- [ ] Usage tokens are normalized to `prompt_tokens`/`completion_tokens`
- [ ] Tests pass with `bundle exec rspec`
