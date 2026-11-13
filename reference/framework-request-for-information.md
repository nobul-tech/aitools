# Request for Information

**Intent**: **Purpose**: Record the verified sources behind session RFIs and
how they map to item 5 of the prompt-turn checklist (surface what you cannot
resolve and what you find), so an agent can see where each rule of item 5
comes from and which rules are the harness's own. **Scope**: Source
disciplines, verified citations with verbatim quotes, the mapping to item 5,
the harness-native additions, maintenance. NOT the checklist item itself
(`@reference/prompt-turn-checklist.md` item 5). NOT resolving points before
surfacing them (`@reference/framework-mission-command.md`). NOT the governed
definition (`/glossary` skill, term "session RFI"). NOT the registry entry
(`/frameworks` skill). **Audience**: Agents running checklist item 5 who need
the why; the agent that builds the prompt-turn hook; agents maintaining
framework entries; the commander, reviewing the adoption.

v1.0 (2026-11-13)

## Source Disciplines

Two fields use the request for information (RFI): construction contract
administration and military intelligence doctrine.

Each source below was read in a browser (chrome-devtools) on 2026-11-12
(local date) by mission S2-Prov; the AIA summary quote was re-checked by the
Session Commander on 2026-11-13. PDFs were text-extracted in the browser with
pdf.js. Quotes are verbatim.

### Construction: AIA G716–2004

AIA Contract Documents help center, "Summary: G716™–2004, Request for
Information (RFI)": https://help.aiacontracts.com/hc/en-us/articles/1500009444782
(the form itself is paywalled; the publisher's summary and instructions were
read).

- "AIA Document G716–2004 provides a standard form for an owner, architect,
  and contractor to request further information from each other during
  construction."
- "The RFI is utilized to obtain information that the requesting party cannot
  obtain through research, document review, or other reasonable means. A RFI
  that is already contained or provided for in the contract documents may
  result in additional administrative charges. RFI’s should be numbered,
  logged and tracked through a document management logging system."

AIA help center, "Instructions: G716™–2004, Request for Information (RFI)":
https://help.aiacontracts.com/hc/en-us/articles/1500009325281

- "Sender's Recommendation. If the sender is seeking a solution or answer to a
  site or construction condition, the sender may include a recommended
  solution based on the sender's expertise and the options available,
  including any known affects on cost or schedule." ("affects" is the AIA's
  spelling.)
- "Receiver's Response. Provide an answer to the RFI in concise terms…"

Corroboration: City of Los Angeles, Bureau of Engineering, Project Delivery
Manual 16.2 "Request for Information" (revised 2018):
https://projectdeliverymanual.engineering.lacity.gov/chapter-16-construction-management-procedures/162-request-information

- "All RFIs should be sequentially numbered starting with the number one."

### Military: the DOD RFI and intelligence reach

FM 1-02.1 *Operational Terms*, May 2026, giving the DOD definition from JP 2-0
(JP 2-0 itself is not public at a stable URL and was not read):
https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN46659-FM_1-02.1-000-WEB-1.pdf

- "request for information – (DOD) 1. Any specific, time-sensitive, ad hoc
  requirement for intelligence information or products to support an ongoing
  crisis or operation not necessarily related to standing requirements or
  scheduled intelligence production. Also called RFI. (JP 2-0)"

FM 2-0 *Intelligence*, October 2026:
https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN47897-FM_2-0-000-WEB-2.pdf

- "Use intelligence reach first to fill intelligence gaps and requirements
  and to answer requests for information. This technique can preclude
  unnecessary tasking or risk to limited collection assets."

## How We Adopted It

| Source practice | Item 5 rule |
|-----------------|-------------|
| "numbered, logged and tracked"; "sequentially numbered starting with the number one" | **Number**: `<sid4>-<n>`, rising through the session, never reused |
| Only for information the requester "cannot obtain through research, document review, or other reasonable means"; "intelligence reach first" | Items 4 and 5: resolve what you can first; "Do not ask what you can find out" |
| "Sender's Recommendation" | **Suggest an answer**: the `Suggest:` line with its reason |
| "Receiver's Response" | The commander's answer closes the session RFI |
| "Reference/Attachments" | **Context in the body**: evidence, problems found, the agent's own mistakes, a delegate's report verbatim |

Harness-native (not claimed from the sources): every session RFI is a
question; one issue per RFI, standing alone; work that depends on an open RFI
is held; new RFIs are batched in one reply; every open session RFI is
reprinted in full at the end of every turn until answered or withdrawn. No
source found says "open until answered" in those words.

## How It's Maintained

- Re-verify the AIA pages and the FM citations when they change or a new
  edition supersedes them.
- When item 5 changes, update the table above, the glossary term "session
  RFI" (`/glossary` skill) and the registry entry together.

## Implementing Artifacts

- `@reference/prompt-turn-checklist.md` item 5 (and its "Adopted from" line)
- Governed term "session RFI" and the redefined "surfacing duty" (`/glossary`
  skill)
- This file
- Registry entry "Request for information" (`/frameworks` skill)

## Cross-References

- Resolving before surfacing: `@reference/framework-mission-command.md`
- Incident tracking for what must outlive the session:
  `@reference/framework-incident-governance.md`
- Adoption lifecycle: `@reference/framework-adoption.md`
