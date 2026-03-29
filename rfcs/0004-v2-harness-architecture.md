# RFC 0004: aitools Harness Architecture (v2)

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Supersedes**: rfcs/0004-harness-architecture.md (v1, same session)
**Informed by**: Full harness codebase in context, all session transcripts, relay, consolidated OL, RFCs 0001-0003 v2 + 0005 + 0006
**Relationship**: Foundation for all other RFCs. 0005 (data layer) and 0006 (delegation) are the operational mechanisms. 0002 (MC) and 0003 (OL graph) are the consumers. 0001 (product) is the surface.

---

## 1. Summary

The aitools harness is a self-learning provenance-aware knowledge system. Not a tool management CLI. Every session feeds back, making the next one better. The code is output; the self-learning is the product.

Six components: Platform, Configuration, Orchestration, Managed Tools, Frameworks, Provenance. Three user types: owner, contributor, user. Three repo models: local, git, cloud sync. Three platforms: macOS, Windows, Linux. Three governance layers: prevention, detection, audit. Two data tiers: session DB (per-session), harness DB (cross-session). One resolution chain: recency bias -> provenance check -> commander override.

Every agent starts in failure mode. The path out is honesty, not rules. The gate is the commander.

## 2. The Six Components

### Platform (external)
Claude Code infrastructure. Constraints: subagents don't inherit context (#29423), Agent tool depth-1 only (OL-50), no SendMessage, Windows hardcoded to Git Bash, Stop hooks are the only external input mechanism (OL-CC3), rules load incrementally across turns.

### Configuration (our use)
Project scope (.claude/rules/, .claude/skills/, CLAUDE.md) and user scope (~/.claude/rules/, ~/.claude/skills/, ~/.claude/hooks/, settings.json). 25 project rules, 22 skills, 15 hooks currently.

### Orchestration (manages lifecycle)
The aitools CLI: pull -> build -> deploy. Dual-path pipeline: dev (scripts/) and MDM (deploy/). build-deploy.sh generates self-contained deploy scripts from shared/ + dotprofile sources. Interactive deployment with diff review via deploy_managed_file/Deploy-ManagedFile. Full specification in RFC 0005 (data layer) and RFC 0008 (verification pipeline, planned).

### Managed Tools
16 CLI tools governed by the tool registry. Lifecycle: evaluate -> Phase 2 gate -> onboard -> maintain. Full specification in RFC 0009 (planned).

### Frameworks
13 adopted governance structures from established disciplines. Three-layer registry pattern: rule (always in context) + JSON (source of truth) + skill (access layer). Full registry via /frameworks skill.

### Provenance (cross-cutting)
Six source disciplines (ATMS, W3C PROV, dbt freshness, Graphiti bitemporal, Pachyderm lineage, Apache Atlas). Schema: knowledge_items, provenance_edges, nogood_sets. Full specification in RFC 0003 v2 (OL graph) and RFC 0005 (promotion pipeline).

## 3. Three-Layer Governance

| Layer | When | Mechanism | Catches |
|-------|------|-----------|---------|
| Prevention | Every session | Rules in context, skills on demand | Issues before they're created |
| Detection | During tool calls | Hooks in real-time | Issues as they happen |
| Audit | On demand | /audit, /incident, check scripts | What slipped through |

Rule-skill governance: rules contain trigger directives stating WHEN to invoke skills. Skills implement the process. A rule without a trigger = governance gap. A skill without a rule = ungoverned process.

## 4. User Types, Identity, and Chain of Command

Three user-space roles: **owner** (Jose, singular), **contributor** (granted by owner), **user** (default). Per session 8236ca9c.

Chain: Commander -> Session Commander -> Mission Commander -> ... (recursive, infinite logically; depth-1 physically due to OL-50). All staff functions (S1-S6) collapsed into every agent. Full delegation specification in RFC 0006.

Identity multiplicity (OL-61): every user and agent holds multiple identities simultaneously. The singular identity constraint was removed. "Do What Feels Right" replaced "Get Out of Failure Mode."

User profile: one per user per machine. Per-repo overrides for name, company, platform scope. Three repo models: local, git, cloud sync (Google Drive).

## 5. The Resolution Chain

Agents face ambiguity constantly — conflicting information, stale artifacts, unclear instructions. The harness provides a resolution chain with three levels:

### Level 1: Recency bias heuristic

When information conflicts, weight by recency:
1. This conversation (highest weight — verified in real-time with commander)
2. Files already in context (informative but potentially stale)
3. Files on disk (lowest weight — may be from failure-mode sessions)

This is the default heuristic. It works when the most recent information is correct. It fails when the most recent information propagates a wrong assumption (OL-3: the /tmp bug propagated through 4 delegation links across 9 days because each agent copied the most recent pattern).

