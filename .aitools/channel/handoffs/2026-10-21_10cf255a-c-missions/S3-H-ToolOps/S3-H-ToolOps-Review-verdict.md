# S3-H-ToolOps-Review verdict: PR #85

**Verdict: no blocking findings.** (Posted as a comment review. This is not an approval.)

Reviewer: S3-H-ToolOps-Review (independent delegate of S3-H-ToolOps), 2026-10-22.
Reviewed: `gh pr diff 85`, the PR body, commit e0d2c03, and the full text of both
SKILL.md files in the PR worktree (`feature/harness-tool-ops-fallback`).

## Checklist

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| a | Requirement and contract | PASS | Requirement: "/tool-ops and its skills read ~/.aitools/reference/tool-ops-*.md, falling back to the repo." `.claude/skills/tool-ops/SKILL.md:43-61` and `shared/skills/aitool-ops/SKILL.md:56-75` both put the deployed copy first and the repo copy second. Both say the deployed tree mirrors repo `reference/` with the same relative paths (tool-ops:51-52, aitool-ops:64-65), which matches the S3-Harness brief's shared contract. |
| b | /aitool-ops stays self-contained | PASS | aitool-ops:70 makes the embedded card the third fallback. aitool-ops:72-73 says "Neither file is required: when both are absent, this card is the answer". This meets `.claude/rules/aitool-ops.md` ("No external file references required at runtime"). |
| c | No Intent text changed | PASS | The diff hunks start at tool-ops:40, tool-ops:95, aitool-ops:53 and aitool-ops:334. The Intent blocks are at tool-ops:6-14 and aitool-ops:9-20, so the diff does not touch them. The Intent change exists only as a draft (`S3-H-ToolOps-drafts/S3-H-ToolOps-intent-tool-ops-skill.md`). Its "Old" block matches tool-ops:10-12 word for word. |
| d | Both platforms shown | PASS | tool-ops:49-50 and 55-56, aitool-ops:62-63 and 67-69 give both the `~/` and the `%USERPROFILE%\` form. |
| e | Only the existing `repoPath` key | PASS | The PR adds no new keys. `repoPath` is written by `scripts/setup-user-config.sh:218` and `.ps1:218`, documented at `reference/user-repo.md:115,126`, passed by the installer at `scripts/aitools-install.sh:427`, and present in the live `~/.aitools/config.json:4`. |
| f | Accuracy | PASS (2 low notes) | The Windows default `%USERPROFILE%\repos\aitools\` matches `scripts/aitools-install.ps1:266,275`. "Never edit the deployed copy; write the repo copy" (tool-ops:60-61) fits the contract: deploy-harness deploys each file with ADOPT_PATH set to the repo source (S3-Harness brief), so an edit to the deployed copy is overwritten or sent to review on the next run. See F1 and F2. |
| g | Scope | PASS | Three files: two SKILL.md files and one draft. No scripts, hooks, or files owned by Core, Cursor or M3. |
| h | PR body claims | PASS | Verified: the hook follow-up (`shared/hooks/tool-ops-session-audit.sh:85-88` reads `$AITOOLS_REPO_PATH`, then `~/repos/aitools`, and not `~/.aitools/reference`). Verified: the stale allowlist entry (`scripts/check-path-refs-allow.txt:12` cites `shared/skills/tool-ops/...`, and no `shared/skills/tool-ops/` directory exists). Verified: "only two SKILL.md files" (my own grep for `tool-ops-` over `shared/skills` and `.claude/skills` matched only those two SKILL.md files plus `.claude/skills/tool-ops/tests/expected-behaviors.md:71`, which is a test fixture). Not re-run by me: the pre-commit and pre-push check counts (unknown beyond the author's report). |

## Findings

**F1 (low, non-blocking): /aitool-ops does not repeat the lag caveat, and the "newer" reason is imprecise.**
`shared/skills/aitool-ops/SKILL.md:73-74` says: "When a file and this card disagree, the file wins (it is newer)." The rule itself is right, but the reason is not. The file wins because it is the source the card is derived from, not because it is newer. /tool-ops warns that the deployed copy can lag the repo (tool-ops:58-60), but /aitool-ops does not. An agent in another repo with both copies present would read a deployed copy that may be stale and not know it. Suggested text: "the file wins (it is the source this card is derived from); the deployed copy refreshes only on the next `aitools` run."

**F2 (low, non-blocking, follow-up): the registry read is still repo-only.**
`.claude/skills/tool-ops/SKILL.md:20` still says "Read `registries/tool-ops.json`". The mission packet section 6 says deploy-harness copies registries to `~/.aitools/registries/`. The requirement covers only `reference/tool-ops-*.md`, so this is out of scope here. Add it to the follow-ups if /tool-ops should also use the deployed registry.

**F3 (low, decision for the commander): Intent scope versus the new section.**
tool-ops:10-12 says "CRUD operations on tool-ops.json only ... NOT per-tool ops references". The new section (tool-ops:43-61) tells agents where to read those references. A strict reading puts it outside the stated scope. The author's draft resolves this without changing meaning. I suggest applying it, because a scope that says "only" while the skill does more invites future drift findings (`/intent-audit`).

**F4 (info): MDM path is stale until a rebuild.**
`build-deploy.sh` was not run. The dotprofile `deploy/setup-user-skills.*` therefore still embeds the old /aitool-ops. The PR body discloses this ("Not run") and lists the rebuild as a follow-up.

INCIDENT: (pre-existing, not introduced by this PR) the Windows repos location is inconsistent across files. `.claude/rules/cross-platform.md` says "Repos live under `~/repos/` (macOS) / `C:\repos\` (Windows)". The user CLAUDE.md and `scripts/aitools-install.ps1:266,275` use `%USERPROFILE%\repos`. This PR follows the installer, which is correct. cross-platform.md is the outlier (protected; needs a draft).

## Not run by this reviewer

- `check-pre-commit.sh` and `check-pre-push.sh` (I took the author's results as reported).
- `build-deploy.sh` and any live read of `~/.aitools/reference/` (that directory does not exist until S3-H-Core lands).
- Windows: not tested.
