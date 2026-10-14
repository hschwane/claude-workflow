# Web apps / PWAs

Guidelines for any browser-delivered app (SPA or installable PWA).

## Version visibility (required)
- The app **always shows its version**, unobtrusive but reachable (About/Settings, footer, menu line): a human-readable version **plus** the exact build (`v1.4.2 · a1b9c3f`, semver + short git sha), so a bug report pins the deployed build.
- Inject it at build time (`package.json` + `git rev-parse --short HEAD` into an env/define constant), never hand-maintain it.

## Manual update control (required)
- A visible **"Check for updates"** button next to the version. Users on a cached PWA can otherwise sit on a stale build for days.
- It drives the service-worker update flow: `registration.update()` → if a worker is `waiting`, `postMessage({type:'SKIP_WAITING'})` → on `controllerchange`, reload. If already current, say so ("You're on the latest version").
- **Always visible feedback**, click to outcome: a checking state, then one clear result (update installed, already latest, or failed with the error shown). Never leave the user wondering whether the click did anything.
- Also **detect updates passively**: when the SW reports a `waiting` worker, show a banner **pinned to the top of the screen** with an explicit **"Update now"** button. Button and banner share one apply path.

## Update UX
- Never hard-reload out from under the user mid-action; offer the reload.
- After an update applies, briefly confirm the new version.
- Prefer a cache-first app shell with network-first (or stale-while-revalidate) data, so an update swaps the shell cleanly without stale data lingering.

## General
- Offline-tolerant where cheap: cache the shell and last-known data, show a clear offline indicator rather than a broken screen.
- Keep the installable manifest (name, icons, theme color, display mode) accurate; it's the app's identity on the home screen.
- **Cache all static and semi-static data locally**, not just the shell. Refetch only what the "Data changed on the server" signal below flags as stale; minimizing bandwidth is the point, not just offline support.
- Consider routing frontend logs through the backend's logging pipeline (`logging.md`) when it eases debugging, e.g. a single-user app where you can't ask for the browser console.

## Access control for private single-user apps (required)
An app for personal/single-user use, deployed somewhere internet-reachable, gets a **password gate by default**. Without it the API is open to anyone who finds the URL, and strangers cost real money (bandwidth, scale-to-zero wake-ups, compute). Put the password in a **deployment env var** so it can be switched off explicitly (e.g. a local deployment never internet-reachable).

**Implementation shape** (in production in `cshop`): gate the **API routes only**, not the static shell (the login view must load publicly). Support two paths: a signed **session cookie** issued on login, and a stateless **Bearer-token** header for scripts/smoke-tests (what lets Claude keep smoke-testing a gated app; see `app-baseline.md`). Compare the secret in **constant time**, rate-limit failed attempts per IP, and require a CSRF check on cookie-authorized state-changing requests.

**Tie it to AI spend risk:** if the app integrates a metered AI engine (`ai-integration.md`), refuse to start when that engine is selected with no access gate; fail loud at boot. Give the operator an explicit override env var for the rare case they want it open.

## Local persisted client state (localStorage / IndexedDB)
- **Version it:** store a `SETTINGS_VERSION` (and a `MIN_COMPATIBLE_VERSION` if the shape can change incompatibly) with the data. On load, **merge** stored values into current defaults field by field, so new fields get sane defaults with no reset or data loss.
- **Validate on read:** run anything read back through a type guard; drop entries that fail (manual edits, corruption, old shape) instead of crashing.
- Writes fail silently (try/catch) on quota exhaustion; a full quota must not break the app.

## "Data changed on the server" signal
- Any endpoint serving semi-static data (lists, config, content that changes occasionally, not just map tiles) returns an **`X-Data-Version`** header (e.g. source file mtime) or an **ETag**. The client stores the last-seen version and shows a lightweight **"data as of … · refresh"** affordance when it differs, instead of polling or silently refetching.
