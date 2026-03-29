# Housekeeping Report — 2026-03-25

## 1. Dotprofile Repo (aitools-nobul-jose)

**Status**: Clean, pushed.

The repo had 1 unpushed commit (`7f7613b Archive session 2026-03-24_c0dc2ddc (aitools)`). Pushed to origin successfully.

## 2. Stale Scratch Session Directories

12 stale session directories found (excluding current `session-2d439e32-3` and active `session-c0dc2ddc-f`):

| Directory | Files | Last Modified | Notes |
|-----------|-------|---------------|-------|
| session-RnTOD5XJFi | 138 | 2026-03-24 | Large — commit msgs, AARs, CI workflow, check logs |
| session-5HyCwPtSDH | 85 | 2026-03-21 | Large — dashboard HTML, governance tools, commit msgs |
| session-KHGOmVeNNM | 4 | 2026-03-23 | Context rot research, hook verification, intent sentinel design |
| session-delta2 | 3 | 2026-03-24 | Build log, commit msg, write-rule script |
| session-XgKlTIlRuW | 3 | 2026-03-22 | Commit message files only |
| session-5RXfu1UodN | 1 | 2026-03-24 | Single JSON: mission-bravo-institutional-memory.json |
| session-d3dae79d-9 | 0 | 2026-03-25 | Empty |
| session-DhaNpbSXl4 | 0 | 2026-03-24 | Empty |
| session-dvFClN4vDd | 0 | 2026-03-24 | Empty |
| session-eAJV8MhjUH | 0 | 2026-03-24 | Empty |
| session-oB9m9QOPNR | 0 | 2026-03-24 | Empty |
| session-YqXYt9wQw4 | 0 | 2026-03-24 | Empty |

**Total**: 237 files across 12 directories. 5 directories are empty (safe to remove). The two large ones (RnTOD5XJFi, 5HyCwPtSDH) contain mostly commit message files and build logs — ephemeral by definition. A few items may be worth reviewing before cleanup:

- `session-KHGOmVeNNM/context-rot-research.md` and `intent-sentinel-design.md` — research artifacts
- `session-5RXfu1UodN/mission-bravo-institutional-memory.json` — may have carry-forward value
- `session-5HyCwPtSDH/*dashboard*.html` — generated dashboards

**Recommendation**: Remove all 5 empty directories immediately. Review the 3 items above, then remove the rest.

## 3. settings.local.json Cruft Analysis

221 permission entries. Categories of cruft:

### A. Old repo name references (`ai-tooling` instead of `aitools`) — 18 entries

Lines 4-12, 19, 34-42, 54, 57, 58, 70, 94, 107-111. The repo was renamed from `ai-tooling` to `aitools` but these permissions still reference the old path `/Users/pepe/repos/ai-tooling`. Examples:
- `Bash(git -C /Users/pepe/repos/ai-tooling log --oneline -30)`
- `Bash(git -C /Users/pepe/repos/ai-tooling push origin main)`
- `Bash(git -C /Users/pepe/repos/ai-tooling add .claude/rules/cross-platform.md CLAUDE.md ...)`

### B. Fragmented shell loop parts — 18 entries

Lines 86-93, 98-102, 106-111, 114-116, 119-120, 151-152, 157, 208. Individual loop keywords accepted as separate permissions:
- `Bash(do)`, `Bash(done)`, `Bash(do basename "$f" .jsonl)`, `Bash(do echo:*)`
- `Bash(while read -r file:*)`, `Bash(while read f)`, `Bash(while read mtime)`
- `Bash(for dir in ~/.npm/_npx/*/)`
- `Bash(do if ls "$dir"node_modules/chrome-devtools-mcp)`
- `Bash(then echo "FOUND in $dir")`, `Bash(break)`, `Bash(fi:*)`
- `Bash(for f in scripts/setup-user-mcp.sh ...)` (lines 106-111)
- `Bash(for f in scripts/*.sh scripts/aitools)` (line 119)
- `Bash(for repo:*)` (line 208)

### C. Commit messages embedded as permissions — 1 entry

