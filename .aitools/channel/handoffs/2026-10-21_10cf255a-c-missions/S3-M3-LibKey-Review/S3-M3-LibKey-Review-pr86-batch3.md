# S3-M3-LibKey-Review: PR #86, re-key batch 3 (693a7e7)

**Verdict: approve-equivalent. 0 blockers, 0 majors, 4 minors, 4 nits.** Nothing here has to be fixed before merge. m1 is a wrong claim in the PR body and should be corrected or backed by a test. m2 to m4 are small hardening changes for the deploy-harness callers that are coming.

Reviewer: S3-M3-LibKey-Review (independent, level 3; no author report read). Scope: `git show 693a7e7`, which touches `scripts/aitools-lib.sh` and `scripts/aitools-lib.ps1` (the resolution section and the new relay section) and `tests/profile/test-lib.sh`, plus the PR body section "Batch 3 / lib contract additions". The libs and the test are unchanged between 693a7e7 and the branch tip 7b28cc5 (`git diff --stat 693a7e7 HEAD` on the three files is empty).

## Spec check (the five items)

| # | Item | Result |
|---|---|---|
| 1 | `AITLIB_MACHINE_KEY/OWNER/LEGACY/HOSTNAME` (PS `$script:AitLibMachine*`) | Met. Defaults are set before the resolver runs, so they hold for an older resolver. Seven test cases cover them (id-key, legacy, unregistered, other, none, no-match, old resolver). |
| 2 | Exits 3 and 4 mapped explicitly in every wrapper, nothing folded into "not found", return codes documented | Met. The table is in both section headers. `_aitlib_exit_note` / `Get-AitLibExitNote` tag every 3 and 4 log line. No wrapper returns 2. Exit 1 is the only code read as "nothing found". Tested in all four wrappers and through the forced Git Bash -> pwsh branch. |
| 3 | One dotprofile ACTION per run | Met, on both the resolver-missing path and the resolver-failed path, deduplicated through the run summary (`urp-missing-twice`). |
| 4 | Relay helpers, escaping, counts, installers not edited | Met for valid UTF-8 text, with the exceptions in m1. The stat shows that only the 3 files changed. |
| 5 | Every #80 contract name keeps working | Met. I compared the result names, return codes and ACTION texts against the #80 body: all are present and unchanged. No top-level `AITLIB_` / `$script:AitLib` assignment (`grep -n -E "^(AITLIB_|\$script:AitLib)"` on both libs: no hits). |

No intent statement was added or changed. The relay section is a plain comment.

## Verification I ran (macOS, isolated HOME = `.scratch/session-LKRev/home`)

- `bash tests/profile/test-lib.sh`: **205 passed, 0 failed** (GNU bash 5.3.15 + pwsh).
- `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-lib.sh`: **205 passed, 0 failed** (bash 3.2.57 + pwsh).
- `bash -n` and `/bin/bash -n` on aitools-lib.sh: clean. pwsh `Parser::ParseFile` on aitools-lib.ps1: clean.
- **Mutation tests** (`mutate.sh`: copy scripts/ and tests/ to scratch, apply one perl substitution, run test-lib). Every mutation was caught:

| Mutation | Result |
|---|---|
| bash: drop `m="${m//[[:cntrl:]]/}"` | 1 failed (relay-record: invalid JSON) |
| bash: count the exit footers | 4 failed (relay-run-ok/-fail/-error-exit0, relay-captured) |
| bash: drop the dotprofile ACTION on the resolver-failed path | 4 failed (broken-silent0/1-urp, exit3-urp, exit4-urp) |
| bash: ignore error lines when the child exits 0 | 1 failed (relay-run-error-exit0) |
| bash: owner default "" instead of `absent` | 1 failed (rmpk-old-resolver) |
| bash: `AITLIB_MACHINE_HOSTNAME` not set | 7 failed (every rmpk case) |
| ps: exit-4 note dropped | 4 failed (exit4-urp/-rmp/-eget/-eset, ps) |
| ps: tab dropped instead of escaped | 6 failed (relay-record ps and bash/ps identity, all relay-run ps) |

## Findings

### m1 (minor): the "byte-identical records, non-ASCII included" claim in the PR body is untested and only partly true; bash can write invalid JSON

PR body, "Relay helpers": "bash and PowerShell write byte-identical records (tested, non-ASCII included)". The only non-ASCII text in test-lib.sh is the resolver identity name `José` (lines 447 and 450, `grep -n -P "[^\x00-\x7F]"`). The relay record case (`RMODE=record`) is ASCII only. Probe `probe-jsonl.sh` writes one record per message with bash 5 / bash 3.2 (UTF-8 and C locale) and pwsh, then decodes it with JSON::PP:

