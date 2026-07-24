# Logging

Standing preferences for logging. **Mandatory for anything beyond a small script** — any backend/service, long-running or not. Extracted independently from `eat-repeat-bot` and `plant-o-tron-2`.

## Typed, catalogued events (not free-text channels)
- Log through **one typed interface** backed by a closed union of named event types, rather than ad hoc `log.info("some string")` calls scattered around. Adding a new kind of log line means adding a new event type, not inventing a new string format — keeps log output structured and greppable/queryable.
- A full compile-time enum is the strongest version of this; a **consistently-namespaced free-text event string** (`"ai_job_start"`, `"backup_upload_error"`, …) through that same one interface is an acceptable lighter-weight fallback for a smaller project — the point is one disciplined convention, not necessarily a compiler-checked one. (This is what `cshop` actually does today.)

## Redact automatically, not ad hoc
- Redact PII/secrets **at the logger boundary**, recursively (nested objects too) — not by remembering to scrub each call site. A logger that can leak a token because one call site forgot to redact is a logger that will eventually leak a token.
- **Boundary redaction is the backstop, not the primary defense:** each call site should still think about what it's putting in the payload and avoid logging sensitive values in the first place. Don't treat automatic redaction as a license to log whatever's convenient.

## Never throws
- The logger itself must **never throw** and must be safe to call with circular references or in-flight promises. Logging is a side effect, not a critical path — an always-on process cannot be crashed by its own logging. Prefer fire-and-forget semantics.

## Subsystem tagging
- Support a `child(module)`-style pattern so logs carry which subsystem emitted them, without repeating a tag string at every call site.

## Testability
- Provide a **recording fake logger** implementing the same interface, collecting emitted events/errors into inspectable arrays (including through `child()`, so parent and child logs land in one place). Tests then assert exactly what was logged — payload shape, count, order — without real I/O or a real logging backend.

## Errors
- Errors logged through the same typed-event path should carry structured context (what operation, what identifier, what upstream status) — not just a stringified stack trace with no way to query it later.

## Per-module, runtime-adjustable verbosity
- Log level/depth is configurable **per module/subsystem**, not just one global level, and **changeable at runtime** — not only via an env var that needs a restart to take effect. When Claude needs to debug something, it must be able to turn up verbosity exactly where the problem is without restarting the process or drowning in unrelated noise.

## Configurable per deployment target
- When the deployment platform already captures and retains logs (a managed platform with built-in log aggregation), rely on that — nothing extra needed. Otherwise, the app must let **logfile location, rotation, and deletion of old logs** be configured manually — don't hard-code a path or let logs grow unbounded on a target that doesn't manage that for you.
