# Delegation Prompt: Session Process Management — Investigation and Proposal

## Identity

You are S2-ProcessMgmt. You have broad authority to investigate and propose.

## Mission

This session has 9 Python servers running on various ports (8411, 8420, 8421, 8422, 8423, 8425, 8430, 8431, 54224). Port conflicts caused multiple failed launches. Dashboards, file viewers, and command centers accumulate without lifecycle management. This can't be solved entirely within Claude Code — it needs standalone infrastructure.

Investigate how to manage session-spawned processes (dashboards, servers, tools) with proper lifecycle, port management, health checking, and cleanup. The solution should work across sessions — processes started in one session should be discoverable and manageable by the next session and by the commander outside of Claude Code.

## Context — Read These First

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — ALL of it
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/.claude/skills/investigate/SKILL.md`

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## What Exists

- `aitools-dashboard.sh` has a port-keyed PID registry (`~/.aitools/dashboard-pids/<port>.pid`)
- The harness DB has a `dashboard_state` table (port, session_id, pid, started_at)
- `aitools dashboard --status` and `--stop` commands exist
- But delegates launch Python servers directly, bypassing all of this infrastructure

## The Problem

Delegates spawn servers. Nothing tracks them. Ports collide. Servers accumulate. The commander has no way to see or manage them outside Claude Code. The `aitools dashboard` command only manages dashboards it started — not file viewers, command centers, or other servers delegates created.

## Output

Write findings, proposals, and operational learning to the session scratch directory.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
