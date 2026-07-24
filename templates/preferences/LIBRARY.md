# Preference library (workflow-provided)

Ready-made standing preferences shipped with the workflow — the maintainer's cross-project "how I like X done" notes, extracted from real projects. `/project-init` and `/project-onboard` install the ones that match a project into its `.claude/preferences/` (copy the file + add the INDEX row); you can also copy any by hand. They are **not** all installed everywhere — only the matching ones, so a project's index stays small.

Installing a file doesn't mean applying it verbatim — see the note in `README.md`: these are recommendations `/plan` adapts to the project or deliberately rejects with a reason, never blind rules.

| Preference file | Install when the project… | INDEX trigger row (left cell) |
|---|---|---|
| `railway.md` | deploys on Railway | `Railway deploy, railway.json, deployment/hosting` |
| `plots-graphs.md` | renders charts / graphs / plots / data-viz | `Charts, graphs, plots, data viz, dashboards` |
| `maps.md` | shows an interactive map (tiles, markers, geo) | `Maps, tiles, markers/pins, clustering, offline maps, map tooltips` |
| `web-app-pwa.md` | is a web app / PWA (service worker, app shell) | `Web app / PWA, service worker, app version + update` |
| `telegram-bots.md` | is a Telegram bot | `Telegram bot, commands, inline keyboards, webhooks/polling` |
| `service-architecture.md` | has a non-trivial backend/service (API, bot, daemon) with real business logic | `Backend/service architecture, layered app, use cases, repository pattern, external API client` |
| `logging.md` | is anything beyond a small script (any backend/service, long-running or not) — mandatory, not optional | `Logging, structured logs, observability, PII redaction` |
| `background-jobs.md` | has scheduled/periodic/background work, retries, or must shut down gracefully | `Scheduled tasks, cron, retries, background jobs, timers, graceful shutdown` |

**To install one:** copy `templates/preferences/<file>` → `<project>/.claude/preferences/<file>`, then add a row to the project's `.claude/preferences/INDEX.md`:
`| <trigger row from the table above> | .claude/preferences/<file> |`

**To add a new library preference:** drop a `<topic>.md` here and add a row above. Keep each file short and specific — the standing rules you'd otherwise repeat every time you touch that tech/feature.
