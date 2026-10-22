# S3-Profile-Review: PR #73 (native profile resolver), independent review

Verdict: no blockers. Mergeable after the 3 major fixes below (each is a few lines), or with them filed as follow-ups if you prefer to keep B1 moving.
Counts: 0 blocker, 3 major, 14 minor, plus 3 open questions.
Tests (local, macOS, bash 5.3 + pwsh 7.6.3): `bash tests/profile/test-profile.sh`: 180 passed, 0 failed. `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-profile.sh --bash-only`: 135 passed, 0 failed.
CI on head d977807: linux, macos and windows all pass (macOS 180/0 and 135/0, Linux 185/0 with rm-web; the Windows step read MachineGuid `09044d2c-...` and hostname `runnervmgnbhw`, and resolve exited 1).
Reviewed: c1308f6 (scripts/aitools-profile.sh, scripts/aitools-profile.ps1, tests/profile/test-profile.sh, .github/workflows/check.yml) plus the CI follow-up d977807. I did not change any code.

## Scope and method

- I read both scripts in full, along with the test, the CI diff, the approved draft spec (S4-Review-drafts/reference/user-repo.md, "Profile Schema" and "Resolution"), the JS baseline (S5-Profile-drafts/scripts/aitools-profile.js), the plan's P-Q2, P-Q3, P-Q5 and D-TS13 rows, and the aitools-lib.sh/.ps1 environment and logging code.
- I ran the probes against both implementations in mktemp HOMEs, with injected ids and hostnames. The scripts are in `.scratch/session-S3PRev/` (probe-lib.sh, probe1-cli.sh, probe2-register.sh, probe3-inproc.ps1, probe4-snapshot.sh, probe5-bash32.sh). The live dotprofile was only read: I grepped it for floats and U+2028 and found none.
- Spec conformance is good. The dotprofile order is env > argument > config > convention > scan > none. The machine order is override > environment > id > config alias > hostname > none. Every miss behaves as the spec's table says. `none` returns identity-level values only. Ids are raw and compared case-insensitively (P-Q2). macOS uses only `scutil --get LocalHostName` (P-Q5). Exit 2 is "error", and the header tells callers not to pass it through (D-TS13).

## Major

**M1. Data lines on stdout can be preceded by a log line, from both implementations.** The `log()` / `Log` override that sends console lines to stderr is defined after `logging_init` / `Initialize-Logging` runs (sh:36 then sh:39-45; ps1:35 then ps1:38-44). `logging_init` calls `_log_aitools_environment`, which calls `log_warn` (aitools-lib.sh:156-160). The same happens in PS through `Write-AitoolsEnvironmentLog` → `LogWarn` → `Write-Host` (aitools-lib.ps1:132-137, 142-151). That warning therefore goes to stdout, and in bash it carries ANSI codes. This breaks the header contract "data on stdout only", including for `--plain` and `--json`.
Probe (probe1): `AITOOLS_ENVIRONMENT=bogus aitools-profile.sh user-repo-path --user-repo-path <dir> --plain` prints
```
<ESC>[33m[...] [aitools-profile] [warn] AITOOLS_ENVIRONMENT='bogus' ignored (...) -- environment is local<ESC>[0m
/var/folders/.../home/repos
```
PS prints the same line without ANSI codes. With `AITOOLS_ENVIRONMENT=claude-code-web` on macOS, `resolve --json` also starts with this line, so the output is no longer one JSON object.
It only fires on an invalid or impossible exported override, which is rare in harness runs because the lib re-exports the resolved value. The impact is a broken path or JSON in the caller.
Fix: define the override before `logging_init` / `Initialize-Logging` in both scripts.

**M2. PowerShell `register` exits 1 (= "not found") on an uncaught throw.** Bash returns 2 with an `error` line in the same case. `Set-JValue` throws `set: '<seg>' is not an object` (ps1:179), and none of its callers in `Invoke-Register` (ps1:682, 687, 689-698) is inside try/catch. pwsh -File then exits 1 and prints a raw exception on stderr.
Probe (probe2): with a profile of `{"version":2,"profiles":{"a":{"machine":null}}}` (or `"machine":"x"`), register `--alias a` gives `bash rc=2 stdout: error<TAB>register failed: set: 'machine' is not an object` and `pwsh rc=1 stdout: (empty)`.
Exit 1 means "nothing found (expected state)" in this contract. A future `user init` that maps 1 to "profile.json missing, offer --create" would take the wrong branch.
Fix: wrap the mutation block in try/catch → `Add-Err "register failed: $($_.Exception.Message)"; Complete-Command 2`. Also consider a script-level `trap { ...; exit 2 }` so no unexpected exception can surface as 1.

