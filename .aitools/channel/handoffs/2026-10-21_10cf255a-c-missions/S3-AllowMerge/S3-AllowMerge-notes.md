# S3-AllowMerge mission notes v1.0 (2026-10-28)

Mission ALLOW-MERGE: live test of the user-scope allow rule
`Bash(gh pr merge:*)` under auto mode. Delegate of Session Commander
10cf255a-c (level 1, Agent tool). Claude Code 2.1.309, macOS.

## Settings confirmed (read-only)

- `~/.claude/settings.json`: `"permissions": {"defaultMode": "default", "allow": ["Bash(gh pr merge:*)"]}`
- dotprofile `profile.json` `claude.settings.permissions`: same values.

## Results

| Step | Command | Exact result |
|------|---------|--------------|
| pre-check #122 | `gh pr view 122 ... --json state,headRefOid,mergeStateStatus,statusCheckRollup` | head 8f644fffcf6e6c634ee09c4959887022d19ba2d2, 8/8 checks SUCCESS, `mergeStateStatus: UNKNOWN` on first read, `CLEAN`/`MERGEABLE` on second |
| merge #122 | `gh pr merge 122 -R nobul-tech/aitools --merge --match-head-commit 8f644fffcf6e6c634ee09c4959887022d19ba2d2` | `(Bash completed with no output)`; MERGED 2026-10-28T17:34:47Z, merge commit d8f0aedda0271fcf450c7595f5fa2b16eee39119 |
| record #122 | `gh pr comment 122 --body-file ...` | https://github.com/nobul-tech/aitools/pull/122#issuecomment-6476109545 |
| main CI | run 40737064303 on d8f0aed | success (29m54s; macOS runner queue) |
| pre-check #120 | `gh pr view 120 ...` | head 1a30fe7f139fb9d313ec332f489e7b19572cc1f5, 8/8 SUCCESS, `CLEAN`/`MERGEABLE` on second read |
| merge #120 | `gh pr merge 120 -R nobul-tech/aitools --merge --match-head-commit 1a30fe7f139fb9d313ec332f489e7b19572cc1f5` | `(Bash completed with no output)`; MERGED 2026-10-28T18:05:35Z, merge commit 1b4e9d7cae8b752a6a3d5355920c8eb791a9435a |
| record #120 | `gh pr comment 120 --body-file ...` | https://github.com/nobul-tech/aitools/pull/120#issuecomment-6476773306 |
| main CI | run 40741876684 on 1b4e9d7 | success (macos 16m52s, linux 7m33s, windows 1m32s) |

Before the rule (MERGE-2, 2026-10-28): "Permission for this action was denied
by the Claude Code auto mode classifier. Reason: [Merge Without Review]."

## Conclusion

The allow rule works: in auto mode, in a sub-agent, a matching
`gh pr merge` resolves at step 1 of the documented decision order and is not
refused. The edit to settings.json was picked up mid-session (documented
settings reload). Findings recorded as item #28 and section "Auto Mode and
Allow Rules for PR Merges (#28)" in `reference/tool-ops-claude-code.md`.

`registries/tool-ops.json` not changed: the `/tool-ops` skill says permission
rules are not in that registry (`denyRules` retired in 15eb5e3); they are
profile-sourced.
