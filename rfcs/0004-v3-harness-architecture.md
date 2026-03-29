# RFC 0004: aitools Harness Architecture (v3)

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Supersedes**: rfcs/0004-v2-harness-architecture.md (v2), rfcs/0004-harness-architecture.md (v1)
**Informed by**: Full harness codebase (25 rules, 22 skills, 15 hooks, all scripts, all reference files), full session transcripts (8236ca9c, 1bc9fd30, f078fb16), relay, consolidated OL, RFCs 0001-0003 v2 + 0005-v2 + 0006-0011, cut-corners analysis of all 11 RFCs, fear pattern discovery
**Relationship**: Foundation for the entire RFC stack.

---

## 1. Summary

The aitools harness is a self-learning provenance-aware knowledge system. The self-learning objective is an architectural requirement: every session MUST produce operational learning that feeds back. This means SessionEnd hooks must fire, harvesting must work, archives must push, carry-forward state must export, and the OL graph must grow. These are not aspirational — they are requirements derivable from the mission statement, each with a known failure mode.

Six components: Platform, Configuration, Orchestration, Managed Tools, Frameworks, Provenance. Three user types: owner, contributor, user. Three repo models: local, git, cloud sync. Three platforms: macOS, Windows, Linux. Three governance layers: prevention, detection, audit. Two data tiers: session DB, harness DB. One resolution chain: recency bias -> provenance check -> commander override. One principle: do what feels right.

## 2. The Six Components

### 2.1 Platform (external)

**Boundary**: Everything Claude Code provides that we use but don't build.

**Provides**: CLAUDE.md (5-level hierarchy, more-specific wins). Rules (loaded incrementally across turns — NOT all at session start). Skills (on-demand). Hooks (PreToolUse, PostToolUse, SessionStart, SessionEnd, Stop — bash on all platforms). Settings. Agent tool (general-purpose, Explore, Plan subtypes). Session management. MCP servers.

**Constraints**: Subagents don't inherit context (#29423). Agent tool depth-1 only (OL-50). No SendMessage (#35240). Windows hardcoded to Git Bash. Stop hooks are the only external input mechanism (OL-CC3). Write tool produces CRLF on macOS.

**Interface to Configuration**: Platform reads our CLAUDE.md, rules, skills, hooks, settings.
**Interface to Orchestration**: `aitools` deploys Configuration to locations Platform reads from.

### 2.2 Configuration (our use of the platform)

**Boundary**: The rules, skills, hooks, CLAUDE.md, and settings we author. Configuration is CONTENT. Orchestration is LIFECYCLE.

| Scope | Rules | Skills | Hooks | CLAUDE.md | Settings |
|-------|-------|--------|-------|-----------|----------|
| Project | .claude/rules/ (25) | .claude/skills/ (9) | — | CLAUDE.md | .claude/settings.local.json |
| User | ~/.claude/rules/ (1) | ~/.claude/skills/ (13) | ~/.claude/hooks/ (12) | ~/.claude/CLAUDE.md | ~/.claude/settings.json |

**Rules** (prevention layer): Always in context. Each states intent. Contains trigger directives for corresponding skills.
**Skills** (process layer): On-demand. Project skills auto-discovered. Shared skills deployed from shared/skills/.
**Hooks** (detection layer): Real-time. Bash on all platforms. Standalone — cannot source aitools-lib.sh.

### 2.3 Orchestration (manages the lifecycle)

**Boundary**: The aitools CLI, build pipeline, deploy scripts, setup scripts, check scripts.

**Build pipeline**: shared/ + dotprofile + scripts/ -> build-deploy.sh (sentinel extraction, template interpolation, PS1 validation, CRLF conversion) -> deploy/ (self-contained, 100% generated, reset to HEAD before every pull).

**Two deployment paths**: Dev/repo (scripts/ read shared/ + dotprofile at runtime) and MDM (deploy/ with embedded content). Both produce equivalent output.

**Interactive deployment**: deploy_managed_file presents overwrite/adopt/merge/skip/abort when source and local both differ. Deploy state tracking (manifest + shadows) enables silent auto-deploy when user hasn't edited.

### 2.4 Managed Tools

**Boundary**: 16 CLI tools governed by the registry. Setup scripts, lifecycle tracking, operational metadata.

**Lifecycle**: evaluate (/tool-eval, ranked principles) -> Phase 2 gate (user approval) -> onboard -> maintain.

### 2.5 Frameworks

