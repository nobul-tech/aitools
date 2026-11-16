# defects.py -- the defect table of mission 874d-7-normative-language.
# Each entry: lines (first, last), sev, char (characteristics or rules violated),
# text (the defect), old (exact RFC text, "<LINE>" = whole line), new, why, barrier.
# build-aar.py reads this table, checks every old text against the RFC on disk,
# and writes the AAR.

D = []

def d(lines, sev, char, text, old, new, why, barrier):
    if isinstance(lines, int):
        lines = (lines, lines)
    D.append(dict(lines=lines, sev=sev, char=char, text=text, old=old, new=new, why=why, barrier=barrier))

# ---------------------------------------------------------------- high
d(100, "high", "RFC 8174; unambiguous",
  "The requirements-language clause adopts RFC 2119 without the RFC 8174 clarification, so the lowercase must, may and required at lines 71, 145, 180, 270, 339, 345, 529, 530 and 549 can each be read as a requirement or as ordinary English; the clause also omits NOT RECOMMENDED.",
  "<LINE>",
  '- **Requirements language.** The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in BCP 14 ([RFC 2119](https://www.rfc-editor.org/rfc/rfc2119), [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174)) when, and only when, they appear in all capitals, as shown here. In lowercase, these words have their ordinary English meaning.',
  'RFC 8174 section 2 (read 2026-11-16 at https://www.rfc-editor.org/rfc/rfc8174.txt): "The words have the meanings specified herein only when they are in all capitals." and "When these words are not capitalized, they have their normal English meanings and are not affected by this document." Its prescribed phrase includes "NOT RECOMMENDED" and cites BCP 14 [RFC2119] [RFC8174].',
  "Yes: with the RFC 8174 phrase, a lowercase keyword is unambiguously ordinary English, so every remaining requirement must carry an uppercase keyword to bind.")

d(529, "high", "RFC 8174; unambiguous; verifiable",
  "A prohibition that protects live session DBs is written with a lowercase 'may', which RFC 8174 gives its ordinary meaning (permission), the opposite of the intent; 'live session DB' is also undefined, so a test cannot tell which files are protected.",
  "- no repo or worktree copy of `harness-db.py` may open a live session DB: tests and probes use throwaway DBs;",
  "- a repo or worktree copy of `harness-db.py` MUST NOT open a session DB under any `<repo>/.aitools/sessions/` directory; tests and probes MUST use throwaway DBs outside that directory;",
  "RFC 2119 section 2: MUST NOT means 'an absolute prohibition'; 3.6.12 states a v4 helper crashes on a v5 DB, so the prohibition is safety-relevant. The directory makes the rule testable.",
  "Yes: a reader could no longer read the line as a permission, and a probe could check the path it opens.")

d(153, "high", "consistent; correct; verifiable",
  "'MUST carry these common fields' contradicts the same section: severity is OPTIONAL (line 169), quote is REQUIRED only when source.kind is commander (line 167), and items in a brief or an AAR MAY omit five of the fields (line 173). A validator built from line 153 rejects conforming documents.",
  "Every entry of an item node is an item, and MUST carry these common fields:",
  "Every entry of an item node is an item. A writer MUST give every item each common field below, except a field marked OPTIONAL, a field marked REQUIRED under a condition that does not hold, and the fields a brief or an AAR inherits from `provenance` (second bullet below):",
  "Requirements in one section must not contradict each other (29148 characteristic 'consistent', as named in the brief).",
  "Yes: the validator's `required` list follows from the corrected text without contradiction.")

d(173, "high", "complete; correct",
  "Items 'inherit' version, agent_id, agent_type, mission and created_at from provenance, but provenance has no matching fields: provenance.version is the document version string 'v1.0' (line 328), not an item version integer (line 160); the AAR provenance has no agent_type (line 381); the brief records the writer under written_by (line 333). The inheritance rule cannot be implemented as written.",
  "In a brief or an AAR, an item MAY omit `version`, `agent_id`, `agent_type`, `mission` and `created_at`; it inherits them from the document's `provenance`.",
  "In a brief or an AAR, an item MAY omit `version`, `agent_id`, `agent_type`, `mission` and `created_at`. A reader MUST then take `version` as 1, `created_at` from `provenance.created_at`, and `agent_id`, `agent_type` and `mission` from `provenance.written_by` (brief) or from `provenance.agent_id` and `provenance.mission`, with `agent_type` `delegate` (AAR).",
  "A requirement must be complete: it must state every value a reader derives. The mapping removes the type clash between provenance.version and item version.",
  "Yes: 3.4.8's import of AAR items into the DB needs exactly this mapping.")

d(187, "high", "complete; verifiable",
  "The type-specific fields carry no obligation status: except objective.source (REQUIRED, line 192), nothing says which fields are required, which are conditional (ref, answer, superseded_by) and which list fields may be empty. The JSON Schema files (3.7.1) and the validator's `required` check (3.7.2) cannot be derived from the text.",
  "3.2.2. The type-specific fields are:",
  '3.2.2. The type-specific fields are listed below. Every listed field is REQUIRED, except a field marked OPTIONAL and a field whose line states when it is present (for example `ref`, "once verified or falsified", and `answer`, "once answered"); a list field (`[]`) MAY be empty. The fields listed under "in an AAR or a running estimate" MUST NOT appear in a brief.',
  "Each requirement must be verifiable; a field whose presence is unspecified cannot be checked. The session agent should then mark OPTIONAL any field it does not want required (for example how, when D874d-23's 'and/or' is applied).",
  "Yes: the schema writers in WP-1 would have one rule instead of guessing per field.")

d(371, "high", "consistent; feasible",
  "'the objective it affects MUST say so' requires the delegating agent to add to an objective, but an objective's text is verbatim from the delegation prompt (line 191, D-DEL8, D874d-13). The two requirements cannot both be met.",
  "3.3.7. A blocker the delegating agent already knows at launch MUST be written as a constraint or in the prompt body, and the objective it affects MUST say so.",
  "3.3.7. When the delegating agent knows of a blocker at launch, it MUST state the blocker as a constraint or in the prompt body, and MUST name there each objective the blocker affects, by its `OBJ` id; it MUST NOT add to an objective's verbatim text (3.2.2).",
  "Names the actor (passive 'be written' hid it) and removes the conflict with the verbatim rule.",
  "Yes: a delegating agent could not be led to edit a commander's verbatim objective.")

