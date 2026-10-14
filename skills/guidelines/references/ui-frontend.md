# UI / frontend design process

How a UI gets designed and built, not what a specific UI looks like. What a good screen must *handle* (empty/loading/error states, forms, feedback, copy) is in `ux-basics.md`.

## When to read this file
In full when a UI is first created or the project's first real design pass happens. After that the project has its own style guide (below) and **that** is what UI work reads; this file becomes a reference.

## Test UI first, real UI when it is time
- **Early experimental versions** (prototypes, the walking skeleton, small scripts and tools) get a plain, purely functional **test UI**. Don't design it and don't write a style guide for it: structural iteration stays cheap only while nothing is fixed.
- The **first real UI** is designed together with the user, at the MVP if it makes sense, **by 1.0 at the latest**. Don't let "we'll design it later" slide past 1.0. That design pass creates the style guide.

## Mockup: diverge first, then converge
Describing taste in words goes in circles. Reacting to something concrete is easier, so put options in front of the user before iterating.

1. **Diverge.** Build **2–3 deliberately different variants** of one representative screen as standalone HTML/CSS, different in layout, density and visual tone, not three shades of one idea. Real content, not lorem ipsum: placeholder text hides exactly what the user would react to.
2. **The user picks or mixes** ("layout of A, colours of B").
3. **Converge.** Iterate the chosen direction into a **click-through mockup** until the user is happy.
4. Build the real UI to match the mockup **as faithfully as possible**, then compare the built UI against it and adjust.

## The project style guide: `docs/design/style-guide.md`
The outcome of the first real design pass is written down so taste isn't renegotiated every time. **The path is fixed:** `docs/design/style-guide.md`, with the mockup (`docs/design/prototype.html`) and anything else the design needs alongside it in `docs/design/`. Its existence tells the critic reviewing a delivery to judge the UI against it, so **do not create it as an empty stub** before the real design pass: a stub would make the critic review against nothing.

**Its structure is the project's own**; there is no template. Settle each of these, or say explicitly it is left open:
- **Design variables:** colours by role (primary, surface, text, danger…), type scale, spacing, radii, shadows, motion. In CSS projects, variables in one file, which the guide names.
- **Layouts:** the few page shapes this project uses, so new screens are composed, not invented.
- **Components and their states:** every recurring component, with hover, focus, disabled, loading, error and empty where they apply.
- **Copy and tone:** how buttons, errors and empty states are worded; language, formality.
- **Interaction rules:** what gets a spinner, what is optimistic, what needs confirmation, how feedback appears.
- **Target devices and inputs:** the viewports and input methods the UI must work on. The critic's screenshots cover exactly these.
- **Accessibility floor:** what the project commits to.
- **Icons and logo:** the chosen set or own style (below).

The mockup stays the literal source of truth for exact layout and behaviour: the guide records *decisions*, the mockup is what to check when a detail is ambiguous.

**Enforce with tooling where practical:** a lint rule blocking raw hex colours outside the variables file, an import restriction limiting an icon library to one mapping module. A rule only written down drifts.

## How the style guide is used
- **`/wf:spec`** reads it for every feature with a UI share and **references** the relevant parts in the spec (`docs/design/style-guide.md#forms`) rather than copying them; a part the spec doesn't reference is a part the implementer never sees.
- **`/wf:deliver`'s critic** reviews the built UI on screenshots against the spec, the style guide and `ux-basics.md` once the style guide exists.
- **When the user rejects something**, decide with them whether it is a general rule or a one-off. A general rule goes into the style guide, dated; a one-off is just fixed. A guide that grows a line per complaint stops being readable.

## General design & accessibility
- Ordinary design sense and **baseline accessibility** (contrast, visible focus, semantic markup, keyboard reachability), but **don't over-engineer it**, especially for a single-user app. Match effort to who will use it.

## Fit the target devices and inputs
- The UI must fit the **devices, screen sizes and input methods the project is built for**, not just a desktop mouse. (Charts: `plots-graphs.md`.)
- **Hover tooltips need a touch equivalent.** On a clickable element the tooltip's information must reach touch users another way: a visible label, an info affordance next to the control, a tap-and-hold reveal.

## Logo
- A logo can be designed alongside the UI: hand-written SVG, or the `cf-image` plugin/skill if available.

## Icons: pick one path, stay consistent
- Either agree with the user on an existing **free icon set** and use it throughout, or define the project's **own icon style**.
- For an own style: **pre-generate a base set** of standard icons up front (common actions and entities), then generate more **on demand in that style**, as hand-written SVG or via `cf-image`. Never mix styles ad hoc.
