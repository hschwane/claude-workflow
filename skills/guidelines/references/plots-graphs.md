# Plots & graphs (data-viz UX)

Guidelines for charts/graphs (time-series, bar, line, field/heat overlays). Extracted from the island-planner weather charts, generalized.

## Library vs hand-rolled
- For a **small number of specific charts**, a hand-rolled **inline SVG** component (line/bar) is preferred over a charting library: full control of layout, hover and theming, no dependency weight.
- A charting library only when you need many chart types or interactions you'd otherwise reinvent. Then wrap it in **one project chart component** so the app depends on your props, not the library.
- **Dense per-pixel visuals** (heat/field/gradient overlays, thousands of points) → `<canvas>` 2D (small off-screen buffer, scaled up), not SVG. Crisp interactive line charts → SVG.

## One component, size presets
- A chart is a self-contained component taking **raw parallel arrays + a window (e.g. `hours`) + a `large` size preset**. Scaling, hover and tooltip live inside it.
- **Click-to-enlarge:** the compact inline chart opens a modal rendering the *same* component at `large`.

## Axes, scaling, units
- **Auto-fit the value axis with small padding** (`floor(min)-1 … ceil(max)+1`); label only the two extreme ticks.
- **Always show units** next to axes *and* in tooltips.
- **Ticks and gridlines track the data shown, not a fixed step:** derive density from the current window (few points → tick every point; wide window → a coarser, evenly spaced subset) so labels never overlap or under-fill.
- **Time axis:** prefer **day-boundary gridlines** (dashed vertical at each new day, labeled "Today"/short weekday) over per-timestamp ticks.
- **Combine related series in one chart** via stacked bands sharing the x/time axis (temperature line + precipitation bars + wind glyphs) instead of three charts. Decimate glyph series (`step = max(1, round(n/target))`).

## Color & theming
- **Split chrome from data:** axes, gridlines, crosshair, tooltip background/border use **theme tokens** (CSS custom properties swapping light/dark); **series colors are fixed semantic literals** (temp = orange, precip = blue) so a series keeps its meaning in both themes.
- Assign series colors **by meaning, not by index**.
- For field/gradient visuals, define a **single scale** (`{min, max, unit, stops:[{v,color}], alphaFor}`) and derive pixel colors (canvas), the CSS gradient and an **auto-generated legend** (bar + ticks + unit) from it.

## Interaction (hover / touch)
- Map pointer x → nearest data index (via `getBoundingClientRect`), snap, and draw a **crosshair + point marker + tooltip** (formatted time + each value with units).
- **First-class touch:** `touchmove` with a **non-passive listener** (`{passive:false}` + `preventDefault`) so dragging across the chart reads values **without scrolling the page**; `touchstart` stays passive. One hover path serves mouse and touch.
- Tooltip: absolutely positioned, `pointer-events:none`, centered on the point and clamped into view.

## Honest states
- End-to-end **loading / error / empty**: the data hook returns `{data, loading, error}` (reset on param change, guard stale/unmounted updates with a `cancelled` flag); the view renders "loading…", the error string and "no data"; the chart guards `n < 2` → "no data".

## Works on every targeted device (required)
- Fully usable on **every input device and screen size the project targets**. If that includes touch, small screens or keyboard-only: hover needs a touch equivalent, size presets stay legible and tappable (~44px) at the smallest breakpoint, and keyboard nav works without a mouse. Check the smallest and largest targeted screen.

## Accessibility & performance
- `role="img"` + a meaningful `aria-label`; expose glyph meaning via `<title>`/`aria-label`. Add **keyboard navigation of the hover** (arrow keys move the selected index) and a screen-reader value readout or visually-hidden data table.
- Optimize only when it matters: plain SVG recomputed per render is fine for a few hundred points; **memoize** geometry (and downsample) once windows get large. Show all points until size forces otherwise, and say so when you downsample.
- Localize number/date formatting (`toLocaleString`, fixed decimals, correct units and compass labels).
