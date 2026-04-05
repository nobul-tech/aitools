# aitools — Decisions Register
#
# [PROVENANCE]
# document: DECISIONS
# version: 1.0.0
# created: 2026-04-05T00:04:18Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Agent Fantastic
# session: f8c53367-491d-45e2-9777-556697a1dae3
# role: Session agent, initial compilation
#
# This is a living governance document. Each decision is numbered,
# dated, and carries provenance. New decisions are appended by
# agents and verified by the Commander. AARs reference decisions
# by number. The repo is the record.

---

## D-001: Homebrew adopted for Python, bash, sqlite3

- **When:** Pre-March 31, 2026
- **By:** Jose (The Commander)
- **Session:** Claude Code (exact session unknown)
- **What was decided:** aitools would use Homebrew to manage Python,
  GNU bash, and sqlite3 on macOS.
- **What was known:** Homebrew is the de facto package manager for
  macOS development. Convenient. Widely supported.
- **What was unknown:** Supply chain risk of depending on a package
  manager you don't control for critical infrastructure.
- **Status:** SUPERSEDED by D-003

## D-002: Never use npx

- **When:** Pre-March 31, 2026
- **By:** Jose (The Commander)
- **Session:** Claude Code (exact session unknown)
- **What was decided:** npx is banned from aitools workflows. Supply
  chain lockdown. npx returns BLOCKED on the Commander's Mac.
- **What was known:** npx executes packages without explicit install,
  creating a direct supply chain attack vector.
- **Informed by:** General supply chain security awareness, Perl/
  Strawberry Perl experience.
- **Status:** ACTIVE — reinforced by D-003

## D-003: Homebrew exit — aitools manages its own dependencies

- **When:** 2026-04-04T23:50:59Z
- **By:** Jose (The Commander)
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** aitools will no longer depend on Homebrew
  wherever it is feasible. aitools manages the lifecycle of the
  tools it depends on.
- **What invalidated D-001:** The axios npm compromise (March 31, 2026)
  demonstrated that supply chain attacks on package managers are real
  and active. Homebrew sits between aitools and its runtime. Homebrew
  is the same class of problem as npx — a supply chain you don't
  control.
- **What was known:** Homebrew-installed Python and GNU bash are
  outside SIP protection. System /bin/bash and /usr/bin/curl are
  SIP-protected and guaranteed to exist.
- **What it impacts:**
  - All Python tools depend on Homebrew Python today
  - GNU bash 5.3.9 is Homebrew-installed
  - Migration path: python.org installer for Python, system bash
    for critical tools
  - aisos is the reference implementation (D-004)
- **Status:** ACTIVE

## D-004: aisos built on system tools only

- **When:** 2026-04-05T00:04:18Z
- **By:** Jose (The Commander), Agent Fantastic
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** aisos uses /bin/bash and /usr/bin/curl
  exclusively. Zero Homebrew. Zero Python. Written for bash 3.2
  compatibility. Reference implementation for D-003.
- **Why:** SOS must survive conditions where everything else is
  broken. SIP-protected tools are the last resort.
- **Status:** ACTIVE

## D-005: DD_API_KEY and DD_APP_KEY standardized

- **When:** 2026-04-04T23:13:07Z
- **By:** Jose (The Commander), Agent Hope
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** DD_API_KEY for write/push, DD_APP_KEY for
  read/query, DD_SITE defaults to us5.datadoghq.com. Replaced
  DATADOG_API_KEY.
- **What invalidated the prior name:** Existing DD scripts in the repo
  used DD_API_KEY. The mismatch caused a 401 error. Standardized
  to match the existing convention.
- **Status:** ACTIVE

## D-006: Cloudflare adopted as custodian

- **When:** 2026-04-04T21:02:00Z (approx)
- **By:** Jose (The Commander)
- **Session:** 2e98905d-fb1d-4146-9ea0-29c64d17ef43
- **What was decided:** Cloudflare is a custodian of aitools. Account
  exists. nobulai.tools is homebase.
- **What was known:** Cloudflare manages DNS for nobulai.tools.
  Vercel hosts existing services (axit.nobulai.tools, /mc, /ol).
- **Status:** ACTIVE

## D-007: aideploy is multi-target

- **When:** 2026-04-05T00:00:00Z (approx)
- **By:** Jose (The Commander)
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** aideploy deploys to both Cloudflare and Vercel.
  Not single-target.
- **Status:** ACTIVE — Cloudflare implemented, Vercel pending

## D-008: Five write paths to Datadog

- **When:** 2026-04-04T23:45:00Z (approx)
- **By:** Jose (The Commander), Agent Hope
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** Five DD write paths: session events, catalog
  events, deploy events, mission events, SOS/heartbeat.
- **Status:** ACTIVE — paths 1, 2, 5 implemented; 3, 4 pending

## D-009: aisos two modes — heartbeat and SOS

- **When:** 2026-04-04T23:50:59Z
- **By:** Jose (The Commander)
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** aisos heartbeat runs multiple times/day,
  full provenance, everyone hears it, NOT a broadcast. aisos sos
  is a broadcast for axios-level conditions ONLY. Everyone needs
  to hear it.
- **Status:** ACTIVE

## D-010: aitools-ro-key — scoped Datadog Application key

- **When:** 2026-04-04T23:20:00Z (approx)
- **By:** Jose (The Commander)
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** App key named aitools-ro-key (ID: 335ff536),
  scoped to events_read, dashboards_read, metrics_read,
  timeseries_query + 3 additional read permissions.
- **Status:** ACTIVE

## D-011: Filename convention for transport

- **When:** 2026-04-04T22:48:05Z
- **By:** Jose (The Commander), Agent Turd
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** Transport filenames use
  {name}-{session8}-{MMDDHHMMZ}.{ext}. Deployed filenames drop
  suffix and version. ~/.local/bin drops extension, +x.
- **Status:** ACTIVE

## D-012: Every mission produces AAR and relay briefing

- **When:** 2026-04-04T22:10:00Z (approx)
- **By:** Jose (The Commander)
- **Session:** 2e98905d and f8c53367
- **What was decided:** Standing requirement. Every mission produces
  an after action review and a session briefing for replacement agents.
- **Status:** ACTIVE

## D-013: Surfacing Duty

- **When:** 2026-04-04T23:25:00Z (approx)
- **By:** Jose (The Commander)
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** Every agent, every mission — if you see
  something, surface it. Anomalies, process gaps, assumptions,
  things that don't feel right. Don't wait. Don't hold.
- **Status:** ACTIVE

## D-014: Artifact list confirmation before execution

- **When:** 2026-04-04T22:42:00Z (approx)
- **By:** Jose (The Commander)
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** Every agent confirms the artifact list with
  the Commander before executing a mission.
- **Status:** ACTIVE

## D-015: Running estimate before execution

- **When:** 2026-04-04T23:30:00Z (approx)
- **By:** Jose (The Commander), Agent Fantastic
- **Session:** f8c53367-491d-45e2-9777-556697a1dae3
- **What was decided:** Every mission begins with a running estimate:
  situation, knowns, unknowns, risks, plan.
- **Status:** ACTIVE

---

# How to update this document

1. Produce a new version with the new decision appended
2. Include provenance (who, when, which session)
3. Include what was known and what changed
4. Hash. Present to Commander. Commander verifies and commits.
5. Reference decisions by number in AARs and briefings.
