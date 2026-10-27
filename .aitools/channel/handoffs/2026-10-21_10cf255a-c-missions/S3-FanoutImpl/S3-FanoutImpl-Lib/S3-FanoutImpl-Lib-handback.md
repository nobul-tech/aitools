# S3-FanoutImpl-Lib hand-back (FO-1)

Version 1.0, 2026-10-26, by S3-FanoutImpl-Lib (level 2, under S3-FanoutImpl).

## Summary

1. FAN-PLAN A1-A4 applied verbatim (each old_string matched once on feature/fanout-base, incl. #113/#115 lib changes).
2. Plan section 3.3 helpers added to both libs after the tracker summary, with parity comments.
3. New suite tests/fanout-lib/test-fanout-lib.sh: 284/0 (bash 5 + pwsh, every case also sh = ps), 95/0/1 under /bin/bash 3.2 --bash-only.
4. CI steps added to check.yml (macOS bash 5 + pwsh, macOS /bin/bash 3.2, Linux).
5. PR https://github.com/nobul-tech/aitools/pull/118, branch feature/fanout-lib, head 14f9fb1 (commits 47157f6 lib+suite+CI, 14f9fb1 CI step order; base d7f6855).

CI run 40437712731: fan-out suite steps pass (Linux bash+pwsh; macOS bash 5+pwsh, /bin/bash 3.2); windows pass; linux/macos red only at the pre-existing claude-mdm step (size gate below).

## Shipped signatures

| bash | PowerShell | Result |
|---|---|---|
| `deploy_tracker_record removed TOOL ITEM` | `Record-DeployOutcome -Outcome "removed"` | counter `_DT_REMOVED` / `$script:dtRemoved`; DETAIL `removed: ITEM`; summary part `N removed` after `accepted` |
| unknown outcome | `default` | log_error/LogError `<fn>: unknown outcome "X" for ITEM (TOOL) -- counted as failed`; failed + DETAIL `failed: ITEM` |
| `RULES_MANIFEST_HEADER`, `SKILLS_MANIFEST_HEADER` | `$rulesManifestHeader`, `$skillsManifestHeader` | headers v1 |
| `lower_name NAME`, `in_list LINE LIST` | n/a | FAN-PLAN A2 |
| `rule_name_kind NAME` (prints) | `Get-RuleNameKind NAME` | hidden/backup/rule/other |
| `skill_name_kind NAME` (prints) | `Get-SkillNameKind NAME` | hidden/backup/skill |
| `read_harness_manifest FILE KIND` | `Read-HarnessManifest -Path P -Kind K` | KIND rules/skills (case-sensitive). sh lines `rule<TAB>name<TAB>src` (first word `rule` for BOTH kinds), `invalid<TAB>...`, or `header-bad`; exit 2 unknown kind, non-zero + stderr unreadable/directory (caller: `out=$(... 2>&1)` and check exit). ps `@{Status; Rules; Invalid}` (key `Rules` for both kinds); throws on unknown kind / unreadable |
| `read_rules_manifest FILE` | `Read-RulesManifest PATH` | wrappers (kind rules) |
| `fanout_text_equal A B` | `Test-FanoutTextEqual A B` | 0 equal ignoring trailing CR/LF, 1 differ, 2 unreadable (detail log) |
| `fanout_dir_matches TARGET CAND` | `Test-FanoutDirMatches TARGET CAND` | 0 / 1 / 2 (below) |

fanout_dir_matches: 1 also for any symlink / non-regular entry under TARGET (never followed); `*.bak.*` base names ignored case-insensitively; files only in CAND do not matter; empty subdirs ignored; 2 wins over 1 (whole tree checked).

## Contract change

- read_harness_manifest/read_rules_manifest exit non-zero for a directory path (PS already threw); setup-user-cursor's copy printed header-bad. All file inputs byte-identical to the cursor copy (suite `rr-*` cases, sh and ps).

## Verification

See PR body: fanout-lib 284/0 and 95/0/1 (3.2); managed-files 57/0, 39/0; adopt-push 28/0, 23/0; profile test-lib 361/0, 160/0 (3.2); rules-fanout-cursor 164/0/1; deploy-harness 76/0; logging 24/0, 15/0/5; step 31 extraction equal incl. `removed`; bash -n + _validate-ps1 OK; pre-commit only step 6 FAIL (known), pre-push only step 7 FAIL (known). CI: see Summary item 5.

## Not run / findings

- INCIDENT: tests/claude-mdm fails 13 on the base already: build-deploy's Intune size gate refuses deploy/deploy-harness.ps1 (202,519 B on d7f6855; 211,576 B with FO-1 since the lib is inlined; limit 200,000). RECONCILE ledger #211. Any fix must budget FO-1's ~9 KB (and FO-4's function).
- Observation: Record-DeployOutcome `switch` is case-insensitive, deploy_tracker_record `case` is not (A3 verbatim, not changed).
- Non-ASCII case-only duplicates differ (perl lc on bytes vs .NET OrdinalIgnoreCase); untested.
- PS Test-FanoutDirMatches would try to read a FIFO under TARGET (bash flags it as non-regular); not tested.
- Windows native not run.

## WRITE_BLOCKED

None.
