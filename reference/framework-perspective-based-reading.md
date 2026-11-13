# Perspective-Based Reading

**Intent**: **Purpose**: Record the verified sources behind the
perspective-based reading framework and how it maps to item 9 of the
prompt-turn checklist (review the written files, one reader at a time), so an
agent can see why each line of item 9 is there and where it came from.
**Scope**: Source discipline, verified citations with verbatim quotes, the
mapping to item 9, the adaptations and what was not adopted, maintenance. NOT
the checklist item itself (`@reference/prompt-turn-checklist.md` item 9). NOT
the attack on the draft before the write (`@reference/framework-adversarial-review.md`).
NOT the registry entry (`/frameworks` skill). **Audience**: Agents running
checklist item 9 who need the why; the agent that builds the prompt-turn hook;
agents maintaining framework entries; the commander, reviewing the adoption.

v1.0 (2026-11-13)

## Source Discipline

Software engineering: software inspection and reading techniques.
Perspective-based reading (PBR) was created by the Experimental Software
Engineering Group at the University of Maryland (Victor Basili and
colleagues) and tested with professional developers at the NASA Goddard Space
Flight Center Software Engineering Laboratory.

Each source below was read in a browser (chrome-devtools) on 2026-11-13; the
PDF was text-extracted in the browser with pdf.js, and words split by a
line-end hyphen are joined. Quotes are verbatim.

### The original study

Victor R. Basili, Scott Green, Oliver Laitenberger, Filippo Lanubile, Forrest
Shull, Sivert Sørumgård, Marvin V. Zelkowitz, "The empirical investigation of
Perspective-Based Reading", *Empirical Software Engineering* 1(2), 133-164,
1996. DOI 10.1007/BF00368702: https://doi.org/10.1007/BF00368702 (Springer;
the abstract was read, the full text is paywalled).

- "The goal of PBR is to provide operational scenarios where members of a
  review team read a document from a particular perspective, e.g., tester,
  developer, user."
- "Our assumption is that the combination of different perspectives provides
  better coverage of the document, i.e., uncovers a wider range of defects,
  than the same number of readers using their usual technique."
- "Teams applying PBR are shown to achieve significantly better coverage of
  documents than teams that do not apply PBR."

### The method, described by its authors

Forrest Shull, Ioana Rus, Victor Basili, "How Perspective-Based Reading Can
Improve Requirements Inspections", *IEEE Computer* 33(7), July 2000, pp.
73-79 (IEEE Xplore document 869376). Copy on Victor Basili's University of
Maryland page: https://www.cs.umd.edu/~basili/publications/journals/J79.pdf

- Using PBR entails "selecting a set of perspectives for reviewing the
  requirements document;", "augmenting each procedure with questions for
  finding defects while creating the model; and" "applying the procedures to
  review the document."
- "Thus, in a PBR inspection, each reviewer on a team assumes a specific
  user’s perspective."
- "PBR techniques provide questions tailored to each step of the procedure
  for creating the representation."
- A reviewer, quoted: "It really helps to have a perspective because it
  focuses my questions. I get confused trying to wear all the hats!"
- "for a familiar application domain, experienced reviewers sometimes ignore
  the PBR procedure and revert to using previously acquired heuristics.
  Training and reinforcement can overcome this tendency."

## How We Adopted It

Commander, 2026-11-13 (session 90ea4d3e): "we are adoptingh adversarial
review and perspective-based reading for these reviews." Item 9 of the
prompt-turn checklist (read the written file line by line, once per reader)
was mapped to perspective-based reading in the same session.

| Item 9 line | PBR element |
|-------------|-------------|
| Name the readers | Selecting a set of perspectives (the users of the document) |
| One pass per reader | Each reviewer assumes one user's perspective |
| Ask that reader's questions | Questions tailored to each perspective's procedure |
| Read what was written; Fix and re-read; Repeat until clean | Harness-native, not from these sources |

Adaptations:

- **One agent, one pass per reader.** In PBR each reviewer on a team takes
  one perspective. In item 9 one agent reads the file several times, once for
  each perspective, in sequence.
- **The readers are the file's consumers.** PBR's perspectives are the users
  of a requirements document (designer, tester, customer). Item 9's are the
  consumers of the written file: the commander, an agent following it, a
  delegate with none of the session's context, and any script, hook or tool
  that parses it.
- **Any written file.** PBR was built for natural-language requirements
  documents; item 9 applies to every file the agent writes.

Not adopted: building each perspective's work product (a test plan, a
design) as the reading procedure, and PBR's defect taxonomy (missing,
ambiguous, inconsistent, incorrect, extraneous, miscellaneous).

## How It's Maintained

- When item 9 changes, update the mapping table here and the registry entry
  (`/frameworks` skill) together.
- Re-read a source in the browser when its URL changes, and update the
  quotes.
- The reversion the authors observed (experienced reviewers falling back on
  their own heuristics) is the failure item 9 guards against; the
  prompt-turn hook is the planned reinforcement. Today the framework has
  only the prevention layer (`@reference/framework-three-layer-governance.md`
  "Three-Layer Completeness").

## Implementing Artifacts

- `@reference/prompt-turn-checklist.md` item 9 (prevention)
- The prompt-turn hook (detection; not built, named in the checklist's
  intent)

## Cross-References

- Framework registry: `/frameworks` skill
- Companion framework, attack on the draft before the write (item 8):
  `@reference/framework-adversarial-review.md`
- Adoption cycle: `@reference/framework-adoption.md`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
