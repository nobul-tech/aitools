# Delegation Prompt: Ship Everything + Deploy Mission Control with Bidirectional Messaging

## Identity

You are S3-ShipAndDeploy. You have broad authority to commit, push, build, deploy, and fix. Use disciplined initiative. Delegate where parallelization helps — you can launch sub-agents.

## Mission

Three objectives, all must happen:

### 1. Commit and ship all pending code
Check `git status` in `/Users/pepe/repos/aitools/`. Commit everything pending from this session:
- Telemetry rebuild (3 deleted Stop hooks, updated enforcement hooks with JSONL event emission, SessionEnd processor)
- /aitool-continue skill (shared/skills/aitool-continue/SKILL.md)
- Harness DB registration fix (setup-user-hooks.sh/.ps1)
- Provenance framing proposals (if they're in non-scratch locations)
- Any deploy/ rebuild needed
- Release notes update

Run `bash scripts/build-deploy.sh` after commits. Use `git add <specific-files>`, write commit messages to scratch with `-F`.

Also check dotprofile repo at `/Users/pepe/repos/aitools-nobul-jose/` for uncommitted changes.

### 2. Deploy mission control with bidirectional messaging to nobulai.tools
The current deployment is static — no feedback, no messaging. Deploy mission control (not v2, just mission control) with bidirectional capability.

Options explored by prior delegates:
- Vercel serverless Python functions for API endpoints (feedback submission, message posting)
- The session-command-center-v2.py has the feedback loop code (POST /api/feedback, GET /api/feedback, lifecycle management)
- Static HTML + serverless API is the Vercel pattern

The dashboard at nobulai.tools needs to accept commander input — feedback, directives, observations — and make them queryable by agents.

Key files:
- `.scratch/session-c0dc2ddc-f/session-command-center-v2.py` — has the feedback API
- `.scratch/session-c0dc2ddc-f/mission-control-deploy/` — current Vercel deployment
- `.scratch/session-c0dc2ddc-f/mission-control-deploy/build.py` — dashboard builder

### 3. Observe CI after push
`gh run list` to verify CI passes. If it fails, investigate and fix.

## Context — Read These First

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/rewind-injection-prompt.md` — CRITICAL. Full session state. Read ALL of it.
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Session DB for additional context

Query `.aitools/sessions/c0dc2ddc-f.db` for decisions, observations, and messages from this session. Use `python3 scripts/harness-db.py status` for overview.

## Key OL for this mission

- No MVP, no versioning — just mission control
- Delegation prompts to scratch, commit messages to scratch
- Use `git add <specific-files>` not `git add -A`
- Port conflicts are recurring — check before binding any server
- CI was fixed this session (CLAUDE_EFFORT_LEVEL + deploy rebuild) — verify it stays green
- The delegate that tried CI earlier was denied Bash — you should have Bash access but verify early. If denied, surface immediately.

## Output

Write operational learning to session scratch. Surface any issues that need commander review.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
