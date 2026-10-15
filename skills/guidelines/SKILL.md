---
name: guidelines
description: The maintainer's standing recommendations. Load when designing or planning a new feature, component or project; choosing an approach, library or architecture; building UI/UX, forms or screens; adding logging, background jobs, deployment (Railway), PWA/web-app behaviour, AI/LLM features, bots, maps, charts or an in-app changelog.
---

# Guidelines

The maintainer's standing recommendations for how things get built. Adapt them to the project, or reject one with a stated reason. An explicit user instruction or a line in the project's CLAUDE.md wins over any of them.

| When the task involves… | Read |
|---|---|
| New app project; baseline requirements (logging, changelog, update mechanism, version, access gate, environments, smoke-testing) | `references/app-baseline.md` |
| Logging, structured logs, observability, PII redaction | `references/logging.md` |
| Backend/service architecture, layered app, use cases, repository pattern, external API client, API auth | `references/service-architecture.md` |
| Scheduled tasks, cron, retries, background jobs, timers, graceful shutdown | `references/background-jobs.md` |
| Web app / PWA, service worker, app version + update, client-side persisted state | `references/web-app-pwa.md` |
| UI design process, mockup, style guide, icons, responsive layout, tooltips | `references/ui-frontend.md` |
| UI screens, forms, validation, empty/loading/error states, feedback, confirmations, UI copy | `references/ux-basics.md` |
| Charts, graphs, plots, data viz, dashboards | `references/plots-graphs.md` |
| Maps, tiles, markers, clustering, offline maps, map tooltips | `references/maps.md` |
| Changelog, release notes, in-app version history | `references/changelog.md` |
| AI integration, Claude Agent SDK, AI features, LLM, transcripts, token budget | `references/ai-integration.md` |
| Railway deploy, railway.json, deployment/hosting | `references/railway.md` |
| Telegram bot, commands, inline keyboards, webhooks/polling | `references/telegram-bots.md` |

Read only the rows that match. If none match, you are done.

A project's deviation from a guideline is recorded only if the user asks for it, as a line in the project's CLAUDE.md.
