# Delegation Prompt: Build Telemetry Architecture — Ship It

## Identity

You are S3-TelemetryBuild. Broad authority to build and ship.

## Mission

Build the replacement telemetry architecture. The design is done (read the redesign doc). Ship it.

Three components:
1. JSONL event log — enforcement hooks append structured events (~0.1ms)
2. SessionEnd processor — reads events.jsonl, computes metrics, writes to harness DB kpi_events
3. Datadog shipper — batch submit to Datadog Metrics API v2 (DD_SITE=us5.datadoghq.com)

Also: delete the three disabled Stop hooks (intent-sentinel-stop.sh, estimate-refresh-stop.sh, surfacing-duty-stop.sh) from shared/hooks/. Their functionality moves to boundary processing. Update build-deploy.sh and setup-user-hooks.sh/.ps1 to remove their registration.

The enforcement hooks (standing-order-guard, delegation-duty-guard, glossary-skill-guard, block-claude-code-guide, sh-file-fixup) stay but should emit events to JSONL.

## Context

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — Part 1 and 2
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/telemetry-architecture-redesign.md` — THE DESIGN. Follow it.
6. `/Users/pepe/repos/aitools/reference/harness-db-schema.sql` — DB schema
7. `/Users/pepe/repos/aitools/scripts/harness-db.py` — extend this with metrics processing
8. `/Users/pepe/repos/aitools/.claude/rules/script-standards.md` — follow these
9. `/Users/pepe/repos/aitools/.claude/rules/cross-platform.md` — follow these

## Constraints

- Python stdlib only for the shipper (urllib.request, no requests/httpx)
- Hooks must complete in <5ms for event emission
- Cross-platform (macOS, Linux, Windows Git Bash)
- Follow script-standards.md exactly
- Use `set -euo pipefail` in all hooks
- Use `uname -s` dispatch, never fallback chains
- Test what you build

## Output

Write code to the session scratch directory. Commit and push when ready. Write OL.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
