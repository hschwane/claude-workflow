# Telegram bots

Standing preferences for building Telegram bots. Extracted from `plant-o-tron` and `eat-repeat-bot`, generalized to best-of-both.

## Stack
- **grammY** on **TypeScript / ESM, Node ≥22**; validate config with **zod**. Add `@grammyjs/i18n` (Fluent) when the bot needs more than one language.

## Transport behind an interface (required)
- Put the transport behind an interface (`start(bot)` / `stop()`) with **polling** and **webhook** implementations, selected by a `TELEGRAM_MODE` env var — switching is a config change, never a code change.
- **Webhooks are the preferred mode on Railway for scale-to-zero:** long-polling keeps an outbound connection open and the service never sleeps. So default to polling for local dev, but ship webhook for Railway (`.env.example` = webhook; `railway.json` `sleepApplication: true` + a `healthcheckPath`).
- In webhook mode: run a **tiny HTTP server** (bare `node:http` or Hono, RAM-conscious), **verify Telegram's secret token** on the webhook route, expose `/health`, and reuse Railway's injected `PORT` / `RAILWAY_PUBLIC_DOMAIN`. Because the app sleeps, **drive scheduled/periodic work from an authenticated cron endpoint** (a Railway cron service `POST`s to it) instead of an in-process interval loop; a `/wake` or `/tasks/run-due` route is the pattern. Polling mode can keep the in-process scheduler.

## Telegram calls behind ports
- Don't scatter raw `bot.api` / `ctx.reply` calls of cross-cutting messaging across use-cases. Define application-layer **ports** (e.g. `GroupNotifier`, `GuestNotifier`) implemented by a Telegram adapter; use-cases depend on the interface. At minimum, wrap outbound sends in small helpers (`send`, `sendWithKeyboard`, `editMessageText`) rather than calling the API inline everywhere. (Keeps the app testable and the messaging layer swappable.)

## Commands: one registry, never-drifting help (required)
- Keep a **single command catalog** — one array of `{ command, descriptionKey, audience, hidden? }` — as the single source of truth.
- Feed **both** `setMyCommands` **and** `/help` from that catalog, so the in-app menu and the help text **can never drift**. (Don't hand-maintain a separate help string synced by a comment.)
- **Scope the menu by audience:** default scope shows guest commands; per-admin `BotCommandScopeChat` adds admin commands — so ordinary users never see admin clutter. Localize per supported locale. Exclude `hidden` commands from both menu and help.
- Register commands **per-feature** (`registerXCommand(bot, deps)`) and assemble them in one bot-builder with a **fixed, documented middleware order** and a single global error boundary (`bot.errorBoundary`, which also works under webhooks — not `bot.catch`).
- **Guard/authorize first**: allowlist or role/membership middleware runs before handlers.

## How many commands
- **Not too many, but as many as needed.** Keep **simple, frequent actions as flat commands**; **collapse complex or rare actions into nested inline-keyboard menus** (e.g. one `/settings` with categorized submenus) rather than adding a command per option. Audience-scoping further trims what any one user sees.

## Onboarding
- A `/start` that gives new users a fitting **welcome** and orients them — role-aware where relevant (`ctx.t(isAdmin ? "start-admin" : "start-guest")`). If `/start` launches a setup wizard, guard it so an already-configured user gets help instead of re-running setup.

## Menu / UI hygiene
- Use **inline keyboards** for anything with choices; give complex flows clear paths and short explanations where they help.
- **Callback-data discipline:** central constants or a typed encode/decode codec, kept under Telegram's **64-byte** limit.
- **Back buttons** (`← Back`) on nested menus; an explicit **close** (`✖`) that **edits the message to a "closed" state and drops the keyboard**, or deletes the message — don't leave stale menus lying in the chat.
- Always call **`answerCallbackQuery()`** after handling a button to clear its spinner; prefer editing the existing message (`editMessageText`) over spamming new ones.

## Free-text input
- Ask for free text **in chat** when it's genuinely needed (a name, a note), via a bounded pattern — either **command-prefixed entry points + a last-registered "unknown input" fallback** that only replies to otherwise-unconsumed private text, or a **persisted pending-step + intercept middleware** that routes the next message. Prompt with a cancel button. Don't pull in a heavyweight conversations plugin for simple prompts.
