# e9d6-01 inventory analysis: which .sh scripts and suites must run on Windows

Version 1.0, 2026-11-14. Author: e9d6-01-inventory-analysis (delegate of 38dc-13-windows-ci-ps1-only,
under M6-Polish, Session Commander 87795dc3-e). Read-only research on worktree
`.claude/worktrees/38dc-13` (HEAD 654900c = origin/main 2ee68d9 + 38dc-13 commit; no
`scripts/`, `.claude/rules/` or `tests/` change except `tests/b8-consumers`, `tests/lib`),
plus the diffs of open PRs #154, #155, #157 (saved in `.scratch/session-e9d6-01/pr*.diff`).

**Intent**: **Purpose**: give 38dc-13 the evidence to classify each script and suite under
the commander's 2026-11-14 rule. **Scope**: the seven work items of the e9d6-01 brief.
NOT edits to any product, test or rule file. NOT running any `.sh` suite. **Audience**: 38dc-13.

Rule applied (commander, 2026-11-14, verbatim): "unless a script is explicitly marked as
cross-platform for good reasons, such as build-deploy.sh and all perl/python scripts, sh
scripts and tests should only run on linux/mac and ps1 on windows."

Classes: **(a)** cross-platform for a good reason (keep on Windows); **(b)** Linux/macOS only
(guard, drop from the windows CI job; the `.ps1` twin suffices); **(c)** needs a new `.ps1`
equivalent (behaviours listed).

## 0. The fact that decides most of item 1 and item 2

The bash entry point `scripts/aitools` runs on Windows in real use, every Claude Code session:

1. `aitools-install.ps1` Step 6 copies it to `%USERPROFILE%\.local\bin\aitools`
   ("Install bash aitools (for Git Bash compatibility)", `scripts/aitools-install.ps1:459-467`).
2. The hook `shared/hooks/dashboard-serve.sh` is registered for SessionStart
   (`shared/hooks/hooks-manifest.json:15`) and runs `aitools` or `$HOME/.local/bin/aitools`
   `dashboard --background` (`dashboard-serve.sh:36-45`). Claude Code on Windows runs hooks in
   Git Bash, so this is the bash `aitools`.
3. `scripts/aitools` sources `aitools-lib.sh` for every command, `dashboard` included
   (`scripts/aitools:1537-1548`; the dashboard dispatch to `aitools-dashboard.ps1` comes later,
   `:1689-1706`).
4. Typed in Claude Code's Bash tool (Git Bash), `aitools` / `aitools user init` /
   `aitools install` run the bash entry point, whose Windows branches run the `.ps1` setup
   scripts (`deploy_configs` `:1104-1161`, user init `:988-1026`, install `:2159-2180`) and,
   at the end of every sync, `source relay-outbound-prompt.sh` (`:2350-2357`).
5. `build-deploy.sh` (cross-platform by the approved exception) sources `aitools-lib.sh` in a
   child bash to resolve the dotprofile (`scripts/build-deploy.sh:216-223`); on Windows the
   lib's `_aitlib_profile_run` takes its Git Bash branch and runs `aitools-profile.ps1` through
   pwsh (`scripts/aitools-lib.sh:196-224`). `aitools.ps1` Step 2 runs build-deploy.sh with Git
   Bash (`scripts/aitools.ps1:2015-2040`), as do `check-pre-push.ps1` step 7 (`:128-179`) and
   `check-pre-commit.ps1` (`:28`, `:117-118`).

