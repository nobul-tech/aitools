# S3-M3-LibKey report: aitools-lib wrappers on the id-keyed resolver (re-key batch 3)

**Intent**: **Purpose**: Record what S3-M3-LibKey shipped on PR #86 (re-key design batch 3 plus the queued lib follow-ups), the contract additions consumers build on, how it was verified, and what is left open. **Scope**: scripts/aitools-lib.sh and scripts/aitools-lib.ps1 (wrapper section and the new relay section), tests/profile/test-lib.sh. NOT setup-user-config / test-config (S3-M3-ConfigKey), NOT the installers (call-site change described only), NOT build-deploy / check-pre-push (S3-M3-B5a). **Audience**: S3-M3Lead, batch 5 (user init UI), the installer and deploy-harness owners, the reviewer, Jose.

## Summary

- PR: https://github.com/nobul-tech/aitools/pull/86 (`feature/m3-rekey`); provenance branch `feature/m3-rekey-lib`.
- Commits: e5a9d2e (merge of #80 head `feature/m3-b2-lib-wrappers`, no conflicts), 693a7e7 (lib + tests), 13eeb57 (merge of the batch 4 head, no conflicts), then the report/review commit(s) below.
- Source: re-key design (h) batch 3; S3-M3-Claude Q1 (hostname); S3-M3-B8b Q2 (dotprofile ACTION); S3-M3-Install open Q1 (relay helpers into the lib).
- Tests: test-lib 205/0 (was 108) in bash 5 and /bin/bash 3.2 with pwsh; every other suite green after the batch 4 merge.
- PR #86 now carries #80's commits: merge #80 first.

## Contract additions (every #80 name unchanged)

| Function | bash | PowerShell |
|---|---|---|
| `resolve_machine_profile` / `Resolve-MachineProfile` (new results) | `AITLIB_MACHINE_KEY`, `AITLIB_MACHINE_OWNER`, `AITLIB_MACHINE_LEGACY`, `AITLIB_MACHINE_HOSTNAME` | `$script:AitLibMachineKey`, `AitLibMachineOwner`, `AitLibMachineLegacy` (bool), `AitLibMachineHostname` |
| `jsonl_record TS SCRIPT LEVEL MSG` / `Write-JsonlRecord` | -- | -- |
| `relay_child_log TEXT` / `Send-ChildLog LINES` | `AITLIB_CHILD_WARNINGS`, `AITLIB_CHILD_ERRORS` | `$script:AitLibChildWarnings`, `AitLibChildErrors` |
| `run_child_relayed LABEL CMD [ARGS]` / `Invoke-ChildRelayed LABEL SCRIPT [ARGS] [SUMMARYTOOL]` | `AITLIB_CHILD_RC` + the two above; returns 0/1 | `$script:AitLibChildRc` + the two above; returns 0/1 |
| private | `_aitlib_exit_note`, `_aitlib_json_esc`, `_aitlib_jsonl_init`, `_aitlib_relay_line`; caches `AITLIB_RUN_ID`, `AITLIB_JSONL_HOST`, `AITLIB_JSONL_OS` | `Get-AitLibExitNote`, `Initialize-AitLibJsonl`, `ConvertTo-AitLibJsonlText`, `Send-AitLibChildLine`; caches `$script:AitLibRunId`, `AitLibJsonlHost`, `AitLibJsonlOs` |

- Defaults: key "", owner `absent`, legacy false, hostname "". They also hold for a resolver that predates the fields (an older embedded deploy copy). Hostname is the live short hostname, set on shared-only and no-match runs too (resolver `put_head`, aitools-profile.sh `cmd_resolve`).
- `AITLIB_MACHINE_ALIAS` is now the profile's `alias` field (its key for a legacy profile), per the resolver.
- Return 0 = a profile matched, not "this machine's": a hostname match on another machine's id-keyed profile returns 0 with owner `other` (test rmpk-other). Writers of per-machine data check owner = this.

## Exit-code mapping

| resolver exit | 0 | 1 | 2 | 3 refused | 4 alias in use |
|---|---|---|---|---|---|
| resolve_user_repo_path | 0 | 1 | 3 | 3 | 3 |
| resolve_machine_profile | 0 | 1 | 3 | 3 | 3 |
| tool_exception_get (PS `$null` on non-0) | 0 | 1 | 1 | 1 | 1 |
| tool_exception_record | 0 | 1 | 1 | 3 | 1 |

No wrapper returns 2. 3 and 4 are logged with code and meaning (`(resolver exit 3: refused)`, `(resolver exit 4: alias used by another profile -- not a result of this command)`). Today only `register` exits 4 and the lib does not wrap register; the mapping is defensive. Documented in both section headers (non-intent comment).

## Summary rows

- New ACTION on a dotprofile resolver error (missing or failing resolver), once per run: `see deploy.log -- the dotprofile could not be resolved` (text suggested in S3-M3-B8b-report.md Q2). ERROR rows unchanged.
- Relay helpers write no rows except `Invoke-ChildRelayed`'s optional `ERROR|<SUMMARYTOOL>|script failed (exception)` on a throw.

## Relay helpers

- Moved from PR #89's "install log helpers" (aitools-install.sh/.ps1 at 0c16ec2): same escaping, key order and footer rule. Differences, all deliberate:
  - run_id/host/os are computed in the lib (AITOOLS_RUN_ID, else one random id per process; host = short hostname; os = uname -s, PS: Darwin/Linux/Windows).
  - PS drops control characters before ConvertTo-Json (bash parity; the installer's ConvertTo-Json wrote `\u001b`), and appends with `\n` via AppendAllText (the installer's Add-Content wrote CRLF on Windows).
  - Error lines are counted; a child that logged an error but exited 0 is one error (installer: not counted).
  - `run_child_relayed` streams (process substitution, exit code via a temp file) instead of capturing, so lines show before a /dev/tty prompt; `relay_child_log` keeps the capture form.
- Same names as the installers for `relay_child_log` and `Write-JsonlRecord`: the installers, which define theirs after sourcing the lib, shadow the lib's copy until the follow-up deletes them. test-config's installer-block cases pass with both defined (190/0).
- Call-site change (follow-up for the installer owner; also in the PR body): delete `jsonl_write`/`relay_child_log`/`run_config_writer` and `Write-JsonlRecord`/`Send-ChildLogLine`/`Invoke-ConfigWriter` (keep `absolute_repos_path` / `Get-AbsoluteReposPath`) and the JSONL globals; bash `log` override calls `jsonl_record`; Step 5: `step5_rc=0; run_child_relayed "Step 5: setup-user-config.sh" "${BASH:-bash}" "$CONFIG_WRITER" "${writer_args[@]}" || step5_rc=$?` / `$null = Invoke-ChildRelayed "Step 5: setup-user-config.ps1" $configWriter $writerArgs "aitools config"`; repoint test-config's extraction to the lib.

## Verification (macOS, isolated HOME under .scratch/session-LibKey)

- `bash -n` (bash 5.3, /bin/bash 3.2), pwsh parser: clean; no top-level `AITLIB_`/`$script:AitLib` assignment (`.scratch/session-LibKey/syntax.sh`).
- Baseline after merging #80: test-lib 108/0.
- test-lib 205/0 (bash 5 + pwsh), 205/0 (/bin/bash 3.2 + pwsh), 90/0 (/bin/bash 3.2 --bash-only). New cases: rmpk-* (id-key, legacy, unregistered, other, none, nomatch, old-resolver, via-pwsh), urp-missing-twice, exit3/exit4 x urp/rmp/eget/eset (+ via-pwsh-exit4-urp), relay-record (+ bash/PS byte identity), relay-run-ok/-fail/-error-exit0, relay-captured.
- Probe `.scratch/session-LibKey/probe-jsonl.sh`: bash and PS records identical, including `é`; the JSONL checker flags an unescaped quote (negative control for the checker). Identity holds for valid UTF-8 without U+0085/U+2028/U+2029 (review m1).
- Negative control `.scratch/session-LibKey/negative.sh`: new test-lib against the pre-batch libs fails every batch 3 case.
- After merging the batch 4 head (13eeb57): test-config 190/0 (bash 5, 3.2); test-profile 689/0 (5, 3.2); tests/logging sh 24/0 (5, 3.2), ps 15/0 (5 skipped); tests/managed-files sh 42/0, ps 24/0. Before that merge test-config was 85/4 (c1, c2, c3, c8) on the untouched tree too (`baseline-config.sh`).
- check-pre-commit: FAIL 6 (known). Step 20 failed before the merge (pre-existing tree refs) and passes after it. WARN 11: the live dotprofile has uncommitted changes -- not mine, untouched.
- check-pre-push: FAIL 7 (known; every deploy script inlines the lib).

## Review

- S3-M3-LibKey-Review (independent, level 3, without this report) reviewed 693a7e7: https://github.com/nobul-tech/aitools/pull/86#pullrequestreview-5621868563 ; file `../S3-M3-LibKey-Review/S3-M3-LibKey-Review-pr86-batch3.md`.
- Verdict: approve-equivalent, 0 blockers, 0 majors, 4 minors, 4 nits; 8 mutations, all caught (table in its file).
- Fixed in the follow-up commit:
  - m1: the "byte-identical, non-ASCII" claim is narrowed in both lib comments and the PR body (identical for valid UTF-8 without U+0085/U+2028/U+2029; invalid UTF-8 gives an unparseable bash record, as the #89 installer code did); `relay-record` now carries `José ✓` and checks bash/PS byte identity.
  - m2: `Invoke-ChildRelayed` header: the child must end with an explicit `exit N`.
  - m3: `run_child_relayed` with no command logs an error and returns 1; test `relay-run-no-command` (both shells).
  - m4: `Invoke-ChildRelayed` parameters renamed `$AitLibLabel`, `$AitLibChildScript`, `$AitLibChildArgs`, `$AitLibSummaryTool`; the test child logs an error if it can see the old names.
  - n1: header sentence on stdout lifetime.
- Not changed: n2 (127 vs 1 for a missing command under bash 3.2; both failures), n3 (switch the installers in one commit -- in the call-site text), n4 (shadowing is safe; already stated).
- After the fixes: test-lib 209/0 (bash 5 + pwsh, /bin/bash 3.2 + pwsh), 92/0 (3.2 --bash-only); every other suite unchanged and green.

## Not run

- Windows / Git Bash: process substitution and the rc file in `run_child_relayed`, PS `[Environment]::MachineName` vs `hostname -s` there, the forced pwsh branch only on macOS.
- Installers and deploy-harness on the lib helpers (not switched).

## Protected-file drafts awaiting approval

- Intent for the new relay section (both libs). Written as a plain comment only; proposed `Intent:` text: `Intent: give every parent script (installers, deploy-harness) one way to run a child setup script and keep its log in deploy.jsonl: show the child's console lines, mirror each structured line to deploy.jsonl with JSON escaping, and count the child's warnings and errors. NOT a writer of deploy.log (the child writes its own) or of summary rows (the child writes its own; Invoke-ChildRelayed adds one ERROR row only for a throw). Consumed by: aitools-install.sh/.ps1 (after the follow-up), deploy-harness.sh/.ps1.`

## Open questions (with suggested answers)

1. **Switch the installers now or with deploy-harness?** Suggested: in the HARNESS mission, which needs the helpers anyway, together with test-config's extraction; one owner for aitools-install.* Step 5.
2. **Should a child that logged an error but exited 0 count as a failure?** Implemented yes (cautious). Suggested: keep; script-standards says such a child must exit 1, so this only fires on a child bug.
3. **Wrap `register` in the lib for batch 5?** Not asked; batch 5 calls the resolver directly. Suggested: no, unless batch 5 wants the exit 3/4 mapping there too.

## INCIDENT markers (not filed)

- `INCIDENT:` reference/script-standards-detail.md "Usage" still shows the installers' unescaped JSONL override pattern (`"msg":"%s"` with a raw message), which writes invalid JSON for a quote; the lib now has `jsonl_record`. Protected; draft needed (also noted in PR #89's follow-ups).
- `INCIDENT:` no harness rule says what a lib function name shared with a caller's own definition means (the installers shadow `relay_child_log` / `Write-JsonlRecord`); related to the lib-naming incident from Review3.

## WRITE_BLOCKED

None. (Two Bash calls were refused by standing-order-guard -- `;` in a `sed` command and `tail` -- and redone with Read / grep, the prescribed tools.)

## Delegates

- S3-M3-LibKey-Review (general-purpose, no isolation, launched without this report).