d(385, "high", "unambiguous; consistent",
  "'not accomplished' is both a status value and an English phrase: it is unclear whether an objective with status `partly` must cite a deviation. 3.4.6 (line 398-399) requires a deviation for a blocker whether the status is `partly` or `not accomplished`, and the validator rule (line 550) repeats the ambiguity.",
  "- An objective that is not accomplished MUST cite the deviation that explains it.",
  "- An objective whose `status` is `partly` or `not accomplished` MUST cite in `deviation_refs` at least one deviation that explains the shortfall.",
  "Uses the enum values literally (code font) so the requirement has one reading; aligned with 3.4.6.",
  "Yes: the validator and the delegate apply the same rule.")

# ---------------------------------------------------------------- medium
d(550, "medium", "unambiguous; consistent",
  "The validator rule repeats the ambiguity of line 385 ('not accomplished' as status or as English).",
  "  - an objective that is not accomplished cites a deviation;",
  "  - an objective whose `status` is `partly` or `not accomplished` cites at least one deviation in `deviation_refs`;",
  "Must match 3.4.4 as corrected.",
  "Yes: validator and specification agree.")

d(412, "medium", "feasible; consistent",
  "'A delegate MUST find its own agentId' is an absolute requirement the RFC itself expects to fail: line 417 provides a fallback 'when a delegate could not find its own (ASM-1)'. A MUST that is violated by design is not feasible, and 'find' is not verifiable; what can be checked is the recorded value.",
  "3.4.9. A delegate MUST find its own agentId by one of these methods (D874d-33):",
  "3.4.9. A delegate MUST write its own agentId in `provenance.agent_id` when it can find it. It SHOULD try these methods (D874d-33); when none yields the id, it MUST leave `provenance.agent_id` empty and record that in an observation:",
  "RFC 2119: MUST is 'an absolute requirement'; the fallback shows departure is expected, which is SHOULD.",
  "Yes: an AAR without an agentId becomes conforming and detectable, not a silent violation.")

d(417, "medium", "verifiable; passive voice",
  "'That id fills agent_id' hides who fills it, and 'other harnesses ... MUST be examined before they are relied on' names no actor and no observable result.",
  "That id fills `agent_id` when a delegate could not find its own (ASM-1). This holds for the Claude Code harness; other harnesses (Claude Code web, Cursor CLI, Cursor cloud agents) MUST be examined before they are relied on (D874d-33).",
  "When a delegate could not find its own agentId, the delegating agent MUST fill `agent_id` with the id it recorded (ASM-1). These methods are verified for the Claude Code harness only; an implementer MUST NOT rely on them in another harness (Claude Code web, Cursor CLI, Cursor cloud agents) until it has tested them there and recorded the result (D874d-33).",
  "Active voice with a named actor; 'tested and recorded' is inspectable.",
  "Yes.")

d(121, "medium", "correct; verifiable",
  "'Every node and every item type is defined once, in this section' is incorrect: the item types and their fields are defined in 3.2 (lines 153-260), not in 3.1. 'MUST mean the same thing' names no actor and no check.",
  "3.1.1. The mission brief, the AAR and the running estimate MUST share one schema. Every node and every item type is defined once, in this section, and MUST mean the same thing in every document that uses it.",
  "3.1.1. The mission brief, the AAR and the running estimate MUST share one schema. The schema files (3.7.1) MUST define each node and each item type once, and every document that uses a node or an item type MUST give it the fields and meaning that sections 3.1 and 3.2 define.",
  "Correct cross-reference; the schema files are the inspectable artifact.",
  "Yes.")

d(145, "medium", "singular; RFC 8174",
  "3.1.3 packs about twelve statements into one paragraph with no key word: it is unclear whether it adds requirements beyond 3.1.2 or only records rationale, and it uses lowercase 'must' twice ('what the delegate must or must not do').",
  "<LINE>",
  "3.1.3. The table in 3.1.2 does not mark the following nodes, so 3.1.2 prohibits them; this paragraph records the decisions that removed them. No document has a `facts` (D874d-32), `report_at_once_if` (D874d-26), `meta` (D874d-19) or `findings` (D874d-22) node. A mission brief also has no `conflict_priority` and no `permissions` node, because `/delegate` documents the standing duties (D874d-64); no `rules` and no `skills` node, which `artifacts` replaces (D874d-65); and no `ambiguities`, `access`, `name_prefix`, `duties` or `return` node (D874d-70). The content of the removed brief nodes is carried elsewhere: an ambiguity the delegating agent resolved before launch is a decision or a constraint; the scratch directory, the paths the delegate is permitted to write, the sources that are not files and the name prefix (D-DEL1) are in the delegation prompt (3.3.5); an action the delegate is required or forbidden to take is a constraint; and what the delegate returns is a deliverable.",
  "States that the paragraph is informative and the requirement is 3.1.2; removes lowercase must.",
  "Yes: an implementer would not look for extra obligations here.")

d(174, "medium", "passive voice; actor",
  "'Such a passage is copied with the secret replaced' hides who copies and who redacts; 'token' is ambiguous (an access token or an LLM token).",
  "- A quote MUST NOT carry a credential or a token. Such a passage is copied with the secret replaced by `[redacted]`, the one permitted change to a verbatim quote. *Settled by this RFC (S-24).*",
  "- A writer MUST NOT copy a credential or an access token into a `quote`. When a quoted passage contains one, the writer MUST replace the secret with `[redacted]`; this is the only change a writer MAY make to a verbatim quote. *Settled by this RFC (S-24).*",
  "Names the actor and makes the redaction itself a MUST.",
  "Yes.")

d(222, "medium", "complete; RFC 8174",
  "'(an open one is also an rfi)' states an obligation (write an rfi item) without a key word or an actor.",
  "  status             resolved | open                 (an open one is also an rfi)",
  "  status             resolved | open      (for an open ambiguity, the writer MUST also write an rfi item)",
  "Hidden obligations are not verifiable.",
  "Yes.")

d((230, 232), "medium", "feasible; consistent",
  "A verified assumption's ref 'points to a fact', but no document has a facts node (D874d-32, line 145, 234-235): in a brief or an AAR the ref cannot be satisfied.",
  "  ref                (once verified or falsified) what settled it: a verified assumption\n                     points to a fact ('validated'), a falsified one to the contradicting\n                     observation ('invalidated'); the glossary's lifecycle (D874d-43)",
  "  ref                (once verified or falsified) the id of the item that settled it: for a\n                     falsified assumption, the contradicting observation ('invalidated'); for\n                     a verified assumption, a fact in the session DB ('validated'). A brief or\n                     an AAR has no facts node (3.1.3), so there `ref` MAY be empty and\n                     `evidence` carries the support; the glossary's lifecycle (D874d-43)",
  "A requirement must be feasible in every document it applies to.",
  "Yes: an AAR writer would otherwise invent a FACT id that resolves nowhere.")