So `scripts/aitools`, `aitools-lib.sh` and `relay-outbound-prompt.sh` are Windows code today.
A guard (exit 1) on any of them breaks SessionStart's dashboard hook, `aitools` in Claude
Code, and build-deploy.sh's dotprofile resolution on Windows. Sourced files cannot carry the
canonical guard at all: `exit 1` in a sourced file ends the caller (an alias module would
close the user's shell).

What on Windows reaches which bash-lib functions (real use, not tests):

| Function group (`aitools-lib.sh`) | Windows caller |
|---|---|
| `logging_init`, `log*`, rotation, fail-safe append, `write_summary`, `show_summary`, `display_path`, `read_config_key` | `scripts/aitools` (every command), build-deploy.sh's resolver child, every POSIX-guarded `.sh` before its guard refuses |
| `tty_interactive`, `read_menu_choice`, `read_tty_choice` | `scripts/aitools` (`check_profile` `:108-151`, user init `:396-880`), `relay-outbound-prompt.sh:94` |
| `run_child_relayed` | `scripts/aitools` user init `:1003`, `:1040` (Windows branch runs `setup-user-config.ps1` through it) |
| `resolve_user_repo_path`, `_aitlib_profile_run` (pwsh branch) | `scripts/aitools:2085`, `build-deploy.sh:221` |
| `invoke_ai` Windows agent lookup (`:860-866`) | none found (only the AI merge calls it) |
| `deploy_managed_file`, `prompt_diff_review`, `review_json_fields`, `sync_managed_json`, AI merge and spinner, dotprofile adopt commit+push | **none on Windows**: only the POSIX-guarded `setup-user-*.sh` and the MDM `deploy/*.sh` call them (build-deploy.sh only names them in comments and inlines the lib into `deploy/*.sh`, `:1393-1468`, `:2303`) |

## 1. Product scripts (item 1)

| Script | Windows reach (citations) | Twin | Class | Reason for the table, or what breaks |
|---|---|---|---|---|
| `scripts/aitools` (bash entry point) | Installed on Windows by `aitools-install.ps1:459-467`; run by the SessionStart hook `dashboard-serve.sh:36-45`; typed in Git Bash; Windows branches at `:160`, `:988-1026`, `:1104-1161`, `:1693-1701`, `:2096-2100`, `:2119`, `:2159-2180`, `:2324-2345` | `aitools.ps1` (native PowerShell) | (a) | "Installed on Windows so `aitools` works in Git Bash (Claude Code's shell) and in the SessionStart dashboard hook; its Windows branches dispatch the `.ps1` scripts." Already in the table (row "Entry points with Windows branches", 2026-11-01). See open question Q1 (turn it into a thin forwarder). |
| `scripts/aitools-lib.sh` | Sourced by `scripts/aitools:1547`, by build-deploy.sh's resolver child (`:218`), by `aitools-install.sh:15` (Windows forwarder) and `build-package.sh:52`, and by every POSIX-guarded `.sh` before its guard | `aitools-lib.ps1` | (a) | "Sourced on Windows by the bash entry point, build-deploy.sh and build-package.sh (Git Bash); every POSIX-guarded script loads it before its guard so the refusal is logged." A guard is impossible (sourced). |
| `scripts/check-lib.sh` | Sourced only by the five POSIX-guarded `check-*.sh` (`check-pre-commit.sh:11`, `check-pre-push.sh:11`, `check-post-push.sh:10`, `check-prereq-detection.sh:12`, `check-script-compliance.sh:13`; all carry the guard), before their guard. The `check-*.ps1` use Git Bash only for `bash -n`, `aitools --version` and build-deploy.sh (`check-post-push.ps1:52-59,114,190`; `check-pre-commit.ps1:28-118`; `check-pre-push.ps1:128-179`), never check-lib.sh | `check-lib.ps1` | (a) for loading, (b) for behaviour | Keep exempt (cannot be guarded: sourced, and the guard of its callers needs its logging). Reason: "Sourced before the OS guard by the POSIX-guarded check scripts, so their refusal is logged on every platform." Its own behaviour (steps, checks.log) is POSIX-only on Windows: test it on macOS/Linux only. |
| `scripts/init-logging.sh` | Sourced only by the same five `check-*.sh`, before their guard (`check-pre-commit.sh:13` etc.) | `init-logging.ps1` | (a) for loading | Same as check-lib.sh: "sourced before the OS guard so the guard logs with `log_error`". 8 lines, no behaviour of its own (`scripts/init-logging.sh:7-8`). |
| `scripts/relay-outbound-prompt.sh` | Sourced by `scripts/aitools:2351-2356` after every sync, so on Windows whenever `aitools` runs in Git Bash; also by `hh.sh:109-113` (not on Windows) | `relay-outbound-prompt.ps1` (sourced by `aitools.ps1`, `hh.ps1`) | (a) while Q1 is open | "Sourced by the bash entry point, which runs on Windows in Git Bash." Cannot carry an exit guard (sourced). If Q1 makes `scripts/aitools` forward to `aitools.ps1` on Windows, it becomes (b) with no Windows caller. **No suite tests it on any platform** (`git grep` over `tests/`: only `test-menu-choice.ps1` names the `.ps1`). |
| `scripts/hh.sh` | None. Installed only by `aitools-install.sh:591-600` (Step 6), which a Windows run never reaches (it forwards to `aitools-install.ps1` at `:80-99`); the Windows installer installs only `hh.ps1` (`aitools-install.ps1:479-486`) and `setup-user-shell.ps1:104` defines `function hh` for it; README says Windows gets `hh.ps1` (`README.md:121`) | `hh.ps1` | (b) | Nothing on Windows calls it. A guard must use structured logging (script-standards), but `hh` is installed alone as `~/.local/bin/hh` with no lib beside it and deliberately loads no lib (`relay-outbound-prompt.sh:93`): the guard has to come after `find_aitools_repo` and source `$REPO_ROOT/scripts/aitools-lib.sh` + `logging_init`, or the rule needs a "lib-free guard" exception (Q3). |
| `scripts/bootstrap.sh` | None. Its header is macOS/Linux (`:2`), and it already refuses other OSes: `*) die "Unsupported OS '$OS'. On Windows use bootstrap.ps1 (irm ... | iex)."` (`:57-59`); README gives Windows `bootstrap.ps1` (`README.md:44-47`) | `bootstrap.ps1` | (b) | It is a curl-piped one-liner that runs before any clone, so it cannot source the lib; its `die` is the guard in effect but is not the canonical pattern the os-guards suite recognises. Either convert to the canonical guard text with a lib-free logger (Q3) or keep the exemption with the reason "remote one-liner run before the clone exists; refuses non-macOS/Linux itself (`uname` case)". |
| `scripts/init-hh-hooks.sh` | Only manual: README tells users `bash scripts/init-hh-hooks.sh` (`README.md:122`) with no platform split. It runs one `git config core.hooksPath scripts/githooks` (`:8`). The hook it enables, `scripts/githooks/pre-commit`, runs in Git Bash on Windows (exempt row "Entry points with Windows branches") | none | (b) or retire | Nothing breaks on Windows if guarded: the README already gives the alternative `git config core.hooksPath scripts/githooks`. `plans/merge-friction-improvements.md:660` proposes deleting it and `scripts/githooks/pre-commit`. Suggested: guard (or delete with the hook, Q4). |
| `scripts/analyze-session.sh` | None: no caller in the repo (`git grep`: only docs, `scripts/analyze-session.sh:4` usage line); no Windows doc | none | (b) | Read-only transcript analyser needing node; no Windows use. Guard it (needs the lib for `log_error`) or retire it if `read-session.py`/harness-db replaced it (unknown; Q5). |
| `shared/shell/aliases.sh` | Not wired on Windows: `setup-user-shell.ps1` writes only `$PROFILE` (`aliases.ps1`, `aitools`, `hh`: `:14`, `:104`), never a Git Bash rc. README shows it as a generic bash/zsh rc line (`README.md:165-170`). Its `clip2md` has a Windows message (`:167-169`: "clip2md: on Windows, use the PowerShell version instead"), so a manual Git Bash source was anticipated | `aliases.ps1` | (b) without an exit guard | A sourced module cannot `exit 1`. If a refusal is wanted: at the top, on MINGW/MSYS/CYGWIN print one line and `return 0` (defines nothing). Otherwise keep the exemption with the reason "sourced into an interactive shell; must not exit it; not installed on Windows". |

Not in the brief's list but the same table: `scripts/aitools-install.sh` (exempt, Windows
forwarder, `:80-99`) has no automatic Windows caller (`scripts/aitools` `install` calls
`aitools-install.ps1` directly, `:2177`); it is reached only by a manual `bash
aitools-install.sh` in Git Bash. Its forwarder is a reasonable "good reason" to keep it.
`build-package.sh` is in the table as "P-1, pending approval": it builds the `.intunewin`
only on Windows (`scripts/build-package.sh:225-238`, BP-4), so it must run in Git Bash on
Windows: (a).

