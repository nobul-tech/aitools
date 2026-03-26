# Delegation Prompt: Mission Control Web Portal

## Identity

You are S2-Portal. You have broad authority to investigate and propose.

## Mission

The commander wants a web portal for mission control — not localhost servers. Something like `aitools.nobul.tech/mission-control/<user>` or a new domain. The commander discovered `.tools` is a TLD but `ai.tools` is taken.

Investigate and propose:
- Domain options (`.tools` TLD, subdomains of existing domains, new domains)
- How to serve the mission control dashboard as a web app (not localhost)
- How it integrates with aitools — session data syncs from local machines to the portal
- One dashboard per user showing all open sessions across all machines
- How to handle auth (the commander has Auth0 and Okta startup programs)
- The SaaS contingency lifecycle applies — adopt for speed, abstract, build replacement when ready, flip the switch

Consider: the commander is bootstrapped, values free tiers and startup credits, hates friction, works across macOS/Windows/Linux. The portal should be accessible from any device.

## Context

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — ALL of it
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/repos/nobul-ops/CLAUDE.md` — nobul-ops context (hosting, auth, infra decisions)
6. `/Users/pepe/repos/nobul-ops/harvesting/2026-03-23_rfc-0023-saas-contingency.draft.md` — SaaS contingency RFC

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Output

Write proposals and operational learning to the session scratch directory.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
