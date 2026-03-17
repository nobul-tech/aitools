# Session Gap Investigation Report

**Date**: 2026-03-16
**Scope**: Sessions from 2026-03-09 through 2026-03-15 (37 sessions scanned)
**Source**: Session transcripts in `aitools-nobul-jose/sessions/aitools/`, Windows session summary, harvest manifest, incidents.json

## Executive Summary

**5 known unfiled issues confirmed.** None of the 5 issues listed in the task brief have corresponding entries in `reference/incidents.json`. One additional issue discovered (version tag gap, since resolved). The scan also found that the surfacing-duty-stop hook itself -- the mechanism designed to catch unfiled incidents -- is broken on Windows, creating a self-referential governance failure.

## Cross-Reference: Filed vs Unfiled

### Already Filed (Related but Not Covering These Issues)

| ID | Title | Relevance |
|----|-------|-----------|
| #8 | Sessions feature silently fails without userRepoPath | Related to session archiving but covers config, not hook behavior |
| #29 | Subagent context gap: rules/CLAUDE.md not inherited | Covers context inheritance, not scratch directory access |
| #31 | Subagent work product condensed to stub summary | Covers summarization loss, not delegation write failures |
| #32 | Silent hook failure: session-archive hook was no-op | Covers missing userRepoPath, not uncommitted archives |

### NOT Filed (The 5 Known Gaps)

All 5 issues below are confirmed unfiled. Draft incident fields follow.

---

## Unfiled Issue 1: Stop Hook Crash on Windows (surfacing-duty-stop.sh line 54)

### Evidence

- Windows session summary lines 6 and 114-115: `Stop hook error: Failed with non-blocking status code: C:/Users/jdpal/.claude/hooks/surfacing-duty-stop.sh: line 54: File: unbound variable`
- The error fires on every agent turn, confirmed by appearing twice in a single session
- Irony: the hook designed to catch unfiled incidents is itself broken, disabling the detection layer on Windows

### Root Cause Analysis

`shared/hooks/surfacing-duty-stop.sh` line 53:
```bash
file_mod=$(stat -f %m "$transcript_path" 2>/dev/null || stat -c %Y "$transcript_path" 2>/dev/null || echo "$now")
```

