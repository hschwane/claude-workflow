# Application baseline (required)

Standing baseline for **any application project bigger than a small script or mini-tool** — the handful of things every such project needs regardless of stack. Each is detailed in its own preference file; this is the checklist that says they're not optional.

**Build these first.** Everything here is development and debugging infrastructure, so it belongs in the **first milestone** (`tech-backbone` in a `/project-init` backlog) — before the features that will depend on it. Logging you add after the fact doesn't cover the code already written; an update mechanism retrofitted into a shipped app is a migration instead of a feature; a changelog started late has a hole in its history. Deferring these costs more than building them early, which is why they aren't "nice to have later."

## Logging (required)
Structured logging, mandatory — see `logging.md`.

## In-app changelog (required)
A changelog built into the app, maintained on every release — see `changelog.md`.

## In-app update mechanism (required whenever feasible)
Build whatever update mechanism fits the architecture — fully automatic where safe, otherwise a single click inside the running app — so the user is never left manually redeploying or reinstalling to get the latest version. For a web app/PWA this is the update button + banner in `web-app-pwa.md`; for other architectures (desktop, CLI, service), build the closest equivalent (self-update command, in-app "update available" prompt, etc.). Skip only if the architecture genuinely has no sane way to do this — say why, don't just omit it.

For a **self-hosted deployment** (Docker on a VPS/Pi, no managed platform auto-deploying it), pull the update at the **infrastructure level** instead: a script that pulls the new image, recreates the container, health-checks it, and **automatically rolls back to the previous image** if the new one doesn't come up healthy — scheduled via a periodic timer, opt-in (don't silently auto-update a self-hosted box by default). This is a different layer from the in-app update control above (that one refreshes the running app's cached assets; this one replaces the running deployment) — a project may need one, the other, or both depending on how it's deployed.

## Claude-driven smoke-testing must always be possible (required)
Claude must always be able to run a smoke test and debug failures against a **live instance** — clicking through the UI, hitting the API, whatever fits the app. Satisfy this one of two ways:
- Run the app **locally** (the common case — see the `run` skill), or
- Stand up a **QS/staging deployment** at the project's deploy provider that Claude can update, redeploy, and tear down on its own, spun up for testing and shut down afterward.

Either way, a QS/staging instance must **never** collide with the production instance — separate environment, separate data, separate URL/domain. Sharing state or a deploy slot with prod is not an acceptable shortcut.
