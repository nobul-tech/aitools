VERDICT: APPROVE WITH CHANGES

Independent review of #124 (FO-4, skills fan-out) by S3-FanoutImpl-Review124, against `plans/skills-and-rules-fanout.md` v1.0 section 3.4 and FO-4. Head reviewed: `fcf6edc`. No blocking findings. The changes I ask for are small and can go in this PR or in FO-5 (which calls the same function). Findings N1 and N2 should be fixed or ticketed before FO-5 adds Cursor as a second consumer.

## Scope and method

- The FO-4 diff only: I rebuilt a synthetic base (FO-3 head `f897b74` + FO-2 head `fd660a9` + FO-1 head `7b7e1fb`, with the author's resolution of the one conflict, `tests/deploy-harness-mdm`) and diffed it against `fcf6edc`. That gives 9 files, +1506/-17, which matches commits `388cf24` + `fcf6edc` exactly. The PR's `git diff f897b74...fcf6edc` also includes FO-2's deploy-harness changes, which are not FO-4's.
- I read every line of `fanout_harness_skills` / `_fanout_list_dir` (scripts/aitools-lib.sh:2838-3271) and `Invoke-HarnessSkillsFanout` / `Get-FanoutSortedNames` (scripts/aitools-lib.ps1:2857-3318), the two call sites, the build-deploy span extraction, and the test and CI edits.
- I ran my own probes under temp HOMEs, every case in .sh and .ps1. Nothing ran against the real HOME.

## Contract 3.4 conformance

Every row of the 3.4 table is implemented in both languages: missing, unreadable, manifest absent / header-bad / unreadable, entry kinds, deploy on fd 3, adopt targets, symlink-or-file kept with ACTION, case-only duplicates, retired prune, preserved, DEST missing, backup_dir, summary, and abort. I checked the call sites against FO-4. They pass `RULES_AITOOLS_REPO` / `$rulesAitoolsRepo` and `USER_REPO_PATH` / `$userRepoPath`. Both are set in the extracted `rules deployment` span (setup-user-claude.sh:318-321, .ps1:348-356), so the MDM copy has them too, and `set -u` is safe. The new span sits after the rules spans and before `exit`, and build-deploy extracts it into both generated scripts (build-deploy.sh, the two new `extract_between` lines).

The five declared contract changes:

1. **Backup at `DEST.bak.<UTC>/<name>/`: VERIFIED and correct.** The Claude Code docs at https://code.claude.com/docs/en/skills, read with chrome-devtools on 2026-10-27, list the personal location as `~/.claude/skills/<skill-name>/SKILL.md`. So a backup at `~/.claude/skills/<name>.bak.<UTC>/SKILL.md`, which is what the contract asked for, would load as a skill. The change is needed. The same page says `synced` is a reserved folder name (Claude Code uses `~/.claude/skills/synced/` for claude.ai skills) and that a symlinked `<skill-name>` folder is followed. Both matter for N3 below.
2. **`backup_dir DEST` runs but does nothing for skills: accepted.** In practice it never copies, because `~/.claude/skills` has no top-level `*.md`. Per-file backups come from `deploy_managed_file`. See N4 on retention.
3. **ACTION text: accepted.**
4. **Executable bit in both directions: VERIFIED** (probe P4, sh=ps).
5. **Return 0, failures as ERROR rows: accepted.** It matches the rules fan-out.

## Findings

### Blocking

None.

### Non-blocking (changes requested)

- **N1: binary files in a skill are silently corrupted, and a rerun reports them `verified`.** The .sh reads each file with `_fs_content=$(cat "$_fs_sfile")` (aitools-lib.sh:3102), which drops NUL bytes. `deploy_managed_file` then normalises trailing newlines. The .ps1 reads with `ReadAllText(..., UTF8)` (aitools-lib.ps1:3124), which replaces invalid bytes with U+FFFD. Probe P8: a 15-byte `img.png` (`PNG\0\0\x89\xff end`) deployed as 10 bytes (.sh) and 16 bytes (.ps1). Both rows were `added`, and the two languages wrote different bytes, so sh and ps diverge too. No tracked skill has a binary file today (`git ls-files shared/skills .claude/skills` lists only `.md` files). But deploy-harness collects every tracked file, and vendored skills often ship images or fonts. Suggested fix: before `deploy_managed_file`, treat a file holding NUL bytes or invalid UTF-8 as not text. Either record it `failed` with "binary file, not deployed (text files only)", or copy it byte for byte with a backup and its own outcome. Add a test case.
- **N2: a `.DS_Store` in a retired skill's DEST copy blocks the prune.** `fanout_dir_matches` requires every regular file under TARGET to exist in the candidate. Finder writes `.DS_Store` into any folder a user opens, and the candidate never has one. Probe P3 (sh=ps): `gone` was kept with the ACTION "Claude Code still loads retired skills ... delete them unless you wrote them". This fails safe, and it is the contract's behaviour (3.3/3.4). But on macOS it will be the common case for any skill folder the user ever looked at. Suggested fix: ignore `.DS_Store` (and maybe `Thumbs.db`/`desktop.ini`) on the TARGET side. That is an FO-1 lib change, so record it as a contract change, or filter it in this function.
- **N3: a harness skill named `synced` is written into Claude Code's reserved sync directory.** Probe P1: with a harness skill `synced`, both languages wrote `~/.claude/skills/synced/SKILL.md` next to Claude Code's `synced/<uuid>/...` tree. The row was `added`. The docs say Claude Code skips an authored skill with that name and owns that folder (it can move it to `.trash`). No such skill exists, so the risk is low. Suggested fix: treat `synced` (any case) and names starting `anthropic-skills` as reserved. Record `failed` with a log line in the entry-kind loop (aitools-lib.sh, the `skill_name_kind` loop in `fanout_harness_skills`; .ps1:2973).
- **N4: the retired-prune backups are never pruned.** A new `DEST.bak.<UTC>` directory is created on every run that removes a retired skill (aitools-lib.sh:3194-3198), and nothing prunes it. config-file-safety "Backup before overwrite" keeps directory backups to 5. `backup_dir`'s pruner matches exactly this name pattern (aitools-lib.sh:1081), but only runs when `backup_dir` copies, which it never does here (contract change 2). Retired removals are rare, so this is low. Suggested fix: after creating the backup root, prune `DEST.bak.*` beyond 5 with the same perl matcher, or note it in FO-7's docs as a known gap.

### Notes (no change needed)

- A symlinked subdirectory inside a deployed skill directory is written through (probe P7: `~/.claude/skills/s/scripts -> ~/elsewhere` meant `elsewhere/a.sh` was updated, sh=ps). This is `deploy_managed_file`'s documented live-symlink behaviour, not FO-4's. Mention it in FO-7.
- An exec-bit-only change is reported `verified`, not `updated` (probe P4 rerun: `3 verified` after the mode was cleared). This is cosmetic. A DETAIL line would make it auditable.
- `GetUnixFileMode`/`SetUnixFileMode` need .NET 7 (pwsh 7.3+). On pwsh 7.2 on macOS/Linux, every file would be `failed` through the catch. 7.2 is EOL, so I only note it.

## What I ran (macOS, isolated temp HOMEs)

| Run | Result |
|---|---|
| tests/skills-fanout (bash 5 + pwsh) | 137 passed, 0 failed, 1 skipped (case-only duplicate, APFS) |
| tests/skills-fanout --bash-only (/bin/bash 3.2) | 54 passed, 0 failed, 25 skipped |
| tests/claude-mdm (bash 5) | 38 passed, 0 failed |
| tests/claude-mdm (/bin/bash 3.2) | 38 passed, 0 failed |
| tests/rules-fanout (bash 5 + pwsh) | 118 passed, 0 failed, 1 skipped |
| tests/rules-fanout --bash-only (/bin/bash 3.2) | 44 passed, 0 failed, 23 skipped |
| tests/deploy-harness-mdm | 67 passed, 0 failed (the forced size-gate case passes with the CLAUDE.md padding) |
| Probe P1 live-like DEST: firecrawl-style relative dir symlinks, `synced/` tree, a symlink with a harness skill's name (`fc2`) | symlinks and Claude Code's `synced/<uuid>` tree untouched; `fc2` not written, kept + ACTION, row `WARN 2 added` (alpha, plus the harness skill `synced`: N3); sh=ps |
| Probe P2 names `a [b]` (+ nested `[r]/n?.md`), `x*y?`, `sp ace`, retired `gone [r]` with a decoy `gone` | all deployed; `gone [r]` removed after a backup to `skills.bak.<UTC>/gone [r]/`; decoy untouched; rerun `4 verified`; sh=ps |
| Probe P3 retired with `.DS_Store` | kept + ACTION (N2); sh=ps |
| Probe P4 executable bit `+x` and `a-x` (first run, and after `chmod a-x` on the harness copy) | bit follows the harness copy both ways; sh=ps |
| Probe P5 dry run (fresh HOME) | `OK dry run (no files written)`; nothing written; logs "Would create" and "Would back up and remove gone"; sh=ps |
| Probe P6 unreadable manifest (chmod 000) | `ERROR cannot read skills manifest`, failed item `.aitools-skills-manifest`, skill still deployed, `ERROR 1 failed`; sh=ps |
| Probe P7 symlinked subdir in DEST/<name> | write-through (note) |
| Probe P8 binary file | corrupted (N1) |
| MDM generated scripts with and without `~/.aitools/skills` | covered by tests/claude-mdm: without it, `OK claude skills n/a (no harness skills)`; with it, `2 added` (.sh) and `1 added` (.ps1) |
| `gh pr checks 124` (when posted) | windows, CodeQL and Analyze pass; **macos and linux still pending** (the jobs that run the new suite). This verdict assumes they go green. A red macos/linux job is blocking until fixed |

The probes' exit code 1 came from my fixture (a CLAUDE.md template too short for setup-user-claude's own validation). The skills rows are not affected.

Probe scripts: `.scratch/session-rv124/probe.sh` and `probe-dry.sh` in the reviewer worktree.
