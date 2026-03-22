# Provenance Deep Research: Non-English Doctrines and Overlooked Frameworks

**Date**: 2026-03-18
**Analyst**: S2 (Intelligence)
**Mission**: Identify concepts from original German doctrine, other military traditions,
and organizational disciplines that address current harness problems but are not yet
adopted.

## Current Problems Being Solved

| # | Problem | Short name |
|---|---------|------------|
| P1 | Scope-creep governance | SCOPE |
| P2 | Carry-forward across sessions/machines/agents | CARRY |
| P3 | Artifact roles (content in wrong artifact type) | ROLES |
| P4 | Briefing decomposition (54 decisions into sub-briefings) | DECOMP |
| P5 | Intent governance at every level (sessions, briefings, plans) | INTENT |

---

## 1. German Doctrine Findings

### 1.1 Concepts English Interpretations Miss

The English term "Mission Command" (US ADP 6-0) flattens several distinct
German concepts into a single phrase. The original tradition contains at least
five separable ideas that English-language doctrine collapses:

#### Selbstandigkeit der Unterfuhrer (Independence of the Subordinate Commander)

The Germans did not use the term "Auftragstaktik" in their own doctrinal
manuals. The Truppenführung (1933) never mentions it. The actual doctrinal
phrase was **Selbstandigkeit der Unterfuhrer** -- the independence of the
subordinate commander. This is more specific than "mission command": it names
WHO gets the independence (the subordinate leader, not everyone) and WHAT they
get (independence to choose method, not independence to choose objectives).

**Harness relevance**: Our subagent delegation model already captures this --
subagents get method independence within a stated intent. But the German
formulation adds an obligation English versions miss: the subordinate must
understand the intent **two levels up** (not just the immediate superior's
intent). This maps to our context gap problem -- subagents lack project rules
and broader context.

**Problem addressed**: P5 (Intent governance)

#### Mitdenken (Thinking Along)

Not merely "initiative." Mitdenken is the expectation that subordinates
actively think about the superior's problem, not just their own task. When a
subordinate encounters information relevant to the superior's intent, they
must proactively communicate it upward even if it is outside their assigned
scope. This is distinct from "initiative" (doing more than asked) -- it is
"cognitive alignment" (thinking about the same problem from a different
vantage point).

**Harness relevance**: This is the concept behind our SITREP/FINDING channel
pattern -- subagents reporting observations back to the main agent. But
Mitdenken implies something stronger: the subordinate should be modeling the
superior's decision space, not just reporting facts. A subagent practicing
Mitdenken would flag "this finding affects decision #34 in the planning
brief" rather than just reporting the raw finding.

**Problem addressed**: P2 (Carry-forward), P5 (Intent)

#### Schwerpunkt (Point of Main Effort)

