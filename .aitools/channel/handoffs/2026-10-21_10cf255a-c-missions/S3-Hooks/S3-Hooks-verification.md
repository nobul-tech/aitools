# S3-Hooks verification (mission HOOKS, incidents #80, #81, #82)

Written by S3-Hooks, 2026-10-21, on macOS (Darwin arm64). Branch `fix/hook-lifecycle`
from origin/main c8573ed. Every run used an isolated `HOME` under the worktree's
gitignored `.aitools/scratch/s3-hooks/`; nothing ran against the real `HOME`, and
`build-deploy.sh` never targeted the real dotprofile. The test scripts are in that
scratch folder (`guard-smoke.sh`, `hooks-functional.sh`, `build-isolated.sh`,
`step7-main.sh`, `parse-check.sh`, `run-checks.sh`); they are not committed.

## 1. Syntax and parse (all touched scripts)

`parse-check.sh` (bash -n; pwsh 7.6.3 `[System.Management.Automation.Language.Parser]::ParseFile`):

```
bash -n OK: scripts/setup-user-hooks.sh
bash -n OK: shared/hooks/standing-order-guard.sh
bash -n OK: scripts/build-deploy.sh
pwsh parse: scripts/setup-user-hooks.ps1 -> PARSE OK
```

## 2. standing-order-guard.sh smoke tests (#82)

`guard-smoke.sh`: 28 cases, each `printf '{"tool_name":"Bash","tool_input":{"command":"<cmd>"}}' | HOME=<fake> bash shared/hooks/standing-order-guard.sh`,
checking the exit code and whether a line was appended to `<fake>/.aitools/logs/standing-order-guard.log`.
Run twice: default `bash` and `/bin/bash` 3.2.57 (macOS system bash). **28 passed, 0 failed on both.**

| Group | Commands | Expected | Result |
|-------|----------|----------|--------|
| Clean | `git status`, `ls -la` | exit 0, no log | PASS |
| #82 read-only prints, now allowed | `sed -n '60,75p' scripts/setup-user-hooks.sh` (the incident's command, quoted), `sed -n 60,75p ...` (unquoted), `sed -n 12p a.txt`, `sed -n '100,$p' a.txt`, `sed -n '$p' a.txt`, `sed -n 1,5p a.txt b.txt` | exit 0, no log | PASS |
| Pipeline (unchanged) | `git log \| sed -n 1,3p` | exit 0, no log | PASS |
| sed write/edit forms reach the check (observe: log, exit 0) | `sed -i '' 's/a/b/' file.txt`, `sed -n 1p -i file.txt`, `sed -n 1p --in-place file.txt`, `sed -n '1,5w out.txt' file.txt`, `sed -n 's/a/b/w out.txt' file.txt`, `sed -n 1,5p file.txt > out.txt`, `sed 's/a/b/' file.txt`, `sed -n '/foo/p' file.txt`, `sed -n 1p` (no file) | exit 0 + `[WOULD-BLOCK]` log line | PASS (9 log lines) |
| Other checks unchanged (enforce) | `git status && git log`, `git status \|\| true`, `ls ; ls`, `cat file.txt`, `head -5 file.txt`, `tail -5 file.txt`, `awk '{print}' file.txt`, `rm -f *.tmp`, `echo hi > f.txt`, `sed -n 1p a.txt && ls` | exit 2, no log | PASS |

Observe-log sample (verbatim, one of nine):

```
2026-10-21T22:57:49Z [WOULD-BLOCK] USO: Dedicated tools --: Use the Edit tool instead of 'sed' to modify files. For non-trivial string manipulation, use Perl (USO: Perl for string manipulation). Read-only line prints (sed -n 'N,Mp' file) are allowed; the Read tool with offset/limit is preferred. | cmd: sed -i '' 's/a/b/' file.txt
```

Consequence to note: while `MODE_SED="observe"`, sed edits outside a pipeline are
logged, not blocked. That is what `.claude/rules/hook-rollout.md` "When to reset to
observe" requires after a matching-logic change; promote to `enforce` after 1+ week
with zero false positives in the log.

## 3. setup-user-hooks.sh functional runs (#80, #81)

