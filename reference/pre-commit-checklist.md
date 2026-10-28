# Pre-Commit Checklist (this repo)

> **Script**: On macOS: `bash scripts/check-pre-commit.sh` (or `--fix`).
> On Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-pre-commit.ps1` (or `-Fix`).
> Always use the platform-native variant. Never run the `.sh` version on Windows.

Before every commit, verify:

## 1. Git identity

Confirm local config: `git config user.name` -> Jose, `git config user.email` -> jose@nobul.tech

## 2. Script syntax validation

For every `.sh` or `.ps1` file being committed:
- Bash: `bash -n path/to/script.sh`
- PS1: See `.claude/rules/cross-platform.md` Pre-validation convention for the full ParseFile command. Note: `$e` must be declared before `[ref]$e` -- undeclared variables cause `[ref]` to error.
- If the other platform's scripts can't be validated locally, note in commit message: `(tested: macOS)` or `(tested: Windows)`

## 3. Build freshness

**Build freshness (dotprofile)**: if `scripts/` or `shared/` changed, the dotprofile `deploy/` may be stale. Do not run `--fix` from an agent: it runs `build-deploy.sh` against the real HOME (the shared `aitools/deploy/` is frozen and is not rebuilt). Verify with pre-push step 7, which rebuilds into a temporary copy.

## 4. Line endings

`.sh` files must have LF. The Write tool on macOS produces CRLF -- run `sed -i '' 's/\r$//' <file>` on any `.sh` file created or modified by the Write tool.

## 5. Platform note

If `.sh` or `.ps1` files are in the commit, end the commit message with `(tested: macOS)` or `(tested: Windows)`. Pure docs/markdown commits can omit this.

## 6. Executable bit on .sh files

`git ls-files -s '*.sh' | grep -v '^100755'` must return nothing. Fix: `git update-index --chmod=+x <file>`. Especially important for files created on Windows (Windows doesn't set Unix executable bit).

## 7. Install command consistency

If modifying `scripts/setup-*.sh` or `.ps1`, verify install commands match the corresponding entry in the tool registry (`/tool-registry` skill). Never hardcode install commands from memory.

## 8. Config merge safety

If the commit modifies a setup script that writes JSON config files
(`config.json`, `settings.json`, `cli-config.json`, `mcp.json`):
- Verify the script reads the existing file before writing (no blind `cat >` or
  `ConvertTo-Json | WriteAllText` for shared configs)
- Verify non-managed fields survive a re-run (check the merge logic)
- If the script intentionally overwrites (sole owner), verify the script header
  documents this

## 9. Release notes

If the commit includes new features, bug fixes, or behavioral changes, `RELEASE_NOTES.md` **must** have a version entry covering the changes. `aitools gitpull` will refuse to tag without one. Omit for docs-only, rule-only, or trivial changes that won't be tagged.

## 10. Deploy drift check

Retired for aitools in practice (`aitools/deploy/` is frozen, so `git diff deploy/`
there can only be empty); the script still runs it. The dotprofile `deploy/` is
checked by pre-push step 7.

## 11. User repo changes

If this session modified files in the user dotfile repo (`userRepoPath` from
`~/.aitools/config.json`), commit those changes too. Use a commit
message that references the aitools change (e.g., "Add cursor.cli
preferences to profile"). Skip if `userRepoPath` is not configured or the
repo has no uncommitted changes.

## 12. Template sync

If `shared/claude-shared.md` was modified, also update the user repo template
(`<userRepoPath>/claude/CLAUDE.md`) with the same changes. The user repo copy
takes priority at runtime -- a stale copy means dev/repo deployments miss the update.

## 13. Deploy template logic sync

If the commit modifies `scripts/setup-user-claude.*`, `scripts/setup-user-cursor.*`,
`scripts/setup-user-mcp.*`, or `scripts/setup-user-hooks.*` AND does NOT modify
`scripts/build-deploy.sh`, this is a **warning** (not a block): only
`setup-user-hooks` still has logic duplicated in `build-deploy.sh` (hook embedding,
REGS_JSON); the other three are extracted at build time, so for them the warning
only means "rebuild and check pre-push step 7". See
`.claude/rules/deploy-paths.md` "Scripts with deploy templates".

This check is a heuristic -- not all `scripts/` changes need template updates (e.g.,
comments, variable renames that only exist in the scripts/ flow). But logic changes
(merge functions, validation, error handling) almost always do.

## 14. Build prerequisite framework

Every `scripts/setup-*.sh/.ps1` that runs `cargo install` (not `--list`) calls
`check_build_prereqs` / `diagnose_build_failure` (`Check-BuildPrereqs` /
`Diagnose-BuildFailure`). FAIL.

## 15. Deprecated summary terms

No `write_summary ... "unchanged"` outside check scripts (use `verified`). FAIL.

## 16. Capability bypass

No governed registry JSON path (`glossary`, `framework-registry`, `incidents`,
`tool-registry`, `tool-ops`) in `.claude/rules/`, `.cursor/rules/` or `CLAUDE.md`,
outside Markdown table rows. FAIL.

## 17. Hook portability

`shared/hooks/*.sh` has no `stat -f ... || stat -c` chain, unguarded
`stat -f` / `date -d`, `find -printf` or `grep -P`. FAIL.

## 18. Python syntax

`py_compile` on staged `.py` files. FAIL.

## 19. Harness DB schema

`reference/harness-db-schema.sql` exists. FAIL.

## 20. Path references

`scripts/check-path-refs.py`: every repo path cited in skills, rules, Cursor rules,
reference docs, hooks and CLAUDE.md exists (allow list
`scripts/check-path-refs-allow.txt`). FAIL.

## 21. Skill levels

`scripts/check-skill-levels.py`: no skill name in two of `shared/skills`,
`.claude/skills`, dotprofile `claude/skills`. FAIL.
