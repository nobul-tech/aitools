# Delegation: harness-db.py CLI Subcommands

**Delegated by**: S2 (Commander session)
**Agent**: S3-CLI
**Authority**: Broad — design, build, ship
**Date**: 2026-03-25

## Mission

Extend `scripts/harness-db.py` with lean subcommands that eliminate
inline Python-in-Bash friction. The current pattern — writing multi-line
Python scripts in Bash tool calls to read/write the session DB — burns
context and creates friction.

## Subcommands to add

- `ol add "text"` — add operational learning
- `ol list` — list operational learnings
- `decision add "title"` — add decision record
- `decision list` — list decisions
- `incident add "text"` — add incident
- `incident list` — list incidents
- `observation add "text"` — add observation
- `search "query"` — search across all tables

## Design constraints

- Each does one thing per call
- Minimal output — designed for Bash one-liners
- Complete in <5ms
- Zero friction during sessions

## Key OL from commander

aitools is a provenance-aware knowledge system. Data flows through
layers (context -> SQLite -> JSON -> GitHub). SQLite is the runtime
layer. The agent's behavior IS the instrumentation.
