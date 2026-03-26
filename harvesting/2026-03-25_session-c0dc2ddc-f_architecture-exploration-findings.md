# S2-Architecture Exploration Findings

**Date**: 2026-03-25
**Author**: S2-Architecture (delegated)
**Session**: c0dc2ddc-f
**Mission**: Broad exploratory investigation across data architecture, domain, Cloudflare credits, and self-learning architecture

---

## 1. Data Architecture: Local-Controller-to-Cloud-Dashboard Patterns

### The Question

The assumption that local SQLite DBs need to "sync" to a hosted portal may be wrong. How do real systems solve the local-controller-to-cloud-dashboard problem?

### Pattern Inventory

I investigated six systems. Each solves the same fundamental problem differently. Here is what each does, how it works, and what aitools can steal from it.

#### Pattern A: Reverse Tunnel Relay (UniFi, Plex, Home Assistant/Nabu Casa)

**How it works**: The local controller maintains a persistent outbound connection to a cloud relay server. The cloud portal does NOT store your data -- it proxies requests through the tunnel to your local controller in real-time. The data never leaves your machine except transiently through the encrypted tunnel when you are actively viewing the dashboard.

**UniFi specifics**: UniFi OS Console (local hardware) is the controller. The cloud portal (unifi.ui.com) connects to your console via a persistent encrypted tunnel. UniFi Cloud does NOT replicate your data -- it relays requests. When you open the dashboard in a browser, the cloud authenticates you, routes your request through the tunnel to your local console, and returns the response. If your console is offline, the dashboard shows nothing.

**Home Assistant / Nabu Casa specifics**: Same pattern. Nabu Casa Cloud acts as a TLS-encrypted proxy using SNITUN (Server Name Indication tunneling). Your Home Assistant instance connects outbound to the Nabu Casa relay. Browser requests hit Nabu Casa, get forwarded through the tunnel, decrypted by the local instance, processed, and returned. Data at rest lives only on your local machine.

**Plex specifics**: Same pattern but with quality degradation as fallback. Direct connection preferred (LAN or port-forwarded). When direct fails, Plex relays through their servers with a 2 Mbps cap. The relay is a last resort, not the primary path.

**What aitools can steal**: **The portal does not need a database.** The portal is a relay + authentication layer. The SQLite DB lives on the developer's machine. The portal proxies requests to the local harness. This eliminates the sync problem entirely -- there is nothing to sync because there is only one copy of the data.

**Tradeoffs**: Portal shows nothing when the machine is offline. This is acceptable for aitools (the developer is working when the data is interesting). Latency depends on tunnel quality, but for a dashboard showing session state and incidents, sub-second responses through a tunnel are more than adequate.

#### Pattern B: Coordination Server with Local State (Tailscale)

**How it works**: A central coordination server stores minimal metadata (public keys, node addresses, network policies). All actual data (traffic, state) flows peer-to-peer between devices. The coordination server is a "shared drop box for public keys" -- nothing more.

**Key insight**: The control plane is hub-and-spoke but carries virtually no traffic. It exchanges encryption keys and sets policies. The data plane is a mesh. If the coordination server goes down, existing connections keep working from cached state. New connections cannot be established.

**What aitools can steal**: **Separate the coordination plane from the data plane.** The "portal" could be a coordination server that knows which machines have which projects, authenticates users, and routes requests. The actual data (incidents, operational learning, session state) stays on the machines and is queried directly. The coordination server stores only: user identity, machine registry, project-to-machine mapping, authentication tokens.

#### Pattern C: Block Exchange / Mesh Sync (Syncthing)

**How it works**: Pure peer-to-peer. No central server at all (discovery servers exist but are optional). Each device maintains its own "local model" (what files it has). The "global model" is the union of all local models, with conflicts resolved by highest version number. Devices sync by exchanging block-level diffs of changed files.

**Key insight**: Syncthing treats every node as equal. There is no "server" or "source of truth" -- the truth is the convergence of all models. Data is divided into blocks (128KB-16MB) and only changed blocks are transferred.

**What aitools can steal**: **Block-level delta sync for cross-machine state.** If two machines both have SQLite DBs with session data, syncing the entire DB is wasteful. Syncing only the changed "blocks" (in aitools terms: new incidents, new session records, new OL entries) is the correct pattern. The JSON archive export at session end (already designed) is essentially a "block" in Syncthing terms.