## 2. Suites the windows job runs through Git Bash that have a `.ps1` twin (item 2)

| Suite | What it tests | Reached on Windows in real use? | `.ps1` twin coverage | Class | Notes |
|---|---|---|---|---|---|
| `tests/logging/test-logging.sh` (Windows CI: 36/0) | `aitools-lib.sh` logging (format, levels, colours, `log_detail`, counters, `write_summary` promotion, 5 MB rotation, fail-safe writes: log is a directory / chmod 000 / dir cannot be created) and `scripts/aitools` (no own log functions, unknown argument, pre-lib warnings, missing lib, `--version`) (`:56-176`). PR #157 adds check-lib.sh checks.log/checks.jsonl cases (`pr157.diff` 1159-1209) | **Yes**: every group is used by `scripts/aitools` and build-deploy.sh's child on Windows (section 0). The #157 check-lib.sh cases: **no** (check-lib.sh is only POSIX code on Windows) | `test-logging.ps1` tests `aitools-lib.ps1` + `aitools.ps1`, not the bash code. Bash-only behaviours with no Windows test if dropped: everything above. `.ps1` lacks a "deploy.log is a directory" case and a "pre-lib warnings logged after the lib loads" case (case lists `:58-182`) | (a) for the lib and entry-point cases while Q1 keeps bash `aitools` on Windows; (b) for #157's check-lib.sh block | If Q1 is answered "forwarder", the whole suite becomes (b). Either way, split the check-lib.sh block out of the Windows run (it tests POSIX-only code). The chmod 000 case is vacuous on NTFS (operational learning). |
| `tests/managed-files/test-managed-files.sh` (Windows CI: 79/0, 3 SKIP) | `deploy_managed_file`, `prompt_diff_review`, `review_json_fields`, tracker, AI merge, display, array detail, read-only copies, abort, setup-user-claude.sh CLAUDE.md adopt filter (`:2-4`, cases `:116-500`) | **No** (section 0 table: no Windows caller of these bash functions). The suite itself SKIPs "claude.md adopt round trip: setup-user-claude.sh does not run on Windows" (CI log) | `test-managed-files.ps1` mirrors most. `.sh`-only cases (by name; bodies not diffed): deploy-state note (`:133`), failed backup (`:148`), `--force` on a terminal (`:165`), JSON LOCAL-only field alone -> verified (`:308`), precedence -> accept & adopt (`:443`), JSON skip (`:457`), JSON write failure (`:462`), the array-detail matrix (`:351-383`; the `.ps1` has 3 detail checks `:207-211`), "json review node script identical in both libs" (`:334`, a static cross-lib check), CLAUDE.md adopt filter of setup-user-claude (`:492-500`) | (b) | Gaps above are parity gaps for the `.ps1` twin to add; none is a reason to keep the `.sh` on Windows. PR #155 adds matching EOF cases to both (`pr155.diff` 316-380, 211-259): no change. |
| `tests/managed-files/test-adopt-push.sh` (Windows CI: 28/0) | dotprofile adopt commit+push helper and its use through `deploy_managed_file` (`:130-234`) | **No** (bash adopt only from POSIX `setup-user-*.sh`) | `test-adopt-push.ps1`. `.sh`-only cases: new untracked file added+pushed (`:144`), caller-resolved dotprofile wins with no resolver call (`:154`), two push failures -> one ACTION row (`:184`), the backup file is not committed (`:198`), merge & adopt into the dotprofile (`:205`) | (b) | Port the five cases to the `.ps1` twin (parity). |
| `tests/menus/test-menu-choice.sh` (Windows CI: 78/0, pywinpty) | `read_menu_choice`/`read_tty_choice` unit cases (`:136-213`), the real managed-file menus (`:260-358`), the bash spinner's signal/trap/exit handling (`:368-486`) | **Partly**: `read_menu_choice`/`read_tty_choice` are used on Windows by `scripts/aitools` user init and `relay-outbound-prompt.sh`; the managed-file menus and the spinner are not (no Windows caller; the spinner runs only inside `_invoke_ai_merge`) | `test-menu-choice.ps1` mirrors the unit and real-menu cases (`:318-440`) and adds the `[RELAY]` prompt cases (`:457-548`); the PowerShell spinner is covered by `tests/aitools-entry/test-console-mode-guard.ps1:345-467`. The bash relay prompt (`relay-outbound-prompt.sh`) is tested nowhere | (b) for the managed-file menu and spinner cases; (a) for the `read_menu_choice` unit cases only while Q1 keeps bash `aitools` on Windows | Simplest: (b) for the whole suite on Windows if Q1 = forwarder. If bash `aitools` stays, a small Git Bash case for `read_menu_choice` + `relay_outbound_prompt` belongs with the entry-point tests, not this suite. |

