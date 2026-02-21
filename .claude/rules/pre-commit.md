## Pre-Commit Checklist (this repo)

Before every commit, verify:

### 1. Git identity

Confirm local config: `git config user.name` -> Jose, `git config user.email` -> jose@nobul.tech

### 2. Script syntax validation

For every `.sh` or `.ps1` file being committed:
- Bash: `bash -n path/to/script.sh`
- PS1: On Windows use `[Parser]::ParseFile(...)` (see cross-platform rule for full command). On macOS, if `pwsh` is installed, use `pwsh -NoProfile -Command "[Parser]::ParseFile(...)"`. If pwsh is unavailable, note in commit message.
- If the other platform's scripts can't be validated locally, note in commit message: `(tested: macOS)` or `(tested: Windows)`

### 3. Build freshness

If any file in `scripts/` or `shared/` was modified, run `bash scripts/build-deploy.sh` and include the regenerated `deploy/` in the commit.

### 4. Line endings

`.sh` files must have LF. The Write tool on macOS produces CRLF -- run `sed -i '' 's/\r$//' <file>` on any `.sh` file created or modified by the Write tool.

### 5. Platform note

If `.sh` or `.ps1` files are in the commit, end the commit message with `(tested: macOS)` or `(tested: Windows)`. Pure docs/markdown commits can omit this.

### 6. Executable bit on .sh files

`git ls-files -s '*.sh' | grep -v '^100755'` must return nothing. Fix: `git update-index --chmod=+x <file>`. Especially important for files created on Windows (Windows doesn't set Unix executable bit).

### 7. Install command consistency

If modifying `scripts/setup-*.sh` or `.ps1`, verify install commands match the corresponding entry in `reference/tool-install-sources.md`. Never hardcode install commands from memory.

### 8. Config merge safety

If the commit modifies a setup script that writes JSON config files
(`config.json`, `settings.json`, `cli-config.json`, `mcp.json`):
- Verify the script reads the existing file before writing (no blind `cat >` or
  `ConvertTo-Json | WriteAllText` for shared configs)
- Verify non-managed fields survive a re-run (check the merge logic)
- If the script intentionally overwrites (sole owner), verify the script header
  documents this

### 9. Release notes

If the commit includes new features, bug fixes, or behavioral changes, verify `RELEASE_NOTES.md` has a version entry covering the changes. Omit for docs-only, rule-only, or trivial changes.

### 10. Deploy drift check

If step 3 ran (build freshness), verify no unstaged deploy/ changes remain after staging:
`git diff deploy/` must be empty after `git add deploy/`. Catches forgotten build output.

### 11. User repo changes

If this session modified files in the user dotfile repo (`userRepoPath` from
`~/.aitools/config.json`), commit those changes too. Use a commit
message that references the ai-tooling change (e.g., "Add cursor.cli
preferences to profile"). Skip if `userRepoPath` is not configured or the
repo has no uncommitted changes.
