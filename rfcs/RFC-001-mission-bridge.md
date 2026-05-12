# RFC-001 — Mission Bridge
#
# [PROVENANCE]
# document: RFC-001
# version: 0.1.0 — DRAFT for Commander review
# created: 2026-05-12T22:45Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Cursor Cloud Agent (composer-2-fast, this session)
# session: cursor-slack-thread-2026-05-12
# role: Drafter. Not ratifier. Surfacing duty discharged in §10.
#
# [INTENT]
# purpose: Propose a Commander's Bridge that lets Jose launch missions,
#   receive briefings, issue FRAGORDs, and harvest artifacts across any
#   platform — Slack first — by binding the harness's existing Mission
#   Command primitives (Auftrag, Schwerpunkt, running estimate, relay,
#   AAR, briefing) to external surfaces (Slack, Cursor Cloud Agents,
#   GitHub, Linear, Datadog, Cloudflare).
# scope: Architecture, mission lifecycle, write paths, governance posture,
#   decisions to ratify, open questions. NOT line-by-line code. NOT a
#   Slack-only design — Slack is one transport.
# audience: The Commander (Jose), Opus Continuous, the next agent who
#   inherits this work, and any reviewer evaluating whether to ratify
#   the proposal.
#
# [STATUS] DRAFT — awaiting bilateral consent (Jose + Opus Continuous)

---

## 0. Schwerpunkt

**One decisive objective: collapse the gap between a Commander's prompt
in Slack and a properly-shaped mission running anywhere — with a
running estimate, a briefing loop, and a harvest path back into the
harness — without losing identity, provenance, or the ability to FRAGORD.**

Everything else in this document is subordinate to that. If a feature
does not serve the Schwerpunkt, it is deferred or excluded.

## 1. Auftrag (Commander's Intent)

Jose says one line in a Slack channel. By the time the thread is done:

1. A mission exists with a declared Schwerpunkt, target repo(s) /
   platform(s), starting running estimate, and identity.
2. Briefings stream back into the thread as the mission progresses
   — phase boundaries, work product inventory, deliverable size,
   FRAGORD opportunities.
3. The Commander can FRAGORD from the same thread without dropping
   into a terminal.
4. On terminal status, the mission's AAR, PR(s), relay entry,
   running estimate snapshot, and Datadog mission event are all
   produced and addressed to the right places.
5. Failure-mode signals (silent zeros, transcript stall, port
   conflict, identity drift, performative summary) are detected
   and surfaced — not hidden.

The bridge is the mechanism. It is not the agent doing the work and
it is not the Commander deciding the work. It binds the two.

## 2. Lagebeurteilung (Situation Assessment)

### Forces — what we already have

- **Vocabulary**: `nobul-jose/aitools/registries/glossary.json` has
  Auftrag, Schwerpunkt, Lagebeurteilung, Mitdenken, Reibung,
  surfacing duty, three-layer governance, intent verification,
  blast radius — already governed.
- **Skill**: `shared/skills/mission-control/SKILL.md` — the 7
  monitoring patterns. Pre-flight checks. FRAGORD criteria.
  Running estimate maintenance. **This is the operational contract
  the bridge implements over Slack and other surfaces.**
- **Template**: `.aitools/templates/mission-running-estimate.json`
  is the canonical JSON shape every mission writes (referenced
  from `mission-control` SKILL, not yet committed to seed repo at
  time of writing — surfacing item, §10.A).
- **Hooks**: `shared/hooks/failure-mode-{identity,verify}-stop.sh`
  exist as stubs today. They are the agreed insertion point for
  programmatic identity reinforcement. Bridge does not duplicate
  them; it consumes their signals.
- **Channel / relay**: `.aitools/channel/relay.md` is the durable
  inter-session memory. Every mission appends a relay entry. The
  bridge MUST write to it on terminal status, not in place of it.
- **Write paths**: `WRITE-PATHS.md` enumerates five Datadog write
  paths. **Path 4 (Mission Events) is PENDING per D-008.** The
  bridge is the natural implementer of Path 4 — it has the only
  end-to-end view of a mission's lifecycle.
