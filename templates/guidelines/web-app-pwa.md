# Web apps / PWAs

Standing preferences for any browser-delivered app (SPA or installable PWA).

## Version visibility (required)
- The app **always shows its version** somewhere unobtrusive but reachable — an About/Settings screen, a footer, or a menu line. Show a human-readable version **plus** the exact build (`v1.4.2 · a1b9c3f` — semver + short git sha), so a bug report pins the exact deployed build.
- Inject the version at build time (e.g. from `package.json` + `git rev-parse --short HEAD` into an env/define constant) — never hand-maintain it.

## Manual update control (required)
- Provide a visible **"Check for updates"** button (next to the version). Users on a cached PWA can otherwise sit on a stale build for days; the button gives them an explicit way out without hunting through browser menus.
- The button drives the service-worker update flow: `registration.update()` → if a worker is `waiting`, `postMessage({type:'SKIP_WAITING'})` → on `controllerchange`, reload. If already current, say so ("You're on the latest version").
- **The button always gives visible feedback**, from click to outcome — a busy/checking state while it runs, then one clear result: update found and installed, already on the latest version, or the check/update failed (show the error, don't fail silently). The user must never be left wondering whether the click did anything.
- Also **detect updates passively**: when the SW reports a `waiting` worker (new build deployed), surface a banner **pinned to the top of the screen** with an explicit **"Update now"** button — not just a passive notice. The manual button and the banner share the same apply path.

## Update UX
- Never hard-reload out from under the user mid-action — offer the reload, let them take it.
- After an update applies, briefly confirm the new version (so the version display doubles as "did my update work?").
- Prefer an app-shell caching strategy where the shell is cache-first and data is network-first (or stale-while-revalidate), so an update swaps the shell cleanly without stale data lingering.

## General
- Design offline-tolerant where it's cheap: cache the shell and the last-known data, show a clear offline indicator rather than a broken screen.
- Keep the installable manifest (name, icons, theme color, display mode) accurate — it's the app's identity on the home screen.
- **Cache all static and semi-static data locally**, not just the app shell — anything that doesn't change every request. Only refetch what the "Data changed on the server" signal below actually flags as stale; minimizing bandwidth is the point, not just offline support.
- Consider routing frontend logs through the backend's logging pipeline (see `logging.md`) when it would meaningfully ease debugging — e.g. a single-user app where you can't ask the user for their browser console.

## Access control for private single-user apps (required)
An app built for personal/single-user use, deployed somewhere internet-reachable, gets a **password gate by default**. Without it, the API surface is open to anyone who finds the URL — and strangers hitting it costs real money (bandwidth, scale-to-zero wake-ups, compute), not just a theoretical risk. Put the password in a **deployment env var** so it can be switched off explicitly (e.g. a local/offline deployment that was never internet-reachable in the first place doesn't need the gate).

**Implementation shape** (seen in production in `cshop`): gate the **API routes only**, not the static shell — the app's own login view still needs to load publicly. Support two auth paths so both a browser and a script can get in: a signed **session cookie** issued on login, and a stateless **Bearer-token** header for scripts/smoke-tests (this is what lets Claude keep smoke-testing a gated app — see `app-baseline.md`). Compare the secret in **constant time**, rate-limit failed attempts per IP, and require a CSRF check on cookie-authorized state-changing requests.

**Tie it to AI spend risk:** if the app also integrates a metered AI engine (see `ai-integration.md`), refuse to start when that engine is selected with no access gate configured — fail loud at boot instead of silently exposing a billable endpoint. Give the operator an explicit override env var for the rare case they genuinely want it open.

## Local persisted client state (localStorage / IndexedDB)
- **Version it**: store a `SETTINGS_VERSION` (and, if the shape can change in incompatible ways, a `MIN_COMPATIBLE_VERSION`) alongside the data. On load, **merge** stored values into the current defaults field-by-field rather than overwriting — new fields silently get sane defaults, no reset/data loss on upgrade.
- **Validate on read**: run anything read back from local storage through a type guard before use; drop/ignore entries that fail validation (manual edits, corruption, an old shape) instead of crashing or propagating bad data.
- Writes should fail silently (try/catch) on quota exhaustion — don't let a full storage quota break the app.

## "Data changed on the server" signal
- For any endpoint serving semi-static data (not just map tiles — any list/config/content that changes occasionally), have it return an **`X-Data-Version`** header (e.g. the source file's mtime) or an **ETag**. The client stores the last-seen version and shows a lightweight **"data as of … · refresh"** affordance when it differs, instead of polling or silently refetching. Keeps the UI honest about staleness without constant background traffic.
