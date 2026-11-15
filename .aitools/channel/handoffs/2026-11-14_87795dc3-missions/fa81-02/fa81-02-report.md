# fa81-02-report (v1.0): early-exit pipe readers out of every pipefail script, hook and test suite; step 7 widened; no Git-perl fallback

**Intent**: **Purpose**: record what mission fa81-02-tests-pipes did, how it was
verified, what it found and what is still open. **Scope**: branch
`fix/fa81-02-tests-pipes` and its PR. NOT the merge result or main's CI after
the merge (those go in the hand-back only: no pushes to main). **Audience**:
the session commander of session 87795dc3 and the commander (pepe).

v1.0, 2026-11-15, written before the independent review and the merge.

## Summary

- 136 pipelines under `pipefail` that ended in a reader that stops early now
  use a form that reads to the end: `grep -q` 81 (16 test suites), `head` 40
  (6 in suites, 30 in `scripts/`, 4 in `shared/hooks/`), perl `exit` 15
  (`aitools-lib.sh` 8, `build-deploy.sh` 2, `setup-user-config.sh` 1, the
  `test-lib` Git Bash driver 4). 6 sites in `scripts/aitools` are left: it has
  no `pipefail`.
- `check-script-compliance` step 7 fails on every early-exit reader (grep
  `-q` / `-l` / `-L` / `-m`, `head`, perl `exit` / `last`) in `scripts/`,
  `scripts/githooks/`, `shared/hooks/` and `tests/`; its suite has a bad and a
  fixed case per reader plus the #168 review-note-4 edge cases.
- `tests/os-guards/test-os-guards.ps1` no longer falls back to Git for
  Windows' bundled perl; without perl it FAILs once, names the fix, and exits 1
  before any case. `tests/profile/test-profile.ps1` keeps Git's perl on purpose.
- Found on the way: two checks of `validate_ai_merge_output` (bash) never
  fired (perl runs `END` after `exit`); they now fire, as the PS1 twin does
  (RFI fa81-02-2).
- Docs: reference section, rule paragraph (and Cursor twin), post-push
  checklist step 23; RELEASE_NOTES v0.77.25.

## Scope change

