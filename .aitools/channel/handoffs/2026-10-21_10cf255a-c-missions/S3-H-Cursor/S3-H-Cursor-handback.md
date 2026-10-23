# S3-H-Cursor hand-back

S3-H-Cursor to S3-Harness, 2026-10-22. PR: https://github.com/nobul-tech/aitools/pull/87. Branch: `feature/harness-cursor-rules`.

## Summary

1. Cursor's user-level rules location is `~/.cursor/rules/` (Windows `%USERPROFILE%\.cursor\rules\`). The format is `*.mdc` with a leading `---` frontmatter block; Cursor ignores plain `.md` there. This comes from cursor.com/help/customization/rules.md plus the installed IDE 3.13.10 and CLI 2026.05.21 loader code.
2. The rules are loaded by an ancestor walk, so they reach only workspaces under the home directory. Relative globs are matched against paths relative to `$HOME`. The converter therefore anchors Claude Code `paths:` as `**/<pattern>`. This was found by the reviewer (B1) and fixed.
3. `setup-user-cursor.sh/.ps1` step 4 fans `~/.aitools/rules/*.md` out to `~/.cursor/rules/<name>.mdc` through `deploy_managed_file` with `ADOPT_PATH ""`. It is additive, and `*.bak.*` files are skipped (S3-Harness contract correction).
4. The tests are `tests/rules-fanout-cursor/`: 78 pass and 1 is skipped. The skipped case (dupcase) needs a case-sensitive file system. The independent review found 1 blocking issue and 8 non-blocking ones, all fixed. The re-review reports no blocking findings, and its R1-R3 are fixed too.
5. The live canary was **not run** because the Cursor CLI is not authenticated. A 1-minute manual canary is in the research file, section C3.

## Location (citations)

- https://cursor.com/help/customization/rules.md, "Where are rules stored?" (2026-10-22): "**User rule files** in `~/.cursor/rules` (Windows: `%USERPROFILE%\.cursor\rules`) stay on the machine and do not sync."
- https://cursor.com/docs/rules.md: "Project rules must use the `.mdc` extension. A plain `.md` file in `.cursor/rules` is ignored by the rules system".
- The IDE (`/Applications/Cursor.app/.../cursor-agent-exec/dist/main.js`) and the CLI (`~/.local/share/cursor-agent/versions/2026.05.21-f84ab11/index.js`) both use `LocalCursorRulesService.loadRulesFromDirAndAncestors`, which loads `<dir>/.cursor/rules/**/*.mdc` up to `/`.
- In the IDE, `rL`/`aL` (glob anchoring) resolve a relative glob against the directory that owns `.cursor/rules`.
- The CLI's `generate-rule` writes user rules to `join(homedir(),".cursor","rules")/<name>.mdc`.
- Full detail, and the conflicting docs/skills.md sentence: `S3-H-Cursor-research.md`.

## Canary result (verbatim)

- Isolated HOME, `agent status`: `Not logged in`.
- Real HOME, `agent status`: `✓ Login successful!` / `Logged in (unable to fetch user details)`.
- `agent about`: `User Email          Not logged in`.
- `agent -p ...`: `Error: Authentication required. Please run 'agent login' first, or set CURSOR_API_KEY environment variable.`

**NOT RUN.** No canary file was created. The real `~/.cursor` was not modified (`~/.cursor/rules` did not exist before this mission and still does not).

## Files changed

- `scripts/setup-user-cursor.sh`, `scripts/setup-user-cursor.ps1`: step 4, plus the header's managed/preserved scope.
- `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`, `tests/rules-fanout-cursor/convert-rule.ps1`.
- `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H-Cursor/`: `S3-H-Cursor-research.md`, `S3-H-Cursor-handback.md`, `S3-H-Cursor-Review-verdict.md`, `S3-H-Cursor-Review-reverify.md`, `S3-H-Cursor-drafts/`.

## Verification

- `bash -n` OK, and the pwsh parser reports OK on `setup-user-cursor.ps1`. PS1 code is ASCII only.
- `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`: 78 passed, 0 failed, 1 skipped. It covers:
  - converter golden cases and PS1 byte parity
  - a resolution model of Cursor's matcher
  - missing and empty sources, first run, rerun, edited target, `--force`
  - skipping backups and non-`.md` files
  - dangling symlinks, an unreadable source directory, a misparse warning, dry run, and dry run with a failure
- Isolated-HOME run over the repo's 26 `.claude/rules`: `OK|cursor rules|26 added`. Cursor's own `cr`/`ur` logic parses them as 9 fileGlobbed (with `**/` globs) and 17 global.
- The reviewer independently checked the globs with the picomatch bundled in Cursor.app: `**/scripts/**` against `repos/aitools/scripts/...` is true, and the old `scripts/**` is false.
- `check-pre-commit`: FAIL on step 6 (the known `harvesting/...build-deploy-prefix.sh` 100644), WARN on 3 and 13 (build-deploy not run; that belongs to S3-H-MDM), WARN on 9 (no release notes).
- `check-pre-push`: FAIL on step 7 only (the known stale dotprofile `deploy/`).

## Not run

- The live canary, because the CLI is not authenticated.
- The CLI's glob anchoring is unknown: its bundle has no client-side matcher. `**/` is correct for either anchor.
- PS1 end to end on Windows. Only the parser, the converter parity run (pwsh on macOS) and the dangling-link probe were run.
- The dupcase test on Linux.
- `build-deploy.sh`, against any HOME.

