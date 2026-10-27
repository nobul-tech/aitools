# S3-MF-Fix6-Review: independent review of PR #108

**Intent**: **Purpose**: An independent verdict on whether PR #108 fixes S3-MF-Audit findings A-6 (code part), A-7, A-8 and A-9 and changes nothing else, in particular not the resolver's output contract. **Scope**: The PR diff (fix/mf-audit-profile-json at b42f9e1, base origin/main), the four findings, the tests. NOT other audit findings. NOT fixing code. NOT approving or merging. **Audience**: S3-MF-Fix6 (author), Jose.

Reviewer: S3-MF-Fix6-Review (wrote none of this code). Checklist: `S3-MF-Audit-findings.md` (origin/docs/mf-audit) section 2 and section 8 I-3. Reviewed 2026-10-22 on macOS.

## Verdict

**Approve-worthy. 0 blocking findings, 4 non-blocking.** All four findings are fixed in both languages where they apply. The tag protocol and exit codes are unchanged. The only behaviour change beyond the findings is the A-9 case-twin refusal. I think it is justified: it is the smallest rule both engines can follow, and it stops bash from writing a profile.json that PowerShell cannot read.

## Per-finding table

| id | status | evidence (PR head) |
|---|---|---|
| A-6 (code) | **fixed** | `die_internal` at aitools-profile.sh:156-162 runs `log_detail "internal error: ..."`, then prints the same stderr text as before and exits 2. The old `'internal error reading %s (engine exit %s)'` and `'internal error %s'` + `"reading $1 (engine exit $__rc)"` are byte-identical. Called from jread :175, jlist :189, jtype :202, jsub :215. Snapshot missing/invalid/engine-failure exits now also log at detail: sh:1205-1215, ps1:1065-1072. PS already had the `trap` LogDetail (ps1:85-89). The PR also checked the other early exits (engine missing sh:144, perl missing sh:149, machine-id sh:799 / ps1:631, hostname sh:811 / ps1:644, usage ps1:208); all of them already log at detail. |
| A-7 | **fixed** | ps1:972-976: the WriteAllText catch now calls `Remove-TempFile $tmp` before `Complete-Command 2`, as bash does (sh:1116 `remove_tmp`). The new edit catch also removes it (ps1:965-967). Remove-TempFile does nothing when the file is absent (ps1:858), so this adds no spurious warn. |
| A-8 | **fixed** | `Get-WriteErrorText` (ps1:867-873) unwraps MethodInvocationException and maps UnauthorizedAccess to "Permission denied" and DirectoryNotFound/FileNotFound to "No such file or directory". It is used in exception-set (ps1:973), register (:1257) and migrate (:1357). Other cases fall back to the inner .NET message (a possible parity gap, n-3). Tests a78-exc-ro, a8-mig-ro, a8-reg-ro and a8-reg-nodir check byte parity. |
| A-9 | **fixed** (with a justified behaviour change) | aitools-json.ps1:105-108 `Find-JProperty` (`-ceq`) and :116-136 `Set-JValue` match exactly, as `Get-JNode` (:50) and perl `setp` do. Both engines refuse a new segment that matches an existing key ignoring case, with the same message: ps1:139-143 `Assert-JNoCaseTwin` and pl:178 `kfold` + :189-202 `$nocase`. `renp` now uses the shared `kfold` (pl:213+); the logic is unchanged and the existing jr-* rename tests still pass. |

## Contract check (nothing else changed)

- **Tag protocol / exit codes**: no `put`/`Put`, `finish`/`Complete-Command` code or exit number changes in the diff, apart from the new PS edit catch (ps1:948-968). That catch turns what used to be a `trap` exit (stderr only, exit 2, no protocol lines) into `result failed` + `error exception-set failed: <msg>` + exit 2. This is the bash shape (sh:1114-1116) and still exit 2, so it brings PS into line with the contract.
- **Existing messages**: the stderr text of every touched bash exit is unchanged (A-6 row). The PS write-failure text changes on purpose (A-8). No consumer parses any of these texts. `grep -rln -e "cannot write" -e "Exception calling" -e "differs only in case" -e "internal error"` over scripts/ and tests/ finds them only in the resolver, the engines, the tests and unrelated perl in build-deploy.sh, plus one unrelated LogError in aitools.ps1:1706.
- **A-9 effect on consumers**:
  - *Resolver register*: an upper-case, hand-written id key is renamed first, so it is not refused. Probe (`probe-register-case.sh`, PR vs origin/main, both impls): all four runs give `result updated`, key `3d4df2a5-...` (lower case), exit 0. Unchanged.
  - *Resolver exception-set*: a hand-written `ToolExceptions` is refused by both with the same lines and profile.json untouched (test a9-exc-case). Before, perl added a sibling `toolExceptions`, which made the synced profile.json unreadable by `ConvertFrom-Json` on Windows (PR body; I did not re-run that PS 7 error), and PS overwrote the other key.
  - *setup-user-config*: a config.json with e.g. `MachineId` now gets `ERROR|aitools config|merge failed` in both languages (sh:291-295 / ps1:264-298, both inside the failure branch). The PR body says so. See n-2 for the UX gap.
  - *user init (scripts/aitools, aitools.ps1)*: it only reads with the engines (aitools:367-374, 536, 739, 780 are get/keys/type/check); writes go through the resolver. No effect.
  - *setup-user-config.ps1:255* (recovery from an invalid config) calls Set-JValue on a fresh object with six distinct names, so no case twin is possible.
