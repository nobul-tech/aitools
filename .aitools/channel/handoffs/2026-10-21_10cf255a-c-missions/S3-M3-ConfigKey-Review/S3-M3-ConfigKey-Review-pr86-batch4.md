**Verdict: approve-equivalent for c1ca81e. One condition: #86 does not merge before batch 5 (finding 1).** No blockers. 1 major, 4 minor, 3 nit.

Reviewer: S3-M3-ConfigKey-Review (independent level-3 reviewer, delegated by S3-M3-ConfigKey). Scope: commit c1ca81e on `feature/m3-rekey`. Files: `scripts/setup-user-config.sh`, `scripts/setup-user-config.ps1`, `tests/profile/test-config.sh`.

## What holds (verified, not taken from the commit message)

- **Tests reproduce.** `test-config.sh` gave 169 passed, 0 failed (with pwsh parity). Under `/bin/bash` 3.2 with `--bash-only` it gave 109 passed, 0 failed. Both ran under an isolated HOME and AITOOLS_LOG_DIR in scratch.
- **Routing parity.** The bash `derive_warn` case patterns and the PS `Write-DeriveWarning` branches select the same classes, in the same order. Every warning text they match is byte-identical between `aitools-profile.sh` and `.ps1`: no machine.id at sh:604 / ps1:494, migrate at sh:675, 694 / ps1:539, 550, config.json at sh:699-736 / ps1:555-583.
- **Classification of every derive-config warning:**
  - Handled (info): every `config.json ...` warning, `not saved to config.json`, `no dotprofile found`, `githubUser unknown`.
  - Advisory (info + one ACTION): `has no machine.id -- run: aitools user init`, and `run: aitools-profile migrate`.
  - Real (log_warn): another machine's profile, clone/rename, duplicate alias, key/id disagreement, hostname-only match, machine id or hostname unavailable, non-object entries, no claude-code-web profile.
  - I found no misclassification except the "handled" label in finding 2.