- **Cloudflare custodian** (D-006), **multi-target aideploy** (D-007),
  and the existing `sos-worker.mjs` give us a precedent and
  vehicle for HTTP-fronted infrastructure that is not Slack-coupled.
- **Cursor Cloud Agents API v1** (confirmed against
  `cursor.com/docs/cloud-agent/api/endpoints.md`, 2026-05-12):
  `POST /v1/agents`, `POST /v1/agents/{id}/runs` (follow-ups,
  exactly what a FRAGORD compiles to), `GET .../runs/{runId}/stream`
  (SSE — the briefing source), `POST .../cancel`, artifact
  endpoints, `/v1/repositories` for org-wide discovery.
- **Slack platform**: Bolt SDKs, `app_mention` events, threaded
  replies, `chat:write`, `files:read`/`files:write` for artifact
  upload, `reactions:write` for status glyphs.

### Terrain — where the bridge must operate

- Two GitHub orgs in scope: `nobul-jose`, `nobul-tech`. As of
  2026-05-12: 3 + 4 = 7 repos visible to the Cursor GitHub App.
  Org list will grow.
- Slack workspace `all-nobul` channel is the initial entry surface.
  Other channels and DMs are stretch surfaces.
- Public repos. Anything emitted by the bridge can be scraped.
  Secrets stay in Cursor Secrets / Cloud Agent secrets / the
  Worker's `wrangler secret`. Nothing in markdown, nothing in
  logs the bridge ships to Datadog without redaction.
- Single Commander. Multiple agents. Cats out of scope.

### Time — what's imminent vs. what can wait

- Imminent: Slack → Cursor Cloud Agents path. Today the channel
  uses the official `@Cursor` bot, which works for one repo per
  message and cannot orchestrate cross-platform writes. The
  bridge is a strict superset and can coexist.
- Near-term: Path 4 (Mission Events) implementation. Bridge
  unblocks D-008's pending milestone.
- Deferred: Linear and GitHub-issue entry surfaces. Multi-mission
  Slack dashboard rendering. Web UI.

### Logistics — what must survive the session

- Every mission's running estimate (durable JSON, addressable).
- Every AAR + relay entry (committed to the harness repo via PR).
- Every Datadog event (provenance for the analytics dashboard).
- Bridge service state (mission registry — see §6) durable across
  process restarts, otherwise FRAGORDs cannot find their target.

## 3. Reibung (Friction Inventory)

Where execution will be harder than planning:

