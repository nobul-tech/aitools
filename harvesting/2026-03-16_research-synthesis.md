# Research Synthesis: Multi-Stream Investigation

## Stream 1: Session Archiving vs Harvesting

### Session Archive (dotprofile)
- **What**: Full session transcript (JSONL)
- **Where**: `<userRepoPath>/sessions/<project>/<date>_<prefix>.jsonl`
- **When**: SessionEnd hook copies transcript
- **Git**: No git ops — user commits/pushes on own schedule (DESIGN GAP)
- **Privacy**: Private per-user repo, user controls what's pushed
- **Purpose**: Complete session history for reference/resume

### Artifact Harvesting (repo)
- **What**: Reusable artifacts extracted from .scratch/ (code, research, prompts)
- **Where**: `harvesting/<date>_<filename>` + manifest
- **When**: SessionEnd hook classifies, moves, updates manifest
- **Git**: No git ops — artifacts are committed with normal workflow
- **Privacy**: In the project repo, visible to all collaborators
- **Purpose**: Capture tactical solutions for potential promotion to harness

### Overlap
- Both fire at SessionEnd
- Both derive session IDs and dates (independently, causing mismatches)
- Both create dated artifacts from session work
- Session IDs flow from CC → archive hook AND harvest hook (no shared derivation)
- Date derivation: archive uses file birth time, harvest uses `date -u` (TODAY)

### Gaps
- No mechanism surfaces uncommitted archives when switching machines
- No validation that harvest manifest session IDs match real archives
- No shared utility for session ID/date derivation between hooks
- Privacy boundary undefined: what if a user wants harvesting but not session archiving?

## Stream 2: Session c8862b68 Identified
- **Skills Extraction Session** — extracted skills deployment from setup-user-mcp into setup-user-skills
- 2069 lines, 17:08-20:01 UTC on 2026-03-15
- NOT tool-ops execution, NOT in harvest manifest (produced no .scratch/ artifacts)
- This was the intermediate session between c0b392f4 (early) and 84280c8b (incident investigation)

## Stream 3: Cross-Platform Scripting Audit

### Platform-specific code found in hooks:
| Hook | Issue | Severity |
|------|-------|----------|
| surfacing-duty-stop.sh | `stat -f %m` and `stat -f %B` — BSD-only, no uname dispatch | **HIGH** (crashes on Windows) |
| session-archive.sh | Has uname dispatch but `date -d` in GNU branch fails on macOS | Medium (fallback works) |
| harvest-session.sh | `date -u +%Y-%m-%d` — portable, no issues | OK |
| tool-ops-session-audit.sh | Not audited yet | Unknown |

### Root cause of Incident C (stop hook crash):
- Line 53: `stat -f %m "$transcript_path"` — BSD stat, no platform dispatch
- Line 56: `stat -f %B "$transcript_path"` — BSD stat birth time
- On Windows Git Bash (GNU stat): `-f` means --file-system, `%m` treated as filename
- The `2>/dev/null || fallback` chain should work BUT `set -euo pipefail` + subshell
  behavior may cause the variable to be empty, triggering `set -u` "unbound variable"

### No established framework found, but patterns:
- uname-s dispatch wrappers (get_mtime, get_birthtime, epoch_to_date)
- ShellCheck portability warnings (SC2039, SC3000+)
- POSIX compliance where possible, bash-specific where needed
- Centralized compat layer in aitools-lib.sh

## Stream 4: Delegation Patterns from AAR

### The execution protocol (7 revisions, final version):
1. Read the full plan before starting
2. Intent-writing: look at skill + recent conversation history
3. Governed term audit before writing
4. Checkpoint commits at phase boundaries
5. Known state annotations
6. **Delegation duty** (recursive):
   - Brief delegated agent with: role/identity, relevant plan sections,
     prior batch results, deviations from plan, downstream context
   - Include the plan (FRAGORD without OPORD is useless)
   - Establish identity (who you are, what role, how work fits larger effort)
   - Any agent that delegates must follow this duty recursively
7. Harness constraints on delegation:
   - Sub-agents don't persist
   - Sub-agents don't inherit rules
   - No mid-execution updates
   - No peer communication
   - Verification happens after, not before

### What should be generalized into a delegation framework:
- Delegation duty as a universal rule
- Identity briefings as mandatory
- Context injection pattern (rules, standing orders, scratch skill)
- Agent type selection (Explore vs general-purpose — Explore can't write)
- Permission handling (batch permission grants, not per-call prompts)

## Stream 5: This Session's Delegation Failures (meta)

| Failure | Root Cause | Fix |
|---------|-----------|-----|
| First 4 agents: no scratch instructions | No delegation framework existed | Delegation rule + skill |
| Second 3 agents: asked to write but used Explore type | Agent type not matched to task | Delegation skill must include agent type guidance |
| User overwhelmed with permission prompts | No permission batching | Document permission patterns |
| Agents didn't read CLAUDE.md or rules | Context not injected | Delegation context template |
| Delegation context file written but agents couldn't use it | Explore agents are read-only for Write | Match agent type to output requirements |
