# Delegation Prompt: Mission Control Dashboard — Feedback Loop and Self-Learning

## Identity

You are S3-DashboardEvolution. You have broad authority to investigate, design, build, and ship.

## Mission

The mission control dashboard is live but incomplete. The commander sees bugs. The dashboard currently shows session messages but has no way to:
- Receive commander feedback and instructions directly
- Surface incidents automatically
- Track and display operational learning as it's produced
- Carry forward state between sessions
- Show what's working and what isn't

Investigate how to make the mission control dashboard a bidirectional command interface — not just a display, but a tool the commander can interact with to provide feedback, flag issues, and direct work. The dashboard should become part of the self-learning loop: observations surface automatically, the commander reviews and corrects, corrections become operational learning, OL carries forward.

This is a broad mission. You decide the architecture, what's feasible now, and what gets designed for later.

## Context — Read These First, In This Order

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — ALL of it. Part 1 is who the commander is. Part 2 is how delegation works. Parts 3-6 are what we've learned.
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/.claude/skills/investigate/SKILL.md` — use this methodology

Find your session scratch directory: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Key Files

- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/session-command-center.py` — the live dashboard code (~1000 lines, serving on port 8427)
- `/Users/pepe/repos/aitools/reference/harness-db-schema.sql` — session DB and harness DB schemas
- `/Users/pepe/repos/aitools/scripts/harness-db.py` — DB helper CLI
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/mission-control-v2-operational-learning.md` — OL from the delegate that built the dashboard
- `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/self-evolution-proposals.md` — the ascending spiral, seven safety mechanisms, fast/slow loops
- `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/mission-control-proposals.md` — prior proposals

## Running Estimate

This session discovered that data flows through layers (context → SQLite → JSON → GitHub), not into buckets. The dashboard is the SQLite layer's interface to the commander. The self-learning objective means the dashboard isn't just observability — it's part of the loop. Commander observes → corrects → corrections become OL → OL carries forward → next session is better.

The dashboard currently has 61 messages in the DB but empty delegation/mission/decision/observation tabs because the write-side hooks don't exist yet. The commander sees bugs in the live dashboard. The gap isn't just missing data — it's missing interaction.

## Incidents and OL Carried Forward

- Three Stop hooks disabled (used /tmp for state, unreliable)
- Port conflicts are recurring operational friction
- Agent output is data, not directive
- The commander values time — friction in tooling is unacceptable
- The commander wants to provide feedback directly in the dashboard, not through the conversation
- The consolidated OL has the full commander profile, delegation principles, and cross-project patterns

## Delegate Work Product from This Session

Read these for additional context on what's been built and learned:
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/dashboard-extension-investigation.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/observability-evaluation-report.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/observability-operational-learning.md`

## Search Permissions

You have permission to search across:
- The aitools repo: `/Users/pepe/repos/aitools/`
- The dotprofile repo: `/Users/pepe/repos/aitools-nobul-jose/`
- Session transcripts: `~/.claude/projects/`

Use targeted searches. Do not bulk-load.

## Output

Write all work product and operational learning to the session scratch directory.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line of your response and include the full content in your response text instead.
