# Web apps / PWAs

Standing preferences for any browser-delivered app (SPA or installable PWA).

## Version visibility (required)
- The app **always shows its version** somewhere unobtrusive but reachable — an About/Settings screen, a footer, or a menu line. Show a human-readable version **plus** the exact build (`v1.4.2 · a1b9c3f` — semver + short git sha), so a bug report pins the exact deployed build.
- Inject the version at build time (e.g. from `package.json` + `git rev-parse --short HEAD` into an env/define constant) — never hand-maintain it.

## Manual update control (required)
- Provide a visible **"Check for updates"** button (next to the version). Users on a cached PWA can otherwise sit on a stale build for days; the button gives them an explicit way out without hunting through browser menus.
- The button drives the service-worker update flow: `registration.update()` → if a worker is `waiting`, `postMessage({type:'SKIP_WAITING'})` → on `controllerchange`, reload. If already current, say so ("You're on the latest version").
- Also **detect updates passively**: when the SW reports a `waiting` worker (new build deployed), surface a non-intrusive "Update available — reload" banner. The manual button and the banner share the same apply path.

## Update UX
- Never hard-reload out from under the user mid-action — offer the reload, let them take it.
- After an update applies, briefly confirm the new version (so the version display doubles as "did my update work?").
- Prefer an app-shell caching strategy where the shell is cache-first and data is network-first (or stale-while-revalidate), so an update swaps the shell cleanly without stale data lingering.

## General
- Design offline-tolerant where it's cheap: cache the shell and the last-known data, show a clear offline indicator rather than a broken screen.
- Keep the installable manifest (name, icons, theme color, display mode) accurate — it's the app's identity on the home screen.

## Local persisted client state (localStorage / IndexedDB)
- **Version it**: store a `SETTINGS_VERSION` (and, if the shape can change in incompatible ways, a `MIN_COMPATIBLE_VERSION`) alongside the data. On load, **merge** stored values into the current defaults field-by-field rather than overwriting — new fields silently get sane defaults, no reset/data loss on upgrade.
- **Validate on read**: run anything read back from local storage through a type guard before use; drop/ignore entries that fail validation (manual edits, corruption, an old shape) instead of crashing or propagating bad data.
- Writes should fail silently (try/catch) on quota exhaustion — don't let a full storage quota break the app.

## "Data changed on the server" signal
- For any endpoint serving semi-static data (not just map tiles — any list/config/content that changes occasionally), have it return an **`X-Data-Version`** header (e.g. the source file's mtime) or an **ETag**. The client stores the last-seen version and shows a lightweight **"data as of … · refresh"** affordance when it differs, instead of polling or silently refetching. Keeps the UI honest about staleness without constant background traffic.
