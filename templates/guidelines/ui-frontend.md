# UI / frontend design process

Standing guidelines for how a UI gets designed and built, not what any specific UI looks like. What a good screen has to *handle* — empty, loading and error states, forms, feedback, copy — is in `ux-basics.md`.

## When to read this file
Read this **in full** when a UI is first being created, or when a project's first real design pass happens. After that pass the project has its own style guide (below), and **that** is what UI work reads — this file becomes a read-if-necessary reference.

## Test UI first, real UI when it is time
- **Early experimental versions** — prototypes, the walking skeleton, small scripts and tools — get a plain, purely functional **test UI**. Don't design it, and don't write a style guide for it: early structural iteration stays cheap only while nothing is fixed.
- The **first real UI** is built together with the user — at the MVP if it makes sense for the project, **by 1.0 at the latest**. Don't let "we'll design it later" slide past 1.0. That design pass is what creates the style guide.

## Mockup: diverge first, then converge
Describing taste in words is where UI work goes in circles: the user explains, Claude builds, the user explains again. Reacting to something concrete is far easier than specifying it up front — so put options in front of the user before anything gets iterated.

1. **Diverge.** Build **2–3 deliberately different variants** of one representative screen as standalone HTML/CSS files — different in layout, density and visual tone, not three shades of the same idea. Three near-identical variants waste the round. Real content, not lorem ipsum: placeholder text hides exactly the problems the user would react to.
2. **The user picks or mixes** ("layout of A, colours of B").
3. **Converge.** Iterate the chosen direction into a **click-through mockup** with the user until they are happy.
4. Build the real UI to match the mockup **as faithfully as possible**, then compare the built UI against the mockup yourself and adjust until they match as closely as practical.

## The project style guide — `docs/design/style-guide.md`
The outcome of the first real design pass is written down, so that taste is not renegotiated from zero on every ticket. **The path is fixed:** `docs/design/style-guide.md`, with the mockup (`docs/design/prototype.html`) and anything else the design needs alongside it in `docs/design/`. Add a row for it to `docs/dev/README.md` when you create it. The file existing is what switches on the UI review in `/verify` — so **do not create it as an empty stub** before the real design pass; a stub would turn on a review against nothing.

**Its structure is the project's own.** There is no template, because what matters differs between a data-dense dashboard and a phone-first hobby app. What it should settle — decide each, or say explicitly that it is left open:

- **Design variables** — colours by role (primary, surface, text, danger…, not raw values at the point of use), type scale, spacing scale, radii, shadows, motion. If the project has CSS, these live as variables in one file, and the guide names that file.
- **Layouts** — the few page shapes this project uses, so new screens are composed, not invented one at a time.
- **Components and their states** — every recurring component, with hover, focus, disabled, loading, error and empty where they apply.
- **Copy and tone** — how buttons, errors and empty states are worded; language, formality.
- **Interaction rules** — what gets a spinner, what is optimistic, what needs a confirmation, how feedback appears.
- **Target devices and inputs** — the viewport sizes and input methods the UI must work on. The UI review screenshots exactly these.
- **Accessibility floor** — what this project commits to (see below).
- **Icons and logo** — the chosen set or own style (see below).

Keep the mockup as the literal source of truth for exact layout and behaviour: the guide records the *decisions*, the mockup is what to check when a detail is ambiguous.

**Enforce it with tooling where practical**, not just documentation: a lint rule blocking raw hex colours outside the variables file, an import restriction limiting an icon library to one mapping module. A rule that is only written down drifts; a rule the linter checks does not.

## How the style guide is used
- **`/plan` reads it** for every ticket with a UI share and **references** the parts that matter in the spec (`docs/design/style-guide.md#forms`) rather than copying them. `/implement` and the review get the details through the spec — so a relevant part the spec does not reference is a part the implementer never sees.
- **`/verify` reviews the built UI** against the spec, the style guide and `ux-basics.md` on every ticket with a UI share, once the style guide exists — see `/verify` §6.
- **When the user rejects something**, decide with them whether it is a general rule or a one-off. A general rule goes into the style guide, dated; a one-off is just fixed. Not every correction is a rule, and a guide that grows a line for every complaint stops being readable.

## General design & accessibility
- Follow ordinary design sense and **baseline accessibility** (contrast, visible focus, semantic markup, keyboard reachability) — but **don't over-engineer it**, especially for an app with a single user. Match the effort to who is actually going to use it.

## Fit the target devices and inputs
- The UI must fit the **devices, screen sizes and input methods the project is actually built for** — not just a desktop mouse. (Charts have their own version of this rule in `plots-graphs.md`.)
- **Hover tooltips need a touch equivalent.** Touch has no hover, so on a clickable element a tooltip's information has to reach the user another way — a visible label, an info affordance next to the control, a tap-and-hold reveal. Don't ship a tooltip that is unreachable on a touch-only device.

## Logo
- A logo can be designed alongside the UI — either hand-written SVG, or through the `cf-image` plugin/skill if it is available in the project.

## Icons — pick one path, stay consistent
- Either agree with the user on an existing **free icon set** and use it throughout, or define the project's **own icon style**.
- If it is an own style: **pre-generate a base set of standard icons** up front (the common actions and entities the app needs), then generate further icons **on demand, matching that established style**, as hand-written SVG or via the `cf-image` skill — never mix styles ad hoc.
