# Telegram bots

Guidelines for building Telegram bots. Extracted from `plant-o-tron` and `eat-repeat-bot`, generalized to best-of-both.

## Stack
- **grammY** on **TypeScript / ESM, Node ≥22**; validate config with **zod**. Add `@grammyjs/i18n` (Fluent) when the bot needs more than one language.

## Transport behind an interface (required)
- Put the transport behind an interface (`start(bot)` / `stop()`) with **polling** and **webhook** implementations, selected by a `TELEGRAM_MODE` env var; switching is a config change, never a code change.
- **Webhooks are preferred on Railway for scale-to-zero:** long-polling keeps an outbound connection open and the service never sleeps. Default to polling for local dev, ship webhook for Railway (`.env.example` = webhook; `railway.json` `sleepApplication: true` + a `healthcheckPath`).
- In webhook mode: a **tiny HTTP server** (bare `node:http` or Hono, RAM-conscious), **verify Telegram's secret token** on the webhook route, expose `/health`, reuse Railway's injected `PORT` / `RAILWAY_PUBLIC_DOMAIN`. Because the app sleeps, **drive scheduled work from an authenticated cron endpoint** (a Railway cron service `POST`s to it) instead of an in-process interval; a `/wake` or `/tasks/run-due` route is the pattern. Polling mode can keep the in-process scheduler.

## Telegram calls behind ports
- Don't scatter raw `bot.api` / `ctx.reply` calls of cross-cutting messaging across use cases. Define application-layer **ports** (e.g. `GroupNotifier`, `GuestNotifier`) implemented by a Telegram adapter. At minimum wrap outbound sends in small helpers (`send`, `sendWithKeyboard`, `editMessageText`).

## Commands: one registry, never-drifting help (required)
- A **single command catalog**, one array of `{ command, descriptionKey, audience, hidden? }`, is the source of truth.
- Feed **both** `setMyCommands` **and** `/help` from it, so menu and help **can never drift**.
- **Scope the menu by audience:** default scope shows guest commands; per-admin `BotCommandScopeChat` adds admin commands. Localize per locale. Exclude `hidden` commands from both menu and help.
- Register commands **per feature** (`registerXCommand(bot, deps)`) and assemble them in one bot builder with a **fixed, documented middleware order** and a single global error boundary (`bot.errorBoundary`, which also works under webhooks; not `bot.catch`).
- **Guard/authorize first:** allowlist or role/membership middleware runs before handlers.

## How many commands
- **Not too many, but as many as needed.** Simple, frequent actions are flat commands; complex or rare ones collapse into nested inline-keyboard menus (one `/settings` with submenus) rather than a command per option.

## Onboarding
- `/start` gives new users a fitting **welcome** and orients them, role-aware where relevant (`ctx.t(isAdmin ? "start-admin" : "start-guest")`). If it launches a setup wizard, guard it so an already-configured user gets help instead of re-running setup.

## Menu / UI hygiene
- **Inline keyboards** for anything with choices; clear paths and short explanations for complex flows.
- **Callback-data discipline:** central constants or a typed encode/decode codec, under Telegram's **64-byte** limit.
- **Back buttons** (`← Back`) on nested menus; an explicit **close** (`✖`) that **edits the message to a "closed" state and drops the keyboard**, or deletes it. No stale menus left in the chat.
- Always call **`answerCallbackQuery()`** after a button; prefer `editMessageText` over new messages.

## Free-text input
- Ask for free text **in chat** only when genuinely needed (a name, a note), via a bounded pattern: **command-prefixed entry points + a last-registered "unknown input" fallback** replying only to otherwise-unconsumed private text, or a **persisted pending step + intercept middleware** routing the next message. Prompt with a cancel button. No heavyweight conversations plugin for simple prompts.
