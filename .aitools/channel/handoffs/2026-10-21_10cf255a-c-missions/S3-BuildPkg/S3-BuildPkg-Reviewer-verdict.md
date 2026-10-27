# S3-BuildPkg-Reviewer verdict: build-package v1.0 plan set and scaffolding

Reviewer: S3-BuildPkg-Reviewer (level 2, independent; wrote none of the reviewed material). Date 2026-10-26.
Reviewed at main 32bf20c: `plans/build-package/{design,implementation-plan,remediation,doc-edits-pending}.md`,
`scripts/build-package.sh`, `packaging/**`, `tests/build-package/test-cli.sh`, doc diffs of 5494d93
(and 32bf20c, which landed during the review and applied doc-edits items 1, 4, 5).
Not read: the writers' notes and the decisions file (independence). Claims were checked against code, PR diffs
and official docs.

## Verdict: APPROVE WITH CHANGES

The plan set covers every commander requirement and the technical claims I checked hold. I found no blocking
defect: the plan is design-level, and each batch delegate re-drafts against the code. The 13 should-fix items
are contract and consistency gaps that would cost an executing delegate a failed batch or a wrong rule. Two of
them are already live on main: the summary-row tool name in the scaffold (F1) and the Equivalence text in
protected `deploy-paths.md` (F2). Fix those two first.

## 1. Commander requirements (brief) — coverage

| Requirement | Covered | Where |
|---|---|---|
| Three package kinds | yes | design §1, plan 3.1 |
| Ubuntu 24.04 + 22.04, container and VM; one package decided | yes (one `.deb`, `Architecture: all`) | design §3(b); plan §5 rows 1-4 |
| Fleet | yes | design §1, §8 |
| Five platforms/environments | yes; `cursor-cloud` is pending P-2 | design §1; cross-platform-detail.md "Supported platforms and environments" |
| Unsigned first | yes | design §14, B14 |
| Parallel distribution | yes | design §2, §3(d) |
| Q4-Q6 resolved | yes | design §9-§11, §15 |
| Language, build hosts, coexistence | yes | design §3(a), (c), (d) |
| Abort as in #106 | yes | plan 3.4 |
| Dotprofile push from a non-main branch = ERROR | **no batch** | RM-47 is mapped to "B5", but neither B5a nor B5b lists it (see F6) |

## 2. Claims verified

1. deploy-harness needs a git work tree: `scripts/deploy-harness.sh:182-184` (`rev-parse --is-inside-work-tree` → ERROR "not a git checkout"). Holds.
2. An unknown installer option exits 0: `scripts/aitools-install.sh:47-51` (`log_warn` + SHOW_HELP), `:76` `exit 0`. Holds (RM-20).
3. Order file = the post-#106 sync order: the PR #106 diff adds `deploy_scripts="deploy-harness.sh setup-user-claude.sh setup-user-mcp.sh setup-user-skills.sh setup-cursor-ide-mcp.sh setup-user-cursor.sh setup-user-settings.sh setup-user-hooks.sh"` (and the .ps1 twin), and drops setup-user-config. This matches plan 3.4.
4. winget in SYSTEM: "the WinGet CLI is not supported in the system context" (learn.microsoft.com/en-us/windows/package-manager/winget/troubleshooting, read with chrome-devtools 2026-10-26). Holds.
5. Intune detection script: "detected when the script both returns a 0 value exit code and writes a string value to STDOUT". `powershell.exe` in the install command starts 32-bit; Sysnative forces 64-bit. "Environment variable expansion within the Uninstall command is not supported." (learn.microsoft.com add-win32, read 2026-10-26). All match design §5 and §12 and plan 3.6.
6. Lib names: `logging_init` (aitools-lib.sh:658) writes `$AITOOLS_LOG_DIR/deploy.log` (:661), so contract change C-2 is right. Also present: `write_summary` :860, `write_environment_skip` :878, `deploy_managed_file` :1792, `sync_managed_json` :2437, `show_summary` :2827. PS1: `Initialize-Logging` honours `AITOOLS_LOG_DIR` (:562); `Test-IsAdmin` is at :2664 (RM-49).
7. check-pre-push has steps 1-10 and the skip label "1-10" (check-pre-push.sh:40, :253-258), so step 11 is free (B11b).
8. Payload facts: there are no symlinks or submodules in the include paths (`git ls-files -s`); the two `.bak.*` files are tracked (RM-72); `.claude/hooks` is absent (a dry run reports it skipped); B2's perl `EXCLUDE_RE` filters `.bak.` and `.DS_Store` correctly (scratch test).
9. Not re-verified: the `.deb` Depends versions (Launchpad), the pwsh 7.6.6 MSI name, and the Jamf and Intune macOS behaviour (left to the B12 matrix as planned).

