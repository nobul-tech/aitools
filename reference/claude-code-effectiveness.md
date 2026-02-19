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
