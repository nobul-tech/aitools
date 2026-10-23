# S3-MF-Runner plan: the lib runner accepts "result" lines; user init uses it and passes --no-machine

**Intent**: **Purpose**: The verbatim change plan for mission S3-MF-Runner (M3-FINISH items 2 and 3), with the case-by-case comparison of the removed private runners against the lib runner and an error-handling audit of every block. **Scope**: `_aitlib_profile_run` / `Invoke-AitLibProfile` (aitools-lib.sh/.ps1, profile-runner section), `ui_profile_run` / `Invoke-UiProfile` and the writer call in scripts/aitools / aitools.ps1, tests/profile/test-lib.sh and test-user-init.sh. NOT the resolver, setup-user-config, or audit findings A-12..A-18. **Audience**: S3-MF-Runner, its reviewer, S3-M3Finish, Jose.

Branch `fix/mf-lib-runner-result` = origin/main (8a9dcb5) + `--no-ff` merges of origin/fix/mf-dotprofile-adopt-push (#103) and origin/feature/mf-config-no-machine (#98).

## 1. Why the private runners exist, and what they do that the lib runner does not

Source: scripts/aitools `ui_profile_run` (comment: "Not the lib runner (_aitlib_profile_run): that one reads an exit 0/1 without a "via" line as a resolver crash, and register and migrate print no "via" line."), aitools.ps1 `Invoke-UiProfile` (same comment).

Resolver output per command used by user init (scripts/aitools-profile.sh): `register` -> `put_reg` prints `result`, `key`, `alias`, `owner`, `ownerKey`, `claimed`, `machineId`, `hostname` (no `via`); `migrate` -> `put_mig` prints `result`, `profileFile`, `renamed`, `unclaimed`, `committed`, `pushed` (no `via`); `resolve` -> prints `via`; `hostname` -> a bare value, no tag (`cmd_hostname`).

| # | case | private bash (ui_profile_run) | private PS (Invoke-UiProfile) | lib today | lib after this plan |
|---|---|---|---|---|---|
| 1 | exit 0/1 with `result`, no `via` (register, migrate) | kept | kept | rewritten to 2 + error line | kept |
| 2 | `hostname` exit 0, bare value | kept | kept | rewritten to 2 | kept (bare-value commands: non-empty value) |
| 3 | exit 0/1 without any result line (crash, policy refusal) | read as 0/1 (the bug the lib guards) | same | 2 + error line | 2 + error line (unchanged) |
| 4 | exit 2, 3, 4 with error lines | passed through | passed through | passed through | passed through |
| 5 | resolver missing | return 1, RC 2, `error` line naming it | return $false, RC 2, `error` line | return 1, RC 0, no line | return 1, RC 2, `error` line naming it (same text format) |
| 6 | PS throw | n/a | RC 2 + `error` line "aitools-profile CMD threw: MSG" | RC 2, detail only | RC 2 + `error` line (same text; newlines collapsed); bash pwsh branch prints the same line |
| 7 | Windows path args | cygpath -w after --profile/--out/--config | n/a | after --path only | after --path/--profile/--out/--config (absolute paths) |
| 8 | stderr -> deploy.log | detail "aitools-profile CMD: LINE" | same | same | same |
| 9 | temp file removal | ui_rm_tmp (log_warn on failure) | no temp file | `rm -f` unchecked (audit A-4) | checked; a failure is a detail line (A-4's suggested fix; a warn would promote every lib caller's OK row, D-TS12) |
| 10 | resolver location | $repo_path/scripts | $repoPath/scripts | lib dir (= $repo_path/scripts for both entry points) or AITOOLS_PROFILE_SH/PS1 | same as lib today |
| 11 | pwsh invocation (Git Bash) | `-File` with argv | in-process | `-Command` with args in env (UTF-8 output) | same as lib today |

Existing lib callers (resolve_user_repo_path, resolve_machine_profile, tool_exception_get/record and PS twins, the dotprofile adopt helper from #103) never pass --profile/--out/--config, never call register/migrate/hostname, and ignore RC/OUT when the runner returns 1. Effects on them: case 5 (they log their own message; unchanged), case 6 (a throw now has an error line, so the wrapper logs that line instead of "resolver failed (exit 2)": same counts and rows; test-lib broken-throw/parse cases assert counts and rows only).

## 2. Batch 1: lib runner + test-lib

### 2a. scripts/aitools-lib.sh

Edit 1 (section header):
old:
```
# Every 3 and 4 is logged with its code and meaning. An exit 0/1 without the
# resolver's "via" line is rewritten to 2 first (_aitlib_profile_run).
```
new:
```
# Every 3 and 4 is logged with its code and meaning. An exit 0/1 without the
# resolver's result lines ("via" or "result"; a value for hostname and
# machine-id) is rewritten to 2 first (_aitlib_profile_run).
```

Edit 2 (runner): the whole `_aitlib_profile_run` comment and function, see the committed diff for the exact text; changes:
- comment: callers include user init; the accepted-output table (hostname/machine-id: exit 0 with a non-empty value; every other command: exit 0 or 1 with a "via" or a "result" line); missing resolver = RC 2 + error line; path args list; throw = error line.
- missing resolver (both branches): `AITLIB_PROFILE_RC=2; AITLIB_PROFILE_OUT="error"$'\t'"resolver <name> [or pwsh ]not found (<dir>)"` before `return 1`.
- path conversion: `if [ "$prev" = "--path" ]` -> `case "$prev" in --path|--profile|--out|--config)`.
- pwsh `-Command` catch: also `[Console]::Out.WriteLine("error`t" + $m)` with `$m = "aitools-profile $env:AITLIB_PS_CMD threw: <message, newlines collapsed>"`; `AITLIB_PS_CMD="${1:-}"` passed in the environment.
- temp file: new `_aitlib_rm_tmp FILE` (rm -f; failure = log_detail), used at the 3 sites.
- guard: `case "$1" in hostname|machine-id) [rc 0 and non-empty] ;; *) via or result line ;; esac`.

### 2b. scripts/aitools-lib.ps1 (parity)

- header line as 2a edit 1.
- `Invoke-AitLibProfile`: missing -> `$script:AitLibProfileRc = 2; $script:AitLibProfileOut = @("error`tresolver $leaf not found ($dir)"); return $false`; catch adds `"error`taitools-profile $cmd threw: $msg"` (newlines collapsed); guard as 2a.

### 2c. tests/profile/test-lib.sh

New driver call `run` (RUN_ARGS comma-separated; FAKEBIN prepended to PATH when set) printing `rc=<return> profrc=<RC>`, `out=<first result|via tag or bare value>`, `err=<first error>`, `args=<the stub's arg lines>`; the result grep accepts `out|err|args`. Cases, bash and PS unless noted:
- stub register / migrate with `result` only, exit 0 -> profrc 0; exit 1 + result -> profrc 1 (not rewritten)
- stub exits 2, 3, 4 with error lines -> passed through
- silent exit 0 / 1 for register -> 2 + "resolver exited N without result lines"
- stub hostname value -> 0; empty hostname -> 2
- missing resolver -> rc 1 profrc 2, error names it
- throw (PS in-process; bash via pwsh) -> profrc 2, err "aitools-profile register threw: boom"
- real resolver: register (fixture id-key, --out temp), migrate (id-key: unchanged), hostname (test hostname)
- via-pwsh (bash only): a cygpath stub converts --profile/--out/--config/--path values, not --slug
Run: `bash tests/profile/test-lib.sh` (bash 5 + pwsh) and `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-lib.sh --bash-only`, isolated HOME; baseline 209/0 must stay green.

## 3. Batch 2: user init

### 3a. scripts/aitools

Edit 1 (`ui_profile_run`): replace the private runner body with the lib runner plus the result copy:
```
ui_profile_run() {
    # Return 1 = no resolver: AITLIB_PROFILE_RC is then 2 with an "error" line naming
    # it, which every caller reads through UI_PROF_RC / ui_lines (the result check)
    _aitlib_profile_run "$@" || :
    UI_PROF_OUT="$AITLIB_PROFILE_OUT"; UI_PROF_RC="$AITLIB_PROFILE_RC"
    return 0
}
```
(comment rewritten: "the lib runner; results copied right after the call (lib result-global contract)").

Edit 2 (flag): in `user_init`, `local ... no_machine=false`; in the `if [ -z "$machine_key" ]` block (user init's own conclusion that this machine is not registered) add `no_machine=true`; at the writer call `if [ -n "$machine_key" ]; then ... --machine-id; elif $no_machine; then writer_args+=(--no-machine); fi` (Windows: `-NoMachine`). Not keyed on `machine_key` being empty at the writer call: the owner-"config" branch (registered, id undetectable) also empties it and must not get the flag. `--no-machine` and `--machine-id` cannot both be set (no_machine only when machine_key was already empty; the later branches only clear it).

### 3b. scripts/aitools.ps1 (parity)

`Invoke-UiProfile` -> `$null = Invoke-AitLibProfile $Arguments` (comment: $false = no resolver, Rc 2 + error line), copy to `$script:UiProfOut` / `UiProfRc`. `$noMachine = $false` set to `$true` in the `-not $script:UiMachineKey` block; `elseif ($noMachine) { $writerArgs["NoMachine"] = $true }`.

### 3c. tests/profile/test-user-init.sh

- unregistered-notty, alias-other, cached-alias-0, dirty: exactly one `ERROR|machine profile|` row, no `no machine match` row, one machine-registration ACTION, the writer's `--no-machine` / `-NoMachine` info line in both shells' output.
- via-config (registered, id undetectable): no flag line in either output; cached machineId kept (existing assertion).
- a registered machine (alias-new): no flag line.
Run test-user-init (baseline 200/0), test-config, test-profile under an isolated HOME; `bash -n` (5 and 3.2) and the pwsh parser on every touched script.

## 4. Error-handling audit (per block)

| block | pattern | verdict |
|---|---|---|
| `_aitlib_rm_tmp` | `rm -f` checked, failure -> log_detail | ok (no silent failure; detail so no row promotion) |
| runner missing-resolver | sets RC 2 + error line, returns 1 | ok; callers check the return |
| pwsh `-Command` catch | writes stderr + error line, exit 2 | ok (not empty) |
| guard | rewrite to 2 with error line + log_detail | ok |
| PS `Invoke-AitLibProfile` catch | LogDetail + error line + Rc 2 | ok |
| `ui_profile_run` `|| :` | commented; result read via UI_PROF_RC (2 + error line) at every call site | ok (USO: suppression with result check) |
| `Invoke-UiProfile` `$null =` | return value documented; Rc checked by callers | ok |
| writer flag | no new suppression | ok |

## 5. Not in scope (seen, left to FIX-1 / FIX-2)

A-2 (resolve_machine_profile resolver-missing has no ACTION), A-3, A-4's `run_child_relayed` part, A-12..A-15 in user init. The runner's part of A-4 is done here because the private runner checked its removal (row 9).
