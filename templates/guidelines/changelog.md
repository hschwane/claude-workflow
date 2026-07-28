# In-app changelog

Standing guidelines for an in-app changelog view — visible to end users, distinct from the repo's `CHANGELOG.md` (which `/release` maintains for the project's own history). A ready-to-reskin implementation ships with this guideline at `.claude/ui/changelog-template.html`.

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
- **Filter by version:** either a single specific version, or a from/to **range**. The manifest supplies the list, so the dropdown is populated without touching an archive.

## Data & loading — static chunks, no endpoint

Build-time artefacts, not a runtime route. The changelog only changes on deploy, so parsing it per request is work for a result that is constant between deploys — and on a scale-to-zero platform an endpoint means viewing the changelog **wakes the app and costs money**. A static asset the service worker precaches costs nothing at all.

Generate from `CHANGELOG.md` and its archives at build time, into the app's static asset directory (gitignored — the markdown is the source):

- `changelog-index.json` — the manifest: the version list plus which file holds which range. A few hundred bytes; it fills the version filter **without loading any archive**.
- `changelog-<range>.json` — one chunk per markdown file, mirroring the same split.

**Chunks, not one file, because of caching:** once a major is closed its chunk never changes again — load it once, cache it forever (`immutable`, or SW CacheFirst). A single combined file would be invalidated by *every* release, so a user re-downloads the entire history because one line was added. One file per version would be too fine: a search would need a request per version.

**Loading:** open with the manifest plus the current major. A version filter reaching further back loads exactly the archive the manifest names. A search loads the remaining chunks once — with a visible loading state, since it is a deliberate action — and after that they are cached. Measured against a real project: ~19 KB gzip for a 20-release major, ~95 KB for a hundred releases of full history fetched once, ever.

## Entry length
Keep both layers short: the collapsed summary is **one line in a handful of words**, the expanded description **one or two sentences**. A longer explanation is for a breaking or genuinely large change only. Measured on a real project, verbose entries drove ~2.3 KB per release — twice what is needed, and it compounds with every version.

## Splitting, and where the archives live
`CHANGELOG.md` in the repo root holds the **current major**; older entries move to `docs/changelog/<major>.x.md` at a major bump, or to `<from>-<to>.md` at a minor boundary if a single major passes ~50 KB. Cuts land on version headings, so a release is never split across two files.

The current file stays in the root because that is where the ecosystem looks for it — Keep a Changelog, GitHub's release links, npm packaging. Nobody looks in the root for `1.x.md`, so the archives belong under `docs/`.

**Document the split in four places**, or a reader will take the root file for the whole history: a line at the **top** of `CHANGELOG.md` (not only the bottom), a header in each archive naming its range and linking back, this guideline, and `CONTRIBUTING.md`.

## Maintenance (required)
- The changelog is updated as part of **every release**, same discipline as the version bump (see `/release`). Structure new entries as Added/Changed/Fixed with a ticket ID so they map directly onto the in-app view — `/release`'s existing conventional-commit grouping (feat → Added, fix → Fixed, everything else → Changed) is the natural source; don't hand-author two divergent changelogs.

## Template
`.claude/ui/changelog-template.html` is a self-contained (no build step, no dependencies) implementation of all of the above: expandable change cards with version/category/ticket tags, a group-by-version or group-by-category toggle, highlighting search that filters to matching entries, a version-range filter, and cursor-paginated infinite scroll against a documented JSON API (the contract is in the file's header comment).

Its palette is deliberately **neutral — a starting point to replace, not a look to keep**. The file's header comment carries the full adapt/keep list; in short:

- **Adapt:** every token in the `APP THEME` block (surfaces, ink, lines, accent, radius, type stacks) in all four places they're declared, the masthead copy, the two endpoint constants, and spacing/shadow to match the app's other surfaces. Delete the demo data once wired up.
- **Keep:** four mutually distinguishable category colors, used consistently wherever a category appears and distinct from the accent (which marks versions); a highlight color distinct from all of them; both themes with the `[data-theme]` overrides intact; the card's reading order (summary → description → tags) and tag order (version, category, ticket); and the heading logic — headings drop away under search, version headings also under a version filter, because the cards' own tags already carry that.

## Known gap in the reference projects
`octofood`'s in-app changelog today is lighter than everything above — a static `changelog.json` generated at build time, a single version-select filter, no search, no pagination, no structured type/ticket fields. That's a gap to close there, not a model to copy: the full feature set above is the standard for new work. Skipping part of it is only legitimate the normal way — a deliberate, stated reason recorded via `/plan` (see the guidelines `README.md`), not by default because a past project shipped less.
