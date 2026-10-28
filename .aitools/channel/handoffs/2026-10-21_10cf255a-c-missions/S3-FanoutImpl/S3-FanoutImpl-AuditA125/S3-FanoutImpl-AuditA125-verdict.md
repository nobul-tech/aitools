AUDIT (logging, A): FINDINGS

Static logging and script-standards audit by S3-FanoutImpl-AuditA125 (independent of auditor B; B's output not read). No blocking findings. 5 non-blocking findings.

**Scope reviewed:** head `72589f9` (`origin/feature/fanout-skills-legacy`), `git diff 3178810...72589f9`: `scripts/setup-user-skills.sh`, `scripts/setup-user-skills.ps1`, the setup-user-skills generator section of `scripts/build-deploy.sh` (lines 1259-1463), `tests/skills-legacy/test-skills-legacy.sh` (checked for silent failures only). For context I read the lib functions these scripts call, on the branch: `log` / `log_error` / `log_detail` / `write_summary` / `write_environment_skip` / `skill_name_kind` / `in_list` / `read_harness_manifest` / `show_summary` in `scripts/aitools-lib.sh`, and their twins in `scripts/aitools-lib.ps1`. This was static reading only: nothing was run.

## Findings

### N1 (non-blocking): summary detail text is over 30 characters
The rule (`.claude/rules/script-standards.md` "Config and file update reporting", "Summary detail text is max 30 chars"; `reference/script-standards-detail.md` "Summary detail text rules") is broken by 4 new strings, each used in both languages:

| Detail | Length | .sh | .ps1 |
|---|---|---|---|
| `n/a (fanned out from ~/.aitools/skills)` | 39 | :62 | :56 |
| `reverse discovery skipped: dotprofile error` | 43 | :89 | :83 |
| `reverse discovery skipped: cannot read ~/.aitools/skills` | 56 | :292 | :229 |
| `reverse discovery skipped: cannot read skills manifest` | 54 | :308 | :241 |

No check script enforces the limit. I found no length check in `check-pre-commit` / `check-pre-push` / `check-post-push` / `check-lib`; scripts enforce it themselves (`deploy-harness.sh:115-118` `short()`, `setup-google-chrome.sh:390-391`). The path and reason already go in the log line, so the row can be short. Suggested texts: `n/a (fanned out)` (16), `no adopt: dotprofile error` (26), `no adopt: harness unreadable` (28), `no adopt: manifest unreadable` (29). The test pins these strings (`test-skills-legacy.sh:181,245,261,269`), so it would need the same edit. The header comments (`.sh:15-16`, `.ps1:14-15`) and `build-deploy.sh:1311` quote the n/a text too.

### N2 (non-blocking): the ERROR rows use the governed term "skipped"
The 3 ERROR details at `.sh:89,292,308` / `.ps1:83,229,241` say "reverse discovery skipped: ...". "skipped" is a governed deployment outcome: the user's choice at the review menu (`reference/script-standards-detail.md` "Governed summary outcomes" and the `/glossary` skill; `.claude/rules/cross-platform.md` "Environment branches": not "skipped" (a governed deployment outcome)). Here it describes an error path, not a user choice. The wording suggested in N1 fixes both findings.

### N3 (non-blocking, doc follow-up): new summary tool name `skills` is not in the canonical tool name table
`reference/script-standards-detail.md` "Tool name table" says to "Always use these exact strings", and `skills` is not in it. The rows are written at `.sh:62,89,292,308` / `.ps1:56,83,229,241`. The table is already out of date: it lists `claude skills` / `cursor skills` under `setup-user-mcp`. Suggested follow-up: add `skills | setup-user-skills` and move the two skills rows to `setup-user-skills` and the fan-out scripts.

### N4 (non-blocking): the test can pass with its parity and MDM cases skipped
- `test-skills-legacy.sh:71-75`: without perl or git it prints `SKIP all cases` and exits 0.
- `:187`, `:276`, `:341`: without pwsh every .ps1 case and the parity check are skipped.
- `:289-293`: without node every MDM case is skipped, and the script exits 0 when no case failed.

Each skip prints a `SKIP` line, so it shows in the log. But a CI runner that lacks pwsh or node would go green with no .sh/.ps1 parity coverage and no MDM coverage. Suggested fix: an opt-in `AITOOLS_TEST_REQUIRE_ALL=1` that turns a skip into a failure, set in `.github/workflows/check.yml` for these steps, or an explicit `command -v pwsh node` step. I did not check whether the macos-14 and ubuntu-latest images ship pwsh and node: unknown.

### N5 (non-blocking nit): log text differs between .sh and .ps1
The summary rows are identical, but the log messages differ:
- `.sh:291` logs no reason, while `.ps1:228` appends `: $_`.
- `.sh:307` logs `(exit $rc): $out --`, while `.ps1:240` logs `` `: $_ -- ``.
- `.sh:61` / `:291` / `:307` pass the path through `display_path`, while `.ps1:55` / `:228` / `:240` log the raw path.

The brief asks for the same log messages. Aligning the wording, with the reason last in both, would make one grep pattern work on both logs.

## Checklist: what passed, with evidence

- [x] **Log line format** `[ts] [script] [level] msg`, UTC with Z, levels info/ok/warn/error/detail. Every new line goes through `log` / `log_error` / `log_detail` (`aitools-lib.sh:775-792`) or `Log` / `LogError` / `LogDetail` (`aitools-lib.ps1:656-674`). No raw `echo`, `printf` or `Write-Host` logging was added. The new `printf`s are the tab constant (`.sh:289`) and the `/dev/tty` prompts (unchanged, `.sh:252-254`).
- [x] **Every new log_error / LogError is counted and paired with an ERROR row** in the same block:
  - `.sh:88/89`, `.sh:291/292`, `.sh:307/308`
  - `.ps1:82/83`, `.ps1:228/229`, `.ps1:240/241`
  - Counting: `log_error` increments `ERRORS` (`aitools-lib.sh:787`) and `LogError` increments `$script:errors` (`aitools-lib.ps1:668`). The exit footers (`.sh:346-355`, `.ps1:318-327`) are unchanged, so these paths exit 1.
- [x] **write_summary on every new code path**:
  - fan-out: OK `skills` n/a (`.sh:62`, `.ps1:56`)
  - fan-out with resolver error: + ERROR `skills` (`.sh:89`, `.ps1:83`)
  - fan-out with harness dir or manifest unreadable: + ERROR `skills` (`.sh:292,308`, `.ps1:229,241`)
  - fan-out with no dotprofile: OK `skills` n/a only (`.sh:336`, `.ps1:262`)
  - fallback: the claude/cursor skills rows, unchanged (`.sh:192-217`, `.ps1:187-212`)
  - The WARN "no skills found" is correctly suppressed in fan-out mode (`.sh:133`, `.ps1:124`).
  - When OK `skills` and ERROR `skills` are both written, the renderer keeps the ERROR (`aitools-lib.sh:3348-3367`, `aitools-lib.ps1:3478-3506`: highest severity wins), so the error is not hidden.
- [x] **The n/a row is OK, not WARN and not "skipped"** (`.sh:62`, `.ps1:56`). It is written before any warning can be counted (only logging_init and the DRY_RUN info line come before it), so `write_summary` does not promote it to WARN (`aitools-lib.sh:957`). The script calls `write_summary OK` directly rather than `write_environment_skip`. That is correct here: `write_environment_skip` would emit `n/a (local)` (`aitools-lib.sh:971-975`), and the fan-out is harness state, not an environment. There is precedent for non-environment n/a rows: `n/a (no harness rules)` and `n/a (package)` in `.claude/rules/deploy-paths.md`. Detail length: see N1.
- [x] **No unguarded error suppression added.**
  - There is no new `2>/dev/null`, `|| true`, `-ErrorAction SilentlyContinue` or empty catch.
  - `.sh:305`: `out=$(read_harness_manifest ... 2>&1) || rc=$?` captures the exit code and checks it on the next line (`:306`). `rc=0` is `local` (`:288`).
  - `.ps1:225-231` and `.ps1:237-243` are try/catch blocks whose catch calls LogError, writes the ERROR row and returns `$false`. `Read-HarnessManifest` throws on unreadable, missing or directory input (`aitools-lib.ps1:2674-2676,2686`), so the catch is reachable.
  - `Get-HarnessSkillNames` writes nothing to the success stream: `Log` uses Write-Host, `Write-Summary` appends to a file, and `HashSet.Add` is `[void]`. So `[bool](Get-HarnessSkillNames)` at `.ps1:263` cannot be turned true by stray output.
  - `.sh:297` `[ -e ] || [ -L ] || continue` is control flow, not suppression.
- [x] **sh/ps1 parity: same branches, same rows.**
  - harness check: `.sh:57-63` / `.ps1:51-57`
  - resolver split: `.sh:83-95` / `.ps1:77-89`
  - discovery gates: `.sh:107-136` / `.ps1:104-127`
  - harness-name collection: `.sh:285-330` / `.ps1:224-252` (lower-cased list vs OrdinalIgnoreCase HashSet; dot and backup names excluded by `skill_name_kind` / `Get-SkillNameKind`, `aitools-lib.sh:2654`, `aitools-lib.ps1:2661`)
  - reverse-discovery gate: `.sh:332-341` / `.ps1:257-265`
  - per-entry filter: `.sh:233-236` / `.ps1:272-275`
  - The test compares rows across 8 cases (`test-skills-legacy.sh:276-284`). Log text differences: N5.
- [x] **Block order and header.** The header now names the platform and the `/tool-registry` skill (`.sh:23-24`, `.ps1:23-24`). Then come `set -euo pipefail`, the lib, the OS guard and the body, with the exit footer unchanged (`.claude/rules/script-standards.md` "Block order").
- [x] **build-deploy.sh section.**
  - The section logs through `blog` (`build-deploy.sh:1265,1369`), defined at `:44`/`:45`/`:52` in the `[ts] [script] [level] msg` format with UTC Z. The PR adds no logging calls there.
  - The 4 added lines (`:1313`, `:1359`, `:1408`, `:1456`) are `echo`s of generated code that wrap the embedded deploy in `if [ "$SKILLS_FANNED_OUT" != "true" ]` / `if (-not $skillsFannedOut)`.
  - The gate variable and the n/a row come from the extracted body (`extract_between '^# --- BEGIN skills body' '^# --- BEGIN skill discovery'`, `:1270-1271`, `:1373-1374`), which contains the harness check (`.sh:53-63`, `.ps1:47-57`). The generated script therefore writes the same OK `skills` n/a row and is safe under `set -u`.
  - The ERROR rows inside the gated block are unchanged (`:1341`, `:1355`, `:1438`, `:1454`).
- [x] **test-skills-legacy.sh silent failures.** The rc of every run is captured (`:167`, `:327`) and checked in each case. Cleanup uses a trap (`:50`). If the OS-guard patch (`:113`, `:337`) fails to match, the run would fail visibly rather than silently. Remaining gaps: N4.

## Not covered (out of scope)
- Runtime behaviour, including a dangling-symlink manifest in Windows PowerShell (`Test-Path -LiteralPath` at `.ps1:236` versus `[ -e ] || [ -L ]` at `.sh:303`). That is auditor B's domain; its parity is unknown to this audit.
- The .ps1 path on a real Windows host: the test runs the .ps1 under pwsh on macOS/Linux with the OS guard patched (`test-skills-legacy.sh:113`), and `check.yml` adds no step to the windows job.
