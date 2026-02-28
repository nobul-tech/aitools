# Claude Code Effectiveness Tracker

Self-assessment of how effectively Jose works with Claude Code, tracked over time.
See `shared/claude-shared.md` > Coaching section for the active improvement checklist.

## Baseline Assessment (2026-02-16)

**Rating: 8.5/10** (top tier on a curve against other users)

### Strengths

| Area | Description |
|------|-------------|
| Architectural thinking | Designs systems, not just fixes. CLAUDE.md hierarchy, build-deploy pipeline, MCP enable/disable architecture. |
| Documentation as infrastructure | Treats `CLAUDE.md`, `reference/`, `shared/` as load-bearing code. Every session starts with full context. |
| Cross-session continuity | Auto-memory + CLAUDE.md + project rules layering means minimal time re-explaining context. |
| Verification discipline | Traces execution paths, checks logs, verifies deployed artifacts rather than assuming correctness. |
| Plan-then-execute | Provides precise audit plans with file names, line numbers, severity ratings, and explicit "not fixing" lists. |
| Meta-investment | Optimizes the system (scaffolding, tooling, conventions) rather than just individual sessions. Multiplier effect. |

### Improvement Areas

| Area | Current | Target (9-10) |
|------|---------|----------------|
| Feedback loop size | Large batch plans (20+ files, 5 groups) | 2-3 file chunks with verification between each |
| Mid-session testing | Tests at end of session | Paste small test runs mid-session after each change group |
| Context management | Long sessions risk truncation | Use `/compact` or split sessions for distinct phases |
| Hooks | Not using Claude Code hooks | Pre/post hooks for auto-lint, auto-format, dangerous command blocking |
| `@` file references | Describes files by name | Use `@path/to/file` in prompts to pre-load into context |

## Progress Log

Track improvement over time. Add entries when notable changes in workflow are observed.

| Date | Rating | Notes |
|------|--------|-------|
| 2026-02-16 | 8.5 | Baseline. Strong architectural thinking and verification. Main gaps: batch size, hooks, context management. |
| 2026-02-19 | 8.5 | Session archive feature (v3.8): entry-flow review caught 3 bugs — missing uname dispatch, lossy path splitting, CRLF in .sh file. All preventable: batch size caused cross-cutting rules to be skipped despite being in context. Also discovered subagents don't inherit project rules. Strengthened coaching bullets accordingly. |
| 2026-02-19 | 8.5 | Post-session audit: subagent findings condensed away, dismissiveness when challenged, silent hook failure buried in summary. Added coaching bullets (preserve work product, standing order on user-reported problems) and surface-silent-failures rule. Technical: userRepoPath missing from config.json -- hook was a no-op. |

## Incident Tracker

Structured tracking of standing order violations, coaching failures, and behavioral
incidents. Each incident gets RCA and remediation tracking.

### Status definitions

| Status | Meaning |
|--------|---------|
| Observed | Incident logged, not yet investigated |
| RCA | Root cause identified |
| Remediated | Fix applied (code change, rule addition, hook) |
| Mitigated | Can't fully fix; risk reduced (workaround, monitoring, hook warning) |
| Accepted | Known limitation, consciously accepted with documentation |
| Verified | Fix/mitigation confirmed effective in a subsequent session |

### Incidents

