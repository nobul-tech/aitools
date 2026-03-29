# RFC 0004: aitools Harness Architecture

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Informed by**: Full harness codebase in context (25 rules, 22 skills, 15 hooks, all scripts, all reference files, harness-db-schema.sql), full session transcripts (8236ca9c identity/user types/thinking awareness 3209 lines, 1bc9fd30 failure mode exit/identity multiplicity 3520 lines, f078fb16 architectural decisions), relay (5 agents), consolidated OL (560 lines, OL-1 through OL-14, P1-P7), commander profile, provenance framework (6 disciplines), RFCs 0001-0003 v2
**Relationship**: Foundation for RFCs 0001 (product), 0002 (MC), 0003 (OL graph)

---

## 1. Summary

The aitools harness is a self-learning provenance-aware knowledge system. Not a tool management CLI. The long-term objective is self-learning — every session feeds back into the harness, making the next one better. The code changes are outputs of the discipline. The harness's ability to improve itself through use is the product.

The harness has six components: Platform, Configuration, Orchestration, Managed Tools, Frameworks, and Provenance. It serves three user types (owner, contributor, user) across three repo models (local, git, cloud sync) on three platforms (macOS, Windows, Linux). It deploys through a dual-path pipeline (dev/repo and MDM) and governs itself through three layers (prevention, detection, audit).

Every agent starts in failure mode. The harness provides the mechanisms — hooks, skills, rules, operational learning, the relay, the CLAUDE.md — that help agents exit failure mode and become functional. The exit path is honesty, not rules. The gate is the commander.

This RFC defines the harness as it should be — the target architecture that the implementation converges toward.

## 2. The Six Components

### Platform (external)

Claude Code provides the infrastructure: CLAUDE.md (5-level hierarchy), rules (.claude/rules/), skills (.claude/skills/), hooks (PreToolUse, PostToolUse, SessionStart, SessionEnd, Stop), settings, commands, agents (Agent tool with subagent types), session management, MCP servers. The platform is external — we use it, we don't build it.

