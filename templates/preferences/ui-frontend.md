# UI / frontend design process

Standing preferences for how a UI gets designed and built, not what any specific UI looks like.

## When to read this file
Read this **in full** when a UI is first being created, or when a project's very first real design pass happens. After that pass produces the project's own condensed design-guidelines doc (see "Capture the system" below), **that** doc is what stays in context for day-to-day UI work — this file becomes a read-if-necessary reference, not something reread on every UI change.

## Test UI now, real design later — but not too much later
- **Small scripts/tools:** a simplistic, purely functional test UI is enough. Don't design it.
- **Larger projects, up through the walking skeleton:** same — functional over polished, so early structural iteration stays cheap.
- **By the 1.0 release at the latest** — and already at the MVP if it makes sense for the project — a **real design** must exist. Don't let "we'll design it later" slide past 1.0.

## Mockup first, then build to match it
- Build a **click-through mockup** with the user (HTML/CSS is usually enough; there's no dedicated UI-mockup skill in this workflow today — if one gets added later, use it instead) and **iterate on it with the user until they're happy** — before writing the real UI against it.
- Implement the real UI to match that mockup **as faithfully as possible.**
- Claude then **reviews the built UI against the mockup itself**, iterating — adjust, compare, adjust again — until the built UI matches the mockup as closely as practical.

## Capture the system
- Once the mockup/first real design pass is done, write down the **reusable components, design variables (colors, spacing, type scale), and the ground rules** for views that get added later — this becomes the project's own condensed design-guidelines doc (see "When to read this file" above). Later UI work reads that doc, not this one.

## General design & accessibility
- Follow ordinary design sense and **baseline accessibility** (contrast, focus states, semantic markup, keyboard reachability) — but **don't over-engineer it**, especially for an app with a single user. Match the effort to who's actually going to use it.

## Fit the target devices and inputs
- The UI must fit the **devices, screen sizes, and input methods the project is actually built for** — not just a desktop mouse. (Charts have their own version of this rule in `plots-graphs.md`; this is the same principle for the whole UI.)
- **Hover tooltips need a touch equivalent.** This is specifically tricky on **clickable elements**: if a button (or anything else that reacts to a tap) also carries a hover tooltip, touch has no hover to trigger it — the tooltip's information has to reach the user another way (a tap-and-hold reveal, a visible label instead of a tooltip, an info affordance next to the control, etc.). Don't ship a tooltip that's simply unreachable on a touch-only device.

## Logo
- A logo can be designed alongside the UI — either hand-written SVG, or through the `cf-image` plugin/skill if it's available in the project.

## Icons — pick one path, stay consistent
- Either agree with the user on an existing **free icon set** and use it throughout, or define the project's **own icon style**.
- If it's an own style: **pre-generate a base set of standard icons** up front (the common actions/entities the app needs), then generate additional icons **on demand, matching that established style**, as hand-written SVG or via the `cf-image` skill — never mix styles ad hoc.
