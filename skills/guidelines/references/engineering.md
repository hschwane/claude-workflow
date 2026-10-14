# Engineering rules

Only the rules that differ from a model's default. Everything else (naming, small functions, formatting) is assumed.

## Acceptance criteria and tests
- **Acceptance criteria need an independent oracle.** Expected values come from the spec or an external source (a standard, a reference implementation, a hand calculation), never from running the code and pasting its output. A test whose expectation was copied from the implementation proves nothing.
- **Tests assert behaviour, not implementation.** Name the behaviour (`returns 401 when the token is expired`), test through the public interface, and don't reach into internals.
- **Real APIs and real dependencies over mocks wherever possible** (test DB, real service in a test environment). A mock only proves the code matches the mock. Mock what genuinely cannot be used; never mock your own code. Anything that costs money or tokens needs the user's permission first, every time.
- Deterministic and independent: no shared mutable state, no ordering dependence, no network, no wall-clock.
- Every bug fix gets a regression test that fails before the fix and passes after. A manual-test finding becomes an automated test, not a note.
- A green gate that ran zero tests is not green. Check the count, not just the exit code.
- Glue code (thin controllers, adapters, wrappers) is covered by integration tests and needs no dedicated unit test.

## Code
- Comments say *why*, never *what*. A comment restating the code is noise.
- `TODO:` marks known debt; link a ticket where one exists.
- No dead code, no commented-out code, no leftover debug prints.
- No secrets in code, ever. Never log raw user data.
- Never swallow an error: no empty catch, no fallback that hides a failure. Fail fast on a violated precondition. Return errors with enough context to debug (operation, identifier, upstream status).
- Expected failure paths are values (`{ ok: false, reason }`), not exceptions; don't throw across module boundaries.
- Side effects (clock, filesystem, network, randomness, SDK calls) are injected with a real default.
- Clear code beats backward compatibility, unless something depends on the old behaviour or it is a published API, CLI or file format.
- Bug fixing: reproduce first (ideally as a failing test), form one theory, gather evidence, fix the root cause and not the symptom.

## Dependencies
Standard library first, then what the project already uses, then project-owned code. A new dependency is the last resort, never for something small. Before proposing one, check and say what you checked: maintained, licence, size and transitive weight, known advisories. A framework or ORM the architecture is built around is a design decision, not a dependency choice. Pin versions, commit the lockfile, drop unused dependencies, don't upgrade unrelated ones.

## Language specifics
- **TypeScript:** `strict: true`, no `any` (use `unknown` and narrow). Derive a union type from a runtime array (`typeof ARR[number]`), never the reverse.
- **Python:** type hints checked with `mypy --strict`; `from __future__ import annotations`.
- **Rust:** `clippy` clean with `-D warnings`. `unwrap()`/`expect()` only where the invariant is locally provable, with a comment saying why.
- **C++:** compile with warnings as errors. Don't rely on `assert()` for checks that must hold; it vanishes under `NDEBUG`.
- **Cargo test layout:** tests live in `tests/` even when they are unit tests by behaviour. Do not move them into `src/` to match test-level names: `cargo test --lib` would then be the only thing running them, which reports green having executed nothing.