Windows-relevant bash behaviour tested only by `.sh` suites (outside the four above, for
38dc-13's parallel porters):

- `tests/hookin/test-hookin.sh` on Windows runs the **Windows branch of `deploy_configs` in
  `scripts/aitools`** (bash, the `.ps1` list with pwsh; `test-hookin.sh:33-36`, `:178-194`,
  `:283-294`; CI step name `check.yml:811`). That is bash product code that runs on Windows;
  a `.ps1` port of test-hookin cannot test it. Keep that loop case as (a) in a Git Bash run, or
  drop it only if Q1 makes bash `aitools` a forwarder. Tell the tests/hookin porter.
- `tests/profile/test-lib.sh` "gitbash" / `via-pwsh-*` cases: `aitools-lib.sh` under Git Bash
  taking the pwsh branch of `_aitlib_profile_run` (`test-lib.sh:37-39`, `:343`, `:683-690`;
  Windows CI 201 passed). Used by build-deploy.sh and `scripts/aitools` on Windows: (a).
- The bash `aitools user init` Windows branch (`scripts/aitools:988-1026`) is **not tested on
  Windows**: `tests/profile/test-user-init.sh` runs `aitools.ps1` there (`:19`, `:52`).
- `tests/hooks/test-sh-file-fixup.sh` has a "Windows backslash path (cygpath -w), as Claude
  Code on Windows sends it" case (Windows CI log): hook behaviour, (a).

## 3. `tests/pywinpty/test-setup-pywinpty.sh` (item 3)

| Part | What it tests | Windows reach | `.ps1` twin | Class |
|---|---|---|---|---|
| `dev-*`, `mdm-*` (`:6-9`, `:16-17`) | `setup-pywinpty.sh` and `deploy/setup-pywinpty.sh` print `OK|pywinpty|n/a (<platform>)` | Already SKIP on Windows (CI log: "POSIX-guarded: refuses Windows (exit 1), covered by tests/os-guards") | n/a (`.sh` is POSIX) | (b), already effectively |
| `build-*` (`:10-15`) | build-deploy.sh writes `deploy/setup-pywinpty.ps1` with the here-string `$AitoolsEmbeddedPywinptyPin` (pywinpty== line, every `--hash=sha256:` line, `'@` at column 0, text equal to `scripts/requirements-pywinpty.txt`), library inlined, parses under pwsh; `deploy/setup-pywinpty.sh` passes `bash -n` | **Yes**: build-deploy.sh runs on Windows (aitools.ps1 Step 2) and this is the step that embeds the pin for the Windows MDM script | `test-setup-pywinpty.ps1` case g (`:31-35`, `:390-448`) runs build-deploy.sh through Git Bash and runs the generated `.ps1` (-DryRun row, "Pin: embedded in this script", install from the temp pin). It does **not** check the here-string text equality, the `'@` column-0 rule or `bash -n` of the generated `.sh` | (a) |
| `pin-*` (`:18-26`) | six broken pins (missing, empty, no pywinpty== line, a `'@` line, no `# wheel-tags:` line, no hash) make the build exit 1 with "Cannot embed the pywinpty pin" and leave the dotprofile `deploy/` unchanged | **Yes** (build-deploy.sh behaviour) | not covered by the `.ps1` | (a) |

"MDM pin embed via Git Bash" is build-deploy.sh behaviour; build-deploy.sh is cross-platform by
the approved exception (`cross-platform.md` "Approved exceptions", 2026-02-17) and the
commander's own example. Reason for the table: "tests build-deploy.sh's pywinpty pin embed,
which runs on Windows (aitools.ps1 Step 2) and produces the Windows MDM script". Optional: fold
the text-equality and `pin-*` checks into the `.ps1` case g so Windows needs no `.sh` here.

## 4. Check-script suites (item 4)

Pattern shared by four of the five: they cut a step's section out of **both** twins and run
it with stub step functions, so on Windows the `.sh` twin's section (POSIX-guarded
`check-*.sh` code) runs in Git Bash past its guard, and on Linux/macOS the `.ps1` twin's
section (Windows-guarded `check-*.ps1` code) runs in pwsh past its guard (ubuntu-24.04 and
macos-15 runners have pwsh). That is the cross-run the commander removed on 2026-11-01 (plan
order 5: "linux/mac should only run the scripts meant to run there").