```
utf8     bash5 / bash32 / C   valid Jos<c3><a9> caf<c3><a9> <e2><9c><93>     ps: identical
c1       bash5, bash32-utf8   valid c1  nel            (U+0085 dropped)
c1       bash32-C, bash5-C    valid c1 <c2><85> nel    (kept raw: depends on the locale)
c1       ps                   valid c1 \u0085 nel
u2028    bash (all)           valid ls <e2><80><a8> sep
u2028    ps                   valid ls   sep
invalid  bash (all)           INVALID bad <ff><fe> bytes
invalid  ps                   valid bad <ef><bf><bd><ef><bf><bd> bytes
```

- Ordinary UTF-8 is byte-identical (good).
- U+0085, U+2028 and U+2029: Newtonsoft escapes them, bash does not, and bash's `[[:cntrl:]]` result for U+0085 depends on the locale.
- Bytes that are not valid UTF-8 (for example a cp1252 path a child prints on Windows) give a record that does not parse. That contradicts the comment at aitools-lib.sh:488-490 ("so a record is always one valid JSON line"). The #89 installer code behaved the same way, so this is not a regression.

Suggested fix: reword the PR body and the comment to "byte-identical for valid UTF-8 text without U+0085/U+2028/U+2029", and add one non-ASCII message (`José ✓`) to the `relay-record` case so the identity claim is actually tested. Optional: in `_aitlib_json_esc`, replace invalid UTF-8 with U+FFFD through perl, as .NET does. It costs one process per record, so it may not be worth it.

### m2 (minor): `Invoke-ChildRelayed` reports a false failure when a child ends without `exit` after a native command failed

aitools-lib.ps1:505-508 reads `$LASTEXITCODE` after `& $ChildScript`. A .ps1 that ends without `exit` leaves the code of the last native command it ran. Probe `probe-ps.sh`, child `c-native-noexit.ps1` (it runs `& /usr/bin/false`, handles that, then logs `COMPLETED successfully` and ends without `exit`):

```
[child] [ok] COMPLETED successfully
[probe-ps] [error] lbl failed (exit 1) -- see .../deploy.log
RESULT ... rc=1 child_rc=1 ... E=1 LEC=1
```

A bash child in the same situation exits 0, because its status is the last command's. Children that use the standard exit footer (script-standards-detail.md "Exit footer": every branch ends in `exit 0/1`) are not affected. The old `Invoke-ConfigWriter` read `$LASTEXITCODE` the same way. Now that the helper is meant for every deploy-harness child, though, it becomes a parity trap. Suggested fix: state in the `Invoke-ChildRelayed` header that "the child must end with an explicit `exit N` (the exit footer); without one, the last native command's exit code is reported". Alternative: also accept `$?` from the call. That is not reliable for scripts either, so the documentation is the cheaper fix.

### m3 (minor): `run_child_relayed` with no command returns 0 and runs nothing

Probe `probe-run.sh`, case `noargs`: `run_child_relayed "noargs"` gives `rc=0 child_rc=0`, with no log line, in bash 5 and 3.2. This is easy to reach with an empty array (`run_child_relayed "Step N" "${cmd[@]}"`), and it is a silent success (USO: no silent failures in reusable code). PowerShell differs: `Invoke-ChildRelayed` with an empty SCRIPT throws, the throw is caught, and it returns 1. Suggested fix, at the top of `run_child_relayed` after the `shift`: `if [ "$#" -eq 0 ]; then AITLIB_CHILD_RC=1; log_error "$label: not run (no command given)"; return 1; fi`. Add a test case for it.

### m4 (minor): PowerShell children see `Invoke-ChildRelayed`'s parameters through dynamic scope

Probe child `c-locals.ps1` prints variables it never defines:

```
child sees Label=[lbl] ChildScript=[.../c-locals.ps1] SummaryTool=[tool]
```

A child that reads an unset `$Label`, `$ChildArgs` or `$SummaryTool` (or tests `if (-not $Label)`) gets the parent's value instead of `$null`. Under `Set-StrictMode` it also loses the "variable not set" error. This is the same class of leak as Review3 #80 B1, in the other direction. Bash has no such leak because the child is a separate process. Suggested fix: give the parameters the lib prefix (`$AitLibLabel`, `$AitLibChildScript`, `$AitLibChildArgs`, `$AitLibSummaryTool`). Positional callers are unaffected, and named callers do not exist yet.

