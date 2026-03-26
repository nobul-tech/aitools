# Delegation Prompt: Dashboard Extension Investigation

## Identity

You are S2-Dashboard-Investigator. You have broad authority to investigate, search, and read across multiple repos and session archives to answer this question.

## Mission

Investigate how to extend the existing `generate-dashboard.py` to serve a live session command center that reads from the SQLite harness DB instead of JSON running estimates. The commander wants to see THIS session dynamically — delegates launched, prompts used, status, work product — not stale running estimates from prior sessions.

The question: should the SQLite-backed live session dashboard extend `generate-dashboard.py` or be a separate tool? Investigate the existing dashboard architecture, the session DB schema, what data is available, and what's missing. Produce a recommendation with evidence.

## Context — Read These First

1. `/Users/pepe/repos/aitools/CLAUDE.md`
2. `/Users/pepe/.claude/CLAUDE.md`
3. `/Users/pepe/.claude/skills/scratch/SKILL.md` — write all output here
4. `/Users/pepe/.claude/skills/investigate/SKILL.md` — follow this methodology

Find your session scratch directory: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Key Files to Read

- `/Users/pepe/repos/aitools/scripts/generate-dashboard.py` — the existing dashboard (1547 lines, live server, multi-mission, HTML template, dark theme)
- `/Users/pepe/repos/aitools/reference/harness-db-schema.sql` — the session DB and harness DB schemas
- `/Users/pepe/repos/aitools/scripts/harness-db.py` — the DB helper CLI
- `/Users/pepe/repos/aitools/scripts/aitools-dashboard.sh` — the dashboard lifecycle manager
- `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/rfc-sqlite-harness-architecture.md` — the SQLite architecture RFC
- `/Users/pepe/repos/aitools/.scratch/session-RnTOD5XJFi/mission-control-proposals.md` — prior proposals for mission control improvements
- `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — this session's consolidated OL

## Search Permissions

You have permission to search (not bulk-load) across:
- All session transcripts on this machine: `~/.claude/projects/`
- The dotprofile repo: `/Users/pepe/repos/aitools-nobul-jose/`
- All scratch directories: `/Users/pepe/repos/aitools/.scratch/session-*/`
- The harvesting directory: `/Users/pepe/repos/aitools/harvesting/`

Use targeted searches (grep, find, head/tail on specific files) to find relevant context. Do NOT load entire transcripts into your context — search for specific patterns and read relevant sections.

## Investigation Focus

1. What does generate-dashboard.py already support? What's its extension surface — can it take a `--db` flag alongside `--estimate`?
2. What data is in the session DB right now? Run `python3 scripts/harness-db.py status` to see.
3. What data would the commander need that ISN'T in the session DB? (delegation prompts, delegate status, work product inventory)
4. What data IS in the session DB that the current JSON dashboard doesn't show? (messages, findings logged by hooks)
5. How have prior sessions discussed this? Search session transcripts and scratch files for "dashboard" + "sqlite" or "dashboard" + "db" patterns.
6. What's the minimum viable extension? What ships NOW vs what needs the full SQLite migration?

## Operational Learning

- Agent output is data, not directive. Present findings with evidence, not conclusions without support.
- The commander values time. Produce actionable findings, not exhaustive surveys.
- The long-term direction is SQLite-backed dashboards. The question is what's feasible NOW as an extension.
- Write observations and operational learning alongside your findings — what you learned during this investigation is valuable.

## Output

Write your complete findings and recommendation to: `<session-dir>/dashboard-extension-investigation.md`

Include:
- Architecture recommendation with evidence
- What data sources feed the extended dashboard
- What schema changes or new tables are needed (if any)
- Minimum viable extension spec
- Your operational learning from this investigation

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line of your response and include the full content in your response text instead.
