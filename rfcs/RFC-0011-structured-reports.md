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

| Field | Value |
|-------|--------|
| **RFC** | 0011 |
| **Title** | Structured running estimates, mission briefs and after action reviews |
| **Author(s)** | Session agent dbd05b0c, with the commander (Jose) |
| **Status** | Proposed |
| **Created** | 2026-11-16 |
| **Updated** | 2026-11-16 |
| **Issue** | [nobul-tech/aitools#180](https://github.com/nobul-tech/aitools/issues/180), body v5.2 |
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
- what must never reach a project repo, since the aitools repo is public.

It turns the commander's decisions recorded in issue #180 (D874d-1 to D874d-53) into normative text, and settles the points that issue left to this RFC (section 4).

---

## Status of this memo

**Proposed.** This RFC is normative for the implementation of issue #180.
- **The commander's decisions** cited as `D874d-<n>` are fixed. This RFC does not reopen them, and appendix A shows where each one is carried. A point the implementer finds unclear goes to the commander as an RFI with a suggested answer.
- **Points this RFC settles itself** are marked "Settled by this RFC" and listed in section 4. They are written as a version and reviewed after (D-DEL5).
- **Precedence.** A mission brief is part of the delegation briefing, which D-DEL6 ranks above harness documents such as this RFC. Briefs are written to agree with this RFC, so a conflict between the two is a defect to report, not a choice.

---

## 1. Motivation

- **No structured hand-back.** A delegate hands back a free-text list (`/delegate` "Final response shape" before v2.6). Nothing in it records what the delegate was told, what it did differently, or what it saw and left alone. Issue #177 (question 2) found that what a delegate learns after its merge has no home.
- **No structured running estimate.**
  - The estimate exists as a stub, `.aitools/channel/running-estimate.json`, and a template that no code reads.
  - The session DB (schema 4) holds intelligence items but no brief, AAR or estimate.
  - RFC 0005-v2 section 4 lists both as gaps: briefings ("Structured or freeform TBD") and the running estimate ("Aggregate from session DB").
- **No structure for the briefing file.** RFC 0006 section 4 (P1, briefing-first pattern) measured delegation quality rising from 2.0-3.4 to 4.0-4.8 once a shared briefing file was written, but never gave that file a structure.
- **The order.** The commander's objective for issue #180: "implement structured running estimates, briefings, aars".

---

## 2. Terminology

- **RFC 2119.** The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY" and "OPTIONAL" are to be interpreted as in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).
- **Governed terms** (`/glossary` skill): mission brief (synonyms: brief, delegate briefing, D874d-18), after action review (AAR), running estimate, deliverable, deviation, process deviation, observation, ambiguity, assumption, fact, operational learning, proposal, blocker, session RFI, delegating agent, delegate, provenance (D874d-37). This RFC uses them in their glossary meanings. Where this RFC refines a meaning (`observation`, `assumption`), plan batch 2.2 brings the glossary in line.
- **Session:** one Claude Code session id. `/clear` starts a new session (a new id, DB and estimate); `/resume` continues the same one (S-25).
- **Session agent:** the agent of the top-level Claude Code session.
- **Delegate:** any agent launched by another agent, at any level.
- **`<repo>`:** the session's project root, recorded in the session DB at session start (`session.project_dir`). It is never the current working directory, which can change during a session (S-22).
- **`<project>`:** the base name of `<repo>`, for example `aitools`.
- **`<sid4>`:** the last four hex digits of the top-level session id (for example `874d`).
- **Session id prefix:** the first 10 characters of the session id, hyphen included (for example `dbd05b0c-2`).
- **`<mission name>`:** `<commanderid>-<n>-<slug>`, where `<commanderid>` is the delegating agent's own four hex digits (`/delegate` naming conventions).
- **Session scratch directory:** `<repo>/.scratch/session-<session id>/` of the top-level session.

---

## 3. Specification

### 3.1 One schema, three documents

3.1.1. The mission brief, the AAR and the running estimate MUST share one schema. Every node and every item type is defined once, in this section, and MUST mean the same thing in every document that uses it.

3.1.2. Each document uses the nodes marked below. A document MUST NOT contain a node it is not marked for.

| Node | Mission brief | AAR | Running estimate |
|---|---|---|---|
| `provenance` | yes | yes | yes |
| `identity` | yes | | |
| `intent` | yes | | yes (the session's) |
| `objectives` | verbatim, with source | + status, how, refs, deliverables | the session's, + status |
| `constraints` | yes | | |
| `assumptions` | given | + end state | yes |
| `decisions` | to honour | | yes |
| `ambiguities` | already resolved, or flagged | found, how resolved | yes |
| `deviations` | | yes | yes |
| `observations` | | yes | yes |
| `operational_learning` | carried forward | new | yes |
| `proposals` | | yes | yes |
| `rfis` | | yes | yes |
| `missions` | | | derived (3.5.4) |
| `assessment` | | | yes |
| `rules`, `skills`, `access`, `name_prefix`, `duties`, `return` | yes | | |

3.1.3. No document has a `facts` node (D874d-32), a `report_at_once_if` node (D874d-26), a `meta` node (D874d-19) or a `findings` node (D874d-22). A mission brief has no `conflict_priority` and no `permissions` node: they are standing duties in `/delegate` and the delegation rule (D-DEL13, 3.9.2).

3.1.4. `provenance` is every document's header (D874d-29). It records what the document is, who wrote it, when, and for which session and mission.

3.1.5. Writers SHOULD emit the nodes in the order of 3.3.2, 3.4.2 and 3.5.2. Readers MUST NOT depend on key order. *Settled by this RFC (S-16).*

### 3.2 Items and plain entries

3.2.1. These nodes are **item nodes**: `objectives`, `assumptions`, `decisions`, `ambiguities`, `deviations`, `observations`, `operational_learning`, `proposals` and `rfis`. Every entry of an item node is an item, and MUST carry these common fields:

```
id             item id (3.2.4)
type           objective | deviation | observation | ambiguity | assumption | fact |
               decision | operational_learning | proposal | rfi
text           the statement
version        1 for a new item; + 1 for each later version (3.2.5)
agent_id       who wrote the item (D874d-25): the session id for the session agent,
               the subagent's agentId for a delegate, "commander", or a hook name
agent_type     session | delegate | commander | hook
mission        the delegate's mission name; empty for the other agent types
source.kind    commander | agent | telemetry | artifact | web
source.location  path:line | commit SHA | URL | transcript path + line
quote          the source text verbatim; REQUIRED when source.kind is commander (S-24)
created_at     UTC, Z suffix
severity       critical | high | medium | low   (OPTIONAL; deviation and observation only)
```

- Who *wrote* an item is `agent_id`. Who *said* it is `source.kind` with `quote`.
- In a brief or an AAR, an item MAY omit `version`, `agent_id`, `agent_type`, `mission` and `created_at`; it inherits them from the document's `provenance`. In the session DB, every row MUST carry them. *Settled by this RFC (S-18, R874d-30).*
- A quote MUST NOT carry a credential or a token. Such a passage is copied with the secret replaced by `[redacted]`, the one permitted change to a verbatim quote. *Settled by this RFC (S-24).*

3.2.1a. The other list nodes hold **plain entries**, not items:

| Node | Entry |
|---|---|
| `constraints` | `{text, source}` |
| `rules` | `{path, kind}`, where `kind` is `rule` (binding, D-DEL6 tier 4) or `reference` (read in full; not binding). *Settled by this RFC (S-8)* |
| `skills` | `{name, use, override}` |
| `duties` | a string |
| `identity.parallel_missions` | `{mission, scope}` |
| `provenance.chain_of_command` | a transcript path |

3.2.2. The type-specific fields are:

```
objective  OBJ-n
  text               verbatim from the delegation prompt (D-DEL8, D874d-13)
  source             who gave it, and where (REQUIRED)
  in an AAR or a running estimate, also:
  status             accomplished | partly | not accomplished          (D874d-23)
  how                a brief summary of how it was done, or why not
  deviation_refs[]   DEV ids
  observation_refs[] OBS ids
  deliverables[]     what it produced: PR or issue URL, commit SHA, file path (D874d-34)

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
  incident           true when it is reported as an INCIDENT: marker

ambiguity  AMB-n                 (D874d-14, D874d-17)
  text               the passage, verbatim
  source             where: a brief section, an order, a rule
  readings[]         the meanings it could have
  resolution         the reading acted on
  resolved_by        reason | read | test | delegate | rfi | assumption   (+ ref)
  evidence
  status             resolved | open                 (an open one is also an rfi)

assumption  ASM-n                (D874d-15)
  text
  status             unverified | verified | falsified
  confidence         low | moderate | high
  evidence           what verified or falsified it
  impact_if_false
  ref                (once verified or falsified) what settled it: a verified assumption
                     points to a fact ('validated'), a falsified one to the contradicting
                     observation ('invalidated'); the glossary's lifecycle (D874d-43)

fact  FACT-n                     a session-DB type kept by D874d-43; no document node lists
                                 facts (D874d-32); an assumption's ref may point to one
  text, evidence

decision  D<sid4>-<n>, or its record id
  text, decided_by, date, quote,
  status             decided | implemented | verified | deferred | reversed | superseded
  superseded_by[]    {decision, part}, when status is superseded or partly superseded
                     (S-19, R874d-31)

operational_learning  OL-n       (its own node, D874d-29)
  text               what worked, what failed, what to do differently
  deviation_refs[], observation_refs[]

proposal  PRO-n                  (barrier analysis: D874d-1; no owner, no timeline: D874d-24)
  what, why          other sources it rests on are cited in `why`
  barrier_analysis   would it have prevented the deviation or the issue?
  affected[]         files, rules, decisions it would change
  deviation_refs[], observation_refs[]
  disposition        proposed | accepted | rejected | deferred      (the commander's)

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
| `spec` | A specification the work product must meet: a reference document, a schema, an interface contract, a test expectation |
| `standard` | An outside authority: official tool documentation, a language or style standard, doctrine |

| `cause` | Meaning |
|---|---|
| `initiative` | The agent chose to deviate, within the commander's intent (disciplined initiative) |
| `blocker` | The given course could not be followed. A blocker is reported at once (D-DEL9); a denied write is one |
| `error` | Done differently by mistake, and found later |

3.2.4. Item ids are `<TYPE>-<n>` (`OBJ`, `DEV`, `OBS`, `AMB`, `ASM`, `FACT`, `OL`, `PRO`). Session RFIs are `R<sid4>-<n>` and decisions `D<sid4>-<n>` (D874d-41). *Settled by this RFC (S-7, S-23):*
- In the session DB (schema 5), `harness-db.py` MUST assign `<TYPE>-<n>` on insert, so parallel writers never collide.
- In a document, the writer numbers its items from 1. It MAY instead keep the ids of the record it copies them from, such as the issue's `ASM-<n>`, for traceability.
- When a document's items are written into the DB (3.4.8), the DB assigns new ids, keeps the document's id in `fields.doc_id`, and rewrites the document's refs to the new ids.
- A delegate cannot see the session's RFI counter, so it numbers its RFIs `R<mission name>-<n>`. The session agent renumbers them into `R<sid4>-<n>` when it raises them.

3.2.5. An item is never changed in place, because provenance is never deleted ("provenance is eternal", the commander, 2026-03-30). A change appends a new version of the item:
- The key of an item row is (`id`, `version`).
- A ref points to an `id` and means its latest version.
- Every reader, including the export, `aar`, the compatibility views (3.6.7) and the derived `missions[]`, reads the latest version of each id.

*Settled by this RFC (S-4).*

### 3.3 Mission brief

3.3.1. The delegating agent MUST write a mission brief for every delegate before it launches the delegate (D-DEL10). The brief MUST be written to `<session scratch dir>/<mission name>-brief.json` (D874d-36 location, D874d-42 name). The planning brief defines the delegate's mission objectives (D874d-12): the brief is where they are written.

3.3.2. The brief MUST be one JSON object with these top-level keys: `provenance`, `identity`, `intent`, `objectives`, `constraints`, `assumptions`, `decisions`, `ambiguities`, `operational_learning`, `rules`, `skills`, `access`, `name_prefix`, `duties`, `return`.

3.3.3. The nodes hold:

```
provenance
  document           "mission-brief"
  schema_version     1
  version            "v1.0", "v1.1" ... (D-DEL5)
  mission            <mission name>, the delegate's name
  session_id         the top-level session's id
  session_db         the session DB's path; empty until schema 5 ships (3.6.11)
  session_scratch    the top-level session's scratch directory (every brief lives there)
  written_by         {agent_id, agent_type, mission (null unless a delegate delegates)}
  chain_of_command[] the transcript path of every agent above the delegate
  created_at
identity             name, level, delegated_by, parallel_missions[] {mission, scope}
intent               purpose, scope, out_of_scope[], audience
objectives[]         objective items: text verbatim + source                 (D-DEL8)
constraints[]        {text, source}: what the delegate must not do or cannot use
assumptions[]        assumption items: what the delegating agent assumes; the delegate
                     verifies or falsifies each
decisions[]          decision items: the decisions the delegate must honour, quoted
ambiguities[]        ambiguity items: points already resolved for the delegate, or flagged
operational_learning[]  operational learning items, carried forward, each with its source
rules[]              {path, kind}: every file to read in full, line by line, by absolute
                     path; kind rule (binding) or reference (S-8)
skills[]             {name, use, override}: /delegate first, then the task skills
access               read_only[], writable[], scratch
name_prefix          "<mission name>-"                                       (D-DEL1)
duties[]             strings: the duties specific to this mission (for example shipping a
                     code change, D-DEL4); standing duties are not restated (D-DEL13)
return               {hand_back, file}: hand_back says the AAR is the hand-back message,
                     JSON in one fenced block (D874d-47, D874d-50); file is null, or the
                     AAR file's path when one is requested (3.4.7)
```

3.3.4. Only structured content goes in the brief. Anything unstructured, such as facts or background, MUST go in the body of the delegation prompt, outside the brief (D874d-32, D-DEL12).

3.3.5. The delegation prompt MUST:
- give the brief's path with the instruction "Before any other work, read your mission brief in full, line by line: `<path>`" (D874d-27);
- carry the mission objectives verbatim, each with its source (D-DEL8, D874d-13);
- tell the delegate explicitly what it reads in full, line by line (the brief and every file in its `rules[]`), and what it uses only as reference material, searched and never loaded whole (the chain-of-command transcripts, large registries and reports) (D874d-27).

3.3.6. Every delegate launched through a workflow (each `agent()` call) MUST get its own brief, written by the delegating agent before the workflow runs, and its prompt MUST give the brief's path. *Settled by this RFC (S-3).*

3.3.7. A blocker the delegating agent already knows at launch MUST be written as a constraint or in the prompt body, and the objective it affects MUST say so. The brief has no list of conditions to report at once: reporting a blocker at once is a standing duty (D-DEL9, D874d-26).

3.3.8. A delegating agent that cannot write into the top-level session's scratch directory, because worktree isolation confines its writes (ASM-4), MUST write the brief into its own scratch directory, under the same name. The prompt gives that path, and the delegate's AAR names it in `provenance.brief`, so `missions[]` still finds it (3.5.4). *Settled by this RFC (S-9).*

### 3.4 After action review (AAR)

3.4.1. Every delegate MUST end its mission with its AAR as its hand-back message (D874d-47). The AAR MUST be JSON in the AAR schema, in one fenced block, and that block MUST be the last ```` ```json ```` block of the hand-back (D874d-50). Prose MAY precede it. A string inside the AAR MUST NOT contain three backticks in a row.

3.4.2. The AAR MUST be one JSON object with these top-level keys: `provenance`, `objectives`, `ambiguities`, `assumptions`, `deviations`, `observations`, `operational_learning`, `proposals`, `rfis`. The first three answer "what was supposed to happen" (TC 7-0.1, 2025, 3-2 and 3-7).

3.4.3. `provenance` holds: `document` ("aar"), `schema_version`, `version`, `mission`, `agent_id` (the delegate's own agentId, 3.4.9), `session_id`, `brief` (the brief's path), `created_at`.

3.4.4. `objectives` MUST restate every objective of the brief, verbatim (D874d-13), each with its status, accomplished, partly or not accomplished (D874d-23).
- Each objective gives `how`, cites deviations or observations, or both (D874d-23).
- An objective that is not accomplished MUST cite the deviation that explains it.
- `deliverables` lists what the delegate produced for it (D874d-34).

3.4.5. The free-text lines of the old hand-back fold into these nodes (D874d-29, D-DEL11):
- a `WRITE_BLOCKED` denial becomes a deviation with cause `blocker` and `from.kind` `rule`, reported at once (D-DEL9);
- a `CONFLICT:` line becomes an ambiguity whose readings are the conflicting instructions, resolved by the D-DEL6 tier that won;
- an `INCIDENT:` marker becomes an observation with `incident: true`;
- PR URLs and files become an objective's `deliverables`.

What a delegate learns after its merge is recorded the same way, as observations or operational learning (D874d-5).

3.4.6. When a blocker stops an objective, the AAR records it in four places:
- the objective's status is `partly` or `not accomplished`;
- a deviation with cause `blocker` explains it;
- an assumption is marked falsified, if a wrong assumption caused it;
- a proposal or an RFI, if only the commander can clear it.

The blocker was also reported at once, with a recommended course of action (D-DEL9).

3.4.7. An AAR file is written only when one is requested. It then MUST be the same JSON, at `<session scratch dir>/<mission name>-aar.json` (D874d-47).

3.4.8. Once schema 5 ships:
- every item of the AAR MUST also be a row in the session DB, written by the delegate as it works;
- the delegate SHOULD produce its hand-back from its rows (`harness-db.py aar`, 3.6.10);
- a delegate that cannot write the session DB because worktree isolation confines its writes (ASM-3) hands back its AAR only. Its delegating agent, which receives the AAR, then writes the items the DB does not already hold, matched by `agent_id` and `fields.doc_id`, with `agent_id` from the AAR's `provenance.agent_id` and the ids rewritten (3.2.4). *Settled by this RFC (S-9, S-23).*

3.4.9. A delegate MUST find its own agentId by one of these methods (D874d-33):
- its `subagents/agent-<agentId>.meta.json`, whose `description` starts with its mission name. This file exists while the delegate runs (observed for background delegates, 2026-11-16);
- a `TaskStop` error that names the caller's id;
- its parent session's transcript (`/delegate` "Claude Code specifics").

The delegating agent MUST record the agentId the launch returns. That id fills `agent_id` when a delegate could not find its own (ASM-1). This holds for the Claude Code harness; other harnesses (Claude Code web, Cursor CLI, Cursor cloud agents) MUST be examined before they are relied on (D874d-33).

### 3.5 Running estimate

3.5.1. There is one running estimate per session (D874d-8). It lives in the session DB (D874d-35) and is written directly by the session agent and every delegate. It is not shared across sessions (D874d-9).

3.5.2. Its export MUST be one JSON object with these top-level keys: `provenance`, `intent`, `assessment`, `objectives`, `missions`, `assumptions`, `decisions`, `ambiguities`, `deviations`, `observations`, `operational_learning`, `proposals`, `rfis`.

```
provenance           document "running-estimate", schema_version, version, session_id,
                     session_db, maintainer (the session agent), created_at, updated_at
intent               the commander's intent for the session; main_effort
assessment           is the session proceeding according to the commander's intent?
                     (FM 1-02.1 "running estimate"; FM 5-0 table C-1 item 6)
objectives[]         the session's objectives: the commander's orders verbatim, with the
                     transcript line, + status, how, refs, deliverables
missions[]           derived on export (3.5.4)
assumptions[], decisions[], ambiguities[], deviations[], observations[],
operational_learning[], proposals[], rfis[]
```

3.5.3. Once schema 5 ships, the session agent MUST update `intent`, `main_effort`, `assessment` and the session's `objectives` at each prompt turn and after each hand-back. *Settled by this RFC (S-2):*
- `intent`, `main_effort` and `assessment` are columns of the `session` table, set with `harness-db.py estimate set`; each change is kept in `version_history`.
- The duty is added to the prompt-turn checklist, item 12 (plan batch 2.3).
- Before schema 5, nothing is written (3.6.11).

3.5.4. `missions[]` is derived on export and never written. It has one entry per `<mission name>-brief.json` in the session scratch directory, and per brief path named in a delegate's AAR `provenance.brief` (3.3.8). Each entry carries the `agent_id` and the objectives' status found on that mission's rows (latest versions, 3.2.5).

3.5.5. At session end, one detached job, started by `harness-db-sessionend.sh`, MUST run these steps in this order:
1. export the estimate to `<repo>/.aitools/channel/estimates/<session id prefix>.json`, untracked (D874d-44, D874d-52);
2. copy it to `<dotprofile>/running-estimates/<project>/<YYYY-MM-DD>_<session id prefix>.json`, where the date is the session's start date in UTC, from the session DB (D874d-52, D874d-53);
3. commit and push the dotprofile's `main` (D874d-51).

The job MUST also:
- run detached, because Claude Code gives SessionEnd hooks a 1.5-second default timeout (`reference/tool-ops-claude-code.md` item #35);
- take a single-flight lock on the dotprofile, so it never contends with `ait-harvest.py archive` for the git index;
- pull with rebase before it pushes, and refuse to push from a branch other than `main`.

The next session's catch-up (`session-catchup.sh`) MUST recover a missing export, copy, commit or push. Because the date is the start date, a resumed session (`/resume`) rewrites the same record file. *Settled by this RFC (S-21, S-22).*

3.5.6. The SessionEnd hook MUST stop writing the single `.aitools/channel/running-estimate.json`. That file and `.aitools/templates/mission-running-estimate.json` are retired (S-13). Every reader and description of the old file is repointed to the per-session export or updated: `scripts/generate-dashboard.py`, `scripts/aitools-dashboard.sh/.ps1`, `shared/hooks/dashboard-serve.sh`, the `/mission-control` and `/aitool-continue` skills, `.claude/rules/aitools-workspace.md` and `reference/artifact-harvesting.md`. Stopping the tracking of the old file is a security matter (section 7, R874d-29).

### 3.6 Store (session DB, schema 5)

3.6.1. The session DB is `<repo>/.aitools/sessions/<session id prefix>.db` (D874d-44, D874d-48), one per top-level session. The session agent and all its delegates, at every level, write to this one file.

3.6.2. At session start, `harness-db.py` MUST compare the full session id stored in an existing DB with the starting session's id. On a mismatch, two sessions share the 10-character prefix: it MUST log an error, never write the other session's DB, and use `<repo>/.aitools/sessions/<full session id>.db` instead (ASM-6). *Settled by this RFC (S-11).*

3.6.3. All session-DB items go in one `items` table, whatever the type and whatever the agent; there is no table per agent (D874d-25, D874d-31):

```
items   id, version, type, text, status, severity, fields, agent_id, agent_type, mission,
        source_kind, source, quote, created_at, updated_at          key (id, version)
refs    from_id, to_id, kind (objective | deviation | observation | deliverable |
        validated | invalidated)
```

`items` has no session-id column (D874d-31), because the file is the session. The `session` table keeps the session's full id, `project_dir`, start time, `intent`, `main_effort` and `assessment`. The export adds the session id.

3.6.4. The type-specific fields (3.2.2) MUST be stored in `fields` as JSON text, parsed and validated in Python. Queries MUST NOT depend on SQLite's JSON functions: availability varies by SQLite build, and parsing in Python keeps the store independent of the build. *Settled by this RFC (S-5).*

3.6.5. Session-DB writers MUST pass the DB's path (`--db`) and their own id. There is no `--session` argument on the session-DB write verbs (D874d-31, 3.6.9):

| Writer | Passes to `harness-db.py` | `agent_id` | `agent_type` (derived) | `mission` |
|---|---|---|---|---|
| Session agent | `--db <path> --agent-id <its session id>` | its session id | `session`: the id equals the DB's session id | |
| Delegate, any level | `--db <path from its brief> --agent-id <its own agentId> --mission <its name>` | its agentId | `delegate`: `--mission` is given | its name |
| Hook | `--db <path> --agent-id <hook file name>` | the hook name | `hook`: the id ends in `.sh` or `.py` | |
| The commander (command channel) | `--db <path> --agent-id commander` | `commander` | `commander` | |

`harness-db.py` derives `agent_type` as the table shows; there is no `--agent-type` flag. The session agent knows its session id and the DB's path from the SessionStart output ("Session started: …", "Session DB: …"; ASM-5).

3.6.6. Connections MUST use the RFC 0010 section 4 settings (WAL, `synchronous=NORMAL`, `busy_timeout=5000`, foreign keys) and `BEGIN IMMEDIATE` for writes. `ensure_schema`, which takes the write lock to run its DDL, MUST run at session start only, not on every write. *Settled by this RFC (S-10):*
- **Agents:** when a write still fails with "database is locked" after the busy timeout, the CLI retries up to three times with backoff, then exits 1 with the error. The agent then records the failed write as a deviation with cause `blocker`.
- **Hooks:** a hook does not retry. It logs the failure and exits 0 (RFC 0010 section 8).

3.6.7. The migration from schema 4 MUST be forward-only, inside `ensure_schema` (RFC 0010 section 5), and tested on copies of the live DBs, as PR #181 was. *Settled by this RFC (S-12, S-17).* It maps:

| v4 | v5 |
|---|---|
| `observations` rows | `items` rows, `version` 1 |
| `observations.evidence`, `confidence`, `criteria`, `cause`, `effect`, `suggestion`, `refs`, `legacy_category` | `fields` (JSON), keyed by the column name |
| `attributed_to` | `agent_id`, unchanged; NULL (rows that came from v3) becomes `unknown`. `agent_type` follows the value: `commander` for `commander`; `hook` for a hook's file name (`*.sh`, `*.py`); `delegate` for a mission name (`<4 hex>-<n>-<slug>`, or an older `S<n>-...` name); otherwise `session` |
| type `finding` | `observation`, `fields.legacy_category` `finding`. A v4 finding records what was seen and analysed, not what was acted on, so it is an observation (D874d-20), although the glossary's `replacedBy` for the retired term is `deviation` (D874d-28) |
| type `fact` | `fact` (D874d-43) |
| `decisions` rows | items of type `decision`, with `fields` holding `decision_id`, `implementation_evidence` and the timestamps |
| `deviations` rows | items of type `deviation`, `from.kind` `plan`, `text` from the description, `effect` from the impact |
| `messages` (SITREP, SPOTREP) | unchanged: messages are not items |
| `missions`, `delegation_log`, `commander_directives`, `commander_feedback`, `events`, `completed_work`, `hard_requirements`, `version_history` | unchanged (RFC 0010: never remove columns) |

After the migration, views named `observations`, `decisions` and `deviations` over `items` MUST present the v4 column names, latest versions only, for existing readers such as `intelligence-stop.py`. The views take no writes, and no index is created on a view.

3.6.8. `scripts/harness-db.py` is the schema's source of truth, and `reference/harness-db-schema.sql` is generated from it (PR #181). This supersedes RFC 0010 section 5, which called the `.sql` file canonical, and RFC 0010 section 7, which called the export git-tracked (D874d-52).

3.6.9. `--session` is removed from the **session-DB write verbs** (3.6.10) and replaced by `--db` (D874d-31). The harness-DB verbs (`knowledge`, `edge`, `nogood`) and the lifecycle verbs (`session start | end`, `process-events`, `mission`) keep their `--session`: there it names a session in the cross-session harness DB, or finds `.scratch/session-<full id>/`, which the 10-character DB name cannot do. The removal ships in the same change as the hooks' switch, and the helper and hooks deploy together (3.6.12). *Settled by this RFC (S-15).*

3.6.10. The session-DB write verbs are:
- `item add | update | list` (new);
- `observation add` and `ol add`, which write items of their type;
- `decision add`, which writes a `decision` item;
- `incident add`, which writes a `deviation` item;
- `estimate set` (new, 3.5.3);
- `aar --agent-id <id>` (new), which renders a delegate's rows as its AAR;
- `export --format json` (existing), which now writes the per-session export (3.5.5).

These keep their stores unchanged: `log` (the `messages` table), `directive add` (`commander_directives`) and `knowledge add` (the cross-session harness DB). The added `validate` verb is described in 3.7.

3.6.11. Until schema 5 ships, nothing is written to the DB for these documents. `provenance.session_db` is empty, and the AAR hand-back is the whole record (AMB-6 of the issue).

3.6.12. **Version skew.** A schema-4 `harness-db.py` crashes on a schema-5 DB: its `migrate_v4` runs before its version check, and it tries to drop and index the `observations` view. Therefore:
- the v5 helper MUST check the DB's schema version before it migrates, and MUST leave a newer DB untouched (hooks exit 0, CLI exits 1);
- the migration to v5 MUST run only through the deployed helper, after `aitools` has deployed the v5 helper and hooks together;
- no repo or worktree copy of `harness-db.py` may open a live session DB: tests and probes use throwaway DBs;
- the deploy reports a skipped helper or hook (an `[s]kip` at the review menu) as a WARN, because the pair must match.

*Settled by this RFC (S-20).*

### 3.7 Schemas, templates and validation

3.7.1. The schemas MUST be JSON Schema files, and every document MUST have a template:

| Kind | Files |
|---|---|
| Schemas | `reference/schemas/mission-brief.schema.json`, `reference/schemas/aar.schema.json`, `reference/schemas/running-estimate.schema.json` |
| Templates (empty instances) | `reference/templates/mission-brief.json`, `reference/templates/aar.json`, `reference/templates/running-estimate.json` |
| Prose reference | `reference/structured-reports.md` |

`deploy-harness` copies the git-tracked `reference/` tree to `~/.aitools/reference/` read-only, so a delegate in any repo can read the schemas. *Settled by this RFC (S-1).*

3.7.2. Validation MUST use the Python standard library only (RFC 0010 section 2). *Settled by this RFC (S-6).* `harness-db.py validate --kind brief | aar | estimate <file>` implements:
- **the JSON Schema subset the schema files use:** `type` (with `null` allowed only where the schema says so), `required`, `properties`, `items`, `enum`, `additionalProperties: false`;
- **the rules JSON Schema cannot express:**
  - a `quote` is required when `source.kind` is `commander`;
  - an objective that is not accomplished cites a deviation;
  - ids match `<TYPE>-<n>`, `R<sid4>-<n>`, `R<mission name>-<n>` or `D<sid4>-<n>`;
  - timestamps are UTC with a Z suffix;
  - item nodes hold items, and plain nodes hold plain entries (3.2.1a).

No third-party validator is added. For an AAR, `validate` reads the last fenced JSON block of a hand-back (3.4.1).

### 3.8 Names and ids

| Thing | Convention | Example |
|---|---|---|
| Mission brief | `<session scratch dir>/<mission name>-brief.json` | `874d-2-structured-reports-brief.json` |
| AAR file (on request only) | `<session scratch dir>/<mission name>-aar.json` | `874d-2-structured-reports-aar.json` |
| Session DB | `<repo>/.aitools/sessions/<session id prefix>.db` | `dbd05b0c-2.db` |
| Export (project repo, untracked) | `<repo>/.aitools/channel/estimates/<session id prefix>.json` | `dbd05b0c-2.json` |
| Record (dotprofile, tracked) | `<dotprofile>/running-estimates/<project>/<YYYY-MM-DD>_<session id prefix>.json` (session start date, UTC) | `running-estimates/aitools/2026-11-15_dbd05b0c-2.json` |
| Session RFI | `R<sid4>-<n>`; a delegate's provisional RFI `R<mission name>-<n>` | R874d-28 |
| Decision | `D<sid4>-<n>` | D874d-53 |

The directories and files the harness creates MUST NOT have spaces in their names (D874d-53). The roots it is given, `<repo>` and the dotprofile path, MAY contain spaces, and every script MUST quote them. *Settled by this RFC (S-22).*

### 3.9 Delegation duties

3.9.1. These delegation duties carry the documents. They are recorded as decisions in `shared/rules/delegation.md` and as practice in `/delegate` (D-DEL7):

| Decision | Duty | By |
|---|---|---|
| D-DEL8 | Mission objectives verbatim in the delegation prompt, recursively through the chain of command (D874d-13) | commander |
| D-DEL9 | A blocker is reported at once, with a recommended course of action; this is a standing duty (D874d-16, D874d-26) | commander |
| D-DEL10 | A brief for every delegate; the prompt gives its path and says to read it in full (D874d-27) | commander |
| D-DEL11 | The final report is the AAR (D874d-29) | commander |
| D-DEL12 | Unstructured content goes in the prompt body, not the brief (D874d-32) | commander |
| D-DEL13 | Every delegate loads `/delegate` at start | the session agent dbd05b0c, review-after (D-DEL5); not the commander's words |

3.9.2. Two of these depend on deployment:
- **D-DEL13.** On the strength of D-DEL13, 3.1.3 leaves `conflict_priority` and `permissions` out of the brief. Until the commander confirms D-DEL13, a delegation prompt MUST still carry those two `/delegate` prompt elements (6 and 7), as it does today.
- **D-DEL9 to D-DEL13.** These reach a delegate only once `aitools` deploys the updated `/delegate` and rule, and the deployed copy can lag the source. Until then, the delegation prompt restates the duties a delegate needs.

3.9.3. The working copy of those files still names the brief `<sid4>_<mission name>-brief.md` in Markdown, and does not yet say the hand-back is JSON. Plan WP-2 brings them in line with this RFC (D874d-49).

---

## 4. Settled by this RFC

Each point below is decided here, not by the commander, and is reviewed after (D-DEL5). S-18 and S-19 change the issue's item schema and are put to the commander as RFIs.

| ID | Point | Settled as | Why |
|---|---|---|---|
| S-1 | Where the schemas and templates live (issue AMB-2) | `reference/schemas/`, `reference/templates/`, `reference/structured-reports.md` (3.7.1) | `deploy-harness` already copies `reference/` to every machine, read-only |
| S-2 | Who updates the running estimate, and where it is kept (issue AMB-3) | The session agent, at each prompt turn and after each hand-back, once schema 5 ships; `intent`, `main_effort` and `assessment` in the `session` table (3.5.3) | The prompt-turn checklist already runs every turn; these three are not items |
| S-3 | Briefs for workflow delegates (issue AMB-5) | One brief per `agent()` call (3.3.6) | The delegation rule covers workflows; a workflow delegate cannot ask for what it was not given |
| S-4 | Changing an item (issue AMB-7) | Append a new version, key (`id`, `version`); readers take the latest (3.2.5) | Provenance is never deleted |
| S-5 | Type-specific fields (issue AMB-8) | One `fields` column of JSON text, parsed in Python (3.6.4) | Keeps the store independent of the SQLite build |
| S-6 | Validating documents (issue ASM-7) | A stdlib validator: the JSON Schema subset plus coded rules (3.7.2) | RFC 0010 section 2: stdlib only; JSON Schema cannot express all of the MUSTs |
| S-7 | Item ids in documents | Numbered from 1, or the copied record's ids (3.2.4) | Traceability to the issue's ASM and AMB ids |
| S-8 | Where a brief lists the mission's references | `rules[]` entries `{path, kind}`, with kind `rule` or `reference` (3.2.1a) | One reading list, with binding and non-binding files told apart |
| S-9 | Delegates confined to their worktree (ASM-3, ASM-4) | The brief goes in the delegating agent's own scratch and the AAR names it; the delegating agent records the delegate's missing items (3.3.8, 3.4.8) | `/delegate`: worktree isolation "confines writes to the worktree" |
| S-10 | Lock contention (ASM-2) | Agents retry three times, then exit 1 and record a blocker; hooks never retry; `ensure_schema` runs at session start only (3.6.6) | A locked DB fails loudly without stalling a hook |
| S-11 | Prefix collision (ASM-6) | Checked at session start; the colliding session uses its full id as the DB name (3.6.2) | No session is left without a DB |
| S-12 | Existing tables, verbs and readers | Views `observations`, `decisions` and `deviations` with v4 columns; each verb keeps or changes its store as 3.6.10 says (3.6.7) | Existing readers such as `intelligence-stop.py` keep working |
| S-13 | The old single export | Retired, with every reader repointed or updated (3.5.6) | Replaced by the per-session export and the dotprofile record |
| S-14 | Briefs, AARs and copies of the commander's words reaching a tracked path | The harvester treats `*-brief.json`, `*-aar.json` and `*.tmp` as ephemeral, and agents save copies of transcripts, prompts and issue bodies as `*.tmp` (section 7) | The harvester copies every other top-level scratch file into the tracked `harvesting/` of a public repo |
| S-15 | Removing `--session` | From the session-DB write verbs only, in the same change as the hooks; helper and hooks deploy together (3.6.9) | Elsewhere `--session` names a session in the cross-session DB |
| S-16 | Key order | Writers emit the spec's order; readers do not depend on it (3.1.5) | JSON objects are unordered |
| S-17 | The v4 to v5 mapping | The table in 3.6.7, every column and table accounted for | No v4 data is lost |
| S-18 | Writer fields of items inside a document | Inherited from `provenance`; required on every DB row (3.2.1) | A document has one writer and one time. Changes the issue's schema: R874d-30 |
| S-19 | A superseded decision | Status `superseded` and `superseded_by[]` (3.2.2) | The issue keeps superseded decisions as the record. Changes the issue's schema: R874d-31 |
| S-20 | Version skew between helper, hooks and DB | Version check first; migration only through the deployed v5 pair; a skipped deploy is a WARN (3.6.12) | A v4 helper crashes on a v5 DB (observed on a throwaway DB) |
| S-21 | The SessionEnd sequence | One detached job: export, copy, commit, push, with a lock and a rebase; catch-up recovers each step (3.5.5) | Two separate hooks have no order, and the SessionEnd window is 1.5 seconds |
| S-22 | `<repo>`, `<project>`, the record's date, spaces in paths | The recorded project root, its base name, the session's start date; no spaces in names the harness creates (section 2, 3.5.5, 3.8) | The working directory changes; the start date fits D874d-53's example |
| S-23 | Document ids against DB ids | The DB assigns new ids, keeps `fields.doc_id` and rewrites refs; delegates' RFIs are `R<mission name>-<n>` (3.2.4) | Parallel documents would collide |
| S-24 | Credentials in verbatim quotes | Replaced by `[redacted]`, the one permitted change (3.2.1) | The verbatim rule and the no-secrets rule otherwise conflict |
| S-25 | What a session is | One Claude Code session id; `/clear` starts a new one, `/resume` continues it (section 2) | SessionEnd fires on both |

---

## 5. Alternatives considered

| Alternative | Outcome |
|---|---|
| One JSON file per session as the store | Rejected: one JSON file cannot take parallel writers safely (R874d-1); SQLite is the store (D874d-35) |
| A table per agent | Rejected: tables would multiply with every delegate and queries would need unions; one table with `agent_id` (D874d-25, D874d-31) |
| A Markdown brief named `<sid4>_<mission name>-brief.md` | Replaced by `<mission name>-brief.json` (D874d-42) |
| An AAR file by default | Rejected: the AAR is the hand-back; a file only on request (D874d-47) |
| Mission commands that keep a `missions` table | Withdrawn: each delegate finds its own agentId (D874d-33); the brief file and the delegate's rows carry the rest |
| A `finding` type | Retired: what was acted on is a deviation, what was seen is an observation (D874d-22, D874d-28) |
| A list of conditions to report at once in each brief | Dropped: reporting a blocker at once is a standing duty (D874d-26) |
| A third-party JSON Schema validator | Rejected: stdlib only (RFC 0010 section 2) |
| Committing the export in the project repo | Rejected: the export stays untracked and the record goes to the dotprofile (D874d-52) |
| A deprecated `--session` alias for one release | Not adopted: D874d-31 drops the argument; skew is handled by S-20. Put to the commander as R874d-32 |

---

## 6. Cross-platform

- **`harness-db.py`:** standard library only. Its header requires Python 3.10 or later. RFC 0010 section 11 still says 3.8, and the code's floor wins. Hooks find Python as `python3`, then `python` (RFC 0010 section 6).
- **Hooks:** bash on every platform (`.claude/rules/cross-platform.md`, "Hook portability"). A hook MUST exit 0 when Python or the DB is missing (RFC 0010 section 8).
- **Paths:** the harness creates no names with spaces, and every script quotes the roots it is given (3.8).
- **The detached SessionEnd job** uses the same detachment as `session-archive.sh`. That it outlives Claude Code on Windows MUST be verified on Windows (plan batch 4.3), not assumed.
- **Finding a delegate's agentId:** verified for Claude Code only (D874d-33). In Claude Code web, delegates cannot delegate further (nesting depth 1), but briefs and AARs still apply. Cursor harnesses are to be examined.

---

## 7. Security and privacy

- **The aitools repo is public** (`gh repo view`: visibility PUBLIC). Briefs, AARs, running estimates and copies of transcripts, prompts and issue bodies carry the commander's words verbatim and the session's content. They MUST NOT be committed to a project repo.
- **The project-repo export stays untracked; the record goes to the commander's dotprofile** (D874d-52). The dotprofile already receives the full session transcripts (`ait-harvest.py archive`), so the record adds no new kind of exposure there.
- **Existing exposure.** Before this RFC, the single export `.aitools/channel/running-estimate.json` is tracked: last committed in `5d8fa521` (2026-11-15), holding one observation. `harvesting/` holds tracked files whose names show session content, among them prompts, AARs, briefs and issue bodies. Whether to stop tracking the export now, add ignore patterns, and treat the files already published is the commander's call (R874d-29). A history rewrite is destructive and is never done without his order.
- **Harvester (S-14).** The SessionEnd and SessionStart harvester copies every non-ephemeral top-level file of a session's scratch directory into the tracked `harvesting/`. Among `.json` files it exempts only `package-lock*`, `node_modules*`, `tsconfig*` and `*.config.json` (`ait-harvest.py` `_is_ephemeral`).
  - It MUST treat `*-brief.json`, `*-aar.json` and `*.tmp` as ephemeral.
  - Agents MUST save copies of transcripts, prompts and issue bodies under a `.tmp` name.
  - Until this ships, harvested copies of such files MUST NOT be committed.
- **Other repos.** The SessionStart hook creates `.aitools/` and `.scratch/` in whatever repo a session runs in. Outside aitools, nothing ignores them. Whether the harness adds both to that repo's `.git/info/exclude` is R874d-33.
- **No credentials.** Writers MUST NOT copy credentials or tokens into any item; a quote replaces them with `[redacted]` (S-24).

---

## 8. Implementation

The plan, `plans/structured-reports/implementation-plan.md`, splits the work into batches of two or three files, each with its verification:

| WP | What |
|---|---|
| WP-0 | This RFC, the plan, and the four verifiers' review (this change) |
| WP-1 | Reference, schemas, templates, and the `validate` verb |
| WP-2 | The harness text brought in line (D874d-49) |
| WP-3 | Session DB schema 5: migration, views, version skew, the hooks' switch to `--db` |
| WP-4 | Delegation-guard checks, the AAR check, the SessionEnd job, the harvester exclusion |
| WP-5 | The skills and readers that use the documents; the old export retired |
| WP-6 | Release, the glossary check, and the doctrine adoption through `/frameworks` |

The implementing mission's brief is `874d-2-structured-reports-brief.json` in the session scratch directory of session dbd05b0c. The mission launches only on the commander's order (D874d-45).

**Out of scope:**
- the `/debrief`, `/brief` and `/channel` skills (D874d-11);
- sharing estimates across sessions, and distributed sessions (D874d-9, D874d-10);
- harnesses other than Claude Code, beyond recording what is found when they are examined (D874d-33).

---

## 9. Open questions

These questions go to the commander, each as an RFI with a suggested answer:
- R874d-29: the existing exposure in the public repo (section 7);
- R874d-30: S-18;
- R874d-31: S-19;
- R874d-32: a `--session` alias;
- R874d-33: `.git/info/exclude` in other repos.

The other points of section 4 are open to the commander's review (D-DEL5).

---

## 10. References

- **Issue** nobul-tech/aitools#180, body v5.2: decisions D874d-1 to D874d-53 (section 1), naming (2), schema (3), store (4), assumptions and ambiguities (6), implementation (7). Comments: the commander's answers (2026-11-15), the March history, "Doctrine behind the design", "Answers recorded".
- **RFCs:** 0005-v2 (session intelligence), 0006 (delegation, P1 briefing-first), 0010 (Python and SQLite engineering).
- **Harness:** `shared/rules/delegation.md`, `shared/skills/delegate/SKILL.md`, `reference/framework-intelligence-types.md`, the glossary (`/glossary`), `reference/prompt-turn-checklist.md`, `reference/tool-ops-claude-code.md` (item #35).
- **Code:** `scripts/harness-db.py`, `scripts/ait-harvest.py`, `scripts/generate-dashboard.py`, `shared/hooks/harness-db-sessionstart.sh`, `harness-db-sessionend.sh`, `session-archive.sh`, `session-catchup.sh`, `intelligence-stop.py`, `dashboard-serve.sh`, `delegation-duty-guard.sh`, `workflow-delegation-guard.sh`.
- **Verifiers' reports** (session dbd05b0c, 2026-11-16), as AAR files in the session scratch directory: `874d-3-spec-verify-aar.json`, `874d-4-adversarial-aar.json`, `874d-5-brief-verify-aar.json`, `874d-6-standards-verify-aar.json`.
- **Doctrine:** TC 7-0.1 (2025), ADP 5-0 (2019), FM 5-0 (2024), ADP 6-0 (2026), FM 6-99 (2021), AR 11-33 (2022); report of mission 874d-1-aar-doctrine.

---

## Appendix A. Where each decision is carried

Every decision of issue #180 section 1. "Superseded" means a newer decision replaced it, in whole or in part. "Session only" means it governed the session's own work, not the implementation.

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
| D874d-13 | 3.2.2, 3.3.5, 3.4.4, 3.9.1 | |
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
| D874d-26 | 3.1.3, 3.3.7 | |
| D874d-27 | 3.3.5, 3.9.1 | |
| D874d-28 | 3.2.1, 3.6.7 | |
| D874d-29 | 3.1.4, 3.2.3, 3.4.5 | |
| D874d-30 | 3.2.2 (`deliverables`; no `artifact_refs`) | Plan batch 2.2 governs the node and item-type names |
| D874d-31 | 3.6.3, 3.6.5, 3.6.9 | |
| D874d-32 | 3.1.3, 3.3.4 | |
| D874d-33 | 3.4.9, section 6, section 8 | |
| D874d-34 | 3.2.2 | |
| D874d-35 | 3.5.1, 3.6 | |
| D874d-36 | 3.3.1 (location) | Name and format superseded by -42 |
| D874d-37 | section 2 | |
| D874d-38 | | Session only (the session's `/delegate` changes) |
| D874d-39 | | Superseded by -41 |
| D874d-40 | | Session only |
| D874d-41 | 3.2.4, 3.8 | |
| D874d-42 | 3.3.1, 3.8 | The AAR file part superseded by -47 |
| D874d-43 | 3.2.1, 3.2.2, 3.6.7 | |
| D874d-44 | 3.5.5, 3.6.1 | The export is untracked (-52) |
| D874d-45 | section 8 | |
| D874d-46 | | Session only (issue v4.1) |
| D874d-47 | 3.4.1, 3.4.7 | |
| D874d-48 | 3.6.1 | |
| D874d-49 | 3.9.3, section 8 (WP-2) | |
| D874d-50 | 3.4.1 | |
| D874d-51 | 3.5.5 | |
| D874d-52 | 3.5.5, section 7 | |
| D874d-53 | 3.5.5, 3.8 | |
