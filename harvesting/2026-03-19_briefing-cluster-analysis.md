# Planning Brief Cluster Analysis

**S2 Intelligence Product -- Decision Dependency Graph Analysis**
**Date**: 2026-03-18
**Source**: plans/mission-command-briefing/planning-brief.json (schema 6.0, 53 active decisions)
**Mission**: Determine if 54 decisions (53 active, #31 merged into #8) can be decomposed into self-contained sub-briefings.

---

## 1. Dependency Graph (Adjacency List)

Each line: Decision ID -> [related decision IDs]

```
 1 -> [2, 10, 14, 18, 36]
 2 -> [1, 10, 18, 36]
 3 -> [4, 5, 6, 7, 15, 22, 23, 24, 25, 26, 27, 28, 37, 38]
 4 -> [3, 5, 6, 7, 19, 21, 23, 25, 26, 27, 28, 44, 46, 48, 54]
 5 -> [3, 4, 6, 20]
 6 -> [3, 4, 5, 20]
 7 -> [3, 4, 19, 25, 27]
 8 -> [9, 31, 37]
 9 -> [8]
10 -> [1, 2, 11, 36]
11 -> [10, 34, 36]
12 -> [13, 28, 39, 40]
13 -> [12, 18, 21, 28, 37, 39, 43, 45]
14 -> [1, 22, 34, 36]
15 -> [3, 16]
16 -> [15, 17]
17 -> [16]
18 -> [1, 2, 13, 19, 36]
19 -> [4, 7, 18]
20 -> [5, 6, 41, 42]
21 -> [4, 13, 39, 40, 43]
22 -> [3, 14, 23, 24, 25, 26, 34, 46]
23 -> [3, 4, 22, 24]
24 -> [3, 22, 23, 25, 26, 30, 35, 36, 48]
25 -> [3, 4, 7, 22, 24, 26, 27, 30, 38, 44]
26 -> [3, 4, 22, 24, 25, 29, 30, 36, 38, 44]
27 -> [3, 4, 7, 25]
28 -> [3, 4, 12, 13, 39]
29 -> [26, 41, 45]
30 -> [24, 25, 26, 35, 36]
32 -> [33]
33 -> [32]
34 -> [11, 14, 22, 36, 46, 47]
35 -> [24, 30, 36, 41, 42, 48, 54]
36 -> [1, 2, 10, 11, 14, 18, 24, 26, 30, 34, 35, 37, 40, 43, 44, 48, 54]
37 -> [3, 8, 13, 36, 38]
38 -> [3, 25, 26, 37, 44]
39 -> [12, 13, 21, 28, 40, 41, 42, 43]
40 -> [12, 21, 36, 39, 41, 42]
41 -> [20, 29, 35, 39, 40, 45, 48, 54]
42 -> [20, 35, 39, 40, 47]
43 -> [13, 21, 36, 39, 45]
44 -> [4, 25, 26, 36, 38, 46, 48, 54]
45 -> [13, 29, 41, 43, 54]
46 -> [4, 22, 34, 44, 47, 48, 54]
47 -> [46, 34, 42]
48 -> [4, 24, 35, 36, 41, 44, 46, 54]
49 -> [3, 8, 13, 16, 36, 43]
50 -> [4, 22, 23, 26, 36, 44, 46, 48, 49, 54]
51 -> [3, 4, 13, 28, 36, 37, 45, 48, 49, 50, 52, 54]
52 -> [4, 25, 38, 45, 49, 51, 54]
53 -> [3, 20, 22, 26, 29, 34, 35, 41, 45, 50, 54]
54 -> [4, 35, 36, 41, 44, 45, 46, 48, 50, 51, 52, 53]
```

### Graph Statistics

| Metric | Value |
|--------|-------|
| Active decisions | 53 |
| Total directed edges | 427 (bidirectional = ~214 unique pairs) |
| Most connected | #36 (17 connections), #4 (15), #3 (14), #54 (12), #51 (12) |
| Least connected | #9 (1), #17 (1), #33 (1), #32 (1) |
| Isolated pair | #32-#33 (telemetry + auth, connected only to each other) |

---

## 2. Cluster Identification

### Method

Community detection via manual analysis of connectivity density. A cluster is a set of decisions where the majority of related edges point within the cluster (internal connectivity > external connectivity).

### Cluster A: Mission Command Core (Delegation and Communication)

**Decisions**: 3, 4, 5, 6, 7, 15, 16, 17, 19, 20, 22, 23, 24, 25, 26, 27, 28, 38, 44

**Internal edge count**: 89
**External edge count**: 62
**Internal connectivity ratio**: 0.59 (moderate-high)

This is the LARGEST cluster. Decision #3 (Mission Command framework definition) is the hub. It includes:
- Framework definition (#3, #15, #16, #17)
- Delegation duty (#4, #5, #6, #7, #19, #20, #28)
- Channel infrastructure (#22, #23)
- Staff functions and authority (#24, #25, #26, #27, #38, #44)

**Key observation**: This cluster has high internal connectivity but ALSO many external edges, especially to clusters B, D, and F. Decision #4 (delegation duty) is the primary bridge node -- it connects to nearly every other cluster.

### Cluster B: Operational Learning (AAR, Harvesting, Sessions)

**Decisions**: 1, 2, 10, 11, 14, 18, 30, 36

**Internal edge count**: 26
**External edge count**: 33
**Internal connectivity ratio**: 0.44 (moderate)

Decision #36 (Operational Learning framework) is the hub. This cluster is moderately self-contained but #36 has heavy external connections (17 total, 9 external). It includes:
- Session archive improvements (#1, #2, #10, #18)
- Harvest manifest fixes (#11)
- Scratch cleanup (#14)
- Registry audit at plan end (#30)
- Framework definition (#36)

### Cluster C: Intent Documentation and Quality

**Decisions**: 12, 39, 40, 42, 43

**Internal edge count**: 11
**External edge count**: 22
**Internal connectivity ratio**: 0.33 (low-moderate)

Centered on the intent skills (#39, #40) with the schema clarification (#43) and intent enforcement hook (#42). Lower internal ratio because these decisions primarily serve OTHER clusters (especially A and D).

### Cluster D: Mission Analysis (Planning Briefs)

**Decisions**: 13, 21, 29, 41, 45, 53

**Internal edge count**: 13
**External edge count**: 31
**Internal connectivity ratio**: 0.30 (low-moderate)

Centered on the /brief skill (#13, #21, #45) and its enforcement mechanisms (#29, #41, #53). High external connectivity because planning briefs serve all frameworks.

### Cluster E: Platform Engineering

**Decisions**: 8, 9

**Internal edge count**: 2
**External edge count**: 3
**Internal connectivity ratio**: 0.40 (moderate, but tiny cluster)

Very tightly coupled pair. #8 defines the framework, #9 fixes the stop hook crash. Only external connection: #37 (provenance).

### Cluster F: Infrastructure and Namespace

**Decisions**: 32, 33, 34, 46, 47, 50

**Internal edge count**: 9
**External edge count**: 27
**Internal connectivity ratio**: 0.25 (low)

The infrastructure cluster is poorly self-contained. #32-#33 (telemetry + auth) form a tight pair. #34 (namespace consolidation), #46 (scratch collision), #47 (scratch hook), and #50 (running estimate) each have more external than internal connections. This cluster exists because the brief's reading order groups them, not because they are tightly coupled.

### Cluster G: Process and Plan-Writing

**Decisions**: 35, 48, 49, 51, 52, 54

**Internal edge count**: 14
**External edge count**: 44
**Internal connectivity ratio**: 0.24 (low)

The most externally connected cluster. #54 (harness improvement cycle) connects to 12 other decisions. #51 (plan-writing protocol) connects to 12. These are "capstone" decisions that synthesize concepts from all other clusters.

### Cluster H: Framework Governance

**Decisions**: 37

**Internal edge count**: 0
**External edge count**: 5
**Internal connectivity ratio**: N/A (singleton)

The provenance map (#37) is truly cross-cutting -- it connects to clusters A (#3, #38), B (#36), D (#13), and E (#8). It belongs to no single cluster.

### Connectivity Matrix (Cluster-to-Cluster Edge Counts)

```
        A     B     C     D     E     F     G     H
  A   [89]   15     9    14     0    12    10     3
  B    15   [26]    2     4     0     4     8     1
  C     9     2   [11]    8     0     1     5     0
  D    14     4     8   [13]    0     2     9     0
  E     0     0     0     0    [2]    0     0     1
  F    12     4     1     2     0    [9]    10    0
  G    10     8     5     9     0    10   [14]    1
  H     3     1     0     0     1     0     1    [0]
```

**Key finding**: Clusters A, F, and G have the heaviest inter-cluster traffic. This means clean decomposition is HARD for those areas.

---

## 3. Framework Alignment Check

### Do graph clusters align with framework boundaries?

**Partially. Here is the alignment and divergence:**

| Framework | Primary Cluster | Alignment | Divergence |
|-----------|----------------|-----------|------------|
| Mission Command | A (core) | HIGH -- #3-#28 are well-grouped | #44, #46, #50 bridge to F/G; #4 connects everywhere |
| Platform Engineering | E | HIGH -- tightly coupled pair | #37 (provenance) is more cross-cutting |
| Mission Analysis | D | MODERATE -- #13, #21, #45 are core | #29 (critical blockers) and #41 (plan-gate) bridge to A and G |
| Operational Learning | B | MODERATE -- #1, #2, #10, #36 are core | #36 has 17 connections spanning all clusters; #30 bridges to A |

### Cross-cutting decisions (belong to multiple frameworks)

| Decision | Frameworks | Why it cross-cuts |
|----------|-----------|-------------------|
| #4 (delegation duty) | MC + all | Every framework's artifacts are created via delegation |
| #36 (OpLearning framework) | OL + MC + MA | Absorbs harvesting and session lifecycle, feeds channel/AAR |
| #37 (provenance map) | All | Maps concepts across all frameworks |
| #44 (S2 AAR schema) | MC + OL | S2 identity (MC) produces AAR (OL) |
| #50 (running estimate) | MC + OL + MA | Maintained by S3 (MC), feeds AAR (OL), seeded from brief (MA) |
| #54 (improvement cycle) | OL + MC + all | Uses delegation (MC), produces AAR (OL), touches all layers |

**Conclusion**: Framework boundaries are NOT clean cluster boundaries. The frameworks define conceptual ownership, but implementation requires cross-framework coordination at nearly every decision. Sub-briefings cannot be fully isolated by framework.

---

## 4. Dependency Ordering

### Tier 0: Pre-requisites (must exist before anything else)

**Must be first:**
- **#32 (log_ship + SQLite)** -- All KPIs depend on telemetry pipeline. Without this, all other decisions' KPIs are aspirational.
- **#33 (Auth0 credentials)** -- log_ship needs datadogApiKey.
- **#34 (namespace consolidation)** -- .aitools/ directory structure must exist before channel, scratch updates, and harvesting path migration.

**Rationale**: The brief's sequencingNotes.kpiDependency explicitly states: "All KPIs are aspirational until decision #32 is implemented. Plan must sequence #32 in first execution phase."

### Tier 1: Critical Blockers (blocks planning itself)

**Must be resolved before plan writing:**
- **#39 (/intent-writing skill update)** -- blocksPlanning: true
- **#40 (/intent-audit skill update)** -- blocksPlanning: true
- **#29 (critical fact resolution)** -- F1, F2, F3 already resolved per brief; F17 depends on #39/#40

**Already resolved** (per brief's status: resolved):
- F1 (tool-registry SKILL.md) -- resolved in current audit session
- F2 (harvest SKILL.md) -- resolved in current audit session
- F3 (frameworks.md) -- resolved in current audit session
- F17 (intent skills) -- resolved once #39/#40 execute

### Tier 2: Framework Definitions (build mental model before implementation)

**Must precede framework-specific decisions:**
- **#3 (Mission Command framework)** -- defines rule, skill, reference, channel for MC
- **#8 (Platform Engineering framework)** -- defines rule, skill, reference for PE
- **#13 (Mission Analysis framework)** -- defines brief schema, decision capture, /brief skill
- **#36 (Operational Learning framework)** -- defines AAR, harvesting, session lifecycle
- **#37 (provenance map)** -- enables concept lookup across all frameworks
- **#38 (staff function definitions)** -- S1/S2/S3 referenced by all MC decisions

### Tier 3: Channel Infrastructure (before delegation works)

**Must precede delegation and running estimate:**
- **#22 (.aitools/channel/ directory)** -- channel directory structure
- **#23 (/channel skill + schemas)** -- SITREP/FINDING schemas

**Rationale**: The brief's sequencingNotes.channelDependency states: "Channel infrastructure must be built before delegation (#4) works with collision-resistant file naming."

### Tier 4: Core Operational Decisions

Now framework-specific decisions can execute in dependency order:

**Mission Command** (depends on Tier 2-3):
- #4 (delegation duty) -- needs #3, #22, #23
- #5, #6 (Explore agent blocking) -- needs #4, #20
- #7 (recursive delegation) -- needs #4
- #15, #16, #17 (naming, conventions, gatekeeping) -- needs #3
- #19 (session references) -- needs #4
- #24 (sensors not filers) -- needs #22, #23
- #25 (staff functions) -- needs #3, #4, #22
- #26 (S2 spawning) -- needs #25, #24
- #27 (FRAGORD) -- needs #4
- #28 (pre-draft intents) -- needs #4, #12

**Platform Engineering** (depends on Tier 2):
- #9 (stop hook fix) -- needs #8

**Mission Analysis** (depends on Tier 2):
- #21 (quality checklist) -- needs #13
- #43 (schema clarification) -- needs #13
- #45 (governed brief access) -- needs #13, #41

**Operational Learning** (depends on Tier 2):
- #1, #2 (session archive) -- needs #36
- #10, #11 (session/harvest fixes) -- needs #36
- #14 (scratch cleanup) -- needs #36
- #18 (plan file archival) -- needs #36
- #30 (registry audit at plan end) -- needs #24, #36

### Tier 5: Enforcement Hooks

**Depends on Tier 4 decisions being designed:**
- #20 (one hook per feature principle) -- design principle
- #41 (plan-gate hook) -- needs #29, #39, #40
- #42 (intent-enforcement hook) -- needs #39, #40
- #47 (scratch-skill-guard hook) -- needs #46
- #53 (governedBy + drift hooks) -- needs #41, #45

### Tier 6: Process and Capstone

**Depends on all prior tiers:**
- #35 (UCIs not effective, escalation) -- needs #24, #30, #36
- #44 (S2 output = AAR schema) -- needs #36, #25, #26
- #46 (scratch collision prevention) -- needs #34, #22
- #48 (fix-right decision tree) -- needs #4, #36, #41
- #49 (flat verb skill naming) -- needs #3, #8, #13, #36
- #50 (running estimate) -- needs #22, #23, #26, #36

### Tier 7: Plan-Writing Protocol

**Depends on everything else:**
- #51 (plan-writing protocol) -- needs #4, #13, #36, #45, #50, #52
- #52 (Plan Writer role) -- needs #25, #38, #51
- #54 (harness improvement cycle) -- needs #4, #36, #41, #44, #45, #48, #50

### Dependency Chain Visualization

```
Tier 0: Infrastructure
  #32 --- #33
  #34

Tier 1: Critical Blockers
  #39   #40   #29

Tier 2: Framework Definitions
  #3    #8    #13   #36   #37   #38

Tier 3: Channel Infrastructure
  #22   #23

Tier 4: Core Decisions (framework-specific, can partially parallelize)
  MC:  #4  #5  #6  #7  #15 #16 #17 #19 #24 #25 #26 #27 #28
  PE:  #9
  MA:  #21 #43
  OL:  #1  #2  #10 #11 #14 #18 #30

Tier 5: Enforcement Hooks
  #20  #41  #42  #47  #53

Tier 6: Process and Capstone
  #35  #44  #46  #48  #49  #50

Tier 7: Plan-Writing Protocol
  #51  #52  #54
```

---

## 5. Parallel Execution Map

### What CAN execute in parallel?

**Within Tier 0**: #32-#33 and #34 are independent. Build telemetry in parallel with namespace consolidation.

**Within Tier 1**: #39 and #40 are related (both update intent skills) but can be executed in parallel since they modify different SKILL.md files. #29 is already resolved.

**Within Tier 2**: All 6 framework definitions can be written in parallel -- they are conceptual definitions that do not depend on each other's code.

**Within Tier 3**: #22 and #23 can execute in parallel (directory structure + skill/schema are additive).

**Within Tier 4**: The four framework groups (MC, PE, MA, OL) have LIMITED parallelism:
- PE (#9) is fully independent of MA (#21, #43) and OL (#1, #2, #10, #11, #14, #18).
- MC core (#4-#7, #15-#17, #19) depends on #22/#23 (Tier 3) but NOT on OL or MA.
- OL (#1, #2, #10, #11, #14, #18, #30) depends on #36 (Tier 2) but NOT on MC or MA.
- MA (#21, #43) depends on #13 (Tier 2) but NOT on MC or OL.

**Within Tier 5**: Hook implementations are partially independent:
- #41 (plan-gate) and #42 (intent-enforcement) share dependency on #39/#40 but operate on different events.
- #47 (scratch guard) is fully independent of #41/#42.
- #53 (governedBy) depends on #41 (extends plan-gate).

**Between Tiers**: Tier 0, 1, and 2 partially overlap:
- Infrastructure (#32-#34) can start immediately.
- Critical blockers (#39, #40) can start immediately (no Tier 0 dependency).
- Framework definitions (#3, #8, #13, #36-#38) can start after critical blockers.

### Parallel Execution Lanes

```
Lane 1 (Infrastructure):     #32 -> #33 -> (done early)
Lane 2 (Namespace):          #34 -> (feeds #22, #46)
Lane 3 (Intent/Quality):     #39, #40 -> #12 -> #42 -> (feeds #41)
Lane 4 (MC Framework):       #3, #15, #16, #17 -> #22, #23 -> #4-#7, #19, #24-#28, #38 -> #44
Lane 5 (PE Framework):       #8 -> #9 -> (done early)
Lane 6 (MA Framework):       #13 -> #21, #43 -> #45 -> #29, #41
Lane 7 (OL Framework):       #36, #37 -> #1, #2, #10, #11, #14, #18, #30 -> #35, #48
Lane 8 (Capstone):           waits for 3-7 -> #46, #47, #49, #50 -> #51, #52, #53, #54
```

### Maximum Parallelism Points

| Phase | Concurrent lanes | Decisions executing |
|-------|-----------------|---------------------|
| Phase 1 | 5 | Lanes 1-5 start simultaneously |
| Phase 2 | 4 | Lanes 3-7 (after intent skills done) |
| Phase 3 | 4 | MC, MA, OL core decisions + hooks |
| Phase 4 | 1 | Capstone (serial, everything feeds in) |

---

## 6. Proposed Sub-Briefings

### Sub-Briefing 1: "Infrastructure Foundation"

**Intent**: Build the telemetry pipeline and workspace namespace that all frameworks depend on. No framework-specific content -- pure infrastructure.

**Decisions**: #32, #33, #34
**Dependencies**: None (Tier 0)
**Can execute in parallel with**: Sub-Briefing 2 (Critical Blockers), Sub-Briefing 3 (Platform Engineering)
**Facts**: F14 (log_ship not built), F15 (Auth0 not implemented)
**Assumptions**: A5 (Datadog credits sufficient), A6 (Auth0 plan available)

**Self-containment score**: HIGH. Only 4 external edges total. #32-#33 are a tight pair. #34 feeds into other sub-briefings but does not need them.

---

### Sub-Briefing 2: "Intent Skills and Quality Gates"

**Intent**: Update the intent-writing and intent-audit skills with session-proven heuristics. Must complete before plan writing begins (blocksPlanning=true). Establishes quality standards used by all other sub-briefings.

**Decisions**: #12, #39, #40, #42, #43
**Dependencies**: None (these are standalone skill updates)
**Can execute in parallel with**: Sub-Briefing 1, Sub-Briefing 3
**Facts**: F8 (64% rules lack intent), F17 (intent skills lack heuristics, resolved once executed)
**Assumptions**: None specific

**Self-containment score**: MODERATE. #12/#39/#40 are tightly coupled. #42 (intent enforcement hook) and #43 (schema clarification) have external edges but their implementation specs are self-contained.

---

### Sub-Briefing 3: "Platform Engineering"

**Intent**: Establish the Platform Engineering framework, fix the stop hook crash, and build the divergence registry. Smallest and most self-contained sub-briefing.

**Decisions**: #8, #9
**Dependencies**: None
**Can execute in parallel with**: Sub-Briefing 1, Sub-Briefing 2
**Facts**: F4 (stop hook crashes on Windows)
**Assumptions**: A2 (stop hook crash isolation), A4 (hooks run bash on all platforms)

**Self-containment score**: VERY HIGH. Only 3 external edges (#37 provenance, #31 merged). Fully independent.

---

### Sub-Briefing 4: "Mission Command Framework"

**Intent**: Build the Mission Command framework -- delegation protocol, inter-agent channel, staff functions, authority model, FRAGORD pattern. The largest and most interconnected sub-briefing.

**Decisions**: #3, #4, #5, #6, #7, #15, #16, #17, #19, #20, #22, #23, #24, #25, #26, #27, #28, #38, #44
**Dependencies**: Sub-Briefing 1 (#34 for .aitools/channel/), Sub-Briefing 2 (#39/#40 for intent skills used in #28)
**Can execute in parallel with**: Sub-Briefing 5 (MA), Sub-Briefing 6 (OL) -- PARTIALLY. MC needs channel infrastructure (#22/#23) before delegation (#4), but MA and OL framework definitions can proceed concurrently.
**Facts**: F9 (skills lack trigger directives), F10 (glossary gaps), F18 (8 new hooks)
**Assumptions**: A3 (blocking Explore agents), A4 (hooks run bash), A7 (hooks as enforcement)

**Self-containment score**: LOW-MODERATE. 19 decisions with 89 internal edges but 62 external edges. The sheer size and #4's role as universal bridge node make this hard to isolate. Consider further decomposition (see note below).

**Sub-decomposition opportunity**: Could split into:
- 4a: Framework definition (#3, #15, #16, #17) + naming (#49 from G)
- 4b: Channel infrastructure (#22, #23)
- 4c: Delegation core (#4, #5, #6, #7, #19, #20, #28)
- 4d: Staff and authority (#24, #25, #26, #27, #38, #44)

---

### Sub-Briefing 5: "Mission Analysis Framework"

**Intent**: Establish the Mission Analysis framework -- planning brief schema, quality checklist, governed brief access, plan-gate enforcement. Governs how all future briefs (including this one's sub-briefings) are created and consumed.

**Decisions**: #13, #21, #29, #41, #45, #53
**Dependencies**: Sub-Briefing 2 (#39/#40 for #41 plan-gate hook), Sub-Briefing 4 (#22 for #53 governedBy references, #26 for S2 intelligence prep)
**Can execute in parallel with**: Sub-Briefing 6 (OL), Sub-Briefing 3 (PE) -- framework definitions can proceed concurrently; hooks (#41, #53) must wait for dependencies
**Facts**: F1-F3 (critical skill breakage, already resolved)
**Assumptions**: None specific

**Self-containment score**: MODERATE. 13 internal edges, 31 external. The external edges are mostly to Cluster A (MC) because brief access feeds into delegation, and to Cluster C (intent) because quality gates feed into brief creation.

---

### Sub-Briefing 6: "Operational Learning Framework"

**Intent**: Establish the Operational Learning framework -- AAR debrief, artifact harvesting, session persistence, channel archival. Closes the learning loop.

**Decisions**: #1, #2, #10, #11, #14, #18, #30, #36
**Dependencies**: Sub-Briefing 1 (#34 for .aitools/ namespace), Sub-Briefing 4 (#24 for sensors-not-filers, #22 for channel archival)
**Can execute in parallel with**: Sub-Briefing 5 (MA), Sub-Briefing 3 (PE)
**Facts**: F5 (8 silently resolved incidents), F6 (stale duplicates), F7 (5 unfiled issues), F13 (stale timestamps)
**Assumptions**: None specific

**Self-containment score**: MODERATE. #36 is the hub with 17 connections, 9 external. Core session improvements (#1, #2, #10, #11) are tightly coupled. #30 (registry audit) bridges to MC cluster.

---

### Sub-Briefing 7: "Process and Governance Capstone"

**Intent**: Cross-cutting process decisions that synthesize concepts from all frameworks -- escalation thresholds, fix-right default, naming conventions, running estimate, and the harness improvement cycle. Must execute LAST before plan-writing.

**Decisions**: #35, #37, #46, #47, #48, #49, #50
**Dependencies**: ALL prior sub-briefings (especially Sub-Briefings 4 and 6)
**Can execute in parallel with**: Sub-Briefing 8 (plan-writing) -- SOME overlap possible; #49 and #46 do not depend on #51/#52
**Facts**: F11 (empty evaluations directory), F16 (/incident skill outdated), F18 (8 new hooks)
**Assumptions**: A7 (hooks as enforcement mechanism)

**Self-containment score**: LOW. Highest external connectivity of any cluster. These are by nature cross-cutting decisions that reference concepts from all frameworks.

---

### Sub-Briefing 8: "Plan-Writing Protocol"

**Intent**: Define how plans are written from briefs -- the S3 write-review loop, Plan Writer role, and harness improvement cycle. The culmination of all other sub-briefings.

**Decisions**: #51, #52, #54
**Dependencies**: ALL prior sub-briefings (especially #4, #13, #36, #45, #50)
**Can execute in parallel with**: Nothing -- this is the final tier
**Facts**: None specific
**Assumptions**: None specific

**Self-containment score**: LOW. 14 internal edges but 44 external. These decisions reference nearly every other decision in the brief. They are the capstone that synthesizes everything.

---

## 7. Fact/Assumption Distribution

### Facts

| Fact | Sub-Briefing(s) | Rationale |
|------|-----------------|-----------|
| F1 (broken /tool-registry) | SHARED (resolved) | Pre-condition for all, already fixed |
| F2 (broken /harvest) | SHARED (resolved) | Pre-condition for all, already fixed |
| F3 (frameworks.md phantom) | SHARED (resolved) | Pre-condition for all, already fixed |
| F4 (stop hook crash Windows) | 3 (Platform Engineering) | Platform-specific bug |
| F5 (8 silently resolved incidents) | 6 (Operational Learning) | Registry hygiene |
| F6 (stale duplicate incidents) | 6 (Operational Learning) | Registry hygiene |
| F7 (5 unfiled issues) | 6 (Operational Learning) | Registry hygiene |
| F8 (64% rules lack intent) | 2 (Intent Skills) | Intent coverage gap |
| F9 (7/8 user skills lack triggers) | 4 (Mission Command) | Trigger directive gap |
| F10 (glossary term gaps) | 4 (Mission Command) | Vocabulary coverage |
| F11 (empty evaluations dir) | 7 (Capstone) | Tool eval gap |
| F12 (broken cross-references) | SHARED | Affects all sub-briefings |
| F13 (stale timestamps) | 6 (Operational Learning) | Framework registry hygiene |
| F14 (log_ship not built) | 1 (Infrastructure) | Telemetry prerequisite |
| F15 (Auth0 not implemented) | 1 (Infrastructure) | Credential management |
| F16 (/incident skill outdated) | 7 (Capstone) | Process improvement |
| F17 (intent skills lack heuristics) | 2 (Intent Skills) | Quality gate prerequisite |
| F18 (8 new hooks proposed) | SHARED (4, 5, 6, 7) | Affects MC, MA, OL hook deployment |

### Assumptions

| Assumption | Sub-Briefing(s) | Rationale |
|------------|-----------------|-----------|
| A1 (closing incidents safe) | 6 (Operational Learning) | Registry cleanup |
| A2 (stop hook crash isolated) | 3 (Platform Engineering) | Platform bug scope |
| A3 (blocking Explore agents OK) | 4 (Mission Command) | Delegation enforcement |
| A4 (hooks run bash all platforms) | SHARED (3, 4, 5, 6, 7) | Hook infrastructure assumption |
| A5 (Datadog credits sufficient) | 1 (Infrastructure) | Telemetry cost |
| A6 (Auth0 plan available) | 1 (Infrastructure) | Credential management |
| A7 (hooks most effective enforcement) | SHARED (4, 5, 7) | Governance mechanism |

---

## 8. Visualization: Sub-Briefing Dependency Diagram

```
                    +----------------------+
                    |  SB1: Infrastructure |
                    |   #32, #33, #34      |
                    +----------+-----------+
                               |
          +--------------------+--------------------+
          |                    |                     |
          v                    v                     v
+-----------------+  +-----------------+             |
|  SB2: Intent    |  |  SB3: Platform  |             |
|  Skills         |  |  Engineering    |             |
|  #12,39,40,42,43|  |  #8, #9        |             |
+--------+--------+  +--------+--------+             |
         |                    |                      |
         |    +---------------+                      |
         |    |                                      |
         v    v                                      v
+-----------------+  +-----------------+  +-----------------+
|  SB4: Mission   |  |  SB5: Mission   |  |  SB6: Oper.     |
|  Command        |  |  Analysis       |  |  Learning       |
|  #3-7,15-17,19  |  |  #13,21,29,41   |  |  #1,2,10,11,14  |
|  20,22-28,38,44 |  |  #45,53         |  |  #18,30,36      |
+--------+--------+  +--------+--------+  +--------+--------+
         |                    |                     |
         +--------------------+---------------------+
                              |
                              v
                    +---------------------+
                    |  SB7: Process &     |
                    |  Governance Capstone |
                    |  #35,37,46-50       |
                    +----------+----------+
                               |
                               v
                    +---------------------+
                    |  SB8: Plan-Writing  |
                    |  Protocol           |
                    |  #51, #52, #54      |
                    +---------------------+
```

### Parallel Execution Summary

```
Time ->
Phase 1:  [SB1: Infrastructure] [SB2: Intent Skills] [SB3: Platform Eng.]
Phase 2:  [SB4: Mission Command] [SB5: Mission Analysis] [SB6: Oper. Learning]
Phase 3:  [SB7: Process Capstone]
Phase 4:  [SB8: Plan-Writing Protocol]
```

**Maximum theoretical concurrency**: 3 (Phase 1 and Phase 2)
**Critical path**: SB2 -> SB4 -> SB7 -> SB8 (longest dependency chain)

---

## 9. Key Findings

### Finding 1: Clean decomposition is achievable but not by framework boundaries alone

The four frameworks (MC, PE, MA, OL) provide CONCEPTUAL grouping but not IMPLEMENTATION isolation. Decision #4 (delegation duty) is referenced by 15 other decisions across all clusters. Decision #36 (Operational Learning) has 17 connections spanning every cluster. Any decomposition must accept that these hub decisions will be shared context across sub-briefings.

### Finding 2: The brief has a natural 4-phase execution structure

Phase 1 (infrastructure + intent + platform) has high parallelism. Phase 2 (three framework implementations) has moderate parallelism. Phase 3 (capstone) and Phase 4 (plan-writing) are essentially serial. This matches a military phased operation model.

### Finding 3: Sub-Briefing 4 (Mission Command) is too large

At 19 decisions, it is the largest cluster and has the most internal complexity. The sub-decomposition into 4a/4b/4c/4d (framework definition, channel infrastructure, delegation core, staff and authority) would improve manageability. This would increase the sub-briefing count from 8 to 11 but keep each unit under 7 decisions.

### Finding 4: Decision #32-#33 (telemetry + auth) is practically independent

These two decisions form a tight pair with zero connections to any framework cluster. They could be executed as a standalone work package at any time. However, they are prerequisite for ALL KPIs, making them logically Tier 0.

### Finding 5: The "capstone" decisions (#35, #48, #50, #51, #52, #54) resist decomposition

These decisions synthesize concepts from all frameworks. They are the hardest to isolate and must be the last to execute. Attempting to pull them into earlier phases would create circular dependencies (e.g., #50 needs #22 and #36 and #4, which span three clusters).

### Finding 6: Intent decisions (#39, #40) are the true critical path bottleneck

Both are blocksPlanning: true and feed into #41 (plan-gate), #42 (intent enforcement), #28 (pre-draft intents), and indirectly into every decision that creates a new artifact with an intent statement. They should execute FIRST, in parallel.