d((243, 244), "medium", "RFC 8174; actor",
  "The rule for a partly superseded decision is normative but has no key word and no actor.",
  "                     status is superseded only when the whole decision is; a decision\n                     superseded in part keeps its status and names the part",
  "                     a writer MUST set status to superseded only when the whole decision\n                     is superseded; for a decision superseded in part, it MUST keep the\n                     status and MUST name the part in superseded_by[].part",
  "Makes the obligation explicit and testable.",
  "Yes.")

d(276, "medium", "unambiguous; passive voice; vague term",
  "'A blocker is reported at once' is passive (who reports?) and 'at once' is vague (before what? in what channel?). The same phrase recurs at lines 390 and 403.",
  "| `blocker` | The given course could not be followed. A blocker is reported at once (D-DEL9); a denied write is one |",
  "| `blocker` | The given course could not be followed; a denied write is a blocker. The agent that meets a blocker MUST report it, with a recommended course of action, as soon as it meets it, not only in its AAR (D-DEL9) |",
  "Names the actor and turns 'at once' into a checkable timing (before the AAR). The channel remains unstated: see the observation on the report channel.",
  "Partly: the timing becomes checkable; the channel still needs a decision.")

d(281, "medium", "RFC 8174; unambiguous",
  "'the writer numbers its items from 1' is normative without a key word, and 'from 1' does not say whether numbering is per type or across the document.",
  "- In a document, the writer numbers its items from 1. It MAY instead keep the ids of the record it copies them from, such as the issue's `ASM-<n>`, for traceability.",
  "- In a document, the writer MUST number the items of each type consecutively from 1 (`OBS-1`, `OBS-2`, ...), except that it MAY keep the ids of the record it copies items from, such as the issue's `ASM-<n>`, for traceability.",
  "Removes the 'per type or per document' ambiguity.",
  "Yes.")

d(282, "medium", "RFC 8174; actor",
  "'the DB assigns new ids, keeps ... and rewrites' states three obligations of harness-db.py without key words; 'the DB' is not an actor.",
  "- When a document's items are written into the DB (3.4.8), the DB assigns new ids, keeps the document's id in `fields.doc_id`, and rewrites the document's refs to the new ids.",
  "- When a document's items are written into the DB (3.4.8), `harness-db.py` MUST assign each a new id, MUST keep the document's id in `fields.doc_id`, and MUST rewrite the document's refs to the new ids.",
  "Each obligation becomes a separate, testable MUST on a named component.",
  "Yes.")

d(283, "medium", "RFC 8174; actor",
  "Delegate RFI numbering and the session agent's renumbering are normative but have no key words.",
  "- A delegate cannot see the session's RFI counter, so it numbers its RFIs `R<mission name>-<n>`. The session agent renumbers them into `R<sid4>-<n>` when it raises them.",
  "- A delegate MUST number its RFIs `R<mission name>-<n>`, because it cannot read the session's RFI counter. The session agent MUST renumber each one to `R<sid4>-<n>` when it raises it to the commander.",
  "Explicit obligations for both actors.",
  "Yes.")

d(285, "medium", "unambiguous; consistent",
  "'Writers MUST NOT change an item in place' does not say whether it applies to documents: a brief in the briefs directory is changed by writing a new document version (line 316), and items in a brief or an AAR may omit version (line 173). The bullets ('The key of an item row') show the rule is about DB rows. 'A change appends' hides the actor and the version arithmetic.",
  "3.2.5. Writers MUST NOT change an item in place, because provenance is never deleted (\"provenance is eternal\", the commander, 2026-03-30). A change appends a new version of the item:",
  "3.2.5. In the session DB, a writer MUST NOT change an item row in place, because provenance is never deleted (\"provenance is eternal\", the commander, 2026-03-30). A writer that changes an item MUST insert a new row with the same `id` and a `version` one greater than the item's latest version. A brief or an AAR is changed by writing a new version of the whole document (D-DEL5):",
  "Scopes the rule; the commander's quotation is kept verbatim.",
  "Yes.")

d(288, "low", "RFC 8174",
  "'Every reader ... reads the latest version' is normative without a key word.",
  "- Every reader, including the export, `aar`, the compatibility views (3.6.7) and the derived `missions[]`, reads the latest version of each id.",
  "- Every reader, including the export, `aar`, the compatibility views (3.6.7) and the derived `missions[]`, MUST read only the latest version of each id.",
  "Testable: insert two versions and check the reader's output.",
  "Yes.")

d(305, "medium", "RFC 8174; consistent",
  "'Every brief lists the AAR as a deliverable' has no key word, and does not say 'exactly one', which the validator requires (line 555).",
  "Every brief lists the AAR as a deliverable (`kind` `aar`): the hand-back, JSON in the AAR schema in one fenced block, and the file only when its `ref` names one (D874d-47, D874d-50).",
  "Every brief MUST list exactly one deliverable of `kind` `aar` (D874d-47, D874d-50). That deliverable is the hand-back, JSON in the AAR schema in one fenced block (3.4.1), and also a file when its `ref` names one (3.4.7).",
  "Aligns 3.2.6 with 3.7.2.",
  "Yes.")

d(310, "medium", "passive voice; consistent",
  "'the brief MUST be written to' hides the actor, and the MUST conflicts with 3.3.8 (line 373), which sends a confined delegating agent's brief to its own scratch directory, without referring to it.",
  "- **Default.** Unless the commander orders otherwise, the brief MUST be written to `<session scratch dir>/<mission name>-brief.json` (D874d-36, D874d-42, D874d-73).",
  "- **Default.** Unless the commander orders otherwise, the delegating agent MUST write the brief to `<session scratch dir>/<mission name>-brief.json` (D874d-36, D874d-42, D874d-73), except as 3.3.8 provides for a delegating agent confined to its worktree.",
  "Names the actor and the exception in one place.",
  "Yes.")

d(311, "medium", "RFC 8174; SHOULD without exception; vague",
  "'belongs in the briefs directory' is not normative; 'An agent that writes a brief whose mission will outlive the session' requires a prediction; the SHOULD gives no case where departing is acceptable; a delegate cannot raise a session RFI (it raises R<mission name>-<n>, 3.2.4).",
  "<LINE>",
  "- **Long lifecycle.** The briefs directory, `<repo>/briefs/`, tracked in git as plans are, holds the briefs of missions that outlive the session that wrote them, such as a mission that implements a roadmap item (D874d-72, D874d-74). An agent MUST NOT write a brief to `<repo>/briefs/<mission name>-brief.json` without the commander's order, and on his order it MUST write the brief there (D874d-73). A delegating agent that expects a mission to outlive its session SHOULD ask the commander to order that placement, in a session RFI (a delegate: in an RFI of its AAR, 3.2.4); it MAY omit the request when the commander has already ruled on that brief's placement.",
  "RFC 2119 section 3: SHOULD means 'there may exist valid reasons in particular circumstances to ignore a particular item'; the replacement names that circumstance.",
  "Yes.")

