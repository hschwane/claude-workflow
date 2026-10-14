# Backend / service architecture

Guidelines for any non-trivial backend, service or long-running app (API, bot, daemon). Extracted from `eat-repeat-bot` and `plant-o-tron-2`, which document the same layering as a deliberate decision.

## Layered architecture (required for non-trivial services)
- **Domain**: pure business rules, zero I/O, zero framework imports. Values in, values out.
- **Application**: use cases/orchestration. Depends on **ports** (repository/notifier interfaces it defines), never a concrete implementation.
- **Infrastructure**: implements the ports (DB repositories, external API clients, messaging/transport adapter).
- **Outer layer** (HTTP/bot handlers, CLI): thin. Wires a request to a use case and formats the response; no business logic.

## Use cases as factory functions
- `makeXUseCase(deps)`: a factory closing over injected dependencies (repositories, notifiers, clock) and returning the callable. No DI framework; tests pass their own fakes.

## Repository pattern + Unit of Work
- Application defines repository **interfaces** (domain/DTO types in, domain types out); infrastructure implements them (e.g. ORM-backed).
- Wrap multi-step writes in a **Unit of Work** owning the transaction (savepoints if steps can partially fail and retry). Use cases don't open transactions against the ORM directly.

## Composition root, fail-fast config
- Wire everything in **one place** (`index.ts`/`main`) in dependency order: load + validate config **first**; if misconfigured, fail loudly with an actionable message and exit, never start partially initialized.
- Validate config with **schema validation** (e.g. Zod) per field, with messages specific enough to fix that never leak secret values.
- **Discriminated unions** for mode-dependent config, so mode-specific fields (e.g. webhook-only settings) exist in the type only when that mode is selected.

## Wrapping external APIs
- Each external API behind a small **client class**: validate responses against a schema (reject silently-wrong shapes), map failures to a **typed error** carrying URL/status/context, and add a light **TTL in-memory cache** per endpoint (`{at, data}`, `Date.now() - at < TTL_MS`).

## Domain rules as pure result-returning functions
- Rules return `{ ok: true } | { ok: false, reason }` rather than throwing for expected failures.

## One source of truth for related registries
- When allowed values need both a runtime array **and** a type, derive the type from the array (`typeof ARR[number]`).
- When two registries must stay in lockstep (command catalog vs admin-only subset, menu vs help text), add an **audit test** asserting they agree, run against the real registries.

## Export/import format versioning
- Any backup/export format gets an explicit **version number** and an **allowlist of versions the importer accepts**. Evolve **additively only** (new optional fields), never repurpose or remove a field, so an old export still imports.

## Resource-conscious by default
- Bound concurrency/connection pools, avoid needless polling or keep-alive work, prefer the cheapest data structure/query that satisfies the requirement. Matters doubly on scale-to-zero deploys (see `railway.md`).
- **Prefer the client for work that can happen there:** server compute costs money, the user's device doesn't. Push formatting, rendering and light computation client-side; keep the server for shared state, secrets and heavy or genuinely shared computation.

## API authentication (required)
Every API surface carries a token unless deliberately public:
- Endpoints the app/PWA calls: authenticate as the app does, an account/session token for multi-user apps, an env-var-configured token for single-user apps (see `web-app-pwa.md`).
- Endpoints exposed for scripts/extensions: their own explicitly issued token, not the interactive session's secret.
- Multi-user apps authorize via the account/session; single-purpose or ops-facing endpoints via a deployment env var.

## Logging is mandatory
Structured logging applies to any backend or service; see `logging.md`. Only the ceremony scales with size.

## Injectable side effects
- Any external effect a unit test shouldn't touch (clock, filesystem, timers, an SDK call function) is an optional parameter defaulting to the real implementation.

## Non-critical side-channels never block the primary path
- Instrumentation that isn't the point of the request (usage recording, backup upload, analytics ping) is wrapped so it can never fail or delay the response: catch, log, move on.