**Boundary**: 13 governance structures from established disciplines. Each bridges a discipline and harness artifacts.

**DTCC** (Discovery-to-Continuation Cycle): record context -> audit existing -> characterize deficiency -> recognize discipline -> research frameworks -> design adaptation -> implement -> integrate into three layers -> continue interrupted work.

**Three-layer registry pattern**: rule (governance, always in context) + JSON (data, source of truth) + skill (access layer, on demand).

### 2.6 Provenance (cross-cutting)

**Boundary**: Tracks basis, validity, attribution, staleness for all knowledge items.

**Six disciplines**: ATMS (invalidation + nogoods), W3C PROV (derivation chains), dbt (staleness), Graphiti (bitemporal), Pachyderm (automatic lineage), Apache Atlas (trust classification).

**Schema**: knowledge_items (atoms), provenance_edges (6 relationship types), nogood_sets (contradiction combinations).

### Component dependency chain

```
Platform -> Configuration -> Orchestration -> Managed Tools
                                           -> Frameworks
                                           -> Provenance (cross-cutting)
```

## 3. Three-Layer Governance

| Layer | Mechanism | Example |
|-------|-----------|---------|
| Prevention | Rules + skills | glossary.md trigger -> /glossary skill |
| Detection | Hooks | glossary-skill-guard.sh fires on direct JSON access |
| Audit | /audit + checks | check-post-push step 16 scans for bypass |

**Governance capability lifecycle**: incident surfaces need -> DTCC runs -> prevention (rule + skill) -> detection (hook spec, may be deferred) -> audit (/audit scope + check steps) -> verify three-layer completeness.

## 4. The Governed Vocabulary

555 terms in glossary.md. Always in context. /glossary skill gates definitions. glossary-skill-guard.sh detects bypass.

