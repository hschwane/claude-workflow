# UX basics: what every screen has to handle

Rules for the parts of a UI that are not its look: what happens when there is nothing, when it is slow, when it fails, and what the words say. The design *process* is in `ui-frontend.md`; the project's own decisions in `docs/design/style-guide.md` (once it exists) **win** where they differ.

A screen that only works with perfect data on a fast connection is not finished.

## Every data view has four states, not one
- **Loading:** something visibly happens within ~100 ms. Prefer a skeleton or inline indicator where the content will appear over a full-page spinner; never a blank area that might be broken. Keep layout stable so content doesn't jump.
- **Empty:** say what would be here and how to get it there, with the action right there ("No bookings yet — **Create booking**"). An empty table with headers is not an empty state. Distinguish "nothing exists yet" from "your filter matches nothing" (offer to clear the filter).
- **Error:** what went wrong in the user's terms, whether their input is safe, and what they can do (**Retry**, fix a field, contact someone). Never a raw exception, stack trace or bare "Error". Keep the rest of the screen usable if one part failed.
- **Content:** including the awkward cases: one item, very many (pagination or virtualisation), very long names, missing optional fields.

## Forms
- **Labels are always visible**, above or beside the field. A placeholder is not a label.
- **Validate at the right moment:** on blur or submit, not every keystroke. Re-validate live once a field has been flagged, so the error clears when fixed.
- **Errors sit next to their field**, say what is wrong and how to fix it ("Use the format 2026-10-12", not "Invalid input"), and focus moves to the first one on submit.
- **Never lose input** on a failed submit, validation error or accidental navigation.
- Mark the minority: if most fields are required, mark the optional ones, and vice versa.
- Use the right input type (`email`, `tel`, `number`, `date`) for mobile keyboards and autofill.
- **Prevent the double submit:** the button shows progress and is disabled while the request runs.

## Feedback on every action
- **Every action gets a visible response**; the user can tell it worked without reloading.
- Match weight to action: inline for a field, a short toast for background success, a blocking message only when the user must act.
- **Toasts are not the only record of an error.** An error the user must act on stays visible until dealt with.
- Show progress for anything over about a second; for long operations say what is happening and, if possible, how far along.

## Destructive and irreversible actions
- **Prefer undo over confirmation** where reversible.
- Where it can't be undone, **confirm**, naming the thing ("Delete booking BK-1001?") and labelling the button with the verb ("**Delete**", not "OK"). Destructive buttons are visually distinct and never the default focus.
- The more that is lost, the more friction: deleting an account or whole dataset may warrant typing the name.

## Copy
- **Real words from the user's domain.** No lorem ipsum, "Item 1", developer vocabulary (`null`, `entity`, `payload`), or internal IDs where a name exists.
- **Buttons say what they do**: a verb, ideally with its object ("Save changes", "Send invite"). Not "Submit", "OK", "Click here".
- **Short and plain.** Cut filler ("Please note that", "Successfully", "In order to"). No marketing tone in a tool, no exclamation marks for routine success, no jokes in errors.
- **Consistent terms.** One word per concept across the app.
- Numbers, dates and currencies in the user's locale.

## Navigation and orientation
- The user always knows **where they are** (title, active nav item) and **how to get back**.
- The back button works as expected; meaningful states have bookmarkable/shareable URLs.
- Keyboard: everything reachable, focus visible, logical tab order. Escape closes what was just opened.

## Responsiveness of the interface itself
- Interactions respond immediately; do the slow part after showing the input was received.
- Hit targets large enough for the input (about 44×44 px on touch).
- Nothing important depends on hover alone; touch has no hover.
