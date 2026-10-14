# AI integration (Claude Agent SDK)

Standing guidelines for any app that integrates AI features. Prior art: `cshop` and `octofood`, both integrating the Claude Agent SDK in production; gaps against them are flagged below.

## Stack (required)
- Build AI integration on the **Claude Agent SDK**, not a hand-rolled API client.

## Two auth modes, one deployment choice
- Support **both** a subscription token (`CLAUDE_CODE_OAUTH_TOKEN`, from `claude setup-token`) **and** a raw API key (`ANTHROPIC_API_KEY`); the deployment sets **exactly one** via env vars. Fail loudly at startup if both or neither are set; don't silently pick one. Prefer subscription as the default where available (no metered surprises); API key is the fallback for a deployment with no subscription to lean on.

## AI infrastructure behind interfaces (required)
- Put the entire AI integration (model calls, prompts, tool wiring) behind a **project-defined interface**, as `railway.md` requires for platform specifics. Swapping models, providers or SDK versions stays a single adapter change.

## Mark AI features clearly (required)
- Anything AI-driven is **clearly labeled as such** in the UI; a user should never be unsure whether a feature is human-authored or AI.
- Technique (from `octofood`): a fixed, consistent visual marker (small badge/icon) on AI-generated or AI-estimated content, shown **everywhere that content appears** (list, detail, edit view), plus a **live status string** while the call runs ("Estimating nutrients…") instead of a generic spinner.

## Budgets in API-token mode (required)
- **Settings** must let the user cap spend with **daily, weekly and monthly maximum budgets**; once exceeded, the app **blocks new AI requests** until the window resets. Don't just log the overage.
- **A backstop, not the only guardrail:** also set a spend cap at the provider (Anthropic Console). The app can't perfectly police cost across concurrent in-flight requests, so the provider-side cap bounds worst-case spend; the in-app budget is the user-facing control on top.
- Subscription mode has no local spend to cap; show the provider's own usage window instead.

## Usage transparency (required)
- Show **usage-limit and token consumption** prominently in the app's menu, styled the way Claude Code shows it: a persistent, glanceable indicator, not buried in a settings sub-page.

## AI transcripts (required)
- The user (and Claude, for debugging/testing) must be able to inspect what the AI actually did, for every AI feature, not just multi-step ones. `cshop`'s "AI Activity Feed" is the reference; `octofood` has no transcript viewer, a gap to close, not a reason to skip transcripts for simple calls.
  - **Chat-style** features: the transcript is a standard, always-visible part of the UI.
  - **Non-chat, workflow-style** features: a **separate window/popup** where the running (and just-completed) workflow can be watched step by step, available while it runs and at minimum until the user navigates away.
- **Style transcripts like the Claude Code app:** collapsed, summarizing headers for each tool call, thinking phase and output block; each expandable, with a popup for a tool call's full input/output.
- **Raw model text/thinking is opt-in**, behind an explicit "show raw output" toggle.

## Working indicator + cancel (required)
- Show the user **that the AI is currently working**, and provide a **cancel button that actually interrupts** the in-flight work end to end (client abort signal → server route → engine call, e.g. `AbortController`), not just hides the UI while it keeps running and billing. Only `cshop` has this end to end; build both from the start.

## Access-control interlock
- If the app is internet-reachable and uses a metered AI engine, don't let it start with no access gate configured (see the access-control note in `web-app-pwa.md`). Cost risk and access control are one decision.
