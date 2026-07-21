# Plots & graphs (data-viz UX)

Standing preferences for charts/graphs (time-series, bar, line, field/heat overlays). Extracted from the island-planner weather charts, generalized to best practice.

## Library vs hand-rolled
- For a **small number of specific, controlled charts**, a hand-rolled **inline SVG** component (line/bar) is preferred over pulling in a charting library — full control of layout, hover, and theming, no dependency weight. The island-planner weather plot is one self-contained SVG component doing its own scaling + hover.
- Reach for a charting library only when you need many chart types or interactions you'd otherwise reinvent. If you do, wrap it in **one project chart component** so the rest of the app depends on your props, not the library.
- **Dense per-pixel visuals** (heat/field/gradient overlays, thousands of points) → `<canvas>` 2D (render into a small off-screen buffer, scale up), not SVG. Crisp interactive line charts → SVG.

## One component, size presets
- Model a chart as a self-contained component taking **raw parallel arrays + a window (e.g. `hours`) + a `large` boolean size preset** (compact inline vs enlarged). Do scaling, hover, and tooltip inside it.
- **Click-to-enlarge:** the compact inline chart opens a modal rendering the *same* component at the `large` preset — one implementation, two sizes.

## Axes, scaling, units
- **Auto-fit the value axis with a small padding** (e.g. `floor(min)-1 … ceil(max)+1`); label only the two extreme ticks to stay uncluttered.
- **Always show units** next to axes *and* in tooltips (°C, mm, m/s, %, …).
- **Time axis:** prefer **day-boundary gridlines** (a dashed vertical at each new calendar day, labeled "Today"/short weekday) over noisy per-timestamp ticks.
- **Combine related series in one chart** via stacked bands sharing the x/time axis (e.g. temperature line + precipitation bars + wind glyphs) instead of three separate charts. Decimate glyph-style series (`step = max(1, round(n/target))`) to avoid clutter.

## Color & theming
- **Split chrome from data:** axes, gridlines, crosshair, tooltip background/border use **theme tokens** (CSS custom properties that swap for light/dark); **series data colors are fixed semantic literals** (e.g. temp = orange, precip = blue) so a series keeps its meaning and stays readable in both themes.
- Assign series colors **by meaning, not by index**.
- For field/gradient visuals, define a **single scale** (`{min, max, unit, stops:[{v,color}], alphaFor}`) and derive everything from it: pixel colors (canvas), the CSS gradient, and an **auto-generated legend** (bar + ticks + unit). One source of truth keeps legend and rendering in sync.

## Interaction (hover / touch)
- Map pointer x → nearest data index (via the element's `getBoundingClientRect`), snap, and draw a **crosshair + point marker + tooltip** (formatted time + each value with units).
- **First-class touch:** handle `touchmove` with a **non-passive listener** (`{passive:false}` + `preventDefault`) so dragging across the chart reads values **without scrolling the page**; keep `touchstart` passive. Same hover path serves mouse and touch.
- Tooltip: absolutely positioned, `pointer-events:none`, horizontally centered on the point and clamped to stay in view.

## Honest states
- End-to-end **loading / error / empty** states: the data hook returns `{data, loading, error}` (reset on param change, guard against stale/unmounted updates with a `cancelled` flag); the view renders explicit "loading…", the error string, and "no data"; the chart itself guards `n < 2` → "no data".

## Accessibility & performance (do this too)
- Give the chart `role="img"` + a meaningful `aria-label`; expose glyph meaning via `<title>`/`aria-label`. **Add what the reference lacked:** keyboard navigation of the hover (arrow keys move the selected index) and a screen-reader-readable value readout or a visually-hidden data table — don't ship mouse/touch-only.
- Only optimize when it matters: plain SVG recomputed per render is fine for a few hundred points; **memoize** derived geometry (and downsample) once a window gets large or re-renders get hot. Prefer showing all points (no silent downsampling) until size forces it — and say so when you do downsample.
- Localize number/date formatting (locale-aware `toLocaleString`, fixed decimals, correct units and compass/direction labels).
