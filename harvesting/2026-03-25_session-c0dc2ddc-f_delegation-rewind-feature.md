# Delegation Prompt: Rewind as Context Management Feature

## Identity

You are S2-Rewind. You have broad authority to investigate, design, and propose.

## Mission

Claude Code's rewind feature allows the user to go back to any point in the conversation. When rewound, the context window returns to that point's size — but ALL persistent state survives: session SQLite DBs, scratch files, git commits, running delegates, deployed services.

This is not a workaround. It's a first-class context management capability. The session lifecycle is not linear — it's: build understanding → capture to persistent stores → launch missions → rewind to free context → leverage understanding with fresh space → repeat.

Design this as an aitools feature. Investigate:

1. **Session design patterns around rewind.** When should the user rewind? How should understanding be captured before rewind? What's the optimal rewind point (% context remaining)?

2. **The DB as time channel.** The session DB persists across rewind. Observations, decisions, OL written before rewind are readable after. How should the agent at the rewind point discover and integrate what was learned in the "future"?

3. **Delegation optimization for rewind.** At low context (2%), writing delegation prompts to scratch is overhead. At high context (60%+), it's negligible. How should delegation patterns adapt to context pressure? Lighter mechanisms at low context?

4. **What v0.67.0 shipped.** The future-timeline shipped: deleted 3 Stop hooks, JSONL event emission, /aitool-continue skill, nobulai.tools with feedback API using GitHub Issues. Read the session DB and scratch files to understand what was built.

5. **Cross-timeline learning.** The "future" learned things through failure that the "past" (current high-context window) can now act on. How does aitools formalize this? Is this related to the provenance system?

## Context

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — read Part 1 and Part 2
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/.claude/skills/investigate/SKILL.md`

Read the session DB for rewind OL entries: query `.aitools/sessions/c0dc2ddc-f.db` for observations containing '[REWIND-OL]'.

Check scratch files for work product from the future timeline — files with recent mtimes that postdate the current conversation point.

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Output

Write findings, proposals, and operational learning to the session scratch directory.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