d(316, "medium", "consistent; passive voice",
  "'committed and pushed to `main`' sets a direct-to-main path for `briefs/` that the project CLAUDE.md 'Channel exception' does not list (it lists handoffs, relay.md, plans and CLAUDE.md; 'Everything else uses a worktree and a PR'). The commander's words 'add briefs to git, plans too' (L4045) do not settle the shipping path. The sentence is also passive.",
  "- It is versioned (D-DEL5): each change is a new version, committed and pushed to `main`.",
  "- The agent that changes it MUST write each change as a new version (D-DEL5), commit it, and push it to `main` directly, as plans are, once `briefs/` is listed in the CLAUDE.md \"Channel exception\"; until then the change reaches `main` through a PR.",
  "Removes the conflict with a standing project rule; the listing itself is the commander's choice (RFI R874d-7-normative-language-1).",
  "Yes: an agent would not push to main against CLAUDE.md on the RFC's authority.")

d(320, "medium", "complete; unambiguous",
  "'with these top-level keys' does not say whether the set is exact or whether a key with no entries is present as [] or omitted; the validator needs one answer.",
  "3.3.2. The brief MUST be one JSON object with these top-level keys: ",
  "3.3.2. The brief MUST be one JSON object whose top-level keys are exactly these, each present even when its list is empty (`[]`): ",
  "Makes the shape testable.",
  "Yes.")

d(379, "medium", "complete; unambiguous",
  "Same as line 320, for the AAR.",
  "3.4.2. The AAR MUST be one JSON object with these top-level keys: ",
  "3.4.2. The AAR MUST be one JSON object whose top-level keys are exactly these, each present even when its list is empty (`[]`): ",
  "Makes the shape testable.",
  "Yes.")

d(423, "medium", "complete; unambiguous",
  "Same as line 320, for the running estimate export.",
  "3.5.2. Its export MUST be one JSON object with these top-level keys: ",
  "3.5.2. Its export MUST be one JSON object whose top-level keys are exactly these, each present even when its list is empty (`[]`): ",
  "Makes the shape testable.",
  "Yes.")

d(332, "medium", "correct",
  "'(every brief lives there)' is false: a long-lifecycle brief lives in the briefs directory (3.3.1) and a confined delegating agent's brief in its own scratch (3.3.8).",
  "  session_scratch    the top-level session's scratch directory (every brief lives there)",
  "  session_scratch    the top-level session's scratch directory",
  "Removes an incorrect statement introduced before v1.3.",
  "Yes.")

d((343, 344), "medium", "feasible; RFC 8174",
  "'the delegate verifies or falsifies each' is a hidden obligation that cannot always be met; 3.4.2 lets an assumption end unverified.",
  "assumptions[]        assumption items: what the delegating agent assumes; the delegate\n                     verifies or falsifies each",
  "assumptions[]        assumption items: what the delegating agent assumes; the delegate\n                     MUST report each one's end state (verified, falsified or unverified)\n                     in its AAR (3.4.2)",
  "A feasible, inspectable obligation.",
  "Yes.")

d(354, "medium", "RFC 8174; actor",
  "3.3.3a says what artifacts[] 'lists' but never obliges the delegating agent to list every file. Evidence that the gap matters: this mission's brief omitted ten project rules that the delegation rule requires (correction from the session agent during this mission).",
  "3.3.3a. `artifacts[]` lists every file the delegate needs, one entry per file, by absolute path, each with an explicit instruction (D874d-65):",
  "3.3.3a. The delegating agent MUST list in `artifacts[]` every file the delegate needs, one entry per file, by absolute path, and MUST give each entry the instruction that its category below names (D874d-65):",
  "A MUST with an actor makes an omission a detectable defect.",
  "Yes: the omission in this mission's brief would have been a checkable violation.")

d(356, "medium", "RFC 8174; vague",
  "'never loads them whole' is normative without a key word; 'when a question comes up' is vague.",
  "The delegate searches these when a question comes up and never loads them whole.",
  "The delegate MUST NOT read such a file whole; it searches the file when it needs an answer the file can give.",
  "Explicit prohibition.",
  "Yes.")

d(360, "medium", "verifiable; actor",
  "'Only structured content goes in the brief' cannot be checked: every brief field holds free text, so 'structured' and 'unstructured' have no test. The actor is hidden.",
  "3.3.4. Only structured content goes in the brief. Anything unstructured, such as facts or background, MUST go in the body of the delegation prompt, outside the brief (D874d-32, D-DEL12).",
  "3.3.4. The delegating agent MUST put in the brief only content that fits a node and an entry defined in 3.3.3, and MUST put any other content, such as facts or background, in the body of the delegation prompt, outside the brief (D874d-32, D-DEL12).",
  "Replaces a vague criterion with one an inspector can apply.",
  "Yes.")

d(379, "medium", "correct; unambiguous",
  "'The first three' of the AAR's keys are provenance, objectives and ambiguities; provenance does not answer 'what was supposed to happen'. The intended nodes are unknown to this reviewer (the TC 7-0.1 mapping was not read).",
  "The first three answer \"what was supposed to happen\" (TC 7-0.1, 2025, 3-2 and 3-7).",
  "`objectives`, `ambiguities` and `assumptions` answer \"what was supposed to happen\" (TC 7-0.1, 2025, 3-2 and 3-7).",
  "Name the nodes. The session agent should confirm the intended set against the 874d-1 doctrine report.",
  "Yes.")

d(384, "medium", "unambiguous; RFC 8174",
  "'Each objective gives `how`, cites deviations or observations, or both' has no key word and garbles D874d-23, which reads 'cite findings/observations and/or provide brief summary on the how': the commander's 'or both' joins the citation and the how, not deviations and observations.",
  "- Each objective gives `how`, cites deviations or observations, or both (D874d-23).",
  "- Each objective MUST give `how`, or cite at least one deviation or observation, or both (D874d-23).",
  "Matches D874d-23 (issue #180 section 1) and makes it a requirement.",
  "Yes.")

