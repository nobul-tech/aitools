# S3-Profile-Review2: independent review of PR #76 and PR #77

1. **PR #76 (exception-get/set):** no blockers, 1 major (M1: the hostname-only refusal can be bypassed through `via=alias`; spec gap in tree section 8), 8 minor. Mergeable once the commander rules on M1, or with M1 as an immediate follow-up.
2. **PR #77 (setup-user-config):** no blockers, 1 major (M1's second half: derive-config caches a hostname-matched alias), 10 minor. The engine move is verified behaviour-neutral.
3. **Totals:** 0 blocker / 2 major (one root cause) / 18 minor.
4. **Tests, all passing:**
   - test-profile: 275/0 (bash 5 + pwsh); 202/0 (bash 3.2, bash-only).
   - test-config: 74/0 (bash 5 + pwsh); 46/0 (bash 3.2, bash-only).
   - `/bin/bash -n`, `perl -c` and the pwsh parser: clean.
5. **Reviews posted (comment only):**
   - https://github.com/nobul-tech/aitools/pull/76#pullrequestreview-5609362853
   - https://github.com/nobul-tech/aitools/pull/77#pullrequestreview-5609362991

## Scope and method

- **Read:** the mission packet; the user and project rules; tree section 8 (S3-GateFix draft); the user-repo.md "Profile Schema" and "Config Schema (v3)" sections (S4-Review draft); the plan decisions (P-Q2/3/4, N-Q1/2, D-TS12/13); the installers' current Step 5; and the prior #73 review, so its findings are not repeated.
- **Changed files, read in full at m3cfg HEAD 67e144f:** aitools-profile.sh/.ps1, aitools-json.pl/.ps1, setup-user-config.sh/.ps1, the test and CI diffs.
- **Diff checked:** `origin/feature/m3-b1b-tool-exceptions` (#76 head 50e4bb5) vs HEAD contains only #77's 8 files.
- **Probes** (mktemp HOMEs; the real HOME and the live dotprofile untouched, except one read-only `git check-ignore`). Scripts in `/Users/new-jose/repos/aitools/.claude/worktrees/m3cfg/.scratch/session-S3PRev2/`:
  - `probe1.sh` (P1-P11, log `probe1.log`)
  - `probe2.sh` (in-process PS logging, invalid profile.json)
  - `engine-cmp.sh` (engine move)
  - `parse.sh` (syntax checks)
- **Review bodies:** `review-76.md`, `review-77.md`. They are the same as the posted comments.

## Major

**M1 (#76 code, #77 trigger). The hostname-only refusal can be bypassed through `via=alias`, and alias can write into another machine's profile.**
- **P1 (both implementations):**
  - `exception-set` on a hostname-only match gives `result refused`, `via hostname`, exit 3.
  - setup-user-config then writes `"machineAlias": "nobul-mac"`.
  - `exception-set` then gives `result created`, `via alias`, exit 0.
- **P11 (both implementations):** config.json `machineAlias` points at a profile registered to another machine. The output is `warn profile "laptop" is registered to another machine` ... `result created`. A realistic trigger is Migration Assistant copying `~/.aitools`. The other machine then matches the entry (same platform, method and path) and silently keeps an install it never chose.
- **Code:**
  - `aitools-profile.sh:790` and `.ps1:649` refuse only `hostname` and `none`, which is tree section 8 taken literally.
  - `aitools-profile.sh:879-884` and `.ps1:749-754` persist the alias for every `via` except an env override.
- **Suggested direction (commander decision):**
  - refuse alias when the profile's `machine.id` is absent or differs from this machine's id (`machine_done` already detects both, sh:470-476);
  - and/or do not persist `machineAlias` when `via=hostname`;
  - update tree section 8.

## Minor, PR #76
1. **PowerShell `exception-set` exits 2 with empty stdout after writing profile.json when git is not on PATH.** `& git` (ps1:582) throws into the `trap` (ps1:59-63). Probe P9 showed the backup made and the entry written. Bash gives a warn and exit 0 (sh:731-733). Fix: a `Get-Command git` check.
2. **`unchanged` is only reachable with `--decided-at`.** The default timestamp is the current time (sh:772-773, ps1:631-632) and it is part of the comparison (sh:831, ps1:698). Probe P2: `created`, then `updated` one second later, so every re-record means a commit and a push.
3. **Parity, `"go": null`:** bash gives `created` (sh:799-800), PowerShell gives `updated` (ps1:660-661). Probe P3.
4. **Parity, a wrong-case `ToolExceptions` key:** bash adds a second `toolExceptions`, PowerShell writes into `ToolExceptions` (case-insensitive lookup). Probe P6.
5. **Duplicate `machine.id` refusal adds a misleading second error.** The output adds "no machine profile for this machine -- run: aitools user init" (sh:794-795, ps1:653-654), but `register` refuses duplicate ids. Probe P5.
6. **Unrelated uncommitted profile.json edits are committed under "Record tool exception".** Probe P10.
7. **The identity fallback checks only `user.email`** (sh:738-743, ps1:589-595). Nit.
8. **Coverage gaps:**
   - No tests for push failure, writes via alias/override/environment, or odd entries. Push failure itself works (P4: `committed true`, `pushed false`, warn, exit 0).
   - Native Windows never runs `exception-set` in CI.

## Minor, PR #77
1. **No double-slash or path validation.** `//` and relative bootstrap paths are written as-is (P7). Spec: user-repo.md Config Schema `validate_json_config`, and config-file-safety.md "Post-write validation". The old Step 5 had it (aitools-install.sh:494, 223-242).
2. **Lost: the fresh-machine fallback without the engine.** The old installer wrote bootstrap keys without node (aitools-install.sh:524-537). The new writer exits 1 without perl (setup-user-config.sh:99-103). The user-repo.md "Without node" text needs updating.
3. **An invalid profile.json is reported as `ERROR|machine profile|no machine match`** plus `ACTION ... (profiles: none)` (probe2; sh:162-167, ps1:160-165).
4. **`setup-user-config.sh:122` runs PATH `bash`, not `"$BASH"`.** The 3.2 config job therefore runs the resolver under Homebrew bash 5 (`command -v bash` gives `/opt/homebrew/bin/bash`).
5. **B3b wiring:** `--drives-json` must be a single line (P8). The PS installer must pass `ConvertTo-Json -Compress` (aitools-install.ps1:383).
6. **B3b wiring:** the installers still write `version: 2` (aitools-install.sh:458), so config.json flips between 2 and 3 until B3b lands.
7. **Salvage unescape** covers only `\"`, `\\` and `\/` (sh:199, ps1:192). Nit.
8. **PowerShell in-process resolver stderr** goes to the console; bash logs it as detail (sh:122-125). Nit.
9. **Governance:** `aitools-json.pl` and `.ps1` are missing from the cross-platform.md OS guard exemptions, and a `.pl` + `.ps1` pair is not covered by the pairing rule. Any future embedding of aitools-profile.sh (the header's "embedded copy") must carry aitools-json.pl. There is no consumer today (grep of build-deploy.sh, aitools, aitools.ps1 and the libs: none).
10. **`setup-user-config.sh:249-250`:** `|| A="a"` / `|| B="b"` lack the comment script-standards.md requires (the result check is implicit). Nit.

## Engine move (lens g)
- The perl engine at #76's head is byte-identical to the code part of aitools-json.pl (242 lines, `cmp` clean; engine-cmp.sh).
- The PS helpers are identical apart from the removed 3-line header. The worktree has them as CRLF, from `.gitattributes` `*.ps1 eol=crlf`; `git ls-files --eol` shows the index as LF.

## Checked and fine
- **#76, refusals:** no dotprofile, hostname, none and snapshot all exit 3; a dry run writes nothing.
- **#76, write path:** temp → re-read → backup → move. Entry shape and key order match user-repo.md.
- **#76, commit and push:**
  - the commit is a pathspec commit of profile.json only;
  - the push uses `GIT_TERMINAL_PROMPT=0`;
  - commit or push failure is a warning, exit 0 (P4).
- **#76, backups:** `profile.json.bak.*` is git-ignored in the live dotprofile (`.gitignore:2`) and in user-init-created ones (scripts/aitools:1163, aitools.ps1:1090).
- **#77, merge and outcomes:**
  - read-then-merge preserves unknown keys in place;
  - there is a backup before every write and none on verified;
  - outcomes are created / updated / verified / recovered / dry-run;
  - D-TS12 holds, and the writer never exits 2 (D-TS13);
  - env overrides are not persisted.
- **#77, parity:** summary rows and config bytes are identical in both implementations.
- **#77, in-process PowerShell:** the child does not clobber the parent's log tag or counters (probe2).

## Not run
- Native Windows and Linux (CI covers those runners).
- PowerShell 7.4 or older: the `-DateKind` fallback means older 7.x parses ISO strings as DateTime. Whether profile.json timestamps round-trip byte for byte there is unknown.
- check-pre-commit / check-pre-push: not needed for a review.

## INCIDENT markers (not filed)
- `INCIDENT:` Tree section 8 (S3-GateFix draft) allows `via=alias` without the "no machine.id" or "registered to another machine" conditions. This is the spec-level root of M1.
- `INCIDENT:` cross-platform.md "OS guard exemptions" and "Platform targeting principle" do not cover the `.pl` + `.ps1` library pair `aitools-json.*`.
- `INCIDENT:` the user-repo.md "Config Schema (v3)" draft still describes the no-node fallback after P-Q3.

## Open questions (with suggested answers)
- **Q1. Should `exception-set` accept `via=alias`?** Suggest: only when the alias profile's `machine.id` equals this machine's id (then `via` would already be `id`), or when this machine's id is unavailable. So, effectively refuse alias for unregistered or foreign profiles, and stop caching hostname matches in config.json.
- **Q2. Should an identical re-keep be `unchanged`?** Suggest yes: compare without `decidedAt` and keep the original timestamp, so there is no commit or push churn.

## WRITE_BLOCKED
None.

## Delegates used
None.
