# Decisions Log - sage-rb

## 2026-02-13: Separate Repo with Native Ruby Implementation

**Decision:** sage-rb is a standalone Ruby gem in its own repo, implementing provider logic natively in Ruby rather than wrapping the sage Go binary.

**Rationale:** Rails developers expect `bundle add` and an initializer — not installing a Go binary and running CLI commands. The provider HTTP calls are simple enough (~150-250 lines per provider) that native implementation is less maintenance than FFI or subprocess wrappers.

**Alternatives Considered:**
- Wrapping the Go binary (bundled or external) — requires binary install, not Rails-native
- FFI/C shared library — CGo complexity, platform-specific builds
- Monorepo with Go code — Go modules don't work well in subdirectories

**Impact:** Provider logic exists in both Go and Ruby. Adding a new provider means updating both repos.

---

## 2026-02-13: No Credential Management

**Decision:** sage-rb never stores, encrypts, or manages credentials. It receives API keys as strings from the host environment.

**Rationale:** Every Ruby environment already has secure credential management (Rails credentials, ENV vars). Adding another layer increases attack surface for zero benefit. The gem is more secure because it never touches credentials.

**Alternatives Considered:**
- Reimplementing sage's AES-256-GCM encryption in Ruby — unnecessary complexity
- Reading sage's ~/.config/sage/ secrets — couples to Go implementation

**Impact:** The gem has no credential-related code. Documentation shows how to wire credentials from Rails credentials or ENV vars.

---

## 2026-02-13: stdlib Only — No Third-Party Dependencies

**Decision:** Use only Ruby stdlib (net/http, json, openssl). No runtime dependencies.

**Rationale:** Matches sage's Go stdlib-only philosophy. Provider HTTP calls don't need a heavy HTTP library. Fewer dependencies = fewer supply chain risks.

**Alternatives Considered:**
- Faraday for HTTP — nicer API but adds dependency tree

**Impact:** Slightly more verbose HTTP code, but acceptable for the small number of providers.

---

## 2026-02-13: Block Detection for Streaming

**Decision:** `Sage.complete` with a block streams (yields chunks); without a block it blocks and returns the full response.

**Rationale:** Maps to the sage CLI mental model (streaming by default, --json for full response). Follows Ruby patterns (File.open with/without block). One method, two behaviors.

**Alternatives Considered:**
- Separate `Sage.stream` method — clear but less consistent with CLI
- Keyword argument `stream: true` — explicit but verbose

**Impact:** API surface is minimal. Users learn one method.

---

## 2026-02-13: Ruby-First with Optional Rails Extras

**Decision:** Core gem works in any Ruby environment. Rails integration (Railtie, generators) loads conditionally via `if defined?(Rails::Railtie)`.

**Rationale:** One conditional check is the only cost. Rails developers get generators. Non-Rails users aren't burdened. Wider audience.

**Alternatives Considered:**
- Rails-only gem — simpler but artificially limits usage

**Impact:** Gem works in plain Ruby scripts, Sinatra, background workers, etc. Rails gets extra niceties.

---