| Suite | What it runs on Windows | Class | What the `.ps1` equivalent covers |
|---|---|---|---|
| `tests/check-pre-push/test-pre-push-step7.sh` (CI 3/0) | Only `check-pre-push.ps1` whole, via pwsh (`:89-91`); the `.ps1` itself runs build-deploy.sh with Git Bash (`check-pre-push.ps1:128-179`). On macOS/Linux the `.sh` (`:93-94`). The `.sh` harness is a pure driver on Windows | (c) | `tests/check-pre-push/test-pre-push-step7.ps1`: clone of the repo with one commit ahead of a fake origin/main and the working-tree `scripts/` copied over (`:58-66`); fixture dotprofile with `deploy/` gitignored and one with a committed stale `deploy/` (`:68-81`); temp HOME + USERPROFILE + `config.json` (`repoPath`, `userRepoPath`) and the four env vars unset (`:84-91`); checks: untracked -> step 7 `[PASS] fresh build OK (dotprofile deploy/ untracked, not compared); resolver consumers dry-run clean`; the fixture dotprofile left clean; stale -> `[FAIL] dotprofile deploy/ is stale` (`:100-110`). SKIP without node; FAIL without Git Bash under CI |
| `tests/check-post-push/test-post-push-step7.sh` (CI 10/0) | `.sh` twin step 7 section in Git Bash (`:67-96`), `.ps1` twin section in pwsh (`:98-132`), static perl reads of both files (`:94-95`, `:133-137`) | (c) | `.ps1` harness: cut "# 7." to "# 9." from `check-post-push.ps1` (CRLF stripped), run with stub `StepPass/Fail/Warn/Skip`, `InvokeGit`, temp HOME, a fake scripts dir whose `build-deploy.sh` writes a marker, `$bashExe` set; checks: exit 0, no marker, exactly one result `SKIP 7 retired: check-pre-push step 7`; static: no non-comment line runs build-deploy with `&`, `bash` or `Start-Process`. The `.sh` harness keeps only the `.sh` twin (macOS/Linux) |
| `tests/check-post-push/test-menu-parity.sh` (CI 24/0) | `check-menu-parity.pl` cases lib, planted, fixtures, errors (`:6-19`): Perl; step 29 sections of both twins (`:20-22`, `:207-225`) | split: Perl cases (a) by the commander's "all perl/python scripts"; twin sections (c) | `.ps1` harness: (1) the Perl cases, run with `perl scripts/check-menu-parity.pl` from pwsh, which is how `check-post-push.ps1` step 29 runs it on Windows (`check-post-push.ps1:886-889`); (2) the `.ps1` step 29 section with stub step functions against a copy of the libs: PASS on the current pair, FAIL on a planted mismatch. The `.sh` harness keeps the Perl cases and the `.sh` section, macOS/Linux only |
| PR #154 `tests/check-post-push/test-post-push-deploy-steps.sh` | Steps 2, 6, 14 sections of both twins on two fake repos (frozen deploy/ with broken files; broken sources), twins-identical check, static check (`pr154.diff` 988-1001). Its own "Limits" note says that on Windows the `.sh` twin's `.ps1` audit is stubbed to a SKIP and its CRLF case is not checked (Git for Windows grep strips CR) (`pr154.diff` 1003-1006) | (c) | `.ps1` harness: the `.ps1` sections on both fake repos: frozen -> `SKIP 2` (retired text), `PASS 6` (.sh), `PASS 6` (.ps1), `PASS 14`, no marker, HOME unchanged by checksum; sources -> `FAIL 6` (.sh), `FAIL 6` (.ps1), `FAIL 14`, one file each; static: no non-comment line reads the aitools `deploy/`. The cross-twin "results identical" check needs both runs: use committed golden results (`tests/lib/platform-lib.sh` pattern) instead of running both twins on one machine |
| PR #154 `tests/check-pre-commit/test-pre-commit-steps3-10.sh` | Steps 3 and 10 sections of both twins, fix on/off; static checks; whole-script run with the fix flag, `.ps1` on Windows, `.sh` elsewhere (`pr154.diff` 1292-1312, `TEST_RUN_TWIN` `:1349-1352`) | (c) | `.ps1` harness: steps 3/10 sections of `check-pre-commit.ps1` with `-Fix` on and off: no marker, nothing staged under `deploy/`, exactly `SKIP 3` and `SKIP 10` naming check-pre-push step 7, no WARN and no `-Fix` advice; static (no line runs build-deploy or stages deploy/, no result text advises `-Fix`, the `-Fix` usage line does not say it builds); whole `check-pre-commit.ps1 -Fix` from a clone whose build-deploy.sh is the fake: steps 3/10 SKIP, summary printed, no marker, HOME and dotprofile unchanged by checksum, nothing staged under `deploy/`, steps 4 and 6 still repair a staged CRLF / 100644 `.sh` (LF, 100755) |

