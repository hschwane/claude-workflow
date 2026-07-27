# Maps (interactive map UX)

Standing preferences for interactive maps. Extracted from the island-planner map (imperative Leaflet + PWA), generalized.

## Library
- **Leaflet** is the default for raster/tile maps — used **imperatively** (`L.map(...)`, own layers/effects) rather than through wrapper JSX components, so marker/layer updates stay under direct control. Reach for MapLibre GL / vector rendering only when you genuinely need GPU vector styling.
- Keep the map behind the app's own component; don't scatter Leaflet calls across the codebase.

## Local tile/data caching + update-when-changed (required)
- Cache map data locally via a **service worker (Workbox)**:
  - **Tiles** (raster basemaps, vector pmtiles) → **CacheFirst** with a long max-age and a large `maxEntries`; allow opaque responses (`cacheableResponse` statuses `[0,200]`, `[0,200,206]` for range requests). Tiles rarely change, so cache-first is correct.
  - **API/data** → **NetworkFirst** with a short `networkTimeoutSeconds` so online always gets fresh data but offline still works.
- **Update when the server changed:** because tiles are CacheFirst they won't auto-refresh, so make invalidation explicit:
  - Version dynamic data with a **`X-Data-Version` header** (e.g. the data file's mtime). The client stores the last seen version, shows a **"data as of …" line + a "refresh now" button**, and re-fetches when it differs. Pass upstream **ETag** through on tile proxies.
  - For a cached map region, "refresh" = **delete the region's cached tiles, then re-download** (CacheFirst won't revalidate on its own). Bake a `?v=` cache-buster into self-hosted tile bundle URLs when the bundle changes.

## Manual offline maps (when offline use matters)
- Support **pre-downloading regions for offline**: predefined named areas (bounding boxes) **and** the ability to enter/select a custom area, with zoom presets (overview / standard / detail). Compute the slippy tile ranges, pre-`fetch` them (modest concurrency, `cache:'reload'`, `mode:'no-cors'`) so the SW caches them; cap the tile count and show an estimated size + a progress bar.
- **Region management:** persist saved regions (localStorage), list them with **refresh / delete**, show storage usage vs quota (`navigator.storage.estimate()`), request **persistent storage** on mount, and offer "clear tile cache".

## Markers & clustering
- Render pins as **`L.divIcon`** (styled HTML — emoji/icon in a circle) rather than image markers: cheap to theme, easy state rings (selected = accent ring, favorite = gold). Make marker size configurable (S/M/L).
- **Cluster markers** with `leaflet.markercluster`, and **expose the de-cluster zoom in the settings menu** — a "cluster markers" toggle plus a **"single markers from zoom N" slider** (`disableClusteringAtZoom`, sensible default ~11, range ~7–16). `showCoverageOnHover:false`.
- **Performance when clustering is off:** viewport-cull — only add markers within `map.getBounds().pad(…)`, rebuilt on `moveend`/`zoomend`. Update a marker's selection state with **`setIcon` (don't rebuild the layer)**.

## Mobile UI layout (map apps)
- **Controls: a vertical FAB stack, top-right** (e.g. 🔍 search, ➤ my-location, ⚙ settings), ~44px targets; sub-popovers open to the **left** of the stack.
- **Search: an expandable/collapsible overlay** toggled by the search FAB (not a permanently docked bar). On mobile it stretches to `width: calc(100% - <fab gutter>)` so it never collides with the FAB stack; opening it collapses any open detail sheet.
- **Details: a draggable bottom sheet** with snap points (e.g. `[15,30,50,100]` vh) and a drag-below-threshold-to-close; use a **non-passive `touchmove`** so dragging the sheet doesn't trigger the browser's pull-to-refresh. When a sheet is open, **offset map centering by half the sheet height** so the selected pin isn't hidden behind it. Hide the bottom nav bar while a sheet is open.

## Tooltips / hover (desktop) + tap (mobile), performantly
- **Use one shared, manually-positioned tooltip `<div>`**, not per-marker `bindTooltip`/`bindPopup` — a single DOM node scales to many markers.
- **Desktop:** on `mousemove`, compose the tooltip and follow the cursor; hide on `mouseout`.
- **Mobile/touch** (detect once via `matchMedia('(hover:none),(pointer:coarse)')`): no hover — a **tap pins the tooltip to the geo-position** (re-anchored on `move`/`zoom`), tapping again closes it.
- **Throttle/debounce the expensive lookups** feeding the tooltip (e.g. vector-feature picking throttled ~100 ms and cached; elevation/network lookups debounced ~250–300 ms and cached). Query vector features via a single map-level pick, not per-feature Leaflet handlers.

## Settings menu
- Keep map behavior in a settings panel persisted to localStorage: basemap style, relief/overlay toggles, **clustering + cluster-zoom**, marker size, offline-maps section, data-version/refresh, and app-version/PWA-update controls (see `web-app-pwa.md`). Provide an on-map legend toggle.