Often translated as "center of gravity" but this is a mistranslation from
Clausewitz. Schwerpunkt in operational German doctrine means the **decisive
point where effort is concentrated**. It is not analytical (finding the
enemy's weakness) but directive (declaring where YOUR force will focus).

The Schwerpunkt concept has a critical property: **there is exactly one**.
A commander cannot have two Schwerpunkte. Every resource allocation, every
subordinate's action, must support or protect the Schwerpunkt. Tasks that
do not contribute are explicitly deprioritized.

**Harness relevance**: This directly addresses scope creep (P1). Every session,
every briefing, every plan should declare its Schwerpunkt -- the single most
important objective. Expansions that do not serve the Schwerpunkt are rejected
or deferred. This is stronger than "priorities" (which allow multiple) or
"objectives" (which can accumulate). Schwerpunkt demands singularity.

**Problem addressed**: P1 (Scope), P4 (Decomposition), P5 (Intent)

#### Lagebeurteilung (Situation Assessment / Estimate of the Situation)

The formal German process for continuous situation assessment. Unlike the US
MDMP (a planning process), Lagebeurteilung is a **continuous assessment
process** that runs throughout execution, not just at planning time. It
explicitly includes: the overall situation, enemy situation, own forces,
environmental factors, civil considerations, and information environment.

The key difference from our running estimate: Lagebeurteilung is **structured
and schema-driven** (specific categories in a specific order), while our
running estimate is free-form JSON. The German process forces the assessor
to examine every category even if nothing has changed, which prevents blind
spots from accumulating.

**Harness relevance**: Our running estimate (ADP 5-0) could adopt the
structured-category approach from Lagebeurteilung. Each session start would
walk through a checklist of assessment categories rather than just reading
the previous state.

**Problem addressed**: P2 (Carry-forward), P1 (Scope)

#### Reibung (Friction) and Systematic Friction Management

Clausewitz's Reibung is often treated as a metaphor in English. In German
doctrine, it is treated as an **operational reality that must be planned
for**. The Truppenführung explicitly states that plans must be simple because
friction will degrade complex plans. This is not a philosophical observation
but a design constraint: complexity is treated as a friction multiplier.

**Harness relevance**: Every additional rule, registry, hook, and skill
adds friction to the harness. The German approach would mandate a friction
assessment for proposed harness changes: "how does this behave when
information is incomplete, when the agent is confused, when context is
large?" Our three-layer governance model (prevention/detection/audit) is
itself a friction management strategy -- but we do not explicitly evaluate
new additions against friction cost.

**Problem addressed**: P1 (Scope), P3 (Roles)

### 1.2 Innere Fuhrung (Inner Leadership)

The Bundeswehr's ethical framework, established 1955. Core concept: the
soldier as "citizen in uniform" (Staatsburger in Uniform). Key principles:

- **Obedience born of understanding** (not blind obedience) -- soldiers must
  understand WHY an order exists to follow it properly
- **Mandatory ethical reflection** -- two hours per month, regardless of rank
- **Right to refuse unlawful orders** -- and the obligation to refuse them
- **Freedom of conscience** -- retained while in service

**Harness relevance**: This maps to our deny-rule pattern and the surfacing
duty. Agents are not blindly obedient -- they have standing orders (PSO/USO)
that override instructions, and a duty to surface ambiguities and deviations.
The concept of "obedience born of understanding" supports our intent
documentation requirement: every rule must explain its WHY so agents can
apply it correctly in novel situations.

The mandatory reflection component maps to Hansei (see section 3.2) and to
our AAR/SessionEnd pattern. But Innere Fuhrung makes it **non-optional and
periodic**, not just triggered by session end.

**Problem addressed**: P5 (Intent), P3 (Roles)

### 1.3 Prussian Generalstab (General Staff System)

Key concepts from the original Scharnhorst/Gneisenau system:

- **Selection by merit, not patronage** -- staff officers chosen by
  demonstrated intelligence and proven performance
- **Exhaustive structured training** -- not just skills but judgment
- **The staff officer as advisor with right to participate in command** --
  Gneisenau's innovation: the chief of staff advises until the commander
  decides, but participates in the decision process
- **Staff officers designed to "support incompetent generals"** --
  Scharnhorst's original intent: the system must work even when the
  commander is weak

**Harness relevance**: The "support incompetent generals" principle is
directly relevant to AI agent governance. The harness must produce good
outcomes even when the agent session is degraded (context rot, rule fade,
confused state). This validates our three-layer approach: if prevention
fails (the "general" ignores the rule), detection catches it (hooks), and
audit reviews it (skills).

The staff advisor model maps to our S1/S2/S3 pattern but adds nuance:
the advisor has a **right to participate** in the decision, not just
provide information. This supports the idea that governance hooks should
be able to block actions (not just warn), which we already implement in
some PreToolUse hooks.

**Problem addressed**: P3 (Roles), P5 (Intent)

---

## 2. Other Military Doctrines

### 2.1 Israeli Defense Forces: Rosh Gadol / Rosh Katan

**Rosh Gadol** (literally "big head") -- a person who sees the bigger
picture, takes initiative, and goes beyond the immediate task to ensure
the end goal is achieved. **Rosh Katan** ("small head") -- one who obeys
instructions literally and avoids initiative beyond their exact wording.

This is Israeli military slang that has entered general Hebrew. Unlike
Auftragstaktik (which is doctrinal), Rosh Gadol/Katan is a **cultural
evaluation framework** -- it classifies people's behavior disposition, not
a command method.

Key IDF cultural elements:
- **"Follow Me" leadership** -- officers lead from the front, shared danger
- **Flat hierarchy** -- soldiers are encouraged to challenge leaders
- **Dugri** -- directness, saying what you mean without diplomatic padding
- **Tolerance for productive disobedience** -- the IDF has a persistent
  pattern of accepting orders disobedience when it serves operational needs

**Harness relevance**: The Rosh Gadol/Katan distinction maps to our agent
behavior modes. A Rosh Gadol agent would proactively file incidents when it
notices ambiguities (our surfacing duty). A Rosh Katan agent would follow
rules literally and miss their intent. Our coaching items (UCI) are
essentially trying to move agent behavior from Rosh Katan toward Rosh Gadol.

The "tolerance for productive disobedience" is relevant to scope governance:
sometimes the right action IS to deviate from the plan, but only when the
deviation serves the commander's intent. Our FRAGORD (fragmentary order)
pattern handles this -- amendments to plans that preserve intent while
changing method.

The IDF's flat hierarchy and Dugri culture are relevant to our
human-agent interaction model: the agent should be direct about problems
(not diplomatic), should challenge unclear instructions (UCI: "Clarify
before complying"), and should surface issues immediately rather than
waiting to be asked.

**Problem addressed**: P1 (Scope), P5 (Intent)

### 2.2 NATO STANAG: Standardization for Interoperability

NATO STANAGs (Standardization Agreements) are the mechanism by which 30+
nations achieve interoperability despite different languages, equipment,
and doctrines. Key concepts:

- **Standardization levels**: compatibility (can work together),
  interchangeability (can substitute), commonality (identical)
- **Ratification with reservations** -- nations can adopt a STANAG "with
  reservations," meaning they comply except for specific documented
  exceptions
- **Doctrine documents cascade**: strategic (AJP-01) to operational
  (AJP-3) to tactical (AJP-3.2) with increasing specificity

**Harness relevance**: The "ratification with reservations" pattern is
directly applicable to our multi-agent coordination problem. When a new
rule or framework is adopted, different contexts (projects, users, agents)
might need to adopt it with documented exceptions rather than wholesale.
Our current model is binary: a rule either applies or doesn't.

The cascading doctrine model (strategic to tactical) maps to our artifact
hierarchy: CLAUDE.md (strategic) to rules (operational) to skills
(tactical). But NATO adds formal version control and update propagation
between levels -- when a strategic document changes, all downstream
documents are reviewed for consistency. We do not currently have this
cascade-update mechanism.

**Problem addressed**: P3 (Roles), P4 (Decomposition)

### 2.3 French Military Doctrine: Subsidiarite and Audace

French doctrine emphasizes:
- **Subsidiarite** (subsidiarity) -- decisions should be made at the lowest
  competent level. Unlike Auftragstaktik (which focuses on HOW the
  subordinate executes), subsidiarity focuses on WHO should decide.
- **Audace** (audacity) -- risk-taking is explicitly encouraged. "It is
  audacity encouraged by subsidiarity that makes it possible to seize
  opportunities" (FT-02, Tactique Generale, 2008).
- **Command by objective** (commandement par objectif) -- similar to
  Auftragstaktik but with the French emphasis on speed and decisiveness.

**Harness relevance**: Subsidiarity is a useful principle for determining
where governance logic should live. Currently our placement decisions
(rule vs skill vs reference) are governed by content type. Subsidiarity
would add a second criterion: governance decisions should be made at the
lowest level that has sufficient context. This means hooks (closest to
the action) should handle simple cases, with escalation to rules (broader
context) and then to skills (full analysis) for complex cases.

**Problem addressed**: P3 (Roles), P1 (Scope)

---

## 3. Japanese/Toyota Organizational Concepts

### 3.1 Hoshin Kanri (Policy Deployment) and Catchball

Hoshin Kanri is a strategic alignment methodology that cascades objectives
from top management to frontline workers through a process called
**Catchball** -- bidirectional dialogue where objectives and plans are
exchanged back and forth until alignment is reached.

Key components:
- **Breakthrough objectives** -- transformational goals (not incremental)
- **Annual objectives** -- derived from breakthrough goals
- **Catchball** -- iterative refinement between levels
- **X-Matrix** -- single-page visualization of goals, strategies, metrics,
  and responsible owners
- **Regular review** -- monthly/quarterly progress assessment

The critical insight: **Catchball prevents scope creep by making every
objective negotiated bidirectionally.** A top-level objective cannot simply
be imposed; the lower level must confirm it is achievable and identify
what must be given up to achieve it. This creates natural scope boundaries
because resources are explicitly finite.

**Harness relevance**: HIGH. Catchball directly addresses P1 (scope creep)
and P4 (briefing decomposition). When decomposing the 54-decision brief
into sub-briefings, each sub-briefing should go through a Catchball
process: the decomposition proposes an intent and scope, the executing
agent confirms feasibility and identifies conflicts, and the scope is
refined through iteration. This prevents the "legitimate but unbounded
expansion" problem because each expansion must survive Catchball
negotiation.

The X-Matrix concept could inform how we visualize the relationship
between briefing decisions, their dependencies, and their responsible
sessions.

**Problem addressed**: P1 (Scope), P4 (Decomposition), P5 (Intent)

### 3.2 Hansei (Self-Reflection)

Hansei is mandatory self-reflection at Toyota, conducted regardless of
whether the outcome was success or failure. Key properties:

- **Intellectual AND emotional** -- recognizing the gap between current
  and ideal state
- **Non-punitive** -- the objective is learning, not blame
- **Structured** -- conducted at key milestones and at project end
- **Includes successful outcomes** -- not just failures. "If you say you
  had no problems, that is a problem" (Toyota saying)

**Harness relevance**: Our AAR (After Action Review) pattern already
captures some of this. But Hansei adds two dimensions our AAR lacks:
1. Reflection on SUCCESS to understand what might have gone right by
   accident rather than by design
2. The emotional/accountability dimension -- taking personal
   responsibility for gaps, not just documenting them

Combined with Innere Fuhrung's mandatory periodic reflection, this
suggests our SessionEnd hook should include a structured Hansei
checkpoint, not just KPI collection.

**Problem addressed**: P2 (Carry-forward), P1 (Scope)

### 3.3 Nemawashi (Root Preparation / Consensus Building)

The practice of informal consultation BEFORE formal decision-making.
Nemawashi literally means "digging around the roots" before transplanting
a tree. Key properties:

- **Informal precedes formal** -- concerns are addressed in 1:1 or small
  group conversations before the formal decision point
- **Reduces resistance** -- by the time a proposal is formally presented,
  all stakeholders have already been consulted
- **Identifies hidden dependencies** -- informal conversation surfaces
  issues that formal processes miss

**Harness relevance**: This maps to our incident discovery process. When
a session finds a potential ambiguity, the current process is to
immediately file an incident. Nemawashi would suggest an intermediate
step: informal investigation to determine whether it IS an ambiguity
(perhaps the answer exists in a reference file the agent hasn't read)
before formal filing. This reduces incident noise.

More broadly, Nemawashi applies to how we decompose the planning brief:
before formally splitting 54 decisions into sub-briefings, conduct
informal exploration (research sessions like this one) to identify hidden
dependencies between decisions.

**Problem addressed**: P4 (Decomposition), P1 (Scope)

### 3.4 Ringi System (Document Circulation for Approval)

The formal complement to Nemawashi. A Ringi-sho (proposal document)
circulates from the originator upward through the hierarchy, with each
person affixing their seal (hanko) to indicate approval. Key properties:

- **Bottom-up origination** -- proposals come from the people closest to
  the work, not from management
- **Sequential review** -- each level reviews before passing up
- **Documented trail** -- the hanko trail shows who reviewed and approved
- **Slow but thorough** -- can take a month for complex decisions

**Harness relevance**: Our source-of-truth protection gate is a
simplified Ringi process: changes to protected files must be drafted,
presented, and approved before writing. The Ringi system adds the
concept of **sequential review levels**, which could be useful for
changes that affect multiple systems (e.g., a change to aitools-lib
that propagates to all deploy scripts).

**Problem addressed**: P3 (Roles), P5 (Intent)

### 3.5 Yokoten (Horizontal Deployment / Copy and Improve)

The practice of sharing improvements laterally across organizational
silos. Key insight: Yokoten is NOT standardization. It is "copy and
improve" -- each receiving unit adapts the improvement to their context
rather than applying it identically.

**Harness relevance**: This directly maps to our framework adoption
process (double-loop learning). When we adopt a concept from an external
discipline, we do not copy it identically -- we adapt it to the harness
context. Yokoten validates this approach and gives it a name. It also
applies to cross-project harness improvements: when one project discovers
a useful pattern, other projects should "go see" and adapt it, not just
copy the rules verbatim.

**Problem addressed**: P2 (Carry-forward), P3 (Roles)

### 3.6 A3 Thinking (One-Page Structured Problem Solving)

Toyota's practice of constraining any problem analysis to a single A3
sheet (11x17 inches). The constraint forces structured thinking:
background, current condition, goal, root cause analysis, countermeasures,
implementation plan, follow-up -- all on one page.

**Harness relevance**: HIGH. This directly addresses P4 (briefing
decomposition). Each sub-briefing could follow an A3-like constraint:
purpose, current state, target state, key decisions, dependencies, and
acceptance criteria -- all fitting in a single coherent document. The
constraint prevents scope expansion because there is literally no room
for it.

A3 thinking also addresses P1 (scope creep) at the session level: each
session could have an "A3" that declares its scope, target state, and
constraints on a single page.

**Problem addressed**: P1 (Scope), P4 (Decomposition), P5 (Intent)

### 3.7 Toyota Kata (Improvement Kata + Coaching Kata)

Mike Rother's codification of Toyota's improvement routines:

- **Improvement Kata**: a four-step pattern: (1) understand the direction,
  (2) grasp the current condition, (3) establish the next target condition,
  (4) experiment toward the target condition
- **Coaching Kata**: the structured dialogue a coach uses to guide a learner
  through the Improvement Kata (five questions)

The key insight: it is not the solutions that matter but the **routine for
finding solutions**. The kata is a repeatable pattern that develops
problem-solving capability.

**Harness relevance**: The Coaching Kata maps to our UCI/PCI system. Each
coaching item is essentially a "next target condition" for agent behavior.
The Improvement Kata's four-step pattern could formalize how we approach
each coaching improvement: understand the direction (what good looks like),
grasp current condition (what actually happens), establish target (specific
behavior change), experiment (try it and assess).

**Problem addressed**: P2 (Carry-forward), P5 (Intent)

---

## 4. OODA/Cynefin/Decision Frameworks

### 4.1 Boyd's OODA Loop

The OODA loop (Observe, Orient, Decide, Act) is often simplified to a
simple cycle. Boyd's actual model is more nuanced:

- **Orient** is the critical phase -- it includes cultural traditions,
  previous experience, genetic heritage, and new information. Orientation
  shapes what you observe and how you decide.
- **Speed of cycling** is the competitive advantage -- getting inside the
  opponent's decision cycle
- **Implicit guidance and control** -- experienced operators skip the
  explicit Decide phase, going directly from Orient to Act based on
  trained patterns

**Comparison to our DTCC**: Our discovery-to-continuation cycle
(Discovery, Triage, Continuation, Closure) maps loosely to OODA but has
important differences. DTCC is a lifecycle for incidents/findings; OODA
is a decision cycle for action. They operate at different levels. However,
OODA's emphasis on **Orientation** (bringing all context to bear on the
current situation) is relevant to our running estimate problem: the
Orient phase is essentially the running estimate -- the accumulated
context that shapes how new information is interpreted.

The "implicit guidance and control" concept maps to our hook system:
experienced patterns (hooks) that bypass explicit deliberation for
known situations.

**Problem addressed**: P2 (Carry-forward), P5 (Intent)

### 4.2 Cynefin Framework (Snowden)

Five domains for classifying situations:

| Domain | Cause-Effect | Response Pattern | Example |
|--------|-------------|-----------------|---------|
| Clear | Obvious | Sense-Categorize-Respond | Following a known script |
| Complicated | Discoverable | Sense-Analyze-Respond | Diagnosing a build failure |
| Complex | Emergent | Probe-Sense-Respond | Designing a new framework |
| Chaotic | None apparent | Act-Sense-Respond | Broken production deployment |
| Confusion | Unknown domain | Gather info to classify | Novel problem type |

**Harness relevance**: HIGH. This directly addresses how agents should
handle different types of problems. Currently, our rules treat all
problems uniformly. Cynefin would suggest:

- **Clear domain**: Follow the rule literally (hook enforcement, check
  scripts). No judgment needed.
- **Complicated domain**: Invoke the skill (governed process). Analysis
  required but the answer is knowable.
- **Complex domain**: Probe first (research sessions, subagent
  exploration). The answer emerges from experimentation.
- **Chaotic domain**: Act immediately to stabilize (fix the break, then
  analyze). Our incident-first pattern for operational incidents.

This classification could inform how we decompose the planning brief:
decisions in the Clear domain (known patterns) can be batched and
executed quickly. Complex-domain decisions (novel frameworks) need
research sessions first. This is a decomposition criterion we currently
lack.

**Problem addressed**: P4 (Decomposition), P1 (Scope), P3 (Roles)

### 4.3 Wardley Mapping (Situational Awareness)

Simon Wardley's mapping technique positions components along two axes:
value chain position (visibility to user) and evolution stage (genesis
to commodity). Key concepts:

- **Situational awareness** -- you cannot make good strategy without
  understanding where your components are in their evolution
- **Evolution stages**: Genesis (novel) to Custom Build to Product to
  Commodity
- **Doctrine** -- universally applicable principles (vs strategy, which
  is context-dependent)
- **Gameplay** -- specific strategic moves based on the map

**Harness relevance**: Wardley's distinction between Doctrine and
Strategy maps to our distinction between rules (doctrine -- always
applicable) and plans (strategy -- context-dependent). The evolution
axis could help classify harness components: some are genesis (novel
patterns being explored), some are commodity (well-understood patterns
like logging). This matters for prioritization: invest governance effort
in genesis/custom components, not commodities.

**Problem addressed**: P3 (Roles), P4 (Decomposition)

### 4.4 Architectural Decision Records (ADRs)

Software engineering practice for recording architectural decisions. Key
concepts:

- **One decision per record** -- atomic, not bundled
- **Status lifecycle**: proposed, accepted, deprecated, superseded
- **Context/Decision/Consequences** structure
- **Immutable once accepted** -- new decisions supersede old ones rather
  than editing them
- **Organizational subdirectories** -- large ADR collections use
  functional decomposition for organization

**Harness relevance**: Our planning brief decisions are essentially ADRs.
The ADR practice of **one decision per record** and **functional
decomposition for large sets** directly addresses P4 (briefing
decomposition). The 54 decisions could be organized into subdirectories
by domain (scope governance, carry-forward, artifact roles, etc.),
with clear supersession chains.

The immutability principle is interesting: rather than editing existing
decisions, new decisions supersede them. This preserves the decision
trail and makes it clear when and why a decision changed.

**Problem addressed**: P4 (Decomposition), P5 (Intent)

---

## 5. Knowledge Management / Scope Governance

### 5.1 Legal Drafting: Scope Limitation Techniques

Contract law has centuries of experience preventing scope creep. Key
techniques:

- **Definitions section** -- every term defined precisely, preventing
  semantic drift. "Including" always means "including but not limited to."
- **Exclusions clause** -- explicitly states what is OUT of scope. "This
  does not cover X, Y, Z."
- **Change order procedures** -- any scope change requires formal written
  agreement with documented rationale
- **Severability** -- if one provision is invalid, the rest survive.
  Can specify which provisions are severable and which are core.
- **Entire agreement clause** -- the document is the complete agreement;
  no external promises or understandings apply

**Harness relevance**: HIGH. Several techniques are directly applicable:

1. **Exclusions clause for intents**: Our intent statements currently say
   what IS covered ("Purpose: ... Scope: ..."). Legal drafting adds what
   is NOT covered ("NOT: ..."). We partially do this ("NOT the harvesting
   process itself") but inconsistently. Making it mandatory would prevent
   scope drift at the file level.

2. **Change order procedure for scope expansion**: Any expansion of a
   session's or briefing's scope should require a formal FRAGORD with
   documented rationale. We have FRAGORDs but they are not consistently
   used for scope changes.

3. **Severability for rules**: If one rule becomes invalid or
   contradictory, the rest should continue to apply. This is implicit in
   our current system but not formalized.

4. **Entire agreement for sessions**: A session's scope is defined by its
   briefing/plan. External understandings from previous sessions do not
   automatically apply unless carried forward explicitly.

**Problem addressed**: P1 (Scope), P5 (Intent), P3 (Roles)

### 5.2 Information Architecture: Coherence Maintenance

Key principles for large documentation systems:

- **Clear boundaries between documentation levels** -- information goes
  into appropriate levels, defined from the start
- **Content hygiene** -- stale, duplicated, or poorly structured content
  degrades the entire system
- **Hierarchical organization** -- mirrors how people categorize
  information mentally
- **Consistent formatting standards** -- reduce cognitive load when
  reading across documents

**Harness relevance**: We already practice most of these through our
artifact roles (rules, skills, references, registries) and intent
documentation. The gap is **proactive content hygiene** -- we do not
currently have a systematic process for detecting and resolving
staleness, duplication, or misplaced content across the harness. The
`/audit` skill partially covers this but is on-demand, not systematic.

**Problem addressed**: P3 (Roles), P1 (Scope)

### 5.3 Library Science: Authority Control

Beyond Ranganathan's faceted classification (already adopted for our
governed vocabulary), library science offers:

- **Authority files** -- definitive lists of approved terms with
  cross-references from variant forms. Our glossary.json serves this
  function.
- **See/See Also references** -- formal relationships between terms
  (broader, narrower, related). Our glossary has definitions but not
  systematic cross-references between terms.
- **Scope notes** -- brief statements clarifying how a term should be
  used. Our glossary definitions partially serve this purpose.

**Harness relevance**: Moderate. We already have the core concepts
through our governed vocabulary framework. Adding formal cross-references
(broader/narrower/related) between glossary terms could help agents
navigate the terminology more effectively.

**Problem addressed**: P3 (Roles)

---

## 6. Synthesis Matrix

### Concept x Problem Area x Leverage Score

Leverage is scored 1-5:
- 5 = Directly solves the problem with minimal new infrastructure
- 4 = Strongly addresses the problem, requires moderate infrastructure
- 3 = Partially addresses the problem
- 2 = Tangentially relevant
- 1 = Interesting but low practical impact

| Concept | Source | P1 SCOPE | P2 CARRY | P3 ROLES | P4 DECOMP | P5 INTENT | Total | New Infra |
|---------|--------|----------|----------|----------|-----------|-----------|-------|-----------|
| **Schwerpunkt** | German/Clausewitz | **5** | 2 | 2 | 4 | 4 | **17** | Low |
| **Catchball** (Hoshin Kanri) | Japanese | **5** | 3 | 2 | **5** | 4 | **19** | Low |
| **A3 Thinking** | Toyota | **5** | 2 | 3 | **5** | 4 | **19** | Low |
| **Cynefin domains** | Snowden | 4 | 2 | 4 | **5** | 3 | **18** | Low |
| **Lagebeurteilung** | German/Bundeswehr | 3 | **5** | 2 | 2 | 3 | **15** | Medium |
| **Exclusions clauses** | Legal drafting | **5** | 1 | 4 | 2 | **5** | **17** | Low |
| **Mitdenken** | German | 2 | 4 | 2 | 2 | **5** | **15** | Medium |
| **Rosh Gadol/Katan** | IDF | 3 | 2 | 2 | 2 | 4 | **13** | Low |
| **Hansei** | Toyota | 3 | 4 | 2 | 2 | 3 | **14** | Low |
| **Yokoten** | Toyota | 1 | 4 | 3 | 1 | 2 | **11** | Low |
| **Subsidiarity** | French | 3 | 1 | 4 | 2 | 3 | **13** | Low |
| **Ringi system** | Japanese | 2 | 1 | 3 | 2 | 3 | **11** | Medium |
| **Nemawashi** | Japanese | 3 | 2 | 1 | 3 | 2 | **11** | Low |
| **ADR decomposition** | Software eng. | 1 | 2 | 2 | **5** | 3 | **13** | Low |
| **OODA Orient phase** | Boyd | 2 | 4 | 1 | 2 | 3 | **12** | Medium |
| **Wardley evolution** | Wardley | 2 | 1 | 3 | 3 | 2 | **11** | Medium |
| **Toyota Kata** | Rother | 2 | 3 | 2 | 1 | 3 | **11** | Medium |
| **NATO reservations** | NATO STANAG | 2 | 1 | 3 | 2 | 2 | **10** | Medium |
| **Reibung assessment** | Clausewitz | 4 | 1 | 3 | 1 | 2 | **11** | Low |
| **Innere Fuhrung** | Bundeswehr | 2 | 1 | 2 | 1 | 4 | **10** | Low |
| **Authority control** | Library science | 1 | 1 | 3 | 1 | 2 | **8** | Low |

---

## 7. Top 5 Recommendations

Ranked by leverage score and implementation feasibility.

### Recommendation 1: Schwerpunkt + Exclusions Clauses = Scope Governance Framework

**Leverage**: Combined score 34. Addresses P1 (SCOPE) at level 5 from two directions.

**Concept**: Every scope-bearing artifact (session, briefing, plan, sub-briefing)
must declare:
1. **Schwerpunkt** -- the single most important objective (German doctrine)
2. **Exclusions** -- what is explicitly OUT of scope (legal drafting)

This is a two-part test: anything proposed during execution must (a) serve the
declared Schwerpunkt AND (b) not fall within the exclusions. If it fails either
test, it requires a formal FRAGORD to amend the scope.

**Provenance**: Clausewitz/Moltke (Schwerpunkt as singular decisive point) +
Anglo-American contract law (exclusions clauses, scope limitation)

**Integration path**:
- **Rule**: Add scope governance rule (`.claude/rules/scope-governance.md`) with
  Schwerpunkt and Exclusions requirements
- **Existing artifact enhancement**: Extend intent statements to include
  Schwerpunkt and Exclusions alongside Purpose/Scope/Audience
- **Hook**: Stop hook could check whether current work aligns with session
  Schwerpunkt
- **Glossary**: Add Schwerpunkt, Exclusions as governed terms
- **Reference**: `reference/framework-scope-governance.md` documenting provenance

**Already covered**: Our intent statements partially cover this (Purpose/Scope),
but lack the singularity constraint of Schwerpunkt and the explicit negation of
Exclusions.

### Recommendation 2: A3 Thinking + Catchball = Briefing Decomposition Method

**Leverage**: Combined score 38. Addresses P4 (DECOMP) at level 5 from two angles.

**Concept**: Decompose the 54-decision planning brief using:
1. **A3 constraint** -- each sub-briefing fits a structured single-page format:
   Schwerpunkt, current state, target state, key decisions (max 7-10), dependencies,
   acceptance criteria
2. **Catchball** -- after initial decomposition, each sub-briefing goes through
   a bidirectional negotiation: "Can you execute this scope? What conflicts arise?
   What must be deferred?"

The A3 constraint prevents sub-briefings from becoming mini planning briefs
(scope creep at the decomposition level). Catchball ensures the decomposition
is feasible and that dependencies are surfaced before execution.

**Provenance**: Toyota Production System (A3 thinking, Ohno) + Hoshin Kanri
(Catchball process, strategic alignment)

**Integration path**:
- **Skill**: `/briefing-decompose` skill that enforces A3 structure
- **Template**: A3 sub-briefing template in reference/
- **Process**: Catchball negotiation step between decomposition and execution
- **Glossary**: Add Catchball, A3 as governed terms

**Already covered**: Our OPORD/FRAGORD pattern handles plan amendments but lacks
the bidirectional negotiation of Catchball. Our intent documentation covers
purpose/scope but lacks the structured constraint of A3.

### Recommendation 3: Cynefin Domain Classification for Decision Routing

**Leverage**: Score 18. Addresses P4 (DECOMP) at level 5 and P3 (ROLES) at level 4.

**Concept**: Classify each decision in the planning brief by Cynefin domain:
- **Clear**: Known pattern, execute per existing rules. Batch and execute quickly.
- **Complicated**: Requires analysis but answer is knowable. Assign to a
  focused session with appropriate skills.
- **Complex**: Answer must emerge through experimentation. Assign to research
  sessions (like this one) with probe-sense-respond cycle.
- **Chaotic**: Immediate action needed to stabilize. Handle as incidents.

This classification determines not just WHAT to do but HOW to approach each
decision -- which is the decomposition criterion we currently lack.

**Provenance**: Cynefin framework (Dave Snowden, 1999)

**Integration path**:
- **Reference**: `reference/framework-cynefin-classification.md`
- **Glossary**: Add Clear/Complicated/Complex/Chaotic as governed terms
  (domain-classification sense, not general English)
- **Planning skill enhancement**: Add Cynefin classification step to
  briefing decomposition
- **Rule**: Guidance on which artifact types handle which domains

**Already covered**: Our three-layer governance (prevention/detection/audit)
partially maps to Cynefin (clear/complicated/complex) but is organized by
WHEN governance acts, not by problem type. Cynefin adds the problem-type
dimension.

### Recommendation 4: Lagebeurteilung = Structured Running Estimate

**Leverage**: Score 15. Addresses P2 (CARRY) at level 5.

**Concept**: Replace our free-form running estimate with the German structured
situation assessment (Lagebeurteilung). Each session start walks through a
fixed checklist:

1. Overall situation (what phase is the project in?)
2. Active plans and their status
3. Open incidents and their severity
4. Pending decisions requiring resolution
5. Carry-forward state from previous sessions
6. Environmental factors (tool versions, platform state)
7. Assessment and recommended priorities

The key addition over our current running estimate: **every category must be
examined even if nothing has changed.** This prevents blind spots from
accumulating across sessions.

**Provenance**: German Bundeswehr (Lagebeurteilung schema from HDv 100/100
Truppenführung) + ADP 5-0 running estimate (already adopted)

**Integration path**:
- **Schema change**: Restructure running-estimate.json to use fixed categories
- **Skill enhancement**: `/running-estimate` skill enforces category walkthrough
- **Hook**: SessionStart hook validates all categories are populated
- **Reference**: Document the category schema and its Bundeswehr provenance

**Already covered**: We have the running estimate concept from ADP 5-0 and
the channel/running-estimate.json implementation. This recommendation adds
the structured-category discipline from German doctrine.

### Recommendation 5: Mitdenken + Hansei = Cognitive Alignment Protocol

**Leverage**: Combined score 29. Addresses P5 (INTENT) at level 5 and P2 (CARRY)
at level 4.

**Concept**: Two complementary practices:
1. **Mitdenken** (during execution): Agents actively model the superior's
   decision space, not just execute their task. When a subagent finds
   information relevant to the broader context, it reports with explicit
   connection to higher-level decisions: "This finding affects briefing
   decision #34 because..."
2. **Hansei** (at milestones): Structured reflection that examines both
   successes and failures, asking "what might have gone right by accident?"
   and "what scope expansion did we accept without explicit decision?"

Together, these create a feedback loop: Mitdenken surfaces relevant
information during execution, Hansei reviews whether that information was
properly used.

**Provenance**: German Auftragstaktik tradition (Mitdenken as cognitive
alignment with superior's intent) + Toyota Production System (Hansei as
structured reflection)

**Integration path**:
- **Subagent prompt enhancement**: Include Mitdenken directive ("model
  the delegating agent's decision space; connect findings to specific
  higher-level decisions")
- **SessionEnd enhancement**: Add Hansei checkpoint to the session end
  process (structured reflection on scope, intent alignment, accidental
  successes)
- **Reference**: `reference/framework-cognitive-alignment.md`
- **Glossary**: Add Mitdenken, Hansei as governed terms

**Already covered**: Our SITREP/FINDING channel pattern partially
implements Mitdenken. Our AAR/SessionEnd hook partially implements
Hansei. This recommendation formalizes both and connects them.

---

## 8. Concepts Already Covered

The following researched concepts map to existing harness frameworks:

| Concept | Source | Already Covered By | Gap |
|---------|--------|--------------------|-----|
| Auftragstaktik (basic) | German | FM 101-5-2, subagent delegation | Only English interpretation adopted; original nuances (Selbstandigkeit, Mitdenken) not captured |
| Running estimate | ADP 5-0 | Channel/running-estimate.json | Lacks structured categories (see Lagebeurteilung) |
| After Action Review | FM 7-0 | SessionEnd hook, AAR pattern | Lacks Hansei's success-reflection and emotional accountability dimensions |
| Double-loop learning | Argyris | Framework adoption process | Well covered |
| Ubiquitous language | Evans/DDD | Governed vocabulary | Well covered |
| Faceted classification | Ranganathan | Governed vocabulary composition | Well covered |
| Capability-based security | Dennis & Van Horn | Governed data access | Well covered |
| Layered defense | Swiss cheese / Reason | Three-layer governance | Well covered |
| 5 Whys | Toyota/Ohno | Incident investigation | Well covered |
| SRE observe-then-enforce | Google SRE | Hook rollout, tool ops | Well covered |
| Tactical-to-strategic | Ousterhout | Artifact harvesting | Well covered |
| CALL OIL taxonomy | US Army CALL | Incident classification | Well covered |
| Kaizen | Toyota | Continuous improvement via incidents | Covered implicitly, not formally adopted |
| OODA loop (simplified) | Boyd | DTCC pattern | Orient phase richness not captured |
| ISO purpose/scope/audience | ISO | Intent documentation | Well covered |

### Notable Gaps in Current Coverage

1. **Scope governance** -- no dedicated framework. Schwerpunkt/Exclusions would fill this.
2. **Problem classification** -- no Cynefin-like routing. All problems treated uniformly.
3. **Briefing decomposition method** -- no structured approach. A3/Catchball would fill this.
4. **Structured carry-forward** -- running estimate exists but lacks category discipline.
5. **Cognitive alignment** -- SITREP/FINDING exists but Mitdenken principle not formalized.

---

## Sources

### German Doctrine
- [Mission-type tactics - Wikipedia](https://en.wikipedia.org/wiki/Mission-type_tactics)
- [The Origins of Auftragstaktik - Army University Press](https://www.armyupress.army.mil/Portals/7/Hot-Spots/docs/MC/MR-Sep-Oct-2002-Widder.pdf)
- [How the Germans Defined Auftragstaktik - Small Wars Journal](https://archive.smallwarsjournal.com/index.php/jrnl/art/how-germans-defined-auftragstaktik-what-mission-command-and-not)
- [Auftragstaktik Leads to Decisive Action - USNI Proceedings](https://www.usni.org/magazines/proceedings/2025/may/auftragstaktik-leads-decisive-action)
- [Fuehren mit Auftrag - German Wikipedia](https://de.wikipedia.org/wiki/F%C3%BChren_mit_Auftrag)
- [Bundeswehr Innere Fuehrung](https://www.deutschland.de/en/topic/politics/bundeswehr-innere-fuehrung)
- [Learning from Germany's Inner Guidance - Wavell Room](https://wavellroom.com/2017/12/12/learning-from-germanys-inner-guidance-the-ethical-citizen-soldier/)
- [Innere Fuehrung ethics and military force](https://www.ethikundmilitaer.de/en/magazine-datenbank/detail/2021-02/article/innere-fuehrung-as-an-attempt-to-answer-the-question-of-military-force-theological-and-ethical-remarks-on-the-current-debate)
- [German General Staff - Wikipedia](https://en.wikipedia.org/wiki/German_General_Staff)
- [Schwerpunkt and center of gravity](https://defense-and-freedom.blogspot.com/2010/01/schwerpunkt-and-center-of-gravity.html)
- [Development of Schwerpunkt - Army University Press](https://www.armyupress.army.mil/Portals/7/military-review/Archives/English/MilitaryReview_20070228_art014.pdf)
- [Truppenführung - Wikipedia](https://en.wikipedia.org/wiki/Truppenf%C3%BChrung)
- [Clausewitz friction and fog of war](https://www.thesandreckoner.co.uk/fog-and-friction-the-limitations-of-strategy-in-dealing-with-uncertainty/)
- [Moltke and no plan survives contact](https://quoteinvestigator.com/2021/05/04/no-plan/)

### IDF / NATO / French Doctrine
- [IDF Follow Me ethos - Times of Israel](https://www.timesofisrael.com/the-follow-me-ethos-and-its-perils/)
- [Rosh Gadol concept](https://www.blog.gr2010.com/understanding-the-unique-israeli-concept-of-rosh-gadol-%D7%A8%D7%90%D7%A9-%D7%92%D7%93%D7%95%D7%9C/)
- [Rosh Gadol managing for initiative](https://www.nathanzeldes.com/blog/2013/03/rosh-gadol-how-you-can-manage-for-initiative-and-get-away-with-it/)
- [NATO Standardization](https://www.nato.int/en/what-we-do/deterrence-and-defence/standardization)
- [STANAG - Wikipedia](https://en.wikipedia.org/wiki/Standardization_agreement)
- [French Army high intensity warfare - Wavell Room](https://wavellroom.com/2022/06/22/french-army-warfare/)
- [French military doctrine - MilitarySphere](https://militarysphere.com/principles-guiding-french-military-doctrine/)

### Japanese / Toyota
- [Hoshin Kanri - Lean Production](https://www.leanproduction.com/hoshin-kanri/)
- [Hoshin Kanri Catchball - Businessmap](https://businessmap.io/lean-management/hoshin-kanri/what-is-catchball)
- [Nemawashi and Wa](https://harishsnotebook.wordpress.com/2016/05/15/the-idea-of-wa-in-nemawashi/)
- [Ringi system - Inventure Japan](https://www.inventurejapan.com/culture/business/ringi)
- [Hansei - Toyota Management System](https://www.ineak.com/hansei-responsibility-self-reflection-and-organizational-learning/)
- [Hansei - Lean Enterprise Institute](https://www.lean.org/lexicon-terms/hansei/)
- [Yokoten - Lean Enterprise Institute](https://www.lean.org/the-lean-post/articles/yokoten-capturing-and-sharing-best-practices/)
- [Toyota Kata - Wikipedia](https://en.wikipedia.org/wiki/Toyota_Kata)
- [A3 Report - MIT Sloan](https://sloanreview.mit.edu/article/toyotas-secret-the-a3-report/)
- [A3 Problem Solving - Lean Enterprise Institute](https://www.lean.org/lexicon-terms/a3-report/)
- [Toyota Production System - global.toyota](https://global.toyota/en/company/vision-and-philosophy/production-system/)
- [Genchi Genbutsu and TPS pillars](https://mag.toyota.co.uk/13-pillars-of-the-toyota-production-system/)

### Decision Frameworks
- [OODA loop - Wikipedia](https://en.wikipedia.org/wiki/OODA_loop)
- [OODA loop - Farnam Street](https://fs.blog/ooda-loop/)
- [Cynefin framework - Wikipedia](https://en.wikipedia.org/wiki/Cynefin_framework)
- [Cynefin - Untools](https://untools.co/cynefin-framework/)
- [Wardley Mapping - Wikipedia](https://en.wikipedia.org/wiki/Wardley_map)
- [ADR - adr.github.io](https://adr.github.io/)
- [ADR best practices - AWS](https://aws.amazon.com/blogs/architecture/master-architecture-decision-records-adrs-best-practices-for-effective-decision-making/)

### Scope Governance / Knowledge Management
- [Contract scope definition - UpCounsel](https://www.upcounsel.com/contract-scope-definition)
- [Scope creep in contract management - ContractWorks](https://www.contractworks.com/blog/preventing-and-managing-scope-creep-in-contract-management)
- [10 underused contract clauses](https://danielrosslawfirm.com/2026/02/02/10-underused-contract-clauses-that-strengthen-business-agreements/)
- [Knowledge base information architecture - Document360](https://document360.com/blog/knowledge-base-information-architecture/)
- [Controlled vocabulary - Library science](https://www.librarianshipstudies.com/2020/03/controlled-vocabulary.html)
- [PMI scope creep](https://www.pmi.org/learning/library/controlling-scope-creep-4614)