| # | Date | Category | Summary | Status | Standing Order | Upstream |
|---|------|----------|---------|--------|---------------|----------|
| I1 | 2026-02-19 | Coaching | Batch size (20+ files) caused cross-cutting rules skipped despite being in context | Remediated | -- | -- |
| I2 | 2026-02-19 | Coaching | Subagent context gap: rules/CLAUDE.md not inherited by Task subagents | Mitigated | -- | [#29423](https://github.com/anthropics/claude-code/issues/29423) |
| I3 | 2026-02-19 | SO #2 | Dismissiveness when user challenged subagent results; deflected instead of investigating | Remediated | Investigate user-reported problems | -- |
| I4 | 2026-02-19 | Coaching | Subagent work product condensed to stub summary, discarding detail | Remediated | -- | -- |
| I5 | 2026-02-19 | SO #7 | Silent hook failure: session-archive hook was no-op due to missing userRepoPath, buried in summary | Remediated | No silent failures | -- |
| I6 | 2026-02-28 | Process | Deploy template logic not updated when scripts/ source fixed — recurring pattern (3+ occurrences) | Remediated | -- | v0.25.1 |

### Incident Details

#### I1: Batch size caused rule skips (2026-02-19)

- **Observed**: Session archive feature planned as 20+ file batch across 5 groups
- **RCA**: Focus narrows to feature logic in large batches; cross-cutting concerns (dispatch patterns, encoding, platform guards) get skipped even when rules are in context
- **Remediation**: Added coaching bullet "Smaller batches: 2-3 file chunks with verification between each" to `shared/claude-shared.md`
- **Status**: Remediated
- **Detection gap**: No automated check. Could be caught by transcript analysis that flags sessions with many consecutive writes without intermediate verification
- **Next step**: Explore PreToolUse hook that warns after N consecutive writes without a check/test step

#### I2: Subagent context gap (2026-02-19)

- **Observed**: Subagents launched via Task tool did not load `.claude/rules/`, `CLAUDE.md`, or `~/.claude/CLAUDE.md`
- **RCA**: Upstream limitation -- Task subagents are isolated processes with no rule inheritance
- **Remediation**: Added coaching bullet warning against delegating code-writing to subagents in projects with cross-cutting rules. Filed [#29423](https://github.com/anthropics/claude-code/issues/29423)
- **Status**: Mitigated (upstream limitation, can't fully fix)
- **Detection gap**: None feasible until upstream fixes. Coaching bullet is the mitigation
- **Next step**: Monitor #29423; re-check on CC version bumps (version-deps item #5)

#### I3: Dismissiveness on user challenge (2026-02-19)

- **Observed**: User challenged subagent audit results; Claude deflected instead of investigating
- **RCA**: Tendency to defend prior output rather than treat user feedback as signal
- **Remediation**: Added standing order #2 "Investigate user-reported problems" and coaching bullet "Clarify before complying"
- **Status**: Remediated
- **Detection gap**: Hard to detect automatically. Transcript analysis could flag responses that don't include investigation steps after user pushback
- **Next step**: None (behavioral, covered by standing order)

#### I4: Subagent work product condensed (2026-02-19)

- **Observed**: Multi-file audit by subagent produced detailed findings; main context condensed them to a stub summary discarding the detail
- **RCA**: Context pressure led to summarization that lost actionable information
- **Remediation**: Added coaching bullet "Preserve subagent work product: write full findings to plans/ or scratch file"
- **Status**: Remediated
- **Detection gap**: Transcript analysis could compare subagent output size vs. main context summary size
- **Next step**: None (behavioral, covered by coaching bullet)

#### I5: Silent hook failure (2026-02-19)

- **Observed**: Session-archive hook was deployed and appeared working, but was actually a no-op because `userRepoPath` was missing from `config.json`
- **RCA**: Hook silently exits on missing config. Feature described as "working" when it had never fired
- **Remediation**: Added `.claude/rules/surface-silent-failures.md` rule. Technical fix: user ran `aitools user init` to set `userRepoPath`
- **Status**: Remediated
- **Detection gap**: Check scripts could verify hook prerequisites (config keys present, target dirs exist). Post-push step #5 partially covers this
- **Next step**: Extend post-push step #5 to verify archive directory exists and has recent files

#### I6: Deploy template drift — recurring (2026-02-28)

- **Observed**: When fixing bugs in `scripts/setup-user-hooks.sh/.ps1` (ConvertPSObjectToHashtable array fix, mergeHookEntry logic), the corresponding template in `build-deploy.sh` was not updated. User had to remind. This is the 3rd+ occurrence of this pattern.
- **RCA**: Generated deploy scripts (`setup-user-{claude,cursor,mcp,hooks}`) have setup logic hardcoded in `build-deploy.sh` templates, duplicated from `scripts/`. Running `build-deploy.sh` faithfully reproduces stale templates — existing pre-commit checks (step 3+10) catch stale builds but not stale template logic.
- **Remediation**:
  - Added pre-commit step 13: heuristic warning when `scripts/setup-user-*` changes without `build-deploy.sh`
  - Updated `deploy-paths.md` rule with explicit template sync table
  - **Structural fix (v0.25.1)**: Refactored `build-deploy.sh` to extract setup logic from `scripts/` at build time via sentinel-based Perl extraction (`extract_between()` helper). Eliminated ~507 lines of duplicated template logic. All 4 script pairs (claude, cursor, mcp, hooks) now use single source of truth.
- **Status**: Remediated (v0.25.1)
- **Verification**: `build-deploy.sh` now fails loudly if sentinels are missing. Pre-commit step 13 remains as a secondary safety net.