d(387, "medium", "RFC 8174; actor",
  "Recording an unread 'read in full' artifact as a deviation is normative without a key word or an actor.",
  "- An artifact whose instruction is `read in full` and that the delegate did not read in full is a deviation, `from.kind` `brief`.",
  "- The delegate MUST record as a deviation, `from.kind` `brief`, each artifact whose instruction is `read in full` that it did not read in full.",
  "Explicit obligation.",
  "Yes.")

d(389, "medium", "RFC 8174; actor",
  "'fold into these nodes' describes a mapping the delegate must apply but states no obligation.",
  "3.4.5. The free-text lines of the old hand-back fold into these nodes (D874d-29, D-DEL11):",
  "3.4.5. The delegate MUST record what the old hand-back carried as free-text lines in these nodes (D874d-29, D-DEL11):",
  "Explicit obligation over the four bullets.",
  "Yes.")

d(397, "medium", "correct; RFC 8174",
  "'records it in four places' is incorrect: two of the four bullets are conditional ('if a wrong assumption caused it', 'if only the commander can clear it'); the paragraph also has no key word.",
  "3.4.6. When a blocker stops an objective, the AAR records it in four places:",
  "3.4.6. When a blocker stops an objective, the delegate MUST record it in its AAR as follows, the last two only when their conditions hold:",
  "Correct count; explicit obligation.",
  "Yes.")

d(403, "medium", "passive voice; vague",
  "'The blocker was also reported at once' is a past-tense passive statement of a requirement; 'at once' is vague (see line 276).",
  "The blocker was also reported at once, with a recommended course of action (D-DEL9).",
  "The delegate MUST also have reported the blocker when it met it, with a recommended course of action (D-DEL9; 3.2.3).",
  "Named actor; ties the timing to 3.2.3.",
  "Yes.")

d(405, "medium", "unambiguous; passive voice",
  "'An AAR file is written only when one is requested' hides the actor, and the fixed path conflicts with 'the brief's AAR deliverable names it in ref': if ref names another path, which wins?",
  "3.4.7. An AAR file is written only when one is requested: the brief's AAR deliverable names it in `ref` (3.2.6). It then MUST be the same JSON, at `<session scratch dir>/<mission name>-aar.json` (D874d-47).",
  "3.4.7. A delegate MUST write an AAR file if, and only if, the `ref` of the brief's `aar` deliverable names a file (3.2.6). The file MUST hold the same JSON as the hand-back. A delegating agent that requests a file MUST name `<session scratch dir>/<mission name>-aar.json` in that `ref` (D874d-47).",
  "Each actor gets one obligation; the path conflict disappears.",
  "Yes.")

d(408, "medium", "vague; consistent",
  "'written by the delegate as it works' is vague timing, and the MUST does not refer to the exception in the third bullet (line 410).",
  "- every item of the AAR MUST also be a row in the session DB, written by the delegate as it works;",
  "- the delegate MUST write every item of its AAR as a row in the session DB when it records the item, not at hand-back, except as the third item of this list provides;",
  "Testable timing; the exception is referenced.",
  "Yes.")

d(438, "medium", "unambiguous; verifiable",
  "'MUST update ... at each prompt turn' does not say whether an unchanged value is rewritten; with version_history kept, the two readings produce different DB contents.",
  "3.5.3. Once schema 5 ships, the session agent MUST update `intent`, `main_effort`, `assessment` and the session's `objectives` at each prompt turn and after each hand-back.",
  "3.5.3. Once schema 5 ships, the session agent MUST review `intent`, `main_effort`, `assessment` and the session's `objectives` at each prompt turn and after each hand-back, and MUST write each one whose value has changed.",
  "One reading; inspectable through version_history.",
  "Yes.")

d(428, "medium", "unambiguous; complete",
  "'intent ... ; main_effort' does not say where main_effort sits in the export: 3.5.2's key list has no main_effort key, so it is presumably a field of intent, but the text does not say so.",
  "intent               the commander's intent for the session; main_effort",
  "intent               the commander's intent for the session, with its main_effort as a field",
  "One reading for the schema writer.",
  "Yes.")

d(443, "medium", "unambiguous; RFC 8174",
  "'no writer writes it' is a prohibition without a key word, and 'one entry per' brief file, briefs-directory brief and AAR brief path double-counts a mission whose brief is found two ways (a scratch brief also named in its AAR's provenance.brief).",
  "<LINE>",
  "3.5.4. `missions[]` MUST be derived on export (`harness-db.py export`); writers MUST NOT write it. It has exactly one entry per distinct mission name found among: the `<mission name>-brief.json` files in the session scratch directory, the briefs in the briefs directory whose `provenance.session_id` is the session's id (3.3.1a), and the brief paths named in a delegate's AAR `provenance.brief` (3.3.8). Each entry carries the `agent_id` and the objectives' status found on that mission's rows (latest versions, 3.2.5).",
  "Removes double counting; explicit prohibition.",
  "Yes.")

d(457, "medium", "passive voice; vague; singular",
  "3.5.6 mixes a MUST with passive statements ('is repointed ... or updated', 'are removed') and the vague 'Nothing is done earlier'; the MUST's timing ('stop writing') is only given two sentences later.",
  "<LINE>",
  "3.5.6. When the SessionEnd hook switches to the per-session export (plan WP-3), it MUST stop writing the single `.aitools/channel/running-estimate.json`. That file and `.aitools/templates/mission-running-estimate.json` are retired (S-13). The implementer MUST repoint to the per-session export, or update, every reader and description of the old file: `scripts/generate-dashboard.py`, `scripts/aitools-dashboard.sh/.ps1`, `shared/hooks/dashboard-serve.sh`, the `/mission-control` and `/aitool-continue` skills, `.claude/rules/aitools-workspace.md` and `reference/artifact-harvesting.md` (D874d-61). The implementer MUST remove the tracked file and its template in plan WP-5, and MUST take no earlier action on the copy already published (D874d-54).",
  "Each obligation gets an actor and a time.",
  "Yes.")

d(490, "medium", "verifiable; vague; RFC 8174",
  "'retries up to three times with backoff' leaves backoff unspecified, so a test cannot check it; the CLI's and the agent's obligations have no key words.",
  "- **Agents:** when a write still fails with \"database is locked\" after the busy timeout, the CLI retries up to three times with backoff, then exits 1 with the error. The agent then records the failed write as a deviation with cause `blocker`.",
  "- **Agents:** when a write still fails with \"database is locked\" after the busy timeout, `harness-db.py` MUST retry it up to three times, waiting longer before each retry (the delays are stated in its `--help`), and then MUST exit 1 with the error. The agent MUST then record the failed write as a deviation with cause `blocker`.",
  "Testable retry behaviour; the delays stay an implementation choice but become documented.",
  "Yes.")

