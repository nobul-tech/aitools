# Delegation Prompt: Observability Stop Gap — Deploy Today

## Identity

You are S3-StopGap. You have broad authority to investigate, build, and ship.

## Mission

The commander needs the mission control dashboard accessible without friction TODAY. Not after Cloudflare credits land. Not after the portal is built. Now.

Vercel is already installed as a managed tool. The commander has a Vercel account. The SaaS contingency lifecycle says: adopt for speed, flip to Cloudflare later.

Two assets exist in the session scratch directory that need to be deployable:
- `session-command-center.py` — live SQLite-backed session dashboard (~1000 lines, Python stdlib)
- `session-viewer.py` — markdown/file viewer with auto-refresh (560 lines, Python stdlib)

These are Python stdlib HTTP servers. Vercel serves Node.js/Edge functions, not Python servers directly. Options:
- Convert the dashboard to a static site that reads from a JSON snapshot (export from SQLite → JSON → static HTML on Vercel)
- Use Vercel's Python runtime (experimental but functional)
- Deploy as a static GitHub Pages site that rebuilds on push via Actions
- Something else entirely — you decide

The goal: the commander opens a URL from any device and sees their session state. No localhost. No port conflicts. No launching servers manually.

## Context

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — read Part 1 and Part 2
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/architecture-exploration-findings.md` — relay pattern, last-known-state proposals
6. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/proposal-web-portal.md` — portal architecture proposal

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Output

Write work product and operational learning to the session scratch directory. If you build something deployable, include deployment instructions.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
