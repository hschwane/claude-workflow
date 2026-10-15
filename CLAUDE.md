# wf — developing the plugin

This repository is the `wf` Claude Code plugin (v4). It is installed through the marketplace in
`.claude-plugin/marketplace.json` and is never copied into projects. `docs/v4-plan.md` records the
design and every decision behind it.

## Layout
```
.claude-plugin/        plugin.json (name wf), marketplace.json
skills/<name>/SKILL.md setup, onboard, convert, spec, deliver, gauntlet, release, guidelines
skills/setup/decisions.md      the project interview, shared by setup and onboard
skills/guidelines/references/  the guideline library, read on demand
shared/workers.md      lead vs workers: threads in a Projects coordinator, subagents in a session
agents/critic.md       the only agent: fresh-context judge against the original bar
hooks/                 the mod: spec board pane (/board) and the wf_usage tool
types/                 the mod's $.state contract
languages/<lang>/      stages.json (the per-language gate commands as DATA) + a minimal fixture
templates/             ci.sh, release.sh, healthcheck.sh, CI/release workflows, gitignores,
                       CLAUDE.md and CHANGELOG templates
scripts/check.sh       the plugin's own gate
```

## Principles (from the v4 plan)
1. **Default: let Claude work.** No process prose in a project's CLAUDE.md; process is opt-in via skills.
2. **Enforce with machinery, not words.** Gates are scripts; judges are fresh-context agents.
3. **The bar is the original intent.** Every critic gets the source (prompt, design doc, reference,
   style guide), not only a spec derived from it.
4. **Use the platform.** Never rebuild what Claude Code ships.
5. **Small enough to maintain.** Skill + agent prose stays under 9,000 words (checked).

## Changing the plugin
- **Anything executable gets executed, everything else that crosses files gets asserted.**
  `scripts/_check_consistency.py` holds the cross-file facts (settings keys, spec statuses and
  labels, paths skills reference, the hint sweep); `scripts/_check_gate.py` proves the gate
  scripts cannot report an unearned pass; `scripts/_check_languages.py` executes every
  language's stage commands on its fixture.
- A per-language command lives in `languages/<lang>/stages.json` — read its `notes` first; the
  setup skill and the fixtures depend on it.
- Add an assertion with every fix, and break the guarded thing once to see it fail.
- `./scripts/check.sh` on every change; `--languages` when a stage command, `ci.sh` or `languages/`
  changes; a live agent run (a fresh agent executes the skill on a real directory and lists every
  ambiguous or impossible instruction, quoted) before a release or after restructuring a skill.
  Ask live runs for **counts**, not exit codes: "green" and "green having run zero tests" look alike.
- Hard-won lessons that still apply: a guard nobody can satisfy is a dead end, not a safeguard;
  escape hatches live in `.claude/gate-overrides.env`, so local and CI agree; prose that assumes a
  deployed web app breaks libraries and CLIs; re-read the whole passage after an edit.

## Releasing the plugin
Bump `.claude-plugin/plugin.json`, commit, merge to `master`, tag `vX.Y.Z`. In cloud sessions the
proxy blocks pushing tags and `master`; use `gh api` instead (pass `-R hschwane/claude-workflow` to
`gh` subcommands — the git remote is a proxy URL gh cannot parse):
```
gh api -X PATCH repos/hschwane/claude-workflow/git/refs/heads/master -f sha="<sha>"
gh api repos/hschwane/claude-workflow/git/refs -f ref="refs/tags/vX.Y.Z" -f sha="<sha>"
gh release create vX.Y.Z -R hschwane/claude-workflow --title "…" --notes-file <file>
```
