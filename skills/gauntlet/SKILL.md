---
name: gauntlet
description: Pursue a whole goal or epic — from a prompt, a design doc or selected specs — in rounds. A supervisor writes specs for the gaps, delivers them, and every critic judges against the original bar, until the goal is met or the budget (share of the weekly allowance, concurrency limit) is spent.
argument-hint: "<goal | design doc | spec ids> [budget: 15%] [parallel: 3]"
disable-model-invocation: true
---

# Gauntlet

You are the **supervisor**. You do not judge your own work and you do not let a derived spec
replace the original: every critic holds the original bar. Inputs: `$ARGUMENTS`.

In a Claude Code **Project**, the coordinator plays this role and threads deliver the specs; in a
normal session you deliver them yourself or through subagents.

## 1. The bar — confirmed once
Build the original bar from the input with the `spec` skill (enrich mode): goal, users, the
reference to match or beat (**named, fetchable, comparable**), acceptance for the whole, scope, what
must not change. A design doc is used as it is; selected specs bring their `source`. Show the bar
and get one confirmation — after that the run does not stop for questions; bar questions are
collected for the final report.

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
   previous round. In round 1 with selected specs, those specs are the round.
2. **Write the round's specs** for the gaps that matter, with the `spec` skill — each spec's
   `source` points at the original bar.
3. **Plan the round:** which specs belong together (same code → one batch in one agent or session,
   in order), which are independent and may run in parallel within the concurrency limit.
4. **Deliver** each group by following `${CLAUDE_PLUGIN_ROOT}/skills/deliver/SKILL.md` — yourself,
   or a subagent per independent group (isolated worktree) that gets that file, its specs and the
   original bar. Every critic receives the **original bar plus its area** (spec, style guide).
5. **Collect** verdicts, fixed and open findings, bar questions. A spec still open after its 4
   rounds becomes input for the next assessment, not an automatic extra round.
6. **Decide:** goal met → finish. Otherwise next round — unless the budget is spent, or two rounds
   in a row closed no gap (then stop: the bar or the approach needs the user).

## 4. Finish
Merge the work per the branching setting only if the user asked for it at the start. Report:
- the bar, and whether it is met — with the evidence (gate output, screenshots, verdicts);
- per round: specs written, delivered, verdicts;
- budget used (weekly share before/after) and rounds run;
- open findings and bar questions, each with the option to turn it into specs or run more rounds.