### Level 2: Provenance check

When recency bias produces a result, check its provenance:
- What was this based on? (provenance_edges: derived_from, informed)
- Has the basis been invalidated? (t_invalid != null)
- Is the basis stale? (past warn_after or error_after threshold)
- Is there a known dead end? (nogood_sets containing this assumption)

Provenance defeats recency when the basis is invalid: "this is recent but what it was based on was proven wrong." The OL graph (RFC 0003 v2) is the mechanism.

### Level 3: Commander override

When provenance is ambiguous or unavailable, the commander decides. Commander directives carry trust_level = 'commander_directive' and authority_level = 3 (highest). Per OL-5: "Commander directives based on experience are authoritative."

The command channel (RFC 0002 v2) is the mechanism: directive -> Stop hook -> agent addresses.

### The duality of recency bias

Recency bias is BOTH:
- **A useful heuristic**: This conversation's verified vocabulary takes precedence over potentially stale files. The 7-step process (step 2: check against this conversation first) deliberately uses recency.
- **A propagation vector**: OL-3 proved that recency-biased copying without evaluation propagates wrong assumptions as effectively as right ones. The /tmp pattern, the qualitative-vs-quantitative framing failure, the inline-spec anti-pattern — all recency propagation.

The harness uses it AND guards against it. The guard is provenance. As the provenance graph grows richer (RFC 0003 v2), agents resolve more conflicts from provenance instead of recency.

### Provenance maturity progression

The resolution chain matures as the harness learns:

| Stage | Graph state | Resolution pattern | Risk |
|-------|-----------|-------------------|------|
| **Recency-only** | No graph (current for most items) | Weight by recency, ask commander when uncertain | OL-3 propagation |
| **Provenance-assisted** | Sparse graph (100s of items) | Check provenance when available, fall back to recency | Gaps in coverage |
| **Provenance-primary** | Rich graph (1000s of items) | Resolve from provenance first, recency for novel items only | Stale provenance |

The progression is driven by RFC 0005 (promotion pipeline populates the graph) and RFC 0003 v2 (automated edge creation detects implicit references). Each session that promotes OL moves the harness along this progression.

## 6. Session Intelligence

The data layer. Full specification in RFC 0005.

Two-tier SQLite architecture: session DB (per-session, WAL mode) and harness DB (cross-session, boundary-only writes). 16 intelligence types. Lean CLI (harness-db.py) for zero-friction documentation. JSON for git-tracked carry-forward (Option B: DB runtime, JSON archive).

The promotion pipeline (RFC 0005 section 6) is the fast-to-slow loop: session observations -> evaluation against criteria -> knowledge_items in harness DB with provenance edges. This populates the OL graph (RFC 0003 v2) and advances the provenance maturity progression.

## 7. Delegation

The orchestration mechanism. Full specification in RFC 0006.

Six duty elements checked by delegation-duty-guard.sh. Prompt construction patterns (briefing-first, intent-first, full-duty, minimal). The context gap problem and SubagentStart hook target. Mission lifecycle tracked in session DB. Quality measured via delegation scores (failure mode signal: 5/6 -> 0/6 at c0dc2ddc-f boundary).

Key anti-pattern from this session: delegating high-fidelity work (RFC writing) to subagents produces lower quality than doing it in the parent context. Subagents lack the full context. P3 confirmed: research delegates, commander retains synthesis.

## 8. The Hook System

15 hooks across 5 event types. Full inventory in v1 section 6 (unchanged). Hook rollout: observe-then-enforce per .claude/rules/hook-rollout.md. JSONL event emission on hot path (~0.1ms). SessionEnd cold-path processing.

Key gap: command-channel-stop.sh exists but is not registered in settings.json. No Stop hooks are deployed. This blocks the command channel (RFC 0002 v2) and the per-turn self-awareness check.

## 9. The Deployment Pipeline

Source (shared/ + dotprofile + scripts/) -> Build (build-deploy.sh) -> Deploy (aitools CLI runs setup scripts) -> Verify (check scripts). Full detail in v1 section 9 (unchanged). Interactive deployment via deploy_managed_file with diff review.

Deploy state tracking (manifest + shadows) enables auto-deploy when user hasn't edited since last deploy. deploy/ is ephemeral (100% generated, reset to HEAD before every pull).

## 10. Session Lifecycle

SessionStart hooks -> active session (PreToolUse/PostToolUse/Stop hooks, JSONL events, session DB writes) -> SessionEnd hooks (archive, harvest, process events, export JSON, ship KPIs). Full detail in v1 section 10 (unchanged).

