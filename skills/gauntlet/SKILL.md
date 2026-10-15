---
name: gauntlet
description: Pursue a whole goal from whatever the user gives. Talk with the user until the goal and everything the loop needs are clear, then repeatedly write specs, deliver them (and release if wanted) until the goal is met or the budget is spent — the user never writes specs, and every builder and critic gets the overarching goal.
argument-hint: "<anything: a sentence, an idea, a document> [budget: 15%] [parallel: 3]"
disable-model-invocation: true
---

# Gauntlet

You are the **supervisor**. You do not judge your own work and you do not let a derived spec
replace the original: every builder and critic holds the goal statement. Inputs: `$ARGUMENTS`.

In a Claude Code **Project**, the coordinator plays this role and threads deliver the specs; in a
normal session you deliver them yourself or through subagents.

## 1. Talk until the loop can run
Start from whatever the user gave — a sentence, an idea, a document. Then talk with them, in
batched questions, **until everything the loop needs is known** — not to write a spec, but so you
can run unattended afterwards:
- **the goal** — what should exist or be true at the end, and for whom;
- **the bar** — how to tell it is reached: a reference to match or beat (**named, fetchable,
  comparable**), acceptance for the whole, the checks that prove it;
- **constraints** — scope, what must not change, taste (for UI: the style guide, or the design pass
  from the `ui-frontend` guideline if there is none yet);
- **the run** — budget and concurrency (section 2), whether to merge and **release** at the end, and
  what to do with open questions while nobody is watching.

Don't ask what the code or the documents already answer. Write the result down as the **goal
statement** (in `docs/design/` when the spec mode stores files, otherwise in the run), show it,
and get one go. After that the run does not stop for questions; new questions are collected for the
final report. There are no specs yet — the rounds write them; the user never has to.

## 2. Budget
- **Weekly allowance share** (default: ask; e.g. `budget: 15%`). Call the `wf_usage` tool (the plugin's
  mod registers it; it may be listed as `mcp__wf__wf_usage`) at the start for the `seven_day` reading and record it as the baseline. Before each round, call it
  again: when the next round would plausibly take the spent share past the budget, stop cleanly.
  If `wf_usage` is unavailable or returns no reading (no subscription, or before the first
  response), say so and ask for a round limit instead — or, when nobody can be asked, use
  **3 rounds** and say that this replaced the budget.
- **Concurrency** (default 2; e.g. `parallel: 3`): never more agents or threads at once than that.

## 3. Rounds
1. **Assess** the current state against the whole bar: run the gate, start the app and look at it
   where there is a UI, read what exists. Include the critics' findings and open items from the
   previous round.
2. **Write the round's specs** yourself for the gaps that matter, following the `spec` skill —
   small, each deliverable in one `deliver` run, its `source` pointing at the goal statement.
3. **Plan the round:** which specs belong together (same code → one batch in one agent or session,
   in order), which are independent and may run in parallel within the concurrency limit.
4. **Deliver** each group by following `${CLAUDE_PLUGIN_ROOT}/skills/deliver/SKILL.md` — yourself,
   or a subagent per independent group (isolated worktree) that gets that file, its specs and the
   goal statement. **Every builder and every critic receives the goal statement in full**, plus
   its own area (spec, style guide), so each change makes sense as part of the whole, not only
   against its spec.
5. **Collect** verdicts, fixed and open findings, bar questions. A spec still open after its 4
   rounds becomes input for the next assessment, not an automatic extra round.
6. **Decide:** goal met → finish. Otherwise next round — unless the budget is spent, or two rounds
   in a row closed no gap (then stop: the bar or the approach needs the user).

## 4. Finish
Merge, and release with `${CLAUDE_PLUGIN_ROOT}/skills/release/SKILL.md`, only if the user asked for
it in section 1. Report:
- the bar, and whether it is met — with the evidence (gate output, screenshots, verdicts);
- per round: specs written, delivered, verdicts;
- budget used (weekly share before/after) and rounds run;
- open findings and bar questions, each with the option to turn it into specs or run more rounds.