Line 72: An entire commit message body was accepted as a permission:
```
Bash(approved" from "fully scripted." Renames "Tested on" to "Verified on"
across all release notes to eliminate overloading with tool approval
terminology.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
\)")
```

### D. Echo/printf debug patterns — 9 entries

Lines 33, 123, 130, 138, 140-141, 146, 154, 157. Specific echo patterns that were accepted during debugging:
- `Bash(echo === $\(basename $f\) ===:*)`
- `Bash(echo ✓ $file:*)`, `Bash(echo ✓ $file exists:*)`, `Bash(echo ✓ $ref exists:*)`
- `Bash(echo === Pandoc Install Commands ===:*)`
- `Bash(echo === BUG \(command substitution strips \\\\n\) ===:*)`
- `Bash(echo === Line endings ===:*)`

### E. One-off investigative commands — ~25 entries

Specific git show SHAs (lines 35-36), GIT_TRACE (163), security keychain commands (192-193), specific complex grep/perl one-liners (196-197), specific `tail -1` on a session JSONL (214), DD_SITE-prefixed pup commands (185-189), old Perl version checks (198-199), specific `OLDPWD=` command (70).

### F. Temp file commit paths — 3 entries

Lines 178-179, 183: `/tmp/commit-msg.txt`, `/tmp/commit-msg-user.txt`, `/tmp/commit-msg2.txt` — before the scratch-file pattern was established.

### G. Redundant broad permissions that supersede specific ones

- `Bash(git:*)` (line 161) makes ALL specific git permissions redundant (lines 4-12, 19-22, 30, etc.)
- `Bash(git -C:*)` (line 58) makes all `git -C /Users/pepe/repos/ai-tooling` entries redundant
- `Bash(git log:*)` (line 128) is redundant with `Bash(git:*)`
- `Bash(git status:*)` (line 113), `Bash(git diff:*)` (line 153), `Bash(git commit:*)` (line 21), etc. — all redundant

### Summary

| Category | Count | Action |
|----------|-------|--------|
| Old repo name (`ai-tooling`) | ~18 | Remove (dead paths) |
| Fragmented loop parts | ~18 | Remove (never match real commands) |
| Embedded commit message | 1 | Remove |
| Echo/printf debug | ~9 | Remove |
| One-off investigative | ~25 | Remove |
| Temp file paths | 3 | Remove |
| Redundant (subsumed by broad wildcard) | ~30 | Remove (covered by `Bash(git:*)` etc.) |
| **Legitimate, keep** | ~**40-50** | Retain |

**Recommendation**: Reset to ~40-50 clean entries. The broad wildcards (`Bash(git:*)`, `Bash(bash:*)`, `Bash(perl:*)`, etc.) plus MCP and WebFetch domains cover nearly everything needed.

## 4. Knowledge DB

- **Location**: `/Users/pepe/.aitools/knowledge.db`
- **Size**: 12.6 MB
- **Last modified**: 2026-03-25 14:39 (today)
- **Harvesting directory**: 528 files total, 49 added today (from session-c0dc2ddc-f)

The DB was rebuilt today. However, the 49 new harvesting artifacts from today's session (all `2026-03-25_session-c0dc2ddc-f_*` files) are untracked in git — they exist on disk but may not have been ingested into the DB if the build script ran before they were created.

**Recommendation**: Rebuild the knowledge DB after committing the new harvesting artifacts. The DB is stale relative to the 49 new artifacts if they were created after the 14:39 rebuild.

## 5. Actions Available

1. **Push dotprofile** — Done.
2. **Clean stale scratch** — Remove 5 empty dirs immediately; review 3 items, then remove rest. Say "clean scratch" to proceed.
3. **Compact settings.local.json** — Reduce from 221 to ~40-50 entries. Say "compact permissions" to proceed.
4. **Rebuild knowledge DB** — After new artifacts are committed. Say "rebuild kb" to proceed.
5. **Commit new harvesting artifacts** — 49 untracked files in `harvesting/`. Say "commit harvest" to proceed.
