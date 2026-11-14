# M3-Fixes-A notes v1.0 (2026-11-13)

Fixes 2 and 3: setup-user-shell is the single, self-repairing owner of the PowerShell
profile and the shell rc integration. Uncommitted in worktree
`.claude/worktrees/console-profile` (branch fix/console-and-profile).

## Files changed
- scripts/setup-user-shell.ps1 -- rewritten: line-based block engine; PATH block + new
  shell-integration block; collapse, stray-marker removal, damage WARN/ACTION with backup
  choice, legacy migration, unchanged = no write/no backup, BOM kept, non-UTF-8 refused.
- scripts/setup-user-shell.sh -- same engine in Perl (temp .pl from a heredoc); bash -n as
  the parse check; rc-file integration moved in from aitools-install.sh (+ backup_file,
  AITOOLS_PROFILE_DIR, AITOOLS_ALIASES_PATH).
- scripts/aitools-install.ps1 / .sh -- Step 7 only runs setup-user-shell (inline $PROFILE /
  rc code deleted; MDM missing-script WARN kept).
- tests/setup-user-shell/test-setup-user-shell.ps1 -- 37 cases (was 8).
- tests/setup-user-shell/test-setup-user-shell.sh -- new, 23 cases; skips on Windows.
- .github/workflows/check.yml -- macOS (bash 5 + /bin/bash 3.2) and Linux steps for the .sh.
- reference/ait-shellintegration.md -- v1.1.

## Design
- Block layout: two marked blocks in $PROFILE (`# >>> aitools managed >>>` PATH,
  `# >>> aitools shell integration >>>` aliases + aitools + hh). Reason: machine-specific
  path vs identical-everywhere block; MDM copy has no aliases file, so the integration
  block must be skippable on its own without touching the PATH block.
- Block = start line to first end line after it (old regex semantics, line-anchored,
  trimmed). First block replaced in place, later ones dropped, stray marker lines dropped
  (they are ours and comments; needed for the "exactly one start + one end" post-check).
- Damage evaluated on what is left on disk (new content; original when the write is
  refused): parse errors > 0 or stray lines (`_aitoolsLocalBin`,
  `Owned by aitools (scripts/setup-user-shell.`, outside our blocks). Not "before the
  write" as the prompt said: the collapse never touches user lines, and reporting on
  the result avoids telling a user to restore a backup over a profile we just fixed.
- Clean backup: names `<profile>.bak.<UTC>` sorted descending (Copy-Item keeps the
  source mtime, so mtime order is wrong -- seen in the real dir); qualifies with <=1
  start and start==end per block kind, 0 parse errors, 0 stray lines (stray check added:
  `_aitoolsLocalBin = Join-Path ...` alone parses with 0 errors). Only backups that
  existed before the run are candidates.
- Legacy migration: marker + following lines of known shape + at most one blank above;
  new block at the first legacy position. MDM: legacy and integration blocks untouched.
- Bash parity: rc logic moved into setup-user-shell.sh unchanged in format (append when
  missing, leave when present, remove ai-tooling pair); one backup per rc per run.

## Evidence
- Real current profile (scratch copy): before 1 block, 0 errors, legacy block; after
  1 PATH + 1 integration block, 0 errors; rows `managed block unchanged`,
  `legacy integration migrated`; second run `unchanged` x2, no write.
- Real corrupted backup 2026-11-13T214623Z (scratch copy, backups as at that time):
  before 84 starts / 85 ends / 135 parse errors / 276 lines with _aitoolsLocalBin;
  after 1/1 + 1 integration block, 85 parse errors, 87 such lines (stray fragments
  outside + 3 in block); rows `collapsed 64 blocks to 1`, `legacy integration migrated`,
  WARN `profile damage left in place`, ACTION Restore ... from ...bak.2026-06-22T221110Z.
- Synthetic fixture: old buggy splice x2 -> 84 starts / 85 ends (same shape), 156 errors.
- ps1 suite 37/0/0; sh suite on guard-stripped mirror (Git Bash 5.3) 23/0/0; native sh
  suite on Windows: SKIP, exit 0; os-guards 33/0/0; isolated build-deploy exit 0,
  generated deploy/setup-user-shell.* pass bash -n / pwsh parser, generated .ps1 run on a
  scratch profile -> OK block added + WARN aliases.ps1 not found.
