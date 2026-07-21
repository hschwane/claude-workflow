# Logging

Standing preferences for logging in a backend/service. Extracted independently from `eat-repeat-bot` and `plant-o-tron-2`.

## Typed, catalogued events (not free-text channels)
- Log through **one typed interface** backed by a closed union of named event types, rather than ad hoc `log.info("some string")` calls scattered around. Adding a new kind of log line means adding a new event type, not inventing a new string format — keeps log output structured and greppable/queryable.

## Redact automatically, not ad hoc
- Redact PII/secrets **at the logger boundary**, recursively (nested objects too) — not by remembering to scrub each call site. A logger that can leak a token because one call site forgot to redact is a logger that will eventually leak a token.

## Never throws
- The logger itself must **never throw** and must be safe to call with circular references or in-flight promises. Logging is a side effect, not a critical path — an always-on process cannot be crashed by its own logging. Prefer fire-and-forget semantics.

## Subsystem tagging
- Support a `child(module)`-style pattern so logs carry which subsystem emitted them, without repeating a tag string at every call site.

## Testability
- Provide a **recording fake logger** implementing the same interface, collecting emitted events/errors into inspectable arrays (including through `child()`, so parent and child logs land in one place). Tests then assert exactly what was logged — payload shape, count, order — without real I/O or a real logging backend.

## Errors
- Errors logged through the same typed-event path should carry structured context (what operation, what identifier, what upstream status) — not just a stringified stack trace with no way to query it later.
