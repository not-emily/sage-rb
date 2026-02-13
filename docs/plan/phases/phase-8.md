# Phase 8: Documentation

> **Depends on:** Phase 7 (all features complete)
> **Enables:** Publication and adoption
>
> See: [Full Plan](../plan.md)

## Goal

Write clear, complete documentation that gets developers from install to working code in under 5 minutes.

## Key Deliverables

- README.md with quickstart, full API reference, and examples
- Rails-specific setup guide (credentials, initializer, generator)
- Plain Ruby setup guide (ENV vars, script usage)
- Provider reference (supported providers, their options, quirks)
- Profile examples and patterns
- Streaming examples

## Files to Create

- `README.md` — primary documentation (quickstart + full reference)

## Dependencies

**Internal:** All previous phases (need complete, working gem to document accurately)

**External:** None

## Implementation Notes

### README Structure

1. **Overview** — what sage-rb is, one paragraph
2. **Installation** — `gem install sage-rb` / Gemfile
3. **Quick Start (Rails)** — generator, credentials, first call (under 2 minutes)
4. **Quick Start (Ruby)** — ENV vars, configure, first call
5. **Configuration**
   - Providers (OpenAI, Anthropic, Ollama with all options)
   - Profiles (definition, defaults, parameter overrides)
6. **Usage**
   - Blocking completion
   - Streaming completion
   - Using profiles
   - Per-call overrides
7. **Providers Reference** — table of providers, required fields, optional fields
8. **Error Handling** — error classes and what causes them
9. **Relationship to sage** — how sage-rb relates to the sage CLI/Go library, shared concepts

### Key Documentation Principles

- **Show, don't tell**: Lead with code examples, explain after
- **Rails first**: Rails examples come before plain Ruby (primary audience)
- **Copy-pasteable**: Every example should work if pasted into a project
- **Credential security**: Always show credentials coming from ENV or Rails credentials, never hardcoded

### Sage Ecosystem Context

Include a brief section explaining how sage-rb fits into the sage ecosystem:
- sage (Go CLI) — command-line tool, file-based config at `~/.config/sage/`
- sage-rb (Ruby gem) — library, initializer-based config
- Same concepts: providers, profiles, complete
- Independent implementations, no dependency between them

## Validation

- [ ] README covers installation, quick start, full API, and all providers
- [ ] Rails quick start works end-to-end when followed literally
- [ ] Plain Ruby quick start works end-to-end when followed literally
- [ ] No hardcoded API keys in any examples
- [ ] All code examples are syntactically valid Ruby
- [ ] Relationship to sage CLI is clearly explained