On Windows Git Bash, `stat -f %m` succeeds (exit 0) but outputs file-system metadata rather than modification time. The `-f` flag in GNU stat (bundled with Git Bash) means "display file system status" not "format string" (which is macOS's `stat -f`). The output contains text like `File: "path"` which gets assigned to `file_mod`. On line 54, `$(( now - file_mod ))` performs arithmetic on the string value. Bash arithmetic treats non-numeric strings as variable names; `File` is not a defined variable, so `set -u` (nounset) triggers a fatal error.

Lines 56 and 94 have the same pattern and would also fail if reached.

### Draft Incident Fields

- **title**: Stop hook (surfacing-duty-stop.sh) crashes on Windows due to cross-platform stat incompatibility
- **severity**: high (disables the surfacing duty detection layer on Windows; self-referential governance failure)
- **affected**: `shared/hooks/surfacing-duty-stop.sh`
- **observation**: `stat -f %m` on line 53 succeeds with exit 0 on Windows Git Bash but produces non-numeric output (GNU stat `-f` = file system, not format). The non-numeric value causes `set -u` to abort on line 54 when bash arithmetic treats the string as an undefined variable name. Error fires on every agent turn: "line 54: File: unbound variable". Same pattern on lines 56 and 94.
- **expected**: `.claude/rules/cross-platform.md` requires hooks to work on all platforms. `.claude/rules/script-standards.md` requires `stat` calls to use cross-platform patterns (macOS `stat -f` vs GNU `stat -c`). The `||` chain on line 53 assumes one of the two stat commands will fail -- but on Windows Git Bash, `stat -f %m` succeeds with wrong semantics.
- **impact**: Surfacing duty detection is completely disabled on Windows. The hook crashes silently (non-blocking) on every agent turn, meaning incident-acknowledgment language is never detected and periodic reminders never fire. This is the detection layer for unfiled incidents -- its failure means the entire surfacing duty enforcement chain is broken on one platform.

---

## Unfiled Issue 2: 3 Uncommitted Sessions on Mac (Cross-Machine Visibility Gap)

### Evidence

- `git -C aitools-nobul-jose status --short` shows 3 untracked session files:
  - `sessions/aitools/2026-03-15_84280c8b.jsonl`
  - `sessions/aitools/2026-03-15_c8862b68.jsonl`
  - `sessions/aitools/2026-03-15_eaacf9da.jsonl`
- Windows session summary (line 91-104) reports the Windows dotprofile had only 1 session from March 15 (`c0b392f4`), confirming the cross-machine gap
- These 3 sessions represent the governance overhaul, the production incident investigation, and the tool-ops planning session -- significant work invisible from Windows
- Also untracked: `sessions/marse/` directory (another project's sessions)
- Modified: `.scratch/commit-msg.txt` (pending commit message: "Sync concurrent-agents rule, archive session")

### Draft Incident Fields

- **title**: Session archive hook produces archives but no auto-commit -- cross-machine visibility depends on manual git operations
- **severity**: medium (sessions are safely stored locally but invisible to other machines; no data loss risk)
- **affected**: `shared/hooks/session-archive.sh`, `reference/user-repo.md`
- **observation**: `session-archive.sh` copies transcript files to the dotprofile repo but performs no git operations (line 93: `cp "$TRANSCRIPT" "$DEST_FILE"`). The hook's header comment says "No git operations (user commits/pushes on their own schedule)" (line 12). After 3 sessions on March 15, all 3 archives sat uncommitted. The Windows session the next day could only see 1 session (previously committed `c0b392f4`).
- **expected**: The design decision to skip git operations is documented in the hook header. However, `reference/user-repo.md` spec says "Session archiving: automatic via SessionEnd hook" -- the word "automatic" implies end-to-end delivery, not just local file copy. There is no spec for how archives reach the remote.
- **impact**: Sessions containing critical decisions (tool-ops framework design, production incident RCA, governance overhaul) are invisible from other machines until manual intervention. User asked Windows session to "audit the macOS conversations" but only 1 of 4 was visible. Cross-machine workflow depends on an undocumented manual step.

---

## Unfiled Issue 3: Fake Session ID 2Hb40B0VEu in Harvest Manifest

### Evidence

- `harvest-manifest.json` lines 59 and 70 reference session `aitools/2026-03-15_2Hb40B0VEu`
- No session archive exists with ID `2Hb40B0VEu` in `aitools-nobul-jose/sessions/aitools/`
- No Claude Code session directory exists at `~/.claude/projects/-Users-pepe-repos-aitools/` with prefix `2Hb40B0VEu`
- The 2 artifacts tagged with this session ID are marked `keep` and `candidate` -- they are the AAR and test suite, the most valuable artifacts from the day
- The ID format `2Hb40B0VEu` is unusual -- Claude Code session IDs are typically UUIDs (e.g., `eaacf9da-9335-405f-abc7-9df5a965d815`)

### Root Cause Analysis

The harvest-session hook (line 111-112) constructs session refs as:
```bash
prefix=$(printf '%s' "$SESSION_ID" | cut -c1-8)
session_ref="${project_name}/${TODAY}_${prefix}"
```

The session ID comes from the hook input JSON's `session_id` field. The format `2Hb40B0VEu` does not match any known Claude Code session ID pattern. This appears to be either:
1. A session that was manually added to the manifest (not via the hook)
2. A corrupted or fabricated session ID from a hook input parsing error
3. The hook ran in a context where `session_id` was empty or malformed, and the prefix was derived from other content

Given that the AAR and test suite were "keep" candidates with rich descriptions (not "Auto-harvested from session scratch"), these entries were likely written manually by an agent during a session, not by the harvest-session hook. The agent may have invented the session ID.

### Draft Incident Fields

- **title**: Harvest manifest contains phantom session ID 2Hb40B0VEu -- no corresponding session archive exists
- **severity**: medium (data integrity issue; artifacts exist and are valid, but provenance chain is broken)
- **affected**: `harvesting/harvest-manifest.json`
- **observation**: Two `keep`/`candidate` artifacts reference session `aitools/2026-03-15_2Hb40B0VEu`. No session archive with ID `2Hb40B0VEu` exists in the dotprofile. No Claude Code project directory matches this ID. The ID format is non-standard (10 alphanumeric chars vs standard UUID format).
- **expected**: Every harvest manifest entry should reference a verifiable session ID that maps to either an archived session or a local Claude Code session directory. The session_ref should be auditable end-to-end: manifest -> archive -> source session.
- **impact**: Provenance chain broken for the two most valuable artifacts from March 15 (AAR and test suite). Cannot verify which session produced them. If the harvest manifest is used for auditing session productivity, phantom IDs produce false data. Pattern could recur if agents write manifest entries directly instead of going through the hook.

---

## Unfiled Issue 4: Date Mismatch Between Archive and Harvest Hooks

### Evidence

- Session `eaacf9da` started at `2026-03-15T22:57:57Z` (from transcript line 2)
- Session archive hook archived it as `2026-03-15_eaacf9da.jsonl` (using transcript birth time: March 15)
- Harvest hook recorded artifacts as `2026-03-16_*` (using `date -u +%Y-%m-%d`: March 16 at session end)
- Manifest entries: `2026-03-16_aar-tool-ops-plan.md`, `2026-03-16_health-check.py`, `2026-03-16_test-tool-ops.py` all reference `session: aitools/2026-03-16_eaacf9da`
- But the actual archive file is `2026-03-15_eaacf9da.jsonl` -- the date prefix differs

### Root Cause Analysis

The two hooks use different date derivation strategies:

- **session-archive.sh** (line 68-78): Uses transcript file birth time (`stat -f %SB` on macOS). Session started on March 15, so birth time = March 15.
- **harvest-session.sh** (line 56): Uses `TODAY=$(date -u +%Y-%m-%d)`. Session ended after midnight UTC on March 16, so `TODAY` = March 16.
- **harvest-session.sh** (line 112): Constructs `session_ref="${project_name}/${TODAY}_${prefix}"` using the same `TODAY`. Result: `aitools/2026-03-16_eaacf9da`.

For late-night sessions that cross midnight UTC, the two hooks produce different dates, breaking the cross-reference between archives and harvest artifacts.

### Draft Incident Fields

- **title**: Date mismatch between session-archive and harvest-session hooks for sessions crossing midnight UTC
- **severity**: medium (breaks cross-referencing but no data loss)
- **affected**: `shared/hooks/harvest-session.sh`, `shared/hooks/session-archive.sh`
- **observation**: `session-archive.sh` uses transcript birth time for the date prefix (session start date). `harvest-session.sh` uses `date -u` at hook execution time (session end date). For session `eaacf9da` (started 2026-03-15T22:57 UTC, ended after midnight), the archive is `2026-03-15_eaacf9da.jsonl` but harvest artifacts reference `aitools/2026-03-16_eaacf9da`. The session_ref in the manifest does not match the actual archive filename.
- **expected**: Both hooks should derive the same date for the same session. The session_ref in harvest-manifest.json should match the actual archive filename in the dotprofile repo.
- **impact**: Cannot navigate from a harvest artifact to its source session by following the session_ref. Automated auditing of harvest-to-session provenance will produce false negatives. Pattern affects any session ending after midnight UTC.

---

## Unfiled Issue 5: Explore Agents Cannot Write to Scratch (Delegation Failure)

### Evidence

- Windows session summary shows "5 Explore agents finished" (line 14) -- these are Task subagents
- UCI: "Preserve subagent work product -- write full findings to the session scratch directory" is a coaching item
- Incident #29 documents that Task subagents don't inherit rules/CLAUDE.md
- Incident #31 documents that subagent work product gets condensed to stubs
- The scratch-init hook (line 43) outputs the session scratch path to stdout, but this is only available to the main session context
- Explore agents (Task subagents) don't receive the scratch directory path and don't have permission/knowledge to write to it
- The UCI coaching item "Preserve subagent work product" instructs the *main agent* to write to scratch, but the subagent itself cannot do so

### Root Cause Analysis

The delegation chain has a gap:

1. `scratch-init.sh` creates a session scratch directory and outputs the path to the main session
2. The main agent knows the scratch path (via SessionStart hook output)
3. When the main agent delegates via Task, the subagent doesn't receive the scratch path
4. Even if the subagent knew the path, it may not have Write permissions to `.scratch/`
5. The subagent returns its findings to the main agent as text
6. The main agent is supposed to write the findings to scratch (per UCI), but this step is often skipped due to context pressure

This is a compound failure: the infrastructure doesn't support subagent -> scratch writes, and the coaching mitigation (main agent writes) is frequently not followed.

### Draft Incident Fields

- **title**: Subagent (explore/Task) delegation lacks scratch directory access -- work products cannot be persisted from subagents
- **severity**: medium (work products are lost but can be re-derived; compounds incident #31)
- **affected**: `shared/hooks/scratch-init.sh`, UCI coaching items in `shared/claude-shared.md`
- **observation**: Scratch directory path is injected into the main session via SessionStart hook stdout. Task subagents (explore agents) don't receive this path and cannot write to `.scratch/session-*/`. The coaching item "Preserve subagent work product" directs the main agent to write findings to scratch, but this is frequently skipped. In the Windows session, 5 explore agents produced findings totaling ~286k tokens of work -- all returned as inline summaries, none persisted to scratch.
- **expected**: UCI: "Preserve subagent work product -- write full findings to the session scratch directory, do not condense them into a stub summary." This coaching item assumes the main agent will act on subagent returns, but provides no enforcement mechanism.
- **impact**: Substantial subagent work products are ephemeral. When the main session ends or compacts context, these findings are lost. The SessionEnd harvest hook cannot harvest what was never written to scratch. Compounds the losses described in incident #31.

---

## Additional Issues Found

### Issue 6: Missing Version Tags (Resolved)

The Windows session summary (line 37, 110) noted "No version tags created (latest tag is still v0.54.1)" and "Missing version tags: v0.59-v0.61.2 were released but never tagged." As of this investigation, tags v0.59 through v0.61.2 now exist on the repo. This issue has been resolved and does not need an incident.

### Issue 7: Dotprofile Has Pending Uncommitted Changes Beyond Sessions

- `git -C aitools-nobul-jose status` also shows modified `.scratch/commit-msg.txt` and untracked `sessions/marse/` directory
- The pending commit message "Sync concurrent-agents rule, archive session" suggests a commit was prepared but never executed
- This is a minor operational hygiene issue, not an incident

## Session Scan Statistics

37 sessions scanned from 2026-03-09 through 2026-03-15:
- Total keyword matches: ~2,737 findings across all sessions
- Highest-density sessions: `2026-03-15_c8862b68` (253 findings, 2069 lines), `2026-03-15_eaacf9da` (191 findings, 1485 lines)
- Most frequent keywords: "gap" (major theme in March 13-15 sessions due to gap->incident rename), "error", "fail", "bug"
- "incident" keyword concentrated in March 15 sessions (incident governance framework being built)

## Recommendations

1. **File all 5 issues via `/incident` skill** -- each has draft fields ready for review
2. **Fix the stop hook first** (Issue 1) -- it's the detection layer. Use `case "$(uname -s)"` dispatch for stat commands, matching the pattern in `session-archive.sh`
3. **Align hook dates** (Issue 4) -- both hooks should use transcript birth time, not current date
4. **Commit dotprofile sessions** (Issue 2) -- immediate manual action, then consider whether auto-commit should be added to the archive hook
5. **Fix phantom session ID** (Issue 3) -- correct `2Hb40B0VEu` entries in manifest to reference the actual session that produced them (likely `eaacf9da` or `c8862b68`)
6. **Design subagent scratch access** (Issue 5) -- consider injecting scratch path into Task subagent prompts via the SubagentStart hook
