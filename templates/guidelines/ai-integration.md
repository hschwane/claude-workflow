# AI integration (Claude Agent SDK)

Standing preferences for any app that integrates AI features. Referenced prior art: `cshop` and `octofood` — both integrate the Claude Agent SDK in production; specifics below are cross-checked against both and flagged where they diverge or where a requirement goes beyond what's shipped today.

## Stack (required)
- Build AI integration on the **Claude Agent SDK**, not a hand-rolled API client.

## Two auth modes, one deployment choice (confirmed: cshop, octofood)
- Support **both** a subscription token (`CLAUDE_CODE_OAUTH_TOKEN`, from `claude setup-token`) **and** a raw API key (`ANTHROPIC_API_KEY`); the deployment sets **exactly one** via env vars. Fail loudly at startup if both or neither are set — don't silently pick one. Prefer subscription as the default where available (no metered surprises); API-key is the fallback for a deployment with no subscription to lean on.

## AI infrastructure behind interfaces (required)
- Put the entire AI integration — model calls, prompts, tool wiring — behind a **project-defined interface**, the same way `railway.md` requires for platform specifics. The rest of the app depends on that interface, so swapping models, providers, or SDK versions later stays a single adapter change.

## Mark AI features clearly (required)
- Anything AI-driven is **clearly labeled as such** in the UI — a user should never be unsure whether they're talking to a human-authored feature or an AI one.
- **Concrete technique** (seen in `octofood`): a fixed, consistent visual marker (a small badge/icon) on AI-generated or AI-estimated content, shown **everywhere that content appears** — list, detail, edit view, not just where it was created — plus a **live status string** while the call is running (e.g. "Estimating nutrients…") instead of a generic spinner.

## Budgets in API-token mode (required)
- When running in API-token mode, **Settings** must let the user cap spend with **daily, weekly, and monthly maximum budgets**; once a budget is exceeded, the app **blocks new AI requests** until the window resets — don't just log the overage and keep going.
- **This is a backstop, not the only guardrail:** also set a spend cap directly at the provider (the Anthropic Console) as the real ops-side safety net. The app can't perfectly police cost across concurrent in-flight requests in real time, so the provider-side cap is what actually bounds worst-case spend — the in-app budget is the user-facing control layered on top of it.
- Subscription mode has no local spend to cap — show the provider's own usage window (see Usage transparency) instead of a budget control.

## Usage transparency (required)
- Show **usage-limit and token-consumption** prominently in the app's menu — styled the way Claude Code itself shows it (a persistent, glanceable indicator, not buried in a settings sub-page).

## AI transcripts (required)
- The user (and Claude, for debugging/testing) must be able to inspect what the AI actually did — for every AI feature, not just multi-step ones. `cshop`'s "AI Activity Feed" is the reference implementation; `octofood`'s AI calls have no transcript viewer at all today — that's a gap in `octofood` to close, not a reason to treat transcripts as optional for simpler/single-shot calls.
  - For **chat-style** AI features, the transcript is a standard, always-visible part of that UI.
  - For **non-chat, workflow-style** AI features, provide a **separate window/popup** where the running (and just-completed) AI workflow can be watched step by step — available while it runs, and at minimum until the user navigates away.
- **Style transcripts like the Claude Code app:** collapsed, summarizing headers for each tool call, each thinking phase, and each output block; each expandable, with a popup available for a tool call's full input/output when the summary isn't enough.
- **Raw model text/thinking is opt-in, not on by default:** stream it behind an explicit "show raw output" toggle rather than always rendering it — keeps the default view readable and doesn't spell out full prompts/outputs unless someone actually wants them.

## Working indicator + cancel (required)
- Any AI feature must show the user **that the AI is currently working**, and provide a **cancel button that actually interrupts** the in-flight AI work end-to-end (client abort signal → server route → engine call, e.g. via `AbortController`) — not just hide the UI while it keeps running and billing in the background. This is the newer, stronger bar: only `cshop` has it end-to-end today, `octofood` has the working indicator but no cancel yet — build both from the start rather than treating cancel as a later add-on.

## Access-control interlock
- If the app is reachable on the internet and uses a metered AI engine, don't let it start with no access gate configured — see the access-control note in `web-app-pwa.md`. Cost risk and access control are the same decision here, not two separate ones.