The prompt scoped the mission to `tests/` ("NOT `scripts/` or `shared/`
(#168 covered them)"). #168 covered `grep -q` only; the ~35 `head` sites of
38dc-24's follow-up are in `scripts/` and `shared/hooks/`. RFI fa81-02-1 asked;
the commander answered, relayed verbatim by the session commander (2026-11-15):
"32) yes it should, and it should expand the scope of the tests to include
this test case. do it in one PR". So this PR fixes every reader in `tests/`,
`scripts/` and `shared/hooks/` and widens step 7 and its suite.

## Findings

| ID | Severity | What | Evidence | Action |
|---|---|---|---|---|
| fa81-02-F1 | high | `validate_ai_merge_output` checks 2 (code fences) and 3 (refusal text) never rejected anything: `perl -ne 'exit 0 if /RE/; END { exit 1 }'` always exits 1, because perl runs `END` after `exit` and the `exit` in `END` sets the status. The PS1 twin rejects | probe (Git Bash, perl 5.42.3): fence present -> exit 1, absent -> exit 1; END form -> 0 / 1. `scripts/aitools-lib.ps1:1544, 1551`. Main vs branch on the same inputs: fenced output passes checks 2-3 on main, branch rejects "AI wrapped output in code fences" | fixed in ea21566 (own commit, revertible alone); RFI fa81-02-2 |
| fa81-02-F2 | medium | 136 early-exit readers under `pipefail` (inventory below); the writer can die of SIGPIPE and the pipeline fail although the reader found its match | Git Bash 5.3: `seq 1 300000 \| head -n 1` 20/20 exit 141, `\| grep -qx 1` 20/20 exit 141; `sed -n '1p'` and both perl forms 0/20 each (probe-lib.sh, the step 7 suite emulation) | fixed in 593274f, 101d2df, 0b0ee4d, 3cefdda, e5e0c49, 781bf2b, 0d1611f, ebac9fe, ea21566, e46ec0f, 955c554, 4a02abf, 94445e0, 58b9e67, ff43472 |
| fa81-02-F3 | medium | `tests/os-guards/test-os-guards.ps1:44-48` fell back to `Git\usr\bin\perl.exe` when no perl was on PATH | file at e207fea; cross-platform.md "Git Bash PATH shadowing": "no fallback to bundled versions"; commander 2026-11-15 (27-1) | fixed in e5e0c49: check-lib's Strawberry block, PATH perl, one FAIL + exit 1; negative test passed |
| fa81-02-F4 | low | `tests/profile/test-profile.ps1:130-138, 259-264` uses Git's perl only, for `aitools-json.pl` | deliberate: `build-deploy.sh` (run in Git Bash on Windows, cross-platform.md approved exception) calls `perl "$JSON_PL"` at lines 278-304 with no Strawberry prepend, so in production `aitools-json.pl` runs under Git Bash's perl; the harness already FAILs when that perl is missing | left (deliberate, per the commander's 27-1 rule) |
| fa81-02-F5 | low | `build-deploy.sh` payload-sha (2089) and `cursor.cli.model` (310) checks passed an empty value: `perl -n` runs no line on empty input and exits 0 | probe: empty input, `perl -ne 'exit 0 if /RE/; exit 1'` -> 0 | fixed in e46ec0f (`-0777`: empty fails) |
| fa81-02-F6 | low | `check-post-push.sh:440` `$(claude --version \| head -1 \|\| echo "unknown")` could print the version and then "unknown" when claude died of SIGPIPE | code reading | fixed in 955c554 |
| fa81-02-F7 | low | `standing-order-guard.sh:310` `FIRST_LINE=$(printf ... \| head -1)` under `set -euo pipefail`: a SIGPIPE'd printf would end the hook with 141, which Claude Code does not treat as a block (fail open) | not reproduced: 20 runs of main's hook on a 300 KB command all exited 2 on Git Bash | fixed in ff43472 (no mode reset: blocks exactly what it blocked) |
| fa81-02-F8 | low | `scripts/aitools` has 3 `grep -q`, 2 `head`, 1 perl `exit` readers | no `set` / `pipefail` line in the file (Grep); without pipefail the pipeline's status is the reader's | left; step 7 does not flag it (no pipefail) |
| fa81-02-F9 | low | `shared/skills/mission-control/SKILL.md:103` shows `ls -t ... \| head -5`; build-deploy embeds it in the generated `setup-user-skills.sh` heredoc, where a scan of the generated scripts lists it | doc example for an agent's shell, not run under pipefail; heredoc text is not executed | left |
| fa81-02-F10 | decision | Widen step 7 to `tests/` and to every reader across the whole scan set | the class recurred in tests/ (81 `grep -q` after #168 fixed 49 in scripts/); commander's "32) yes" | done in 649faf1 |
| fa81-02-F11 | low | Step 7 blind spots: heredoc bodies scanned as code; a reader behind another word (`LC_ALL=C grep`, `PERLIO=:perlio perl`); perl programs in double quotes or with `exit` on a later line; `sed q`, `awk exit`; bash embedded in a `.ps1` (the `test-lib.ps1` driver) | step 7 header comment | left, documented in the check and the reference |
| fa81-02-F12 | low | With F1 fixed, an AI merge of a file with a line starting with three backticks (markdown with a code block) is rejected on macOS/Linux, as it already was on Windows | `aitools-lib.ps1:1544` `(?m)^```` | proposed follow-up: narrow check 2 in both twins to fences that wrap the whole output |
| fa81-02-F13 | low | `check-script-compliance.ps1` step 7 skip message could say "bash-only; runs in the .sh twin" (38dc-24 follow-up, owner 38dc-23) | 38dc-24-report "Follow-ups" | left (not this mission's file) |
| fa81-02-F14 | low | Process: the counted grep rewriter put one redirection before the pattern (`grep -F >/dev/null "second warning"`, test-lib.sh:633) after its quote tracking was thrown by an escaped quote on line 608 | a scan of the diff for a word after the new `>/dev/null` | fixed in 3cefdda before commit; every changed line was also reviewed in the diff |

## Inventory

Every early-exit reader in the step 7 scan set after merging main e207fea
(PRs #166 and #168), before the fixes, from
`.scratch/session-fa81-02/inventory2.pl` (an independent prototype of the new
step 7 scanner, `step7-scan.pl`, found the same 134 pipefail sites). Open PRs
at inventory time: only #166 and #168 touched inventoried files; #174 touched
`standing-order-guard.sh` and merged before the fix.

| File | Line | Reader | Pipefail | Fix form or left |
|---|---|---|---|---|
| `scripts/aitools` | 43 | head | n | left: no pipefail in scripts/aitools (the reader's own status is the pipeline's) |
| `scripts/aitools` | 345 | perl-exit | n | left: no pipefail in scripts/aitools (the reader's own status is the pipeline's) |
| `scripts/aitools` | 2158 | grep-q | n | left: no pipefail in scripts/aitools (the reader's own status is the pipeline's) |
| `scripts/aitools` | 2179 | grep-q | n | left: no pipefail in scripts/aitools (the reader's own status is the pipeline's) |
| `scripts/aitools` | 2190 | grep-q | n | left: no pipefail in scripts/aitools (the reader's own status is the pipeline's) |
| `scripts/aitools` | 2194 | head | n | left: no pipefail in scripts/aitools (the reader's own status is the pipeline's) |
| `scripts/aitools-install.sh` | 417 | head | y | sed -n '1p' / '1,Np' |
| `scripts/aitools-install.sh` | 703 | head | y | sed -n '1p' / '1,Np' |
| `scripts/aitools-install.sh` | 704 | head | y | sed -n '1p' / '1,Np' |
| `scripts/aitools-install.sh` | 727 | head | y | sed -n '1p' / '1,Np' |
| `scripts/aitools-install.sh` | 728 | head | y | sed -n '1p' / '1,Np' |
| `scripts/aitools-lib.sh` | 102 | head | y (library) | sed -n '1p' / '1,Np' |
| `scripts/aitools-lib.sh` | 422 | perl-exit | y (library) | perl next if $done; if (/RE/) { print; $done = 1 } |
| `scripts/aitools-lib.sh` | 477 | perl-exit | y (library) | perl next if $done; if (/RE/) { print; $done = 1 } |
| `scripts/aitools-lib.sh` | 487 | perl-exit | y (library) | perl next if $done; if (/RE/) { print; $done = 1 } |
| `scripts/aitools-lib.sh` | 494 | perl-exit | y (library) | perl next if $done; if (/RE/) { print; $done = 1 } |
| `scripts/aitools-lib.sh` | 1550 | perl-exit | y (library) | perl next if $done; if (/RE/) { print; $done = 1 } |
| `scripts/aitools-lib.sh` | 1551 | perl-exit | y (library) | perl -0777 -ne 'exit(...)' (status; parity with PS1) |
| `scripts/aitools-lib.sh` | 1557 | perl-exit | y (library) | perl END { exit($f ? 0 : 1) } (check now fires) |
| `scripts/aitools-lib.sh` | 1564 | perl-exit | y (library) | perl END { exit($f ? 0 : 1) } (check now fires) |
| `scripts/aitools-lib.sh` | 1895 | head | y (library) | sed -n '1p' / '1,Np' |
| `scripts/build-deploy.sh` | 310 | perl-exit | y | perl -0777 -ne 'exit(...)' |
| `scripts/build-deploy.sh` | 2089 | perl-exit | y | perl -0777 -ne 'exit(...)' |
| `scripts/check-post-push.sh` | 440 | head | y | sed -n '1p' / '1,Np' |
| `scripts/check-post-push.sh` | 441 | head | y | sed -n '1p' / '1,Np' |
| `scripts/check-pre-push.sh` | 86 | head | y | sed -n '1p' / '1,Np' |
| `scripts/check-prereq-detection.sh` | 159 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-bash.sh` | 33 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-bash.sh` | 52 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-cursor-ide-mcp.sh` | 164 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 56 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 66 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 74 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 75 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 118 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 120 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 135 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 137 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 149 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 150 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 158 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-pandoc.sh` | 159 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-user-config.sh` | 385 | perl-exit | y | perl next if $done; if (/RE/) { print; $done = 1 } |
| `scripts/setup-user-cursor.sh` | 90 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-user-cursor.sh` | 99 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-user-cursor.sh` | 115 | head | y | sed -n '1p' / '1,Np' |
| `scripts/setup-user-mcp.sh` | 111 | head | y | sed -n '1p' / '1,Np' |
| `shared/hooks/harness-db-sessionend.sh` | 31 | head | y | sed -n '1p' / '1,Np' |
| `shared/hooks/harness-db-sessionstart.sh` | 28 | head | y | sed -n '1p' / '1,Np' |
| `shared/hooks/scratch-init.sh` | 38 | head | y | sed -n '1p' / '1,Np' |
| `shared/hooks/standing-order-guard.sh` | 310 | head | y | sed -n '1p' / '1,Np' |
| `tests/b8-consumers/test-b8-consumers.sh` | 95 | grep-q | y | grep PATTERN >/dev/null |
| `tests/b8-consumers/test-b8-consumers.sh` | 96 | grep-q | y | grep PATTERN >/dev/null |
| `tests/b8-consumers/test-b8-consumers.sh` | 170 | grep-q | y | grep PATTERN >/dev/null |
| `tests/b8-consumers/test-b8-consumers.sh` | 174 | grep-q | y | grep PATTERN >/dev/null |
| `tests/build-deploy/test-build-deploy-backup.sh` | 126 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-post-push/test-menu-parity.sh` | 112 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-post-push/test-menu-parity.sh` | 124 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-post-push/test-menu-parity.sh` | 124 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-post-push/test-menu-parity.sh` | 131 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-post-push/test-menu-parity.sh` | 138 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-post-push/test-menu-parity.sh` | 143 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-post-push/test-menu-parity.sh` | 172 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-pre-commit/test-pre-commit-steps3-10.sh` | 174 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-pre-commit/test-pre-commit-steps3-10.sh` | 293 | head | y | sed -n '1p' / '1,Np' |
| `tests/check-pre-commit/test-pre-commit-steps3-10.sh` | 342 | grep-q | y | grep PATTERN >/dev/null |
| `tests/check-script-compliance/test-step7-grepq.sh` | 127 | grep-q | y | left: planted fixture / race demo of the step 7 suite (excluded from the scan) |
| `tests/check-script-compliance/test-step7-grepq.sh` | 128 | grep-q | y | left: planted fixture / race demo of the step 7 suite (excluded from the scan) |
| `tests/check-script-compliance/test-step7-grepq.sh` | 129 | grep-q | y | left: planted fixture / race demo of the step 7 suite (excluded from the scan) |
| `tests/check-script-compliance/test-step7-grepq.sh` | 130 | grep-q | y | left: planted fixture / race demo of the step 7 suite (excluded from the scan) |
| `tests/check-script-compliance/test-step7-grepq.sh` | 131 | grep-q | y | left: planted fixture / race demo of the step 7 suite (excluded from the scan) |
| `tests/check-script-compliance/test-step7-grepq.sh` | 133 | grep-q | y | left: planted fixture / race demo of the step 7 suite (excluded from the scan) |
| `tests/check-script-compliance/test-step7-grepq.sh` | 172 | grep-q | y | left: planted fixture / race demo of the step 7 suite (excluded from the scan) |
| `tests/check-script-compliance/test-step7-grepq.sh` | 243 | grep-q | y | left: planted fixture / race demo of the step 7 suite (excluded from the scan) |
| `tests/claude-mdm/test-claude-mdm.sh` | 95 | grep-q | y | grep PATTERN >/dev/null |
| `tests/claude-mdm/test-claude-mdm.sh` | 260 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` | 207 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` | 270 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` | 529 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 207 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 258 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 332 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 332 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 343 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 400 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 405 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 451 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 477 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 502 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 644 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 720 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 733 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 757 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 757 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 757 | grep-q | y | grep PATTERN >/dev/null |
| `tests/deploy-harness/test-deploy-harness.sh` | 757 | grep-q | y | grep PATTERN >/dev/null |
| `tests/fanout-lib/test-fanout-lib.sh` | 572 | head | y | sed -n '1p' / '1,Np' |
| `tests/fanout-lib/test-fanout-lib.sh` | 589 | grep-q | y | grep PATTERN >/dev/null |
| `tests/hooks/test-workflow-delegation-guard.sh` | 325 | grep-q | y | grep PATTERN >/dev/null |
| `tests/hooks/test-workflow-delegation-guard.sh` | 326 | grep-q | y | grep PATTERN >/dev/null |
| `tests/hooks/test-workflow-delegation-guard.sh` | 327 | grep-q | y | grep PATTERN >/dev/null |
| `tests/managed-files/test-adopt-push.sh` | 207 | grep-q | y | grep PATTERN >/dev/null |
| `tests/os-guards/test-os-guards.sh` | 127 | head | y | sed -n '1p' / '1,Np' |
| `tests/profile/test-config.sh` | 205 | grep-q | y | grep PATTERN >/dev/null |
| `tests/profile/test-config.sh` | 229 | grep-q | y | grep PATTERN >/dev/null |
| `tests/profile/test-config.sh` | 545 | grep-q | y | grep PATTERN >/dev/null |
| `tests/profile/test-config.sh` | 677 | grep-q | y | grep PATTERN >/dev/null |
| `tests/profile/test-lib.ps1` | 268 | perl-exit | y (bash driver in .ps1) | perl next if $done; if (/RE/) { print; $done = 1 } |
| `tests/profile/test-lib.ps1` | 270 | perl-exit | y (bash driver in .ps1) | perl next if $done; if (/RE/) { print; $done = 1 } |
| `tests/profile/test-lib.sh` | 183 | perl-exit | y | perl next if $done; if (/RE/) { print; $done = 1 } |
| `tests/profile/test-lib.sh` | 185 | perl-exit | y | perl next if $done; if (/RE/) { print; $done = 1 } |
| `tests/profile/test-lib.sh` | 633 | grep-q | y | grep PATTERN >/dev/null |
| `tests/pywinpty/test-setup-pywinpty.sh` | 119 | head | y | sed -n '1p' / '1,Np' |
| `tests/pywinpty/test-setup-pywinpty.sh` | 297 | grep-q | y | grep PATTERN >/dev/null |
| `tests/relay-outbound/test-relay-outbound.sh` | 126 | head | y | sed -n '1p' / '1,Np' |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 263 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 273 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 280 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 280 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 281 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 447 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 449 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 453 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 551 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 565 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 579 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 736 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` | 776 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 195 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 269 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 300 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 304 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 326 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 326 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 344 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 355 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 400 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 400 | grep-q | y | grep PATTERN >/dev/null |
| `tests/rules-fanout/test-rules-fanout.sh` | 401 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 244 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 245 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 351 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 516 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 570 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 570 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 670 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 672 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 676 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 680 | grep-q | y | grep PATTERN >/dev/null |
| `tests/skills-fanout/test-skills-fanout.sh` | 744 | head | y | sed -n '1p' / '1,Np' |

150 rows. Line numbers: the tree after merging main e207fea (PRs #166, #168; merge 3a4633e), before the fixes.

## Changes

| Commit | Content |
|---|---|
| 3a4633e | merge main e207fea (#166, #168, #170, #173-#176) |
| 593274f, 101d2df, 0b0ee4d, 3cefdda, 781bf2b | `grep -q` -> `grep ... >/dev/null` in 15 suites (counted rewrite, 2-3 files per batch), `head` -> `sed -n` in 3 suites, the `test-lib.sh` driver's perl readers |
| e5e0c49 | `test-os-guards.ps1` no Git-perl fallback; `test-lib.ps1` driver perl readers; `test-setup-pywinpty.sh` |
| 0d1611f | `head -n 5` in `test-os-guards.sh`, `test-relay-outbound.sh` |
| ebac9fe | `aitools-lib.sh` pipe-safety only (head, perl first-match) |
| ea21566 | `validate_ai_merge_output` status checks (F1) |
| e46ec0f | `aitools-install.sh`, `build-deploy.sh` (F5), `setup-user-config.sh` |
| 955c554 | `check-post-push.sh`, `check-pre-push.sh`, `check-prereq-detection.sh` |
| 4a02abf, 94445e0 | `setup-bash.sh`, `setup-cursor-ide-mcp.sh`, `setup-user-mcp.sh`, `setup-pandoc.sh`, `setup-user-cursor.sh` |
| 58b9e67, ff43472 | hooks: `harness-db-sessionend.sh`, `harness-db-sessionstart.sh`, `scratch-init.sh`, `standing-order-guard.sh` |
| 649faf1 | step 7 widened; its suite extended |
| f47854c | reference section, rule paragraph + Cursor twin, post-push checklist step 23 |
| 0159d30 | merge main d15b67c (#172) |
| 195a06d | RELEASE_NOTES v0.77.25 |

## Verification

All on Windows 11 (native pwsh 7.6.10, Git Bash 5.3.15, GNU grep 3.0, perl
5.42.3); logs under `.scratch/session-fa81-02/`.

- `bash -n` on every touched `.sh` (each batch); the pwsh parser on
  `test-lib.ps1` and `test-os-guards.ps1`: no errors, ASCII only.
- Counted rewrites: `rewrite-grepq.pl` (a quote-aware lexer: 12, 7, 21, 6, 1,
  34 sites per batch; total 81, equal to the inventory) and `rewrite-head.pl`
  (5, 4, 4, 15, 3); each refuses to write unless the count matches.
  `verify-diff.pl` checked every grep pair (new line minus ` >/dev/null` equals
  old minus `q`); its only mismatches were its own (it also stripped `q` from
  file greps and `git diff --quiet`), checked by eye.
- `.ps1` suites in native pwsh: `test-os-guards.ps1` 69 passed, 0 failed;
  negative case (fake root, Strawberry path pointed at a missing directory,
  every PATH dir holding perl.exe removed): exit 1, one FAIL line naming perl
  and the fix, no classification run. `test-lib.ps1` 201 passed, 0 failed,
  1 skipped, before and after the library change (its gitbash cases source
  `aitools-lib.sh` and exercise the changed perl readers).
- Cross-platform `.sh` suites in Git Bash: `test-build-deploy-backup.sh`
  24/0 (twice: after batch 1 and after the `build-deploy.sh` change),
  `test-workflow-delegation-guard.sh` 74/0/1, `test-setup-pywinpty.sh` 31/0/2,
  `run-hook-tests.sh`: all four files pass (41/0, 12/0, 50/0, 58/0).
- Hook pre-deploy verification (isolated HOME): standing-order-guard clean ->
  0, `&&` -> 2, echo redirect -> 2, 3-line command with a 300 KB line -> 0;
  scratch-init in a temp repo -> 0 and the first `session_id` of two;
  harness-db-sessionend/-start -> 0.
- Probes: `read_config_key` on a config with the key three times and 300 KB
  padding returns the first value; MERGE_WHY old vs new identical;
  `validate_ai_merge_output` main vs branch (F1).
- `build-deploy.sh` under an isolated HOME into a `git archive` copy of the
  dotprofile: exit 0 (25 pre-existing Intune-size WARNs); the library fixes are
  in the 25 generated scripts that inline `aitools-lib.sh`; `pandoc` and `rg`
  version lines carry `sed -n '1p'`.
- Step 7: the scanner extracted from the check, over the branch's scan set:
  no site. A local emulation of the step 7 suite (OS guard removed, run_check
  replaced by the extracted scanner): 59 passed, 0 failed.
- `scripts/check-pre-commit.ps1`: 7 PASS, 11 SKIP, 1 WARN (dotprofile
  uncommitted changes, pre-existing), 0 FAIL. `scripts/check-pre-push.ps1`:
  7 PASS, 3 WARN (pre-commit confirmation, roadmap, 20 commits), 0 FAIL.

## Not run

- Every POSIX-only suite and check (they refuse Git Bash): the 13 POSIX
  suites touched, `check-script-compliance.sh` and the real
  `test-step7-grepq.sh`, `check-pre-commit.sh` / `check-pre-push.sh` (refused:
  "This script is for macOS/Linux. On Windows, use check-pre-commit.ps1.").
  CI's linux and macos jobs run them.
- BSD sed and BSD grep behaviour: not read, not reproduced (case D records
  the macOS runs).

## Review after

| File | Old -> new |
|---|---|
| `.claude/rules/script-standards.md` | "Never end a pipeline in `grep -q` ..." -> every early-exit reader, its fix forms, step 7 over scripts/, shared/hooks/, tests/ |
| `.cursor/rules/script-standards.mdc` | the same paragraph |
| `reference/script-standards-detail.md` | section intro covers suites, test libraries, eval'd check strings; new readers table, sed rationale and evidence, perl END rule, not-affected list, widened Enforcement; "it is not checked yet" removed |
| `reference/post-push-checklist.md` step 23 | grep -q only -> every reader, the three directories |
| `scripts/check-script-compliance.sh` step 7 | grep -q in scripts/ + hooks -> five readers in scripts/, githooks, hooks, tests/; `file:line(reader)`; new FAIL text "... end in a reader that exits early (grep -q / -l / -m, head, perl exit) under pipefail:" |
| `scripts/aitools-lib.sh` `validate_ai_merge_output` | checks 2-3 inert -> reject fenced and refusal output; check 1 empty line not conversational |
| `scripts/build-deploy.sh` | empty payload sha / model accepted -> rejected |
| `tests/os-guards/test-os-guards.ps1` | PATH perl else Git's perl -> check-lib Strawberry block, PATH perl, else FAIL + exit 1 |
| `RELEASE_NOTES.md` | v0.77.25 added |

## Follow-ups

- Narrow check 2 of both AI-merge validators to fences that wrap the whole
  output (F12), if markdown merges with code blocks should pass.
- `check-script-compliance.ps1` step 7 skip text (F13, owner 38dc-23).
- Step 7 blind spots (F11): a reader behind an env assignment is the likeliest
  to recur.

## RFIs

- RFI fa81-02-1 (scope: head sites in scripts/ and shared/hooks/): answered,
  "32) yes it should, and it should expand the scope of the tests to include
  this test case. do it in one PR".
- RFI fa81-02-2 (F1 behaviour change): sent; proceeding with the parity fix
  in its own commit, reverted before merge if the commander says so.

## Deviations and conflicts

- CONFLICT: prompt step 6 "Run ... check-pre-commit.sh and check-pre-push.sh"
  vs the commander's platform rule ("sh scripts and tests should only run on
  linux/mac and ps1 on windows", cross-platform.md) -- resolved by tier 1: ran
  the `.ps1` twins on Windows; the `.sh` scripts refuse Git Bash (recorded).
- CONFLICT: prompt "batch delegates if the edit count calls for them (2-3
  files per batch)" vs accuracy of a mechanical edit -- resolved by tier 2
  (both in the prompt; 38dc-24 made the same call): counted rewrite scripts
  run by fa81-02 itself in batches of 2-3 files with verification between;
  no batch delegates.
- A Write aimed at the main checkout's `.aitools/channel/handoffs/` path (my
  mistake: the report belongs in the worktree) was denied by the permission
  classifier; nothing was written there. This report is in the worktree.

## Delegates used

- fa81-02-rev (independent reviewer): pending at v1.0.