After #154 merges: check-post-push step 7 and check-pre-commit steps 3/10 no longer run
build-deploy.sh in either twin (retired SKIPs), so the only Git Bash product use left in these
checks is `bash -n`, `bash scripts/aitools --version` (`check-post-push.ps1:114`) and
check-pre-push step 7's build-deploy.sh. #154's check.yml adds both new suites to the windows
job as `bash ...` steps (`pr154.diff` 380-393): 38dc-13's layout should replace those with the
`.ps1` harnesses. #154 does not change the conclusions above.

## 5. Item 5

| Suite | Windows today | Class | Reason |
|---|---|---|---|
| `tests/setup-user-shell/test-setup-user-shell.sh` | Not in the windows job (`check.yml` runs only the `.ps1`, `:786-789`); when run there it prints SKIP and exits 0 (`:25-28`) | (b) | Tests POSIX-guarded `setup-user-shell.sh`; `test-setup-user-shell.ps1` covers the Windows script. Optional: replace the in-suite SKIP with nothing (it is never run on Windows). |
| `tests/ci-suites/test-check-ci-suites.sh` | Linux job only (`check.yml:458-460`) | (b) | Tests `scripts/check-ci-suites.pl`, whose only caller is the linux job's static "Every test suite is in CI" step (`check.yml:443-456`). Perl is cross-platform, but nothing runs this Perl script on Windows; no reason to test it there. |

## 6. Cross-platform candidates (item 6)

| Suite | Product code it runs on Windows | Any `.ps1` product code? | Class | Reason |
|---|---|---|---|---|
| `tests/os-guards/test-os-guards.sh` (CI: 31 POSIX-guarded `.sh`, 49 exempt, 34/0) | Runs every POSIX-guarded `.sh` with Git Bash under an isolated HOME and checks the refusal (`:166-170`); reads the exemption table (`:70-118`) | No (the `.ps1` refusals run on macOS/Linux, `:171-181`) | (a) | "Proves every POSIX-guarded `.sh` refuses Git Bash on Windows; that can only be shown by running it in Git Bash." A `.ps1` driver would still launch Git Bash per script. Any guard 38dc-13 adds (hh.sh, analyze-session.sh, init-hh-hooks.sh) is picked up automatically (classification from the files, `:61-121`); a removed exemption row makes an unguarded script fail it (`:129-136`). |
| `tests/hooks/test-*.sh` (6: delegation-duty-guard, workflow-delegation-guard, sh-file-fixup, glossary-skill-guard, sessionstart-harness-db, hooks-smoke) | `shared/hooks/*.sh` only (headers; `git grep` finds no `pwsh` or `.ps1` in the six files); hooks-smoke also runs harvest-session/session-catchup (Python `ait-harvest.py` path) | No | (a) | "Claude Code runs hooks in Git Bash on Windows" (`cross-platform.md` "Hook portability"). sh-file-fixup has a Windows-only case (backslash paths from Claude Code on Windows). Windows CI: delegation-duty-guard and workflow-delegation-guard each SKIP one "perl absent" case. |
| `tests/build-deploy/test-build-deploy-backup.sh` (CI 24/0) | `scripts/build-deploy.sh` only; a stub `pwsh` replaces the PS1 validator, "no .ps1 is run or parsed" (`:18-20`) | No | (a) | "build-deploy.sh is the approved cross-platform bash builder (2026-02-17), run on Windows by aitools.ps1 Step 2." |
| `tests/build-package/test-cli.sh` (CI 36/0) | `scripts/build-package.sh` (CLI, dry-run plans, stubs) (`:2-14`) | No (`packaging/windows/*.ps1` are only named in the plan text, `build-package.sh:312-316`) | (a) | "build-package.sh builds the Windows `.intunewin` and can only do so on Windows (IntuneWinAppUtil.exe, BP-4, `build-package.sh:225-238`)." Its exemption row still reads "P-1, pending approval" (`cross-platform.md:114`). |

## 7. Docs and briefs (item 7)

