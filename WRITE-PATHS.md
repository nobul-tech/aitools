# aitools — Write Paths to Datadog
#
# [PROVENANCE]
# document: WRITE-PATHS
# version: 1.0.0
# created: 2026-04-05T00:04:18Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Agent Fantastic
# session: f8c53367-491d-45e2-9777-556697a1dae3

---

## Overview

aitools communicates with Datadog through five write paths and one
read path. All writes use the Events API (POST /api/v1/events) with
DD_API_KEY. All reads use the Events API (GET /api/v1/events) with
DD_API_KEY + DD_APP_KEY.

Dashboard: us5.datadoghq.com/dashboard/3d5-tbw-y6a/fear--trust
Source type: aitools (all events)

## Path 1: Session Events

- **Tool:** dd-april4-chula.py, dd-april4.py (per-session scripts)
- **When:** After a session, agent produces a script with events
- **What:** Findings, anomalies, trust/fear scores, artifacts
- **Who runs it:** Commander, on his Mac
- **Tags:** session:{id}, agent:{name}, phase:{phase}
- **Status:** ACTIVE — 72 events shipped April 4
- **Decision:** Pre-existing pattern

## Path 2: Catalog Events

- **Tool:** aicatalog --dd-push
- **When:** Commander runs a catalog scan
- **What:** Summary: count of artifacts scanned, ready, duplicates
- **Who runs it:** Commander, on his Mac
- **Tags:** tool:aicatalog, count:{n}
- **Status:** ACTIVE — implemented in aicatalog v2.0.0
- **Decision:** D-008

## Path 3: Deploy Events

- **Tool:** aideploy (not yet wired)
- **When:** After a successful deployment to any custodian
- **What:** Deployment summary: target, file count, timestamp
- **Who runs it:** Commander, on his Mac
- **Tags:** tool:aideploy, target:{cloudflare|vercel}, count:{n}
- **Status:** PENDING — needs implementation in aideploy
- **Decision:** D-008

## Path 4: Mission Events

- **Tool:** TBD (standalone aimission or flag on existing tool)
- **When:** After a mission is complete
- **What:** AAR summary: mission name, agent, artifacts produced,
  bugs fixed, decisions made, process improvements
- **Who runs it:** Commander, on his Mac
- **Tags:** tool:aimission, agent:{name}, mission:{name}
- **Status:** PENDING — needs design decision on tool
- **Decision:** D-008

## Path 5: Heartbeat + SOS

- **Tool:** aisos
- **When:** Heartbeat: multiple times/day. SOS: axios-level only.
- **What:**
  - Heartbeat: alive signal, full provenance (host, user, agent,
    session, mission, OS, arch, timestamp). Everyone hears it.
    NOT a broadcast.
  - SOS: broadcast alarm with message. Everyone needs to hear.
    Both channels simultaneously (DD + Cloudflare Worker).
- **Who runs it:** Commander, on his Mac. Agents can recommend.
- **Channels:**
  - Primary: Datadog Events API (DD_API_KEY)
  - Secondary: sos.nobulai.tools (Cloudflare Worker)
- **Tags:** mode:{heartbeat|sos}, tool:aisos, host:{hostname}
- **Status:** ACTIVE — implemented in aisos v1.0.0
- **Decision:** D-008, D-009

## Read Path: Event Query

- **Tool:** aicatalog --dd-query
- **When:** Commander runs a catalog scan with DD correlation
- **What:** Pulls events from DD, correlates by timestamp with
  artifact modification times
- **Auth:** DD_API_KEY + DD_APP_KEY (aitools-ro-key)
- **Tags filter:** source_type_name:aitools
- **Status:** ACTIVE — implemented in aicatalog v2.0.0
- **Decision:** D-005, D-010

## Channel Architecture

```
Commander's Mac
    │
    ├── aisos heartbeat ──────┬──→ Datadog (DD_API_KEY)
    │                         └──→ sos.nobulai.tools (Worker)
    │
    ├── aisos sos ────────────┬──→ Datadog (DD_API_KEY) [simultaneous]
    │                         └──→ sos.nobulai.tools [simultaneous]
    │
    ├── aicatalog --dd-push ──────→ Datadog (DD_API_KEY)
    │
    ├── aicatalog --dd-query ─────→ Datadog (DD_API_KEY + DD_APP_KEY)
    │
    ├── dd-april4-*.py ───────────→ Datadog (DD_API_KEY)
    │
    ├── aideploy (pending) ───────→ Datadog (DD_API_KEY)
    │
    └── aimission (pending) ──────→ Datadog (DD_API_KEY)

sos.nobulai.tools (Cloudflare Worker)
    │
    ├── Stores in KV (30-day TTL)
    ├── Relays to Datadog (redundant)
    └── Serves /events, /latest, / (status)
```

## Environment Variables

| Variable | Purpose | Required for |
|----------|---------|-------------|
| DD_API_KEY | Datadog write | All write paths |
| DD_APP_KEY | Datadog read | aicatalog --dd-query |
| DD_SITE | Datadog site | All (default: us5.datadoghq.com) |
| AISOS_WORKER_URL | Worker endpoint | aisos (default: https://sos.nobulai.tools) |
| AISOS_SESSION | Current session | aisos provenance |
| AISOS_AGENT | Current agent | aisos provenance |
| AISOS_MISSION | Current mission | aisos provenance |