## WRITE_BLOCKED

None.

## INCIDENT markers (not filed)

1. INCIDENT: The `~/.cursor/AGENTS.md` relay mirror (`scripts/aitools` deploy, `aitools-install` Step 22) appears never to be loaded by Cursor. Both loaders read `<ancestor>/AGENTS.md` (that is, `~/AGENTS.md`), and no bundle contains `.cursor/AGENTS.md` or `".cursor","AGENTS.md"`. Caveat: a dynamically built path would not show up in a string search. Fix options: mirror the relay into `~/.cursor/rules/relay.mdc` (`alwaysApply: true`), or into `~/AGENTS.md`. Either needs a canary.
2. INCIDENT: `backup_dir` / `Backup-Dir` (aitools-lib) back up a directory only when it contains `*.md`. So `~/.cursor/rules`, which holds only `.mdc`, never gets a directory backup, contrary to config-file-safety.md "Directory deployment" step 2. Per-file `.bak.<ts>` backups do still happen. The reviewer confirmed this.
3. INCIDENT: The S3-Harness fan-out contract does not say how Claude Code `paths:` scoping maps to each tool. Claude Code is project-relative; Cursor user-rule globs are relative to `$HOME`. This PR handles it with `**/` anchoring. Suggested fix: add a "scoping translation" clause to the contract and to `reference/tool-ops-cursor.md`. The reviewer raised it.
4. INCIDENT (doc drift): `reference/cursor-practices.md` says Cursor User Rules are "Not file-accessible; set via IDE UI" and that the CLI "uses Cursor User Rules (SQLite) + project CLAUDE.md + .cursor/rules/ only". Both statements are stale now that `~/.cursor/rules` exists.

## Open questions (with suggested answers)

1. **The `**/` anchoring makes aitools project rules attach in other repos under `~`** that have `scripts/` or `reference/`. The 17 rules without `paths:` are always applied in every Cursor chat under `~` (O1). Should project-scoped rules be fanned out at user level at all?
   - Suggested answer: keep this PR as is, because it implements the contract. Then have S3-Harness decide whether `.claude/rules` (aitools project rules) belong in `~/.aitools/rules` at all, or should go to `<repo>/.cursor/rules` instead. This applies to Claude Code's `~/.claude/rules` as well.
2. **Windows repos at `C:\repos\`** (cross-platform.md) are outside `%USERPROFILE%`, so user rule files would not load there.
   - Suggested answer: standardise on `%USERPROFILE%\repos\` (the user CLAUDE.md already says so) and correct cross-platform.md. That file is protected, so it needs commander review.
3. **A harness rule that is removed leaves its `.mdc` behind** as "preserved", and it stays loaded (O2).
   - Suggested answer: accept the additive pattern for now. Have deploy-harness record a manifest later, so consumers can retire rules that are no longer in the source.
4. **Live canary.**
   - Suggested answer: the commander runs research section C3 after `agent login`. Expected output: `AITOOLS-CANARY-MDC-7Q4` only.

## MDM port notes (for S3-H-MDM)

- No logic port is needed. Step 4 sits between the `// --- END profile preferences` (bash) / `# --- END profile preferences` (ps1) sentinels and `# --- END cursor body`, and `build-deploy.sh` already extracts that span verbatim into `deploy/setup-user-cursor.*`. This includes `cursor_rule_from_md`, `cursor_rule_check`, `lower_name`, `ConvertTo-CursorRule` and `Test-CursorRuleParse`.
- Port the hand-written header BLOCKs in `scripts/build-deploy.sh`. Today they say "Does three things:" (around lines 635 and 673). They need step 4 added, and in the PS1 BLOCK the managed/preserved scope for `~/.cursor/rules` as well. Copy the text from the source script headers.
- At runtime the MDM script reads `~/.aitools/rules`. The MDM sequence must run `deploy/deploy-harness.*` **before** `setup-user-cursor`. Otherwise the step reports `OK | cursor rules | n/a (no harness rules)`, which is correct but deploys nothing.
- The bash MDM script needs `perl`, which macOS and Linux ship. The PS1 version is native.
- After the build, verify with `grep -c 'Step 4: Cursor user rules' deploy/setup-user-cursor.sh` (expect 1), and the same for `.ps1`, under an isolated HOME.

## Reviewer verdicts

- First review, CHANGES REQUESTED (1 blocking, 8 non-blocking): https://github.com/nobul-tech/aitools/pull/87#pullrequestreview-5620875626. All fixed in `1a4e31e`.
- Re-review, no blocking findings: https://github.com/nobul-tech/aitools/pull/87#pullrequestreview-5621000182. R1-R3 fixed in the final commit.
  - R1: PS1 dangling-link detection now uses `ResolveLinkTarget($true).Exists`, probed on pwsh 7 / macOS.
  - R2: comment lines inside `paths:` are skipped.
  - R3: bash skips the parse check when a file has no frontmatter.
- GitHub refused `--request-changes` with "Can not request changes on your own pull request", because the reviewer runs under the author's account. Both verdicts were therefore posted as comments, with the verdict on the first line.

## Delegates used

- S3-H-Cursor-Review (level 3, general-purpose, no isolation): the review plus the re-verify.
