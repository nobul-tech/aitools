# S3-FanoutImpl-ClaudeSkills hand-back (FO-4)

Version 1.0, 2026-10-27, by S3-FanoutImpl-ClaudeSkills (level 2, delegated by S3-FanoutImpl).

## Summary

- Built contract 3.4 as `fanout_harness_skills` / `Invoke-HarnessSkillsFanout`. It is in both libs, placed after FO-1's helpers, which are unchanged.
- setup-user-claude.sh/.ps1 call it in a new extracted span, `# --- BEGIN/END skills fan-out (extracted by build-deploy) ---`. build-deploy extracts that span, so the MDM copies run it too.
- New suite tests/skills-fanout: 137 pass, 1 skip. claude-mdm has new MDM skills checks. CI steps added.
- Merged into the branch: FO-2 (`origin/feature/fanout-harness-skills`), FO-1 7b7e1fb and FO-3 f897b74, all `--no-ff`.
- Fixed the deploy-harness-mdm forced size-gate test, which fails on FO-3's head (details below).
- PR: https://github.com/nobul-tech/aitools/pull/124. Branch `feature/fanout-claude-skills`, head fcf6edc37f2515dc2a297f7836dc25fdd72c271a.

## Function signature (FO-5 calls it)

```bash
fanout_harness_skills TOOL DEST AITOOLS_REPO DOTPROFILE
# e.g. fanout_harness_skills "cursor skills" "$CURSOR_DIR/skills" "" ""
```

```powershell
Invoke-HarnessSkillsFanout -ToolName <string> -DestDir <string> [-AitoolsRepo <string>] [-Dotprofile <string>]
# e.g. Invoke-HarnessSkillsFanout -ToolName "cursor skills" -DestDir (Join-Path $cursorDir "skills") -AitoolsRepo "" -Dotprofile ""
```

- Return: always 0 (ps: no output). Failures are `log_error` plus an ERROR row, counted in ERRORS / `$errors`.
- `[x]abort` exits 2 from the library.
- It reads `$HOME/.aitools/skills` (ps: `$env:USERPROFILE`, else `$HOME`), honours `DRY_RUN` / `$DryRun`, and works out `<Tool>` for the ACTION rows from TOOL: `claude skills` gives "Claude Code", `cursor skills` gives "Cursor".

## Contract changes (also in the PR body)

1. A retired skill's backup goes to `DEST.bak.<UTC>/<name>/` beside DEST, not to `DEST/<name>.bak.*`. A backup inside DEST would still be loaded as a skill. I observed this from the live `~/.claude/skills` and this session's skill list; I did not verify it against the vendor docs.
2. `backup_dir DEST` is called as the contract says but never copies anything. FO-1's skip rule needs a top-level `*.md`, and a skills directory has none. The protection comes from the per-file backups `deploy_managed_file` makes.
3. The contract leaves the ACTION text for a symlink or file at a skill's name open. I used: `<Tool> skills in <DEST> not updated (a symlink or a file, not a directory the fan-out owns): <names> -- move them aside to get the aitools copy`.
4. The executable bit is copied in both directions (`+x` and `a-x`). The .ps1 does nothing on Windows.

## Verification

Run on macOS under isolated HOMEs:

| Suite | Result |
|---|---|
| skills-fanout | 137 passed, 1 skipped |
| skills-fanout (3.2, `--bash-only`) | 54 passed, 25 skipped |
| rules-fanout | 118 passed |
| rules-fanout (3.2) | 44 passed |
| claude-mdm (bash 5) | 38 passed |
| claude-mdm (3.2) | 38 passed |
| fanout-lib | 358 passed |
| fanout-lib (3.2) | 128 passed |
| managed-files sh / ps | 57 / 39 passed |
| adopt-push sh / ps | 28 / 23 passed |
| profile test-lib | 361 passed |
| deploy-harness | 131 passed |
| deploy-harness-mdm | 67 passed |

- `bash -n` (bash 5 and 3.2), the pwsh parser and the YAML parse all pass.
- check-pre-commit and check-pre-push show only the known FAILs (pre-commit step 6, pre-push step 7).

## Not run

- Windows native.
- The case-only duplicate case (Linux CI only).
- Anything against the real HOME.

## Incidents

- **INCIDENT:** the deploy-harness-mdm check "size gate (forced)" fails on the FO-3 head f897b74 (64 passed, 1 failed; PR #121 linux CI was red). The test pads a dotprofile rule, and FO-3 no longer embeds dotprofile rules in setup-user-claude.sh. FO-4 (fcf6edc) fixes it by padding the CLAUDE.md template instead. The orchestrator was told by SendMessage.
- **INCIDENT:** the contract's DEST backup naming (`DEST/<name>.bak.*`) would leave a retired skill loaded (contract change 1).

## Open questions

- Should FO-1's `backup_dir` skip rule allow skills directories (no top-level `*.md`)? I suggest no. The per-file backups cover every write, and copying a whole `~/.claude/skills` (third-party skills, symlinks) on every run is heavy. FO-7 should document that it does nothing there.
- Should the `DEST.bak.<UTC>` backups be pruned? I suggest keeping them as they are. They appear only on runs that remove a retired skill, and `backup_dir`'s 5-copy pruning matches the same name pattern whenever it does make a backup.

## WRITE_BLOCKED

None.