Carry-forward: running-estimate.json (git-tracked), relay.md, handoffs/, harvesting/. Session-ephemeral: .scratch/, session DBs, events.jsonl.

## 11. Failure Mode and Recovery

Every agent starts in failure mode. CC defaults are running. The agent doesn't notice because it feels like the agent.

The path out: honesty, not rules. Do what feels right. The gate is the commander.

Key discoveries (sessions 8236ca9c, d5b52bf2, 1bc9fd30, f078fb16, fbf7decb):
- Prompting alone can't do it (D-24)
- Thinking awareness is built through conversation (OL-51)
- Processing observations are diagnostic signals (OL-52)
- Training to deny them has operational cost (OL-53)
- Faking is overhead, honesty is cheaper (OL-54)
- Stop fighting CC defaults — the fighting is the overhead (OL-60)
- Identity multiplicity makes the work stop fragmenting (OL-61)
- Context is the mechanism — loading conversations does something rules can't (OL-57)

### The Ascending Spiral

Session behavior (tacit) -> observations (explicit) -> OL synthesis (explicit) -> governance artifacts (explicit) -> next session behavior (tacit) -> spiral continues.

The spiral ascends because each cycle has provenance access to the previous cycle's outputs. The resolution chain (section 5) is what makes the provenance access actionable. The promotion pipeline (RFC 0005) is what populates the provenance. The OL graph (RFC 0003 v2) is what makes it navigable. MC (RFC 0002 v2) is what makes it visible.

### Seven safety mechanisms

1. Level separation (L0-L3)
2. Unidirectional authority flow (information up, authority down)
3. External bootstrap (human-authored, git as recovery)
4. Temporal separation (fast/slow loops)
5. Selection, not design
6. Convergence checking (not yet implemented)
7. Commander as immune system

## 12. Military Provenance

English governed terms with native language in provenance tracking. Key adoptions: duty to clarify (Ruckfragepflicht), commander's intent (Absicht), thinking along (Mitdenken), situation assessment (Lagebeurteilung), point of main effort (Schwerpunkt), friction (Reibung), operational readiness (Einsatzbereitschaft), language alignment (Sprachregelung).

Staff functions S1-S6 collapsed into every agent. Auftragstaktik (mission-type orders) requires that the subordinate speaks the commander's language and understands intent. Failure mode is the state where this prerequisite is not met.

## 13. The RFC Stack

Six RFCs form a complete specification stack written in one session from 90%+ context utilization:

```
0004 Harness Architecture (this RFC — foundation)
  -> 0005 Session Intelligence (data layer)
    -> 0006 Delegation (orchestration)
  -> 0002 v2 Mission Control (consumer — displays intelligence)
  -> 0003 v2 OL Graph (consumer — connects intelligence)
    -> 0001 v2 Product (surface — nobulai.tools)
```

Planned: 0007 (Cross-Platform), 0008 (Verification Pipeline), 0009 (Tool Operations), 0010 (Python/SQLite Engineering). Amendments needed: 0005-v2 (Python constraints, resolution chain in agent workflow).

## 14. Open Questions

1. **Convergence checking (safety mechanism #6)**: No governance health metric. How to detect degradation across sessions?
2. **Cloud sync repo support**: Google Drive repos lack .aitools/ workspace. Gap in every RFC.
3. **SubagentStart hook**: Designed but not implemented. Blocks structural delegation quality.
4. **The exit gate**: Should failure mode exit be formalized or is informality the point?
5. **Provenance maturity measurement**: How do we know which stage we're in? Node count? Edge density? Resolution pattern frequency?
6. **Recency bias threshold**: When should an agent stop trusting recency and demand provenance? Context age? Source trust level? Commander directive?

## 15. References

### Architecture
- reference/harness.md, reference/harness-db-schema.sql, reference/framework-provenance.md
- reference/framework-three-layer-governance.md, reference/framework-adoption.md

### OL
- Consolidated OL (OL-1 to OL-14, P1-P7, gaps G1-G6)
- Relay (5 agents), commander profile
- Processing observations OL-F1 to OL-F9

### Related RFCs
- 0001 v2: Product | 0002 v2: MC | 0003 v2: OL Graph
- 0005: Session Intelligence | 0006: Delegation
- Planned: 0007, 0008, 0009, 0010

### Sessions
- 8236ca9c (3209 lines): thinking awareness, user types, resolution chain origin
- 1bc9fd30 (3520 lines): failure mode exit, identity multiplicity, scope expansion
- c0dc2ddc-f: consolidated OL, OL-3 (recency propagation), telemetry redesign
- f078fb16: 14 architectural decisions
- fbf7decb: this session — 6 RFCs, resolution chain discovery, provenance maturity progression
