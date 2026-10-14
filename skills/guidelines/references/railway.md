# Railway deployment

Applies whenever the project deploys on Railway (the preferred deploy target in general).

## Configuration
- **Scale-to-zero** enabled: the app sleeps when idle, so it must tolerate cold starts.
- **European region** (e.g. `europe-west4`).
- **Production URL is exactly `<project-name>.up.railway.app`**, nothing appended. Railway's auto-generated domain adds the environment and a random suffix (`myapp-production-a1b2.up.railway.app`), so **set the subdomain explicitly** when generating the domain. If the bare name is taken, ask rather than silently falling back to a decorated one. A QA/staging instance (see `app-baseline.md`) gets its own clearly distinct domain; production owns the bare name.
- **`railway.json` `build.watchPatterns`** must exclude `docs/`, `tests/`, `.claude/`, `.github/` and markdown, so constant docs/spec commits don't trigger redeploys. If the app *serves* files from those paths at runtime, drop the matching `!` line.
- After deploy, **verify health via the Railway MCP** (or the healthcheck endpoint) before considering a release done.
- **Database migrations run in the `start` command, not `pre_deploy_command`.** Railway's pre-deploy step runs in an ephemeral container without volumes mounted, so a migration touching a volume-backed DB (e.g. SQLite on a volume) silently no-ops or fails there. Run migrations as the first step of the start script.

## Portability: Railway-specifics behind an interface (required)
Any Railway-specific capability (the Railway API/SDK, platform env vars, volumes, private networking, platform quirks) **must be used only behind a project-defined interface**, never sprinkled through the codebase. Switching to another target (VPS, other PaaS, self-hosted) is then a single adapter swap. When a feature touches Railway-specific behaviour, put the abstraction in the approach and a subtask for the adapter; don't couple app logic to Railway.
