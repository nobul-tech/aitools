# S3-MA-Cleanup log v1.0 (mission MERGE-ALL, GitHub cleanup)

**Written:** 2026-10-27T12:15Z · **By:** S3-MA-Cleanup (delegate of MERGE-ALL, Session Commander 10cf255a-c) · **Base:** origin/main 51d895b

## 1. Open PRs: NOT empty

The task assumes every PR has merged. It has not. `gh pr list -R nobul-tech/aitools --state open` at 2026-10-27T12:00Z and again at 12:14Z returned 10 open PRs, all base `main`, all `mergeStateStatus` UNKNOWN (GitHub has not computed it):

| PR | Branch | Title (short) |
|---|---|---|
| #117 | feature/fanout-ci | FO-0: run every passing test suite in CI |
| #118 | feature/fanout-lib | FO-1: fan-out lib helpers |
| #119 | feature/fanout-harness-skills | FO-2: deploy-harness skills manifest |
| #120 | feature/fanout-size-warn | FO-0b: oversized generated scripts as WARN |
| #121 | feature/fanout-claude-rules | FO-3: setup-user-claude fans out rules |
| #122 | feature/ddg-agent-workflow | delegation-duty-guard: Agent and Workflow calls |
| #123 | feature/fanout-cursor | FO-5: Cursor fan-out |
| #124 | feature/fanout-claude-skills | FO-4: fan out skills into ~/.claude/skills |
| #125 | feature/fanout-skills-legacy | FO-6: setup-user-skills fallback |
| #126 | feature/fanout-docs | FO-7: reference/skills.md, rules.md |

These are the FAN-PLAN / fan-out PRs. Merging them was not this step's job; the merge step of MERGE-ALL still owes them.

## 2. Remote branches of merged PRs #50-#120: NOT deleted (WRITE_BLOCKED)

`WRITE_BLOCKED: git push origin --delete <branch> for 40 merged, contained branches -- Permission for this action was denied by the Claude Code auto mode classifier. Reason: [Git Destructive].`

Not retried in any other form. Nothing was deleted (`git ls-remote origin` after the denial still lists every branch).

Classification (dry run of `.scratch/session-macleanup/branches.sh`, after `git fetch origin --prune`; rule: PR MERGED, branch on origin, `git merge-base --is-ancestor origin/<branch> origin/main`, not used by an open PR, not main):

**Deletable (40), for the commander to delete or to allow:** #73, #76-#78, #80-#106, #108-#116. Branches: feature/m3-b1-profile-resolver, feature/m3-b1b-tool-exceptions, feature/m3-b3-config-writer, docs/m2-tree-user-repo, feature/m3-b2-lib-wrappers, fix/review-diff-display, feature/m3-b6-user-init, feature/m3-b4-setup-user-claude, fix/m3-review2-fixes, feature/harness-tool-ops-fallback, feature/m3-rekey, feature/harness-cursor-rules, feature/harness-deploy-harness, fix/m3-b3b-installer-review3, feature/m3-b8c-consumers, feature/m3-b8a-consumers, feature/m3-b8b-consumers, feature/harness-mdm, docs/s3-harness-orchestration, feature/m3-b5-build-deploy, docs/m3-protected-drafts, docs/m3-lead-plan, feature/mf-config-no-machine, docs/harness-approved-drafts, feature/harness-rules-manifest, docs/m3-approved-drafts, docs/mf-incidents, fix/mf-dotprofile-adopt-push, docs/mf-audit, docs/m3-approved-intents, feature/harness-hookin, fix/mf-audit-profile-json, fix/mf-audit-consumers, feature/harness-cursor-user-rules, feature/harness-mdm-followups, fix/mf-audit-claude-build, fix/mf-lib-runner-result, fix/mf-audit-config, fix/mf-lib-relay, fix/mf-installer-relay.

A ready script deletes exactly these: `bash /Users/new-jose/repos/aitools/.scratch/session-macleanup/branches.sh --delete` (it re-checks every condition before each delete).

**Kept, not contained in origin/main (rule says keep):**
- #50-#71 (21 branches): merged by squash before the merge-commit decision, so the branch tips are not ancestors of main. Their content is on main as the squash commits (`gh pr list` mergeCommit column).
- #74 feature/user-level-skills (f61d6fc), #75 refactor/retire-reference-cards (2375fea): merged into stale stacked bases (handoff 2026-10-22 D.2); re-landed as #128/#129.
- #79 feature/m3-b3b-installer-config (69b6420): one commit pushed after the merge; the same commit is on main as 97deb5a.

**Kept, not merged:** #107 docs/handoff-10cf255a-c (CLOSED), #117-#120 (OPEN).

**Out of the stated range, not touched:** merged #127-#132 branches (docs/apply-incidents-146, feature/user-level-skills-reland, refactor/retire-reference-cards-reland, fix/merge-followups, fix/build-deploy-backup, docs/v0.74.0-scrub). Suggest the same check for them.

