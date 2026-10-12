# UX basics — what every screen has to handle

Standing rules for the parts of a UI that are not its look: what happens when there is nothing, when it is slow, when it fails, and what the words say. The design *process* is in `ui-frontend.md`; the project's own decisions are in `docs/design/style-guide.md` once it exists, and **they win** where they say something different.

These are the things a demo never shows and a real user hits on day one. A screen that only works with perfect data on a fast connection is not finished.

## Every data view has four states, not one
Design and build all of them, not just the happy one:
- **Loading** — something visibly happens within ~100 ms. Prefer a skeleton or an inline indicator where the content will appear over a full-page spinner; never a blank area that might be broken. Keep the layout stable so content does not jump when it arrives.
- **Empty** — say what would be here and how to get it there, with the action right there ("No bookings yet — **Create booking**"). An empty table with headers and no rows is not an empty state. Distinguish "nothing exists yet" from "your filter matches nothing" (offer to clear the filter).
- **Error** — what went wrong in the user's terms, whether their input is safe, and what they can do (**Retry**, fix a field, contact someone). Never a raw exception, a stack trace or a bare "Error". Keep the rest of the screen usable if only one part failed.
- **Content** — including the awkward cases: one item, very many items (pagination or virtualisation), very long names, missing optional fields.

## Forms
- **Labels are always visible**, above or beside the field. A placeholder is not a label — it disappears the moment someone types.
- **Validate at the right moment:** on blur or on submit, not on every keystroke while the user is still typing. Re-validate live once a field has been flagged, so the error clears as soon as it is fixed.
- **Errors sit next to the field they belong to**, say what is wrong and how to fix it ("Use the format 2026-10-12", not "Invalid input"), and focus moves to the first one on submit.
- **Never lose input.** A failed submit, a validation error or an accidental navigation keeps what was typed.
- Mark the minority: if most fields are required, mark the optional ones, and vice versa.
- Use the right input type (`email`, `tel`, `number`, `date`) so mobile keyboards and autofill work.
- **Prevent the double submit:** the button shows progress and is disabled while the request runs.

## Feedback on every action
- **Every action gets a visible response.** Saving, deleting, sending — the user must be able to tell it worked without reloading.
- Match the weight of the feedback to the action: inline for a field, a short toast for a background success, a blocking message only when the user must act.
- **Toasts are not the only record of an error.** An error the user needs to act on stays visible until it is dealt with.
- Show progress for anything over about a second; for long operations, say what is happening and, if possible, how far along it is.

## Destructive and irreversible actions
- **Prefer undo over confirmation** where the action can be reversed — it is faster for the common case and still safe.
- Where it cannot be undone, **confirm** — naming the thing ("Delete booking BK-1001?") and labelling the button with the verb ("**Delete**", not "OK"). Destructive buttons are visually distinct and never the default focus.
- The more that is lost, the more friction: deleting an account or a whole dataset may warrant typing the name.

## Copy
- **Real words, from the user's domain.** No lorem ipsum, no "Item 1", no developer vocabulary (`null`, `undefined`, `entity`, `payload`), no internal IDs where a name exists.
- **Buttons say what they do** — a verb, ideally with its object ("Save changes", "Send invite"). Not "Submit", not "OK", not "Click here".
- **Short and plain.** Cut filler — "Please note that", "Successfully", "In order to". No marketing tone in a tool, no exclamation marks for routine success, no jokes in error messages.
- **Consistent terms.** One word per concept across the whole app — not "booking" here and "reservation" there.
- Numbers, dates and currencies in the user's locale and format.

## Navigation and orientation
- The user always knows **where they are** (title, active navigation item) and **how to get back**.
- The browser back button works and does what the user expects; meaningful states have URLs that can be bookmarked or shared.
- Keyboard: everything reachable, focus visible, a logical tab order. Escape closes what was just opened.

## Responsiveness of the interface itself
- Interactions respond immediately; do the slow part after showing that the input was received.
- Hit targets large enough for the target input — about 44×44 px on touch.
- Nothing important depends on hover alone (see `ui-frontend.md`).
