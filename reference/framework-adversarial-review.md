# Adversarial Review

**Intent**: **Purpose**: Record the verified sources behind the adversarial
review framework and how its techniques map to item 8 of the prompt-turn
checklist (review and refine the draft before writing the file), so an agent
can see why each line of item 8 is there and where it came from. **Scope**:
Source discipline, verified citations with verbatim quotes, the mapping to
item 8, the adaptations and what was not adopted, maintenance. NOT the
checklist item itself (`@reference/prompt-turn-checklist.md` item 8). NOT the
review of a file already written (`@reference/framework-perspective-based-reading.md`).
NOT the registry entry (`/frameworks` skill). **Audience**: Agents running
checklist item 8 who need the why; the agent that builds the prompt-turn hook;
agents maintaining framework entries; the commander, reviewing the adoption.

v1.0 (2026-11-13)

## Source Discipline

Military and intelligence analysis: red teaming and structured analytic
techniques.

"Adversarial review" is the harness's name for this group of techniques. The
sources do not use it as one term: the UK MOD handbook files devil's advocacy
and the pre-mortem under "red teaming", and the Tradecraft Primer files
devil's advocacy under "contrarian techniques" and the key assumptions check
under "diagnostic techniques".

Each source below was read in a browser (chrome-devtools) on 2026-11-13; the
PDFs were text-extracted in the browser with pdf.js. Quotes are verbatim.

### Red teaming, devil's advocacy and the pre-mortem (military)

UK Ministry of Defence, Development, Concepts and Doctrine Centre, *Red
Teaming Handbook*, 3rd edition, June 2021.
Page: https://www.gov.uk/government/publications/a-guide-to-red-teaming
PDF: https://assets.publishing.service.gov.uk/media/61702155e90e07197867eb93/20210625-Red_Teaming_Handbook.pdf

- 1.9: "Red teaming is defined as: the independent application of a range of
  structured, creative and critical thinking techniques to assist the end
  user make a better-informed decision or produce a more robust product."
- 1.10: "A red team is defined as: a team that is formed with the objective
  of subjecting an organisation’s plans, programmes, ideas and assumptions to
  rigorous analysis and challenge."
- 6.8: "Devil’s advocacy is a simple red teaming technique that can be used
  to challenge the confidence in a plan and identify any weak points that
  might exist."
- 6.9: "Once the plan has been developed, the devil’s advocate argues that it
  will fail and more importantly identifies the reasons why."
- 6.10: "Devil’s advocacy can be conducted by the individual on their own
  plan; however, this is difficult and involves some tricky mental
  gymnastics."
- 11.2: "Pre-mortem analysis is a red teaming technique that is very
  effective at identifying any potential problems and points of failure in a
  plan."

### Key assumptions check, devil's advocacy and red team analysis (intelligence analysis)

US Government, *A Tradecraft Primer: Structured Analytic Techniques for
Improving Intelligence Analysis*, March 2009. PDF on the CIA Center for the
Study of Intelligence site:
https://www.cia.gov/resources/csi/static/Tradecraft-Primer-apr09.pdf

- Key Assumptions Check: "List and review the key working assumptions on
  which fundamental judgments rest." Method, step 3: "Challenge each
  assumption, asking why it “must” be true and whether it remains valid under
  all conditions."
- Technique groups: "contrarian techniques explicitly challenge current
  thinking".
- Devil's Advocacy: "Challenging a single, strongly held view or consensus by
  building the best possible case for an alternative explanation."
- Team A/Team B: "forcing analysts to argue “the other side” can often make
  them more aware of their own mind-set."
- Red Team Analysis: "Models the behavior of an individual or group by trying
  to replicate how an adversary would think about an issue." In the Primer,
  red team analysis models an adversary's thinking. Item 8's "Red team it"
  follows the UK MOD sense instead: challenge of one's own plan.

### Pre-mortem

Gary Klein, "Performing a Project Premortem", *Harvard Business Review*,
September 2007 (reprint F0709A).
https://hbr.org/2007/09/performing-a-project-premortem

- Publisher's summary on the page: "In a premortem, team members assume that
  the project they are planning has just failed—as so many do—and then
  generate plausible reasons for its demise."
- Opening of the article: "Projects fail at a spectacular rate. One reason is
  that too many people are reluctant to speak up about their reservations
  during the all-important planning phase."
- The rest of the article is behind the HBR paywall and was not read.

## How We Adopted It

Commander, 2026-11-13 (session 90ea4d3e): "we are adoptingh adversarial
review and perspective-based reading for these reviews." Item 8 of the
prompt-turn checklist (attack the draft in thinking before writing the file)
was mapped to adversarial review in the same session.

| Item 8 line | Source technique |
|-------------|------------------|
| Red team it | Red teaming: plans and assumptions subjected to "rigorous analysis and challenge" (UK MOD handbook 1.10) |
| Pre-mortem it | Pre-mortem (Klein 2007; UK MOD handbook 11.2) |
| Check key assumptions | Key assumptions check (Tradecraft Primer 2009) |
| Argue the other side | Devil's advocacy (UK MOD handbook 6.8-6.10; Tradecraft Primer), and the Primer's Team A/Team B ("argue “the other side”") |
| Check it against its sources; Look for overcorrection; Repeat until clean | Harness-native, not from these sources |

Adaptations:

- **One agent, in thinking.** The sources prefer a separate red team or a
  designated devil's advocate (UK MOD handbook 1.9: "best conducted by a
  separate red team"). Item 8 has the drafting agent attack its own draft,
  which the handbook calls difficult (6.10). An independent review is
  available through delegation: a separate delegate that did not see the
  author's notes (`/delegate` skill, "Reviews").
- **Before the write.** The sources apply the techniques to a plan before it
  is committed to; item 8 applies them to a draft before it is written to a
  file.

Not adopted: red team analysis in the Primer's own sense (modelling an
adversary's decisions), the separate contrarian paper, the Team A/Team B
debate phase, and the group setting of the pre-mortem.

## How It's Maintained

- When item 8 changes, update the mapping table here and the registry entry
  (`/frameworks` skill) together.
- Re-read a source in the browser when its URL changes or a new edition
  appears (the UK MOD handbook is in its 3rd edition), and update the quotes.
- Today the framework has only the prevention layer: the prompt-turn hook
  that will deliver the checklist is not built
  (`@reference/framework-three-layer-governance.md` "Three-Layer
  Completeness").

## Implementing Artifacts

- `@reference/prompt-turn-checklist.md` item 8 (prevention)
- The prompt-turn hook (detection; not built, named in the checklist's
  intent)

## Cross-References

- Framework registry: `/frameworks` skill
- Companion framework, review of the written file (item 9):
  `@reference/framework-perspective-based-reading.md`
- Adoption cycle: `@reference/framework-adoption.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