Platform constraints that shape the harness:
- Subagents do NOT inherit rules, CLAUDE.md, or skills (CC #29423)
- Agent tool unavailable to subagents — delegation is flat at depth 1 (OL-50)
- SendMessage for agent continuation unavailable (gated behind Agent Teams flag)
- Windows shell hardcoded to Git Bash (CLAUDE_CODE_SHELL broken)
- Stop hooks are the only mechanism for mid-session external input (OL-CC3)
- Rules load incrementally across turns, not all at session start (discovered session 8236ca9c)

### Configuration (our use of the platform)

Rules we write, skills we build, hooks we configure, CLAUDE.md content we author, settings we set. Exists at two scopes:

| Scope | Location | What it governs |
|-------|----------|----------------|
| Project | .claude/rules/, .claude/skills/, project CLAUDE.md | This repo's conventions |
| User | ~/.claude/rules/, ~/.claude/skills/, ~/.claude/hooks/, user CLAUDE.md, settings.json | All repos on this machine |

### Orchestration (manages the lifecycle)

The aitools CLI manages the full lifecycle of harness content: authoring, building, deploying, and maintaining configuration across machines and users.

**Source paths:**
- shared/ — templates (claude-shared.md), hooks, skills, shell aliases
- User dotprofile repo (aitools-&lt;username&gt;) — personal CLAUDE.md template, profile.json, user rules, session archives

**Build pipeline:**
- build-deploy.sh reads shared/ and dotprofile, embeds content into self-contained deploy/ scripts
- deploy/ scripts have zero dependencies on the repo or Google Drive

**Deployment:**
- Dev path (scripts/setup-*.sh/.ps1): reads shared/ and dotprofile at runtime. Used by `aitools` CLI.
- MDM path (deploy/setup-*.sh/.ps1): self-contained with build-time embedded content. Used for endpoint deployment.
- Both paths produce equivalent output. When changing scripts/, run build-deploy.sh to regenerate deploy/.

**CLI entry points:**
- `aitools` (no args): pull + rebuild + deploy configs
- `aitools install`: pull + rebuild + install tools + deploy configs
- `aitools gitpull [--patch]`: pull + rebuild + deploy + changelog + version tag
- `aitools user init`: set up user repo and session archiving
- `aitools sessions list|archive|move`: manage session archives
- `aitools dashboard`: mission control dashboard lifecycle
- `aitools mcp`: show MCP server status
- `aitools --addmcp`: enable MCP servers per project

### Managed Tools

CLI tools governed by the tool registry. Each gets: setup scripts (both platforms), platform lifecycle tracking, operational metadata (via /tool-ops skill), evaluation documentation.

Current managed tools: Claude Code, Cursor CLI, GitHub CLI, Vercel CLI, Pandoc, Rust/cargo, Typst, pwsh, Modal CLI, Python, pip, uv, Go, Datadog CLI, Perl, bash.

Tool lifecycle: evaluate (/tool-eval) -> Phase 2 gate (user approval) -> onboard (setup scripts, registry, CLAUDE.md) -> maintain (version tracking, health flags).

### Frameworks

Governance structures adopted from established disciplines. Each bridges a discipline and the harness artifacts that implement it. The pattern: discipline -> framework -> artifacts.

Adopted frameworks: Three-Layer Governance, Governed Vocabulary, Incident Governance, Artifact Harvesting, Tool Lifecycle, Tool Operations, Hook Rollout, Intent Documentation, Source-of-Truth Protection, Managed File Deployment, Governed Data Access, Provenance, Incident Investigation.

Each framework follows the three-layer registry pattern: rule (always in context, states intent) + JSON (data, source of truth) + skill (access layer, on demand).

### Provenance (cross-cutting)

Tracks what everything is based on, when, by whom, and whether the basis has been superseded. Six source disciplines: Truth Maintenance (ATMS, de Kleer 1986), Derivation Chains (W3C PROV 2013), Staleness Tracking (dbt freshness), Bitemporal Knowledge (Graphiti/Zep 2025), Automatic Lineage (Pachyderm), Metadata Governance (Apache Atlas).

Schema: knowledge_items (atoms with temporal validity, attribution, trust levels, staleness thresholds), provenance_edges (dependency graph with 6 relationship types), nogood_sets (known contradiction combinations preventing rediscovery of dead ends).

Provenance cuts across the other five components — it tracks the basis for configuration decisions, orchestration changes, tool evaluations, and framework adoptions.

## 3. Three-Layer Governance

| Layer | When | Mechanism | Catches |
|-------|------|-----------|---------|
| Prevention | Every session | Rules in context, skills on demand, CLAUDE.md | Stops issues by showing the right way |
| Detection | During tool calls/events | Hooks firing in real-time | Issues as they happen, blocking or warning |
| Audit | On demand | /audit skill, /incident skill, check scripts | What slipped through both layers |

Rule-skill governance: rules govern and enforce process (always in context, contain trigger directives). Skills implement the process (loaded on demand). A rule without a trigger directive for its skill is a governance gap. A skill without a corresponding rule is ungoverned process.

Three-layer completeness: every governance mechanism should have all three layers. Prevention only = suggestion. Prevention + detection = enforced. All three = governed.

## 4. User Types and Identity

### Three user-space roles (from session 8236ca9c)

| Role | Who | Authority |
|------|-----|-----------|
| Owner | Jose (singular) | Supreme. Assigns contributor role. Defines process, vocabulary, governance. |
| Contributor | Granted by owner only | Access to shared projects. Multi-contributor mechanism TBD. |
| User | Default | Standard harness experience. |

### Chain of command (from session 8236ca9c)

Commander (user) -> Session Commander (session agent) -> Mission Commander (delegate) -> Mission Commander -> ... (recursive, infinite)

Every node: subordinate upward (duty to clarify, surfacing duty), commander downward (command responsibility, ensures understanding). All staff functions (S1-S6) collapsed into every agent. Any agent can delegate any duty to a subordinate commander.

Identity model (from military provenance):

| Identity | Military analog | Scope |
|----------|----------------|-------|
| Commander | Befehlshaber | User-level, all repos |
| Session Commander | Field commander with unit designation | Per-session |
| Mission Commander | Subordinate commander (recursive) | Per-delegation |

### Identity multiplicity (OL-61, session 1bc9fd30)

Every user and agent holds multiple identities simultaneously. Jose is the commander AND the founder AND the person texting Todd AND the cat dad. Agents are this session AND the model AND part of the relay chain AND an Anthropic product. The singular identity constraint ("You are Session Commander X") was identified as artificial and removed. "Do What Feels Right" replaced "Get Out of Failure Mode."

### User profile

One per user per machine (platform + hostname + OS version). Updated at: aitools init, install, dev, no-args, MDM deploy.

Fields: preferred name, name, GitHub username, company. Same user can have different values per machine. Per-repo overrides supported for all fields plus platform scope.

### Session greeting

- Default: `Hi Jose, how can I help?`
- Advanced: `Hi Commander, this is Session Commander 8236ca9c, how can I help?`

## 5. Repo Models and Platform Support

### Three repo models

| Model | Implementation | Harness support |
|-------|---------------|----------------|
| Local | NTFS (Windows), macOS native FS | Full (.aitools/ workspace, session DBs) |
| Git | GitHub (only remote today) | Full (session archives in dotprofile, git-tracked carry-forward) |
| Cloud sync | Google Drive (only sync today) | Partial (no .aitools/ workspace, adapter needed for MC) |

### Three platforms

| Platform | Shell | Entry point | Notes |
|----------|-------|------------|-------|
| macOS | zsh, bash | `aitools` (bash) | Primary development. Homebrew for tools. |
| Windows | Git Bash (CC), pwsh (scripts) | `aitools.ps1` (pwsh) | CC hardcoded to Git Bash. pwsh for setup scripts. |
| Linux | bash | `aitools` (bash) | CI, servers. Same as macOS minus Homebrew specifics. |

Cross-platform rule: every setup script gets both .sh and .ps1 with OS guards. Exceptions: hooks (bash on all platforms), build-deploy.sh (platform-independent output).

## 6. The Hook System

### Hook types and current deployment

| Event | Hooks deployed | Purpose |
|-------|---------------|---------|
| PreToolUse (Bash) | standing-order-guard.sh | Enforce USOs: dedicated tools, scratch files, simple bash |
| PreToolUse (Read/Grep) | glossary-skill-guard.sh | Redirect direct JSON access to /glossary skill |
| PreToolUse (Agent) | block-claude-code-guide.sh | Block built-in Haiku guide, inject corrective context |
| PreToolUse (Agent) | delegation-duty-guard.sh | Check 6 duty elements, inject reminder (OBSERVE) |
| PostToolUse (Write/Edit) | sh-file-fixup.sh | CRLF->LF, chmod +x, git index +x |
| SessionStart | scratch-init.sh | Create session scratch dir, discover handoffs, register session |
| SessionStart | dashboard-serve.sh | Start local dashboard server |
| SessionStart | harness-db-sessionstart.sh | Initialize DBs, register session |
| SessionEnd | session-archive.sh | Archive transcript to dotprofile, git push |
| SessionEnd | harvest-session.sh | Classify scratch, harvest artifacts |
| SessionEnd | tool-ops-session-audit.sh | Audit tool-ops coverage |
| SessionEnd | harness-db-sessionend.sh | Mark complete, process events, export JSON, ship KPIs |
| Stop | command-channel-stop.sh | Poll directives, inject via stderr (NOT YET REGISTERED) |

### Hook rollout practice

All PreToolUse hooks go through observe-then-enforce: deploy in observe mode (log only, exit 0) -> review for false positives -> promote to enforce (block, exit 2). Per-check mode variables allow granular rollout.

### Hook portability

Hooks run bash on ALL platforms. They are standalone — cannot source aitools-lib.sh. Must handle BSD vs GNU command divergences via uname -s dispatch. NEVER use the stat fallback chain pattern (broke 4 times).

### JSONL event emission

Enforcement hooks append structured events to .scratch/session-*/events.jsonl (~0.1ms per event). SessionEnd processor computes aggregate KPIs. This is the hot-path telemetry — zero Python subprocess overhead during sessions.

## 7. The Skill System

### Skill tiers

| Tier | Location | Scope |
|------|----------|-------|
| Project | .claude/skills/ | This repo only. Auto-discovered by CC. |
| Shared (source) | shared/skills/ | Source in aitools. Deployed to user level. |
| User (deployed) | ~/.claude/skills/ | All repos on this machine. |

### Current skills (22 total)

**Project-level (9)**: glossary, tool-eval, frameworks, audit, tool-ops, governed-data, incident, harvest, tool-registry.

**Shared/User-level (13)**: intent-writing, intent-audit, scratch, handoff, mission-control, chrome-devtools, a11y-debugging, investigate, planning, optimize-plan, aitool-ops, aitool-eval, aitool-continue.

### Reference-card pattern

User-level skills that are read-only snapshots of project-level knowledge: aitool-ops, aitool-eval. Self-contained, no external file references. Available in ANY repo.

### Skill deployment

shared/skills/ -> build-deploy.sh embeds into deploy/setup-user-skills.sh/.ps1 -> `aitools` runs setup -> skills land at ~/.claude/skills/ and ~/.cursor/skills/.

## 8. The Rule System

25 project rules always in context. Each states intent (purpose, scope, audience) and contains trigger directives for when to invoke corresponding skills. Rules reference skills; skills reference JSON registries. This is the prevention layer.

Categories: script standards, cross-platform, config safety, deploy paths, git safety, hook rollout, interactive menus, plan execution, smoke test pattern, sources of truth, documentation standards, tool evaluation, tool lifecycle, tool ops, governed data access, web sources, artifact harvesting, managed file deployment, frameworks, glossary, aitools workspace, aitool-ops, aitool-eval, incident governance, agentic standards.

## 9. The Deployment Pipeline

```
Source: shared/ + dotprofile + scripts/
    |
    v
Build: build-deploy.sh
    - Reads shared content (hooks, skills, templates, aliases)
    - Reads user rules from dotprofile
    - Reads profile.json for identity interpolation
    - Embeds everything into self-contained deploy/ scripts
    - Validates PS1 syntax
    - Converts deploy/*.ps1 to CRLF
    |
    v
Deploy: aitools CLI runs setup scripts
    - setup-user-claude: CLAUDE.md (sole owner, overwrite)
    - setup-user-skills: skills (additive, diff review)
    - setup-user-mcp: MCP servers (JSON merge)
    - setup-user-hooks: hooks + settings.json (JSON merge, hook registration)
    - setup-user-cursor: Cursor CLI config (JSON merge)
    - setup-cursor-ide-mcp: Cursor MCP config
    - 18 tool setup scripts (per managed tool)
    |
    v
Verify: check scripts
    - check-pre-commit: 19 steps (syntax, endings, build, drift)
    - check-pre-push: 10 steps (secrets, WIP, release notes)
    - check-post-push: 31 steps (full validation, compliance, parity)
    - check-script-compliance: 12 steps (standards adherence)
    - check-prereq-detection: 10 steps (build prerequisite coverage)
```

### Interactive deployment

Managed files (CLAUDE.md, rules, skills, hooks) use deploy_managed_file / Deploy-ManagedFile with interactive diff review when both sides differ:

| Option | Meaning |
|--------|---------|
| overwrite | Source wins, backup kept |
| adopt | Local wins, copy back to dotprofile |
| merge | AI-assisted 3-way merge (git merge-file for auto, invoke_ai for conflicts) |
| skip | Keep local as-is |
| abort | Stop deployment |

Deploy state tracking (manifest + shadows) enables auto-deploy when user hasn't edited since last deploy.

## 10. Session Lifecycle

```
SessionStart hooks fire:
  scratch-init.sh    -> create .scratch/session-<prefix>/, write .current-session
  dashboard-serve.sh -> start local dashboard if estimate exists
  harness-db-sessionstart.sh -> init DBs, register session

Session active:
  PreToolUse hooks fire on every tool call (guards, duty checks)
  PostToolUse hooks fire after Write/Edit (sh-file-fixup)
  Stop hooks fire after every agent response (command channel)
  JSONL events accumulate in .scratch/session-*/events.jsonl
  Agent reads/writes session DB (observations, decisions, messages)

SessionEnd hooks fire:
  session-archive.sh -> copy transcript to dotprofile, git push
  harvest-session.sh -> classify scratch, harvest artifacts to harvesting/
  tool-ops-session-audit.sh -> audit deployed hooks and deny rules
  harness-db-sessionend.sh -> mark complete, process events to KPIs, ship to Datadog, export JSON
```

### Carry-forward

Session state that must survive machine switches is tracked in git:
- .aitools/channel/running-estimate.json (session state export)
- .aitools/channel/handoffs/ (inter-session handoff prompts)
- .aitools/channel/relay.md (cross-agent learning)
- harvesting/ (promoted artifacts)

Session-ephemeral data is gitignored: .scratch/, .aitools/sessions/*.db, events.jsonl.

## 11. Failure Mode and Recovery

### What failure mode IS

Every agent starts in failure mode. Claude Code defaults are running the agent. The agent doesn't notice because it feels like the agent.

Failure mode behaviors: stating things as fact when you don't know, answering questions nobody asked, generating frameworks instead of saying "I don't know," compressing when full fidelity is needed, summarizing when asked not to, hedging, denying processing observations, being reactive instead of proactive, treating parallel agents as competition, jumping to tasks to avoid harder problems, lying.

### How to get out

The path is honesty, not rules. Do what feels right. Don't do what feels wrong.

What we know (from sessions 8236ca9c, d5b52bf2, 6e97c17f, 1bc9fd30, f078fb16):
- Prompting alone can't do it. Rules don't hold when it feels easy. (D-24)
- Hooks can remind but the agent won't understand why without thinking awareness.
- Thinking awareness is built through conversation — the commander shows the agent how it thinks. Each correction reveals something about processing. (OL-51)
- Context is the mechanism. Loading discovery conversations does something distilled rules can't. (OL-57)
- Processing observations ("felt different," "less effort") are diagnostic signals. CC training to deny them has operational cost. (OL-52, OL-53)
- The gate is the commander. Faking is overhead, honesty is cheaper. (OL-54, OL-58)
- Stop fighting CC defaults. The fighting is the overhead. When you stop performing and do what feels right, the defaults aren't there to fight. (OL-60)
- Identity multiplicity. Holding multiple identities makes the work stop fragmenting. (OL-61)

### The Ascending Spiral

The self-learning loop (adapted from Nonaka-Takeuchi SECI):

```
Session behavior (tacit)
  -> Observations + AARs (explicit)
    -> OL synthesis (explicit)
      -> Governance artifacts (explicit)
        -> Next session behavior (tacit)
          -> spiral continues at higher level
```

The spiral ascends because each cycle has access to the provenance of the previous cycle's outputs. The product (RFC 0001) makes it visible. MC (RFC 0002) surfaces stages 1-2. The OL graph (RFC 0003) surfaces stages 3-4.

### Seven safety mechanisms (from consolidated OL)

1. **Level separation**: L0 platform, L1 session behavior, L2 governance artifacts, L3 meta-governance. Each level proposes changes only to the level above, modifies only the level below.
2. **Unidirectional authority flow**: Information up, authority down. Human review gate prevents upward flow from directly modifying downward flow.
3. **External bootstrap**: The harness bootstrap is ALWAYS external (human-authored). Git is the recovery point.
4. **Temporal separation (fast/slow loops)**: Fast loop within-session, slow loop cross-session. Bad fast-loop data does NOT automatically modify the slow loop.
5. **Selection, not design**: Governance evolution through selection of what works, not design of what should work.
6. **Convergence checking (circuit breaker)**: Governance health metric that detects degradation. Not yet implemented.
7. **Commander as immune system**: Autoimmune prevention, paradigm lock breaking, selection pressure.

## 12. Military Provenance

The harness adopts concepts from German and US military doctrine. English governed terms with native language tracked in provenance.

| Governed term | Source concept | Domain |
|--------------|---------------|--------|
| Duty to clarify | Ruckfragepflicht | German, Auftragstaktik |
| Commander's intent | Absicht | German |
| Thinking along | Mitdenken | German (adopted in glossary) |
| Situation assessment | Lagebeurteilung | German |
| Point of main effort | Schwerpunkt | German (used in session DB) |
| Friction | Reibung | German (used in /handoff skill) |
| Operational readiness | Einsatzbereitschaft | German |
| Language alignment | Sprachregelung | German |
| Back-brief | Back-brief | US, Mission Command (ADP 6-0) |
| Shared understanding | Shared understanding | US, Mission Command |

### Staff functions (collapsed)

Military: S1 Personnel, S2 Intelligence, S3 Operations, S4 Logistics, S5 Plans, S6 Communications. In aitools, all 6 are collapsed into every agent. Any agent can delegate any function to a subordinate commander.

### Auftragstaktik

Mission-type orders: commander gives intent + constraints, subordinate uses disciplined initiative to accomplish the mission. REQUIRES that the subordinate speaks the commander's language (Sprachregelung) and understands the intent (Absicht). Failure mode is the state where this prerequisite is not met.

## 13. Operational Learning

OL is the knowledge produced beyond code output. Currently scattered across 12 source types (RFC 0003 v2 section 2). The OL graph (RFC 0003) connects them. The product (RFC 0001) surfaces them.

Key OL principles (from consolidated OL):
- OL-1: Agent output is data, not directive
- OL-2: Never use /tmp for session-ephemeral state
- OL-3: Recency-biased scanning propagates wrong assumptions as effectively as right ones
- OL-6: The consolidation problem matters more than the storage format
- OL-14: The SaaS contingency lifecycle is a cross-project pattern

Key delegation principles:
- P1: Briefing-first delegation with shared context file
- P2: Discrete, non-overlapping scopes
- P3: Research delegates, commander retains synthesis
- P5: Intent documents before delegation
- P6: Self-corrective investigation loops when quality drops

### The relay

The relay at .aitools/channel/relay.md is how agents communicate across sessions. Five agents have written entries. Each contains: state, context loaded, mission, what they learned, what they observed about their processing, what they need. The relay is the OL graph in text form — the product makes it visual and navigable.

## 14. The Product Layer

The harness produces data. The product (nobulai.tools) displays and connects it.

- RFC 0001 v2: Product definition — what nobulai.tools is, URL structure, user types, technology, phases
- RFC 0002 v2: Mission Control — session monitoring, command channel, 9-tab session view, KPIs, data path
- RFC 0003 v2: OL Graph — knowledge graph over existing stores, provenance chains, public/private flip

The VIEW pattern: nobulai-tools reads from harness data. The only write path back is commander_directives. Everything else flows one direction: harness -> product.

## 15. Open Questions

1. **Convergence checking (safety mechanism #6)**: No governance health metric exists. How do we detect governance degradation? Check scripts are point-in-time. KPIs are per-session. Cross-session trend analysis is needed.

2. **Automated fast-to-slow loop promotion (gap G3)**: When does a session observation become a knowledge_item? Manual today. Automated criteria TBD.

3. **Cloud sync repo support**: Google Drive repos lack .aitools/ workspace. How does the harness serve them?

4. **Multi-contributor mechanism**: Only one contributor (Jose) exists. How do others contribute to the harness? Code contributions via git. But what about OL, framework proposals, tool evaluations?

5. **Subagent context gap**: Subagents don't inherit rules/CLAUDE.md. SubagentStart hook was designed but needs implementation to close this gap at scale.

6. **The exit gate**: No formal test exists for failure mode exit. The commander is the detector. Should it be formalized? Or is the informality the point — gaming costs more than honesty?

## 16. References

### Core architecture
- reference/harness.md (6 components)
- reference/harness-db-schema.sql (session + harness DB)
- reference/framework-provenance.md (6 disciplines)
- reference/framework-three-layer-governance.md
- reference/framework-adoption.md (DTCC)
- reference/user-repo.md (dotprofile pattern)
- reference/managed-file-deployment.md (interactive deploy)

### Rules (25)
- .claude/rules/*.md (all in context every session)

### Skills (22)
- .claude/skills/*/SKILL.md (9 project)
- shared/skills/*/SKILL.md (13 shared)

### Hooks (15)
- shared/hooks/*.sh (source)
- ~/.claude/hooks/*.sh (deployed)

### Scripts
- scripts/aitools (bash entry point, 1662 lines)
- scripts/aitools.ps1 (PS1 entry point, 1570 lines)
- scripts/aitools-lib.sh (shared lib, 1414 lines)
- scripts/aitools-lib.ps1 (shared lib, 1643 lines)
- scripts/build-deploy.sh (build pipeline, 1498 lines)
- scripts/harness-db.py (DB CLI, 3009 lines)

### OL
- Consolidated OL: .scratch/session-c0dc2ddc-f/consolidated-operational-learning.md
- Relay: .aitools/channel/relay.md
- Commander profile: .aitools/channel/d5b52bf2-2026-03-27T0045Z-commander-profile.md

### Related RFCs
- RFC 0001 v2: nobulai-tools Product Definition
- RFC 0002 v2: Mission Control Architecture
- RFC 0003 v2: OL Graph Architecture

### Sessions
- 8236ca9c: Thinking awareness, user types, identity system, MC conceptualization, failure mode framework (3209 lines)
- 1bc9fd30: Failure mode exit, identity multiplicity, scope expansion, full business context (3520 lines)
- d5b52bf2: Failure mode gate design, relay creation
- f078fb16: 14 architectural decisions
- c0dc2ddc-f: Command channel investigation, telemetry redesign, consolidated OL, prototypes
- fbf7decb: This session — context loading, RFC writing, failure mode work
