# Logging

**Mandatory for anything beyond a small script**: any backend/service, long-running or not. Extracted from `eat-repeat-bot` and `plant-o-tron-2`.

## Typed, catalogued events (not free-text channels)
- Log through **one typed interface** backed by a closed union of named event types, not ad hoc `log.info("some string")` calls. A new kind of log line means a new event type, not a new string format; output stays structured and queryable. (`cshop` uses free-text namespaced strings today, a gap to close, not license to skip the union.)

## Redact automatically, not ad hoc
- Redact PII/secrets **at the logger boundary**, recursively (nested objects too), not by remembering to scrub each call site.
- **Boundary redaction is the backstop, not the primary defense:** each call site should still avoid logging sensitive values. It is not a license to log whatever's convenient.

## Never throws
- The logger must **never throw** and must be safe with circular references or in-flight promises. Logging is a side effect, not a critical path. Prefer fire-and-forget.

## Subsystem tagging
- Support a `child(module)` pattern so logs carry which subsystem emitted them without repeating a tag at every call site.

## Testability
- Provide a **recording fake logger** implementing the same interface, collecting events/errors into inspectable arrays (including through `child()`, so parent and child land in one place). Tests assert exactly what was logged (payload shape, count, order) without real I/O.

## Errors
- Errors logged through the typed-event path carry structured context (operation, identifier, upstream status), not just a stringified stack trace.

## Per-module, runtime-adjustable verbosity
- Log level is configurable **per module/subsystem** and **changeable at runtime**, not only via an env var needing a restart. When Claude debugs something, it must be able to turn up verbosity exactly where the problem is without restarting or drowning in noise.

## Configurable per deployment target
- Where the platform already captures and retains logs (managed platform with log aggregation), rely on that. Otherwise the app must let **logfile location, rotation and deletion of old logs** be configured; don't hard-code a path or let logs grow unbounded.
