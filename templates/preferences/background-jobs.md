# Background jobs, scheduling & resilience

Standing preferences for scheduled/periodic work, retries, and graceful process lifecycle in a backend/service. Extracted independently from `eat-repeat-bot` and `plant-o-tron-2`.

## Timers/schedules survive a restart
- Persist scheduled work (a DB row: what, when, for whom) alongside the in-memory timer handle. On boot, **`rearmAll()`** — reload persisted schedules and re-arm their timers — so a process restart never silently drops pending work.

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
