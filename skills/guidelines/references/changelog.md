# In-app changelog

Guidelines for an in-app changelog view, visible to end users, distinct from the repo's `CHANGELOG.md` (the project's own history, written at release). A ready-to-reskin implementation is `references/changelog-template.html` in this skill.

## Presence & access (required)
- Built into the app itself (its own page/view/window), not a link out to a repo file or external page.
- Reachable from Settings and from anywhere the app shows the current version or the update control (see `web-app-pwa.md`); the version display doubles as an entry point.

## Look & structure
- Styled in the app's own design language, not a raw markdown dump.
- Each **release is its own visually distinct block** (card, bordered section); scannable, not a wall of text.
- Within a release, entries are tagged **Added / Changed / Fixed** (Keep a Changelog).
- Each entry carries the **ticket number** and the **release version** it shipped in.

## Finding things
- **Search:** plain substring search that **highlights the match** and **filters the view to matching entries**. No fuzzy search, no client-side index.
- **Filter by version:** a single version or a from/to **range**, populated from the manifest without touching an archive.

## Data & loading: static chunks, no endpoint
Build-time artefacts, not a runtime route. The changelog only changes on deploy, so parsing per request is work for a constant result, and on a scale-to-zero platform an endpoint means viewing the changelog **wakes the app and costs money**. A static asset the service worker precaches costs nothing.

Generate from `CHANGELOG.md` and its archives at build time into the static asset directory (gitignored; the markdown is the source):
- `changelog-index.json`: the manifest, the version list plus which file holds which range. A few hundred bytes; fills the version filter **without loading any archive**.
- `changelog-<range>.json`: one chunk per markdown file.

**Chunks, not one file, because of caching:** once a major is closed its chunk never changes; cache it forever (`immutable`, or SW CacheFirst). One combined file would be invalidated by every release. One file per version would be too fine: a search would need a request per version.

**Loading:** open with the manifest plus the current major. A version filter reaching further back loads exactly the archive the manifest names. A search loads the remaining chunks once, with a visible loading state, then they are cached. Measured: ~19 KB gzip for a 20-release major, ~95 KB for a hundred releases fetched once.

## Entry length
The collapsed summary is **one line in a handful of words**, the expanded description **one or two sentences**. Longer only for a breaking or genuinely large change. Verbose entries measured ~2.3 KB per release, twice what is needed, compounding with every version.

## Splitting, and where the archives live
`CHANGELOG.md` in the repo root holds the **current major**; older entries move to `docs/changelog/<major>.x.md` at a major bump, or `<from>-<to>.md` at a minor boundary if a major passes ~50 KB. Cuts land on version headings, so a release is never split across files. The current file stays in the root because the ecosystem looks there (Keep a Changelog, GitHub release links, npm); archives belong under `docs/`.

**Document the split in four places**, or a reader takes the root file for the whole history: a line at the **top** of `CHANGELOG.md`, a header in each archive naming its range and linking back, this guideline, and `CONTRIBUTING.md`.

## Maintenance (required)
- Update the changelog on **every release**, same discipline as the version bump. Structure entries as Added/Changed/Fixed with a ticket ID so they map onto the in-app view; conventional-commit grouping (feat → Added, fix → Fixed, everything else → Changed) is the natural source. Don't hand-author two divergent changelogs.

## Template
`references/changelog-template.html` is self-contained (no build step, no dependencies): expandable change cards with version/category/ticket tags, group-by-version or by-category toggle, highlighting search that filters to matches, a version-range filter, and cursor-paginated infinite scroll against a JSON API documented in the file's header comment.

Its palette is deliberately **neutral, a starting point to replace**. The header comment carries the full adapt/keep list; in short:
- **Adapt:** every token in the `APP THEME` block (surfaces, ink, lines, accent, radius, type stacks) in all four places they're declared, the masthead copy, the two endpoint constants, spacing/shadow to match the app. Delete the demo data once wired up.
- **Keep:** four mutually distinguishable category colors used consistently and distinct from the accent (which marks versions); a highlight color distinct from all of them; both themes with the `[data-theme]` overrides intact; the card reading order (summary → description → tags) and tag order (version, category, ticket); the heading logic (headings drop away under search, version headings also under a version filter, since the cards' tags already carry that).

The full feature set is the standard for new work; a lighter changelog (e.g. a static `changelog.json` with one version select, no search or pagination) is acceptable only for a stated reason.