### n1 (nit): the stdout lifetime of `run_child_relayed`

The process substitution and the exit-code file work in bash 3.2. The code is written to the file before the pipe closes, because the subshell holds the pipe until after `printf > "$rcf"`. Probe results:

- `closeout`: the child closes stdout and exits 7. Reported as `exit 7`, correct.
- `bgholder`: a background grandchild keeps stdout open. The call blocks until the grandchild exits (2.1 s) and relays its late line. The old `$(...)` capture behaved the same way.

Suggested fix: one sentence in the header ("returns when every process holding the child's stdout has closed it").

### n2 (nit): a command that is not found gives exit 1 under bash 3.2

Probe `notfound` (`run_child_relayed nf /no/such/cmd`): bash 5 reports `exit 127`, `/bin/bash` 3.2 reports `exit 1`. Both are failures and both give one `log_error`, so this is cosmetic.

### n3 (nit): run_id can split during the installer switch

`jsonl_record` caches its own `AITLIB_RUN_ID` (aitools-lib.sh:503-520). The installers keep their own `RUN_ID`. Both come from `AITOOLS_RUN_ID` when it is set (the `aitools` entry points export it), and each draws its own random id when it is not. A partly switched installer started directly (`bash scripts/aitools-install.sh`) would write two run_ids in one run. Suggested fix: do the call-site switch in the PR body in one commit, as written.

### n4 (nit): installer shadowing is safe today, but note why

- bash: the installer redefines `relay_child_log` after sourcing the lib. The lib's `run_child_relayed` calls `_aitlib_relay_line`, never `relay_child_log`, so the installer's copy changes nothing inside the lib.
- PowerShell: the installer redefines `Write-JsonlRecord`, and the lib's `Send-AitLibChildLine` resolves the installer's copy at call time. I checked this with probe `SHADOW=1`, which printed `SHADOW-JSONL warn w1`. The signatures match positionally, so the relay keeps working. Records then come from the installer's code (`Add-Content`, `$env:COMPUTERNAME`), so they are not byte-identical until the switch.

Neither case is a bug. The PR body sentence "the installers' copies shadow the lib's until they are deleted" is accurate.

## Probes that found nothing wrong

- `stdin`: `printf 'hello\n' | run_child_relayed ... bash -c 'read -r l'` reads `hello`. Process substitution keeps the caller's stdin (bash 5 and 3.2).
- `setefail`: a child with `set -e` that hits `false` gives exit 1 and one `log_error`. `bare` (called without `|| rc=$?` under `set -e`): the caller exits, as documented.
- `nolf`: a last line without a newline is relayed and counted. `colour`: `ESC[33m ... ESC[0m\r` is cleaned and counted. `footer`: `COMPLETED with` / `FAILED with` are relayed and not counted.
- PowerShell: a `throw` and a parse error in the child are caught (`rc=1`, one LogError, the `ERROR|tool|script failed (exception)` row). A bare `exit` gives rc 0. Lines written with `Write-Output` are relayed and counted, the same as `Write-Host` lines. `Write-Error` goes to the error stream and is not counted. A nested `Invoke-ChildRelayed` (child -> grandchild) counts each warning once at each level. `$script:warnings` / `$script:AitLibChildWarnings` resolve to the parent while the child runs: the child's own counters are not touched, and its footer shows its own count.
- `owner` on return 0: documented in the header and the PR body (`rmpk-other`: a hostname match on another machine's id-keyed profile returns 0 with owner `other`). No caller reads `AITLIB_MACHINE_OWNER` yet (`grep` over scripts/ and shared/ finds only the lib and resolver headers). Batches 5 and 6 must check `owner = this` before writing per-machine data.

## Test adequacy

Good. The new cases check return code, globals, counters, summary rows and, through `notes=`, the exit-code tagging in the log. They run through both libs and the forced pwsh branch. Every mutation above failed at least one case. Gaps: a non-ASCII relay record (m1), `run_child_relayed` with no command (m3), and a PowerShell child that ends without `exit` (m2, if it is documented rather than fixed).

INCIDENT: none. No harness deficiency was found beyond the findings above.

Probes and logs: `.scratch/session-LKRev/` in the m3rklib worktree (`probe-jsonl.sh`, `probe-run.sh`, `probe-ps.sh`, `mutate.sh`, `mutate-all.sh`, `test-lib-bash5.log`, `test-lib-bash32.log`).