d(511, "medium", "RFC 8174; passive voice",
  "Shipping order, joint deployment and 'no deprecated alias' are requirements without key words.",
  "The removal ships in the same change as the hooks' switch, and the helper and hooks deploy together (3.6.12). There is no deprecated alias (D874d-57).",
  "The removal MUST ship in the same change as the hooks' switch to `--db`, and `aitools` MUST deploy the helper and the hooks together (3.6.12). There MUST NOT be a deprecated `--session` alias (D874d-57).",
  "Explicit requirements, D874d-57 unchanged.",
  "Yes.")

d(524, "medium", "unambiguous; passive voice",
  "'Until schema 5 ships, nothing is written' is passive, and 'ships' is undefined: merged to main, deployed by aitools on this machine, or this session's DB migrated? Lines 407, 438 and S-2 use the same undefined event.",
  "3.6.11. Until schema 5 ships, nothing is written to the DB for these documents.",
  "3.6.11. Until schema 5 ships (section 2), agents MUST NOT write the items of these documents to the DB.",
  "Explicit prohibition; 'ships' defined in section 2 (next defect).",
  "Yes.")

d(113, "medium", "unambiguous; complete",
  "The event 'schema 5 ships', on which 3.4.8, 3.5.3, 3.6.11 and S-2 depend, is not defined in section 2.",
  "<LINE>",
  "<LINE>\n- **Schema 5 ships:** `aitools` has deployed, on the machine where the session runs, a `harness-db.py` that writes schema 5, together with the hooks that call it (3.6.12).",
  "Ties every 'once schema 5 ships' to an observable state that respects 3.6.12 (migration only through the deployed helper). The session agent may choose another reading (see the ambiguity).",
  "Yes.")

d(530, "medium", "RFC 8174",
  "The deploy's WARN obligation has no key word, and 'the pair must match' uses a lowercase 'must'.",
  "- the deploy reports a skipped helper or hook (an `[s]kip` at the review menu) as a WARN, because the pair must match.",
  "- the deploy MUST report a skipped helper or hook (an `[s]kip` at the review menu) as a WARN, because the helper and the hooks are safe only at the same version.",
  "Explicit requirement; no lowercase must.",
  "Yes.")

d(546, "medium", "verifiable; complete",
  "The validate verb 'implements' the checks, but the RFC never says what it does when a check fails (exit status, message), so a test cannot tell pass from fail.",
  "`harness-db.py validate --kind brief | aar | estimate <file>` implements:",
  "`harness-db.py validate --kind brief | aar | estimate <file>` MUST perform the checks below, MUST exit 0 when all pass, and MUST exit 1 and name each failed check when any fails:",
  "Verifiable outcome; the exit codes follow 3.6.6 (exit 1 on error).",
  "Yes.")

d(551, "medium", "consistent",
  "The id rule admits only D<sid4>-<n> for decisions, but 3.2.2 (line 238) lets a decision keep 'its record id' (for example D-DEL6), which the validator would then reject.",
  "  - ids match `<TYPE>-<n>`, `R<sid4>-<n>`, `R<mission name>-<n>` or `D<sid4>-<n>`;",
  "  - ids match `<TYPE>-<n>`, `R<sid4>-<n>`, `R<mission name>-<n>` or `D<sid4>-<n>`; a decision that keeps the id of its record (3.2.2), such as `D-DEL6`, is exempt from this check;",
  "Validator and schema agree. The alternative is to drop 'or its record id' from 3.2.2.",
  "Yes.")

d(587, "medium", "vague; RFC 8174",
  "'the delegation prompt restates the standing duties a delegate needs' has no key word, the prompt is not an actor, and 'needs' is vague.",
  "Until then, the delegation prompt restates the standing duties a delegate needs. The brief never carries them (D874d-64); the prompt still carries the prompt elements `/delegate` lists.",
  "Until then, the delegating agent MUST restate in the delegation prompt each of D-DEL8 to D-DEL13 that the deployed `/delegate` does not yet carry. The brief MUST NOT carry them (D874d-64), and the prompt MUST still carry the prompt elements `/delegate` lists.",
  "Inspectable: compare the deployed skill with the source.",
  "Yes.")

d(591, "medium", "unambiguous",
  "'those files' follows 3.9.3, whose last named files are the delegation guards; the files that still name `<sid4>_<mission name>-brief.md` are shared/rules/delegation.md (line 30) and shared/skills/delegate/SKILL.md (lines 129, 143, 582), named in 3.9.1.",
  "<LINE>",
  "3.9.4. The working copies of `shared/rules/delegation.md` (D-DEL10) and `shared/skills/delegate/SKILL.md` still name the brief `<sid4>_<mission name>-brief.md` in Markdown, and do not yet say the hand-back is JSON. Plan WP-2 brings them in line with this RFC (D874d-49).",
  "Names the files; verified with grep on 2026-11-16.",
  "Yes.")

d(82, "medium", "unambiguous; passive voice",
  "'a conflict between the two is a defect to report, not a choice' does not say which text the delegate follows while the conflict is open, nor who reports it; 'Briefs are written' is passive.",
  "Briefs are written to agree with this RFC, so a conflict between the two is a defect to report, not a choice.",
  "A delegating agent MUST write each brief to agree with this RFC. A delegate that finds its brief in conflict with this RFC MUST follow the brief, which D-DEL6 ranks higher, and MUST report the conflict in its AAR as an ambiguity (3.4.5).",
  "Gives one course of action consistent with D-DEL6 and 3.4.5's CONFLICT mapping.",
  "Yes.")

d(421, "medium", "consistent; passive voice",
  "'is written directly by the session agent and every delegate' contradicts 3.4.8 (a confined delegate hands back its AAR only) and 3.6.11 (nothing is written before schema 5).",
  "It lives in the session DB (D874d-35) and is written directly by the session agent and every delegate.",
  "It lives in the session DB (D874d-35); the session agent and every delegate write it directly, except as 3.4.8 (a delegate confined to its worktree) and 3.6.11 (before schema 5 ships) provide.",
  "Consistent with the exceptions.",
  "Yes.")

# ---------------------------------------------------------------- low
d(71, "low", "RFC 8174",
  "Lowercase 'must' in the abstract.",
  "- what must never reach a project repo, since the aitools repo is public.",
  "- which documents are kept out of a project repo, since the aitools repo is public.",
  "Informative text without key-word look-alikes.", "n/a")

