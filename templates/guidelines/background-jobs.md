# Background jobs, scheduling & resilience

Standing preferences for scheduled/periodic work, retries, and graceful process lifecycle in a **backend/service**. Extracted independently from `eat-repeat-bot` and `plant-o-tron-2`.

**Scope: backend only.** This does not apply to frontend/client code, and not to a backend with no scheduled/periodic/retry work at all — a stateless request/response API needs none of this. Skip anything below that doesn't apply, and say why (see the preferences README on treating these as recommendations, not rules).

## Deployment-aware triggering (required whenever more than one deploy target is realistic)
**How** a job gets triggered depends on the deployment:
- **Scale-to-zero (e.g. Railway with `sleepApplication`)** — the process is asleep between requests, so an **in-process scheduler (`setInterval`/cron-in-code) will not fire**. Trigger jobs from the **outside**: an external cron/scheduler service hits an authenticated HTTP endpoint (e.g. `POST /tasks/run-due`), which wakes the app, runs due work, and lets it sleep again.
- **Always-on (VPS, container without scale-to-zero, local dev)** — a plain **in-process scheduler** is simpler and sufficient; no external wakeup needed.

**If the project might deploy either way** (or the deploy target could change later — see `railway.md`'s portability rule), put the trigger mechanism behind an interface with an implementation per mode, selected by a config variable (mirroring the Telegram polling/webhook pattern in `telegram-bots.md`): the job *logic* (what runs, retry/backoff, persistence) stays identical; only *what calls it* changes. Don't hard-wire an in-process scheduler into a project that might later move to scale-to-zero, or vice versa.

## Schedules survive a restart
- Persist scheduled work as data (a DB row: what, when, for whom) — never only as an in-memory timer. How that persisted state gets acted on again follows the triggering mode above:
  - **Always-on / in-process scheduler:** pair the persisted row with an in-memory timer handle; on boot, **`rearmAll()`** — reload persisted schedules and re-arm their timers — so a restart never silently drops pending work.
  - **External-trigger / scale-to-zero:** there's no long-lived in-memory timer to lose — each wakeup just **queries what's due** from the persisted state. The persistence *is* the survival mechanism; no `rearmAll()` needed.

## Bounded retries
- Failed operations that should retry get a **bounded** retry policy: fixed or backoff delays, a **persisted attempt count**, and a max-attempts cutoff after which it stops and surfaces the failure instead of retrying forever.

## Pluggable periodic work: a provider registry
- When there's more than one kind of periodic/background job, use a small runner that accepts `register(provider)` implementations and runs them each tick, **isolating one provider's failure from the others** (catch + log per provider, continue to the next) — new job types plug in without touching the runner or each other.

## Timezone-explicit scheduling
- Convert any human-meaningful local time to **UTC explicitly** before storing/using it in a cron expression or schedule — never rely on the container/host's local timezone, which can silently change across deploys and desync the schedule.

## Graceful shutdown (required for scale-to-zero platforms)
- Handle `SIGTERM`/`SIGINT` explicitly: stop accepting new work, close the HTTP server / polling loop / DB connections, log the shutdown reason. Required on Railway and similar platforms where the process is **stopped**, not killed — an ungraceful exit there routinely means half-written state or a dropped in-flight request.

## Defense-in-depth for real-world side effects
- Anything controlling real-world state (hardware, an external system with a physical effect) should not rely on a single control path. Add an independent **watchdog/failsafe** timer that can force a safe state even if the main control logic hangs or the process restarts mid-cycle, and do **boot-time reconciliation** of any cycle that was interrupted (check what state the world is actually in, not just what the last-known intent was).