## 3. Scaffolding checks

- `tests/build-package/test-cli.sh`: 32 passed, 0 failed under bash 5.3, and 32/0 under `/bin/bash` 3.2 (isolated HOME and AITOOLS_LOG_DIR in `.scratch/session-review/home`).
- `build-package.sh all --dry-run --version 0.1.0` (isolated HOME): exit 0. The plan lines are correct, but see F1.
- `bash -n` passes on the script, the macOS and Linux launchers and the test. `plutil -lint` passes on the LaunchAgent. The pwsh parser passes on all three `.ps1`. Modes: launchers 100755; control.in, the plist and the `.ps1` files 100644. The `.ps1` files are LF with no BOM.
- build-package.sh against script-standards: the block order is fine (the missing OS guard is the pending P-1 exemption). Every `log_error` path ends in an ERROR row. The one `2>/dev/null` (:268-270) is commented and checked, and the `command -v` checks are commented. The exit footer is present. Nit: `source aitools-lib.sh` has no existence check (B2's pseudocode adds one).
- Stubs: each has a header, refuses to run (exit 1 with an error line on stderr) and uses PS 5.1-safe syntax. Their headers drift from the plan (F5, N1, N2).

## 4. Findings

Severity: blocking / should-fix / nit.

**F1 (should-fix). Every summary row is named `build-package`, and `show_summary` keeps one row per tool name.**
- Where: plan 3.1 "Summary rows"; `scripts/build-package.sh` (`TOOL`); `tests/build-package/test-cli.sh` row checks.
- Evidence: aitools-lib.sh:2833 `show_summary` dedups rows by tool name and shows the highest severity. My standalone `all --dry-run` panel showed one row (`intune: n/a (macos)`); the `deb: n/a` and `dry-run: stage, pkg` rows were dropped. The same will happen to the per-kind `OK build-package <kind>: <file>` rows, and to several ERRORs, which collapse into one.
- Fix: give each kind its own tool name (`build-package pkg`, `build-package stage`, ...), or use DETAIL rows. Update plan 3.1 and test-cli.sh.

**F2 (should-fix; live in a protected rule). The Equivalence section in `.claude/rules/deploy-paths.md` contradicts design.md.**
- Where: `.claude/rules/deploy-paths.md` "Equivalence" (committed in 32bf20c); doc-edits-pending entry 4.
- Evidence: the rule says "the same ... summary rows" and "only the profile-sourced content differs". Design §3(d) lists five reported differences: repoPath, no pull/clone/build, no adopt or merge, no gh auth, no dotprofile. F3 and N4 add two more.
- Fix: replace the paragraph with the design's numbered list, plus the relay and version items. The rule is protected, so this needs commander approval.

**F3 (should-fix). Installer Step 22 (relay → `~/.cursor/AGENTS.md`) is not handled in package mode.**
- Where: `aitools-install.sh` :847-870; scripts/aitools :1189, :1295; aitools.ps1 :206-225.
- Evidence: `.aitools/` is excluded from the payload (design §4). `sync-relay-to-cursor-agents.py:136-138` returns 1 when relay.md is missing, so every package run gets WARN "failed (non-fatal)". If the relay were included instead, fleet users would get Jose's failure-mode relay in `AGENTS.md`.
- Fix: in B3a/B3b, write OK `relay sync` `n/a (package)` in package mode, and list it among the equivalence differences.

**F4 (should-fix). B3b (and possibly B3a) will break `tests/hookin/test-hookin.sh`, which is not in their file lists.**
- Evidence: PR #106's test-hookin.sh asserts with static greps that the lists are inline: `grep -cE '^ +local deploy_scripts="deploy-harness\.(sh|ps1) '` and `'^ +\$deployScripts = @\("deploy-harness\.ps1", '` (diff lines ~805-807). It also extracts `deploy_configs` into a fixture repo (:808), which will not contain `aitools-order.txt`.
- Also: B3a's verification cites `tests/profile/test-install.sh`, which does not exist (the profile tests are test-config, test-lib, test-profile and test-user-init).
- Fix: add `tests/hookin/test-hookin.sh` (and `hookin-driver.ps1` if it is affected) to B3b, making it 3 files, and correct the test name in B3a.

**F5 (should-fix). The Windows App A host is contradictory.**
- Where: `packaging/windows/install-system.ps1` header :15-17; `install-user.ps1` :20; plan 3.6 and B9a; design §5.
- Evidence: the scaffold says App A "Runs BEFORE pwsh 7 may exist, so it must parse and run under Windows PowerShell 5.1 (Sysnative)". The plan says App A is started by `C:\Program Files\PowerShell\7\pwsh.exe` with `#Requires -Version 7`, after a pwsh 7.6 dependency app. Microsoft confirms that `powershell.exe` in an install command runs 32-bit (claim 5).
- Fix: pick one. The plan's choice is consistent with BP-8 and the pwsh 7 baseline, so update the scaffold headers. `detect-user.ps1` stays 5.1 (under the P-1 exemption).

**F6 (should-fix). Remediation items with no executable batch.**
- Evidence: remediation uses unsplit IDs (B3, B5, B6, B7), while the plan claims "same batch ID" (plan B6 intro). Unassigned in effect:
  - setup-user-mcp: RM-63, RM-64, RM-65 (P-3 MCP tiers too). It is in no B6 sub-batch.
  - setup-user-skills: RM-73. Also in no B6 sub-batch.
  - RM-41 (`as_root`, `install_via_brew` / `install_via_apt`): B7a requires it, and plan B7 says "its own lib batch", but that batch does not exist.
  - RM-47 (commander decision).
  - B3 items RM-23, 25, 27, 28, 29, 30 are absent from B3a/B3b behaviour.
  - B5 items RM-43, 48, 50-53 are absent from B5a/B5b behaviour.
- Fix: give each RM a lettered batch. Add B5c (privilege and install helpers, RM-41, before B7), B6g (setup-user-mcp) and B6h (setup-user-skills). Mark deferred items `--dev` explicitly.

**F7 (should-fix). The BP-10 refuse-when-privileged guard does not reach every user-scope writer.**
- Evidence: plan B6 says "Every script calls `require_user_context`", but deploy-harness (B4), setup-user-mcp, setup-user-skills and setup-cursor-ide-mcp have no batch that adds it. deploy-harness writes `~/.aitools` first in the order.
- Fix: add the guard to B4 and to the new B6g/B6h, and to B7 for the tool scripts.

**F8 (should-fix). The launcher batches depend on B5a only, but they need B5b.**
- Evidence: postinstall, App A and `aitools-setup` run as root or SYSTEM and relocate `AITOOLS_LOG_DIR`. Design §13 says the logging fail-safe (RM-46) and the HOME guard (RM-26) "matter when a launcher relocates" it, and both are in B5b.
- Fix: add B5b to the After column of B8a, B9a and B10b (contract change C-1).

**F9 (should-fix). Launcher exit policy is not recorded as an exemption.**
- Evidence: B8a's postinstall pseudocode writes an ERROR row on resolution rc 3 and then exits 0. This deliberately breaks the script-standards exit footer (ERRORS > 0 → exit 1). The same applies to the B10c cloud snippets (RM-113).
- Fix: put the launcher exit policy (exit non-zero only for a broken payload; ERROR rows reported through logs and markers) into the P-1 "package launchers" row text.

**F10 (should-fix). B2 pseudocode errors.**
- (a) `printf ... > "$STAGE_DIR/VERSION"` runs unconditionally, which contradicts 3.1/3.2 ("stage without --version: no VERSION file").
- (b) The text after the block refers to a "delegate: use perl" marker and a `sed` placeholder, and neither exists. This is stale.
- (c) If `present` is empty, `git ls-tree -r ... --` and `git archive $COMMIT --` take the whole tree, including `deploy/` and `plans/`.
- (d) `[ -n "$(git ... ls-tree ...)" ]` turns a git failure into "include path absent", which is a silent failure.
- Fix: guard each case, and check git's exit status separately.

**F11 (should-fix). The `--phase system` side effects under SYSTEM are unspecified.**
- Evidence: App A runs `aitools-install.ps1 -Phase system -PackageMode` as SYSTEM. The installer preamble (logging, summary-file touch RM-27, the config dir) would write under the SYSTEM profile, which BP-10 and RM-39 forbid.
- Fix: plan 3.3 should state that the system phase writes only under `AITOOLS_LOG_DIR` and HKLM, and that it creates nothing under `$HOME`.

**F12 (should-fix). The plan has gone stale since it was written.**
- Line bases are 5976553 (plan) and 0ddd127 (remediation); HEAD is now 32bf20c.
- §6 still lists #99 as open, but it merged, and 32bf20c applied doc-edits items 1, 4 and 5.
- B0 is done (568fb5b, 5494d93) but not marked.
- The doc-edits-pending status lines say "uncommitted", but they are committed in 32bf20c.
- B13 promises drafts that doc-edits-pending does not contain: the script-standards-detail exemption for `detect-user.ps1`, the interactive-menus line, RM-105 and RM-108.
- Fix: refresh §6 and B13, and add the missing drafts.

**F13 (should-fix). design §3(a) contradicts the pinned interface on host detection.**
- Evidence: design §3(a) says kinds are chosen by capability, "never by `$AITOOLS_PLATFORM`". Plan 3.1 `detect_kind` and the scaffold (build-package.sh:209, :220, :236) test the platform first.
- Fix: make design §3(a) match the plan's stated BP-4 reason, and cite it in P-1.

**N1 (nit). control.in render rules are not pinned in the plan.**
- The scaffold strips `#` lines; plan B10a only says "`@VERSION@` replaced".
- `Section: devel` (scaffold) differs from `admin` (plan). `Homepage` exists only in the scaffold.
- Fix: pin the render rules and the fields in plan B10a.

**N2 (nit). Linux launcher headers drift from the plan.**
- The `aitools-setup` header says it is installed to `/usr/bin/aitools-setup`; the plan installs it at `/opt/aitools/bin/` with a `/usr/bin` symlink. The header's usage also lacks `--rerun`.
- The postinst header steps 2-3 (check the symlink, log to `/var/log`) are not in plan B10a.

**N3 (nit). Windows naming differs.** The supported list says "Windows 11"; the launcher headers say "Windows 10/11".

**N4 (nit). `repo_version` cannot report a payload's version.** It uses `git describe` (scripts/aitools:1074-1088), so in a payload it yields "unknown" or a date. B3b should read `VERSION`.

**N5 (nit). winget may not be registered yet for a new user.** winget is an MSIX "registered for the user" (MS troubleshooting page). Whether it is registered right after first sign-in, when App B runs, is unverified. Add this to R-8 and B12 row 10.

**N6 (nit). B12's After column is too narrow.** It lists only B8-B11, but its pass criteria ("no `[error]`") also need B4, B5b and B6.

**N7 (nit; unverified). `runuser -u <user> --` may not set HOME.** Pass `HOME=$AITLIB_TARGET_HOME` explicitly in `run_as_target_user`.

**N8 (nit). Personal address in the public fleet package.** `Maintainer: nobul-tech <jose@nobul.tech>` puts a personal address in a public fleet package. The plan already lists it as an open question; the suggested answer is a team or noreply address.

## 5. Plan review (/optimize-plan, applied by hand)

- **Stale:** F12.
- **Dependencies:** F4 (B3b → test-hookin), F8 (launchers → B5b), F6 (B7a → missing lib batch), N6.
- **Leverage:**
  - B3a unblocks B3b, B8a, B9a and B10a.
  - B5a unblocks B6 (all sub-batches), B7 and every launcher.
  - B2 is independent and unblocks B4's tests, B8-B11 and B11b. Start it now, next to B1.
- **Scope:** the plan is one coherent effort. B7 (14+ tool batches) is effectively a separate workstream under `/tool-adopt`; consider tracking it as its own plan.
- **Missing:** F3 (relay), F11 (system-phase writes), RM-47 scheduling.

## 6. INCIDENT markers (not filed)

- INCIDENT: show_summary's dedup by tool name silently drops OK rows for multi-row tools; build-package hits it (F1).
- INCIDENT: protected rule `.claude/rules/deploy-paths.md` "Equivalence" overstates equivalence against design.md §3(d) (F2).

WRITE_BLOCKED: none.