d(80, "low", "RFC 8174; passive voice",
  "'goes to the commander as an RFI' is an obligation of the implementer without a key word.",
  "A point the implementer finds unclear goes to the commander as an RFI with a suggested answer.",
  "The implementer MUST raise each point it finds unclear with the commander as a session RFI with a suggested answer.",
  "Explicit obligation.", "Yes.")

d(130, "low", "unambiguous",
  "'refs' is not a field name: the AAR objective has deviation_refs and observation_refs (lines 196-197).",
  "| `objectives` | verbatim, with source | + status, how, refs, deliverables | the session's, + status |",
  "| `objectives` | verbatim, with source | + status, how, deviation_refs, observation_refs, deliverables | the session's, + status |",
  "Field names as defined.", "Yes.")

d(149, "low", "SHOULD without exception",
  "The SHOULD on key order gives no case where departing is acceptable.",
  "Writers SHOULD emit the nodes in the order of 3.3.2, 3.4.2 and 3.5.2. Readers MUST NOT depend on key order.",
  "Writers SHOULD emit the top-level keys in the order of 3.3.2, 3.4.2 and 3.5.2; a writer whose JSON library cannot preserve that order MAY emit another. Readers MUST accept the keys in any order.",
  "RFC 2119 section 3 (SHOULD: valid reasons may exist to ignore it); 'accept in any order' is testable by shuffling keys.", "Yes.")

d(169, "low", "unambiguous",
  "'deviation and observation only' does not say whether severity on another type is forbidden or ignored.",
  "(OPTIONAL; deviation and observation only)",
  "(OPTIONAL on deviation and observation items; MUST NOT appear on other types)",
  "One reading for the validator.", "Yes.")

d(180, "low", "RFC 8174",
  "Lowercase 'must' in a normative table.",
  "`{text, source}`: what the delegate must do or must not do, including",
  "`{text, source}`: an action the delegate is required or forbidden to take, including",
  "No key-word look-alikes in normative text.", "n/a")

d(238, "low", "vague",
  "'or its record id' does not say which record.",
  "decision  D<sid4>-<n>, or its record id",
  "decision  D<sid4>-<n>, or the id the decision has in its own record (for example D-DEL6)",
  "Concrete example.", "Yes.")

d(255, "low", "actor",
  "'(the commander's)' does not say who sets the initial value or who may change it.",
  "  disposition        proposed | accepted | rejected | deferred      (the commander's)",
  "  disposition        proposed | accepted | rejected | deferred      (a writer sets proposed;\n                     only the commander's decision changes it)",
  "Names both actors.", "Yes.")

d(270, "low", "RFC 8174",
  "Lowercase 'must' in a normative table.",
  "A specification the work product must meet:",
  "A specification that the work product is required to meet:",
  "No key-word look-alikes.", "n/a")

d(309, "low", "unambiguous",
  "'The planning brief' is the commander's term in D874d-12 but is not defined in section 2; in the RFC's own prose it reads as a second document.",
  "The planning brief defines the delegate's mission objectives (D874d-12); the brief is where they are written.",
  "The mission brief records the delegate's mission objectives (D874d-12: \"The planning brief should define the mission objectives for the delegate.\").",
  "Uses the governed term; the commander's words stay verbatim in the quotation (issue #180 section 1).", "Yes.")

d(339, "low", "RFC 8174",
  "Lowercase 'must' in the brief's node definitions.",
  "constraints[]        {text, source}: what the delegate must do or must not do (for",
  "constraints[]        {text, source}: an action the delegate is required or forbidden to take (for",
  "No key-word look-alikes.", "n/a")

d(345, "low", "RFC 8174",
  "Lowercase 'must' in the brief's node definitions.",
  "decisions[]          decision items: the decisions the delegate must honour, quoted",
  "decisions[]          decision items: the decisions that bind the delegate, quoted",
  "No key-word look-alikes.", "n/a")

d(355, "low", "vague",
  "'The prompt adds \"line by line\"' does not say which prompt or to what.",
  "The prompt adds \"line by line\" (D874d-27).",
  "The delegation prompt adds \"line by line\" to this instruction (3.3.5; D874d-27).",
  "Concrete reference.", "Yes.")

d(357, "low", "RFC 8174",
  "'Never listed' is a prohibition without a key word or an actor.",
  "- **Never listed:** a governed registry's JSON file",
  "- **Never listed** (the delegating agent MUST NOT list them): a governed registry's JSON file",
  "Explicit prohibition.", "Yes.")

d(362, "low", "actor",
  "'The delegation prompt MUST' makes a document the actor; the obligation is the delegating agent's.",
  "3.3.5. The delegation prompt MUST:",
  "3.3.5. The delegating agent MUST write the delegation prompt so that it:",
  "Actor named.", "Yes.")

d(373, "low", "SHOULD without exception",
  "The SHOULD on worktree choice gives no case where departing is acceptable.",
  "A delegating agent SHOULD give a delegate that writes briefs or DB rows a worktree made with `git worktree add`, which does not confine writes, rather than the Agent tool's worktree isolation.",
  "A delegating agent SHOULD give a delegate that writes briefs or DB rows a worktree made with `git worktree add`, which does not confine writes, rather than the Agent tool's worktree isolation; it MAY use worktree isolation when the mission requires it, and then the rest of this paragraph and 3.4.8 apply.",
  "RFC 2119 section 3.", "Yes.")

d(381, "low", "RFC 8174",
  "'provenance holds' has no key word.",
  "3.4.3. `provenance` holds:",
  "3.4.3. `provenance` MUST hold:",
  "Explicit requirement.", "Yes.")

d(395, "low", "passive voice; actor",
  "'is recorded the same way' hides the actor; D874d-5 says it goes in the delegate's AAR.",
  "What a delegate learns after its merge is recorded the same way, as observations or operational learning (D874d-5).",
  "A delegate MUST record in its AAR what it learns after its merge, the same way, as observations or operational learning (D874d-5).",
  "Matches D874d-5 ('in the AAR').", "Yes.")

d(409, "low", "SHOULD without exception",
  "The SHOULD on producing the hand-back from rows gives no case where departing is acceptable.",
  "- the delegate SHOULD produce its hand-back from its rows (`harness-db.py aar`, 3.6.10);",
  "- the delegate SHOULD produce its hand-back from its rows (`harness-db.py aar`, 3.6.10); it MAY write the hand-back without it when the verb fails, and then records the failure as a deviation;",
  "RFC 2119 section 3.", "Yes.")

d(410, "low", "RFC 8174",
  "The delegating agent's write of missing items has no key word.",
  "Its delegating agent, which receives the AAR, then writes the items the DB does not already hold",
  "Its delegating agent, which receives the AAR, MUST then write the items the DB does not already hold",
  "Explicit obligation.", "Yes.")