| File:line | Quote | Proposed sentence |
|---|---|---|
| `CLAUDE.md:51-53` | "A script is tested only where its OS guard lets it run: linux and macOS run the `.sh` halves, Windows runs the `.ps1` halves on native pwsh, and cross-platform scripts (hooks, Python, the bash entry points) run on all three." | "A script is tested only where it runs: `.sh` scripts and `.sh` suites on Linux and macOS, `.ps1` scripts and `.ps1` suites on Windows (native pwsh). Only scripts the exemption table marks cross-platform (hooks, build-deploy.sh, build-package.sh, Perl and Python, and the bash entry point while it is installed on Windows) are also tested on Windows, through Git Bash." (Channel exception: direct to main.) |
| `.claude/rules/cross-platform.md:116` | "Entry points sourced or run on any platform (rationale unrecorded, pending approval) ... Bootstrap/shell helpers; each `.sh` also runs in Git Bash" | Split the row per section 1: keep `relay-outbound-prompt.sh` ("sourced by the bash entry point, which runs on Windows in Git Bash"); `bootstrap.sh` (reason in section 1 or guard); move `hh.sh`, `init-hh-hooks.sh` out (guarded). The `.ps1` names in that row are Windows-guarded or Windows-only already and need no exemption reason beyond their own headers. |
| `.claude/rules/cross-platform.md:110-111` | "Shared libraries ... Dot-sourced, never invoked directly"; "Init libraries ... Sourced for initialization" | "Sourced on every platform: the bash entry point, build-deploy.sh and build-package.sh load `aitools-lib.sh` in Git Bash, and every POSIX-guarded script loads its library before the guard so the refusal is logged." |
| `.claude/rules/cross-platform.md:118` | "Analysis tools (rationale unrecorded, pending approval) | `analyze-session.sh`" | Remove the row and guard the script (or retire it). |
| `plans/ci-platform-targeting.md:47` | "`build-deploy.sh`, `build-package.sh`, `bootstrap.sh`, `hh.sh`, `relay-outbound-prompt.sh`, `init-hh-hooks.sh`, `analyze-session.sh`, `aitools-lib.sh`, `check-lib.sh`, `init-logging.sh` | all (exemption table: "each .sh also runs in Git Bash") | linux, macos, windows" | Replace with the per-script classes of section 1 (a v1.2 of the plan, or a pointer to this report). |
| `reference/smoke-test-pattern-detail.md:19-20` | "On Windows (Git Bash), always use `pwsh -File` for `.ps1`. Never run `.sh` setup scripts on Windows" | Add: "Never run `.sh` test suites on Windows either: run the `.ps1` suite with `pwsh -NoProfile -File tests/<dir>/test-<name>.ps1`. Only the suites of cross-platform scripts (hooks, build-deploy, build-package, os-guards) run in Git Bash." |
| `reference/evaluations/pywinpty-windows-2026-11-13.md:325` | "`bash tests/managed-files/test-managed-files.sh > $env:TEMP\mf-sh.log 2>&1; "exit $LASTEXITCODE"`" (Windows test commands for the pywinpty evaluation) | An evaluation record of what was run on 2026-11-13; leave it, or add a dated note: "Since 2026-11-14 the `.sh` suite does not run on Windows; the Windows evidence is the `.ps1` command on the next line." |
| PR #157 `M6-F-report.md` (new file; about lines 83, 165, 193) | "The bash halves run in Git Bash under a `uname -s` → Linux spoof (`spoof-linux.sh`), as local evidence only"; operational learning: "A `uname -s` spoof exported as a bash function (`export -f uname`) runs a platform-targeted suite's bash half in Git Bash. It is useful local evidence" | Contradicts the commander's rule ("local Windows evidence must be .ps1 runs, not Git Bash .sh runs") and the 2026-11-01 order to remove guard overrides. Replace the learning with: "Do not spoof `uname` to run a `.sh` suite on Windows; Windows evidence is the `.ps1` suites; the `.sh` halves are evidenced by the macOS and Linux CI jobs." The same claim is in #157's RELEASE_NOTES "Verified on" (about line 39) and in incident #174's `correctiveAction` (`pr157.diff` 583): mark those runs as superseded evidence. INCIDENT candidate below. |
| `plans/merge-friction-improvements.md:166-167`, `:287`, `:432`, `:655` | windows jobs "via Git Bash"; `windows-extended` job running `test-profile, test-config, test-lib, test-user-init, test-adopt-push, deploy-harness` with `shell: bash`; "`tests/run-suites.sh` as a bash-only test driver (Git Bash is the managed bash on Windows)" | Plan v1.1 of 2026-10-26, older than ci-platform-targeting (2026-11-01) and today's rule; its status is unknown. If still live: "The suite driver runs `.sh` suites on macOS/Linux and `.ps1` suites on Windows (a `run-suites.ps1` twin); no `.sh` suite runs in Git Bash except the cross-platform list." |
| `plans/mission-command-briefing/task-rebuild-brief.py:390` | "(4) Test on both macOS and Windows Git Bash" | Historical brief generator (2026-03); low value. If kept: "Test on macOS/Linux (`.sh`) and on Windows with the `.ps1` twin". |
| `plans/build-package/doc-edits-pending.md:197` | proposed cross-language row for build-package.sh, "the kind tools are native executables that Git Bash can launch" | Consistent with the rule (a cross-platform build script). No change; it is the P-1 approval item. |
| `.github/workflows/check.yml:622-623`, `:798-800` | "Windows -- validates PS1 scripts natively + bash scripts via Git Bash"; "Heavy suites, .ps1 half: Git Bash drives native pwsh" | 38dc-13 rewrites the job; new header: "Windows -- `.ps1` suites natively; Git Bash only for the cross-platform suites (hooks, build-deploy, build-package, os-guards, and the bash entry point while Q1 is open)". |
| `reference/cross-platform-detail.md:261`, `:284-292` (being edited by 38dc-12) | "No bash twin is needed: Git Bash keeps its own terminal state..."; the bash spinner "seen in Git Bash, mission M3b"; "Tests: the spinner cases of `tests/menus/test-menu-choice.sh`" | Pointer only: the spinner cases run on macOS/Linux after this change (the bash spinner has no Windows caller); the PowerShell spinner's tests are `tests/aitools-entry/test-console-mode-guard.ps1`. |

