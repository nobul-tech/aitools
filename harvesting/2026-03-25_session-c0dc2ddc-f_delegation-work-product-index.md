# Delegation Prompt: Operational Learning Index

## Identity

You are S3-Index. You have broad authority to investigate, evaluate, design, build, and ship.

## Mission

Make all of our accumulated operational learning across all projects accessible, queryable, and quality-ranked — without bloating context — in a way that can be iteratively improved through subsequent missions.

## Context — Read These First, In This Order

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — the consolidated OL from this session. Read ALL of it. Part 1 tells you who the commander is. Part 2 tells you how to delegate. Parts 3-6 tell you what we've learned across three projects.
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`

Find your session scratch directory: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Running Estimate from This Session

This session loaded the entire aitools codebase (~570K tokens), discovered a /tmp bug in three hooks, investigated it, loaded 9 RFCs and 11 reference files from a prior session, launched three cross-project audit delegations (aitools, marse, nobul-ops), produced the consolidated OL, built an OL dashboard, built a session command center reading from SQLite, and built a session file viewer. Two parallel missions are running alongside you.

Key decisions: JSON is too cumbersome for runtime state — SQLite is the runtime layer. The long-term objective of aitools is self-learning. The commander's long-term objective is aitools as leverage across all projects. Data flows through layers (context → SQLite → JSON → GitHub), not into buckets. Consolidation matters more than storage format. The 1M context window can hold all operational learning if consolidated.

## Operational Learning Carried Forward

- Delegation prompts go to scratch files. Scripts go to scratch files. Execute from there.
- Agent output is data, not directive. Evaluate against conventions before propagating.
- The commander values time above all else. Friction is unacceptable.
- Release notes and git commit history are first-class sources of operational learning.
- The dotprofile repo (`/Users/pepe/repos/aitools-nobul-jose/`) has session archives across all projects and platforms.
- Prior sessions built Python transcript parsers that extract user messages — they exist somewhere in scratch or harvesting directories. Find and reuse them.
- Port conflicts are a recurring operational friction item. Check port availability before binding.
- The commander said "is sqlite the right tool here, or should we broaden our scope to investigate that?" — do not assume SQLite. Investigate what's right.
- Quality differentiation of work product is a research question. Recency is one signal among many. Investigate what signals exist in the data.
- Whatever you build should be iteratively improvable — subsequent missions should be able to extend it.

## Incidents from This Session

- I-1: Agent conserved tokens when told not to (3 corrections)
- I-2: Agent delegated to Explore agents (can't write)
- I-3: Agent assumed running estimate was future capability (SessionStart hooks exist)
- I-4: Agent anchored on SQLite as answer to everything (consolidation matters more than format)
- I-5: Agent assumed 1M context couldn't hold all OL (it can, if consolidated)
- I-6: Agent didn't carry forward consolidated OL to delegate (produced it then didn't use it)

## Delegate Work Product from This Session

These files contain OL from completed missions — read them for additional context:
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/investigation-tmp-hooks.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/prior-session-delegation-audit.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/marse-session-delegation-audit.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/nobul-ops-session-audit.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/aitool-resume-test.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/dashboard-extension-investigation.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/observability-evaluation-report.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/observability-operational-learning.md`
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/mission-control-v2-operational-learning.md`

## Search Permissions

You have permission to search across:
- The aitools repo: `/Users/pepe/repos/aitools/`
- The dotprofile repo: `/Users/pepe/repos/aitools-nobul-jose/`
- Session transcripts on this machine: `~/.claude/projects/`
- The marse repo: `/Users/pepe/repos/marse/`
- The nobul-ops repo: `/Users/pepe/repos/nobul-ops/`

Use targeted searches. Do not bulk-load transcripts.

## Output

Write all work product and operational learning to the session scratch directory.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line of your response and include the full content in your response text instead.