No local worktree was removed (117 entries in `git worktree list`).

## 3. Open issues

14 open at start. Each checked against origin/main 51d895b by `git grep` / `git show` (scripts `.scratch/session-macleanup/verify-*.sh`).

**Closed (4), each with an evidence comment:**

| Issue | Evidence | Fixed by |
|---|---|---|
| #22 truncated output | `scripts/setup-rust.sh:48-54`, `setup-rust.ps1:29-33` log every line as detail; `scripts/aitools:2074-2077`, `aitools.ps1:1968-1971` log full pull output before the 3-line preview | PR #38 (be46ce8), PR #37 (62442cb) |
| #24 `[ ] && log` piped loops | `setup-rust.sh:49-51`, `aitools-lib.sh:2936-2938` use `if [ -n ]; then log; fi` over here-strings; no `do [ .* ] && log` in scripts/ | PR #38 |
| #28 entry-point override clobbered | entry points define no log functions; `scripts/aitools:1555-1559`; `reference/script-standards-detail.md:157-161`; `tests/logging/test-logging.sh:96-99`, `.ps1:102-106` | PR #37 (62442cb) |
| #31 fresh-install settings | `aitools-lib.sh:2840-2852`, `aitools-lib.ps1:2798-2812` create settings.json from the profile without prompts | PR #35 (075c3da) |

Comments: issuecomment-6441418817 (#22), -6441422532 (#24), -6441423133 (#28), -6441423603 (#31).

**Left open (10):**

| Issue | Why |
|---|---|
| #29 EOF at prompts | The lib sites are fixed (`read_tty_choice` `aitools-lib.sh:1579`, `Read-ConsoleChoice` `aitools-lib.ps1:1509`, `Test-InteractiveConsole` :1505; EOF tests in `tests/managed-files/`; PR #35, #68). Still open: `scripts/relay-outbound-prompt.sh:77` bare `read -r choice < /dev/tty`, the same bug class. Close after that one line uses `read_tty_choice`. |
| #27 grep-decided success | `scripts/setup-cursor-ide-mcp.sh:198` still `agent mcp remove`, the PS1 twin `:171` `agent mcp disable` (bash/PS1 mismatch the issue names). The `exit $?` part is fixed. |
| #25, #23, #26 | Large multi-site issues; sample sites fixed (ReadConfigKey Write-Host gone; "could not read config" gone) but not every listed site was verified. |
| #72 PS1 interactive tests skip on Windows | `tests/managed-files/test-managed-files.ps1:248` still skips. |
| #14 brew-only scripts | no apt/dnf path in setup-typst/uv/go/datadog.sh. |
| #19 Linux CI | no `linux-install` job in `.github/`. |
| #21, #10 epics | sub-issues still open. |

## 4. Stale refs (reported, not deleted)

- Local only (not on origin): `refs/mdmpkg/pr106` (0dea75f), `refs/mdmpkg/pr111` (8caa79e), `refs/mdmpkg/pr112` (52821bd), all 2026-10-22, all contained in origin/main. Safe to remove with `git update-ref -d`.
- Remote branches outside this session's PRs, not contained in origin/main: `master` (c421715, 2026-04-05), `aigit-smoke/dd6fbde7-20260523T060352Z` (2026-05-22), `claude/fable-status-q9ch93` (2026-10-05), `claude/great-cray-R3Ne4` (2026-06-01), `claude/tender-goldberg-gae94k` (2026-10-16), `cursor/cloud-env-setup-28cd` (2026-06-21), `cursor/env-setup-agents-md-a271` (2026-05-21), `cursor/rfc-mission-bridge-700b` (2026-05-12), `nobul-grok/consolidated-tools-provenance` (2026-05-16). Each may hold unmerged work: commander decision.
- Remote `feature/m3-rekey-lib` (1c89444): no PR head in the list, contained in origin/main: deletable.
- GitHub `refs/pull/*` are server-managed; nothing to do.

## 5. Open questions (suggested answers)

1. Allow the 40 branch deletions? Suggested: yes; run `branches.sh --delete` yourself, or add an allow rule for `git push origin --delete` in this session.
2. Squash-merged #50-#71 and #74/#75/#79 branches: delete too? Suggested: yes for #50-#71 and #79 (content on main), keep #74/#75 until the re-land is verified on both machines.
3. The 9 non-session remote branches: suggested: review `master` and the `cursor/*` RFC branch, delete the rest.

## INCIDENT markers (not filed)

- INCIDENT: the merge-all brief ordered branch deletion, but auto mode classifies `git push --delete` as Git Destructive, so a delegate cannot do it; the brief did not say so. Prevention: state classifier-blocked actions in mission prompts, or pre-approve them.
- INCIDENT: issues #22, #24, #28, #31 stayed open for 24 days after the PRs that fixed them merged (#35, #37, #38 did not use closing keywords). Detection: a post-merge check that lists open issues named in a merged PR body.