- **ACTION placement is a sound reading of script-standards-detail.md "Severity decision guide".**
  - The guide's rule is "`log_warn` + `write_summary ACTION` -- always pair ACTION with a log_warn carrying the same instruction". Section 3 does exactly that: `config: Run: aitools user init (...)` plus the ACTION with the same text.
  - It runs after the config row. That is the only way to keep the row OK, because `write_summary` / `Write-Summary` auto-promote OK to WARN once `WARNINGS > 0` (aitools-lib.sh:569, aitools-lib.ps1:498).
  - The warning is still counted in the footer, and the installer relay (#89) counts it once, as before. This is the right trade.
  - The coupling to auto-promote ordering is implicit; nit 3 asks for a comment.
- **Deprecated flag semantics match across shells.** Probes, with output in scratch `probe.log`:
  - `--machine-alias ""` and `-MachineAlias ""`: both log the detail line, pass no override, and produce the same rows and config.
  - `--machine-id X --machine-alias ""` and `-MachineId X -MachineAlias ""`: both give ERROR `bad arguments`, exit 1. Bash keys on "flag seen" (`DEPRECATED_ALIAS=true`) and PS keys on `$PSBoundParameters.ContainsKey`, so they agree.
- **Callers.**
  - `scripts/aitools:1296,1302` and `scripts/aitools.ps1:1261` pass the old flag only when it is non-empty. It is accepted, and its only effect is a detail line.
  - The installers (`aitools-install.sh:500`, `.ps1:386`) pass neither flag.
  - No caller breaks.
- **Intent blocks are unchanged.** The diff hunks start after the `Intent:` block in both headers. `CONFIG_INTENT_JSON` is untouched. Drift in both is noted in finding 4.
- **Bash 3.2.** No 4.x constructs were added. The new code uses plain `case` and `[ ]`, and the 3.2 suite passes.
- **PS case-insensitive variable bug class.** I checked `$MachineId`/`$d.mid`/`$D_ID`-style pairs and `$advice`/`$deprecatedAlias`/`$choiceArg`. They have no collisions: `$d.id` and `$d.mid` are distinct hashtable keys.
- **Exit codes.** Only 0 and 1. No prompts.

## Findings

### 1. major -- the migrate ACTION names a command that does not migrate yet (merge gate for #86)

- **Where:** `scripts/setup-user-config.sh:358` and `scripts/setup-user-config.ps1` section 3. Text: `Run: aitools user init (re-keys machine profiles by machine id)`.
- **Evidence:** on this branch, `scripts/aitools` has no call to `aitools-profile ... migrate`. `grep -n migrate scripts/aitools` finds only the v1->v2 `migrate_profile_v1_to_v2` and the `aiToolingRepoPath` key migration (lines 104-271, 823-841). The commit says so itself: "batch 5 calls migrate there".
- **Impact:** the live dotprofile on this Mac is a 2.1 legacy entry (`nobul-mac` with `machine.id`). If #86 merges before batch 5, every `aitools` run shows this ACTION. Running the advised command then leaves the profile alias-keyed, so the ACTION never clears.
- **Fix:** record "batch 5 lands on #86 before merge" as an explicit merge condition in the #86 PR body. Alternative, if #86 must merge first: word the ACTION as `aitools-profile.sh migrate --profile <dotprofile>/profile.json` until batch 5. That conflicts with the lead decision to name the user-facing command. Suggested answer: the merge gate.

### 2. minor -- a stale `machineId` is logged "handled by this write" but is kept

- **Where:** sh:175-176 (`config.json\ *` -> "handled"), sh:267 (`machineId` set only when `derived.machineId` is non-empty), and the PS equivalents.
- **Evidence (probe p1, both shells, identical):** config.json had `machineId "aaaaaaaa-..."` and the live id matched a legacy alias-keyed entry.
  - Log: `config: config.json machineId "aaaaaaaa-1111-2222-3333-444444444444" disagrees with machine.id match "nobul-mac" -- machine.id wins (handled by this write)`.
  - The written config still has `"machineId": "aaaaaaaa-1111-2222-3333-444444444444"`.
  - The same happens for `config.json machineId ... not in profiles -- ignored` (resolver sh:719).
- **Impact:**
  - The log line is untrue.
  - The stale key also persists. Resolver step 4L is gated on `[ -z "$config_id" ]` (aitools-profile.sh:723). A machine whose id later becomes undetectable therefore skips its valid legacy `machineAlias` cache and falls to the hostname guess.
- **Fix (either option):**
  - (a) When derive-config matched (`DERIVE_RC=0`, `via` not `hostname` and not an env override) and `derived.machineId` is empty, remove `machineId`. `aitools-json.pl` has a `del` op (line 270). `aitools-json.ps1` has no remove function, so the PS side would use `$cfg.PSObject.Properties.Remove("machineId")` on the merged object. Add a test case where an old machineId plus a legacy match leaves no machineId.
  - (b) Route those two texts to "real" (log_warn) instead of "handled".
  - Suggested: (a). Design (e) defines machineId as "the matched key", so a non-matching cached key should not survive a successful derivation.

### 3. minor -- c10 does not prove its stated claim ("upper-case id selects the lower-case key")

- **Where:** `tests/profile/test-config.sh:276-279`.
- **Evidence:**
  - The fixture's live id is `AITOOLS_PROFILE_TEST_MACHINE_ID=$ID_MAC` (run_writer, line 91). Step 3 therefore selects the same profile with or without `--machine-id "$ID_MAC"`. c3 (same fixture, no flag) asserts the same rows and keys.
  - c10 would pass if `--machine-id` were ignored. The plumbing is proven only by c10d (unknown id -> no match).
  - Probe p2 shows the override path works when the id cannot be detected: `via=override`, identical in both shells. Note that machineId is not written there, because owner is not `this`.
- **Fix:** add `log_has "via=override"` to c10, or run c10 with `CASE_ENV="AITOOLS_PROFILE_TEST_MACHINE_ID=none"` and assert `via=override` plus `machineAlias "nobul-mac"`.

### 4. minor -- intent statements now drift from the code (protected: draft needed, not an edit)

- **Where:**
  - `setup-user-config.sh:7-9` / `.ps1:6-8`: "machine alias and how it was chosen", "callers prompt, then pass --machine-alias / -MachineAlias".
  - `CONFIG_INTENT_JSON` (sh:223 and the PS twin): the scope lists "githubUser, userRepoPath, machineAlias" and not machineId.
- **Evidence:** the usage lines (sh:31-33) now make `--machine-id` the flag and `--machine-alias` deprecated. Every created or updated config.json gets this `meta.intent` text.
- **Fix:** leaving the intents unchanged was correct (sources-of-truth.md "Intent statements"). Ship a draft for commander approval in the mission folder and list it under "Protected-file drafts awaiting approval" in the #86 body. Suggested text: "... machine id and alias and how they were chosen ... callers prompt, then pass --machine-id" and scope "(githubUser, userRepoPath, machineId, machineAlias)". When the JSON intent changes, the c1 regex and the byte-parity cases all pick it up.

### 5. minor -- the machineId salvage from a corrupt config is untested

- **Where:** sh:247 / PS salvage list. The commit message claims "machineId ... in the salvage list of a corrupt config".
- **Evidence:** the c4 fixture (`test-config.sh:218`) has no `machineId`. Its `has_json '"machineId": ...'` (line 223) is satisfied by the derivation, not by salvage.
- **Fix:** add a case with `"machineId": "<KEY_MAC>"` in a corrupt config and `AITOOLS_PROFILE_TEST_MACHINE_ID=none` (no derived machineId). Assert `Recovered machineId from the invalid config` in deploy.log and the key in the output, in both shells.

### 6. nit -- the "registers this machine" ACTION also fires for the rename/clone signal

- **Where:** sh:183 (real branch: `*"run: aitools user init"*` -> `NEED_INIT`).
- **Evidence:** probe p4 and c18. The warning is `... renamed (run: aitools user init to update it), or a clone ...`, and the ACTION reads `Run: aitools user init (registers this machine)`. The machine is already registered. This text came from the old code, so the behaviour is not new.
- **Fix (optional):** a separate advice text for the rename case, e.g. `(updates this machine's profile)`.

### 7. nit -- the PS footer count is not asserted

- **Where:** `out_has` reads only `$CASE.bash.out` (`test-config.sh:164-166`), so the "COMPLETED with N warning(s)" checks in c13 and c18 cover bash only.
- **Evidence:** I checked by probe that PS prints the same counts: `COMPLETED with 1 warning(s)` for p1 and `2` for p4. Nothing in the suite guards it.
- **Fix:** save the PS output as `$CASE.ps.out` in `case_run` and compare the footer lines, or diff the `[warn]` line counts.

### 8. nit -- the auto-promote coupling is implicit

- **Where:** the section 3 comment, sh:353-354 / PS twin.
- **Evidence:** the comment says the ACTION comes "after the config row". It does not say why: `write_summary` promotes OK to WARN once WARNINGS > 0. A later edit that moves the ACTION block above section 2 would silently turn every advisory run into a WARN row, and c13/c17 would catch it only by the row text.
- **Fix:** add one clause: "(must stay after the row: write_summary promotes OK to WARN once a warning is counted)".

## What I ran

All runs used HOME and AITOOLS_LOG_DIR under `.scratch/session-CfgRev/`, never the real HOME.

- `git show c1ca81e`. I read in full: both writers after the change, the diff of `test-config.sh`, `aitools-profile.sh` (`machine_done`, `resolve_machine`, `cmd_derive_config`), and the warning texts of `aitools-profile.ps1`.
- `bash tests/profile/test-config.sh` -> 169 passed, 0 failed.
- `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-config.sh --bash-only` -> 109 passed, 0 failed.
- `probe.sh`, bash and pwsh, on these fixtures:
  - p1: stale machineId plus a legacy id match.
  - p2: `--machine-id` / `-MachineId` override with the id undetectable.
  - p3: empty deprecated flag.
  - p4: advisory and real warnings together.
  - p5: `--machine-id X` with an empty `--machine-alias`.
  - Results: every pair gave identical rows and config keys. Findings 2, 3 and 6 come from these runs.
- `grep` of the callers: `scripts/aitools`, `aitools.ps1`, `aitools-install.*`, `aitools-lib.*`.
- `grep migrate scripts/aitools` (finding 1).
- Not run: Windows, Git Bash, check-pre-commit and check-pre-push. Running the checks was not in the review scope.

INCIDENT markers (not filed):
- `INCIDENT:` script-standards-detail.md "Severity decision guide" / "ACTION items" do not mention that `write_summary` auto-promotes OK to WARN once a warning is counted. Pairing an ACTION with `log_warn` therefore promotes every later OK row of the same script, which forces callers to order rows by hand (finding 8).
