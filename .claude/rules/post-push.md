## Post-Push Checklist (this repo)

Two tiers: **Always** runs after every push. **Extensive** runs after significant
releases (new features, structural changes, new tools) or when requested.

### Always (after every push)

#### 1. Verify push landed

`git log --oneline origin/main -1` -- confirm the expected commit is on remote.

#### 2. Smoke-test deploy scripts

`bash -n deploy/*.sh` -- catches build corruption or stale copies. Fast (<1s).

#### 3. MCP config integrity

Run `bash scripts/setup-user-mcp.sh` and `bash scripts/setup-cursor-mcp.sh`.
Verify chrome-devtools has `--isolated` in both `~/.claude.json` and
`~/.cursor/mcp.json`.

#### 4. CLI entry point

`bash scripts/aitools --version` -- confirms the self-update stamp and that
the entry point parses.

---

### Extensive (audits + tests for significant releases)

Run all Always items first, then:

#### 5. Full script syntax validation

`bash -n` on every `.sh` in `scripts/` and `deploy/`. On Windows, also
`[Parser]::ParseFile` on every `.ps1`.

#### 6. deploy/ drift audit

Rebuild and diff:
```
bash scripts/build-deploy.sh
git diff deploy/
```
Any diff means deploy/ was stale at push time. Should be empty.

#### 7. Rule parity audit

Verify the Rule Correspondence table in `reference/cursor-practices.md` is
accurate: every `.claude/rules/*.md` has its documented `.cursor/rules/*.mdc`
counterpart (or is marked Claude Code-specific). Flag missing or orphaned files.

#### 8. Source-of-truth consistency

For each tool in `reference/tool-install-sources.md`:
- Verify the install command matches what the corresponding `setup-*.sh/.ps1`
  script actually runs.
- Verify all 4 lifecycle fields (Platform Status, Concurrency, Post-Install
  Config, Dependencies) are present.

#### 9. Protected files inventory

Every file in the `.claude/rules/sources-of-truth.md` protected table exists on
disk. Every file matching the glob patterns (`.claude/rules/*.md`,
`.cursor/rules/*.mdc`, `plans/*.md`) is covered by the table.

#### 10. Cross-platform pairing

Every `scripts/setup-*.sh` has a matching `.ps1` (and vice versa). Same for
`deploy/`. Flag unpaired scripts.

#### 11. CLAUDE.md limits

`wc -l CLAUDE.md` must be under 200 lines. If over, content must be moved to
`@reference/` imports.

#### 12. Reference link audit

Every `@reference/` import in `CLAUDE.md` points to a file that exists.
Every file in `reference/` that is imported is up to date (not stale or
contradicting CLAUDE.md).

#### 13. Line ending audit

All `.sh` files in the repo have LF line endings (not CRLF).
`file scripts/*.sh deploy/*.sh shared/hooks/*.sh` -- none should report CRLF.

#### 14. Credential / secret scan

Grep the full push diff for patterns: passwords, tokens, API keys, `.env`
contents, hardcoded absolute paths containing usernames.
`git diff origin/main~N..origin/main` (where N = number of pushed commits).

#### 15. Roadmap freshness

Flag any "In Progress" item in `ROADMAP.md` whose plan file hasn't been
modified in 14+ days. Flag any completed work that's missing from
`RELEASE_NOTES.md`.

#### 16. Hook verification

Verify `~/.claude/settings.json` contains the SessionEnd hook entry pointing
to `session-archive.sh`. If `userRepoPath` is set in config, verify the
user repo directory exists.

#### 17. Untracked file hygiene

`git status` should show no untracked files that belong in the repo. Flag
any untracked `.md`, `.sh`, `.ps1`, or `.mdc` files that look like they
should have been committed.