Searched and clean (no instruction to run `.sh` suites on Windows or to bypass guards):
`shared/skills/**` (only `scratch/SKILL.md:151-157`, which runs scratch scripts, not suites),
`.claude/skills/**`, `README.md` (its Windows rows use `.ps1`; `bash scripts/build-deploy.sh`
at `:139` is the cross-platform builder), `shared/rules/**`, `tests/**/*.md` (none exist).

## Open questions (each with a suggested answer)

- **Q1. Should the bash `aitools` stay a full entry point on Windows?** It is installed there
  (`aitools-install.ps1:459-467`) and run by the SessionStart dashboard hook. Suggested: make it
  a thin forwarder on MINGW/MSYS/CYGWIN (like `aitools-install.sh:80-99`): `exec pwsh -NoProfile
  -ExecutionPolicy Bypass -File aitools.ps1` with translated flags, before it sources the lib.
  Then `aitools-lib.sh` (except for build-deploy.sh's resolver child), `relay-outbound-prompt.sh`,
  the bash user-init and deploy_configs Windows branches leave Windows, and test-logging.sh,
  test-menu-choice.sh and test-hookin's Windows loop case become (b). Until decided, keep them (a).
  Risk to check first: `aitools.ps1` prompts through Git Bash's mintty (console mode, ConPTY).
- **Q2. Do test suites that only read the other twin's file text (static perl checks) violate
  the rule?** Suggested: no; reading a `.ps1` from a `.sh` harness executes nothing. Only
  executing a script, or a section of it, outside its platform does.
- **Q3. Guards on scripts that cannot load the lib (`hh.sh`, installed alone; `bootstrap.sh`,
  run before the clone)?** Suggested: allow a lib-free guard (the canonical `case` with a
  `printf` to stderr in the `[timestamp] [script] [error]` format) as a recorded exception in
  `cross-platform.md`, and teach `tests/os-guards` to accept it; or keep `bootstrap.sh` exempt
  with its existing `uname` refusal.
- **Q4. `init-hh-hooks.sh` and `scripts/githooks/pre-commit`: guard or delete?** Suggested:
  delete both (`plans/merge-friction-improvements.md:660` proposes it; the hook rebuilds the real
  dotprofile `deploy/`, README `:122` already warns against it in worktrees). If kept: guard
  `init-hh-hooks.sh`, keep the hook exempt.
- **Q5. `analyze-session.sh`: guard or retire?** Suggested: guard now (no Windows caller);
  retirement is a separate decision for whoever owns the session-analysis tools.
- **Q6. Should FO-0 check per-platform coverage?** `check-ci-suites.pl` counts a suite run in
  any job (`check.yml:452-455`). Suggested: after the new layout, extend it so each `.sh` suite
  must run in the macos and linux jobs and each `.ps1` suite in the windows job, with the
  cross-platform `.sh` suites listed in its exemption table with their reason.
- **Q7. Should the `.ps1` twins close the parity gaps listed in section 2 before the `.sh`
  suites leave Windows?** Suggested: no, they are independent (the `.sh` cases test bash code
  that never runs on Windows); file the gaps as follow-ups so the twins reach parity.

## Lines for 38dc-13

- WRITE_BLOCKED: none.
- CONFLICT: none. (Brief item 1 says "add a POSIX guard"; for sourced files that is not
  possible, so section 1 gives "keep exempt with a reason" or a `return` refusal instead. This
  follows the brief's own "keep exempt with a recorded reason" option, not a conflict.)
- INCIDENT: PR #157's M6-F report recommends a `uname -s` spoof (`export -f uname`) to run
  platform-targeted `.sh` suites in Git Bash as local evidence, and its release notes and
  incident #174 corrective action cite those runs. That is a guard bypass, against the
  commander's 2026-11-01 order 5 and the 2026-11-14 rule. Spec deviation, medium.
- INCIDENT: `tests/check-post-push/test-post-push-step7.sh`, `test-menu-parity.sh` and #154's
  two suites run the `.ps1` twin's step sections in pwsh on Linux and macOS, past the Windows
  guard (sections are cut out and dot-sourced), against plan `ci-platform-targeting.md` order 5.
  Spec deviation, medium.
- INCIDENT: `scripts/relay-outbound-prompt.sh` (sourced on every bash `aitools` run, Windows
  included) and the bash `aitools user init` Windows branch have no test on any platform /
  on Windows. Gap, low.