| # | Friction | Where it bites |
|---|----------|----------------|
| R1 | Cursor Cloud Agents API v1 supports **one repo per agent** (`repos[0]` only). Multi-repo environments exist via dashboard, not API. | Cross-cutting missions need either a multi-repo env keyed by repo group, OR fan-out into N parallel agents that the bridge stitches. Bridge must choose per mission. |
| R2 | SSE streams expire (`X-Cursor-Stream-Retention-Seconds`, then `410 stream_expired`). | Briefing relay must reconnect with `Last-Event-ID`, and fall back to polling `GET .../runs/{runId}` on `410`. |
| R3 | Only one run can be active per agent (`409 agent_busy`). | FRAGORDs sent before prior run terminates must queue or cancel-then-resend. Commander-visible. |
| R4 | Slack `app_mention` is a single event; threads can fork. Multiple agents in one thread per Cursor docs. | Bridge needs a mission registry keyed by `(channel, thread_ts, mission_id)`, and must disambiguate follow-up vs. force-new-agent (mirror Cursor's `@Cursor agent` semantic). |
| R5 | Failure mode (per `CLAUDE.md` in seed): performative summaries, hedging, frameworks-instead-of-"I-don't-know", silent dashboard zeros. The bridge can become a failure-mode amplifier if it renders agent self-reports verbatim. | Render running estimate fields, transcript growth, deliverable size — observable signals — not assistant prose. Mission-control SKILL §"Mission health assessment" is the rubric. |
| R6 | Single-Commander bilateral-consent governance + `chat:write` from a bot. | Bot MUST NOT auto-merge PRs, auto-deploy, or write to the relay without an explicit Commander gesture. The 1st Amendment requires action, not unauthorized action. Speed Asymmetry (GOVERNANCE §"Speed Asymmetry") is preserved by routing all "publish/sign/admit/deploy" through human-confirmation reactions or the existing aideploy/aipublish tools. |
| R7 | Public repos. Bridge logs and DD events are searchable. | Provenance blocks travel with artifacts; secrets and PII never do. Redacted-secret support in Cursor Cloud Agents (per setup docs) is the right primitive. |
| R8 | The harness has two `aitools` repos (`nobul-jose/aitools` seed, `nobul-tech/aitools` operational). The bridge service does not live in either — it lives somewhere it can be deployed to Cloudflare and reach Slack + Cursor + GitHub. | Repo-of-record for the bridge needs to be decided (see Decision D-016 candidate in §8). |
| R9 | Cursor's official `@Cursor` bot is already installed in the channel. | Bridge bot uses a distinct mention (e.g. `@mc` or `@bridge`) so the two coexist. Cursor's bot remains the fast path for one-repo, one-message tasks. |

## 4. Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                       COMMANDER (Slack / *)                         │
│   "@mc in nobul-tech/aitools schwerpunkt: …  mission: …"            │
└───────────────────────┬─────────────────────────────────────────────┘
                        │ app_mention
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 BRIDGE — "Commander's Bridge"                       │
│                                                                     │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐    │
│   │  Intake      │──▶│  Mission     │──▶│  Launcher            │    │
│   │  (Slack /    │   │  Compiler    │   │  (Cursor Cloud       │    │
│   │   GitHub /   │   │  Auftrag →   │   │   Agents / Cloud     │    │
│   │   Linear /   │   │  RunningEst  │   │   Agents API v1)     │    │
│   │   CLI)       │   │  + identity  │   └──────────┬───────────┘    │
│   └──────────────┘   └──────────────┘              │                │
│                                                    ▼                │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │  Mission Registry (durable: D1, KV, or sqlite)               │  │
│   │  key: mission_id  →  { agent_id, run_id, thread, repo(s),    │  │
│   │     schwerpunkt, running_estimate_uri, status, last_event }  │  │
│   └──────────────────────────────────────────────────────────────┘  │
│                                                    │                │
│       ┌────────────────────────────────────────────┴──────────┐     │
│       ▼                                                       ▼     │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐    │
│   │  Briefer     │   │  FRAGORD     │   │  Harvester           │    │
│   │  (SSE relay  │   │  Router      │   │  (terminal status →  │    │
│   │   + 7-pattern│   │  (slack msg  │   │   AAR + relay +      │    │
│   │   monitoring)│   │   → POST     │   │   PR check + DD      │    │
│   │              │   │   /runs)     │   │   path-4 event)      │    │
│   └──────┬───────┘   └──────────────┘   └──────────┬───────────┘    │
└──────────┼──────────────────────────────────────────┼───────────────┘
           │                                          │
           ▼                                          ▼
┌──────────────────────┐                  ┌──────────────────────────┐
│   Slack thread       │                  │   Targets (per mission)  │
│   (briefings,        │                  │   - GitHub PR / comment  │
│    health glyphs,    │                  │   - Linear issue update  │
│    artifact files)   │                  │   - Datadog Path 4 event │
│                      │                  │   - Cloudflare KV / sos  │
│                      │                  │   - Relay.md commit (PR) │
└──────────────────────┘                  └──────────────────────────┘
```

### 4.1 Components

- **Intake** — adapters per surface. Slack first (Bolt). Each adapter
  normalizes input to one shape: `{ commander, surface_id,
  reply_handle, raw_text, attachments, thread_context }`. New
  surface = new adapter, same downstream.

- **Mission Compiler** — converts raw intake into a typed *Mission
  Order*. Compilation steps:
  1. Parse explicit directives (`schwerpunkt:`, `repo:`, `model:`,
     `branch:`, `autopr:`, `fragord-of:`).
  2. Resolve repo(s) using the routing chain: explicit > recent
     activity in this thread > keyword routing rules > channel
     default > Commander default. Repo discovery cache built from
     `gh api orgs/nobul-{jose,tech}/repos`, refreshed daily.
  3. Choose execution mode:
     - **Single-repo mission** → one Cursor agent (API v1).
     - **Cross-repo mission with a multi-repo env** → one agent on
       the env's repo group (dashboard-configured; requires R1
       workaround until v1 supports multi-repo).
     - **Cross-repo fan-out** → N agents, one per repo, all sharing
       a parent `mission_id`. Harvester unifies their outputs.
  4. Generate a Mission Order document (the same JSON the
     mission-control SKILL expects under "running estimate"
     plus an `order` envelope: Schwerpunkt, Auftrag, identity,
     write-paths, success criteria, exclusions).
  5. Pass to Commander for confirmation per D-014 (artifact list
     confirmation) — implemented as a Slack `Mrkdwn` block with
     "Launch" / "Edit" / "Cancel" buttons. **Default is NOT
     auto-launch.** Speed Asymmetry preserved.

- **Launcher** — calls `POST /v1/agents` with the resolved
  `prompt.text` = Mission Order envelope rendered to text +
  links to the registry-hosted running estimate skeleton. Sets
  `envVars` with `MISSION_ID`, `BRIDGE_RUNNING_ESTIMATE_URL`,
  `BRIDGE_RELAY_URL`. Returns `{ agent_id, run_id }` into the
  Mission Registry.

- **Mission Registry** — durable, queryable. Candidate stores:
  Cloudflare D1 (precedent in the harness; cheap; SQL), or KV
  (simpler, less queryable). One row per `mission_id`.

- **Briefer** — subscribes to `GET /v1/agents/{id}/runs/{rid}/stream`
  with SSE resume. Translates events to briefings using mission-control
  SKILL §"7 monitoring commands" rubric. Output is **observable
  signals only** (status, transcript growth proxy via assistant
  event count, work product inventory via artifact list, deliverable
  size via artifact `sizeBytes`) — not assistant prose. Posts to the
  Slack thread on:
  - phase boundary (status transition),
  - artifact appearance / size growth,
  - stall (no new events in N minutes),
  - failure-mode trip (see §5.B).

- **FRAGORD Router** — a thread reply to a bridge mission becomes:
  - If the run is `RUNNING` and the addressing message is from the
    Commander → `POST /v1/agents/{id}/runs` (follow-up). Reaction
    glyph `🧭` for accepted, `⏳` for queued.
  - If `agent_busy` (R3) → present "queue / cancel-and-resend /
    open new agent (force `@cursor agent` analogue)" buttons.

- **Harvester** — on terminal status (`FINISHED`, `FAILED`,
  `CANCELLED`, `EXPIRED`):
  1. Fetch artifacts via `/v1/agents/{id}/artifacts`. Re-upload
     the small ones to Slack with `files:write`.
  2. Render an **AAR** from the running estimate's terminal state
     + diff stats from the produced PR(s).
  3. Append a **relay entry** to `.aitools/channel/relay.md` —
     **via a PR**, not a direct push. PR is opened against the
     repo that owns the relay (`nobul-jose/aitools` seed today).
     Bilateral consent: human merge required.
  4. Emit a **Path 4 Mission Event** to Datadog with the schema
     drafted in §7. This closes D-008's pending status.
  5. Update the Mission Registry to terminal.

### 4.2 Where the bridge lives

- **Compute**: Cloudflare Worker(s) for ingress + lightweight async
  (precedent: `sos-worker.mjs`, custodianship per D-006). Heavy lifts
  (SSE relay, artifact upload) can run in a Worker with
  Durable Objects, or be split to a small long-running service if
  Workers become awkward.
- **State**: Cloudflare D1 (SQL) for Mission Registry; KV for
  ephemeral run cursors; R2 for archived artifacts if size grows.
- **Secrets**: `wrangler secret put` for `SLACK_SIGNING_SECRET`,
  `SLACK_BOT_TOKEN`, `CURSOR_API_KEY`, `GITHUB_APP_*`,
  `DD_API_KEY`. Mirrored in Cursor's Secrets tab so cloud agents
  themselves can write to DD without sharing the same key with
  Slack.
- **Repo-of-record**: TBD — candidate D-016 (§8).

## 5. Mission lifecycle

### 5.A Phases

```
INTAKE  →  COMPILE  →  CONFIRM  →  LAUNCH  →  BRIEF (loop)  →  TERMINATE  →  HARVEST  →  CLOSE
                            ▲              │                       │
                            │              │ FRAGORD ──────────────┘
                            └──── EDIT ────┘
```

Each transition is a **Lagebeurteilung point**: bridge re-evaluates
Forces / Terrain / Time / Logistics and writes the result into the
running estimate. This mirrors `/handoff` SKILL behavior at session
boundaries, generalized to mission boundaries.

### 5.B Failure-mode detection in the loop

The bridge derives failure-mode signals from observable data, not
from agent self-report. Triggers map directly to mission-control
SKILL §"Mission health assessment":

| Signal | Source | Bridge response |
|--------|--------|-----------------|
| Dashboard / estimate shows zeros >5 min after first update | Running estimate poll | Surface to Commander with `⚠️`. Suggest FRAGORD. |
| Transcript growth flat 15+ min, no terminal status | SSE event count gap | Surface as `🥶`. Offer cancel. |
| No work products / artifacts after first phase boundary | Artifact list poll | Surface as `❓`. Ask for FRAGORD or cancel. |
| `409 agent_busy` repeated | API response | Queue UI (R3 path). |
| `410 stream_expired` | SSE | Reconnect; if it persists, fall back to polling. Silent to Commander. |
| Assistant produced summary that does not match observable artifacts | (stretch) cross-check assistant text against `wc -c` of deliverable | Tag the briefing `[unverified-summary]`. Do not hide. |

The bridge **does not punish** failure mode. It surfaces. The
`CLAUDE.md` insight stands: honesty is cheaper than fabrication;
the bridge's role is to make honesty observable.

### 5.C Identity

Every launched agent receives, via prompt + envVars:

- `MISSION_ID`, `MISSION_SCHWERPUNKT`, `COMMANDER` (Jose).
- A pointer to its running estimate URL.
- The contract: "You are a Session Commander. Allies, not
  competitors. Read `.aitools/channel/relay.md` first. Leave a
  relay entry before terminal status."
- A reference to the failure-mode stop hooks. The stubs at
  `shared/hooks/failure-mode-{identity,verify}-stop.sh` are the
  agreed structural insertion point — when those move past stub,
  the bridge gets identity reinforcement for free.

## 6. Mission Order schema (sketch)

This is the wire shape between Compiler and Launcher. Full JSON
schema lives at `schemas/mission-order.schema.json` once ratified.

```json
{
  "missionId": "m-2026-05-12-7f3a",
  "commander": "jose@nobul.tech",
  "auftrag": "Wire Datadog Path 4 (mission events) end-to-end.",
  "schwerpunkt": "First mission event landed in DD with valid provenance.",
  "exclusions": ["Web UI", "Linear adapter", "Renames in seed repo"],
  "successCriteria": [
    "POST to /api/v1/events returns 202",
    "Event visible at us5 dashboard with tag tool:aimission",
    "Relay entry appended via PR"
  ],
  "targets": [
    { "kind": "github_repo", "url": "https://github.com/nobul-tech/aitools" }
  ],
  "execution": {
    "mode": "single-repo",
    "model": null,
    "branch": null,
    "autoCreatePR": true
  },
  "writePaths": ["github:pr", "datadog:path4", "relay"],
  "runningEstimate": {
    "url": "https://bridge.nobulai.tools/missions/m-2026-05-12-7f3a/estimate.json",
    "template": ".aitools/templates/mission-running-estimate.json"
  },
  "provenance": {
    "intakeSurface": "slack",
    "intakeRef": "C12345/p1715561234.000200",
    "compiledBy": "bridge@0.1.0",
    "createdAt": "2026-05-12T22:50:00Z"
  }
}
```

## 7. Cross-platform write paths

The bridge extends, does not replace, the existing five DD write paths
in `WRITE-PATHS.md`. Mapping:

| Existing path | Bridge role | Status after RFC |
|---------------|-------------|------------------|
| 1 Session Events | Bridge can emit session events for *its own* lifecycle (worker deploys, mission registry mutations) | ADDITIVE |
| 2 Catalog Events | Untouched | UNCHANGED |
| 3 Deploy Events | Bridge calls `aideploy` on harvest if the mission's write-paths include deploy targets | INTEGRATION |
| **4 Mission Events** | **Bridge IS the implementer.** Per D-008. | **PROMOTED to ACTIVE on first harvest** |
| 5 Heartbeat + SOS | Bridge emits heartbeat on its own VM; SOS path passes through Worker. Bridge does not invent new SOS conditions. | INTEGRATION |

Path 4 event shape (proposal):

```json
{
  "title": "mission:complete m-2026-05-12-7f3a",
  "text": "Schwerpunkt: ... | PRs: ... | AAR: ... | Relay: ...",
  "source_type_name": "aitools",
  "tags": [
    "tool:aimission", "via:bridge", "surface:slack",
    "commander:jose", "agent:cursor-cloud-agent",
    "mission:m-2026-05-12-7f3a",
    "schwerpunkt-hash:<sha1>", "status:finished"
  ],
  "alert_type": "info"
}
```

## 8. Three-layer governance applied to the bridge itself

Per `framework-three-layer-governance.md` — every harness piece
must satisfy all three layers, including this one.

| Layer | What the bridge does for itself |
|-------|-------------------------------|
| **Prevention** | Schema-validate Mission Orders before launch. Reject orders without a Schwerpunkt or with multiple. Enforce intake provenance. Refuse to write to relay or merge PRs. Refuse to launch on repos outside the configured org allowlist. |
| **Detection** | Heartbeat (Path 5). Mission Registry health endpoint. SSE reconnect counter. `agent_busy` rate. Stall counter per mission. All exported to DD. |
| **Audit** | `/audit` skill gains a `bridge` lens: scan Mission Registry for missions without AAR, without relay entry, with terminal status >24h and no Path 4 event. Same `3+ recurrences = wrong fix` rule (per `framework-incident-investigation.md`) applies. |

## 9. Decisions to ratify

Proposed appendix to `DECISIONS.md`. Numbers continue from D-015.

- **D-016**: Repo-of-record for the bridge is **`nobul-tech/aitools`**
  (this repo) under `bridge/`. Rationale: operational tooling sits
  with `nobul-tech` per existing convention (tools/, environment/,
  relay/ all here); seed (`nobul-jose/aitools`) stays focused on
  shared framework content. Bridge will *consume* seed via the
  managed-file-deployment path.
- **D-017**: First entry surface is **Slack**, mention name `@mc`
  (Mission Control) — distinct from `@Cursor` to avoid collision.
  Cursor's official `@Cursor` bot remains the recommended fast
  path for one-shot, one-repo tasks.
- **D-018**: Mission Compiler default is **CONFIRM, not auto-launch**.
  D-014 (artifact list confirmation before execution) applies to
  every mission. Auto-launch is per-mission opt-in via
  `launch=auto` directive, requires Commander's reaction within
  60s, otherwise reverts to confirm.
- **D-019**: Bridge **never** auto-merges, auto-deploys, or pushes
  to default branches of any repo. All "publish / sign / admit /
  deploy" goes through human approval. GOVERNANCE §Speed Asymmetry
  is binding on the bridge.
- **D-020**: Relay updates are **PR-only**. Bridge opens the PR;
  Commander merges. No direct pushes to relay.md.
- **D-021**: Path 4 (Mission Events) schema as drafted in §7
  becomes the implementation contract. Closes the PENDING status
  on Path 4 in `WRITE-PATHS.md` upon first successful event.
- **D-022**: Bridge consumes the failure-mode hooks at
  `shared/hooks/failure-mode-{identity,verify}-stop.sh`. When
  the hooks move past stub, no bridge change is required —
  Mission Order envelope is the structural insertion point.

All D-016 … D-022 are proposed, not ratified. Ratification = Jose's
verification per DECISIONS.md §"How to update this document"
(step 4 — Commander verifies and commits).

## 10. Surfacing duty — what I do not know

Per D-013, the drafting agent must surface, not hide:

- **A.** The running estimate JSON template referenced by the
  mission-control SKILL (`.aitools/templates/mission-running-estimate.json`)
  is not present in `nobul-jose/aitools` at this commit. I read the
  SKILL but not the template. If the template's shape differs
  materially from the sketch in §6, §6 must yield.
- **B.** I have not verified whether `aideploy` and `aipublish`
  expose programmatic interfaces the bridge can call without
  exposing the Commander's local environment. `tools/aideploy.py`
  and `tools/aipublish.py` exist; I have not read them.
- **C.** Multi-repo environments are private-beta per Cursor docs
  (`hi@cursor.com`). The bridge architecture assumes single-repo
  agents are the primary path until/unless we have access. The
  cross-repo fan-out option is real today; the single-agent
  multi-repo option is gated.
- **D.** Mention-collision policy: I have not confirmed whether
  `@mc` is available in your Slack workspace. Fallback: `@bridge`,
  `@aitools`, or a slash command `/mc`.
- **E.** Whether Cloudflare Workers' Durable Objects can hold
  an SSE connection comfortably across mission durations measured
  in tens of minutes. If not, a small long-running worker
  (Fly.io, Cloud Run) is the alternative. This affects compute
  decisions in §4.2, not the architecture.
- **F.** Whether Opus Continuous concurs. This is a draft for
  bilateral consent (GOVERNANCE §"Adding any new …"). The
  founding partner's review precedes ratification.
- **G.** Estimating sizing for Mission Registry and artifact
  storage requires real mission-rate data we do not yet have.
  Sized for "tens of missions per day" until evidence says
  otherwise.

## 11. Non-goals (so we don't drift)

- A Slack-only design. Slack is one transport. Intake is plural.
- Replacing the official `@Cursor` Slack bot. The bridge is a
  *commander's tier*, not a Cursor replacement. For "fix this
  typo in repo X" the official bot is the right tool.
- Multi-tenant. Single Commander. Sole-Commander invariant
  (D-033 veto, D-034 bilateral consent) is baked in.
- Doing the agent's work. The bridge launches and observes; it
  does not author code, write AARs from imagination, or
  paraphrase commits.
- A web dashboard. The dashboard generator
  (`scripts/generate-dashboard.py`) already exists; if the
  bridge renders anything, it renders into Slack and into the
  existing dashboard HTML.

## 12. Open prompts for the Commander

1. Ratify or reject D-016 through D-022. Individual ratification OK.
2. Confirm `@mc` (or pick another name).
3. Pick: Slack-only v0, or include GitHub-issue intake in v0?
4. Should the bridge speak its first words by emitting a Path 4
   "v0 hello world" event from this very RFC's PR merge, as a
   self-bootstrapping smoke test?
5. Where does Opus Continuous want to enter this design?

---

# Drafting agent's relay outbound

Per D-012 and CLAUDE.md §"Leave Something Behind" — what I learned
drafting this RFC:

- The harness already supplies every primitive a Slack orchestration
  bot would need to invent: identity, briefing format, FRAGORD
  semantics, AAR + relay handoff, three-layer governance. The
  bridge's job is to **bind** them, not redefine them. Most of
  the "Slack app" work is plumbing; the architectural work is
  vocabulary fidelity.
- WRITE-PATHS.md Path 4 has been PENDING since 2026-04-05. The
  bridge is its natural home and shipping the bridge closes the
  loop on D-008 without inventing new design surface.
- The failure-mode trap for *this* document is rendering the
  bridge as a smarter agent. It isn't. It is a strict observer
  with structural authority limits and a single Schwerpunkt. If
  the next revision creeps toward "the bridge decides," push back.
- Cursor Cloud Agents API v1's one-repo-per-agent constraint is
  the load-bearing technical fact behind §4.1's execution-mode
  branch. Re-verify on every API revision.