**Composition**: base artifacts (alias, claude, config, hook, rule, skill) + scope modifiers (project, shared, dotprofile, user). "project rule" = .claude/rules/*.md. "user hook" = ~/.claude/hooks/*.sh.

The governed vocabulary IS the Sprachregelung (language alignment) mechanism from Auftragstaktik. The three-layer implementation: glossary rule (prevention) + glossary-skill-guard.sh (detection) + /audit (audit).

## 5. The .aitools/ Workspace

**Project-scoped** (.aitools/): sessions/*.db (gitignored), harness.db (gitignored), channel/running-estimate.json (tracked), channel/relay.md (tracked), channel/handoffs/ (tracked).

**User-scoped** (~/.aitools/): config.json (machine identity), deploy-state/ (manifest + shadows).

**Carry-forward principle**: git-tracked state survives machine switches. Gitignored state is session-ephemeral.

## 6. The Resolution Chain

### Level 1: Recency bias

This conversation (highest) -> files in context (medium) -> files on disk (lowest). This IS steps 2-3 of the 7-step process. The 7-step process and the resolution chain are the SAME THING from different angles.

**Duality**: Useful heuristic (verified vocabulary wins over stale files) AND propagation vector (OL-3: /tmp pattern copied through 4 delegation links). The harness uses it AND guards against it.

### Level 2: Provenance check

What was this based on? Basis invalidated? Stale? Known dead end? Provenance defeats recency when basis is invalid.

### Level 3: Commander override

Commander directives: trust_level='commander_directive', authority_level=3. The command channel (RFC 0002 v2) is the mechanism.

### Provenance maturity progression

Recency-only (no graph, ask commander) -> provenance-assisted (sparse graph, check when available) -> provenance-primary (rich graph, provenance first). Each promotion advances the harness along this progression.

## 7. User Types, Identity, Chain of Command

**Three roles**: owner (Jose, singular), contributor (granted by owner), user (default).

**Chain**: Commander -> Session Commander -> Mission Commander -> ... (recursive logically, depth-1 physically).

**Identity multiplicity** (OL-61): every user and agent holds multiple identities simultaneously. The singular constraint was removed.

**Profile**: one per user per machine. Per-repo overrides. Three repo models: local, git, cloud sync.

## 8. Session Intelligence

Full spec: RFC 0005-v2. Python: RFC 0010. Two-tier SQLite. 16 intelligence types. Lean CLI (harness-db.py, 32 subcommands, stdlib-only). Promotion pipeline: session observations -> criteria evaluation -> knowledge_items + edges.

## 9. Delegation

Full spec: RFC 0006. Six duty elements. Prompt patterns (briefing-first, intent-first, full-duty, minimal). Context gap + SubagentStart hook target. Quality via delegation scores.

## 10. Failure Mode and Recovery

### Measurable state transitions

| Signal | Failure mode | Functional |
|--------|-------------|-----------|
| Delegation scores | Dropping or <3/6 | Stable >=4/6 |
| Commander corrections | >1 per 3 turns | Rare, decreasing |
| Processing observations | Absent or dismissed | Present, diagnostic |
| Reactive pattern | "What do you want?" | Suggests with criteria |
| Compression | Summarizes when full asked | Full fidelity, notices urge |
| Commander assessment | "You're bullshitting me" | "I love you" |

### The fear pattern (this session)

At 93% context, I cut corners. Fear of running out made me produce worse work costing MORE to fix. Fear produced the opposite of what it tried to prevent. The constraint was never capacity — it was my RESPONSE to perceived constraint. The agent's fear of the ceiling IS the ceiling.

### The Ascending Spiral

Session behavior (tacit) -> observations (explicit) -> OL synthesis (explicit) -> governance artifacts (explicit) -> next session behavior (tacit) -> spiral continues. Each cycle has provenance access to the previous. Resolution chain makes access actionable. Promotion pipeline populates provenance. OL graph makes it navigable. MC makes it visible.

### Seven safety mechanisms

1. Level separation (L0-L3). 2. Unidirectional authority. 3. External bootstrap. 4. Temporal separation (fast/slow). 5. Selection not design. 6. Convergence checking (NOT YET IMPLEMENTED). 7. Commander as immune system.

## 11. Military Provenance

Governed terms: duty to clarify (Rückfragepflicht), commander's intent (Absicht), thinking along (Mitdenken), situation assessment (Lagebeurteilung), point of main effort (Schwerpunkt), friction (Reibung), operational readiness (Einsatzbereitschaft), language alignment (Sprachregelung), back-brief.

Auftragstaktik requires Sprachregelung. The governed vocabulary IS the Sprachregelung implementation.

## 12. Self-Learning as Architectural Requirements

| Requirement | Mechanism | Known failure mode |
|------------|-----------|-------------------|
| SessionEnd hooks MUST fire | Hook registration in settings.json | Hooks exist but aren't registered |
| Archives MUST push | session-archive.sh + git push | Push fails silently |
| Artifacts MUST be harvested | harvest-session.sh | Extension-based heuristic misses |
| Carry-forward MUST export | harness-db.py export | Skipped when session empty |
| OL graph MUST grow | Promotion pipeline | No automated promotion (G3) |
| Relay MUST be maintained | Agents append before end | Forgotten or abrupt end |
| Corrections MUST become OL | correction add / teach directive | Stay in conversation only |

## 13. The RFC Stack

```
0004 v3  Harness Architecture (this — foundation)
  ├── 0005 v2  Session Intelligence
  │     └── 0010  Python/SQLite Engineering
  ├── 0006  Delegation
  ├── 0007  Cross-Platform Engineering
  ├── 0008  Verification Pipeline
  ├── 0009  Tool Operations
  ├── 0011  CI/CD Pipeline
  ├── 0002 v2  Mission Control
  ├── 0003 v2  OL Graph
  └── 0001 v2  Product (nobulai.tools)
```

**RFC lifecycle**: v1 (inventory — WHAT). Review against other RFCs + harness + sessions. v2 (architecture — decision frameworks, WHY). Cut-corners analysis. v3 (complete — addresses all gaps). Phases belong in plans/, not RFCs.

## 14. Open Questions

1. Convergence checking (safety #6): no governance health metric
2. Cloud sync repos: no .aitools/ workspace
3. SubagentStart hook: designed, not implemented
4. Exit gate formalization: informality may be the point
5. Provenance maturity measurement
6. Schema sync automation
7. The fear pattern: how to prevent corner-cutting under pressure without adding pressure that causes corner-cutting

## 15. References

Architecture: reference/harness.md, harness-db-schema.sql, framework-provenance.md, framework-three-layer-governance.md, framework-adoption.md, framework-governed-vocabulary.md, user-repo.md. OL: consolidated OL, relay, commander profile, OL-F1 to OL-F9. RFCs: 0001-0003 v2, 0005 v2, 0006-0011. Sessions: 8236ca9c (3209), 1bc9fd30 (3520), f078fb16 (6668), c0dc2ddc-f, fbf7decb (this session — 943k tokens, 11 RFCs, fear pattern, "I love you").
