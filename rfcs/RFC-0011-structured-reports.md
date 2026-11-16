# RFC 0011: Structured running estimates, mission briefs and after action reviews

**Intent**: **Purpose**: Specify, as normative text, the three structured
documents the harness uses to brief, report and track work: the mission
brief, the after action review (AAR) and the running estimate. Specify their
shared schema, their files and names, the SQLite store every agent writes to,
the delegation duties that carry them, and their security requirements.
Settle the design points issue #180 left to this RFC. **Scope**: The schema
(nodes, item types, fields), file locations and naming, the store and write
rules, the schema 4 to 5 migration and version skew, validation,
cross-platform and security requirements, the delegation duties, and the
points settled here. NOT the commander's decisions themselves, which this
RFC cites and does not reopen (issue #180 section 1; appendix A shows where
each is carried). NOT the work packages and batches (the plan). NOT the
doctrine research (the issue comment "Doctrine behind the design").
**Audience**: Whoever implements issue #180; every agent that writes or
reads a brief, an AAR or a running estimate; the commander, reviewing the
points settled here.

v1.0 (2026-11-16), session dbd05b0c.
v1.1 (2026-11-16), session dbd05b0c: corrected after four independent
verifiers (missions 874d-3 to 874d-6). It now covers: plain list nodes
versus item nodes; the `fact` type; the full v4 to v5 mapping; version skew;
one SessionEnd job; the scope of `--session`; definitions of `<repo>`, the
record's date and project, and a session; the security exposure in the
public repo; appendix A. The settled points (section 4) are extended to
S-25.
v1.2 (2026-11-16), session dbd05b0c: the commander's answers of L3394,
L3479 and L3589 (D874d-54 to D874d-70). The brief's `rules[]` and
`skills[]` become `artifacts[]` (D874d-65); the brief drops `ambiguities`,
`access`, `name_prefix` and `duties`, and `return` becomes a structured
`deliverables[]` (D874d-70); S-18 and S-19 are accepted (D874d-55, D874d-56);
standing duties stay out of the brief (D874d-64); other repos receive
`.git/info/exclude` entries (D874d-58); no WP-0 verdict is kept
(D874d-68). Also: BCP 14 key words where a rule had none, the issue's
ASM and AMB ids marked as such, the delegation guards' check of the
brief path, and the `<project>` definition.
v1.3 (2026-11-16), session dbd05b0c: the briefs directory (D874d-71 to
D874d-74, the commander's prompt of L4045). A brief resides in the session
scratch directory by default; a brief whose mission outlives its session
resides, on the commander's order, in the tracked `<repo>/briefs/` (3.3.1,
3.3.1a).
v1.4 (2026-11-16), session dbd05b0c: the language, reviewed line by line
against RFC 2119, RFC 8174 and requirement-quality practice by missions
874d-7 (normative language and requirement quality) and 874d-9 (an
implementer's reading); their proposals are applied, merged where both
touched a line. The route to `main` of a brief in the briefs directory is
deferred by the commander (D874d-76).
v1.5 (2026-11-16), session dbd05b0c: consistency and formal register,
reviewed line by line by mission 874d-11 (the relaunch of 874d-8, which an
API safeguard stopped); its proposals are applied, and the session agent's
own pass. Decisions D874d-75 to D874d-77 (L4523).

| Field | Value |
|-------|--------|
| **RFC** | 0011 |
| **Title** | Structured running estimates, mission briefs and after action reviews |
| **Version** | v1.5 |
| **Author(s)** | Session agent dbd05b0c, with the commander (Jose) |
| **Status** | Proposed |
| **Created** | 2026-11-16 |
| **Updated** | 2026-11-16 |
| **Issue** | [nobul-tech/aitools#180](https://github.com/nobul-tech/aitools/issues/180), body v5.6 |
| **Session** | dbd05b0c-2365-4159-9976-bc64a2af874d |
| **Plan** | `plans/structured-reports/implementation-plan.md` |
| **Related** | RFC 0005-v2 (session intelligence), RFC 0006 (delegation), RFC 0010 (Python and SQLite engineering) |

---

## Abstract

This RFC specifies one schema for three documents:
- the **mission brief**: what a delegate is to do, written by the delegating agent before launch;
- the **after action review (AAR)**: what the delegate did against its brief, returned as its hand-back;
- the **running estimate**: the session's living record, written by every agent in the session.

It specifies:
- where each document lives and how each is named;
- the SQLite session DB every agent writes to, and how each kind of agent writes there;
- how the store migrates from schema 4 without data loss or version skew;
- the delegation duties that make delegates produce and read these documents;
- which documents are kept out of a project repo, since the aitools repo is public.

It states as normative text the commander's decisions recorded in issue #180 (D874d-1 to D874d-77), and settles the points that issue left to this RFC (section 4).

---

## Status of this memo

**Proposed.** This RFC is normative for the implementation of issue #180.
- **The commander's decisions** cited as `D874d-<n>` are fixed. This RFC does not reopen them, and appendix A shows where each one is carried. The implementer MUST raise each point it finds unclear with the commander as a session RFI with a suggested answer.
- **Points this RFC settles itself** are marked "Settled by this RFC" and listed in section 4. They are written as a version and listed under "Review after" for the commander's review (D-DEL5).
- **Precedence.** A mission brief is part of the delegation prompt and briefing, which D-DEL6 ranks above harness documents such as this RFC. A delegating agent MUST write each brief to agree with this RFC. A delegate that finds its brief in conflict with this RFC MUST follow the brief, which D-DEL6 ranks higher, and MUST report the conflict in its AAR as an ambiguity (3.4.5).

---

## 1. Motivation

- **No structured hand-back.** A delegate hands back a free-text list (`/delegate` "Final response shape" before v2.6). Nothing in it records what the delegate was told, what it did differently, or what it saw and left alone. Issue #177 (question 2) found that what a delegate learns after its merge has no home.
- **No structured running estimate.**
  - The estimate exists as a stub, `.aitools/channel/running-estimate.json`, and a template that no code reads.
  - The session DB (schema 4) holds intelligence items but no brief, AAR or estimate.
  - RFC 0005-v2 section 4 lists the mission brief and the running estimate as gaps: briefings ("Structured or freeform TBD") and the running estimate ("Aggregate from session DB").
- **No structure for the mission brief.** RFC 0006 section 4 (P1, briefing-first pattern) measured delegation quality, scored out of 5.0, rising from a range of 2.0 to 3.4 to a range of 4.0 to 4.8 once a shared briefing file was written, but never gave that file a structure.
- **The commander's objective.** For issue #180: "implement structured running estimates, briefings, aars".

---

## 2. Terminology

- **Requirements language:** The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in BCP 14 ([RFC 2119](https://www.rfc-editor.org/rfc/rfc2119), [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174)) when, and only when, they appear in all capitals, as shown here. In lowercase, these words have their ordinary English meaning. The capitalized NOT in the intent statement at the head of this document follows the intent-statement convention (`/intent-writing` skill) and is not a key word.
- **Governed terms:** the `/glossary` skill defines these terms: mission brief (synonyms: brief, delegate briefing; D874d-18), after action review (AAR), running estimate and deliverable (D874d-37), deviation, process deviation, observation, ambiguity, assumption, fact, operational learning, proposal, blocker, session RFI, delegating agent, delegate, provenance. This RFC uses them in their glossary meanings. Where this RFC changes a meaning (`mission brief`, `observation`, `assumption`, `artifact`, the session RFI's id), plan batch 2.2 brings the glossary in line. The schema's nodes and fields have no glossary entries at present (D874d-66).
- **Artifact:** in the brief's `artifacts[]` and in `source.kind` `artifact`, a file that the harness or a mission uses: a harness artifact (rule, skill, hook, reference, registry) or a mission's working file (plan, specification, transcript, a file it changes). This is wider than the glossary's `artifact`, a harness file (D874d-67).
- **`ASM-<n>` and `AMB-<n>` without a prefix:** in this RFC, such an id names an assumption or an ambiguity of issue #180 section 6, not an item id of a document (3.2.4).
- **Session:** one Claude Code session, identified by its session id. `/clear` starts a new session (a new id, DB and estimate); `/resume` continues the same session (S-25).
- **Session agent:** the agent of the top-level session, the Claude Code session in which the commander works.
- **Delegate:** the glossary's `delegate`, at any level of the chain of command: any agent launched by another agent.
- **`<repo>`:** the session's project root, recorded in the session DB at session start (`session.project_dir`). It is not the current working directory, which can change during a session (S-22).
- **`<project>`:** the project name under which the session's record is filed. When `<repo>` is in a git repository and the common directory that `git -C <repo> rev-parse --path-format=absolute --git-common-dir` prints is named `.git`, it is the base name of that directory's parent, the main worktree, so a session started in a linked git worktree uses its project's name (for example `aitools`). Otherwise (`<repo>` is not in a git repository, or the common directory is not named `.git`, as in a submodule or a bare repository), it is the base name of `<repo>`.
- **`<sid4>`:** the last four hex digits of the top-level session id (for example `874d`).
- **Session id prefix:** the first 10 characters of the session id, hyphen included (for example `dbd05b0c-2`). In the name of a file, `<session id prefix>` stands for that value, except after a prefix collision (3.6.2), when it stands for the full session id. The session DB, the export and the record (3.8) use the same value.
- **`<mission name>`:** `<commanderid>-<n>-<slug>`, where `<commanderid>` is the last four hex digits of the delegating agent's own id (its session id for the session agent, its agentId for a delegate), `<n>` is a positive integer, and `<slug>` is one or more of the characters `A-Z`, `a-z`, `0-9` and `-` (`/delegate` naming conventions).
- **Session scratch directory:** `<repo>/.scratch/session-<session id>/` of the top-level session, written `<session scratch dir>` in path patterns.
- **Session DB:** the SQLite file of one top-level session, `<repo>/.aitools/sessions/<session id prefix>.db` (3.6.1).
- **Briefs directory:** `<repo>/briefs/`, the tracked directory that holds the mission briefs whose missions outlive the session that wrote them (3.3.1).
- **Hand-back:** the final message of a delegate to its delegating agent, which is its AAR (D874d-47); not a `handoff` of a session (glossary).
- **Schema 5 ships:** `aitools` has deployed, on the machine where the session runs, a `harness-db.py` that writes schema 5, together with the hooks that call it (3.6.12).
- **Abbreviations:** AAR, after action review; AMB, ambiguity (the issue's id prefix); ASM, assumption (the issue's id prefix); BCP, Best Current Practice; CLI, command-line interface; DB, database; DDL, data definition language; hex, hexadecimal; id, identifier; JSON, JavaScript Object Notation; OL, operational learning (an item id prefix); PR, pull request; RFC, Request for Comments; RFI, request for information (a session RFI, in the glossary's sense); SHA, Secure Hash Algorithm (the identifier of a commit); SITREP, situation report; SPOTREP, spot report; URL, uniform resource locator; UTC, Coordinated Universal Time; WAL, write-ahead logging; WP, a work package of the plan (section 8). The doctrine references TC, ADP, FM and AR are the US Army's Training Circular, Army Doctrine Publication, Field Manual and Army Regulation.
- **Identifier families:** `D874d-<n>` is a decision of the commander recorded in issue #180 (appendix A); `D-DEL<n>` is a decision of the delegation rule (`shared/rules/delegation.md`); `S-<n>` is a point settled by this RFC (section 4); `R<sid4>-<n>` is a session RFI (3.2.4); `L<n>` is line `<n>` of the transcript of session dbd05b0c. In running text, an id that cites its record is plain text; a pattern or a field value is in code format.
- **Empty:** a string described as empty holds `""`; `null` MAY appear only in `provenance.written_by.mission` (3.3.3). A list node with no entries is `[]`; 3.3.2, 3.4.2 and 3.5.2 require every top-level key to be present.

---

## 3. Specification

### 3.1 One schema, three documents

3.1.1. The mission brief, the AAR and the running estimate MUST share one schema. The schema files (3.7.1) MUST define each item type and each plain entry once, and every document that uses an item type or a plain entry MUST give it the fields and meaning that 3.2 defines. The nodes `provenance` and `intent` are the exception: each document gives them the fields that 3.3.3, 3.4.3 and 3.5.2 define for it.

3.1.2. Each document uses the nodes marked below. A document MUST NOT contain a node it is not marked for.

| Node | Mission brief | AAR | Running estimate |
|---|---|---|---|
| `provenance` | yes | yes | yes |
| `identity` | yes | | |
| `intent` | yes | | yes (the session's) |
| `objectives` | verbatim, with source | + status, how, deviation_refs, observation_refs, deliverables | the session's, + status, how, deviation_refs, observation_refs, deliverables |
| `constraints` | yes | | |
| `assumptions` | given | + end state | yes |
| `decisions` | to honor | | yes |
| `ambiguities` | | found, how resolved | yes |
| `deviations` | | yes | yes |
| `observations` | | yes | yes |
| `operational_learning` | carried forward | new | yes |
| `proposals` | | yes | yes |
| `rfis` | | yes | yes |
| `missions` | | | derived (3.5.4) |
| `assessment` | | | yes |
| `artifacts` | yes (D874d-65) | | |
| `deliverables` | yes: what the delegate is to produce (D874d-70) | inside each objective only, not a top-level node (3.2.6) | inside each objective only, not a top-level node (3.2.6) |

3.1.3. The table in 3.1.2 does not mark the following nodes, so 3.1.2 prohibits them; this clause records the decisions that removed them. No document has a `facts` (D874d-32), `report_at_once_if` (D874d-26), `meta` (D874d-19) or `findings` (D874d-22) node. A mission brief also has no `conflict_priority` and no `permissions` node, because `/delegate` documents the standing duties (D874d-64); no `rules` and no `skills` node, which `artifacts` replaces (D874d-65); and no `ambiguities`, `access`, `name_prefix`, `duties` or `return` node (D874d-70). The content of the removed brief nodes is carried elsewhere: an ambiguity the delegating agent resolved before launch is a decision or a constraint; the scratch directory, the paths the delegate is permitted to write, the sources that are not files and the name prefix (D-DEL1) are in the delegation prompt (3.3.5); an action the delegate is required or forbidden to take is a constraint; and what the delegate returns is a deliverable.

3.1.4. `provenance` is every document's header (D874d-29). It records what the document is, who wrote it, when, and for which session and mission.

3.1.5. Writers SHOULD emit the top-level keys in the order of 3.3.2, 3.4.2 and 3.5.2; a writer whose JSON library cannot preserve that order MAY emit another. Readers MUST accept the keys in any order. *Settled by this RFC (S-16).*

### 3.2 Items and plain entries

3.2.1. These nodes are **item nodes**: `objectives`, `assumptions`, `decisions`, `ambiguities`, `deviations`, `observations`, `operational_learning`, `proposals` and `rfis`. Every entry of an item node is an item. Every item MUST carry `id`, `type`, `text` and `source` (`source.kind`, `source.location`); it MUST carry `quote` when `source.kind` is `commander`; it MAY carry `severity` only when its type is `deviation` or `observation`; it MUST carry `version`, `agent_id`, `agent_type`, `mission` and `created_at`, except as the second bullet below permits. The common fields are:

```
id             item id (3.2.4)
type           objective | deviation | observation | ambiguity | assumption | fact |
               decision | operational_learning | proposal | rfi
text           the statement (for a proposal, a one-line summary of `what`; for an rfi,
               its `title`)
version        1 for a new item; + 1 for each later version (3.2.5)
agent_id       who wrote the item (D874d-25): the session id for the session agent,
               the delegate's agentId, "commander", or a hook name
agent_type     session | delegate | commander | hook
mission        the delegate's mission name; empty for the other agent types
source.kind    commander | agent | telemetry | artifact | web
source.location  path:line | commit SHA | URL | transcript path + line
quote          the source text verbatim; REQUIRED when source.kind is commander
               (issue #180 section 3); a credential in it becomes [redacted] (S-24)
created_at     UTC, in the form `YYYY-MM-DDTHH:MM:SSZ`, with an optional fraction of 1 to 6 digits (3.7.2)
severity       critical | high | medium | low   (OPTIONAL on deviation and observation items; MUST NOT appear on other types)
```

- Who *wrote* an item is `agent_id`. Who *said* it is `source.kind` with `quote`.
- In a brief or an AAR, an item MAY omit `version`, `agent_id`, `agent_type`, `mission` and `created_at`. An omitted `version` is the integer 1 (`provenance.version` is the document's version string, not an item's). In a brief, the other omitted fields take the values of `provenance.written_by.agent_id`, `provenance.written_by.agent_type`, `provenance.written_by.mission` (`""` when that is `null`) and `provenance.created_at`; in an AAR, the values of `provenance.agent_id`, the agent type `delegate`, `provenance.mission` and `provenance.created_at`. In the session DB, every row MUST carry them (D874d-55, which accepted S-18).
- A writer MUST NOT copy a credential or an access token into a `quote`. When a quoted passage contains one, the writer MUST replace the secret with `[redacted]`; this is the only change a writer MAY make to a verbatim quote. *Settled by this RFC (S-24).*

3.2.1a. The other list nodes hold **plain entries**, not items:

| Node | Entry |
|---|---|
| `constraints` | `{text, source}`: an action the delegate is required or forbidden to take, including every skill conflict the delegating agent pre-resolved (allowed or overridden) |
| `artifacts` | `{path, instruction}` (3.3.3a; D874d-65) |
| `deliverables` (brief) | `{kind, ref, objective, text}` (3.2.6; D874d-70) |
| `objective.deliverables` (AAR, running estimate) | `{kind, ref, text}`: the same entry, its objective implicit (3.2.6) |
| `identity.parallel_missions` | `{mission, scope}` |
| `provenance.chain_of_command` | a transcript path |
| `missions` (running estimate) | `{mission, brief, agent_id, objectives[] {id, status}}`, derived on export (3.5.4) |

3.2.2. The type-specific fields are listed below. Every listed field is REQUIRED, except a field whose line states when it is present (for example `ref`, "once verified or falsified", and `answer`, "once answered"); a list field (`[]`) MAY be empty. The fields listed under "in an AAR or a running estimate" MUST NOT appear in a brief.

```
objective  OBJ-n
  text               verbatim from the delegation prompt (D-DEL8, D874d-13)
  source             who gave it, and where (`source.kind` and `source.location`, 3.2.1)
  in an AAR or a running estimate, also:
  status             accomplished | partly | not accomplished          (D874d-23)
  how                a short summary of how it was done, or why not; present unless the objective cites at least one deviation or observation (3.4.4, D874d-23)
  deviation_refs[]   DEV ids
  observation_refs[] OBS ids
  deliverables[]     what it produced, as deliverable entries (3.2.6; D874d-34)

deviation  DEV-n                 acted on: done differently from what was given (D874d-22)
  from.kind          brief | order | plan | rule | spec | standard     (3.2.3)
  from.ref           where: OBJ-2, a brief constraint, plans/x.md step 3, a rule file and section
  from.text          what it said, verbatim
  text               what was done instead
  cause              initiative | blocker | error                      (3.2.3)
  why                the reason
  effect             on which objectives, and how
  objective_refs[], observation_refs[]

observation  OBS-n               seen, not acted on (D874d-20)
  text               what was seen, without interpretation
  evidence           quoted text, file:line, command output
  incident           true when it is reported as an INCIDENT: marker, otherwise false

ambiguity  AMB-n                 (D874d-14, D874d-17)
  text               the passage, verbatim
  source             the common `source` (3.2.1); its `location` names where: a brief section, an order, a rule
  readings[]         the meanings it could have
  resolution         the reading acted on
  resolved_by        reason | read | test | delegate | rfi | assumption   (and, for delegate, rfi and assumption, a `ref`: the id of the mission or item that settled it)
  evidence
  status             resolved | open      (for an open ambiguity, the writer MUST also write an rfi item)

assumption  ASM-n                (D874d-15)
  text
  status             unverified | verified | falsified
  confidence         low | moderate | high
  evidence           what verified or falsified it
  impact_if_false
  ref                (once verified or falsified) the id of the item that settled it: for a
                     falsified assumption, the contradicting observation ('invalidated'); for
                     a verified assumption, a fact in the session DB ('validated'). No document has a facts node (3.1.3), so in a document a `ref` that would
                     point to a fact MAY be empty, and `evidence` carries the support. The terms
                     'invalidated' and 'validated' follow the glossary's lifecycle (D874d-43).

fact  FACT-n                     a session-DB type kept by D874d-43; no document node lists
                                 facts (D874d-32); an assumption's `ref` MAY point to one
  text, evidence

decision  D<sid4>-<n>, or the id the decision has in its own record (for example D-DEL6)
  text, decided_by, date, quote (empty when `decided_by` is not the commander),
  status             decided | implemented | verified | deferred | reversed | superseded
  superseded_by[]    {decision, part}: the decision that supersedes it, and the part
                     ("whole", or the part named) (D874d-56, which accepted S-19).
                     A writer MUST set status to superseded only when the whole decision
                     is superseded; for a decision superseded in part, it MUST keep the
                     status and MUST name the part in superseded_by[].part

operational_learning  OL-n       (its own node, D874d-29)
  text               what worked, what failed, what to do differently
  deviation_refs[], observation_refs[]

proposal  PRO-n                  (barrier analysis: D874d-1; no owner, no timeline: D874d-24)
  what, why          `why` also cites the other sources that the proposal rests on
  barrier_analysis   would it have prevented the deviation or the issue?
  affected[]         files, rules, decisions it would change
  deviation_refs[], observation_refs[]
  disposition        proposed | accepted | rejected | deferred      (a writer MUST set proposed;
                     only the commander's decision changes it)

rfi  R<sid4>-<n>                 (D874d-41; a delegate's provisional id: 3.2.4)
  title, question (with its context), suggestion, answer (verbatim, once answered),
  status             open | answered | withdrawn
```

3.2.3. `deviation.from.kind` and `deviation.cause` take these values (D874d-29):

| `from.kind` | What the agent deviated from |
|---|---|
| `brief` | The mission brief: an objective, the scope or an exclusion, a constraint |
| `order` | An order given during the mission, outside the brief: the commander's prompt, or a message from the delegating agent |
| `plan` | The steps or the sequence of a plan the work follows; a deviation of this kind is a process deviation (D874d-21) |
| `rule` | A rule, a standing order, a CLAUDE.md file, or a skill's mandated process |
| `spec` | A specification that the work product is required to meet: a reference document, a schema, an interface contract, a test expectation |
| `standard` | An outside authority: official tool documentation, a language or style standard, doctrine |

| `cause` | Meaning |
|---|---|
| `initiative` | The agent chose to deviate, within the commander's intent (disciplined initiative) |
| `blocker` | The given course could not be followed; a denied write is a blocker. The agent that meets a blocker MUST report it, with a recommended course of action, as soon as it meets it, not only in its AAR (D-DEL9): a delegate sends it to its delegating agent (in Claude Code, with `SendMessage`), and the session agent MUST report it to the commander in its reply |
| `error` | Done differently by mistake, and found later |

3.2.4. Item ids are `<TYPE>-<n>`, where `<TYPE>` stands for the item type: `OBJ` (objective), `DEV` (deviation), `OBS` (observation), `AMB` (ambiguity), `ASM` (assumption), `FACT` (fact), `OL` (operational learning) or `PRO` (proposal). Session RFIs are `R<sid4>-<n>` and decisions `D<sid4>-<n>` (D874d-41). *Settled by this RFC (S-7, S-23):*
- In the session DB (schema 5), `harness-db.py` MUST assign the id on insert, inside the insert's `BEGIN IMMEDIATE` transaction (3.6.6), so parallel writers never collide: `<TYPE>-<n>`, `R<sid4>-<n>` for an item of type `rfi` and `D<sid4>-<n>` for an item of type `decision`, where `<n>` is one more than the highest `<n>` already in the DB with that prefix (1 for the first). A writer that records a decision already numbered elsewhere (its record id: a `D874d-<n>` of the issue, a `D-DEL<n>`) passes that id with `--id`; the insert exits 1 when the id is taken.
- In a document, the writer MUST number the items of each type consecutively from 1 (`OBS-1`, `OBS-2`, ...), except that it MAY keep the ids of the record it copies items from, such as the issue's `ASM-<n>`, for traceability.
- When a document's items are written into the DB (3.4.8), `harness-db.py` MUST assign each a new id, MUST keep the document's id in `fields.doc_id`, and MUST rewrite each ref that points to an item of the same document to that item's new id; it MUST keep unchanged a ref to an id outside the document (a brief's objective, a session RFI, a decision).
- A delegate that writes the session DB MUST use the `R<sid4>-<n>` ids the DB assigns to its RFIs. In a document whose items are not in the DB (before schema 5 ships, or under 3.4.8's worktree confinement), the delegate MUST number its RFIs `R<mission name>-<n>`, and `harness-db.py` MUST assign `R<sid4>-<n>` when the items are written (the third bullet). Before schema 5 ships, the session agent MUST renumber each such RFI to `R<sid4>-<n>` when it raises it to the commander.

3.2.5. In the session DB, a writer MUST NOT change an item row in place, because provenance is never deleted ("provenance is eternal", the commander, session ddfe01cb, 2026-03-30). A writer that changes an item MUST insert a new row with the same `id` and a `version` one greater than the item's latest version. A brief or an AAR is changed by writing a new version of the whole document (D-DEL5). In the DB:
- The key of an item row is (`id`, `version`).
- A ref points to an `id` and means its latest version. In the DB, refs (the `*_refs[]` and `ref` fields of 3.2.2) are stored only in the `refs` table, never in `fields`; each `refs` row carries the `from_version` of the item version that holds it, and an item's refs are those of its latest version.
- Every reader, including the export, `harness-db.py aar`, the compatibility views (3.6.7) and the derived `missions[]`, MUST read only the latest version of each id.

*Settled by this RFC (S-4).*

3.2.6. A **deliverable** entry has one shape wherever it appears: in the brief's `deliverables[]`, what the delegate is to produce; in an objective's `deliverables[]` (AAR and running estimate), what it produced (D874d-34, D874d-70):

```
kind               aar | pr | issue | commit | file
ref                the pointer a reader can open and check: a file's absolute path,
                   a PR or issue URL, a commit SHA. In a brief, where the deliverable
                   is expected: a file's absolute path, `<owner>/<repository>, base <branch>`
                   for a PR, `<owner>/<repository>` for an issue or commit; for the AAR, the AAR file's
                   path when one is requested, else empty (the hand-back only)
objective          the OBJ id it serves, REQUIRED in a brief; "" for the AAR, which
                   serves every objective (in an objective it is implicit)
text               what it is
```

Every brief MUST list exactly one deliverable of `kind` `aar` (D874d-47, D874d-50). That deliverable is the hand-back, JSON in the AAR schema in one fenced block (3.4.1), and also a file when its `ref` names one (3.4.7). *Settled by this RFC (S-26).*

### 3.3 Mission brief

3.3.1. The delegating agent MUST write a mission brief for every delegate before it launches the delegate (D-DEL10). The mission brief records the delegate's mission objectives (D874d-12: "The planning brief should define the mission objectives for the delegate."). The brief's location depends on its lifecycle:
- **Default.** Unless the commander orders otherwise, the delegating agent MUST write the brief to `<session scratch dir>/<mission name>-brief.json` (D874d-36, D874d-42, D874d-73), except as 3.3.8 provides for a delegating agent confined to its worktree. Most briefs serve one mission within one session and are ephemeral.
- **Long lifecycle.** The briefs directory, `<repo>/briefs/`, tracked in git as plans are, holds the briefs of missions that outlive the session that wrote them, such as a mission that implements a roadmap item (D874d-72, D874d-74). An agent MUST NOT write a new brief to `<repo>/briefs/<mission name>-brief.json` without the commander's order, and on the commander's order it MUST write the brief there (D874d-73); a new version of a brief already there (3.3.1a) needs no new order. A delegating agent that expects a mission to outlive its session SHOULD ask the commander to order that placement, in a session RFI (a delegate: in an RFI of its AAR, 3.2.4); it MAY omit the request when the commander has already ruled on that brief's placement.

The file name is the same in both locations.

3.3.1a. A brief in the briefs directory is subject to these additional rules:
- The agent that changes it MUST write each change as a new version (D-DEL5) and commit it. Whether such a commit goes to `main` directly, as plans do, or through a PR is deferred by the commander (D874d-76); until the commander decides, the commit reaches `main` the way the commander orders for that change, or else through a PR (aitools `CLAUDE.md`, "Channel exception"). A version MUST reach `main` before any delegate is launched from it; if it cannot, the agent MUST NOT launch a delegate from it and MUST report the failure to the commander.
- An agent that launches a delegate from it in a later session MUST first write a new version whose `provenance` (`session_id`, `session_db`, `session_scratch`, `written_by`, `chain_of_command`, `created_at`) describes the launching session, so that the delegate reports into that session.
- It carries the commander's words verbatim, and committing it to a public repository publishes them. The commander's order to place a brief there constitutes acceptance of that disclosure (section 7).

3.3.2. The brief MUST be one JSON object whose top-level keys are exactly these, each present even when its list is empty (`[]`): `provenance`, `identity`, `intent`, `objectives`, `constraints`, `assumptions`, `decisions`, `operational_learning`, `artifacts`, `deliverables`.

3.3.3. The nodes hold:

```
provenance
  document           "mission-brief"
  schema_version     1
  version            "v1.0", "v1.1" ... (D-DEL5)
  mission            <mission name>, the delegate's name
  session_id         the top-level session's id
  session_db         the session DB's path; empty until schema 5 ships (3.6.11)
  session_scratch    the top-level session's scratch directory (where a default brief
                     resides, 3.3.1)
  written_by         {agent_id, agent_type, mission (the writer's mission name when the writer is a delegate, otherwise null)}
  chain_of_command[] the transcript path of every agent above the delegate, the top-level
                     session's first and the delegating agent's last
  created_at
identity             name, level (1 for a delegate of the session agent, + 1 for each level
                     below), delegated_by, parallel_missions[] {mission, scope}
intent               purpose, scope, out_of_scope[], audience
objectives[]         objective items: text verbatim + source            (D-DEL8, D874d-13)
constraints[]        {text, source}: an action the delegate is required or forbidden to
                     take (for example shipping a code change, D-DEL4), and every skill conflict
                     pre-resolved (allowed or overridden); standing duties are documented
                     in /delegate, never in the brief (D874d-64)
assumptions[]        assumption items: what the delegating agent assumes; the delegate
                     MUST report each one's end state (verified, falsified or unverified)
                     in its AAR (3.4.2)
decisions[]          decision items: the decisions that bind the delegate, quoted
operational_learning[]  operational learning items, carried forward, each with its source
artifacts[]          {path, instruction}: every file the delegate needs (3.3.3a, D874d-65)
  path               the file's absolute path
  instruction        "read in full" | "use as reference for answers"
deliverables[]       {kind, ref, objective, text}: what the delegate is to produce, the
                     AAR always among them (3.2.6, D874d-70)
```

3.3.3a. The delegating agent MUST list in `artifacts[]` every file the delegate needs, one entry per file, by absolute path, and MUST give each entry the instruction that its category below names (D874d-65):
- **`read in full`:** every user- and project-scope `CLAUDE.md` file and rule, and any nested `CLAUDE.md` in the directories the delegate works in (user rule `delegation.md`); the `SKILL.md` of every skill the mission uses, `/delegate` first; the mission's specifications; every file the delegate changes or verifies. The delegation prompt adds "line by line" to this instruction (3.3.5; D874d-27).
- **`use as reference for answers`:** the chain-of-command transcripts (D874d-27, "what to use as reference material (sessions)"), large reports and extracted documents, and files a mission that orchestrates other delegates needs only to brief them. The delegate MUST NOT read such a file whole; it searches the file when it needs an answer the file can give.
- **Never listed** (the delegating agent MUST NOT list them): a governed registry's JSON file, even one the delegate changes through its skill (its skill's SKILL.md is listed instead; `.claude/rules/governed-data-access.md`), and anything that is not a file, such as an issue, a PR or a web page, which the delegation prompt names with the command to read it (3.3.5).
- **Not in `artifacts[]`:** what a skill is for goes in the prompt body (D874d-32); a skill conflict the delegating agent pre-resolved goes in `constraints[]` (`/delegate` writing step 6). Whether a file binds the delegate follows from what it is (D-DEL6 tiers), not from its instruction.

3.3.4. The delegating agent MUST put in the brief only content that fits a node and an entry defined in 3.3.3, and MUST put any other content, such as facts or background, in the body of the delegation prompt, outside the brief (D874d-32, D-DEL12).

3.3.5. In the delegation prompt, the delegating agent MUST:
- give the brief's path with the instruction "Before any other work, read your mission brief in full, line by line: `<path>`" (D874d-27);
- carry the mission objectives verbatim, each with its source (D-DEL8, D874d-13);
- tell the delegate explicitly to read in full, line by line, every artifact whose instruction is `read in full`, and to search every artifact whose instruction is `use as reference for answers` when a question comes up, never loading it whole (D874d-27, D874d-65);
- tell the delegate to load `/delegate` at start, where its standing duties are documented (D-DEL13, D874d-64);
- give, as `/delegate` prompt elements, what the brief no longer holds (D874d-70): the delegate's scratch directory by absolute path (user rule `scratch.md`), the paths it is permitted to write, the sources that are not files with the command to read each, and the name prefix `<mission name>-` for every `*.md` file it writes (D-DEL1).

3.3.6. Every delegate launched through a workflow (each `agent()` call) MUST be given its own brief, written by the delegating agent before the workflow runs, and its prompt MUST give the brief's path. *Settled by this RFC (S-3).*

3.3.7. When the delegating agent knows of a blocker at launch, it MUST state the blocker as a constraint or in the prompt body, and MUST name there each objective the blocker affects, by its `OBJ` id; it MUST NOT add to an objective's verbatim text (3.2.2). The brief has no list of conditions to report at once: reporting a blocker at once is a standing duty (D-DEL9, D874d-26).

3.3.8. A delegating agent SHOULD give a delegate that writes briefs or DB rows a worktree made with `git worktree add`, which does not confine writes, rather than the Agent tool's worktree isolation; it MAY use worktree isolation when the mission requires it, and then the rest of this clause and 3.4.8 apply. A delegating agent that cannot write into the top-level session's scratch directory, because worktree isolation confines its writes (ASM-4), MUST write the brief into its own scratch directory, under the same name. The prompt gives that path, and the delegate's AAR names it in `provenance.brief`, so `missions[]` still finds it (3.5.4). *Settled by this RFC (S-9).*

### 3.4 After action review (AAR)

3.4.1. Every delegate MUST end its mission with its AAR as its hand-back message (D874d-47). The AAR MUST be JSON in the AAR schema, in one fenced block, and that block MUST be the last block of the hand-back whose opening line is exactly three backticks followed by `json` and nothing else; the block ends at the next line that is exactly three backticks (D874d-50). Prose MAY precede or follow it. A string inside the AAR MUST NOT contain three backticks in a row.

3.4.2. The AAR MUST be one JSON object whose top-level keys are exactly these, each present even when its list is empty (`[]`): `provenance`, `objectives`, `ambiguities`, `assumptions`, `deviations`, `observations`, `operational_learning`, `proposals`, `rfis`. `objectives`, `ambiguities` and `assumptions` answer "what was supposed to happen" (TC 7-0.1 (2025), 3-2 and 3-7).

3.4.3. `provenance` MUST hold: `document` ("aar"), `schema_version`, `version`, `mission`, `agent_id` (the delegate's own agentId, 3.4.9), `session_id`, `brief` (the brief's path), `created_at`.

3.4.4. `objectives` MUST restate every objective of the brief, verbatim (D874d-13), each with its `status` (`accomplished`, `partly` or `not accomplished`; D874d-23).
- Each objective MUST give `how`, or cite at least one deviation or observation, or both (D874d-23).
- An objective whose `status` is `partly` or `not accomplished` MUST cite in `deviation_refs` at least one deviation that explains the shortfall.
- `deliverables` MUST list what the delegate produced for it, as deliverable entries (3.2.6; D874d-34).
- The delegate MUST record as a deviation with `from.kind` `brief` each artifact whose instruction is `read in full` that it did not read in full.

3.4.5. The delegate MUST record what the old hand-back carried as free-text lines in these nodes (D874d-29, D-DEL11):
- a `WRITE_BLOCKED` denial becomes a deviation with cause `blocker` and `from.kind` `rule`, reported as 3.2.3 requires (D-DEL9);
- a `CONFLICT:` line becomes an ambiguity whose readings are the conflicting instructions, resolved by the D-DEL6 tier that won;
- an `INCIDENT:` marker becomes an observation with `incident: true`;
- a PR URL or a file becomes a deliverable entry of the objective it serves (3.2.6).

A delegate MUST record in its AAR what it learns after its merge as observations or operational learning (D874d-5).

3.4.6. When a blocker stops an objective, the delegate MUST record it in its AAR as follows, the last two only when their conditions hold:
- the objective's status is `partly` or `not accomplished`;
- a deviation with cause `blocker` explains it;
- an assumption has `status` `falsified`, if a wrong assumption caused it;
- a proposal or an RFI, if only the commander can clear it.

The delegate MUST also report the blocker when it meets it, with a recommended course of action, not only in its AAR (D-DEL9; 3.2.3).

3.4.7. A delegate MUST write an AAR file if, and only if, the `ref` of the brief's `aar` deliverable names a file (3.2.6), and MUST write it at that path, holding the same JSON as the hand-back. A delegating agent that requests a file MUST name `<session scratch dir>/<mission name>-aar.json` in that `ref`, or, when it wrote the brief to its own scratch directory (3.3.8), `<mission name>-aar.json` in that directory (D874d-47).

3.4.8. Once schema 5 ships:
- the delegate MUST write every item of its AAR as a row in the session DB when it records the item, not at hand-back, except as the third bullet of this clause provides;
- the delegate SHOULD produce its hand-back from its rows (`harness-db.py aar`, 3.6.10); it MAY write the hand-back without the verb when the verb fails, and MUST then record the failure as a deviation;
- a delegate that cannot write the session DB because worktree isolation confines its writes (ASM-3) hands back its AAR only. Its delegating agent, which receives the AAR, MUST then write each AAR item the DB does not already hold, with `agent_id` from the AAR's `provenance.agent_id` and the ids rewritten (3.2.4). An AAR item is already held when a row has the same `agent_id` and either the same `id` (an AAR rendered from the DB by `aar`) or a `fields.doc_id` equal to the item's id (an item written earlier from a document). *Settled by this RFC (S-9, S-23).*

3.4.9. A delegate MUST try these methods, in this order, to find its own agentId (D874d-33):
- the file `subagents/agent-<agentId>.meta.json` in the `subagents/` directory of the top-level session (`~/.claude/projects/<project-dir>/<session id>/subagents/`, `/delegate` "Claude Code specifics"), found by searching that directory for the file whose `description` starts with its mission name. This file exists while the delegate runs (observed for background delegates, 2026-11-16);
- a `TaskStop` error that names the caller's id;
- its parent session's transcript (`/delegate` "Claude Code specifics").

The delegating agent MUST record the agentId the launch returns. A delegate that finds its agentId by none of them MUST set `provenance.agent_id` to `""` and MUST NOT write the session DB; its delegating agent MUST then write its items (3.4.8) with the agentId the launch returned (ASM-1). These methods are verified for the Claude Code harness only; an implementer MUST NOT rely on them in another harness or environment (Claude Code web, Cursor CLI, Cursor cloud agents) until it has tested them there and recorded the result (D874d-33).

### 3.5 Running estimate

3.5.1. There is one running estimate per session (D874d-8). It lives in the session DB (D874d-35); the session agent and every delegate write it directly, except as 3.4.8 (a delegate confined to its worktree) and 3.6.11 (before schema 5 ships) provide. It is not shared across sessions (D874d-9).

3.5.2. Its export MUST be one JSON object whose top-level keys are exactly these, each present even when its list is empty (`[]`): `provenance`, `intent`, `assessment`, `objectives`, `missions`, `assumptions`, `decisions`, `ambiguities`, `deviations`, `observations`, `operational_learning`, `proposals`, `rfis`.

```
provenance           document "running-estimate", schema_version, version, session_id,
                     session_db, maintainer (the session agent's id, which is the session id), created_at, updated_at
intent               {text, main_effort}: the commander's intent for the session and its
                     main effort
assessment           the session agent's judgment of whether the session is proceeding
                     according to the commander's intent, and why
                     (FM 1-02.1 "running estimate"; FM 5-0 table C-1 item 6)
objectives[]         the session's objectives (the items of type objective whose `mission`
                     is empty; a delegate's objectives appear only in `missions[]`): the
                     commander's orders verbatim, with the transcript line, + status, how,
                     deviation_refs, observation_refs, deliverables
missions[]           derived on export (3.5.4)
assumptions[], decisions[], ambiguities[], deviations[], observations[],
operational_learning[], proposals[], rfis[]: every agent's items of these types,
                     latest versions (3.2.5)
```

3.5.3. Once schema 5 ships, the session agent MUST review `intent`, `main_effort`, `assessment` and the session's `objectives` at each prompt turn and after each hand-back, and MUST write each one whose value has changed. *Settled by this RFC (S-2):*
- `intent`, `main_effort` and `assessment` are columns of the `session` table (`main_effort` is stored in the v4 column `schwerpunkt`, the German word for the main effort, which keeps its name because RFC 0010 never removes columns; `intent` and `assessment` are added), set with `harness-db.py estimate set`, which writes nothing when the value is unchanged; each change adds a `version_history` row whose `version` is the highest plus 1 and whose `changes` names the column and its new value.
- Plan batch 2.3 adds this duty to item 12 of the prompt-turn checklist.
- Before schema 5 ships, the session agent writes none of them to the DB (3.6.11).

3.5.4. `missions[]` MUST be derived on export (`harness-db.py export`); writers MUST NOT write it. It has exactly one entry per mission name found in any of: each `*-brief.json` in the session scratch directory; each brief in the briefs directory whose `provenance.session_id` is the session's id (3.3.1a); each `*-brief.json` in any other `.scratch/session-*/` directory under `<repo>`, at any depth, whose `provenance.session_id` is the session's id (3.3.8); and each mission name on the session's rows. Each entry is `{mission, brief, agent_id, objectives[] {id, status}}`: `brief` is the path found (`""` when rows exist but no brief is found); `agent_id` and the statuses are read from the rows whose `mission` is that name (latest versions, 3.2.5), `agent_id` `""` when there are none.

3.5.5. At session end, one detached job, started by `harness-db-sessionend.sh`, MUST run these steps in this order; when the session DB is missing or below schema 5, it MUST run none of them and record that as a failed step (below):
1. export the estimate to `<repo>/.aitools/channel/estimates/<session id prefix>.json`, untracked (D874d-44, D874d-52): the aitools `.gitignore` MUST list `.aitools/channel/estimates/`, and in other repos the exclude entry for `.aitools/` covers it (section 7);
2. copy it to `<dotprofile>/running-estimates/<project>/<YYYY-MM-DD>_<session id prefix>.json`, where the date is the session's start date in UTC, from the session DB (D874d-52, D874d-53). `<dotprofile>` is the dotprofile repo as `ait-harvest.py archive` resolves it; when none is configured or it is not a git repository, the job MUST skip steps 2 and 3 and record them as failed steps (below);
3. commit and push the dotprofile's `main` (D874d-51).

The job MUST also:
- run detached, because Claude Code gives SessionEnd hooks a 1.5-second default timeout (`reference/tool-ops-claude-code.md` item #35);
- take the single-flight lock that `ait-harvest.py archive` takes (`~/.aitools/locks/harvest.lock`) before step 2 and hold it until step 3 ends; while a live holder has it, wait (the job is detached) up to 10 minutes, then skip steps 2 and 3, record them as failed steps and leave them to the catch-up;
- before step 2, check that the dotprofile is on `main`, and if it is not, skip steps 2 and 3 and record them as failed steps; in step 3, commit only the record file, then `git pull --rebase`, then push.

The next session's catch-up (`session-catchup.sh`) MUST, for every session DB in `<repo>/.aitools/sessions/` other than the starting session's, recover what is missing: the export when it is absent or older than the DB; the record when it differs from the export; the commit and the push when the record is uncommitted or the dotprofile's `main` is ahead of its upstream. The job and the catch-up MUST record each failed step, with the session id and the error, in `~/.aitools/logs/harness-db-sessionend.log`, and the next SessionStart output MUST print one line for each failed step the catch-up could not recover, in addition to the log entry. Because the date is the start date, a resumed session (`/resume`) rewrites the same record file. *Settled by this RFC (S-21, S-22).*

3.5.6. When the SessionEnd hook switches to the per-session export (plan WP-3), it MUST stop writing the single `.aitools/channel/running-estimate.json`. That file and `.aitools/templates/mission-running-estimate.json` are retired (S-13). The implementer MUST repoint to the per-session export, or update, every reader and description of the old file: `scripts/generate-dashboard.py`, `scripts/aitools-dashboard.sh/.ps1`, `shared/hooks/dashboard-serve.sh`, the `/mission-control` and `/aitool-continue` skills, `.claude/rules/aitools-workspace.md` and `reference/artifact-harvesting.md` (D874d-61). The implementer MUST remove the tracked file and its template in plan WP-5, and MUST take no earlier action on the copy already published (D874d-54).

### 3.6 Store (session DB, schema 5)

3.6.1. The session DB is `<repo>/.aitools/sessions/<session id prefix>.db` (D874d-44, D874d-48), one per top-level session. The session agent and all its delegates, at every level, write to this one file.

3.6.2. At session start, `harness-db.py` MUST compare the full session id stored in an existing DB with the starting session's id. On a mismatch, two sessions share the 10-character prefix: it MUST log an error, MUST NOT write the other session's DB, and MUST use `<repo>/.aitools/sessions/<full session id>.db` instead, printing that path in its "Session DB:" line (ASM-6). Every later writer or reader that derives the path from a session id (a hook, the SessionEnd job, the catch-up) MUST apply the same rule: `<session id prefix>.db` when it holds that session id, else `<full session id>.db`. An existing DB with no `session` row is treated as the starting session's. *Settled by this RFC (S-11).*

3.6.3. All session-DB items MUST be stored in one `items` table, regardless of the type and of the agent; there is no table per agent (D874d-25, D874d-31):

```
items   id, version, type, text, status, severity, fields, agent_id, agent_type, mission,
        source_kind, source (the item's source.location), quote, created_at
        key (id, version)
refs    from_id, from_version, to_id, kind (objective | deviation | observation |
        validated | invalidated)
```

`items` has no session-id column (D874d-31), because the file is the session. An objective's `deliverables` are kept in its `fields.deliverables` (3.2.6). The `session` table keeps the session's full id, `project_dir`, start time, `intent`, `main_effort` and `assessment`. The export adds the session id.

3.6.4. The type-specific fields (3.2.2) MUST be stored in `fields` as JSON text, parsed and validated in Python. Queries MUST NOT depend on SQLite's JSON functions: availability varies by SQLite build, and parsing in Python keeps the store independent of the build. *Settled by this RFC (S-5).*

3.6.5. Session-DB writers MUST pass the DB's path (`--db`) and their own id. There is no `--session` argument on the session-DB verbs (D874d-31, 3.6.9):

| Writer | Passes to `harness-db.py` | `agent_id` | `agent_type` (derived) | `mission` |
|---|---|---|---|---|
| Session agent | `--db <path> --agent-id <its session id>` | its session id | `session`: the id equals the DB's session id | empty |
| Delegate, any level | `--db <path from its brief> --agent-id <its own agentId> --mission <its name>` | its agentId | `delegate`: `--mission` is given | its name |
| Hook | `--db <path> --agent-id <hook file name>` | the hook name | `hook`: the id ends in `.sh` or `.py` | empty |
| The commander, writing directly through the command channel (RFC 0002 v2) with `item add` (an agent that records the commander's words writes with its own id and `source.kind` `commander`, 3.2.1) | `--db <path> --agent-id commander` | `commander` | `commander` | empty |

`--db` and `--agent-id` are REQUIRED on every session-DB write verb. `harness-db.py` derives `agent_type` in this order: `commander` when the id is `commander`; `hook` when it ends in `.sh` or `.py`; `delegate` when `--mission` is given (a mission name, section 2); `session` when the id equals the `session_id` stored in the DB; otherwise it MUST exit 1 with an error and write nothing. There is no `--agent-type` flag. The session agent knows its session id and the DB's path from the SessionStart output ("Session started: ...", "Session DB: ..."; ASM-5).

3.6.6. Connections MUST use the RFC 0010 section 4 settings (WAL, `synchronous=NORMAL`, `busy_timeout=5000`, foreign keys) and `BEGIN IMMEDIATE` for writes. `ensure_schema`, which takes the write lock to run its DDL, MUST run at session start only, not on every write. A write verb that finds the DB missing or below schema 5 MUST NOT create or migrate it: the CLI MUST exit 1 with an error naming the DB's version, and a hook MUST log it and exit 0; such a session writes no items until its next start (3.6.11 applies to it). *Settled by this RFC (S-10):*
- **Agents:** when a write still fails with "database is locked" after the busy timeout, `harness-db.py` MUST retry it up to three times (four attempts in all), waiting 1, 2 and 4 seconds before the retries, and then MUST exit 1 with the error. The agent MUST then record the failed write as a deviation with cause `blocker`, in its AAR (a delegate) or its reply (the session agent), and MUST write that deviation to the DB once a later write succeeds.
- **Hooks:** a hook MUST NOT retry a failed write; it MUST log the failure and exit 0 (RFC 0010 section 8).

3.6.7. The migration from schema 4 MUST be forward-only (no step returns a DB to schema 4) and MUST run inside `ensure_schema` (RFC 0010 section 5). The implementer MUST test it on copies of the live session DBs before it ships, as PR #181 was tested. *Settled by this RFC (S-12, S-17).* It maps:

| v4 | v5 |
|---|---|
| `observations` rows | `items` rows, `version` 1; `observation_id` becomes the id `<TYPE>-<n>`, numbered per type in `observation_id` order (the old number in `fields.legacy_id`); `category` becomes `type`; `text`, `status`, `severity`, `source_kind`, `source`, `quote` and `created_at` keep their columns; `status` `pending` becomes `unverified` for an assumption and `NULL` for the other types; the `refs` column becomes rows of the `refs` table, each with `kind` `observation` |
| `observations.evidence`, `confidence`, `criteria`, `cause`, `effect`, `suggestion`, `legacy_category` | `fields` (JSON), keyed by the column name |
| `attributed_to` | `agent_id`, unchanged; `NULL` (rows that came from v3) becomes `unknown`. `agent_type` follows the value: `commander` for `commander`; `hook` for a hook's file name (`*.sh`, `*.py`); `delegate` for a mission name (`<mission name>`, or an older `S<n>-...` name); otherwise `session` |
| type `finding` | `observation`, `fields.legacy_category` `finding`. A v4 finding records what was seen and analyzed, not what was acted on, so it is an observation (D874d-20), although the glossary's `replacedBy` for the retired term is `deviation` (D874d-28) |
| type `fact` | `fact` (D874d-43) |
| `decisions` rows | items of type `decision`: `decision_id` becomes `id` (its record id, 3.2.4), `title` becomes `text`, `decided_at` becomes `created_at`, `status` keeps its column, and `fields` holds `description`, `implementation_evidence` and `implemented_at` |
| `deviations` rows | items of type `deviation`, id `DEV-<n>` in `deviation_id` order (the old number in `fields.legacy_id`), `from.kind` `plan`, `text` from the description, `effect` from the impact, `fields.batch_origin` from `batch_origin` |
| `session` | unchanged; `schwerpunkt` holds `main_effort`; the columns `intent` and `assessment` are added |
| `messages` (SITREP, SPOTREP) | unchanged: messages are not items |
| `missions`, `delegation_log`, `commander_directives`, `commander_feedback`, `events`, `completed_work`, `hard_requirements`, `version_history` | unchanged (RFC 0010: never remove columns) |
| `schema_version` | a row for version 5 is added when the migration completes |

After the migration, views named `observations`, `decisions` and `deviations` over `items` MUST present the v4 column names, latest versions only, for existing readers such as `intelligence-stop.py`. Each view column is an `items` column under its v4 name (for `decisions`: `id AS decision_id`, `text AS title`, `created_at AS decided_at`; for `observations`: `type AS category`); a v4 column that v5 keeps in `fields` is presented as `NULL`, because the views, like every query, do not use SQLite's JSON functions (3.6.4). The views MUST NOT accept writes, and the migration MUST NOT create an index on a view. A migrated row (one with `fields.legacy_id` or `fields.legacy_category`) is exempt from the type-specific fields that 3.2.2 requires, in `validate` and in the DB's checks.

3.6.8. `scripts/harness-db.py` is the schema's source of truth, and `reference/harness-db-schema.sql` is generated from it (PR #181). This supersedes RFC 0010 section 5, which called the `.sql` file canonical, and RFC 0010 section 7, which called the export git-tracked (D874d-52).

3.6.9. `--session` is removed from every session-DB verb that 3.6.10 lists, write or read, and replaced by `--db` (D874d-31). The harness-DB verbs (`knowledge`, `edge`, `nogood`) and the lifecycle verbs (`session start | end`, `process-events`, `mission`) keep their `--session`: there it names a session in the cross-session harness DB, or finds `.scratch/session-<session id>/`, which needs the full session id that the 10-character DB name does not give. The removal MUST ship in the same change as the hooks' switch to `--db`, and `aitools` MUST deploy the helper and the hooks together (3.6.12). There MUST NOT be a deprecated `--session` alias (D874d-57). *Settled by this RFC (S-15).*

3.6.10. Every session-DB verb takes `--db`: the read verbs `ol list`, `decision list`, `incident list` and `search`; `log` and `directive add | list | poll | ack`, which keep their stores (`messages`, `commander_directives`); and the verbs this RFC adds or changes:
- `item add | update | list` (new);
- `observation add` and `ol add`, which write items of their type;
- `decision add`, which writes a `decision` item;
- `incident add`, which writes a `deviation` item (a process deviation, `from.kind` `plan`; not the `observation` of an `INCIDENT:` marker, 3.4.5);
- `estimate set` (new, 3.5.3);
- `aar --db <path> --agent-id <id> --brief <path>` (new), which renders the rows with that `agent_id` as the delegate's AAR, taking `provenance.mission`, `provenance.brief` and the objectives' verbatim text from the brief, and each objective's status, `how` and deliverables from the delegate's objective rows;
- `export --format json` (existing), which now writes the per-session export (3.5.5).

`knowledge add` keeps its store, the cross-session harness DB, and its `--session`. The `validate` verb, which takes a file and no `--db`, is described in 3.7.2.

3.6.11. Until schema 5 ships (section 2), agents MUST NOT write the items of these documents to the DB. `provenance.session_db` is empty, and the AAR hand-back is the whole record (AMB-6 of the issue).

3.6.12. **Version skew.** A schema-4 `harness-db.py` crashes on a schema-5 DB: its `migrate_v4` runs before its version check, and it tries to drop and index the `observations` view. Therefore:
- the v5 helper MUST check the DB's schema version before it migrates, and MUST leave a newer DB untouched (hooks exit 0, CLI exits 1);
- the migration to v5 MUST run only through the deployed helper, after `aitools` has deployed the v5 helper and hooks together;
- a repo or worktree copy of `harness-db.py` MUST NOT open a session DB under any `<repo>/.aitools/sessions/` directory: the hooks MUST resolve only `~/.aitools/bin/harness-db.py`, without their fallbacks to `<repo>/scripts/harness-db.py` and `~/repos/aitools/scripts/harness-db.py` (a hook that finds no deployed helper exits 0, section 6), and tests and probes MUST use throwaway DBs outside that directory;
- the deploy MUST report a skipped helper or hook (an `[s]kip` at the review menu) as a WARN, because the helper and the hooks that call it (`harness-db-sessionstart.sh`, `harness-db-sessionend.sh`, `scratch-init.sh`, `command-channel-stop.sh`, `intelligence-stop.py`) are safe only at the same version;
- the harness DB (`.aitools/harness.db`) shares `SCHEMA_VERSION`: the v5 helper records version 5 in it although its tables do not change, and a v4 helper then warns on it and changes nothing (`record_schema_version`).

*Settled by this RFC (S-20).*

### 3.7 Schemas, templates and validation

3.7.1. Each document kind MUST have a schema, written as a JSON Schema file that names its draft in `$schema`, and a template, an empty instance:

| Kind | Files |
|---|---|
| Schemas | `reference/schemas/mission-brief.schema.json`, `reference/schemas/aar.schema.json`, `reference/schemas/running-estimate.schema.json` |
| Templates (empty instances) | `reference/templates/mission-brief.json`, `reference/templates/aar.json`, `reference/templates/running-estimate.json` |
| Prose reference | `reference/structured-reports.md` |

`deploy-harness` copies the git-tracked `reference/` tree to `~/.aitools/reference/` read-only, so a delegate in any repo can read the schemas. *Settled by this RFC (S-1).*

3.7.2. Validation MUST use the Python standard library only (RFC 0010 section 2). *Settled by this RFC (S-6).* `harness-db.py validate --kind brief | aar | estimate <file>` (the kinds name the documents whose `provenance.document` is `mission-brief`, `aar` and `running-estimate`) MUST perform the checks below, MUST exit 0 when all pass, and MUST exit 1 when any fails, printing one line per violation (`<JSON path>: <rule>`) to stderr:
- **the JSON Schema subset the schema files use:** `type` (a type name, or a two-element array whose second element is "null", used only where null is allowed, section 2), `required`, `properties`, `items`, `enum`, `additionalProperties: false`, and `$ref` to `#/$defs/<name>` in the same file. Each schema file holds the shared item and entry definitions (3.2) in its own `$defs`, identical in the three files, and a test compares them;
- **the rules JSON Schema cannot express:**
  - a `quote` is present when `source.kind` is `commander`;
  - an objective whose `status` is `partly` or `not accomplished` cites at least one deviation in `deviation_refs`;
  - ids match `<TYPE>-<n>`, `R<sid4>-<n>`, `R<mission name>-<n>` or `D<sid4>-<n>`; a decision that keeps the id of its record (3.2.2), such as `D-DEL6`, is exempt from this check;
  - timestamps are UTC in the form `YYYY-MM-DDTHH:MM:SSZ`, optionally with a fraction of 1 to 6 digits after the seconds;
  - item nodes hold items, and plain nodes hold plain entries (3.2.1a);
  - every `artifacts[]` path is absolute, and its instruction is one of the two values (3.3.3a);
  - every deliverable's `kind` is one of its values, and a brief has exactly one deliverable of kind `aar` (3.2.6).

The implementer MUST NOT add a third-party validator. For an AAR, `validate` reads the last fenced JSON block of a hand-back (3.4.1).

### 3.8 Names and ids

| Kind | Convention | Example |
|---|---|---|
| Mission brief (default) | `<session scratch dir>/<mission name>-brief.json` | `874d-3-spec-verify-brief.json` |
| Mission brief (long lifecycle, on the commander's order) | `<repo>/briefs/<mission name>-brief.json`, tracked | `briefs/874d-2-structured-reports-brief.json` |
| AAR file (on request only) | `<session scratch dir>/<mission name>-aar.json` | `874d-2-structured-reports-aar.json` |
| Session DB | `<repo>/.aitools/sessions/<session id prefix>.db` | `dbd05b0c-2.db` |
| Export (project repo, untracked) | `<repo>/.aitools/channel/estimates/<session id prefix>.json` | `dbd05b0c-2.json` |
| Record (dotprofile, tracked) | `<dotprofile>/running-estimates/<project>/<YYYY-MM-DD>_<session id prefix>.json` (session start date, UTC) | `running-estimates/aitools/2026-11-15_dbd05b0c-2.json` |
| Session RFI | `R<sid4>-<n>`; a delegate's provisional RFI `R<mission name>-<n>` | `R874d-28` |
| Decision | `D<sid4>-<n>` | `D874d-53` |

The directories and files the harness creates MUST NOT have spaces in their names (D874d-53). The roots it is given, `<repo>` and the dotprofile path, can contain spaces, so every script MUST quote them where it expands them. *Settled by this RFC (S-22).*

### 3.9 Delegation duties

3.9.1. These delegation duties carry the documents. They are recorded as decisions in `shared/rules/delegation.md` and as practice in `/delegate` (D-DEL7):

| Decision | Duty | By |
|---|---|---|
| D-DEL8 | Mission objectives verbatim in the delegation prompt, recursively through the chain of command (D874d-13) | commander |
| D-DEL9 | A blocker is reported at once, with a recommended course of action; this is a standing duty (D874d-16, D874d-26) | commander |
| D-DEL10 | A brief for every delegate; the prompt gives its path and says to read it in full (D874d-27) | commander |
| D-DEL11 | The final report, the hand-back, is the AAR (D874d-29) | commander |
| D-DEL12 | Unstructured content goes in the prompt body, not the brief (D874d-32) | commander |
| D-DEL13 | Every delegate loads `/delegate` at start | the session agent dbd05b0c, review after (D-DEL5); the commander placed the standing duties in the skill (D874d-64) |

3.9.2. **Deployment lag.** D-DEL8 to D-DEL13 reach a delegate only once `aitools` deploys the updated `/delegate` and rule, and the deployed copy can lag the source. Until then, the delegating agent MUST restate in the delegation prompt each of D-DEL8 to D-DEL13 that the deployed `/delegate` does not yet carry. The brief MUST NOT carry them (D874d-64), and the prompt MUST still carry the prompt elements `/delegate` lists.

3.9.3. The delegation guards (`delegation-duty-guard.sh`, `workflow-delegation-guard.sh`) MUST check that a delegation prompt contains an absolute path ending in `-brief.json` and the words "read your mission brief in full" (case-insensitive), the instruction of 3.3.5 (D874d-27), in observe mode first (`.claude/rules/hook-rollout.md`). When the prompt gives a brief path, they score `/delegate` elements 2 and 4 from the brief's `artifacts[]` and `operational_learning[]`.

3.9.4. At v1.5 of this RFC, the working copies of `shared/rules/delegation.md` (D-DEL10) and `shared/skills/delegate/SKILL.md` name the brief `<sid4>_<mission name>-brief.md` in Markdown and do not say that the hand-back is JSON. Plan WP-2 brings them in line with this RFC (D874d-49).

---

## 4. Settled by this RFC

Each point below is decided here, not by the commander, and is listed under "Review after" for the commander's review (D-DEL5). The commander has since decided three of them: S-18 (accepted, D874d-55), S-19 (accepted, D874d-56) and S-8 (replaced by `artifacts[]`, D874d-65).

| ID | Point | Settled as | Why |
|---|---|---|---|
| S-1 | Where the schemas and templates live (issue AMB-2) | `reference/schemas/`, `reference/templates/`, `reference/structured-reports.md` (3.7.1) | `deploy-harness` already copies `reference/` to every machine, read-only |
| S-2 | Who updates the running estimate, and where it is kept (issue AMB-3) | The session agent, at each prompt turn and after each hand-back, once schema 5 ships; `intent`, `main_effort` and `assessment` in the `session` table (3.5.3) | The prompt-turn checklist already runs every turn; these three are not items |
| S-3 | Briefs for workflow delegates (issue AMB-5) | One brief per `agent()` call (3.3.6) | The delegation rule covers workflows; a workflow delegate cannot ask for what it was not given |
| S-4 | Changing an item (issue AMB-7) | Append a new version, key (`id`, `version`); readers take the latest (3.2.5) | Provenance is never deleted |
| S-5 | Type-specific fields (issue AMB-8) | One `fields` column of JSON text, parsed in Python (3.6.4) | Keeps the store independent of the SQLite build |
| S-6 | Validating documents (issue ASM-7) | A stdlib validator: the JSON Schema subset plus coded rules (3.7.2) | RFC 0010 section 2: stdlib only; JSON Schema cannot express all of the requirements |
| S-7 | Item ids in documents | Numbered from 1, or the copied record's ids (3.2.4) | Traceability to the issue's ASM and AMB ids |
| S-8 | Where a brief lists the mission's references | *Superseded by D874d-65:* `artifacts[]` entries `{path, instruction}` (3.3.3a) | The commander's decision; whether a file binds follows from what it is |
| S-9 | Delegates confined to their worktree (ASM-3, ASM-4) | The brief goes in the delegating agent's own scratch and the AAR names it; the delegating agent records the delegate's missing items (3.3.8, 3.4.8) | `/delegate`: worktree isolation "confines writes to the worktree" |
| S-10 | Lock contention (ASM-2) | `harness-db.py` retries a locked write three times for an agent, then exits 1, and the agent records a blocker; hooks never retry; `ensure_schema` runs at session start only (3.6.6) | A locked DB fails loudly without stalling a hook |
| S-11 | Prefix collision (ASM-6) | Checked at session start; the colliding session uses its full id as the DB name (3.6.2) | No session is left without a DB |
| S-12 | Existing tables, verbs and readers | Views `observations`, `decisions` and `deviations` with v4 columns; each verb keeps or changes its store as 3.6.10 says (3.6.7) | Existing readers such as `intelligence-stop.py` keep working |
| S-13 | The old single export | Retired, with every reader repointed or updated (3.5.6) | Replaced by the per-session export and the dotprofile record |
| S-14 | Briefs, AARs and copies of the commander's words reaching a tracked path | The harvester treats `*-brief.json` and `*-aar.json` as ephemeral (it already treats `*.tmp` so), and agents save copies of transcripts, prompts and issue bodies as `*.tmp` (section 7) | The harvester copies every other top-level scratch file into the tracked `harvesting/` of a public repo |
| S-15 | Removing `--session` | From the session-DB verbs that 3.6.10 lists, write and read, in the same change as the hooks; helper and hooks deploy together (3.6.9) | Elsewhere `--session` names a session in the cross-session DB |
| S-16 | Key order | Writers emit the spec's order; readers do not depend on it (3.1.5) | JSON objects are unordered |
| S-17 | The v4 to v5 mapping | The table in 3.6.7, every column and table accounted for | No v4 data is lost |
| S-18 | Writer fields of items inside a document | Inherited from `provenance`; required on every DB row (3.2.1) | A document has one writer and one time. Accepted by the commander (D874d-55) |
| S-19 | A superseded decision | Status `superseded` and `superseded_by[]` (3.2.2) | The issue keeps superseded decisions as the record. Accepted by the commander (D874d-56) |
| S-20 | Version skew between helper, hooks and DB | Version check first; migration only through the deployed v5 pair; a skipped deploy is a WARN (3.6.12) | A v4 helper crashes on a v5 DB (observed on a throwaway DB) |
| S-21 | The SessionEnd sequence | One detached job: export, copy, commit, push, with a lock and a rebase; catch-up recovers each step (3.5.5) | Two separate hooks have no order, and the SessionEnd window is 1.5 seconds |
| S-22 | `<repo>`, `<project>`, the record's date, spaces in paths | The recorded project root, the base name of its main worktree, the session's start date; no spaces in names the harness creates (section 2, 3.5.5, 3.8) | The working directory changes; the start date fits D874d-53's example |
| S-23 | Document ids against DB ids | The DB assigns new ids, keeps `fields.doc_id` and rewrites refs; a delegate's RFIs in a document not yet in the DB are `R<mission name>-<n>` (3.2.4) | Parallel documents would collide |
| S-24 | Credentials in verbatim quotes | Replaced by `[redacted]`, the one permitted change (3.2.1) | The verbatim rule and the no-secrets rule otherwise conflict |
| S-25 | What a session is | One Claude Code session, identified by its session id; `/clear` starts a new session, `/resume` continues it (section 2) | SessionEnd fires on both |
| S-26 | The structure of a deliverable (D874d-70: "structured and match the RFC") | One shape, `{kind, ref, text}`, in the brief (with the `objective` it serves) and in an objective's `deliverables[]`; the AAR is always one (3.2.6) | One definition serves what is asked and what is produced; a delegating agent checks each `ref` it receives |

---

## 5. Alternatives considered

| Alternative | Outcome |
|---|---|
| One JSON file per session as the store | Rejected: one JSON file cannot take parallel writers safely (R874d-1); SQLite is the store (D874d-35) |
| A table per agent | Rejected: tables would multiply with every delegate and queries would need unions; one table with `agent_id` (D874d-25, D874d-31) |
| A Markdown brief named `<sid4>_<mission name>-brief.md` | Replaced by `<mission name>-brief.json` (D874d-42) |
| An AAR file by default | Rejected: the AAR is the hand-back; a file only on request (D874d-47) |
| `harness-db.py mission` commands that keep a `missions` table | Rejected: each delegate finds its own agentId (D874d-33); the brief file and the delegate's rows carry the rest |
| A `finding` type | Retired: what was acted on is a deviation, what was seen is an observation (D874d-22, D874d-28) |
| A list of conditions to report at once in each brief | Rejected: reporting a blocker at once is a standing duty (D874d-26) |
| A third-party JSON Schema validator | Rejected: stdlib only (RFC 0010 section 2) |
| Committing the export in the project repo | Rejected: the export stays untracked and the record goes to the dotprofile (D874d-52) |
| A deprecated `--session` alias for one release | Rejected by the commander (D874d-57); skew is handled by S-20 |
| `rules[]` and `skills[]` in the brief (S-8: `rules[]` entries `{path, kind}`) | Replaced by `artifacts[]` (D874d-65) |
| Separate `rules[]` and `references[]` lists, binding and not | Rejected: `artifacts[]` says how to read each file; whether it binds follows from what it is (D-DEL6) |
| `ambiguities`, `access`, `name_prefix`, `duties` and `return {hand_back, file}` in the brief | Removed by the commander (D874d-70); their content moves to decisions, constraints, the prompt and `deliverables[]` (3.1.3) |

---

## 6. Cross-platform

- **`harness-db.py`:** standard library only. Its header requires Python 3.10 or later. RFC 0010 section 11 gives 3.8; the floor stated in the code, 3.10, applies. Hooks find Python as `python3`, then `python` (RFC 0010 section 6).
- **Hooks:** bash on every platform (`.claude/rules/cross-platform.md`, "Hook portability"). A hook MUST exit 0 when Python or the DB is missing (RFC 0010 section 8).
- **Paths:** the harness creates no names with spaces, and every script quotes the roots it is given (3.8).
- **The detached SessionEnd job** uses the same detachment as `session-archive.sh`. The implementer MUST verify on Windows (plan batch 4.3) that it outlives Claude Code there, and MUST NOT assume it.
- **Finding a delegate's agentId:** verified for Claude Code only (D874d-33). In Claude Code web, delegates cannot delegate further (nesting depth 1), but briefs and AARs still apply. Cursor harnesses are not yet examined (section 8).

---

## 7. Security and privacy

- **The aitools repo is public** (`gh repo view`: visibility PUBLIC). Briefs, AARs, running estimates and copies of transcripts, prompts and issue bodies carry the commander's words verbatim and the session's content. An agent MUST NOT commit them to a project repo, with one exception: a brief the commander orders into the briefs directory (3.3.1, 3.3.1a; D874d-72 to D874d-74).
- **The project-repo export stays untracked; the record goes to the commander's dotprofile** (D874d-52). The dotprofile already receives the full session transcripts (`ait-harvest.py archive`), so the record adds no new kind of exposure there.
- **Existing exposure.** At v1.5 of this RFC, the single export `.aitools/channel/running-estimate.json` is tracked: last committed in `5d8fa521` (2026-11-15), holding one observation. `harvesting/` holds tracked files whose names show session content, among them prompts, AARs, briefs and issue bodies. The commander decided that this work takes no action on them (D874d-54). The old export stops being written in plan WP-3 and is removed in WP-5 (3.5.6). A history rewrite is destructive, and an agent MUST NOT rewrite history without the commander's order.
- **Harvester (S-14).** The SessionEnd and SessionStart harvester copies every non-ephemeral top-level file of a session's scratch directory into the tracked `harvesting/`. Among `.json` files it exempts only `package-lock*`, `node_modules*`, `tsconfig*` and `*.config.json` (`ait-harvest.py` `_is_ephemeral`).
  - It MUST treat `*-brief.json` and `*-aar.json` as ephemeral (`_is_ephemeral` already treats `*.tmp` so).
  - An agent that saves a copy of a transcript, a prompt or an issue body in a scratch directory MUST give it a name ending in `.tmp`.
  - Until the harvester change above ships, an agent MUST NOT commit a harvested copy of a brief, an AAR, a transcript, a prompt or an issue body.
- **Other repos.** The SessionStart hook creates `.aitools/` and `.scratch/` in any repo a session runs in, and outside aitools nothing ignores them. At session start, in any git repo where `git check-ignore` reports `.aitools/` or `.scratch/` as not ignored, the SessionStart hook MUST append each such entry to the file that `git rev-parse --git-path info/exclude` names (that file is local and never committed; in a linked worktree `.git` is a file, not a directory, which is why the hook asks git for the path), and MUST report each entry in the session that appends it; an entry already appended is not reported again (D874d-58).
- **No credentials.** Writers MUST NOT copy credentials or access tokens into any item; in a quote, the writer MUST replace each with `[redacted]` (3.2.1, S-24).

---

## 8. Implementation

The plan, `plans/structured-reports/implementation-plan.md`, splits the work into batches of two or three files, each with its verification:

| WP | What |
|---|---|
| WP-0 | This RFC and the plan, on main (D874d-59, D874d-69); the findings of four verifiers (874d-3 to 874d-6) and three language reviewers (874d-7, 874d-9, 874d-11) applied; no separate verdict is kept (D874d-68) |
| WP-1 | Reference, schemas, templates, and the `validate` verb |
| WP-2 | The harness text brought in line (D874d-49) |
| WP-3 | Session DB schema 5: migration, views, version skew, the hooks' switch to `--db` |
| WP-4 | Delegation-guard checks, the AAR check, the SessionEnd job, the harvester exclusion |
| WP-5 | The skills and readers that use the documents; the old export retired |
| WP-6 | Release, the glossary check, and the doctrine adoption through `/frameworks` |

The implementing mission's brief is `briefs/874d-2-structured-reports-brief.json`, placed in the briefs directory on the commander's order (D874d-71). The mission launches only on the commander's order (D874d-45).

**Out of scope:**
- the `/debrief`, `/brief` and `/channel` skills (D874d-11);
- sharing estimates across sessions, and distributed sessions (D874d-9, D874d-10);
- harnesses other than Claude Code, beyond recording what is found when they are examined (D874d-33).

---

## 9. Open questions

None open. R874d-29 to R874d-33 were answered on L3394 (D874d-54 to D874d-58), R874d-40 to R874d-43 on L3479 (D874d-66 to D874d-69), R874d-44 and R874d-45 on L4045 (D874d-71 to D874d-74), and R874d-46 to R874d-48 on L4523 (D874d-75 to D874d-77). The other points of section 4 remain subject to the commander's review (D-DEL5). The implementer MUST raise each point it finds unclear with the commander as a session RFI with a suggested answer.

---

## 10. References

- **Issue** nobul-tech/aitools#180, body v5.6: decisions D874d-1 to D874d-77 (section 1), naming (section 2), schema (section 3), store (section 4), implementation (section 7). Comments: the commander's answers (2026-11-15), the March history, "Doctrine behind the design", "Answers recorded", "Sections 5 and 6 (moved in v5.4)" (the standards and specs, and the assumptions and ambiguities), "Body version history (moved in v5.5)" and "Commander's decisions on the analysis type and the AAR node (2026-11-15)".
- **RFCs:** 0005-v2 (session intelligence), 0006 (delegation, P1 briefing-first), 0010 (Python and SQLite engineering).
- **Harness:** `shared/rules/delegation.md`, `shared/skills/delegate/SKILL.md`, `reference/framework-intelligence-types.md`, the glossary (`/glossary`), `reference/prompt-turn-checklist.md`, `reference/tool-ops-claude-code.md` (item #35).
- **Code:** `scripts/harness-db.py`, `scripts/ait-harvest.py`, `scripts/generate-dashboard.py`, `shared/hooks/harness-db-sessionstart.sh`, `harness-db-sessionend.sh`, `session-archive.sh`, `session-catchup.sh`, `intelligence-stop.py`, `dashboard-serve.sh`, `delegation-duty-guard.sh`, `workflow-delegation-guard.sh`.
- **Verifiers' reports** (session dbd05b0c, 2026-11-16), as AAR files in the session scratch directory (untracked, on the machine that ran the session, S-14): `874d-3-spec-verify-aar.json`, `874d-4-adversarial-aar.json`, `874d-5-brief-verify-aar.json`, `874d-6-standards-verify-aar.json`; the language reviewers' `874d-7-normative-language-aar.json`, `874d-9-implementer-read-aar.json` and `874d-11-consistency-aar.json`; and `874d-10-consistency-forensics-aar.json`, on why mission 874d-8 stopped.
- **Doctrine:** TC 7-0.1 (2025), ADP 5-0 (2019), FM 5-0 (2024), ADP 6-0 (2026), FM 6-99 (2021), AR 11-33 (2022); report of mission 874d-1-aar-doctrine (`.aitools/channel/handoffs/2026-11-15_dbd05b0c-missions/874d-1-aar-doctrine/874d-1-aar-doctrine-report.md`, untracked at v1.4).

---

## Appendix A. Where each decision is carried

This table lists every decision of issue #180 section 1 (D874d-1 to D874d-77). A note writes "-22" for D874d-22. "Superseded" means a newer decision replaced it, in whole or in part. "Session only" means it governed the session's own work, not the implementation.

| Decision | Carried in | Note |
|---|---|---|
| D874d-1 | 3.2.2 proposal (barrier analysis) | Node set superseded by -19, -22, -29 |
| D874d-2 | 3.1.3 | Superseded by -22 (no `findings` node) |
| D874d-3 | 3.1.3, 3.2.2 | Superseded by -22 and -28 |
| D874d-4 | 3.1.2 | Superseded by -29 (`operational_learning` is its own node) |
| D874d-5 | 3.4.5 | |
| D874d-6 | 3.6.7 (`messages`: SPOTREP) | |
| D874d-7 | 3.7.1 | Format superseded by -35 (store) and -42 (files) |
| D874d-8 | 3.5.1 | "as json" superseded by -35 |
| D874d-9 | 3.5.1, section 8 | |
| D874d-10 | section 8 (out of scope) | |
| D874d-11 | section 8 (out of scope) | |
| D874d-12 | 3.3.1 | |
| D874d-13 | 3.2.2, 3.3.3, 3.3.5, 3.4.4, 3.9.1 | |
| D874d-14 | 3.2.2, 3.4.2 | |
| D874d-15 | 3.2.2, 3.4.2 | |
| D874d-16 | 3.9.1 | The prompt's list superseded by -26 |
| D874d-17 | section 2, 3.2.2 | |
| D874d-18 | section 2 | |
| D874d-19 | 3.1.3, 3.1.4 | |
| D874d-20 | 3.2.2, 3.6.7 | |
| D874d-21 | 3.2.3 | |
| D874d-22 | 3.1.3, 3.2.2 | |
| D874d-23 | 3.2.2, 3.4.4 | |
| D874d-24 | 3.2.2 | |
| D874d-25 | 3.2.1, 3.6.3 | |
| D874d-26 | 3.1.3, 3.3.7, 3.9.1 | |
| D874d-27 | 3.3.3a, 3.3.5, 3.9.1, 3.9.3 | |
| D874d-28 | 3.2.1, 3.6.7 | |
| D874d-29 | 3.1.4, 3.2.2, 3.2.3, 3.4.5, 3.9.1 | |
| D874d-30 | 3.2.2 (`deliverables`; no `artifact_refs`) | Its glossary requirement is set aside at present (D874d-66) |
| D874d-31 | 3.6.3, 3.6.5, 3.6.9 | |
| D874d-32 | 3.1.3, 3.2.2, 3.3.3a, 3.3.4, 3.9.1 | |
| D874d-33 | 3.4.9, section 6, section 8 | |
| D874d-34 | 3.2.2, 3.2.6, 3.4.4 | |
| D874d-35 | 3.5.1, 3.6 | |
| D874d-36 | 3.3.1 (location) | Name and format superseded by -42 |
| D874d-37 | section 2 | |
| D874d-38 | | Session only (the session's `/delegate` changes) |
| D874d-39 | | Superseded by -41 |
| D874d-40 | | Session only |
| D874d-41 | 3.2.2, 3.2.4, 3.8 | |
| D874d-42 | 3.3.1, 3.8 | The AAR file part superseded by -47 |
| D874d-43 | 3.2.1, 3.2.2, 3.6.7 | |
| D874d-44 | 3.5.5, 3.6.1 | The export is untracked (-52) |
| D874d-45 | section 8 | |
| D874d-46 | | Session only (issue v4.1) |
| D874d-47 | 3.2.6, 3.4.1, 3.4.7 | |
| D874d-48 | 3.6.1 | |
| D874d-49 | 3.9.4, section 8 (WP-2) | |
| D874d-50 | 3.2.6, 3.4.1 | |
| D874d-51 | 3.5.5 | |
| D874d-52 | 3.5.5, 3.6.8, section 7 | |
| D874d-53 | 3.5.5, 3.8 | |
| D874d-54 | 3.5.6, section 7 | |
| D874d-55 | 3.2.1 (S-18) | |
| D874d-56 | 3.2.2 (S-19) | |
| D874d-57 | 3.6.9, section 5 | |
| D874d-58 | section 7 | |
| D874d-59 | section 8 (WP-0) | Session only (commit 419d32dd) |
| D874d-60 | | The plan ("How every batch is shipped") |
| D874d-61 | 3.5.6 | And plan WP-2, WP-5 |
| D874d-62 | | Superseded by -66 |
| D874d-63 | | Session only (issue body v5.3) |
| D874d-64 | 3.1.3, 3.3.3, 3.3.5, 3.9.1, 3.9.2 | |
| D874d-65 | 3.1.2, 3.1.3, 3.2.1a, 3.3.2, 3.3.3, 3.3.3a, 3.3.5, 3.7.2, section 5 | |
| D874d-66 | section 2, D874d-30 above | |
| D874d-67 | section 2 | And plan batch 2.2 |
| D874d-68 | section 8 (WP-0) | |
| D874d-69 | section 8 (WP-0) | Session only |
| D874d-70 | 3.1.2, 3.1.3, 3.2.1a, 3.2.6, 3.3.2, 3.3.3, 3.3.5, 3.4.7, 3.7.2, section 5 | |
| D874d-71 | section 8 | |
| D874d-72 | section 2, 3.3.1, 3.3.1a, 3.8, section 7 | |
| D874d-73 | 3.3.1, section 7 | |
| D874d-74 | section 2, 3.3.1, section 7 | |
| D874d-75 | | Session only (the relaunch of the consistency review) |
| D874d-76 | 3.3.1a | |
| D874d-77 | | Session only (the false-positive report) |