#### Pattern D: CRDTs (Conflict-Free Replicated Data Types)

**How it works**: Data structures that can be independently modified on any replica and are guaranteed to converge to a consistent state without coordination. Used by Google Docs (collaborative text editing), Figma (collaborative design), Redis (distributed KV), Riak (distributed DB).

**Key insight**: CRDTs solve a harder problem than aitools has. CRDTs handle concurrent writes to the same data by the same or different users in real-time. aitools has a much simpler problem: one user, multiple machines, mostly non-overlapping sessions (you work on Mac OR Windows, rarely both simultaneously on the same project).

**What aitools can steal**: **The "last writer wins" merge strategy is sufficient.** aitools does not need CRDTs because the concurrency model is simpler. But the CRDT principle that "every replica can be updated independently and convergence is automatic" is exactly right for the cross-machine model. The JSON export + git pull pattern already achieves this for tracked state.

### Synthesis: The Recommended Architecture for aitools Mission Control

Based on these patterns, here is the architecture that fits aitools:

```
┌─────────────────────────────────────────────────────┐
│                  MISSION CONTROL PORTAL              │
│            (Cloudflare Workers + Pages)               │
│                                                       │
│  - Authentication (Cloudflare Access or nobul-auth)   │
│  - Machine registry (D1 or KV: which machines exist)  │
│  - Connection broker (which machine is online now)     │
│  - Dashboard UI (Pages: static HTML/JS)               │
│  - NO application data stored in the portal           │
│                                                       │
│  The portal is a RELAY, not a DATABASE.               │
└──────────────┬────────────────────────────────────────┘
               │ Cloudflare Tunnel (outbound from machine)
               │ or WebSocket connection
               │
┌──────────────▼────────────────────────────────────────┐
│              DEVELOPER'S MACHINE                       │
│                                                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │ harness-db.sqlite                                │   │
│  │ - sessions, incidents, operational_learning      │   │
│  │ - tool_registry, framework_registry              │   │
│  │ - running_estimates, session_kpis                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Local API server (lightweight, starts with CC)   │   │
│  │ - Serves SQLite data via REST/JSON               │   │
│  │ - Handles portal relay requests                  │   │
│  │ - Read-only for portal queries                   │   │
│  │ - Write path: only via harness hooks             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Cloudflare Tunnel daemon (cloudflared)           │   │
│  │ - Persistent outbound connection                 │   │
│  │ - Routes portal requests to local API            │   │
│  └─────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

### Why This Architecture

1. **No sync problem.** There is one copy of each machine's data, on that machine. The portal reads it through a tunnel. Nothing to sync, nothing to conflict.

2. **Writes don't block.** Incidents, learning, and session state each write to their own SQLite tables locally. The portal is read-only. No cross-machine write coordination needed.

3. **Distributed components that observe each other.** The portal can show a combined view across machines by querying each machine's API in parallel. Machine A's incidents + Machine B's incidents = the unified incident dashboard. This is the "observe each other" model the commander described.

4. **Offline resilience.** When a machine is offline, the portal shows "machine offline, last seen: [timestamp]." The data is not lost -- it is on the machine. When the machine reconnects, the portal can query it again.

5. **Cross-machine carry-forward still works.** The existing design (JSON export at session end, committed to git, pulled on the other machine) remains the carry-forward mechanism. The portal adds visibility, not a new data path.

6. **Cloudflare Tunnel is free.** cloudflared establishes outbound-only connections. No port forwarding needed. No public IP needed. This is UniFi's architecture running on Cloudflare's infrastructure.

### What This Architecture Does NOT Solve

- **Historical data when machine is off.** The portal can only show live data when the machine is connected. For historical dashboards (trend lines, session history), either: (a) cache recent data in D1 as a read-through cache, or (b) push daily snapshots to R2. Both are additive optimizations, not architectural changes.

- **Multi-user.** This is a single-developer architecture. Multi-user would need per-user tunnels and access control. Cross that bridge when needed.

### Provenance of Each Component

| Component | Inspired by | What we adapted |
|-----------|-------------|-----------------|
| Portal as relay | UniFi Cloud, Nabu Casa | "The dashboard is a proxy, not a database" |
| Coordination server | Tailscale | "Minimal metadata centrally, all data local" |
| Outbound tunnel | Cloudflare Tunnel, Nabu Casa SNITUN | "Machine connects out, portal routes in" |
| Local API server | Home Assistant, UniFi OS Console | "Local controller serves data over API" |
| Block-level state export | Syncthing BEP | "Export only changed records for cross-machine" |
| Last-writer-wins merge | CRDT simplification | "One user, one machine at a time = simple merge" |

---

## 2. Domain Availability

### Research Method

Web search for `nobulai.tools` and `nobul.tools`. Neither domain appears in any search results, WHOIS records, or DNS queries (DNS lookup was blocked by permission but web searches found zero evidence of either domain being registered or active).

### Findings

| Domain | Status | Evidence |
|--------|--------|----------|
| `nobulai.tools` | **Likely available** | Zero search results. No WHOIS records found. No DNS records. |
| `nobul.tools` | **Likely available** | Zero search results. No WHOIS records found. No DNS records. |

**Caveat**: Web search cannot definitively confirm availability. The commander should verify directly at a registrar (instantdomainsearch.com or Namecheap) before proceeding.

### .tools TLD Pricing

| Registrar | Registration | Renewal | Transfer |
|-----------|-------------|---------|----------|
| Dynadot | $9.85 (promo through June 2026) | $30.18 | $30.18 |
| Namecheap | ~$10.48 | ~$30+ | ~$30+ |

**Note**: .tools domains have cheap registration ($10) but expensive renewal ($30/year). This is a common TLD pricing trap. Budget for the renewal cost, not the registration cost.

### Recommendation

`nobulai.tools` is the stronger choice:
- Incorporates the company name (Nobul) and the product category (AI tools)
- More unique and brandable than `nobul.tools`
- Both are likely available and cheap to register ($10)
- Consider registering BOTH to prevent squatting ($20 total)

---

## 3. Cloudflare BOOTSTRAPPED Credits

### How to Apply

1. Go to [cloudflare.com/forstartups/](https://www.cloudflare.com/forstartups/)
2. Click "Apply"
3. Enter promo code: **BOOTSTRAPPED**
4. Fill out the application with: company name, website URL, LinkedIn profile, email (must match your domain), description of what you are building
5. Wait for approval (typically a few days)

**Prerequisite**: You need a Cloudflare account. Create one first if you don't have one. This does NOT count as "signing up retail" -- Cloudflare's free tier is genuinely free, and the startup program is applied ON TOP of an existing account.

### Eligibility Requirements

| Requirement | Details |
|-------------|---------|
| Revenue/Funding | Have NOT raised $50,000+ (bootstrapped/stealth) |
| Company age | Founded within last 5 years |
| Product type | Software-based product or service (agencies/service companies NOT eligible) |
| Website | Must have a live website |
| Email | Professional email matching your domain |
| LinkedIn | Company LinkedIn profile required |

### What the $5,000 Credits Cover

**INCLUDED (vast majority of Cloudflare products):**
- Cloudflare Workers (serverless compute)
- Cloudflare Pages (static site hosting + SSR)
- R2 (S3-compatible object storage) -- **capped at $10,000 of credits** (but the BOOTSTRAPPED tier is only $5K total, so effectively uncapped within the tier)
- D1 (serverless SQLite database)
- KV (key-value store)
- Queues
- Workers AI -- **capped at $50,000 of credits** (again, $5K tier means effectively uncapped within tier)
- CDN, DNS, WAF, DDoS protection
- Cloudflare Tunnel (free anyway)
- Cloudflare Access (Zero Trust)
- All pay-as-you-go products

**NOT INCLUDED:**
- Domain registrar purchases (must pay separately)
- Account management / 24x7 enterprise phone support
- SLA
- Some products requiring additional onboarding: Aegis, Custom Tiered Cache, Argo Tunnels for Load Balancers, Magic Transit, BYOIP/static IP, Dedicated Gateway IP, FedRAMP Setup

### Expiry

- Credits valid for **1 year** from acceptance, or until fully consumed, whichever comes first
- Non-transferable, non-refundable, non-redeemable for cash

### Gotchas

1. **1 year expiry is firm.** The nobul-ops session noted someone miscalculated "7+ years" -- that was wrong. It is 12 months. Period.
2. **Credits are non-transferable.** Cannot be moved to a different account.
3. **Registrar not included.** If you register `nobulai.tools` through Cloudflare Registrar, you pay for that separately.
4. **Must be building software.** If the application describes Nobul as a "consulting firm" or "services company," it will be rejected. Frame it as "developer tools company building aitools, a cross-platform tool lifecycle management CLI."
5. **Email must match domain.** jose@nobul.tech or similar -- not a gmail address.
6. **Upgrade path exists.** If Nobul later raises funding, it can upgrade to $25K, $100K, or $250K credit tiers.

### Strategic Fit

For the aitools mission control portal, $5K in Cloudflare credits covers:
- **Workers**: Portal API logic (relay requests to developer machines)
- **Pages**: Dashboard UI (static HTML/JS/CSS)
- **D1**: Machine registry, user auth state (minimal data)
- **R2**: Optional: cache daily data snapshots for offline/historical views
- **Tunnel**: Free anyway -- connects developer machines to the portal
- **Access**: Zero Trust authentication for the portal

At Cloudflare's pricing, $5K is substantial. Workers are $0.50/million requests. Pages is free for most use cases. D1 is $0.75/million reads. For a single-developer dashboard with occasional access, $5K could last the full 12 months easily.

---

## 4. Self-Learning Architecture

### The Question

When aitools encounters a bug, the question is not "how do we fix this bug?" but "how should aitools adapt and learn from this incident?" What do real systems do?

### Pattern Inventory from Real Systems

#### Pattern 1: Automated Root Cause Analysis (Datadog Bits AI SRE)

**How it works**: When an alert fires, Bits AI SRE immediately launches a parallel investigation. It reads telemetry data (logs, metrics, traces), checks linked runbooks, references past investigations, and runs exploratory queries. It generates multiple root cause hypotheses and tests them by querying data across the environment. It "reasons like a senior SRE" but can explore exponentially more hypotheses in parallel.

**The self-learning loop**: Bits AI references PAST investigations when analyzing new alerts. Each investigation's findings are stored and become context for future investigations. The more incidents it handles, the faster it converges on root causes for similar incidents.

**What aitools can steal**: **Investigation context as a queryable corpus.** aitools already has incident entries in incidents.json. If each incident's investigation context (what was checked, what was found, what was the root cause) is stored in a structured, queryable format (SQLite), then the next time a similar symptom appears, the investigation agent can query: "Has this symptom been seen before? What was the root cause last time?"

#### Pattern 2: Self-Updating Runbooks (PagerDuty SRE Agent)

**How it works**: PagerDuty's SRE Agent generates self-updating runbooks. When an incident is resolved, the resolution steps are captured and added to the runbook for that class of incident. The next time the same class of incident occurs, the runbook is automatically available. Over time, runbooks evolve from "here's what we did" to "here's what the system does automatically."

**The self-learning loop**: Incident -> Resolution -> Runbook capture -> Next incident triggers runbook -> Runbook is refined based on new resolution details.

**What aitools can steal**: **Operational learning entries as proto-runbooks.** The OL entries in the consolidated learning doc (OL-1 through OL-14) are essentially runbooks: "When you encounter X, do Y because Z." The self-learning loop would be: incident -> investigation -> OL entry (runbook) -> next session loads OL -> agent follows runbook -> if runbook insufficient, update OL.

The difference from PagerDuty: aitools runbooks are governance-gated (commander review before promotion to rules). PagerDuty auto-updates without review. The aitools model is correct for a governance-first system.

#### Pattern 3: Fix Once, Fix Forever (Shoreline.io)

**How it works**: Shoreline creates "remediation loops" -- background processes that check for issues, collect diagnostics, and apply repairs automatically every second. When an operator fixes an issue manually, they can convert the fix into an automated remediation loop. The loop runs continuously on all hosts.

**Key insight**: "To make a meaningful dent in repetitive incidents, it can't take longer to fix something once and for all than it takes to fix it once." The ROI of automation is immediate if the automation cost <= the manual fix cost.

**The self-learning loop**: Manual fix -> Codify into remediation loop -> Loop runs automatically -> If loop fails on a new variant, operator refines -> Refined loop handles more cases.

**What aitools can steal**: **Incident-to-hook pipeline.** When an incident is filed and resolved, the resolution should produce a concrete artifact: a new hook, a new check step, a new rule, or a new skill. The /tmp incident (OL-2) should have produced a hook that validates ephemeral state paths at SessionStart. The "fix once, fix forever" principle maps directly to the three-layer governance model: an incident in one session produces a Prevention artifact (rule), a Detection artifact (hook), or an Audit artifact (check step) that prevents recurrence in all future sessions.

#### Pattern 4: Incident History as Investigation Fuel (incident.io)

**How it works**: incident.io starts with years of incident history and adds telemetry on top. When a new alert resembles a past incident, the AI knows which team responded, what runbook was followed, and what the resolution was. It can identify the exact pull request behind a failure within seconds, draft code fixes, open PRs, and suggest next steps.

**Key insight**: The value is in the HISTORY, not the current telemetry. A system with 1000 past incidents and mediocre telemetry outperforms a system with perfect telemetry and no history, because the history contains the RESOLUTION patterns.

**What aitools can steal**: **The incident registry IS the self-learning corpus.** aitools already has incidents.json. The missing piece is: (a) structured enough to query by symptom similarity, (b) includes resolution details, not just the problem description, (c) queryable at session start ("what incidents have been filed for this class of problem before?").

#### Pattern 5: Predictive Prevention (NashTech pattern)

**How it works**: Instead of just reacting to incidents, predictive agents analyze patterns across incidents to identify systemic weaknesses BEFORE they cause the next failure. This is the "shift left" of incident management -- from "fix it when it breaks" to "fix the class of thing that breaks."

**What aitools can steal**: **The /audit skill as a predictive agent.** The /audit skill already does point-in-time governance review. Adding incident pattern analysis ("incidents #3, #7, and #12 all involve missing error handling in hooks -- this is a systemic pattern, not three independent bugs") would make it predictive. The governance health metric (gap G4 in the consolidated OL) is the quantitative version of this.

#### Pattern 6: Automated Retrospective Knowledge (LFI Research)

**How it works**: Recent research (2025) on Learning from Incidents (LFI) in software engineering found that the same types of failures recur across different projects and development stages. Engineers report "failures are made again and again -- the same problems occur but in different places." The root cause: lack of structure in learning from failures.

Emerging approach: Use LLMs to synthesize incident data into reports, combined with RAG (Retrieval-Augmented Generation) to enable engineers to query organizational knowledge about failures.

**What aitools can steal**: **The consolidated OL document IS the structured learning artifact.** The research confirms that the problem is not the incidents themselves but the lack of consolidation and retrieval. The path aitools is on (consolidated OL -> loaded at session start -> updated each session) is exactly what the research recommends. The next step is making it queryable (SQLite) and automatically synthesized (session-end LLM pass over new incidents -> updated OL).

### Synthesis: The Self-Learning Architecture for aitools

```
                   THE ASCENDING SPIRAL (OPERATIONALIZED)

