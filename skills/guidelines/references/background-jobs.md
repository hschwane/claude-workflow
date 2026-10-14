# Background jobs, scheduling & resilience

Guidelines for scheduled/periodic work, retries and graceful process lifecycle in a **backend/service**. Extracted from `eat-repeat-bot` and `plant-o-tron-2`.

**Backend only.** Not for frontend code, and not for a stateless request/response backend with no scheduled/periodic/retry work. Skip what doesn't apply, and say why.

## Deployment-aware triggering (required whenever more than one deploy target is realistic)
**How** a job gets triggered depends on the deployment:
- **Scale-to-zero (e.g. Railway with `sleepApplication`)**: the process is asleep between requests, so an **in-process scheduler (`setInterval`/cron-in-code) will not fire**. Trigger from the **outside**: an external cron service hits an authenticated HTTP endpoint (e.g. `POST /tasks/run-due`), which wakes the app, runs due work, and lets it sleep again.
- **Always-on (VPS, container without scale-to-zero, local dev)**: a plain **in-process scheduler** is simpler and sufficient.

**If the project might deploy either way** (see `railway.md`'s portability rule), put the trigger mechanism behind an interface with an implementation per mode, selected by a config variable (like the polling/webhook pattern in `telegram-bots.md`). Job *logic* (what runs, retry/backoff, persistence) stays identical; only *what calls it* changes.

## Schedules survive a restart
- Persist scheduled work as data (a DB row: what, when, for whom), never only as an in-memory timer.
  - **Always-on / in-process:** pair the row with an in-memory timer handle; on boot, **`rearmAll()`** (reload persisted schedules, re-arm timers) so a restart never silently drops pending work.
  - **External-trigger / scale-to-zero:** each wakeup **queries what's due** from persisted state. Persistence is the survival mechanism; no `rearmAll()` needed.

## Bounded retries
- Retrying operations get a **bounded** policy: fixed or backoff delays, a **persisted attempt count**, and a max-attempts cutoff after which it stops and surfaces the failure.

## Pluggable periodic work: a provider registry
- With more than one kind of periodic job, use a small runner with `register(provider)` that runs each provider per tick, **isolating one provider's failure from the others** (catch + log per provider, continue). New job types plug in without touching the runner.

## Timezone-explicit scheduling
- Convert any human-meaningful local time to **UTC explicitly** before storing it or using it in a cron expression; never rely on the host's local timezone, which can change across deploys and desync the schedule.

## Graceful shutdown (required for scale-to-zero platforms)
- Handle `SIGTERM`/`SIGINT`: stop accepting new work, close the HTTP server / polling loop / DB connections, log the shutdown reason. On Railway and similar the process is **stopped**, not killed; an ungraceful exit means half-written state or a dropped request.

## Defense-in-depth for real-world side effects
- Anything controlling real-world state (hardware, an external system with a physical effect) should not rely on a single control path. Add an independent **watchdog/failsafe** timer that can force a safe state if the main logic hangs or the process restarts mid-cycle, and do **boot-time reconciliation** of any interrupted cycle (check the world's actual state, not just the last-known intent).
