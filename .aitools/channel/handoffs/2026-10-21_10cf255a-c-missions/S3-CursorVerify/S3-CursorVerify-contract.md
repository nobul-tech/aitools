# S3-CursorVerify verification contract v1.0

Version 1.0, 2026-10-28, by S3-CursorVerify. Both platform verifiers
(S3-CursorVerify-Bash, S3-CursorVerify-Pwsh) follow this text unchanged. A
verifier that must deviate records a "Contract change" section, with the
reason, in its hand-back.

## Code under test

- REF: `9c2d0257a64d10be1be32a30c24b382a91f7689c` (`feature/fanout-cursor`, PR #123 head;
  it contains origin/main b5a881a and the FO-1..FO-5 chain). After #123 merges, the
  same phases are rerun with REF = the origin/main merge commit.
- Scripts are run FROM THE FIXTURE CLONE (`<ROOT>/aitools/scripts/...`), never from
  /Users/new-jose/repos/aitools or a worktree.

## Fixture

`bash /Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cverify/build-fixture.sh build <ROOT> <REF>`
builds `<ROOT>/aitools` (clone + fixture commit), `<ROOT>/dotprofile`, `<ROOT>/home`
(isolated HOME with `.aitools/config.json` {reposPath, repoPath, userRepoPath},
`.cursor/rules/user-own.mdc`, `.cursor/skills/user-skill/SKILL.md`).
`build-fixture.sh retire <ROOT>` removes and commits `shared/rules/fx-retire.md`,
`shared/rules/fx-retire2.md`, `shared/skills/fx-retire-skill`.
Read the script before using it. Do not edit it; copy it into your own scratch if
you need a variant, and say so.

Fixture inputs (expected winner in brackets):
- rules: shared `fx-shared.md`, `fx-[br].md`, `fx-retire.md`, `fx-retire2.md`,
  `fx-dup.md` [shared]; aitools `.claude/rules/fx-project.md`, `fx-dup2.md` [aitools];
  dotprofile `fx-dot.md`, `fx-dup.md` (loses), `fx-dup2.md` (loses), `FX-Upper.MD`.
- skills: shared `fx-skill-a` (with executable `scripts/run.sh`), `fx-dupskill` [shared],
  `fx-[br]ack`, `fx-retire-skill`; aitools `.claude/skills/fx-skill-b`, `fx-dupskill`
  (loses), `fx-dupskill2` [aitools]; dotprofile `fx-dot-skill`, `fx-dupskill` (loses),
  `fx-dupskill2` (loses).
- Plus every real rule and skill in the REF tree.

Environment for every run: `HOME=<ROOT>/home USERPROFILE=<ROOT>/home`,
`AITOOLS_SUMMARY_FILE=<phase dir>/<script>.summary`, `NO_COLOR=1`; unset
`AITOOLS_FORCE AITOOLS_DRY_RUN AITOOLS_LOG_DIR AITOOLS_USER_REPO_PATH`; stub `rg` and
`agent` on PATH (see `.../session-cverify/smoke-sh.sh`); stdin `/dev/null` except in
phase P5. deploy-harness always with `--skip-config` (config.json is not under test).

## Phases (run in this order on one ROOT)

| Phase | Action | Expected |
|---|---|---|
| P1 | build; deploy-harness; setup-user-cursor | every non-retired rule of all three sources -> `~/.cursor/rules/<stem>.mdc` carrying the fan-out marker; every skill -> `~/.cursor/skills/<name>/**` (exec bit kept on `run.sh`); first source wins for rules and skills, one ERROR row per skipped duplicate; `user-own.mdc` and `user-skill/` byte-identical to before; bracket names handled; record what happens to `FX-Upper.MD` (deploy-harness, manifest, Cursor) |
| P2 | rerun deploy-harness; setup-user-cursor (no changes) | every item verified; no file under `~/.cursor` or `~/.aitools` changes (content, mode, mtime); no new `*.bak.*` |
| P3 | commit an edit to `shared/rules/fx-shared.md` and `shared/skills/fx-skill-a/SKILL.md` in the clone; run deploy-harness `--dry-run`, then setup-user-cursor `--dry-run` (ps: `-DryRun`) | nothing written under `~/.aitools` or `~/.cursor`; dry-run summary rows |
| P3b | same sources, real runs | the two items `updated`; a per-file backup `<file>.bak.<UTC>` exists for each overwritten file; record whether a directory backup of `~/.cursor/rules` / `~/.cursor/skills` was made (OL: `backup_dir` skips dirs with no top-level `*.md`) |
| P4 | user edits `~/.cursor/rules/fx-retire2.mdc` (append a line); `build-fixture.sh retire`; deploy-harness; setup-user-cursor | `fx-retire.mdc` and `skills/fx-retire-skill/` backed up then removed (tracker `removed`); `fx-retire2.mdc` KEPT (user-modified) with a WARN/ACTION naming it; `user-own.mdc`, `user-skill/` untouched; manifests list the three names as `retired` |
| P5 | pty: edit `~/.cursor/rules/fx-shared.mdc` and `~/.cursor/skills/fx-skill-b/SKILL.md` locally, run setup-user-cursor under a pseudo-terminal (python3 `pty` or `script -q`), answer `s` to every review prompt | the review menu prompts for both (capture the prompt text); both local edits survive; then a second pty run answering `x` -> exit 2 and no later item written |
| P6 | parity (orchestrator) | the S3-CursorVerify orchestrator diffs your `tree.txt` and `rows.txt` against the other platform's |

## Output (per phase, under `<your scratch>/out/<phase>/`)

- `tree.txt`: one line per entry under `<ROOT>/home/.cursor/rules`, `<ROOT>/home/.cursor/skills`,
  `<ROOT>/home/.aitools/rules`, `<ROOT>/home/.aitools/skills`: `<relative path><TAB><type f|d|l><TAB><octal mode><TAB><sha256 or ->`,
  sorted bytewise (LC_ALL=C), with every `.bak.<UTC stamp>` replaced by `.bak.TS`.
  Exclude logs. Make the generator a scratch script and use the SAME logic on both
  platforms (write it in perl or python3 so it is platform-neutral; ps verifier may reuse
  the bash verifier's generator only if it already exists, otherwise write its own to the
  same spec).
- `rows.txt`: the summary rows whose tool is `harness files`, `cursor rules`, `cursor skills`,
  or ACTION rows, in emitted order, DETAIL rows included.
- `<script>.out`: full console output; `exit.txt`: exit code per script.

## Never

- Never run any aitools script against the real HOME (`/Users/new-jose`). Check `HOME` in
  every runner before it calls a script and abort if it is the real one.
- Never edit files in /Users/new-jose/repos/aitools or any worktree except your own
  scratch and your hand-back folder.
