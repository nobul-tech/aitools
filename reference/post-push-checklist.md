# Post-Push Checklist (this repo)

> **Script**: On macOS: `bash scripts/check-post-push.sh`.
> On Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-post-push.ps1`.
> Always use the platform-native variant. Never run the `.sh` version on Windows.

## Flag disposition

When the audit produces flags:

1. **Fix now** -- quick fixes (release notes update, delete scratch files): address in a follow-up commit
2. **Defer** -- requires planning or user action (e.g., `aitools user init`): add to ROADMAP.md or note in session
3. **Won't-fix** -- known exception: document why inline and move on

## Always (after every push)

### 1. Verify push landed

`git log --oneline origin/main -1` -- confirm the expected commit is on remote.

### 2. Smoke-test deploy scripts

`bash -n deploy/*.sh` -- catches build corruption or stale copies. Fast (<1s).

### 2b. Functional smoke test (when requested or after significant changes)

Run modified setup scripts to verify they work end-to-end. Use the
redirect-and-check pattern from `.claude/rules/smoke-test-pattern.md` —
never parse setup script output inline from the Bash tool.

### 3. MCP config integrity

Read-only check -- no setup scripts, no side effects:
- Verify `chrome-devtools` appears in both `~/.claude.json` and `~/.cursor/mcp.json`
- Verify `--isolated` appears in the chrome-devtools entry in both files
- `grep -l 'chrome-devtools' ~/.claude.json ~/.cursor/mcp.json` + `grep 'isolated' ~/.claude.json ~/.cursor/mcp.json`

If missing, flag for Extensive tier (#15) or manual fix -- do not run setup scripts here.

### 4. CLI entry point + version consistency

`bash scripts/aitools --version` -- confirms the self-update stamp and that
the entry point parses.

Also verify version matches the latest tag:
`git describe --tags --match "v*" --abbrev=0`. A `+N` suffix indicates
unreleased commits -- the version tag step (below) will resolve this after
all checks pass. A clean version (no `+`) should match the tag exactly.

### 5. Session archive readiness

If `~/.claude/settings.json` contains the SessionEnd hook (`session-archive.sh`),
verify `userRepoPath` is set in `~/.aitools/config.json`. If hook is
present but `userRepoPath` is missing, flag as "session archive inactive -- run
`aitools user init`."

---

## Extensive (audits + tests for significant releases)

Run all Always items first, then:

### 6. Full script syntax validation

`bash -n` on every `.sh` in `scripts/` and `deploy/`. On Windows, also
`[Parser]::ParseFile` on every `.ps1`. On macOS, also validate `.ps1`
files -- see `.claude/rules/cross-platform.md` Pre-validation convention for the
full ParseFile command (pwsh is a managed tool).

### 7. deploy/ drift audit

Rebuild and diff:
```
bash scripts/build-deploy.sh
git diff deploy/
```
Any diff means deploy/ was stale at push time. Should be empty.

### 9. Source-of-truth consistency

For each tool in `reference/tool-registry.md`:
- Verify the install command matches what the corresponding `setup-*.sh/.ps1`
  script actually runs.
- Verify all 6 lifecycle fields (Platform Status, Concurrency, Post-Install
  Config, Dependencies, Invocation, Last verified version) are present.
- Verify Platform Status uses 3-platform format (`macOS: ... | Windows: ... | Linux: ...`).
- Verify Last verified version is populated for the current platform (not `pending` indefinitely).

### 10. Protected files inventory

Every file in the `.claude/rules/sources-of-truth.md` protected table exists on
disk. Every file matching the glob patterns (`.claude/rules/*.md`,
`.cursor/rules/*.mdc`, `plans/*.md`) is covered by the table.

### 11. Cross-platform pairing

Every `scripts/setup-*.sh` has a matching `.ps1` (and vice versa). Same for
`deploy/`. Flag unpaired scripts.

### 12. CLAUDE.md limits

`wc -l CLAUDE.md` must be under 200 lines. If over, content must be moved to
`@reference/` imports.

### 13. Reference link audit

Every `@reference/` import in `CLAUDE.md` points to a file that exists.
Every file in `reference/` that is imported is up to date (not stale or
contradicting CLAUDE.md).

### 14. Line ending audit

All `.sh` files in the repo have LF line endings (not CRLF).
`file scripts/*.sh deploy/*.sh shared/hooks/*.sh` -- none should report CRLF.

### 15. MCP config deploy

Full setup script run (heavier than Always #3):
- Run `bash scripts/setup-user-mcp.sh` and `bash scripts/setup-cursor-ide-mcp.sh`
- Verify chrome-devtools has `--isolated` in both `~/.claude.json` and
  `~/.cursor/mcp.json`

### 16. Roadmap freshness

Flag any "In Progress" item in `ROADMAP.md` whose plan file hasn't been
modified in 14+ days. Flag any completed work that's missing from
`RELEASE_NOTES.md`.

### 17. Hook verification

Verify `~/.claude/settings.json` contains the SessionEnd hook entry pointing
to `session-archive.sh`. If `userRepoPath` is set in config, verify the
user repo directory exists.

### 18. Untracked file hygiene

`git status` should show no untracked files that belong in the repo. Flag
any untracked `.md`, `.sh`, `.ps1`, or `.mdc` files that look like they
should have been committed.

### 19. Config merge audit

For each setup script that writes JSON config files, verify it uses
read-then-merge (not blind overwrite). Flag any `cat >` or bare
`WriteAllText` targeting a config file that has non-managed fields.

### 20. Claude Code maintenance review

Check `claude --version` against the "Current version" in
`reference/tool-ops-claude-code.md`. If they differ:
- Update "Current version" in the registry
- Walk CRITICAL items: check upstream GitHub issues (are they still open?)
- Walk HIGH items if the version bump is major (e.g., 2.1 -> 2.2 or 3.0)
- Update "Last verified" for any re-checked items

### 21. Tool version freshness

For each versioned tool in `reference/tool-registry.md`:
- Run `<tool> --version` and compare against the current platform's entry in
  `reference/tool-versions.json`. Flag any tool where installed version differs.
- If different: update `tool-versions.json` for this platform, update `Last verified version`
  in `tool-registry.md`, and review upstream changelog for breaking changes.

For `@latest` / remote tools:
- Check `lastReviewed` in `tool-versions.json`. Flag if older than 30 days.
- Review upstream for changes to flags, config options, or behavior affecting `assumptions`.

### 22. Logging hygiene audit

**22a -- Winget output filtering:**
- Scan all `scripts/setup-*.ps1` for the bad pattern: `$wingetOutput.Trim().Split(...)` piped
  to `ForEach-Object { Log $_.TrimEnd() }` on a single line without a filter guard.
- PASS: No files match the unfiltered pattern.
- FAIL: One or more files still log winget progress characters (`-`, `\`, `|`, `/`) verbatim.

**22b -- Cloud MCP in setup-user-mcp:**
- Verify that `scripts/setup-user-mcp.sh` calls `show_cloud_mcp_status` in its exit section (between `BEGIN exit` and `END exit`).
- Verify that `scripts/setup-user-mcp.ps1` calls `Show-CloudMcpStatus` in its exit section (between `BEGIN exit` and `END exit`).
- PASS: Both source scripts include the call in the exit section.
- FAIL: Missing from one or both source scripts.

### 29. Deployment menu parity audit

Extract interactive menu choice patterns (`[letter]`) from both
`scripts/aitools-lib.ps1` (Prompt-DiffReview) and `scripts/aitools-lib.sh`
(prompt_diff_review). Verify identical choice letters and order in auto-merge
menu and fallback menu. Flag mismatches.

### 30. Return value coverage audit

Extract all return values from `Deploy-ManagedFile` / `deploy_managed_file`.
For each caller file (`setup-user-claude`, `setup-user-mcp`,
`setup-user-hooks`), verify a case/switch branch exists for every return value.
Also verify `Record-DeployOutcome` / `deploy_tracker_record` handles every
value.

### 31. Deployment state machine sync

Verify the return value sets match between PS1 and bash:
- `Deploy-ManagedFile` return values == `deploy_managed_file` MANAGED_FILE_RESULT values
- `Record-DeployOutcome` cases == `deploy_tracker_record` cases

---

## Version tag (after all checks pass)

Runs after the applicable tier (Always or Extensive) completes with no
unresolved flags.

**Note**: `aitools gitpull` enforces this gate automatically -- it will skip
tagging if RELEASE_NOTES.md has no matching entry. The manual tag flow below
provides the same check for commits tagged outside of gitpull.

**Skip if:** `git describe --tags --match "v*" --exact-match HEAD` succeeds
(HEAD is already tagged) or no `RELEASE_NOTES.md` entry was added in this push.

**Steps:**

1. Confirm the latest `RELEASE_NOTES.md` version entry (e.g., `v0.15.1`)
2. Ask the user: **minor bump**, **patch bump**, or **skip**
   - Default suggestion based on release notes: features/tools = minor,
     bug fixes only = patch
3. Verify the chosen tag matches the RELEASE_NOTES.md version. Mismatch = stop
   and resolve before tagging.
4. Create and push the tag:
   ```
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
5. Verify: `aitools --version` should report a clean version (no `+N` suffix)
