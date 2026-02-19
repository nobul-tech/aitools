## Pre-Commit Checklist (this repo)

Before every commit, verify:

### 1. Git identity

Confirm local config: `git config user.name` -> Jose, `git config user.email` -> jose@nobul.tech

### 2. Script syntax validation

For every `.sh` or `.ps1` file being committed:
- Bash: `bash -n path/to/script.sh`
- PS1 (Windows only): `[Parser]::ParseFile(...)` (see cross-platform rule for full command)
- If the other platform's scripts can't be validated locally, note in commit message: `(tested: macOS)` or `(tested: Windows)`

### 3. Build freshness

If any file in `scripts/` or `shared/` was modified, run `bash scripts/build-deploy.sh` and include the regenerated `deploy/` in the commit.

### 4. Line endings

`.sh` files must have LF. The Write tool on macOS produces CRLF -- run `sed -i '' 's/\r$//' <file>` on any `.sh` file created or modified by the Write tool.

### 5. Platform note

End the commit message with `(tested: macOS)` or `(tested: Windows)`.