**M3. The perl engine changes float values on `register` (silent precision loss).** `numnorm` (sh:128-133) re-stringifies every non-integer through perl's default `%.15g`. Values with 16-17 significant digits are rewritten to different numbers.
Probe (probe2, register of a file whose only intended change is machine.id): `0.30000000000000004` → `0.3` and `0.3333333333333333` → `0.333333333333333`. Node keeps both, and so does PS.
Today's live profile.json has no floats (grep), so this is latent. But `register` rewrites the whole user source-of-truth file, including `claude.settings`, which the code does not own.
Fix (simplest): keep the original number lexeme verbatim in the `N` node instead of normalizing. This also keeps `1e5` and `2.50` byte-for-byte, which fits "every other byte unchanged". Alternative: shortest round-trip formatting (`%.17g` with a shortening loop).

## Minor

1. **The claim of byte-identity with node holds only for integers and plain strings.** Register output for the same input (probe2):
   - node: `1, 100000, 1e-7, 123456789012345680000, 0, U+2028 raw`
   - bash: `1, 100000, 1e-07, 123456789012345678901, 0, U+2028 raw`
   - pwsh: `1.0, 100000.0, 1E-07, 123456789012345678901, -0.0, " "`
   Bash and pwsh outputs differ for this input; the test fixture only has `2.5` and an emoji. Suggest narrowing the header claim (sh:24-25, ps1:23-25) to "integers, strings, booleans, null", or adding a float fixture and normalizing.
2. **A lone surrogate is written differently by each engine.** For input `"\ud800x"`, bash writes the bytes `ED A0 80` (invalid UTF-8; `u8()` at sh:108), pwsh writes `EF BF BD` (U+FFFD), and node writes `"\ud800x"` (probe2). This is an edge case. Suggest that bash emit `\ud800` when the code point is in D800-DFFF.
3. **`--help` / `-h` in the command position differs between implementations.** Bash exits 2 with `unknown command: --help` (sh:1035-1045). PS exits 0 with the usage text (ps1:260). The JS baseline exited 0. Probe1: `help-as-cmd: bash rc=2 pwsh rc=0`.
4. **PS option names are case-insensitive; bash's are exact.** `$opt` is a default (case-insensitive) hashtable (ps1:236, 250). `resolve --PROFILE f` gives PS rc=0 and bash rc=2 `unknown option: --PROFILE` (probe1).
5. **The two JSON readers accept different inputs** (PS ConvertFrom-Json vs the perl engine; probe1):
   - Keys that differ only in case (`{"K":1,"k":2}`): bash ok, PS rc=2 "keys with different casing". This is valid JSON, so on Windows a profile.json with such keys (for example inside `claude.settings`) would make every resolve fail.
   - An empty key `""`: bash ok, PS rc=2.
   - A top-level single-element array `[{...}]`: bash rejects it ("top level is not an object"), PS accepts it, because assigning pipeline output unrolls the one-element array (ps1:104-108).
   - Raw control characters inside strings: bash rejects (correct per RFC 8259), PS accepts.
   - Lookups: `Get-JNode` uses `PSObject.Properties[$s]`, which is case-insensitive (ps1:120). `{"Profiles":{...}}` resolves in PS and errors in bash.
   - Suggest `ConvertFrom-Json -AsHashtable` (an ordered or case-sensitive dictionary) with exact-key lookup, or document the PS-side limits.
6. **Hostname normalization differs.** Bash `short_host` deletes all whitespace and lower-cases ASCII only (`tr`, sh:529). PS trims the ends and uses `ToLowerInvariant` (ps1:292).
   - Profile hostname `"My Mac.local"` with this host `mymac`: bash matches, PS errors with no match (probe1 host-space).
   - Profile `"ÉCOLE"` with host `école`: PS matches, bash does not (probe1 host-unicode).
   - Real LocalHostName and COMPUTERNAME values are ASCII without spaces, so the risk is low. Suggest the same rule on both sides (trim, then lower-case ASCII).
7. **`register` reports `unchanged` when it added a name or company.** The state compares only `machine` (sh:1027, ps1:709; same in the JS baseline). Probe2 reg-noname: `result unchanged`, but the written file has the added `"name": "NewName"`. A caller that skips the move on `unchanged` drops the change. Suggest comparing the whole profile entry.
8. **A tab or newline in `--name` / `--company` / `--shell` is written differently.** Bash's `edit_set` passes values through `one_line` (sh:935), so a tab becomes a space. PS writes `\t` (probe2 reg-tabname: files differ).
9. **PS `snapshot` unrolls arrays.** `$snap[$k] = if (...) { $n.Value } ...` (ps1:621) enumerates arrays, so `"cursor":["only"]` becomes `"cursor":"only"` and `"cursor":[]` becomes `null` (probe4). Separately, both engines write `"version":{}` when version is missing; JS omitted the key. Suggest `$snap[$k] = $n.Value` inside an explicit if/else, without capturing the if-statement's output.
10. **In-process PS with relative paths reads the wrong file.** `Read-JsonFile` checks with `Test-Path` (PS location) but reads with `[IO.File]::ReadAllText` (process cwd) (ps1:94, 98). `register` writes with `WriteAllText` (ps1:700). Probe3: after `Set-Location b` with the process cwd at `a`, `& aitools-profile.ps1 resolve --profile p.json --alias in-b` read `a/p.json` (`override alias "in-b" not in profiles (in-a)`). The header documents in-process use (ps1:16). This is the documented ".NET working directory" gotcha in cross-platform.md. Fix: resolve paths with `GetUnresolvedProviderPathFromPSPath` first.
11. **Error-handling patterns (script-standards.md "Error handling requirements").**
    - `before=$(pj json ...) || before=""` (sh:987) and `after=$(...) || after=""` (sh:1026) treat every engine failure as "absent". They should only do that for exit 1, as `jread` does. If the post-write read fails, the result can be reported as `unchanged`.
    - `raw=$(uname -n)` (sh:538) has no rc check; under `set -e` a failure exits with uname's code, not 2.
