# Project decisions — interview and what each answer produces

Shared by `setup` and `onboard`. Ask only what applies to this project. Every answer lands in the
`<!-- wf:settings -->` block of `CLAUDE.md` or in a file; nothing is written as prose about process.
Templates are under `${CLAUDE_PLUGIN_ROOT}/templates/`.

| Decision | Ask when | Options (default) | Produces |
|---|---|---|---|
| **Specs** | always | `none` · `files` · `issues` (**none**) | settings `spec-mode`. `files`: `docs/specs/` is created by the first spec. `issues`: labels `wf-spec`, `wf:draft`, `wf:ready`, `wf:in-progress` (`gh label create`) |
| **Tests** | always | unit · unit + integration · + e2e (**unit**, + integration once there are system boundaries) | the test stages in `scripts/ci.sh`; `tests/unit/`, `tests/integration/` as needed |
| **CI** | the project lives on GitHub | yes · no (**yes**) | `.github/workflows/ci.yml` from `github/ci-<lang>.yml`; `{{CI_BRANCHES}}` → `[<trunk>]`, or `[<trunk>, develop]` under git-flow, **on both triggers**. Optionally `github/dependabot.yml` (not the pip ecosystem for uv projects) |
| **Git** | always | `main-only` · `git-flow` (**main-only**); trunk name (**main**) | settings `branching`, `trunk` |
| **Release** | something is published or deployed | `none` · `github` · `npm` · `pypi` · `crates` · `docker` · `internal` (**none**) | settings `release`; `scripts/release.sh` with `{{BUILD_ARTIFACT}}` `{{PUBLISH}}` `{{MIGRATIONS}}` `{{DEPLOY}}` filled or deleted — the build starts from an empty output directory (`rm -rf dist` before `uv build` / `npm pack`), or a publish uploads stale artifacts too; `CHANGELOG.md`; optional `.github/workflows/release.yml` from `github/release-npm.yml` / `release-pypi.yml` / `release-github.yml` (`{{TOOLCHAIN_STEPS}}` = the CI file's setup + install steps), `workflow_dispatch` only |
| **Deploy / health** | `release` is not `none`/`internal` — a published package needs it too, even with `deploy: none` | platform, if any; how the live version is visible (**ask**) | settings `deploy`; `scripts/healthcheck.sh` with a `version_probe` (health endpoint, `npm view`, PyPI/crates.io JSON — compare the repository URL too, a registry answers for whoever owns the name) |
| **UI** | there is a graphical UI | `test-ui` · `style-guide` later (**test-ui**) | settings `ui`. The style guide is created by the first real design pass with the user (`ui-frontend` guideline), never as an empty stub |
| **Docs** | the project has something a reader could not recover from the code | — | only those documents, under `docs/`; no architecture or setup docs by default |

## Rules that hold for every answer
- **Fill or delete.** A `{{TOKEN}}` left in a file is a defect; so is a `step`/`check` line that
  cannot succeed yet — delete it and say so in the report. In every script you fill (`ci.sh`,
  `release.sh`, `healthcheck.sh`) delete the block from `# --- how to fill this in` down to and
  including `# --- end of authoring notes`, and every hint line — find them with
  `grep -nE '^[[:space:]]*#[[:space:]]*e\.g\.'` (indented ones included; an `e.g.` in the middle of
  a comment is not a hint and stays).
- **Escape hatches live in `.claude/gate-overrides.env`** (`CI_ALLOW_EMPTY`, `TESTS_ALLOW_NONE`,
  `FULL_ALLOW_NONE`, `RELEASE_ALLOW_EMPTY`, `HEALTH_ALLOW_EMPTY`), each with a comment saying why,
  so local and CI agree.
- **Go through the package manager** in every stage (`npm run …`, `uv run …`, `cargo …`).
- **Lockfile committed**, unless an existing project deliberately ignores it (then no `--locked`
  install in CI).