`hooks-functional.sh`: a copy of `scripts/` and `shared/hooks/` under scratch (so an
adopt cannot touch the worktree's real `shared/hooks`), a fake `HOME` with
`.aitools/config.json` `userRepoPath` pointing at a fake dotprofile. `script -q /dev/null`
provides a pty where a terminal is needed.

| Scenario | Setup | Result (verbatim from the run, ANSI stripped) |
|----------|-------|------------------------------------------------|
| A: non-interactive (`< /dev/null`, no pty) | dotprofile `claude/hooks/standing-order-guard.sh` = stale 3-line copy; `~/.claude/hooks/user-custom.sh` present | exit 0. `[warn] Ignoring dotprofile copy of managed hook standing-order-guard.sh (...dotprofile/claude/hooks/standing-order-guard.sh): shared/hooks is the only source -- delete the copy`; `[info] Non-interactive: skipped adoption prompt for user-custom.sh`. Deployed hook vs repo `shared/hooks`: SAME. Deployed hook vs dotprofile copy: DIFFERENT (#80: the shadow is no longer deployed) |
| B: pty, stdin at EOF | same state, dotprofile copy removed | exit 0. `User-created hook detected: user-custom.sh`, `[warn] No input at prompt (EOF) -- defaulting to skip`, `[info] Skipped adoption of user-custom.sh`, `COMPLETED with 1 warning(s)`. Nothing adopted |
| B-control: pre-change script (`git show origin/main:scripts/setup-user-hooks.sh`) | identical state | **exit 1**, output ends at `User-created hook detected: user-custom.sh` with no error line and no summary row: the #81 / GitHub #29 failure mode, reproduced |
| C: pty, adopt | deployed hook line 2 edited locally (`# LOCAL EDIT by user`), source line 2 edited differently (`# SOURCE EDIT upstream`) so the 3-way merge conflicts; answers `a` then `s`, one every 4 s | exit 0. `Merge has conflicts -- manual choice required.`, `choice [o/a/m/s/x]: a`, `>> adopted: local version copied back to aitools shared/hooks`, `[ok] Adopted -> .../fake-repo/shared/hooks/standing-order-guard.sh`, `Review: cd .../fake-repo && git diff`. Repo `shared/hooks/standing-order-guard.sh` now equals the local edit (line 2 = `# LOCAL EDIT by user`). Dotprofile `claude/hooks/standing-order-guard.sh` created: **no**; dotprofile `claude/hooks/` empty (#80/SD-2) |

A first attempt at C piped both answers at once; the pty delivered EOF to the first
prompt, which then took the logged default (`No input at prompt (EOF) -- defaulting to
overwrite`), and the second answer went to the reverse-discovery prompt (adopted
`user-custom.sh` to the dotprofile, as that menu offers). That run is a second
confirmation of EOF-safe behavior in the lib's diff review; the timed feeder fixed the
harness.

## 4. build-deploy.sh (MDM path)

No code change. Reason (scripts/build-deploy.sh:1293-1337 and 1387-1427): the
generated `deploy/setup-user-hooks.*` replace the whole `# --- BEGIN hook deployment`
... `# --- END hook deployment` block with embedded hooks resolved from `shared/hooks/`
then `scripts/`; there is no dotprofile lookup, adopt, or reverse-discovery prompt to
mirror. The guard change reaches MDM through the embed (`cat`).

`build-isolated.sh` (isolated `HOME`, fake dotprofile): build exit 0;
`bash -n OK: deploy/setup-user-hooks.sh`; `pwsh parse deploy/setup-user-hooks.ps1: PARSE OK`;
`MODE_SED="observe"` present in the embedded guard (sh 2, ps1 2 occurrences);
`resolve_hook`, `Resolve-HookSource`, `User-created hook`, `DOTPROFILE_HOOKS`,
`dotprofileHooks`: 0 occurrences in either generated script. `adopt_managed_file` /
`Adopt-ManagedFile` appear only as inlined library definitions (no call sites).

`step7-main.sh` (check-pre-push step 7 mechanics, run for origin/main and for HEAD):
the diff between the two generated `deploy/setup-user-hooks.sh` is exactly the guard
change (the `MODE_SED` lines, the exemption comment + regex, the `if/else` around
`violation`).

## 5. Repo checks

| Check | Result | Notes |
|-------|--------|-------|
| `check-pre-commit.sh` (no `--fix`, so its build-deploy call does not run) | 11 PASS, 2 SKIP, 6 WARN, 1 FAIL | FAIL = step 6, `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` is 100644 on origin/main (pre-existing, not touched here). WARNs: step 3/13 build freshness (dotprofile regenerated separately), 5 platform note (in commit message), 7 install cmd, 9 release notes, 11 uncommitted changes in the real dotprofile (not mine; I made no writes there) |
| `check-pre-push.sh` | 6 PASS, 3 WARN, 1 FAIL | FAIL = step 7: dotprofile `deploy/` stale for setup-user-claude, setup-user-hooks, setup-user-skills. `step7-main.sh` shows setup-user-claude and setup-user-skills are already stale on origin/main; setup-user-hooks is this branch's guard change and is expected until the dotprofile `deploy/` is regenerated after merge. Step 7 builds under its own temp `HOME` (check-pre-push.sh:120-135) |

## 6. Not run

- `setup-user-hooks.ps1` was not executed: its OS guard exits on macOS, and no Windows
  machine was available. Parse-checked only. The PS1 changes mirror the bash logic
  line for line (resolve order, shadow warning, adopt target, `Test-InteractiveConsole`
  gate, `Read-ConsoleChoice "skip"`).
- `deploy/setup-user-hooks.*` (MDM) were not executed; parse-checked only.
- No Linux or Windows Git Bash run of the guard.