12. **When perl is missing, the error goes to stdout as a tagged line, even with `--plain` / `--json`** (sh:353-357; probe5: `error<TAB>perl not found ...` rc=2). Callers that check rc are fine. Suggest stderr only.
13. **PS 5.1 is not guarded.** The guard only checks `-ge 6` (ps1:46). Under Windows PowerShell 5.1, `ConvertFrom-Json -Depth` and 3-argument `Join-Path` (in the lib) are unavailable. The baseline is PS 7 (cross-platform.md "PowerShell 7 baseline"). Actual 5.1 behaviour: unknown (not run). Suggest an explicit `PSVersion.Major -lt 7` → exit 2 with a message.
14. **The CI Windows step is a smoke test only.** The parity suite never runs under native Windows pwsh: CRLF stdout, backslash paths, `--path-form mixed`, `register` on win32/x64. Also, `derive-config` ignores `--path-form` for `derived.userRepoPath` (ps1:576). Suggest a short Windows case for `register` plus `user-repo-path --path-form mixed`.

Windows reasoning (not run, no Windows machine):
- `Get-ItemProperty HKLM:\...\Cryptography MachineGuid` worked on the CI runner. On the commander's workstation it is still UNVERIFIED, as the header says.
- COMPUTERNAME is the NetBIOS name, capped at 15 characters, so the legacy hostname step will not match hostnames registered earlier from node's full `os.hostname()` when they are longer.
- `pwsh -File` stdout is CRLF and in the console codepage. B2's bash-side consumers on Windows must strip `\r` and expect non-ASCII paths to be mangled; in-process PS callers are unaffected.

## Open questions (with suggested answers)

- **Q1. env vs `--user-repo-path` order.** The PR follows the spec (env first, sh:577-588). The JS baseline deliberately had the argument win ("a caller's choice wins", js:209-217). If the entry point exports `AITOOLS_USER_REPO_PATH` while `user init` passes the user's new choice, the env wins.
  Suggested: keep the spec order and make sure `user init` unsets or does not inherit the env var. Confirm with the commander.
- **Q2. build-deploy.sh as a consumer.** The intent header names build-deploy.sh as a consumer (sh:13). On Windows, build-deploy runs under Git Bash (CI step "Build deploy scripts (via Git Bash)"), where the .sh OS guard exits 2 (sh:47-51).
  Suggested: build-deploy uses only the `AITOOLS_USER_REPO_PATH` handed over by the entry point (as the spec draft says) and never calls the resolver itself on Windows. Reword the header for B-later.
- **Q3. Corrupt config.json in `resolve`.** The PR warns and continues; the JS baseline exited 2.
  Suggested: keep the PR behaviour. It matches user-repo-path and derive-config, and lets setup-user-config repair the file.

## Checked and found fine

- bash 3.2: printf -v, here-strings, `[[ =~ ]]`, `${v//[$'\t\r\n']/ }` and empty profiles all work under /bin/bash 3.2.57 (probe5 plus the 3.2 suite).
- No empty `"${a[@]}"` expansions under `set -u`.
- Duplicate keys: last value wins at the first key's position in both engines (matches node).
- BOM and CRLF input are accepted in both.
- `--json` escaping of quotes, `<>&'` and non-ASCII is identical in both (probe4).
- Paths with spaces work (probe1).
- Non-object profile entries are ignored with a warning, identically (probe4).
- The `register` duplicate-id refusal works.
- `--create` output is byte-identical across engines.
- The CI pwsh `exit 0` fix (d977807) is correct for the runner's appended `exit $LASTEXITCODE`.

INCIDENT: (outside the PR) `aitools-lib.sh` `logging_init` and `aitools-lib.ps1` `Initialize-Logging` emit a console `warn` line during init, before a script can redirect console logging. Every script whose stdout carries data inherits M1. A lib-level option (for example a `LOG_CONSOLE_FD` / stderr switch honoured by `log`) would remove the ordering trap.
