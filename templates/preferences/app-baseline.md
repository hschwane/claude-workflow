# Application baseline (required)

Standing baseline for **any application project bigger than a small script or mini-tool** — the handful of things every such project needs regardless of stack. Each is detailed in its own preference file; this is the checklist that says they're not optional.

## Logging (required)
Structured logging, mandatory — see `logging.md`.

## In-app changelog (required)
A changelog built into the app, maintained on every release — see `changelog.md`.

## In-app update mechanism (required whenever feasible)
Build whatever update mechanism fits the architecture — fully automatic where safe, otherwise a single click inside the running app — so the user is never left manually redeploying or reinstalling to get the latest version. For a web app/PWA this is the update button + banner in `web-app-pwa.md`; for other architectures (desktop, CLI, service), build the closest equivalent (self-update command, in-app "update available" prompt, etc.). Skip only if the architecture genuinely has no sane way to do this — say why, don't just omit it.

## Claude-driven smoke-testing must always be possible (required)
Claude must always be able to run a smoke test and debug failures against a **live instance** — clicking through the UI, hitting the API, whatever fits the app. Satisfy this one of two ways:
- Run the app **locally** (the common case — see the `run` skill), or
- Stand up a **QS/staging deployment** at the project's deploy provider that Claude can update, redeploy, and tear down on its own, spun up for testing and shut down afterward.

Either way, a QS/staging instance must **never** collide with the production instance — separate environment, separate data, separate URL/domain. Sharing state or a deploy slot with prod is not an acceptable shortcut.
