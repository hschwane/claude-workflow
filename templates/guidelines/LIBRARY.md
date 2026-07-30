# Guideline library (workflow-provided)

Ready-made standing guidelines shipped with the workflow — the maintainer's cross-project "how I like X done" notes, extracted from real projects.

**Every project gets the whole library.** `/project-init` and `/project-onboard` install all of it into `.claude/guidelines/`, and `/workflow-update` keeps it in sync. There is no per-project selection, because there is nothing to select: relevance is decided per *task*, by the trigger table, not per project at install time. A project that grows a chart or a background job a year in finds the guideline already there — which is the case selective installation kept getting wrong.

Installing a file doesn't mean applying it verbatim — see the note in `README.md`: these are recommendations `/plan` adapts to the project or deliberately rejects with a reason, never blind rules.

A project's `.claude/guidelines/` is **plugin-owned**: `/workflow-update` overwrites every file from the current version, so a fix here reaches existing projects instead of freezing at install time. Project-specific rules — including a deliberate deviation from one of these — belong in `.claude/memory/decisions.md`, which updates never touch.

## The library

The trigger text is what lands in the project's `INDEX.md`, and it is the *only* thing that decides when a guideline is read. Write it as the words that would plausibly appear in a ticket about that subject.

| Guideline file | Read when the task involves… |
|---|---|
| `app-baseline.md` | New app project, baseline requirements, logging/changelog/update mechanism, QA smoke-testing |
| `logging.md` | Logging, structured logs, observability, PII redaction |
| `service-architecture.md` | Backend/service architecture, layered app, use cases, repository pattern, external API client |
| `background-jobs.md` | Scheduled tasks, cron, retries, background jobs, timers, graceful shutdown |
| `web-app-pwa.md` | Web app / PWA, service worker, app version + update |
| `ui-frontend.md` | UI design, mockup, design system, icons, responsive layout, tooltips |
| `plots-graphs.md` | Charts, graphs, plots, data viz, dashboards |
| `maps.md` | Maps, tiles, markers/pins, clustering, offline maps, map tooltips |
| `changelog.md` | Changelog, release notes, in-app version history |
| `ai-integration.md` | AI integration, Claude Agent SDK, AI features, LLM, transcripts, token budget |
| `railway.md` | Railway deploy, railway.json, deployment/hosting |
| `telegram-bots.md` | Telegram bot, commands, inline keyboards, webhooks/polling |

## Adding a guideline

1. Drop a `<topic>.md` in this directory.
2. Add a row above.
3. Add the same row to `INDEX.md.template` — that file is copied into projects verbatim, so a guideline missing from it ships as a file nothing ever reads. The plugin's `scripts/check.sh` asserts the two stay in step.

Keep each file short and specific: the standing rules you'd otherwise repeat every time you touch that tech or feature. A guideline that restates general good practice earns nothing — `docs/dev/code-style.md` already carries that, and it is always available.

## What a *design* reads is a different question

`/project-init` step 1.5 and `/project-onboard` still match this table against the project to decide what to **read while designing** — a Railway deploy means reading `railway.md` before writing the architecture, and `app-baseline.md`'s required items become backlog tickets. That is a reading decision at the moment the project is being shaped. It has nothing to do with what gets installed: everything gets installed.
