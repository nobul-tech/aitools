# S3-H-ToolOps handback

## Summary
1. /tool-ops (`.claude/skills/tool-ops/SKILL.md`) and /aitool-ops (`shared/skills/aitool-ops/SKILL.md`) now look for `reference/tool-ops-*.md` in this order: the deployed copy `~/.aitools/reference/` (`%USERPROFILE%\.aitools\reference\`), then the aitools repo copy.
2. /aitool-ops falls back to its embedded snapshot as the third option, so it still works when `~/.aitools/reference/` does not exist.
3. The repo fallback uses the existing `repoPath` key in `~/.aitools/config.json`, defaulting to `~/repos/aitools/` (`%USERPROFILE%\repos\aitools\`). No config keys were added.
4. No Intent text was changed. An optional /tool-ops Intent scope change is in a draft that awaits approval.
5. The independent reviewer found no blocking issues. I applied its F1 wording fix. F2-F4 are follow-ups.

- PR: https://github.com/nobul-tech/aitools/pull/85
- Branch: `feature/harness-tool-ops-fallback` (base main)
- Reviewer verdict: https://github.com/nobul-tech/aitools/pull/85#pullrequestreview-5620712430 (COMMENTED). The verdict file is `S3-H-ToolOps-Review-verdict.md` in this folder.

## Files changed
- `.claude/skills/tool-ops/SKILL.md`: new subsection "Per-tool ops references (where to read them)". "Adding a new tool" step 7 now says to write the reference in the repo. Updated the cross-reference line.
- `shared/skills/aitool-ops/SKILL.md`: new subsection "Reading the current source" (deployed copy, then repo, then this card). Updated the cross-reference line.
- `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H-ToolOps/S3-H-ToolOps-drafts/S3-H-ToolOps-intent-tool-ops-skill.md`: the Intent draft (not applied).
- This handback and the reviewer verdict.

## Grep hits for `tool-ops-` in skills, hooks, scripts and tests (worktree at origin/main 15cc56a)

In scope (changed):
- `shared/skills/aitool-ops/SKILL.md:48` (staleness note), `:86` (hook name only, not a path), `:337` (cross-reference)
- `.claude/skills/tool-ops/SKILL.md:98` (create step), `:105` (cross-reference)

Out of scope (reported, not changed):
- `.claude/skills/tool-ops/tests/expected-behaviors.md:71`: test fixture. It could gain a read-order case.
- `shared/hooks/tool-ops-session-audit.sh:85-88`: reads `tool-ops-claude-code.md` from `$AITOOLS_REPO_PATH`, then `~/repos/aitools`. It does not check `~/.aitools/reference/`. Follow-up.
- `shared/hooks/tool-ops-session-audit.sh:2,4,34` and `shared/hooks/hooks-manifest.json:11`: hook name and log name, not reference paths.
- `scripts/check-post-push.sh:240,439` and `scripts/check-post-push.ps1:280,509`: repo checks. They should read the repo copy, so no change.
- `scripts/setup-google-chrome.sh:4`, `.ps1:4`, `scripts/setup-cursor-ide-mcp.sh:18`, `scripts/setup-user-mcp.sh:15`: comments only.
- `scripts/check-path-refs-allow.txt:11-12,36-37`: allowlist. Line 12 cites `shared/skills/tool-ops/tests/expected-behaviors.md`, which does not exist (`ls shared/skills` shows no `tool-ops`). The entry is stale.

Open PRs: none of the open PRs (#80-#84) touches either skill. #81 touches `shared/skills/delegate/SKILL.md`, which has no `tool-ops-` path hit.

## build-deploy
`scripts/build-deploy.sh:1040-1233` embeds every `shared/skills/*` into the dotprofile `deploy/setup-user-skills.sh/.ps1`. After merge, run a rebuild under an isolated HOME so the MDM path gets the new /aitool-ops. `.claude/skills/tool-ops` is project-level and is not embedded.

## Verification
- `bash scripts/check-pre-commit.sh` (staged): 8 PASS, 10 SKIP, 2 WARN, 1 FAIL.
  - Step 16 (capability bypass) PASS.
  - Step 20 (path references) PASS.
  - Step 6 FAIL: pre-existing.
  - Step 3 WARN: build freshness, because build-deploy was not run.
  - Step 11 WARN: uncommitted changes in the dotprofile repo, not mine.
- `bash scripts/check-pre-push.sh`: 6 PASS, 1 SKIP, 2 WARN, 1 FAIL. Step 7 FAIL is pre-existing (dotprofile deploy/ stale).
- I spot-checked one reviewer claim: `scripts/aitools-install.ps1:266,275` defaults to `Join-Path $env:USERPROFILE "repos"`. Confirmed.

## Not run
- `build-deploy.sh`: it needs an isolated HOME.
- A live read of `~/.aitools/reference/`: the directory does not exist until S3-H-Core's deploy-harness lands.
- Windows: not tested (docs-only).

## WRITE_BLOCKED
None.

## INCIDENT markers (not filed)
- INCIDENT: (from the reviewer, pre-existing) `.claude/rules/cross-platform.md` puts Windows repos at `C:\repos\`. The user CLAUDE.md and `scripts/aitools-install.ps1:266,275` use `%USERPROFILE%\repos`. The rule is protected, so the fix must be a draft.
- INCIDENT: (low) `scripts/check-path-refs-allow.txt:12` is a stale allowlist entry for a path that does not exist.

## Open questions, with suggested answers
1. Apply the /tool-ops Intent draft? I suggest yes (reviewer F3). The current scope says "NOT per-tool ops references", and the skill now tells agents where to read them.
2. Should /tool-ops also read `~/.aitools/registries/tool-ops.json` first (reviewer F2)? I suggest no for now. In the aitools repo the working-tree registry is the one you edit. Revisit if /tool-ops is ever deployed for use outside the repo.
3. Should `tool-ops-session-audit.sh` check `~/.aitools/reference/` first? I suggest yes, in a separate hook PR after deploy-harness merges.

## Delegates used
- S3-H-ToolOps-Review (level 3, general-purpose, no isolation): it posted the review linked above.
