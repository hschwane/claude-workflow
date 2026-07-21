# Railway deployment

Standing preferences that apply whenever this project deploys on Railway. (Railway is the preferred deploy target in general — that hint stays in the workflow; these are the details.)

## Configuration
- **Scale-to-zero** enabled — the app sleeps when idle, so it must tolerate cold starts.
- **European region** (e.g. `europe-west4`).
- **Service URL prefixed with the project name** (e.g. `<project>.up.railway.app` — choose the subdomain when generating the domain).
- **`railway.json` `build.watchPatterns`** must exclude `docs/`, `tests/`, `.claude/`, `.github/`, and markdown, so the workflow's constant docs/spec commits don't trigger redeploys. If the app *serves* files from those paths at runtime, drop the matching `!` line and note the exception here.
- After deploy, **verify health via the Railway MCP** (or the healthcheck endpoint) before considering a release done.

## Portability — Railway-specifics behind an interface (required)
Any Railway-specific capability — the Railway API/SDK, platform env vars, volumes, private networking, or platform quirks — **must be used only behind a project-defined interface/abstraction**, never sprinkled through the codebase. The rest of the app depends on that interface, not on Railway.

This keeps switching to another deployment target (a VPS, another PaaS, self-hosted) a matter of swapping a single adapter implementation — no lock-in. When a ticket touches Railway-specific behavior, `/plan` should put the abstraction in the approach and add a subtask for the adapter, not couple app logic to Railway directly.
