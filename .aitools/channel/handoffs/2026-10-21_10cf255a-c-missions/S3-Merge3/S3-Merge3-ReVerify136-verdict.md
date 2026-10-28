VERDICT: MERGEABLE

**PR #136** (fix/tool-ops-path-ref -> main). Head reviewed: `62d22f5ede75e203517520f6899258fbea39777c`. Its parent is the main tip `5e13ef7`, so the branch is current with main.
Reviewer: S3-Merge3-ReVerify136, an independent level-2 delegate of S3-Merge3, mission MERGE-3. I did not write this change. Version 1.0, 2026-10-28.

This is the first review of the PR. No earlier verdict or PR comment existed.

Authority: the commander's order of 2026-10-28, "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise." Applied here, "learn from past mistakess" meant three things. I re-read `mergeStateStatus` instead of trusting the first read. I checked the fix against the checker's own documented intent instead of the author's claim. I probed the allowlist entry for over-allowing instead of assuming it was narrow.

## Blocking findings

None.

## Non-blocking findings

1. **The allowlist header's category list leaves out "convention".** `scripts/check-path-refs-allow.txt` lines 3-4 say: "Add an entry only for a fixture, an example, history, or a planned file; fix a stale path instead of listing it." The new entry is in none of those categories. The file already has a `# Conventions, not repo paths` section (line 36), and its precedent is `reference/cursor-practices.md|.cursor/skills/` (line 37). The new entry fits that established practice, but the header text has drifted from it. Suggested follow-up: add "or a convention (a path that means a location in any folder, not in this repo)" to the header. This PR does not need to do it.
2. **The entry applies to the whole file, not to one line.** The checker matches `(citing file, cited path)` exactly (`scripts/check-path-refs.py:181`, `(r[0], r[2]) not in allow`). Every current and future backticked `.claude/settings.json` in `reference/tool-ops-claude-code.md` passes. This is acceptable: the repo does not track `.claude/settings.json` (`git ls-files` is empty), so every such citation in that file can only mean the project-scope convention. The probe below shows it reaches nothing beyond that pair.
3. **No release-notes entry.** Step 9 was SKIPPED at the committed head ("docs-only changes"). The author reports a WARN when the change was staged. It is a one-line allowlist change, so this is not a blocker.

## Is the allowlist the right fix (vs rewording)?

Yes.
- Line 396 ("a project-scope `.claude/settings.json` allow rule applies only after the folder's trust dialog is accepted") and line 453 cite Claude Code's per-folder project settings file. Line 453 is a quotation from code.claude.com/docs/en/permissions.md. Rewording it would falsify the quote. Changing either line to `~/.claude/settings.json` would reverse the user-scope vs project-scope contrast that item #28 rests on.
- `reference/tool-ops-*.md` is a protected file (`.claude/rules/sources-of-truth.md`). The checker's docstring (`scripts/check-path-refs.py:29-33`) says: "protected files take an allowlist entry instead of a marker". So the documented path is an allowlist entry, not a `path-ref: ignore` marker and not an edit to the protected file. The checker's intent (lines 4-7) is to detect dead repo-relative paths. A per-folder convention is not one.

## Format and parser

The entry is `reference/tool-ops-claude-code.md|.claude/settings.json|<reason>`. It has 3 non-empty `|` fields, and the reason contains no `|` (`load_allow`, lines 142-146). If the format were wrong the checker would exit 2. It exits 0.

## Over-allow probe

`.scratch/session-m3r136/overallow-probe.sh` builds a throwaway git repo from the PR's allowlist and doc, then adds three probes:
- `reference/other.md` citing `.claude/settings.json`: **still reported** (`reference/other.md:1`). The entry does not apply to other files.
- `.claude/settings.json.bak` cited in the allowed file: **still reported** (`:641`). Matching is exact, not by prefix.
- `.claude/settings.local.json` in the allowed file: not reported. `git check-ignore -v` shows the cause is the user's global ignore (`~/.config/git/ignore:1:**/.claude/settings.local.json`), not the allowlist. Set-membership matching cannot cover that path.
- Lines 396 and 453 were suppressed as intended.

## .ps1 parity

`scripts/check-pre-commit.ps1` step 20 (lines 359-393) runs the same `scripts/check-path-refs.py --root $script:RepoRoot`. It therefore reads the same `scripts/check-path-refs-allow.txt`. No `.ps1` change is needed. This is confirmed from the source; I did not run it under pwsh.

## Scope

`gh pr diff 136` and `git diff --stat origin/main origin/fix/tool-ops-path-ref` both show `scripts/check-path-refs-allow.txt | 1 +` and nothing else. The PR has one commit (62d22f5) and no unrelated changes.

## Evidence (commands run, macOS)

- Detached worktree `/Users/new-jose/repos/aitools/.claude/worktrees/m3-rr136` at `origin/fix/tool-ops-path-ref` (62d22f5).
- `python3 scripts/check-path-refs.py --root <wt>` at 62d22f5: `dead path references: 0`, exit 0.
- The same command at origin/main 5e13ef7 (same worktree, detached there temporarily, then returned to 62d22f5): exit 1, with `reference/tool-ops-claude-code.md:396: .claude/settings.json` and `reference/tool-ops-claude-code.md:453: .claude/settings.json`, `dead path references: 2`. This reproduces the failure on main and shows the PR fixes it.
- `bash scripts/check-pre-commit.sh`, run from the worktree (no `--fix`), exit 1:
  - step 20 `[PASS] every cited repo path exists`
  - the only FAIL is step 6 `Executable bit (.sh)`, the known pre-existing failure (the PR touches no `.sh`)
  - step 11 WARN: uncommitted changes in the dotprofile, not part of this PR
  - PASS: 1, 14, 15, 16, 17, 19, 21. The rest SKIP.
- CI at 62d22f5: CI macos, linux and windows SUCCESS (run 40747982538). CodeQL Analyze (actions, javascript-typescript, python, ruby) and CodeQL SUCCESS (run 40747978888).
- `gh pr view 136 --json mergeStateStatus`: `CLEAN` on both reads, base `main`, state `OPEN`.

## Not run

- `check-pre-commit.ps1` under pwsh: parity confirmed from the source only.
- `check-pre-push`: the PR changes only the allowlist. Running `grep -rl check-path-refs` over `scripts/`, `.github/` and `tests/` finds only the checker, the allowlist and the two `check-pre-commit` scripts, so no pre-push step, CI workflow or test reads the allowlist.
- `--fix`, and anything else that runs build-deploy against the real HOME.
