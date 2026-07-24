# AI integration (Claude Agent SDK)

Standing preferences for any app that integrates AI features. Referenced prior art: `cshop` and `octofood` (both work in progress — not everything below is already implemented there).

## Stack (required)
- Build AI integration on the **Claude Agent SDK**, not a hand-rolled API client.

## Two auth modes, one deployment choice
- Support **both** a subscription-based login **and** a raw API token; the deployment sets **one of the two** via env vars, not both at once.

## AI infrastructure behind interfaces (required)
- Put the entire AI integration — model calls, prompts, tool wiring — behind a **project-defined interface**, the same way `railway.md` requires for platform specifics. The rest of the app depends on that interface, so swapping models, providers, or SDK versions later stays a single adapter change.

## Mark AI features clearly (required)
- Anything AI-driven is **clearly labeled as such** in the UI — a user should never be unsure whether they're talking to a human-authored feature or an AI one.

## Budgets in API-token mode (required)
- When running in API-token mode, **Settings** must let the user cap spend with **daily, weekly, and monthly maximum budgets** that the app enforces — it must not let usage exceed them.

## Usage transparency (required)
- Show **usage-limit and token-consumption** prominently in the app's menu — styled the way Claude Code itself shows it (a persistent, glanceable indicator, not buried in a settings sub-page).

## AI transcripts (required)
- The user (and Claude, for debugging/testing) must be able to inspect what the AI actually did:
  - For **chat-style** AI features, the transcript is a standard, always-visible part of that UI.
  - For **non-chat, workflow-style** AI features, provide a **separate window/popup** where the running (and just-completed) AI workflow can be watched step by step — available while it runs, and at minimum until the user navigates away.
- **Style transcripts like the Claude Code app:** collapsed, summarizing headers for each tool call, each thinking phase, and each output block; each expandable, with a popup available for a tool call's full input/output when the summary isn't enough.

## Working indicator + cancel (required)
- Any AI feature must show the user **that the AI is currently working**, and provide a **cancel button that actually interrupts** the in-flight AI work — not just hides the UI while it keeps running in the background.
