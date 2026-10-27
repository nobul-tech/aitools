VERDICT: APPROVE

Independent review of #119 (FO-2, deploy-harness skills manifest), head `f0e2c7d`, diff `git diff d7f6855...f0e2c7d` (4 files: `scripts/deploy-harness.sh`, `scripts/deploy-harness.ps1`, `tests/deploy-harness/test-deploy-harness.sh`, `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`). Reviewer: S3-FanoutImpl-Review119. I judged the code against `plans/skills-and-rules-fanout.md` v1.0 sections 1, 3.2 and FO-2. I did not read the author's notes.

## Contract 3.2: met

- Path, header, `<name><TAB><source>`, byte-order sort, LF with no BOM, sources `shared|aitools|dotprofile|retired`, winner recorded, names written as found on disk: met (probe P0; suite checks).
- Name rule: no `/` or `\`, no leading `.`, no `.bak.`. The planner enforces it for previous lines (sh `harness_manifest_plan`, ps1 `Get-HarnessManifestPlan`). Deploy now skips hidden and `*.bak.*` skill dirs (sh:262, ps1:250). The PR body declares this as an addition.
- Listing is tracked per kind (`<kind><TAB><label>` / `"<kind>|<label>"`), and only a listed source retires a name. A missing dotprofile `claude/skills` returns before `LISTED` is written (sh:216-218), so dotprofile skills are kept while dotprofile rules are still listed (probe P6, suite "per kind").
- A retired skill is retired with `backup_dir` / `Backup-Dir`. The new backup is found by a literal prefix match and compared with the directory (`diff -r -q` / SHA-256 per file); only then is the directory removed and re-checked. Any failure gives log_error, an ERROR row, and the directory is kept.
- The preserved scan ignores both manifests (and their `.tmp`) and every path with a `*.bak.*` component (sh:665, ps1 same).
- `add_source skills "dotprofile/skills" ...` sits inside the `DOTPROFILE` block, and the MDM parser picks it up unchanged (the MDM suite passes once the size gate is raised; see below).
- Section 5b is generalised into one planner and one writer per language, not copied. The rules output is unchanged: the rules cases pass.
- sh/ps1 parity: identical in every probe I ran (P0-P6, both languages), and the suite's trace-parity check passes. `.ps1` stays CRLF (709/709 lines). Error handling: every new suppression is checked (`Get-Item -ErrorAction SilentlyContinue` has a comment and a null check; the `2>` captures are read back; `bak=""` has a commented fallback; catches log).

## Blocking findings

None.

## Non-blocking findings

1. **A retired skill dir with no top-level `*.md` gets stuck: ERROR and exit 1 on every run, with a misleading message.** `backup_dir` / `Backup-Dir` skip a directory with no top-level `*.md` without saying so (lib), so `retire_skill_dir` reports `backup failed (no new <name>.bak.* directory)` (sh:551/562, ps1:538 and its twin message). Deploy still accepts such a dir as a skill. Probe P5: `shared/skills/nomd/a/x.md` deploys, then after removal every run is `ERROR|harness files|retire failed: nomd`, rc=1, in both languages. Suggest one of three fixes:
   - (a) do not treat a dir without a top-level `SKILL.md` / `*.md` as a skill at deploy time;
   - (b) back it up with `cp -R` / `Copy-Item -Recurse` directly in `retire_skill_dir`;
   - (c) give `backup_dir` a result flag (FO-1) and name the real cause in the message.
2. **A partial backup is left behind and looks real.** When `cp -R` fails part-way (probe P4: one unreadable file), `backup_dir` only warns and leaves an incomplete `s2.bak.<UTC>/`. The verification catches it correctly (kept, ERROR row, removed on the next good run), but the incomplete directory stays and counts toward the 5-backup retention. Suggest logging that directory as incomplete, or removing or renaming it when the comparison fails.
3. **`.bak.` is matched case-sensitively in one place and case-insensitively in others.** Deploy (sh:262 `case`, ps1:250 `-clike`) and the manifest name rule are case-sensitive. The preserved scan (sh:665 `/i`) and FO-1's planned `skill_name_kind` (plan 3.3, "case-insensitive") are not. Result: a skill named `x.BAK.y` is deployed and listed, but FO-4 would skip it as a backup. Align when FO-1 lands.
4. **A non-directory carrying a retired skill name warns every run with no summary row.** sh:614 / ps1:617 call log_warn only, while script-standards says every path writes a summary row. Minor.
5. **Library prune issues, pre-existing and out of scope, but reached through this path.**
   - bash `backup_dir` prunes with `find -name "<name>.bak.*"`, which is a glob. Backups of a skill named with `[ ]` are never pruned (seen: P3 created the backup; the prune pattern cannot match it literally).
   - A `*` or `?` in a name could prune another skill's backups. I reasoned this from the code; I did not run it.
   - `Backup-Dir` prunes with `-Filter` and `Remove-Item <path>` (wildcard).
   - Fix in FO-1 lib scope.
6. **Docs drift (FO-7).** In `reference/harness.md`, the "Deployed harness" table still lists only `shared/skills` and `.claude/skills` as skills sources, and "No deletion" is no longer true for retired rules and skills.

## What I ran (macOS, isolated HOME only)

- `tests/deploy-harness/test-deploy-harness.sh`:
  - bash 5.3.15: **113 passed, 0 failed**
  - `/bin/bash` 3.2.57 first on PATH: **113 passed, 0 failed**
  - the `.sh`/`.ps1` skills trace-parity check passes in both runs.
- `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` on the PR head: **10 passed, 56 failed**. Every failure comes from the known size gate (`deploy/deploy-harness.ps1 is 210015 bytes, over the Intune script limit (200000)`). This is not this PR's to fix; FO-0b fixes it.
- The same MDM suite on a throwaway clone of `f0e2c7d` with the gate raised (clone only; nothing pushed, the PR's code not edited): **65 passed, 1 failed**. The one failure is the size check. Both passes I needed are there: "dotprofile skill embedded and deployed by MDM (nested file)" and "skills manifest written by MDM, same as dev, lists the dotprofile skill".
- `bash -n scripts/deploy-harness.sh`: OK. PowerShell parser on `scripts/deploy-harness.ps1`: OK.
- My own probes, each run by `.sh` and `.ps1` (pwsh, OS guard disabled in a temp copy), with identical results:
  - **P0**: skill names with `[ ]` and spaces (`my [x] skill/sub dir/n.md`) are deployed and listed as found.
  - **P1**: nested `SKILL.md.bak.<ts>` and `tests/old.bak.1/x.md` inside a deployed skill are not reported as preserved.
  - **P2**: moving `.claude/skills/mv1` to `shared/skills/mv1` between runs flips the source to `shared`, retires nothing and makes no backup.
  - **P3**: retiring the `[ ]` skill and a skill holding nested backups: both are backed up intact (nested `*.bak.*` included) and removed, with DETAIL rows.
  - **P4**: a retired skill with an unreadable file: the partial backup is detected, ERROR row, rc=1, directory kept. The next run, with permissions fixed, removes it.
  - **P5**: retired skill dir with no top-level md: finding 1.
  - **P6**: dotprofile rules listed, dotprofile `claude/skills` missing, manifest has `dk<TAB>dotprofile`: kept, line kept.

Not run: Windows, `check-pre-commit`, `check-pre-push` (the author's job; not needed for the verdict), CI (FO-0).