- **Unicode fold parity** (`probe-fold.sh`): perl `lc` after `utf8::decode` and PS `-ieq` agree on KELVIN SIGN vs `k` (both refuse), `SS` vs `ß` (both accept) and `İ` vs `i` (both accept).
- **Judgement on A-9**: justified, not overreach. Exact match alone would still diverge: PS `Add-Member` throws on a case twin where perl appends a sibling (PR body). The only rule both engines can apply the same way is to refuse, and it matches the case rule `rename` already had (`jr-exists-case`). It is a new failure mode for hand-edited files, though, and no spec records it (I-5 below).

## Blocking findings

None.

## Non-blocking findings

- **n-1 (test gap, A-6)**: no test reaches `die_internal`, the four internal-error exits that A-6 is about. The new a6-* tests cover only the snapshot paths. These exits are hard to trigger, since they need the engine to fail on an already validated file. The engine path is fixed to `$SCRIPT_DIR` (sh:142), so a test would need a copy of the resolver dir with a stub `aitools-json.pl` that passes `check` and fails `get`. Optional. The code change is small and I read it at each call site.
- **n-2 (consumer UX, A-9 behaviour change)**: when setup-user-config refuses a case twin, the reason is logged only at detail (sh:293 `log_detail "merge: $MERGE_MSG"`, ps1:293). The console shows only "config merge failed -- existing file left untouched", with no ACTION, so a user with a hand-written `MachineId` does not learn which key to fix unless they read deploy.log. Test-config has no case for it either. Suggest a follow-up in S3-MF-NoMachine's file (not this PR): put the engine message in the log_error, or add `ACTION "Fix <key> in config.json (details in deploy.log)"`.
- **n-3 (parity residue, A-8)**: `Get-WriteErrorText` maps two exception classes. Any other write failure (disk full, `IOException` "file in use", path too long) still prints the .NET message where bash prints perl's `$!` text. That is acceptable as a documented fallback (ps1:863-866), but A-8 is fully closed only for the two common cases.
- **n-4 (I-3 draft, for the commander)**: the draft (S3-MF-Fix6-drafts/reference/script-standards-detail.md.edit.txt) is consistent with the code as far as I checked. `set -euo pipefail` is at sh:66, the lib + `logging_init` at sh:69-79, and every early exit listed in the draft logs at detail (A-6 row). The one stderr-only exit is the PS 7 guard (ps1:68-71), and the draft names it as the exception. I did not audit the draft's other block-order items against the PS file: unknown. It is a protected-file draft and does not block this PR.

## Spec deficiency

- `INCIDENT:` (I-5, new) No spec covers how the JSON engines treat key case. Exact segment match, the refusal of a new key that differs only in case, and the reason (PowerShell `ConvertFrom-Json` rejects such files) are written only in the aitools-json.pl header (pl:27-30) and the aitools-json.ps1 comments (ps1:110-115). reference/user-repo.md and reference/cross-platform-detail.md say nothing about it (`grep -i "ignoring case|case-insensitive|differs only in case"`: no hits). A hand-edited profile.json or config.json can now fail a run, and nothing documents that for the user. Suggested: one paragraph in reference/cross-platform-detail.md (PowerShell JSON) or reference/user-repo.md "profile.json"; protected, so draft first.

## Tests run (macOS, isolated HOME and AITOOLS_LOG_DIR under `.scratch/session-mfrev/`, cwd `.scratch/session-mfrev/cwd`)

Script: `.scratch/session-mfrev/run-tests.sh` (logs `<suite>-bash5.log` / `<suite>-bash32.log` beside it).

- `bash -n` (GNU bash 5.3.15) and `/bin/bash -n` (3.2.57) on scripts/aitools-profile.sh and tests/profile/test-profile.sh: clean.
- `perl -c scripts/aitools-json.pl`: syntax OK.
- pwsh `Parser::ParseFile` on scripts/aitools-profile.ps1 and scripts/aitools-json.ps1: clean.

| suite | GNU bash 5.3.15 | /bin/bash 3.2.57 (`AITOOLS_TEST_BASH=/bin/bash`) | baseline before PR |
|---|---|---|---|
| test-profile | 744 passed, 0 failed (exit 0) | 744 passed, 0 failed (exit 0) | 689/0 (+55 new assertions, as the PR body says) |
| test-lib | 209 passed, 0 failed (exit 0) | 209 passed, 0 failed (exit 0) | 209/0 |
| test-config | 190 passed, 0 failed (exit 0) | 190 passed, 0 failed (exit 0) | 190/0 |
| test-user-init | 200 passed, 0 failed (exit 0) | 200 passed, 0 failed (exit 0) | 200/0 |

The pwsh parity halves ran in every suite (pwsh 7 on macOS).

Probes: `probe-register-case.sh` (register with an upper-case id key, PR head vs origin/main, bash and pwsh), `probe-fold.sh` (Unicode case-fold parity of the two engines).

## Not run

- Windows / Git Bash: the PS side ran under pwsh 7 on macOS through `AITOOLS_PROFILE_TEST_ANY_OS=1` only.
- check-pre-commit / check-pre-push (the author reports them; known pre-existing failures are step 6 and step 7).
- `build-deploy.sh` and anything against the real HOME.
- The PS 7 "keys with different casing" ConvertFrom-Json error on a sibling-key file: I took it from the PR body and did not reproduce it.
