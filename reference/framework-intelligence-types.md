# Intelligence Types

**Intent**: **Purpose**: Define the intelligence types the harness records,
and show where each comes from: military intelligence doctrine and
government auditing, adapted to a world of a commander, agents and code.
Record the decisions that shaped the set, so an agent writing an
intelligence item knows which type to use and why. **Scope**: The doctrine
read (quoted, with URLs and dates), the mapping from doctrine to our types
(adopted or not, with the reason), the decided type list (definition,
fields, lifecycle, origin), the retirement of the SALUTE FINDING (RFI 44),
the schema-4 migration rule, maintenance. NOT the table definitions
(`scripts/harness-db.py`, the source of truth; generated copy
`@reference/harness-db-schema.sql`). NOT the provenance graph
(`@reference/framework-provenance.md`). NOT the AAR, running-estimate and
briefing structures (issue #180; only the `/debrief`, `/brief` and
`/channel` skills are deferred, by the commander: "not now, dont do
anything on this yet", answer 5, D-SR11 in issue #180). NOT the term
definitions (`/glossary` skill). **Audience**: Agents that
write intelligence items (`harness-db.py`, AARs, hand-backs); whoever
builds issue #180; the commander, reviewing the adoption.

v1.0 (2026-11-15), mission fa81-04-intel-schema (session 87795dc3).
v1.1 (2026-11-15): after the independent review (PR #181): the FM 1-02.1
edition date, the spot report's usage note, what the CLI writes to
`status`, and facts versus what a delegate learns after a merge.
v1.2 (2026-11-15, session dbd05b0c, RFI 874d-2): the intent no longer
calls issue #180 deferred (answer 5 deferred only the three skills); "How
the types sit in an AAR" records the commander's decisions that supersede
its table (deviations replace findings; objectives, assumptions and
ambiguities at the top; the finding type retired); "Not read" corrects
the AR 11-33 entry (public on armypubs, read by mission
874d-1-aar-doctrine).

## The commander's orders behind this document

All verbatim, session 87795dc3, 2026-11-15:

- "there should be a schema for defined intelligence types" (answer 4,
  issue #180).
- "have the mission look at intelligence types for our millitary domain
  knowledge and doctrine (have it do web research if needed) to better
  inform it on the schema for intelligence types. we need to adapt and
  adopt the types for our world, theres probably a lot of intelligence
  types in military/intelligenece agencies that dont apply in our world of
  commanders, agents, and code." (order 43)
- "having intelligence types we dont use is not a big deal but i agree with
  you that FINDING is redundant." (on RFI 44)
- "i kind of like findings over insights. i like how a finding is defined
  as cause and effect. an insight is also a very passive term isnt it? vs a
  finding is more active and perhaps can carry third element
  1cause/2effect/3suggestion." (his most recent word on the analysis type)
- "46) yes, add it to gh issue mission thing or whatever" (RFI fa81-04-1:
  the AAR's middle node is renamed from `insights` to `findings`).
- Earlier, on 2026-03-30 (dotprofile `sessions/aitools/2026-03-30_ddfe01cb.jsonl`
  L1129): "so the intelligence schema per item, includes provenance, and
  provenance is its own schema and a graph itself".

## Source Disciplines

Military intelligence doctrine (US joint and Army, UK joint with the NATO
grading system) and government auditing (the elements of a finding).

Every source below was read in a browser (chrome-devtools) on 2026-11-15
(UTC) by mission fa81-04; PDFs were text-extracted in the browser with
pdf.js. Quotes are verbatim; curly quotes and dashes are as printed.

### JP 2-0, Joint Intelligence (22 October 2013)

https://irp.fas.org/doddir/dod/jp2_0.pdf. The current edition (2022) is
not public: the Joint Chiefs of Staff page
(https://www.jcs.mil/Doctrine/Joint-Doctrine-Pubs/2-0-Intelligence-Series/)
says "A full list of joint doctrine publications may be found on JEL+. (CAC
required)". FM 2-0 (2023, below) quotes JP 2-0 definitions that match the
2013 text used here.

- Data, information, intelligence (I-1 a): "Raw data by itself has
  relatively limited utility. However, when data is collected from a sensor
  and processed into an intelligible form, it becomes information and gains
  greater utility. Information on its own may be of utility to the
  commander, but when related to other information about the OE and
  considered in the light of past experience, it gives rise to a new
  understanding of the information, which may be termed “intelligence.”"
- (I-1 a): "Information is of greatest value when it contributes to the
  commander’s decision-making process by providing reasoned insight into
  future conditions or situations."
- The process (I-5): "The six categories of intelligence operations are:
  planning and direction; collection; processing and exploitation; analysis
  and production; dissemination and integration; and evaluation and
  feedback."
- Requirements (I-7): "Ultimately, the commander designates PIRs, which
  together with friendly force information requirements (FFIRs), constitute
  the commander’s critical information requirements (CCIRs)." and "The
  development of information requirements (to include EEIs) leads to the
  generation of requests for information (RFIs)."
- Products (I-18): "Intelligence products are generally placed in one of
  eight production categories: warning, current, general military, target,
  scientific and technical (S&T), CI, identity intelligence (I2), and
  estimative intelligence (see Figure I-6). The categories are distinguished
  from each other primarily by the purpose for which the intelligence was
  produced."
- Disciplines (Figure B-1): "GEOINT – Geospatial Intelligence", "HUMINT –
  Human Intelligence", "SIGINT – Signals Intelligence", "MASINT –
  Measurement and Signature Intelligence", "OSINT – Open-source
  Intelligence", "TECHINT – Technical Intelligence", "CI –
  Counterintelligence".
- Facts and assumptions (Appendix A, A-1): "Intelligence analysts should
  distinguish between what is known with confidence based on the facts of
  the situation and the OE and what are untested assumptions."
- Confidence (Figure A-1): "Confidence in a judgment is based on three
  factors: number of key assumptions required, the credibility and
  diversity of sourcing in the knowledge base, and the strength of
  argumentation." and "Confidence levels are stated as Low, Moderate, and
  High."
- Sources (chapter II, the attribute "Accurate" of intelligence
  excellence): "Evaluate source reliability through a
  feedback process in which past data received from a source is compared
  with the “ground truth”".
- Glossary: "intelligence estimate. The appraisal, expressed in writing or
  orally, of available intelligence relating to a specific situation or
  condition with a view to determining the courses of action open to the
  enemy or adversary and the order of probability of their adoption."

### FM 2-0, Intelligence (01 October 2023)

https://irp.fas.org/doddir/army/fm2_0.pdf

- 1-20: "Combat information is a report that is gathered by or provided to
  the tactical commander which, due to its highly perishable nature or the
  criticality of the situation, cannot be processed into tactical
  intelligence before being used to support decision making."
- 1-26: "The Army intelligence process consists of four steps (plan and
  direct, collect and process, produce, and disseminate and integrate) and
  five continuing activities (synchronize, conduct intelligence operations,
  perform PED, analyze, and assess)."
- 1-7 repeats the eight product categories of JP 2-0.
- 1-67, among the products of counterintelligence capabilities (later
  paragraphs list spot reports for other collectors too): "Size, activity,
  location, unit, time, and equipment (SALUTE) and/or spot reports."

### FM 1-02.1, Operational Terms

https://irp.fas.org/doddir/army/fm1-02-1.pdf. The edition of 28 February
2024 that "supersedes FM 1-02.1, dated 09 March 2021" (its date line is
font-encoded in the PDF: each character is shifted by 29 code points;
decoded by the reviewer, fa81-04-rev, and checked by the author).
`@reference/framework-mission-command.md` cites the May 2026 edition on
armypubs.army.mil.

- "spot report — (DOD) A concise narrative report of essential information
  covering events or conditions that may have an immediate and significant
  effect on current planning and operations that is afforded the most
  expeditious means of transmission consistent with requisite security.
  (JP 3-09.3) Also called SPOTREP. (Note: In reconnaissance and
  surveillance usage, spot report is not to be used.)" The note restricts
  the term in reconnaissance and surveillance usage only; FM 2-0 still
  lists spot reports among collection products (below), and our harness
  has no reconnaissance usage.
- "priority intelligence requirement — (DOD) An intelligence requirement
  that the commander and staff need to understand the threat and other
  aspects of the operational environment. (JP 2-0) Also called PIR."
- "commander’s critical information requirement — (DOD) An information
  requirement identified by the commander as being critical to facilitating
  timely decision making. (JP 3-0) Also called CCIR."
- "request for information — (DOD) 1. Any specific time-sensitive ad hoc
  requirement for intelligence information or products to support an
  ongoing crisis or operation not necessarily related to standing
  requirements or scheduled intelligence production. (JP 2-0) Also called
  RFI."
- "running estimate — The continuous assessment of the current situation
  used to determine if the current operation is proceeding according to the
  commander’s intent and if planned future operations are supportable.
  (ADP 5-0)"

### JDP 2-00, Intelligence, Counter-intelligence and Security Support to Joint Operations (4th edition, August 2023)

UK Ministry of Defence:
https://assets.publishing.service.gov.uk/media/653a4b0780884d0013f71bb0/JDP_2_00_Ed_4_web.pdf
(page: https://www.gov.uk/government/publications/jdp-2-00-understanding-and-intelligence-support-to-joint-operations).
It reproduces the NATO Intelligence Grading System and the NATOTerm
definitions, and points to AJP-2 for report formats.

- 1.7: "the deductive and predictive analysis (also known as insight and
  foresight), which provides the added value in an assessment."
- NATOTerm (1.7): "information — Data arranged to convey meaning." and
  "intelligence — The product resulting from the directed collection and
  processing of information regarding the environment and the capabilities
  and intentions of actors, in order to identify threats and other
  opportunities for exploitation by decision-makers."
- 3.39 c: "Reliability and credibility must be evaluated separately. A
  previously reliable source may still provide inaccurate information
  through sincere error or coming under hostile control, and occasionally
  highly credible information can come from a usually unreliable source."
- 3.40 a: "It captures the separate judgements of reliability and
  credibility in a single alphanumeric digraph with reliability graded from
  A to F and credibility from 1 to 6." Also: "a grading of F6 (or either
  element separately) does not render the information useless or mean it
  has no value."
- Table 3.1, The NATO Intelligence Grading System: reliability of the
  source "A Completely reliable", "B Usually reliable", "C Fairly
  reliable", "D Not usually reliable", "E Unreliable", "F Reliability
  cannot be judged"; credibility of the information "1 Confirmed by other
  sources", "2 Probably true", "3 Possibly true", "4 Doubtful", "5
  Improbable", "6 Truth cannot be judged".
- 3.41: "Analysis is defined as: in intelligence usage, an activity in the
  processing phase of the intelligence cycle in which information is
  subjected to review in order to identify significant facts for subsequent
  interpretation."
- Table 3.3: INTREP "Sent whenever information or intelligence is urgent
  and contains any deductions that can be made in the time available.";
  INTSUM "A concise, periodic summary of intelligence about the current
  situation within the joint operations area."

### GAO Government Auditing Standards (the Yellow Book), 2024 revision

https://guides.gaoinnovations.gov/yellowbook/2024/evidence.html#findings-2

- 8.116: "As part of a performance audit, when auditors identify findings,
  they should plan and perform procedures to develop the criteria,
  condition, cause, and effect of the findings to the extent that these
  elements are relevant and necessary to achieve the audit objectives."
- 8.124: "Criteria identify the required or desired state or expectation
  with respect to the program or operation."
- 8.125: "Condition: Condition is a situation that exists."
- 8.126: "Cause: The cause is the factor or factors responsible for the
  difference between the condition and the criteria, and may also serve as
  a basis for recommendations for corrective actions."
- 8.127: "Effect or potential effect: The effect or potential effect is the
  outcome or consequence resulting from the difference between the
  condition and the criteria."

### Not read

- NATO AJP-2 and AJP-2.1, STANAG 2511: no public copy was found (the
  gov.uk Allied Joint Publications collection does not list them). The
  grading system is taken from JDP 2-00 Table 3.1, which names it "The NATO
  Intelligence Grading System".
- ADP 2-0, ATP 2-01.3 (intelligence preparation of the battlefield): not
  read; IPB analyses terrain and an adversary, and nothing here depends on it.
- AR 11-33 and the Center for Army Lessons Learned taxonomy (observation,
  insight, lesson): no copy at irp.fas.org (404). The AAR's node names are
  the commander's (2026-03-16, renamed 2026-11-15), not taken from CALL.
  Correction (v1.2): AR 11-33, Army Lessons Learned Program (28 July 2022),
  is public on armypubs
  (https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN34074-AR_11-33-000-WEB-1.pdf),
  read 2026-11-15 by mission 874d-1-aar-doctrine (session dbd05b0c). Its
  glossary defines "Observation — Notes or comments on an operation, event,
  or exercise from the perspective of the person(s) who perceived or
  experienced it first-hand." and "Issue — An observed, analyzed, and
  validated shortcoming, deficiency, or problem that precludes performance
  to standard and requires resolution-focused problem solving.", and also
  lesson, lessons learned, best practice and trend. It defines no
  "insight". Full quotes: `.aitools/channel/handoffs/2026-11-15_dbd05b0c-missions/874d-1-aar-doctrine/874d-1-aar-doctrine-report.md`
  section 6.

## How We Adopted It

### Our world

A commander (pepe) gives orders and answers questions. A session commander
and its delegates collect, analyse and act. The collectors are agents,
hooks, CI and the commander's own words; the subjects are code, tools,
sessions and decisions. There is no adversary, no terrain and no target.

### Mapping: doctrine term to our type

| Doctrine term (source) | Our type or field | Adopted? Why |
|---|---|---|
| Data (JP 2-0 I-1) | Telemetry: `events.jsonl`, transcripts, logs | Not a type. Raw data is processed before it is an item |
| Information (JP 2-0 I-1; NATOTerm) | **observation** | Adopted: what was seen or reported, no interpretation |
| Intelligence: information related, evaluated and interpreted (JP 2-0 I-1; NATOTerm) | **finding** (analysis), **fact** (confirmed) | Adopted: the line between information and intelligence is the line between observation and finding |
| "Insight and foresight", deductive and predictive analysis (JDP 2-00 1.7) | **finding** | Adopted as finding, not as "insight": the commander, 2026-11-15, "i kind of like findings over insights ... an insight is also a very passive term" |
| Finding: criteria, condition, cause, effect (GAO 8.116-8.127) | **finding** fields: `text` (condition), `criteria`, `cause`, `effect`, `suggestion` | Adopted, with the commander's third element "3suggestion" in place of a full recommendation |
| Recommendation (GAO, reported with findings) | `suggestion` (one line) and **proposal** (the worked change) | Adopted as two levels; see "Suggestion and proposal" |
| Facts versus untested assumptions (JP 2-0 App. A) | **fact**, **assumption** | Adopted |
| Confidence Low / Moderate / High (JP 2-0 Fig. A-1) | `confidence` field (low, moderate, high) | Adopted for analytic judgements (findings, assumptions) |
| Reliability of the source A-F, credibility of the information 1-6 (NATO grading, JDP 2-00 Table 3.1) | Source: `attributed_to`, `source_kind`, `authority_level`. Content: `status`, `trust_level`, `confidence` | Principle adopted (rate the source and the content separately); letter-number grades not adopted: our sources are few and named, and no per-source track record is kept. `trust_level` still mixes the axes (see Follow-ups) |
| Disciplines (JP 2-0 Fig. B-1) | `source_kind`: HUMINT -> `commander` (his words) and `agent` (an agent's report); SIGINT, MASINT -> `telemetry` (hooks, events, CI, KPIs); OSINT -> `web` (documentation read in the browser); TECHINT -> `artifact` (code, files, commits, command output) | Adopted as source kinds, not as types. GEOINT not adopted (no geography). CI (counterintelligence) not adopted as a type: untrusted downloads and injected instructions are handled by standing orders |
| Intelligence process: planning and direction, collection, processing and exploitation, analysis and production, dissemination and integration, evaluation and feedback (JP 2-0 I-5; FM 2-0 1-26) | Item lifecycle: requirements (session RFIs, the Mission Brief), collection (agents, hooks, the commander), processing (writing the item), analysis (findings, operational learning), dissemination (the `[INTEL]` Stop-hook injection, hand-backs, handoffs, relay), evaluation (verify, invalidate, staleness) | Adopted as the frame for the lifecycle, not as types |
| Combat information (FM 2-0 1-20) | A **SPOTREP**: an observation reported before it is analysed | Adopted |
| Spot report, SALUTE (FM 1-02.1; FM 2-0) | **SPOTREP** message (`log --type spotrep`); its content is an observation with a severity | Adopted. Replaces the FINDING message |
| SITREP (planning-brief decision #23) | **SITREP** message | Kept: status, not intelligence |
| INTREP (JDP 2-00 Table 3.3) | Not a separate report: a SPOTREP plus a finding | Not adopted: one urgent report is enough |
| INTSUM (JDP 2-00 Table 3.3) | Handoff, running estimate | Out of scope (issue #180) |
| Request for information (FM 1-02.1; JP 2-0) | **rfi** (a session RFI, `<sid4>-<n>`) | Adopted; already governed as "session RFI" |
| PIR, CCIR (FM 1-02.1) | The commander's intent and the Mission Brief (`/delegate` element 10) | Not adopted as a type now: the briefing structure is issue #180 |
| EEI (JP 2-0 I-7) | None | Not adopted: one level of questions (the RFI) is enough at our scale |
| Warning intelligence (JP 2-0 I-18) | `severity` critical, sent as a SPOTREP | Folded into severity |
| Current and estimative intelligence; intelligence estimate; running estimate (JP 2-0; FM 1-02.1) | Running estimate | Out of scope (issue #180) |
| General military, target, scientific and technical, identity intelligence (JP 2-0 I-18) | None | Not adopted: they describe an adversary, its weapons, targets and people |
| Lesson (lessons learned) | **operational learning** | Adopted: the governed term (commit `4980640`) |

### The decided intelligence types

One set for both databases (the session `observations.category` and the
harness `knowledge_items.item_type`), defined once in
`scripts/harness-db.py` (`INTELLIGENCE_TYPES`). The harness DB also keeps
four record types: `decision`, `commander_directive`, `rule_change`,
`framework_change` (`KNOWLEDGE_ITEM_TYPES`). In a session, decisions and
directives have their own tables (`decision add`, `directive add`).

| Type (stored as) | Definition | Fields beyond the common ones | Lifecycle (`status`) | Origin |
|---|---|---|---|---|
| observation (`observation`) | What was seen or reported at a source, without interpretation | `evidence`; `severity` when it matters at once | pending, verified (corroborated), falsified | Information (JP 2-0; NATOTerm); the SALUTE report |
| fact (`fact`) | An observation confirmed against its source or by a second, independent source | `evidence` | verified; later invalidated (`t_invalid` in the harness DB) | "facts that have been observed" (JP 2-0 App. A); credibility 1 "Confirmed by other sources" |
| assumption (`assumption`) | An unverified belief the work rests on | `evidence`, `confidence` | pending (unverified), verified (record a fact, `validated` edge), falsified (record the contradicting observation, `invalidated` edge) | "untested assumptions" (JP 2-0 App. A) |
| finding (`finding`) | The analysis of observations: the condition found, against what criteria, its cause, its effect, and a one-line suggestion | `text` = the condition; `refs` (session) or `derived_from` edges (harness) to its observations; `criteria`; `cause`; `effect`; `suggestion`; `confidence`; `severity` | pending, verified (rechecked or reviewed by the commander), falsified; superseded by a newer finding | GAO 8.116-8.127; "insight and foresight" (JDP 2-00); the commander, 2026-11-15 |
| operational learning (`operational_learning`) | The lesson drawn from observations and findings: what worked, what failed, what to do differently, carried forward | `refs` to the findings it draws on | verified when recorded (`ol add`); staleness clock in the harness DB | The governed term (`4980640`); lessons learned |
| proposal (`proposal`) | A worked-out change, derived from findings, with barrier analysis | today `text` (the change) and `refs`; barrier analysis, severity, affected files and decisions come with the AAR (issue #180) | proposed, accepted, rejected, deferred (the commander's disposition) | The AAR's third node (commander, 2026-03-16) |
| rfi (`rfi`) | A question for the commander (a session RFI) | `text` (the question with its context), `suggestion` (the suggested answer), `quote` (his answer, verbatim) | open, answered, withdrawn | RFI (JP 2-0; FM 1-02.1); `@reference/framework-request-for-information.md` |

**Common fields, every type** (`scripts/harness-db.py`):

- identity and content: the id (`OBS-<n>`, `OL-<n>` in a session; a stable
  `item_id` in the harness DB), the type, `text` / `content`, `status`,
  `severity`, `confidence`, `created_at`;
- provenance (the commander's 2026-03-30 order, "the intelligence schema per
  item, includes provenance"): `attributed_to` (who: `commander`, a
  delegate's name, a hook), `source_kind` (commander, agent, telemetry,
  artifact, web), `source` (where: path and line, commit SHA, URL,
  transcript line), `quote` (the source text verbatim; always when the
  source is the commander's words);
- in the harness DB also: `version`, `t_valid` / `t_invalid`,
  `authority_level`, `trust_level`, the staleness fields, and
  `provenance_edges` (`derived_from`, `informed`, `triggered`, `validated`,
  `invalidated`, `superseded`).

`status` is free text in the schema (no CHECK): v3 rows hold values such as
`active` and `pending-review` that are kept as they are. The values above
are the ones to write. Today the CLI writes only the first state of each
lifecycle: `observation add` writes `pending` for every type (for an rfi,
pending means open; for a proposal, proposed), and `ol add` writes
`verified`. No verb changes `status` after that yet; the later states are
set by hand or by the AAR and estimate tooling of issue #180.

**Facts and what a delegate learns after a merge.** The commander,
2026-11-15 (answer 4): "dont call them post-merge facts, they are either
observations or operational learning". What a delegate learns after its
merge is recorded as an observation or as operational learning, never as
a "fact" by default. A fact is only an observation that has been
confirmed against its source or by a second source.

### How the types sit in an AAR

The AAR is the commander's three nodes, `observations`, `findings`,
`proposals` (2026-03-16; the middle node renamed from `insights` on
2026-11-15, "46) yes, add it to gh issue mission thing or whatever").

| AAR node | Types |
|---|---|
| `observations` | observation, fact, assumption (with its status) |
| `findings` | finding, operational learning (answer 45, "keep under insights", carried to the renamed node) |
| `proposals` | proposal, rfi |

**Superseded for the AAR (the commander, 2026-11-15, session dbd05b0c).**
The table above is the AAR as PR #181 shipped it. The same day the
commander decided:

- `deviations` replaces the `findings` node, and `deviation` is a governed
  term: something the agent did differently from what it was given to do;
- the objectives sit at the top of the AAR, with the assumptions and the
  ambiguities found in the brief, and `ambiguity` is governed again;
- what the agent acted on (deviations) and what it only saw (observations)
  stay separate categories;
- references are typed: a proposal names the deviations and observations
  it rests on (`deviation_refs[]`, `observation_refs[]`; `finding_refs[]`
  was asked for on L79 before the node was replaced).

- the `finding` type is retired (RFI 874d-13): deprecated in the glossary,
  `replacedBy: deviation`. The harness DB keeps it in `INTELLIGENCE_TYPES`
  until schema 5 (issue #180), which adds `deviation` and `ambiguity` and
  maps v4 findings to observations;
- operational learning is its own top-level node, and `provenance` replaces
  `meta` as the document header (RFI 874d-14).

The full schemas for the mission brief, the AAR and the running estimate are
in issue #180. Until schema 5 ships, the DB types above stand.

### RFI 44: retire FINDING as a separate type

**Decision.** The March FINDING, a SALUTE report of something seen
(planning-brief decision #23: "FINDING (SALUTE): {type, severity, finding,
location:{file,line}, agent, timestamp, context, actionTaken,
recommendation}"), is retired. What it reported is an **observation** with a
severity; the message that carries it at once is a **SPOTREP**. The word
"finding" is kept, with the meaning the commander chose on 2026-11-15: the
**analysis** type (condition, cause, effect, suggestion).

**Reasons.**

1. Doctrine draws its main line between information and intelligence (JP 2-0
   I-1; NATOTerm). The SALUTE FINDING sat on both sides: a reported fact
   with a `recommendation` attached. Splitting it puts the fact in an
   observation and the analysis in a finding.
2. Doctrine names the immediate report of an observed event the spot report
   (FM 1-02.1), in SALUTE format (FM 2-0), and decision #23 already said
   "FINDING severity=critical is the SPOTREP".
3. In auditing, a finding is the analysis: criteria, condition, cause and
   effect (GAO 8.116). The commander chose that sense: "i like how a finding
   is defined as cause and effect".
4. The v3 database proves the ambiguity: `ol add` stored operational
   learning as category `finding`, and March scripts stored audit results
   under the same category (harvested `batch-audit-findings.py`,
   `insert-provenance-observations.py`). One word held three things.

**The session commander's view, confirmed and refined.** The view given to
this mission ("they overlap but are not the same ... what was found is an
observation, what it means is an insight") is confirmed by the doctrine:
information versus intelligence. The refinement is the name: the analysis
type is **finding**, not insight (the commander, 2026-11-15), and the
glossary deprecates "insight" with `replacedBy: finding`.

**A finding and an incident.** The incident record already has the shape
of a finding: `observation` (condition), `expected` (criteria),
`rootCause` (cause), `impact` (effect), `suggestedResolution`
(suggestion). An incident is a finding about a harness deficiency that is
tracked in the incident registry (`/incident` skill). Nothing in the
registry changes.

### Suggestion and proposal

Kept as two levels, not merged. A finding's `suggestion` is one line that
points at the change ("add a CI test that diffs the two files"). A proposal
is the change worked out: what, why, the barrier analysis (would it have
prevented the issue?), what it affects, and the commander's disposition. It
links back with a `derived_from` edge (harness) or `refs` (session).

Reasons: the commander's sketch gives the finding a "suggestion", not a
plan; his AAR (2026-03-16) keeps `proposals` as their own node, with
barrier analysis; GAO reports "findings, conclusions, and recommendations"
as separate parts; and the incident registry already treats
`suggestedResolution` as "a starting point ... NOT a commitment"
(`@.claude/rules/incident-governance.md`). Merging them would put an
unreviewed plan inside every finding.

### Migration from schema 3

`harness-db.py` migrates a DB when it opens it to write (`ensure_schema`).
v3 rows keep their data; values that changed meaning are remapped by rule,
never guessed, and the old value is kept:

| v3 value | v4 value | Rule |
|---|---|---|
| `observations.category = 'finding'`, `severity IS NULL`, `status = 'verified'` | `operational_learning` | The exact signature `ol add` wrote (and the March `batch-ol.py`) |
| any other `observations.category = 'finding'` | `observation` | A SALUTE-style report; severity and status kept |
| `messages.message_type = 'finding'` | `spotrep` | One-to-one rename |
| `knowledge_items.item_type = 'finding'` | `observation` | No severity column in v3; nothing to split on |
| `knowledge_items.item_type = 'ol_entry'` | `operational_learning` | The governed term |

`legacy_category` (session) and `legacy_item_type` (harness) hold the v3
value on every remapped row. No v3 row becomes a v4 `finding`: the analysis
type starts empty.

## How It's Maintained

- The type list, the CHECK constraints and the CLI choices come from the
  tuples in `scripts/harness-db.py`. Change a type there, bump
  `SCHEMA_VERSION`, add the migration to `ensure_schema`, regenerate
  `@reference/harness-db-schema.sql` (`harness-db.py schema --output
  reference/harness-db-schema.sql`), and update this file and the glossary
  together. `tests/harness-db/test-schema.py` fails while the .sql and the
  script differ.
- A new or renamed type needs a glossary entry and a word-list line
  (`/glossary` skill) and a row in the two tables above.
- Re-verify the doctrine citations when a cited edition is superseded
  (JP 2-0's 2022 edition, if it becomes public, replaces the 2013 text).

## Implementing Artifacts

- `scripts/harness-db.py`: `INTELLIGENCE_TYPES`, `KNOWLEDGE_ITEM_TYPES`,
  `MESSAGE_TYPES`, `SOURCE_KINDS`, `CONFIDENCE_LEVELS`, the schema, the
  v3 -> v4 migration, and the `observation add`, `ol add`, `log` and
  `knowledge add` verbs
- `@reference/harness-db-schema.sql` (generated)
- `tests/harness-db/test-schema.py` and its v3 fixtures
  (`tests/harness-db/fixtures/`)
- Glossary entries: intelligence type, observation, fact, assumption,
  finding, insight (deprecated), operational learning, proposal, SPOTREP,
  SITREP (`/glossary` skill)
- This file; registry entry "Intelligence types" (`/frameworks` skill)

## Cross-References

- Provenance graph and trust levels: `@reference/framework-provenance.md`
- Session RFIs: `@reference/framework-request-for-information.md`
- Mission command (the Mission Brief, the commander's intent):
  `@reference/framework-mission-command.md`
- Incidents (a finding about the harness): `@.claude/rules/incident-governance.md`
- AAR, running estimate and briefings: issue #180
