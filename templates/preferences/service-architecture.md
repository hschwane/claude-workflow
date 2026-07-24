# Backend / service architecture

Standing preferences for any non-trivial backend, service, or long-running app (API, bot, daemon). Extracted independently from `eat-repeat-bot` and `plant-o-tron-2` — both document the same layering as a deliberate ADR, which is a strong signal it generalizes.

## Layered architecture (required for non-trivial services)
- **Domain** — pure business rules, zero I/O, zero framework imports. Functions take values, return values.
- **Application** — use cases / orchestration. Depends on **ports** (repository/notifier interfaces it defines itself), never on a concrete implementation.
- **Infrastructure** — implements the ports: DB repositories, external API clients, the messaging/transport adapter.
- **Outer layer** (HTTP handlers / bot handlers / CLI) — thin. It wires a request to a use case and formats the response; it holds no business logic.

This keeps the core testable without I/O, and swappable (new transport, new DB) without touching business logic.

## Use cases as factory functions
- Write each use case as `makeXUseCase(deps)` — a factory that closes over its injected dependencies (repositories, notifiers, clock) and returns the callable. No DI framework needed; each test just passes its own fakes.

## Repository pattern + Unit of Work
- Application defines repository **interfaces** (domain/DTO types in, domain types out); infrastructure provides the concrete implementation (e.g. an ORM-backed repo).
- Wrap multi-step writes in a **Unit of Work** that owns the transaction (with savepoint support if steps can partially fail and retry). Don't let use cases open transactions directly against the ORM.

## Composition root, fail-fast config
- Wire everything in **one place** (`index.ts`/`main`), in dependency order: load + validate config **first**; if anything is misconfigured, fail loudly with an actionable message and exit — never start partially initialized.
- Validate config with **schema validation** (e.g. Zod) per field, with error messages specific enough to fix but that never leak secret values.
- Use **discriminated unions** for mode-dependent config, so mode-specific fields (e.g. webhook-only settings) only exist in the type when that mode is selected — eliminates runtime "is this set" checks and impossible states.

## Wrapping external APIs
- Put each external API behind a small **client class**: validate responses against a schema (reject silently-wrong shapes instead of trusting them), map failures to a **typed error** carrying the URL/status/context, and add a light **TTL in-memory cache** per endpoint (`{at, data}`, check `Date.now() - at < TTL_MS`) instead of hitting the external service on every call.

## Domain rules as pure result-returning functions
- Business rules return a typed result — `{ ok: true } | { ok: false, reason: "..." }` — rather than throwing for expected failure paths. Keeps control flow explicit and the function trivially unit-testable.

## One source of truth for related registries
- When a set of allowed values needs both a runtime array **and** a type, derive the type from the array (`typeof ARR[number]`), not the other way around — one list, never two.
- When two registries must stay in lockstep (e.g. a command catalog vs. an admin-only subset, or a menu vs. its help text), add an **audit test** that asserts they agree, run against the real registries — catches "added to one, forgot the other" at CI time instead of production.

## Export/import format versioning
- Any backup/export format gets an explicit **version number** and an **allowlist of versions the importer accepts**. Evolve the schema **additively only** (new optional fields) — never repurpose or remove a field — so an old export a user is still holding keeps importing.

## Resource-conscious by default
- Backends are frugal by default: bound concurrency/connection pools, avoid needless polling or keep-alive work, prefer the cheapest data structure/query that satisfies the requirement. This matters doubly on scale-to-zero deploys (see `railway.md`) where idle resource use has a direct cost.
- **Prefer the client for work that can happen there:** server compute costs money, the user's own device doing the same work does not. Push formatting, rendering, and light computation client-side by default; keep the server for what only it can or should do (shared state, secrets, heavy or genuinely shared computation).

## API authentication (required)
Every API surface carries a token unless it's deliberately public:
- Endpoints the frontend/app/PWA calls: authenticate the same way the app does — an account/session token for multi-user apps, an env-var-configured token for single-user apps (see `web-app-pwa.md`'s access-control note).
- Endpoints exposed on purpose for scripts/extensions: their own token, issued explicitly — not the same secret as the interactive session.
- Multi-user apps authorize via the account/session; single-purpose or ops-facing endpoints authorize via a deployment env var.

## Logging is mandatory
Structured logging applies to any backend or service — see `logging.md` for the how. Not optional here, only the level of ceremony scales with size.