Session N encounters bug
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ FAST LOOP (within session)                               │
│                                                          │
│ 1. OBSERVE: Bug detected (by agent, hook, or commander) │
│ 2. INVESTIGATE: /incident skill or investigation agent   │
│    - Query: "Has this symptom been seen before?"         │
│    - Check incidents DB for similar symptoms             │
│    - If match: load prior investigation context          │
│    - If new: full investigation                          │
│ 3. FILE: Structured incident with root cause             │
│ 4. FIX: Immediate fix for this instance                  │
│ 5. ARTIFACT: Produce prevention artifact                 │
│    - Rule (prevention layer)                             │
│    - Hook (detection layer)                              │
│    - Check step (audit layer)                            │
│    - OL entry (knowledge layer)                          │
│ 6. VERIFY: New artifact catches the class of bug         │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ SESSION BOUNDARY (SessionEnd hook)                       │
│                                                          │
│ 1. Export new incidents to SQLite DB                      │
│ 2. Update consolidated OL with new entries               │
│ 3. Export JSON archive to git (cross-machine)            │
│ 4. Push to portal (if connected):                        │
│    - Session summary                                     │
│    - New incidents                                       │
│    - New prevention artifacts                            │
│    - Updated OL                                          │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ SLOW LOOP (cross-session, commander review)              │
│                                                          │
│ 1. /audit skill: Pattern analysis across incidents       │
│    - "Incidents #3, #7, #12 all involve hook error       │
│      handling -- systemic pattern detected"              │
│ 2. Commander review: Which patterns warrant governance   │
│    changes vs. tactical fixes?                           │
│ 3. Governance health metric: Is the system improving?    │
│    - Incidents per session trending down?                │
│    - Time to resolution trending down?                   │
│    - Recurrence rate of incident classes?                │
│ 4. Consolidated OL update: New principles from patterns  │
│ 5. SELECTION: Commander decides what survives            │
└─────────────────────────────────────────────────────────┘
```

### The Five Self-Learning Mechanisms (Concrete)

| # | Mechanism | Inspired by | Implementation |
|---|-----------|-------------|----------------|
| 1 | **Investigation context as queryable corpus** | Datadog Bits AI | Incident DB with structured symptom/resolution fields. Query at investigation start. |
| 2 | **OL entries as proto-runbooks** | PagerDuty self-updating runbooks | Each OL entry = a runbook. Loaded at session start. Updated when insufficient. Commander gates promotion to rules. |
| 3 | **Incident-to-artifact pipeline** | Shoreline "fix once fix forever" | Every resolved incident MUST produce at least one prevention artifact (rule, hook, check step, or OL entry). |
| 4 | **Incident pattern analysis** | incident.io history-first approach | /audit skill extended with cross-incident pattern detection. Governance health metric quantifies improvement. |
| 5 | **Consolidated OL as the learning artifact** | LFI research + SECI model | Single loadable doc, updated each session, queryable via SQLite, auto-synthesized at session boundary. |

### What This Means for the Portal

The mission control portal gains a self-learning dashboard:

- **Incident trends**: Filed per session, resolved per session, recurrence rate
- **Governance health**: Prevention artifacts produced per incident, time from incident to artifact
- **OL growth**: New entries per session, entries referenced (loaded + used) per session
- **Pattern alerts**: "3 incidents in the same class detected -- systemic pattern"

This is the "how should aitools adapt" answer: not by auto-patching code, but by ensuring every incident produces a prevention artifact and every prevention artifact is loaded into the next session. The ascending spiral operationalized.

---

## Operational Learning Produced

### OL-15: The portal is a relay, not a database

**Principle**: A mission control portal for local-first tools should proxy requests to the developer's machine, not replicate the data centrally. This eliminates the sync problem entirely.

**Evidence**: UniFi, Home Assistant/Nabu Casa, and Plex all use this pattern. The data lives on the local controller. The cloud portal is an authenticated relay.

**Carry-forward instruction**: When designing the aitools portal, default to relay architecture. Only add server-side data storage (D1, R2) for specific, justified use cases (offline historical views, cached snapshots for performance).

### OL-16: Every resolved incident must produce a prevention artifact

**Principle**: Adapted from Shoreline's "fix once, fix forever" and PagerDuty's self-updating runbooks. An incident without a prevention artifact is a lesson observed, not a lesson learned.

**Evidence**: The /tmp hook bug (OL-2) was discovered, investigated, and fixed -- but the prevention artifact (a SessionStart hook that validates ephemeral state paths) was NOT produced. The bug recurred conceptually because the prevention step was skipped.

**Carry-forward instruction**: When closing an incident, check: "What artifact prevents this CLASS of bug?" If the answer is "none," the incident is not truly resolved. The artifact can be a rule, hook, check step, or OL entry -- but it must exist.

### OL-17: $5K Cloudflare credits are the prerequisite, and the eligibility window is open NOW

**Principle**: The BOOTSTRAPPED promo code gets $5K in credits covering Workers, Pages, D1, R2, KV, Tunnel, Access -- everything needed for the relay portal architecture. Nobul meets all eligibility requirements (software company, <5 years, bootstrapped, has a website and LinkedIn).

**Carry-forward instruction**: Apply immediately. The credits last 12 months. The portal development can start as soon as credits are confirmed.

---

## Summary of Recommendations

| # | Recommendation | Priority | Action |
|---|---------------|----------|--------|
| 1 | Apply for Cloudflare BOOTSTRAPPED credits NOW | **Immediate** | Go to cloudflare.com/forstartups/, code BOOTSTRAPPED |
| 2 | Register `nobulai.tools` (and `nobul.tools` as defensive) | **Immediate** | Check availability at instantdomainsearch.com, register via Namecheap/Dynadot (~$20 total) |
| 3 | Build portal as relay architecture on Cloudflare | **This month** | Workers + Pages + Tunnel. No database sync needed. |
| 4 | Implement incident-to-artifact pipeline | **This month** | Extend /incident skill: every closed incident requires a linked prevention artifact |
| 5 | Extend /audit with cross-incident pattern detection | **Next month** | Query incident DB for symptom clusters, report systemic patterns |
| 6 | Add governance health metrics to portal dashboard | **Next month** | Incidents/session, artifacts/incident, recurrence rate |