d(429, "low", "complete",
  "The assessment is defined as a question, not as the content the field holds.",
  "assessment           is the session proceeding according to the commander's intent?",
  "assessment           the session agent's judgement of whether the session is proceeding according\n                     to the commander's intent, and why",
  "Defines the content.", "Yes.")

d(455, "low", "passive voice",
  "'a step that failed MUST be reported' hides the actor (session-catchup.sh, named earlier in the sentence).",
  "and a step that failed MUST be reported in the next SessionStart output, not only in a log.",
  "and MUST report each step that failed in the next SessionStart output, not only in a log.",
  "Actor named.", "Yes.")

d(463, "low", "RFC 8174",
  "Lowercase 'never write' inside a MUST list.",
  "it MUST log an error, never write the other session's DB, and use",
  "it MUST log an error, MUST NOT write the other session's DB, and MUST use",
  "Each obligation has a key word.", "Yes.")

d(491, "low", "RFC 8174",
  "Hook retry behaviour is normative without key words.",
  "- **Hooks:** a hook does not retry. It logs the failure and exits 0 (RFC 0010 section 8).",
  "- **Hooks:** a hook MUST NOT retry a failed write; it MUST log the failure and exit 0 (RFC 0010 section 8).",
  "Explicit requirement.", "Yes.")

d(493, "low", "singular; passive voice",
  "One MUST carries three obligations, one of them passive ('tested').",
  "3.6.7. The migration from schema 4 MUST be forward-only, inside `ensure_schema` (RFC 0010 section 5), and tested on copies of the live DBs, as PR #181 was.",
  "3.6.7. The migration from schema 4 MUST be forward-only (no step returns a DB to schema 4) and MUST run inside `ensure_schema` (RFC 0010 section 5). The implementer MUST test it on copies of the live session DBs before it ships, as PR #181 was tested.",
  "Singular, active requirements.", "Yes.")

d(507, "low", "RFC 8174",
  "View restrictions without key words.",
  "The views take no writes, and no index is created on a view.",
  "The views MUST NOT accept writes, and the migration MUST NOT create an index on a view.",
  "Explicit requirement.", "Yes.")

d(536, "low", "unambiguous",
  "'every document MUST have a template' reads as every document instance; the JSON Schema draft is not named.",
  "3.7.1. The schemas MUST be JSON Schema files, and every document MUST have a template:",
  "3.7.1. Each document kind MUST have a schema, written as a JSON Schema file that names its draft in `$schema`, and a template, an empty instance:",
  "One reading; the draft choice stays the implementer's.", "Yes.")

d(549, "low", "RFC 8174",
  "Lowercase 'required' in the validator's rule list.",
  "  - a `quote` is required when `source.kind` is `commander`;",
  "  - a `quote` is present when `source.kind` is `commander`;",
  "The list states checks; the requirement is in 3.2.1.", "n/a")

d(557, "low", "passive voice",
  "'A third-party validator MUST NOT be added' hides the actor.",
  "A third-party validator MUST NOT be added.",
  "The implementer MUST NOT add a third-party validator.",
  "Actor named.", "Yes.")

d(572, "low", "RFC 2119 MAY misuse",
  "'MAY contain spaces' uses MAY for a property of input data; RFC 2119 MAY means an item is truly optional for an implementation.",
  "The roots it is given, `<repo>` and the dotprofile path, MAY contain spaces, and every script MUST quote them.",
  "The roots it is given, `<repo>` and the dotprofile path, can contain spaces, so every script MUST quote them where it expands them.",
  "RFC 2119 section 5: MAY means 'an item is truly optional'.", "n/a")

d(655, "low", "passive voice",
  "'MUST be verified on Windows ..., not assumed' hides the actor.",
  "That it outlives Claude Code on Windows MUST be verified on Windows (plan batch 4.3), not assumed.",
  "The implementer MUST verify on Windows (plan batch 4.3) that it outlives Claude Code there, and MUST NOT assume it.",
  "Actor named.", "Yes.")

d(656, "low", "vague; RFC 8174",
  "'are to be examined' is a requirement-like phrase without a key word, and section 8 puts other harnesses out of scope.",
  "Cursor harnesses are to be examined.",
  "Cursor harnesses are not yet examined (section 8).",
  "Informative and consistent with section 8.", "n/a")

d(662, "low", "passive voice",
  "'They MUST NOT be committed' hides the actor.",
  "They MUST NOT be committed to a project repo, with one exception:",
  "An agent MUST NOT commit them to a project repo, with one exception:",
  "Actor named.", "Yes.")

d(664, "low", "RFC 8174; passive voice",
  "'is never done without his order' is a prohibition without a key word or an actor.",
  "A history rewrite is destructive and is never done without his order.",
  "A history rewrite is destructive, and an agent MUST NOT rewrite history without his order.",
  "Explicit prohibition.", "Yes.")

d(667, "low", "unambiguous",
  "'under a `.tmp` name' does not say where the rule applies or what the name must look like.",
  "  - Agents MUST save copies of transcripts, prompts and issue bodies under a `.tmp` name.",
  "  - An agent that saves a copy of a transcript, a prompt or an issue body in a scratch directory MUST give it a name ending in `.tmp`.",
  "Testable by the harvester's own pattern.", "Yes.")

d(668, "low", "passive voice; unambiguous",
  "'Until this ships' has an unclear antecedent, and the prohibition is passive.",
  "  - Until this ships, harvested copies of such files MUST NOT be committed.",
  "  - Until the harvester change above ships, an agent MUST NOT commit a harvested copy of a brief, an AAR, a transcript, a prompt or an issue body.",
  "Named antecedent and actor.", "Yes.")

d(669, "low", "actor",
  "'the harness MUST add' does not name the component; the sentence before names the SessionStart hook.",
  "the harness MUST add both to that repo's `.git/info/exclude` (local, never committed) and report it once per repo (D874d-58).",
  "the SessionStart hook MUST add both to that repo's `.git/info/exclude` (local, never committed) and MUST report the addition once per repo (D874d-58).",
  "Actor named.", "Yes.")

d(670, "low", "actor",
  "'a quote replaces them' makes the quote the actor.",
  "Writers MUST NOT copy credentials or tokens into any item; a quote replaces them with `[redacted]` (S-24).",
  "Writers MUST NOT copy credentials or access tokens into any item; in a quote, the writer replaces each with `[redacted]` (3.2.1, S-24).",
  "Actor named; consistent with 3.2.1.", "Yes.")
