"""Apply the merged language-review edits (missions 874d-7 and 874d-9) to RFC 0011, making v1.4.

Usage: apply-rfc-v14.py <rfc.md>
Each edit is (old, new); old MUST occur exactly once when its turn comes. All edits apply, or none:
on any miss the script prints the failing edit and exits 1 without writing.
Sources: 874d-7-normative-language-aar.json and 874d-9-implementer-read-aar.json (PRO ids in comments);
"merged" marks the session agent's merge where both reviewers touched a line.
"""
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

E = [
    # version history (7/OBS-101; D874d-75 to D874d-77)
    ("""v1.3 (2026-11-16), session dbd05b0c: the briefs directory (D874d-71 to
D874d-74, the commander's prompt of L4045).""",
     """v1.3 (2026-11-16), session dbd05b0c: the briefs directory (D874d-71 to
D874d-74, the commander's prompt of L4045)."""),
    ("""3.3.1a). The normative language was reviewed line by line.""",
     """3.3.1a).
v1.4 (2026-11-16), session dbd05b0c: the language, reviewed line by line
against RFC 2119, RFC 8174 and requirement-quality practice by missions
874d-7 (normative language and requirement quality) and 874d-9 (an
implementer's reading); their proposals are applied, merged where both
touched a line. The route to `main` of a brief in the briefs directory is
deferred by the commander (D874d-76)."""),
    # section: abstract, status
    ("- what must never reach a project repo, since the aitools repo is public.",  # 7/PRO-1
     "- which documents are kept out of a project repo, since the aitools repo is public."),
    ("carried. A point the implementer finds unclear goes to the commander as an RFI with a suggested answer.",  # 7/PRO-2
     "carried. The implementer MUST raise each point it finds unclear with the commander as a session RFI with a suggested answer."),
    ("Briefs are written to agree with this RFC, so a conflict between the two is a defect to report, not a choice.",  # 7/PRO-3, 9/PRO-48 merged
     "A delegating agent MUST write each brief to agree with this RFC. A delegate that finds its brief in conflict with this RFC MUST follow the brief, which D-DEL6 ranks higher, and MUST report the conflict in its AAR as an ambiguity (3.4.5)."),
    # section 2
    ("""- **RFC 2119.** The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY" and "OPTIONAL" are to be interpreted as in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).""",  # 7/PRO-4
     """- **Requirements language.** The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in BCP 14 ([RFC 2119](https://www.rfc-editor.org/rfc/rfc2119), [RFC 8174](https://www.rfc-editor.org/rfc/rfc8174)) when, and only when, they appear in all capitals, as shown here. In lowercase, these words have their ordinary English meaning."""),
    ("the base name of `<repo>`'s main worktree (the parent of `git rev-parse --path-format=absolute --git-common-dir`), so a session started in a git worktree files under its project, for example `aitools`.",  # 9/PRO-54
     "the base name of `<repo>`'s main worktree (the parent of `git -C <repo> rev-parse --path-format=absolute --git-common-dir` when that directory is named `.git`), so a session started in a git worktree files under its project, for example `aitools`; when `<repo>` is not in a git repository, or the common directory is not named `.git` (a submodule, a bare repository), the base name of `<repo>`."),
    ("- **Session id prefix:** the first 10 characters of the session id, hyphen included (for example `dbd05b0c-2`).",  # 9/PRO-27
     "- **Session id prefix:** the first 10 characters of the session id, hyphen included (for example `dbd05b0c-2`); after a prefix collision (3.6.2), the full session id. The session DB, the export and the record (3.8) use the same value."),
    ("where `<commanderid>` is the delegating agent's own four hex digits (`/delegate` naming conventions).",  # 9/PRO-46
     "where `<commanderid>` is the last four hex digits of the delegating agent's own id (its session id for the session agent, its agentId for a delegate), `<n>` is a positive integer, and `<slug>` is one or more of the characters `A-Z`, `a-z`, `0-9` and `-` (`/delegate` naming conventions)."),
    ("- **Briefs directory:** `<repo>/briefs/`, the tracked directory that holds the mission briefs whose missions outlive the session that wrote them (3.3.1).",  # 7/PRO-5, 9/PRO-12
     """- **Briefs directory:** `<repo>/briefs/`, the tracked directory that holds the mission briefs whose missions outlive the session that wrote them (3.3.1).
- **Schema 5 ships:** `aitools` has deployed, on the machine where the session runs, a `harness-db.py` that writes schema 5, together with the hooks that call it (3.6.12).
- **Empty:** a string described as empty holds `""`; `null` is allowed only in `provenance.written_by.mission` (3.3.3). Every top-level key that a document's key list names (3.3.2, 3.4.2, 3.5.2) is present, and a list node with no entries is `[]`."""),
    # 3.1
    ("3.1.1. The mission brief, the AAR and the running estimate MUST share one schema. Every node and every item type is defined once, in this section, and MUST mean the same thing in every document that uses it.",  # 7/PRO-6
     "3.1.1. The mission brief, the AAR and the running estimate MUST share one schema. The schema files (3.7.1) MUST define each node and each item type once, and every document that uses a node or an item type MUST give it the fields and meaning that sections 3.1 and 3.2 define."),
    ("| `objectives` | verbatim, with source | + status, how, refs, deliverables | the session's, + status |",  # 7/PRO-7, 7/OBS-98
     "| `objectives` | verbatim, with source | + status, how, deviation_refs, observation_refs, deliverables | the session's, + status, how, deviation_refs, observation_refs, deliverables |"),
    ("| per objective (3.2.6) | per objective (3.2.6) |",  # 9/PRO-52
     "| inside each objective only, not a top-level node (3.2.6) | inside each objective only, not a top-level node (3.2.6) |"),
    ("3.1.3. No document has a `facts` node (D874d-32), a `report_at_once_if` node (D874d-26), a `meta` node (D874d-19) or a `findings` node (D874d-22). A mission brief has no `conflict_priority` and no `permissions` node: standing duties are documented in `/delegate`, never in the brief (D874d-64). A mission brief has no `rules` and no `skills` node: `artifacts` replaces both (D874d-65). A mission brief has no `ambiguities`, `access`, `name_prefix`, `duties` or `return` node (D874d-70): what the delegating agent resolved before launch is a decision or a constraint; the scratch directory, the paths the delegate may write, the sources that are not files and the name prefix (D-DEL1) are in the delegation prompt (3.3.5); what the delegate must or must not do is a constraint; and what it returns is a deliverable.",  # 7/PRO-8
     "3.1.3. The table in 3.1.2 does not mark the following nodes, so 3.1.2 prohibits them; this paragraph records the decisions that removed them. No document has a `facts` (D874d-32), `report_at_once_if` (D874d-26), `meta` (D874d-19) or `findings` (D874d-22) node. A mission brief also has no `conflict_priority` and no `permissions` node, because `/delegate` documents the standing duties (D874d-64); no `rules` and no `skills` node, which `artifacts` replaces (D874d-65); and no `ambiguities`, `access`, `name_prefix`, `duties` or `return` node (D874d-70). The content of the removed brief nodes is carried elsewhere: an ambiguity the delegating agent resolved before launch is a decision or a constraint; the scratch directory, the paths the delegate is permitted to write, the sources that are not files and the name prefix (D-DEL1) are in the delegation prompt (3.3.5); an action the delegate is required or forbidden to take is a constraint; and what the delegate returns is a deliverable."),
    ("Writers SHOULD emit the nodes in the order of 3.3.2, 3.4.2 and 3.5.2. Readers MUST NOT depend on key order.",  # 7/PRO-9
     "Writers SHOULD emit the top-level keys in the order of 3.3.2, 3.4.2 and 3.5.2; a writer whose JSON library cannot preserve that order MAY emit another. Readers MUST accept the keys in any order."),
    # 3.2.1
    ("Every entry of an item node is an item, and MUST carry these common fields:",  # 9/PRO-1 (over 7/PRO-10)
     "Every entry of an item node is an item. Every item MUST carry `id`, `type`, `text` and `source` (`source.kind`, `source.location`); it MUST carry `quote` when `source.kind` is `commander`; it MAY carry `severity` only when its type is `deviation` or `observation`; it carries `version`, `agent_id`, `agent_type`, `mission` and `created_at` as the second bullet below says. The common fields are:"),
    ("text           the statement\nversion        1 for a new item",  # 9/PRO-2
     "text           the statement (for a proposal, a one-line summary of `what`; for an rfi,\n               its `title`)\nversion        1 for a new item"),
    ("quote          the source text verbatim; REQUIRED when source.kind is commander (S-24)",  # 7/OBS-96
     "quote          the source text verbatim; REQUIRED when source.kind is commander\n               (issue #180 section 3); a credential in it becomes [redacted] (S-24)"),
    ("(OPTIONAL; deviation and observation only)",  # 7/PRO-11
     "(OPTIONAL on deviation and observation items; MUST NOT appear on other types)"),
    ("- In a brief or an AAR, an item MAY omit `version`, `agent_id`, `agent_type`, `mission` and `created_at`; it inherits them from the document's `provenance`. In the session DB, every row MUST carry them (D874d-55, which accepted S-18).",  # 9/PRO-3 (over 7/PRO-12)
     "- In a brief or an AAR, an item MAY omit `version`, `agent_id`, `agent_type`, `mission` and `created_at`. An omitted `version` is the integer 1 (`provenance.version` is the document's version string, not an item's). In a brief, the other omitted fields take the values of `provenance.written_by.agent_id`, `provenance.written_by.agent_type`, `provenance.written_by.mission` and `provenance.created_at`; in an AAR, the values of `provenance.agent_id`, `delegate`, `provenance.mission` and `provenance.created_at`. In the session DB, every row MUST carry them (D874d-55, which accepted S-18)."),
    ("- A quote MUST NOT carry a credential or a token. Such a passage is copied with the secret replaced by `[redacted]`, the one permitted change to a verbatim quote. *Settled by this RFC (S-24).*",  # 7/PRO-13
     "- A writer MUST NOT copy a credential or an access token into a `quote`. When a quoted passage contains one, the writer MUST replace the secret with `[redacted]`; this is the only change a writer MAY make to a verbatim quote. *Settled by this RFC (S-24).*"),
    ("`{text, source}`: what the delegate must do or must not do, including",  # 7/PRO-14
     "`{text, source}`: an action the delegate is required or forbidden to take, including"),
    # 3.2.2
    ("3.2.2. The type-specific fields are:",  # 7/PRO-15
     "3.2.2. The type-specific fields are listed below. Every listed field is REQUIRED, except a field marked OPTIONAL and a field whose line states when it is present (for example `ref`, \"once verified or falsified\", and `answer`, \"once answered\"); a list field (`[]`) MAY be empty. The fields listed under \"in an AAR or a running estimate\" MUST NOT appear in a brief."),
    ("status             resolved | open                 (an open one is also an rfi)",  # 7/PRO-16
     "status             resolved | open      (for an open ambiguity, the writer MUST also write an rfi item)"),
    ("""  ref                (once verified or falsified) what settled it: a verified assumption
                     points to a fact ('validated'), a falsified one to the contradicting
                     observation ('invalidated'); the glossary's lifecycle (D874d-43)""",  # 7/PRO-17 (over 9/PRO-4)
     """  ref                (once verified or falsified) the id of the item that settled it: for a
                     falsified assumption, the contradicting observation ('invalidated'); for
                     a verified assumption, a fact in the session DB ('validated'). A brief or
                     an AAR has no facts node (3.1.3), so there `ref` MAY be empty and
                     `evidence` carries the support; the glossary's lifecycle (D874d-43)"""),
    ("decision  D<sid4>-<n>, or its record id",  # 7/PRO-18
     "decision  D<sid4>-<n>, or the id the decision has in its own record (for example D-DEL6)"),
    ("""                     status is superseded only when the whole decision is; a decision
                     superseded in part keeps its status and names the part""",  # 7/PRO-19
     """                     a writer MUST set status to superseded only when the whole decision
                     is superseded; for a decision superseded in part, it MUST keep the
                     status and MUST name the part in superseded_by[].part"""),
    ("disposition        proposed | accepted | rejected | deferred      (the commander's)",  # 7/PRO-20
     "disposition        proposed | accepted | rejected | deferred      (a writer sets proposed;\n                     only the commander's decision changes it)"),
    # 3.2.3
    ("A specification the work product must meet:",  # 7/PRO-21
     "A specification that the work product is required to meet:"),
    ("The given course could not be followed. A blocker is reported at once (D-DEL9); a denied write is one |",  # 7/PRO-22, 9/PRO-49 merged
     "The given course could not be followed; a denied write is a blocker. The agent that meets a blocker MUST report it, with a recommended course of action, as soon as it meets it, not only in its AAR (D-DEL9): a delegate sends it to its delegating agent (in Claude Code, with `SendMessage`), and the session agent reports it to the commander in its reply |"),
    # 3.2.4
    ("- In the session DB (schema 5), `harness-db.py` MUST assign `<TYPE>-<n>` on insert, so parallel writers never collide.",  # 9/PRO-5
     "- In the session DB (schema 5), `harness-db.py` MUST assign the id on insert, inside the insert's `BEGIN IMMEDIATE` transaction (3.6.6), so parallel writers never collide: `<TYPE>-<n>`, `R<sid4>-<n>` for an rfi and `D<sid4>-<n>` for a decision, where `<n>` is one more than the highest `<n>` already in the DB with that prefix (1 for the first). A writer that records a decision already numbered elsewhere (its record id: a `D874d-<n>` of the issue, a `D-DEL<n>`) passes that id with `--id`; the insert exits 1 when the id is taken."),
    ("- In a document, the writer numbers its items from 1. It MAY instead keep the ids of the record it copies them from, such as the issue's `ASM-<n>`, for traceability.",  # 7/PRO-23
     "- In a document, the writer MUST number the items of each type consecutively from 1 (`OBS-1`, `OBS-2`, ...), except that it MAY keep the ids of the record it copies items from, such as the issue's `ASM-<n>`, for traceability."),
    ("- When a document's items are written into the DB (3.4.8), the DB assigns new ids, keeps the document's id in `fields.doc_id`, and rewrites the document's refs to the new ids.",  # 7/PRO-24, 9/PRO-6 merged
     "- When a document's items are written into the DB (3.4.8), `harness-db.py` MUST assign each a new id, MUST keep the document's id in `fields.doc_id`, and MUST rewrite each ref that points to an item of the same document to that item's new id; it MUST keep unchanged a ref to an id outside the document (a brief's objective, a session RFI, a decision)."),
    ("- A delegate cannot see the session's RFI counter, so it numbers its RFIs `R<mission name>-<n>`. The session agent renumbers them into `R<sid4>-<n>` when it raises them.",  # 7/PRO-25, 9/PRO-5 merged
     "- A delegate that writes the session DB MUST use the `R<sid4>-<n>` ids the DB assigns to its RFIs. In a document whose items are not in the DB (before schema 5 ships, or under 3.4.8's worktree confinement), the delegate MUST number its RFIs `R<mission name>-<n>`, and `harness-db.py` MUST assign `R<sid4>-<n>` when the items are written (the third bullet). Before schema 5 ships, the session agent MUST renumber each such RFI to `R<sid4>-<n>` when it raises it to the commander."),
    # 3.2.5
    ("3.2.5. Writers MUST NOT change an item in place, because provenance is never deleted (\"provenance is eternal\", the commander, 2026-03-30). A change appends a new version of the item:",  # 7/PRO-26
     "3.2.5. In the session DB, a writer MUST NOT change an item row in place, because provenance is never deleted (\"provenance is eternal\", the commander, 2026-03-30). A writer that changes an item MUST insert a new row with the same `id` and a `version` one greater than the item's latest version. A brief or an AAR is changed by writing a new version of the whole document (D-DEL5):"),
    ("- A ref points to an `id` and means its latest version.",  # 9/PRO-7
     "- A ref points to an `id` and means its latest version. In the DB, refs (the `*_refs[]` and `ref` fields of 3.2.2) are stored only in the `refs` table, never in `fields`; each `refs` row carries the `from_version` of the item version that holds it, and an item's refs are those of its latest version."),
    ("- Every reader, including the export, `aar`, the compatibility views (3.6.7) and the derived `missions[]`, reads the latest version of each id.",  # 7/PRO-27
     "- Every reader, including the export, `aar`, the compatibility views (3.6.7) and the derived `missions[]`, MUST read only the latest version of each id."),
    # 3.2.6
    ("the repo and base branch for a\n                   PR, the repo for an issue or commit;",  # 9/PRO-8
     "`<owner>/<repo>, base <branch>`\n                   for a PR, `<owner>/<repo>` for an issue or commit;"),
    ("objective          the OBJ id it serves (brief only; in an objective it is implicit)",  # 9/PRO-8
     "objective          the OBJ id it serves, REQUIRED in a brief; \"\" for the AAR, which\n                   serves every objective (in an objective it is implicit)"),
    ("Every brief lists the AAR as a deliverable (`kind` `aar`): the hand-back, JSON in the AAR schema in one fenced block, and the file only when its `ref` names one (D874d-47, D874d-50).",  # 7/PRO-28
     "Every brief MUST list exactly one deliverable of `kind` `aar` (D874d-47, D874d-50). That deliverable is the hand-back, JSON in the AAR schema in one fenced block (3.4.1), and also a file when its `ref` names one (3.4.7)."),
    # 3.3.1
    ("The planning brief defines the delegate's mission objectives (D874d-12); the brief is where they are written.",  # 7/PRO-29
     "The mission brief records the delegate's mission objectives (D874d-12: \"The planning brief should define the mission objectives for the delegate.\")."),
    ("- **Default.** Unless the commander orders otherwise, the brief MUST be written to `<session scratch dir>/<mission name>-brief.json` (D874d-36, D874d-42, D874d-73).",  # 7/PRO-30, 9/PRO-9 merged
     "- **Default.** Unless the commander orders otherwise, the delegating agent MUST write the brief to `<session scratch dir>/<mission name>-brief.json` (D874d-36, D874d-42, D874d-73), except as 3.3.8 provides for a delegating agent confined to its worktree."),
    ("- **Long lifecycle.** A brief whose mission outlives the session that wrote it, such as a mission that implements a roadmap item, belongs in the briefs directory, at `<repo>/briefs/<mission name>-brief.json`, tracked in git as plans are (D874d-72, D874d-74). An agent MUST NOT place a brief there without the commander's order (D874d-73). An agent that writes a brief whose mission will outlive the session SHOULD recommend that placement to the commander as a session RFI.",  # 7/PRO-31, 9/PRO-10 merged
     "- **Long lifecycle.** The briefs directory, `<repo>/briefs/`, tracked in git as plans are, holds the briefs of missions that outlive the session that wrote them, such as a mission that implements a roadmap item (D874d-72, D874d-74). An agent MUST NOT write a new brief to `<repo>/briefs/<mission name>-brief.json` without the commander's order, and on his order it MUST write the brief there (D874d-73); a new version of a brief already there (3.3.1a) needs no new order. A delegating agent that expects a mission to outlive its session SHOULD ask the commander to order that placement, in a session RFI (a delegate: in an RFI of its AAR, 3.2.4); it MAY omit the request when the commander has already ruled on that brief's placement."),
    ("- It is versioned (D-DEL5): each change is a new version, committed and pushed to `main`.",  # 7/PRO-32, 9/PRO-11 merged; D874d-76
     "- The agent that changes it MUST write each change as a new version (D-DEL5) and commit it. Whether such a commit goes to `main` directly, as plans do, or through a PR is deferred by the commander (D874d-76); until he decides, it reaches `main` the way he orders for that change, or else through a PR (aitools `CLAUDE.md`, \"Channel exception\"). A version MUST reach `main` before any delegate is launched from it; if it cannot, the agent MUST NOT launch a delegate from it and MUST report the failure to the commander."),
    # 3.3.2, 3.3.3
    ("3.3.2. The brief MUST be one JSON object with these top-level keys:",  # 7/PRO-33
     "3.3.2. The brief MUST be one JSON object whose top-level keys are exactly these, each present even when its list is empty (`[]`):"),
    ("session_scratch    the top-level session's scratch directory (every brief lives there)",  # 7/PRO-34, 9/PRO-9
     "session_scratch    the top-level session's scratch directory (where a default brief\n                     resides, 3.3.1)"),
    ("chain_of_command[] the transcript path of every agent above the delegate",  # 9/PRO-13
     "chain_of_command[] the transcript path of every agent above the delegate, the top-level\n                     session's first and the delegating agent's last"),
    ("identity             name, level, delegated_by, parallel_missions[] {mission, scope}",  # 9/PRO-14
     "identity             name, level (1 for a delegate of the session agent, + 1 for each level\n                     below), delegated_by, parallel_missions[] {mission, scope}"),
    ("constraints[]        {text, source}: what the delegate must do or must not do (for",  # 7/PRO-35
     "constraints[]        {text, source}: an action the delegate is required or forbidden to take (for"),
    ("""assumptions[]        assumption items: what the delegating agent assumes; the delegate
                     verifies or falsifies each""",  # 7/PRO-36
     """assumptions[]        assumption items: what the delegating agent assumes; the delegate
                     MUST report each one's end state (verified, falsified or unverified)
                     in its AAR (3.4.2)"""),
    ("decisions[]          decision items: the decisions the delegate must honour, quoted",  # 7/PRO-37
     "decisions[]          decision items: the decisions that bind the delegate, quoted"),
    # 3.3.3a
    ("3.3.3a. `artifacts[]` lists every file the delegate needs, one entry per file, by absolute path, each with an explicit instruction (D874d-65):",  # 7/PRO-38
     "3.3.3a. The delegating agent MUST list in `artifacts[]` every file the delegate needs, one entry per file, by absolute path, and MUST give each entry the instruction that its category below names (D874d-65):"),
    ("The prompt adds \"line by line\" (D874d-27).",  # 7/PRO-39
     "The delegation prompt adds \"line by line\" to this instruction (3.3.5; D874d-27)."),
    ("The delegate searches these when a question comes up and never loads them whole.",  # 7/PRO-40
     "The delegate MUST NOT read such a file whole; it searches the file when it needs an answer the file can give."),
    ("- **Never listed:** a governed registry's JSON file (its skill's SKILL.md is listed instead;",  # 7/PRO-41, 9/PRO-15 merged
     "- **Never listed** (the delegating agent MUST NOT list them): a governed registry's JSON file, even one the delegate changes through its skill (its skill's SKILL.md is listed instead;"),
    # 3.3.4 to 3.3.8
    ("3.3.4. Only structured content goes in the brief. Anything unstructured, such as facts or background, MUST go in the body of the delegation prompt, outside the brief (D874d-32, D-DEL12).",  # 7/PRO-42
     "3.3.4. The delegating agent MUST put in the brief only content that fits a node and an entry defined in 3.3.3, and MUST put any other content, such as facts or background, in the body of the delegation prompt, outside the brief (D874d-32, D-DEL12)."),
    ("3.3.5. The delegation prompt MUST:",  # 7/PRO-43 (reworded: the bullets are verbs)
     "3.3.5. In the delegation prompt, the delegating agent MUST:"),
    ("3.3.7. A blocker the delegating agent already knows at launch MUST be written as a constraint or in the prompt body, and the objective it affects MUST say so.",  # 7/PRO-44 (over 9/PRO-17)
     "3.3.7. When the delegating agent knows of a blocker at launch, it MUST state the blocker as a constraint or in the prompt body, and MUST name there each objective the blocker affects, by its `OBJ` id; it MUST NOT add to an objective's verbatim text (3.2.2)."),
    ("A delegating agent SHOULD give a delegate that writes briefs or DB rows a worktree made with `git worktree add`, which does not confine writes, rather than the Agent tool's worktree isolation.",  # 7/PRO-45
     "A delegating agent SHOULD give a delegate that writes briefs or DB rows a worktree made with `git worktree add`, which does not confine writes, rather than the Agent tool's worktree isolation; it MAY use worktree isolation when the mission requires it, and then the rest of this paragraph and 3.4.8 apply."),
    # 3.4
    ("and that block MUST be the last ```` ```json ```` block of the hand-back (D874d-50).",  # 9/PRO-18
     "and that block MUST be the last block of the hand-back whose opening line is exactly three backticks followed by `json`, with nothing after them; the block ends at the next line that is exactly three backticks (D874d-50)."),
    ("3.4.2. The AAR MUST be one JSON object with these top-level keys:",  # 7/PRO-46
     "3.4.2. The AAR MUST be one JSON object whose top-level keys are exactly these, each present even when its list is empty (`[]`):"),
    ("The first three answer \"what was supposed to happen\"",  # 7/PRO-47, 9/PRO-51
     "`objectives`, `ambiguities` and `assumptions` answer \"what was supposed to happen\""),
    ("3.4.3. `provenance` holds:",  # 7/PRO-48
     "3.4.3. `provenance` MUST hold:"),
    ("- Each objective gives `how`, cites deviations or observations, or both (D874d-23).",  # 7/PRO-49 (over 9/PRO-19)
     "- Each objective MUST give `how`, or cite at least one deviation or observation, or both (D874d-23)."),
    ("- An objective that is not accomplished MUST cite the deviation that explains it.",  # 7/PRO-50
     "- An objective whose `status` is `partly` or `not accomplished` MUST cite in `deviation_refs` at least one deviation that explains the shortfall."),
    ("- An artifact whose instruction is `read in full` and that the delegate did not read in full is a deviation, `from.kind` `brief`.",  # 7/PRO-51
     "- The delegate MUST record as a deviation, `from.kind` `brief`, each artifact whose instruction is `read in full` that it did not read in full."),
    ("3.4.5. The free-text lines of the old hand-back fold into these nodes (D874d-29, D-DEL11):",  # 7/PRO-52
     "3.4.5. The delegate MUST record what the old hand-back carried as free-text lines in these nodes (D874d-29, D-DEL11):"),
    ("What a delegate learns after its merge is recorded the same way, as observations or operational learning (D874d-5).",  # 7/PRO-53
     "A delegate MUST record in its AAR what it learns after its merge, the same way, as observations or operational learning (D874d-5)."),
    ("3.4.6. When a blocker stops an objective, the AAR records it in four places:",  # 7/PRO-54
     "3.4.6. When a blocker stops an objective, the delegate MUST record it in its AAR as follows, the last two only when their conditions hold:"),
    ("The blocker was also reported at once, with a recommended course of action (D-DEL9).",  # 7/PRO-55
     "The delegate MUST also have reported the blocker when it met it, with a recommended course of action (D-DEL9; 3.2.3)."),
    ("3.4.7. An AAR file is written only when one is requested: the brief's AAR deliverable names it in `ref` (3.2.6). It then MUST be the same JSON, at `<session scratch dir>/<mission name>-aar.json` (D874d-47).",  # 7/PRO-56, 9/PRO-20 merged
     "3.4.7. A delegate MUST write an AAR file if, and only if, the `ref` of the brief's `aar` deliverable names a file (3.2.6), and MUST write it at that path, holding the same JSON as the hand-back. A delegating agent that requests a file MUST name `<session scratch dir>/<mission name>-aar.json` in that `ref`, or, when it wrote the brief to its own scratch directory (3.3.8), `<mission name>-aar.json` in that directory (D874d-47)."),
    ("- every item of the AAR MUST also be a row in the session DB, written by the delegate as it works;",  # 7/PRO-57
     "- the delegate MUST write every item of its AAR as a row in the session DB when it records the item, not at hand-back, except as the third item of this list provides;"),
    ("- the delegate SHOULD produce its hand-back from its rows (`harness-db.py aar`, 3.6.10);",  # 7/PRO-58
     "- the delegate SHOULD produce its hand-back from its rows (`harness-db.py aar`, 3.6.10); it MAY write the hand-back without it when the verb fails, and then records the failure as a deviation;"),
    ("Its delegating agent, which receives the AAR, then writes the items the DB does not already hold, matched by `agent_id` and `fields.doc_id`, with `agent_id` from the AAR's `provenance.agent_id` and the ids rewritten (3.2.4).",  # 7/PRO-59, 9/PRO-21 merged
     "Its delegating agent, which receives the AAR, MUST then write each AAR item the DB does not already hold, with `agent_id` from the AAR's `provenance.agent_id` and the ids rewritten (3.2.4). An AAR item is already held when a row has the same `agent_id` and either the same `id` (an AAR rendered from the DB by `aar`) or a `fields.doc_id` equal to the item's id (an item written earlier from a document)."),
    ("3.4.9. A delegate MUST find its own agentId by one of these methods (D874d-33):",  # 7/PRO-60, 9/PRO-23 merged
     "3.4.9. A delegate MUST try these methods, in this order, to find its own agentId (D874d-33):"),
    ("That id fills `agent_id` when a delegate could not find its own (ASM-1). This holds for the Claude Code harness; other harnesses (Claude Code web, Cursor CLI, Cursor cloud agents) MUST be examined before they are relied on (D874d-33).",  # 7/PRO-61, 9/PRO-23 merged
     "A delegate that finds its agentId by none of them MUST set `provenance.agent_id` to `\"\"` and MUST NOT write the session DB; its delegating agent MUST then write its items (3.4.8) with the agentId the launch returned (ASM-1). These methods are verified for the Claude Code harness only; an implementer MUST NOT rely on them in another harness (Claude Code web, Cursor CLI, Cursor cloud agents) until it has tested them there and recorded the result (D874d-33)."),
    # 3.5
    ("It lives in the session DB (D874d-35) and is written directly by the session agent and every delegate.",  # 7/PRO-62
     "It lives in the session DB (D874d-35); the session agent and every delegate write it directly, except as 3.4.8 (a delegate confined to its worktree) and 3.6.11 (before schema 5 ships) provide."),
    ("3.5.2. Its export MUST be one JSON object with these top-level keys:",  # 7/PRO-63
     "3.5.2. Its export MUST be one JSON object whose top-level keys are exactly these, each present even when its list is empty (`[]`):"),
    ("intent               the commander's intent for the session; main_effort\nassessment           is the session proceeding according to the commander's intent?",  # 7/PRO-64, 7/PRO-65
     "intent               {text, main_effort}: the commander's intent for the session and its\n                     main effort\nassessment           the session agent's judgement of whether the session is proceeding\n                     according to the commander's intent, and why"),
    ("objectives[]         the session's objectives: the commander's orders verbatim, with the\n                     transcript line, + status, how, refs, deliverables",  # 9/PRO-24
     "objectives[]         the session's objectives (the items of type objective whose `mission`\n                     is empty; a delegate's objectives appear only in `missions[]`): the\n                     commander's orders verbatim, with the transcript line, + status, how,\n                     deviation_refs, observation_refs, deliverables"),
    ("assumptions[], decisions[], ambiguities[], deviations[], observations[],\noperational_learning[], proposals[], rfis[]\n```",  # 9/PRO-24
     "assumptions[], decisions[], ambiguities[], deviations[], observations[],\noperational_learning[], proposals[], rfis[]: every agent's items of these types,\n                     latest versions (3.2.5)\n```"),
    ("3.5.3. Once schema 5 ships, the session agent MUST update `intent`, `main_effort`, `assessment` and the session's `objectives` at each prompt turn and after each hand-back.",  # 7/PRO-66
     "3.5.3. Once schema 5 ships, the session agent MUST review `intent`, `main_effort`, `assessment` and the session's `objectives` at each prompt turn and after each hand-back, and MUST write each one whose value has changed."),
    ("- `intent`, `main_effort` and `assessment` are columns of the `session` table, set with `harness-db.py estimate set`; each change is kept in `version_history`.",  # 9/PRO-25
     "- `intent`, `main_effort` and `assessment` are columns of the `session` table (`main_effort` is stored in the v4 column `schwerpunkt`, which keeps its name because RFC 0010 never removes columns; `intent` and `assessment` are added), set with `harness-db.py estimate set`, which writes nothing when the value is unchanged; each change adds a `version_history` row whose `version` is the highest plus 1 and whose `changes` names the column and its new value."),
    ("3.5.4. `missions[]` MUST be derived on export; no writer writes it. It has one entry per `<mission name>-brief.json` in the session scratch directory, per brief in the briefs directory whose `provenance.session_id` is the session's id (3.3.1a), and per brief path named in a delegate's AAR `provenance.brief` (3.3.8). Each entry carries the `agent_id` and the objectives' status found on that mission's rows (latest versions, 3.2.5).",  # 7/PRO-67, 9/PRO-26 merged
     "3.5.4. `missions[]` MUST be derived on export (`harness-db.py export`); writers MUST NOT write it. It has exactly one entry per mission name found in any of: each `*-brief.json` in the session scratch directory; each brief in the briefs directory whose `provenance.session_id` is the session's id (3.3.1a); each `*-brief.json` in any other `.scratch/session-*/` directory under `<repo>`, at any depth, whose `provenance.session_id` is the session's id (3.3.8); and each mission name on the session's rows. Each entry is `{mission, brief, agent_id, objectives[] {id, status}}`: `brief` is the path found (`\"\"` when rows exist but no brief is found); `agent_id` and the statuses are read from the rows whose `mission` is that name (latest versions, 3.2.5), `agent_id` `\"\"` when there are none."),
    ("MUST run these steps in this order:",  # 9/PRO-33
     "MUST run these steps in this order; when the session DB is missing or below schema 5, it MUST run none of them and record that as a failed step (below):"),
    ("1. export the estimate to `<repo>/.aitools/channel/estimates/<session id prefix>.json`, untracked (D874d-44, D874d-52);",  # 9/PRO-29
     "1. export the estimate to `<repo>/.aitools/channel/estimates/<session id prefix>.json`, untracked (D874d-44, D874d-52): the aitools `.gitignore` MUST list `.aitools/channel/estimates/`, and in other repos the exclude entry for `.aitools/` covers it (section 7);"),
    ("from the session DB (D874d-52, D874d-53);",  # 9/PRO-30
     "from the session DB (D874d-52, D874d-53). `<dotprofile>` is the dotprofile repo as `ait-harvest.py archive` resolves it; when none is configured or it is not a git repository, the job MUST skip steps 2 and 3 and record them as failed steps (below);"),
    ("- take a single-flight lock on the dotprofile, so it never contends with `ait-harvest.py archive` for the git index;",  # 9/PRO-31
     "- take the single-flight lock that `ait-harvest.py archive` takes (`~/.aitools/locks/harvest.lock`) before step 2 and hold it until step 3 ends; while a live holder has it, wait (the job is detached) up to 10 minutes, then skip steps 2 and 3 and leave them to the catch-up;"),
    ("- pull with rebase before it pushes, and refuse to push from a branch other than `main`.",  # 9/PRO-31
     "- before step 2, check that the dotprofile is on `main`, and if it is not, skip steps 2 and 3; in step 3, commit only the record file, then `git pull --rebase`, then push."),
    ("The next session's catch-up (`session-catchup.sh`) MUST recover a missing export, copy, commit or push, and a step that failed MUST be reported in the next SessionStart output, not only in a log.",  # 9/PRO-32 (over 7/PRO-68)
     "The next session's catch-up (`session-catchup.sh`) MUST, for every session DB in `<repo>/.aitools/sessions/` other than the starting session's, recover what is missing: the export when it is absent or older than the DB; the record when it differs from the export; the commit and the push when the record is uncommitted or the dotprofile's `main` is ahead of its upstream. The job and the catch-up MUST record each failed step, with the session id and the error, in `~/.aitools/logs/harness-db-sessionend.log`, and the next SessionStart output MUST print one line for each failed step the catch-up could not recover, not only a log entry."),
    ("3.5.6. The SessionEnd hook MUST stop writing the single `.aitools/channel/running-estimate.json`. That file and `.aitools/templates/mission-running-estimate.json` are retired (S-13). Every reader and description of the old file is repointed to the per-session export or updated: `scripts/generate-dashboard.py`, `scripts/aitools-dashboard.sh/.ps1`, `shared/hooks/dashboard-serve.sh`, the `/mission-control` and `/aitool-continue` skills, `.claude/rules/aitools-workspace.md` and `reference/artifact-harvesting.md` (D874d-61). The hook stops writing the old file when it switches to the per-session export (plan WP-3); the tracked file and its template are removed in plan WP-5. Nothing is done earlier about the file already published (D874d-54).",  # 7/PRO-69
     "3.5.6. When the SessionEnd hook switches to the per-session export (plan WP-3), it MUST stop writing the single `.aitools/channel/running-estimate.json`. That file and `.aitools/templates/mission-running-estimate.json` are retired (S-13). The implementer MUST repoint to the per-session export, or update, every reader and description of the old file: `scripts/generate-dashboard.py`, `scripts/aitools-dashboard.sh/.ps1`, `shared/hooks/dashboard-serve.sh`, the `/mission-control` and `/aitool-continue` skills, `.claude/rules/aitools-workspace.md` and `reference/artifact-harvesting.md` (D874d-61). The implementer MUST remove the tracked file and its template in plan WP-5, and MUST take no earlier action on the copy already published (D874d-54)."),
    # 3.6
    ("it MUST log an error, never write the other session's DB, and use `<repo>/.aitools/sessions/<full session id>.db` instead (ASM-6).",  # 7/PRO-70, 9/PRO-28 merged
     "it MUST log an error, MUST NOT write the other session's DB, and MUST use `<repo>/.aitools/sessions/<full session id>.db` instead, printing that path in its \"Session DB:\" line (ASM-6). Every later writer or reader that derives the path from a session id (a hook, the SessionEnd job, the catch-up) MUST apply the same rule: `<session id prefix>.db` when it holds that session id, else `<full session id>.db`. An existing DB with no `session` row is treated as the starting session's."),
    ("""items   id, version, type, text, status, severity, fields, agent_id, agent_type, mission,
        source_kind, source, quote, created_at, updated_at          key (id, version)
refs    from_id, to_id, kind (objective | deviation | observation | deliverable |
        validated | invalidated)""",  # 9/PRO-34, 9/PRO-7
     """items   id, version, type, text, status, severity, fields, agent_id, agent_type, mission,
        source_kind, source (the item's source.location), quote, created_at
        key (id, version)
refs    from_id, from_version, to_id, kind (objective | deviation | observation |
        validated | invalidated); an objective's deliverables are kept in its
        fields.deliverables (3.2.6)"""),
    ("| The commander (command channel) |",  # 9/PRO-36
     "| The commander, writing himself through the command channel with `item add` (an agent that records his words writes with its own id and `source.kind` `commander`, 3.2.1) |"),
    ("`harness-db.py` derives `agent_type` as the table shows; there is no `--agent-type` flag.",  # 9/PRO-35
     "`--db` and `--agent-id` are REQUIRED on every session-DB write verb. `harness-db.py` derives `agent_type` in this order: `commander` when the id is `commander`; `hook` when it ends in `.sh` or `.py`; `delegate` when `--mission` is given (a mission name, section 2); `session` when the id equals the `session_id` stored in the DB; otherwise it MUST exit 1 with an error and write nothing. There is no `--agent-type` flag."),
    ("MUST run at session start only, not on every write.",  # 9/PRO-38
     "MUST run at session start only, not on every write. A write verb that finds the DB missing or below schema 5 MUST NOT create or migrate it: the CLI exits 1 with an error naming the DB's version, and a hook logs it and exits 0; such a session writes no items until its next start (3.6.11 applies to it)."),
    ("- **Agents:** when a write still fails with \"database is locked\" after the busy timeout, the CLI retries up to three times with backoff, then exits 1 with the error. The agent then records the failed write as a deviation with cause `blocker`.",  # 7/PRO-71, 9/PRO-37 merged
     "- **Agents:** when a write still fails with \"database is locked\" after the busy timeout, `harness-db.py` MUST retry it up to three times (four attempts in all), waiting 1, 2 and 4 seconds before the retries, and then MUST exit 1 with the error. The agent MUST then record the failed write as a deviation with cause `blocker`, in its AAR (a delegate) or its reply (the session agent), and MUST write that deviation to the DB once a later write succeeds."),
    ("- **Hooks:** a hook does not retry. It logs the failure and exits 0 (RFC 0010 section 8).",  # 7/PRO-72
     "- **Hooks:** a hook MUST NOT retry a failed write; it MUST log the failure and exit 0 (RFC 0010 section 8)."),
    ("3.6.7. The migration from schema 4 MUST be forward-only, inside `ensure_schema` (RFC 0010 section 5), and tested on copies of the live DBs, as PR #181 was.",  # 7/PRO-73
     "3.6.7. The migration from schema 4 MUST be forward-only (no step returns a DB to schema 4) and MUST run inside `ensure_schema` (RFC 0010 section 5). The implementer MUST test it on copies of the live session DBs before it ships, as PR #181 was tested."),
    ("| `observations` rows | `items` rows, `version` 1 |",  # 9/PRO-39
     "| `observations` rows | `items` rows, `version` 1; `observation_id` becomes the id `<TYPE>-<n>`, numbered per type in `observation_id` order (the old number in `fields.legacy_id`); `category` becomes `type`; `text`, `status`, `severity`, `source_kind`, `source`, `quote` and `created_at` keep their columns; `status` `pending` becomes `unverified` for an assumption and NULL for the other types; `refs` becomes `refs` rows |"),
    ("| `observations.evidence`, `confidence`, `criteria`, `cause`, `effect`, `suggestion`, `refs`, `legacy_category` |",  # 9/PRO-39
     "| `observations.evidence`, `confidence`, `criteria`, `cause`, `effect`, `suggestion`, `legacy_category` |"),
    ("| `decisions` rows | items of type `decision`, with `fields` holding `decision_id`, `implementation_evidence` and the timestamps |",  # 9/PRO-39
     "| `decisions` rows | items of type `decision`: `decision_id` becomes `id` (its record id, 3.2.4), `title` becomes `text`, `decided_at` becomes `created_at`, `status` keeps its column, and `fields` holds `description`, `implementation_evidence` and `implemented_at` |"),
    ("| `deviations` rows | items of type `deviation`, `from.kind` `plan`, `text` from the description, `effect` from the impact |",  # 9/PRO-39
     "| `deviations` rows | items of type `deviation`, id `DEV-<n>` in `deviation_id` order (the old number in `fields.legacy_id`), `from.kind` `plan`, `text` from the description, `effect` from the impact, `fields.batch_origin` from `batch_origin` |"),
    ("| `messages` (SITREP, SPOTREP) | unchanged: messages are not items |",  # 9/PRO-39
     "| `session` | unchanged; `schwerpunkt` holds `main_effort`; the columns `intent` and `assessment` are added |\n| `messages` (SITREP, SPOTREP) | unchanged: messages are not items |"),
    ("for existing readers such as `intelligence-stop.py`. The views take no writes, and no index is created on a view.",  # 7/PRO-74, 9/PRO-40, 9/PRO-39 merged
     "for existing readers such as `intelligence-stop.py`. Each view column is an `items` column under its v4 name (for `decisions`: `id` AS `decision_id`, `text` AS `title`, `created_at` AS `decided_at`; for `observations`: `type` AS `category`); a v4 column that v5 keeps in `fields` is presented as NULL, because the views, like every query, do not use SQLite's JSON functions (3.6.4). The views MUST NOT accept writes, and the migration MUST NOT create an index on a view. A migrated row (one with `fields.legacy_id` or `fields.legacy_category`) is exempt from the type-specific fields 3.2.2 requires, in `validate` and in the DB's checks."),
    ("3.6.9. `--session` is removed from the **session-DB write verbs** (3.6.10) and replaced by `--db` (D874d-31).",  # 9/PRO-41
     "3.6.9. `--session` is removed from every session-DB verb that 3.6.10 lists, write or read, and replaced by `--db` (D874d-31)."),
    ("The removal ships in the same change as the hooks' switch, and the helper and hooks deploy together (3.6.12). There is no deprecated alias (D874d-57).",  # 7/PRO-75
     "The removal MUST ship in the same change as the hooks' switch to `--db`, and `aitools` MUST deploy the helper and the hooks together (3.6.12). There MUST NOT be a deprecated `--session` alias (D874d-57)."),
    ("3.6.10. The session-DB write verbs are:\n- `item add | update | list` (new);",  # 9/PRO-41
     "3.6.10. Every session-DB verb takes `--db`: the read verbs `ol list`, `decision list`, `incident list` and `search`; `log` and `directive add | list | poll | ack`, which keep their stores (`messages`, `commander_directives`); and the verbs this RFC adds or changes:\n- `item add | update | list` (new);"),
    ("- `aar --agent-id <id>` (new), which renders a delegate's rows as its AAR;",  # 9/PRO-22
     "- `aar --db <path> --agent-id <id> --brief <path>` (new), which renders the rows with that `agent_id` as the delegate's AAR, taking `provenance.mission`, `provenance.brief` and the objectives' verbatim text from the brief, and each objective's status, `how` and deliverables from the delegate's objective rows;"),
    ("These keep their stores unchanged: `log` (the `messages` table), `directive add` (`commander_directives`) and `knowledge add` (the cross-session harness DB).",  # 9/PRO-41
     "`knowledge add` keeps its store, the cross-session harness DB, and its `--session`."),
    ("3.6.11. Until schema 5 ships, nothing is written to the DB for these documents.",  # 7/PRO-76
     "3.6.11. Until schema 5 ships (section 2), agents MUST NOT write the items of these documents to the DB."),
    ("- no repo or worktree copy of `harness-db.py` may open a live session DB: tests and probes use throwaway DBs;",  # 7/PRO-77, 9/PRO-42 merged
     "- a repo or worktree copy of `harness-db.py` MUST NOT open a session DB under any `<repo>/.aitools/sessions/` directory: the hooks MUST resolve only `~/.aitools/bin/harness-db.py`, without their fallbacks to `<repo>/scripts/harness-db.py` and `~/repos/aitools/scripts/harness-db.py` (a hook that finds no deployed helper exits 0, section 6), and tests and probes MUST use throwaway DBs outside that directory;"),
    ("- the deploy reports a skipped helper or hook (an `[s]kip` at the review menu) as a WARN, because the pair must match.",  # 7/PRO-78, 9/PRO-43 merged
     "- the deploy MUST report a skipped helper or hook (an `[s]kip` at the review menu) as a WARN, because the helper and the hooks that call it (`harness-db-sessionstart.sh`, `harness-db-sessionend.sh`, `scratch-init.sh`, `command-channel-stop.sh`, `intelligence-stop.py`) are safe only at the same version;\n- the harness DB (`.aitools/harness.db`) shares `SCHEMA_VERSION`: the v5 helper records version 5 in it although its tables do not change, and a v4 helper then warns on it and changes nothing (`record_schema_version`)."),
    # 3.7
    ("3.7.1. The schemas MUST be JSON Schema files, and every document MUST have a template:",  # 7/PRO-79
     "3.7.1. Each document kind MUST have a schema, written as a JSON Schema file that names its draft in `$schema`, and a template, an empty instance:"),
    ("`harness-db.py validate --kind brief | aar | estimate <file>` implements:",  # 7/PRO-80, 9/PRO-45 merged
     "`harness-db.py validate --kind brief | aar | estimate <file>` MUST perform the checks below, MUST exit 0 when all pass, and MUST exit 1 when any fails, printing one line per violation (`<JSON path>: <rule>`) to stderr:"),
    ("`type` (with `null` allowed only where the schema says so), `required`, `properties`, `items`, `enum`, `additionalProperties: false`;",  # 9/PRO-44
     "`type` (a type name, or a two-element array whose second element is \"null\", used only where null is allowed, section 2), `required`, `properties`, `items`, `enum`, `additionalProperties: false`, and `$ref` to `#/$defs/<name>` in the same file. Each schema file holds the shared item and entry definitions (3.2) in its own `$defs`, identical in the three files, and a test compares them;"),
    ("- a `quote` is required when `source.kind` is `commander`;",  # 7/PRO-81
     "- a `quote` is present when `source.kind` is `commander`;"),
    ("- an objective that is not accomplished cites a deviation;",  # 7/PRO-82
     "- an objective whose `status` is `partly` or `not accomplished` cites at least one deviation in `deviation_refs`;"),
    ("- ids match `<TYPE>-<n>`, `R<sid4>-<n>`, `R<mission name>-<n>` or `D<sid4>-<n>`;",  # 7/PRO-83
     "- ids match `<TYPE>-<n>`, `R<sid4>-<n>`, `R<mission name>-<n>` or `D<sid4>-<n>`; a decision that keeps the id of its record (3.2.2), such as `D-DEL6`, is exempt from this check;"),
    ("- timestamps are UTC with a Z suffix;",  # 9/PRO-47
     "- timestamps are UTC in the form `YYYY-MM-DDTHH:MM:SSZ`, optionally with a fraction of 1 to 6 digits after the seconds;"),
    ("A third-party validator MUST NOT be added.",  # 7/PRO-84
     "The implementer MUST NOT add a third-party validator."),
    # 3.8, 3.9
    ("The roots it is given, `<repo>` and the dotprofile path, MAY contain spaces, and every script MUST quote them.",  # 7/PRO-85
     "The roots it is given, `<repo>` and the dotprofile path, can contain spaces, so every script MUST quote them where it expands them."),
    ("Until then, the delegation prompt restates the standing duties a delegate needs. The brief never carries them (D874d-64); the prompt still carries the prompt elements `/delegate` lists.",  # 7/PRO-86
     "Until then, the delegating agent MUST restate in the delegation prompt each of D-DEL8 to D-DEL13 that the deployed `/delegate` does not yet carry. The brief MUST NOT carry them (D874d-64), and the prompt MUST still carry the prompt elements `/delegate` lists."),
    ("MUST check that a delegation prompt gives a brief path and the instruction to read it in full (D874d-27), in observe mode first (`.claude/rules/hook-rollout.md`).",  # 9/PRO-16
     "MUST check that a delegation prompt contains an absolute path ending in `-brief.json` and the words \"read your mission brief in full\" (case-insensitive), the instruction of 3.3.5 (D874d-27), in observe mode first (`.claude/rules/hook-rollout.md`). When the prompt gives a brief path, they score `/delegate` elements 2 and 4 from the brief's `artifacts[]` and `operational_learning[]`."),
    ("3.9.4. The working copy of those files still names the brief `<sid4>_<mission name>-brief.md` in Markdown, and does not yet say the hand-back is JSON. Plan WP-2 brings them in line with this RFC (D874d-49).",  # 7/PRO-87, 9/PRO-53
     "3.9.4. The working copies of `shared/rules/delegation.md` (D-DEL10) and `shared/skills/delegate/SKILL.md` still name the brief `<sid4>_<mission name>-brief.md` in Markdown, and do not yet say the hand-back is JSON. Plan WP-2 brings them in line with this RFC (D874d-49)."),
    # sections 6, 7, 9
    ("That it outlives Claude Code on Windows MUST be verified on Windows (plan batch 4.3), not assumed.",  # 7/PRO-88
     "The implementer MUST verify on Windows (plan batch 4.3) that it outlives Claude Code there, and MUST NOT assume it."),
    ("Cursor harnesses are to be examined.",  # 7/PRO-89
     "Cursor harnesses are not yet examined (section 8)."),
    ("They MUST NOT be committed to a project repo, with one exception:",  # 7/PRO-90
     "An agent MUST NOT commit them to a project repo, with one exception:"),
    ("A history rewrite is destructive and is never done without his order.",  # 7/PRO-91
     "A history rewrite is destructive, and an agent MUST NOT rewrite history without his order."),
    ("- Agents MUST save copies of transcripts, prompts and issue bodies under a `.tmp` name.",  # 7/PRO-92
     "- An agent that saves a copy of a transcript, a prompt or an issue body in a scratch directory MUST give it a name ending in `.tmp`."),
    ("- Until this ships, harvested copies of such files MUST NOT be committed.",  # 7/PRO-93
     "- Until the harvester change above ships, an agent MUST NOT commit a harvested copy of a brief, an AAR, a transcript, a prompt or an issue body."),
    ("At session start, in any git repo where no ignore rule covers them, the harness MUST add both to that repo's `.git/info/exclude` (local, never committed) and report it once per repo (D874d-58).",  # 7/PRO-94, 9/PRO-50 merged
     "At session start, in any git repo where `git check-ignore` reports `.aitools/` or `.scratch/` as not ignored, the SessionStart hook MUST append each such entry to the file that `git rev-parse --git-path info/exclude` names (in a linked worktree `.git` is a file, not a directory; local, never committed), and MUST report it in the session that appends it; the appended entry keeps it from being reported again (D874d-58)."),
    ("Writers MUST NOT copy credentials or tokens into any item; a quote replaces them with `[redacted]` (S-24).",  # 7/PRO-95
     "Writers MUST NOT copy credentials or access tokens into any item; in a quote, the writer replaces each with `[redacted]` (3.2.1, S-24)."),
    ("A point the implementer finds unclear goes to the commander as an RFI with a suggested answer.",  # section 9, 7/PRO-2
     "The implementer MUST raise each point it finds unclear with the commander as a session RFI with a suggested answer."),
    # appendix A
    ("| D874d-74 | section 2, 3.3.1 | |",
     "| D874d-74 | section 2, 3.3.1 | |\n| D874d-75 | | Session only (the relaunch of the consistency review) |\n| D874d-76 | 3.3.1a | |\n| D874d-77 | | Session only (the false-positive report) |"),
]

for i, (old, new) in enumerate(E, 1):
    n = text.count(old)
    if n != 1:
        print(f"FAIL edit {i}: expected 1 match, found {n}: {old[:90]!r}", file=sys.stderr)
        sys.exit(1)
    text = text.replace(old, new)

open(path, "w", encoding="utf-8").write(text)
print(f"applied {len(E)} edits")
