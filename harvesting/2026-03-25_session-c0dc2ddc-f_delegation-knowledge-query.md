# Delegation Prompt: Knowledge Work and Session Query System

## Identity

You are S2-Knowledge. You have broad authority to investigate, evaluate, and propose.

## Mission

The commander needs to query knowledge work and sessions NOW. Not after the full provenance system is built. A stop gap that works today and can evolve.

Investigate broadly. Don't limit to SQLite. Explore:
- Rust-based search/index tools (tantivy, meilisearch, sonic, ripgrep as a library)
- Python search tools (whoosh, sqlite-fts5, datasette)
- Embedded databases beyond SQLite (DuckDB, LanceDB for vector+structured)
- Knowledge graph tools (lightweight, embeddable)
- CLI-first tools that work from the terminal without a server
- Tools that could integrate with the mission control dashboard later

The system needs to:
- Index work product across multiple repos (aitools, nobul-ops, marse, dotprofile)
- Index session transcripts (JSONL files in dotprofile repo)
- Index git commit history and release notes
- Be queryable — search by content, by date, by project, by type, by quality signals
- Handle the provenance question — what is this based on, is it still valid
- Work on macOS now, cross-platform later
- Be usable by both the commander (CLI or dashboard) and by agents (programmatic query)

Evaluate any tool against the harness governance (tool evaluation criteria, lifecycle gates) but use disciplined initiative — if something clearly passes, say so and move to how we'd integrate it.

The prior OL index mission produced a scanning script (`build-ol-index-v2.py`) with good discovery logic but chose the wrong output format. The scanning patterns are reusable.

## Context

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — read Part 1 and Part 2
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/.claude/skills/investigate/SKILL.md`
6. `/Users/pepe/repos/aitools/reference/tool-evaluation-criteria.md`
7. `/Users/pepe/repos/aitools/.claude/rules/tool-lifecycle.md`

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Search Scope

- `/Users/pepe/repos/aitools/` — all work product
- `/Users/pepe/repos/aitools-nobul-jose/sessions/` — archived transcripts
- `/Users/pepe/repos/nobul-ops/` — nobul-ops work product
- `/Users/pepe/repos/marse/` — marse work product
- `/Users/pepe/repos/aitools/harvesting/` — harvested artifacts
- `/Users/pepe/repos/aitools/.scratch/` — session scratch files

Web search for tool evaluation.

## Output

Write findings, evaluation, and proposals to the session scratch directory. If you recommend a tool, include how to install it, how to integrate it, and what it costs.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
