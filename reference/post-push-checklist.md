# Post-Push Checklist (this repo)

> **Script**: On macOS: `bash scripts/check-post-push.sh`.
> On Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-post-push.ps1`.
> Always use the platform-native variant. Never run the `.sh` version on Windows.

## Flag disposition

When the audit produces flags:

1. **Fix now** -- quick fixes (release notes update, delete scratch files): address in a follow-up commit
2. **Defer** -- requires planning or user action (e.g., `aitools user init`): add to ROADMAP.md or note in session
3. **Won't-fix** -- known exception: document why inline and move on

The script runs every step on every run (`EXTENSIVE=true` is hard-coded; the
`--extensive` / `-Extensive` flag has no effect); the tiers below are a reading
order, not modes.

## Always (after every push)

### 1. Verify push landed

`git log --oneline origin/main -1` -- confirm the expected commit is on remote.

### 2. Smoke-test deploy scripts (retired)

Always SKIP (`retired: check-pre-push step 7 rebuilds into a temp dotprofile
copy`). The step ran `bash -n` on the aitools `deploy/*.sh`, which is frozen:
`build-deploy.sh` has written the generated scripts to `<userRepoPath>/deploy/`
(the dotprofile build output) since 2c0fd32 (2026-06-14), so the step proved
nothing about them. Before PR #154 it, and steps 6 and 14, still read the
frozen tree (incident #176); no step reads it now
(`tests/check-post-push/test-post-push-deploy-steps.sh`).

What checks the generated scripts instead: check-pre-push step 7, on every
push, rebuilds them into a temporary copy of the dotprofile under a temporary
HOME. The build fails on a generated `.ps1` that does not parse (where pwsh is
installed), and the step dry-runs the three resolver consumers
(`setup-user-claude`, `-settings`, `-cursor`). It does not run `bash -n` on
every generated `.sh` or audit their line endings: that is not covered, as it
was not covered by the frozen-tree check either.

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

`bash -n` on every `.sh` in `scripts/` and `shared/hooks/`, and
`[Parser]::ParseFile` on every `.ps1` in `scripts/` (on macOS and Linux
through pwsh, a managed tool: FAIL when it is missing; see
`.claude/rules/cross-platform.md` Pre-validation convention for the command).
The source scripts only: the frozen aitools `deploy/` is not read (step 2).

### 7. deploy/ drift audit (retired)

Always SKIP (`retired: check-pre-push step 7 rebuilds into a temp dotprofile
copy`). The shared `aitools/deploy/` is frozen. Drift of the dotprofile
`deploy/` is checked by pre-push step 7 (a rebuild into a temporary copy of the
dotprofile under a temporary HOME), which runs on every push when a dotprofile
is configured (it SKIPs without one and WARNs without node or Git Bash). Do not run
`build-deploy.sh` here: with the real HOME it replaces the real dotprofile
`deploy/`. Until v0.77.2 both scripts ran `build-deploy.sh` with the caller's
HOME and then `git diff deploy/` on the frozen aitools tree, so the step always
passed and rebuilt the real dotprofile as a side effect; the step no longer
runs it (`tests/check-post-push/test-post-push-step7.sh`).

### 9. Source-of-truth consistency

The script counts registry tools that have `lifecycle.platformStatus` (WARN when
it cannot read any). The deeper checks (install command vs setup script, every
lifecycle field, per-platform status values) are manual: run them through the
`/tool-registry` skill.

### 10. Key files inventory

The script checks that 8 key source-of-truth files exist (`registries/tool-registry.json`,
`reference/tool-evaluation-criteria.md`, `reference/tool-evaluation-playbook.md`,
`CLAUDE.md`, `shared/claude-shared.md`, `ROADMAP.md`,
`reference/tool-ops-claude-code.md`, `reference/user-repo.md`). The list is
hardcoded in both scripts.

### 11. Cross-platform pairing

Every `scripts/setup-*.sh` has a matching `.ps1` (and vice versa). Flag
unpaired scripts.

### 12. CLAUDE.md limits

`wc -l CLAUDE.md` must be under 200 lines. If over, content must be moved to
`@reference/` imports.

### 13. Reference link audit

Every `@reference/` import in `CLAUDE.md` points to a file that exists
(existence only; CLAUDE.md has no `@reference/` imports today).

### 14. Line ending audit

Every `.sh` in `scripts/` and `shared/hooks/` has LF line endings (not CRLF);
the frozen aitools `deploy/` is not read (step 2). By hand:
`file scripts/*.sh shared/hooks/*.sh` -- none should report CRLF.

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

For each versioned tool in the tool registry (`/tool-registry` skill):
- Run `<tool> --version` and compare against the current platform's
  `versions.<platform>.lastVerifiedVersion`. Flag any tool where installed version differs.
- If different: update that platform's `lastVerifiedVersion` and `lastVerified` via the
  `/tool-registry` skill, and review upstream changelog for breaking changes.

For `@latest` / remote tools (MCP servers):
- Check `mcpServers.<name>.versions.lastReviewed` in the registry. Flag if older than 30 days.
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

### 17b. Hook schema validation

Validates the hook entries in `~/.claude/settings.json` (node). SKIP when
settings.json is missing or node is unavailable.

### 23. Script standards compliance

Runs `scripts/check-script-compliance.sh`; FAIL when any of its checks fails,
SKIP when the script is missing.

### 24. Summary panel DETAIL support

Verifies the `DETAIL` summary category exists in the lib and the scripts.

### 25. CLI tools table sync

Compares the registry's invocation commands with the Managed CLI Tools table in
`shared/claude-shared.md`; WARN lists the commands missing from the table.

### 26. Deploy scripts list sync

Looks for a `build-deploy.sh ... generates` line in `CLAUDE.md`. CLAUDE.md has
none today, so the step always SKIPs ("could not find deploy reference in
CLAUDE.md") until the list returns or the step is retired.

### 27. Build prerequisites installed

When cargo is installed, verifies the build prerequisites are present; WARN
names the missing ones.

### 28. Deploy state integrity (retired)

Always SKIP: managed files keep no deploy state.

### 29. Deployment menu parity audit

Runs `scripts/check-menu-parity.pl` (perl; SKIP when perl is missing) on
`scripts/aitools-lib.sh` and `scripts/aitools-lib.ps1`, two comparisons:

- **Menu lines**: the `[letter]` printed by each `printf` (bash) and
  `[Console]::Write` / `WriteLine` (PowerShell) menu line, as one sorted set
  per file.
- **Prompts** (since v0.77.2): the prompt passed to each `read_menu_choice`
  (its PROMPT argument) and `Read-MenuChoice` (`-Prompt`) call, such as the
  AI-merge preview's `[y]es / [r]efine / [n]o`. Its `[x]` letters and
  `[a/b/c]` lists make one set per call; the two files' lists of sets must
  match. A prompt in a variable takes the literal assigned to it earlier in
  the file; a prompt built at run time counts as `?`.

Order is not compared. FAIL prints what differs (e.g. `prompts only in bash:
[q,r,y]`). The script header lists the blind spots; tests:
`tests/check-post-push/test-menu-parity.sh`.

### 30. Return value coverage audit

For the inline-handling caller (`setup-user-claude.sh`), verify every
`MANAGED_FILE_RESULT` value appears. Skills, hooks, rules and harness files
delegate to `deploy_tracker_record`, covered by step 31.

### 31. Deployment state machine sync

Verify the return value sets match between PS1 and bash:
- `Deploy-ManagedFile` return values == `deploy_managed_file` MANAGED_FILE_RESULT values
- `Record-DeployOutcome` cases == `deploy_tracker_record` cases

### 32. Hook-registration parity audit

`shared/hooks/hooks-manifest.json` is the single source of truth for hook
registration (`hooks`: file + event + matcher) and for deploy-only helper
files (`deploy`: e.g. Python siblings and `ait-harvest.py`). The step runs
`scripts/check-hook-parity.py` (python3, or python as fallback) against four
files and verifies that each stays manifest-driven:

- `scripts/setup-user-hooks.sh`: reads `hooks-manifest.json` and registers
  hooks through the node block's manifest loop (`for (const r of regs)`). No
  hardcoded `mergeHookEntry('<event>', '<file>'...)` calls.
- `scripts/setup-user-hooks.ps1`: reads `hooks-manifest.json` and registers
  hooks through `foreach ($r in $regs)`. No hardcoded
  `MergeHookEntry "<event>" "<file>"` calls.
- `scripts/build-deploy.sh`: its hook preflight (required-file check) and both
  embed loops (`deploy/setup-user-hooks.sh` and `.ps1`) read their file lists
  from the manifest, so no manifest-listed hook or helper filename appears
  literally outside comments. Full-line comments are ignored, and names match
  as whole tokens, so a comment that mentions a hook passes.

PASS: all four files are manifest-driven. FAIL: a check failed (the output
names it, e.g. `build-deploy: hardcoded hook filename(s) resurfaced [...]`).
SKIP: a file is missing or python is unavailable. The same audit runs in CI
(Linux job, "Hook-registration parity audit").

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
