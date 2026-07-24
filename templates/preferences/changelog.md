# In-app changelog

Standing preferences for an in-app changelog view — visible to end users, distinct from the repo's `CHANGELOG.md` (which `/release` maintains for the project's own history). A ready-to-reskin implementation ships at `templates/ui/changelog-template.html`.

## Presence & access (required)
- The changelog is built into the app itself — its own page/view/window — not a link out to a repo file or external page.
- Reachable from Settings, and from anywhere else the app already shows the current version or the update control (see `web-app-pwa.md`) — the version display doubles as an entry point into the changelog.

## Look & structure
- Styled in the app's own design language, not a raw markdown dump.
- Each **release is its own visually distinct block/segment** (a card, a bordered section) — scannable, not a wall of text.
- Within a release, entries are tagged **Added / Changed / Fixed** (Keep a Changelog categories).
- Each entry carries the **ticket number** and the **release version** it shipped in.

## Finding things
- **Search:** a plain substring search that **highlights the match** in each entry's text and **filters the view down to only the entries that matched** — no fuzzy search, no client-side index, just substring + highlight + filter.
- **Filter by version:** either a single specific version, or a from/to **range** of versions.

## Data & loading
- Changes are stored in a **backend source**, fetched dynamically — not bundled into the client build. This keeps the changelog editable without a redeploy and keeps the initial payload small.
- **Paginate** — load more on scroll (infinite scroll) — rather than shipping the full history at once, to keep bandwidth down (see `web-app-pwa.md`'s bandwidth-conscious caching). Search and version filters run **server-side** too, so pagination and bandwidth savings hold even while filtering.

## Maintenance (required)
- The changelog is updated as part of **every release**, same discipline as the version bump (see `/release`). Structure new entries as Added/Changed/Fixed with a ticket ID so they map directly onto the in-app view — `/release`'s existing conventional-commit grouping (feat → Added, fix → Fixed, everything else → Changed) is the natural source; don't hand-author two divergent changelogs.

## Template
- `templates/ui/changelog-template.html` is a self-contained (no build step, no dependencies) implementation of all of the above: release cards, Added/Changed/Fixed tags, highlighting search with entry-level filtering, version-range filter, and cursor-paginated infinite scroll against a documented JSON API (the contract is in the file's header comment). Re-skinning it means replacing the CSS custom properties at the top of the file with the app's real design tokens and pointing the two endpoint constants at the real backend routes — the structure and behavior don't need to change.

## Scale it to the project
Everything above is the target shape for a project where change volume or user count justifies it. A smaller project shipping a lighter version is a legitimate call, not a shortfall — e.g. a static `changelog.json` generated at build time (parse `CHANGELOG.md`'s existing version/date headings, skip the backend endpoint entirely) instead of a paginated backend, a single version-select filter instead of search/range, plain rendered markdown headings instead of colored category tags. `octofood` ships exactly this lighter version today. Grow into the fuller shape (search, backend pagination, structured type/ticket fields) once the changelog is actually big enough, or gets enough traffic, for those to earn their cost.
