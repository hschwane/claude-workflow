# Application baseline (required)

Baseline for **any application bigger than a small script or mini-tool**: the things every such project needs regardless of stack. Each is detailed in its own file; this is the checklist saying they're not optional.

**Build these first**, in the first milestone, before the features that depend on them. Logging added later doesn't cover code already written; an update mechanism retrofitted into a shipped app is a migration; a changelog started late has a hole in its history.

## Logging (required)
Structured logging, mandatory; see `logging.md`.

## In-app changelog (required)
A changelog built into the app, maintained on every release; see `changelog.md`.

## In-app update mechanism (required whenever feasible)
Build whatever update mechanism fits the architecture (fully automatic where safe, otherwise one click inside the running app) so the user is never left manually redeploying or reinstalling. For a web app/PWA this is the update button + banner in `web-app-pwa.md`; for desktop, CLI or service, the closest equivalent (self-update command, "update available" prompt). Skip only if the architecture has no sane way to do this, and say why.

For a **self-hosted deployment** (Docker on a VPS/Pi, no managed platform auto-deploying it), pull the update at the **infrastructure level**: a script that pulls the new image, recreates the container, health-checks it, and **automatically rolls back** if the new one isn't healthy, run by a periodic timer, opt-in (don't silently auto-update a self-hosted box). This is a different layer from the in-app control (which refreshes cached assets; this replaces the running deployment); a project may need one, the other, or both.

## Version visibility (required)
The running app must be able to say which version it is: a `--version` flag, a `/health` payload carrying it, a footer line. Without it you cannot tell whether a deploy landed, and a post-release healthcheck has nothing to assert against, so a release that deployed the previous build reports success. Wire it from the manifest at build time rather than typing the number twice.

## An access gate where the app is reachable (required when applicable)
Anything exposed beyond localhost needs *some* gate before it holds real data: a password for a private single-user tool, API-token auth for a service, accounts for several users. Retrofitting authentication after the data model exists is a rewrite of every handler.

## Environments: three names, most projects have two (required)
Use these words everywhere; a project that invents its own quickly has two things called "dev".

| Name | Exists when | Fed by |
|---|---|---|
| **production** | whenever the project deploys at all | releases; the only thing "deploy" means |
| **reference** | optional; a deployed copy of the integration branch, if the project wants a look at the merged state before users get it | every merge into the integration branch |
| **dev** | always: where Claude builds, runs and tests | nothing; tracks no branch, started on demand and stopped after use |

The common shape is **production + a local dev environment**. A *deployed* dev environment is a last resort, only where local genuinely cannot run the code or surface the bug.

**Reference must not be able to touch production.** Separate service, database, secrets and domain; no shared writable resource, ever.

**Data and APIs in dev.** Use the real API wherever it can be used; a mock only proves the code matches the mock. Mock what genuinely cannot be used against a test environment. **Anything that costs money or tokens needs the user's permission first**, every time, not once.

## Claude-driven smoke-testing must always be possible (required)
Claude must always be able to smoke-test and debug against a **live instance** (clicking through the UI, hitting the API). Either:
- run the app **locally** (the common case), or
- stand up a **QS/staging deployment** at the deploy provider that Claude can update, redeploy and tear down on its own.

Either way, a QS/staging instance must **never** collide with production: separate environment, data and URL/domain. Sharing state or a deploy slot with prod is not acceptable.
