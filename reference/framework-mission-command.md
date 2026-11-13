# Mission Command

**Intent**: **Purpose**: Record the verified sources behind the mission
command framework and how it maps to items 2 and 4 of the prompt-turn
checklist (fix the meaning of the order; resolve what you can with
disciplined initiative), so an agent can see where those items come from.
**Scope**: Source discipline, verified citations with verbatim quotes, the
mapping to items 2 and 4, what was not adopted, maintenance. NOT the checklist
items themselves (`@reference/prompt-turn-checklist.md` items 2 and 4). NOT the
surfacing of open points (`@reference/framework-request-for-information.md`).
NOT the registry entry (`/frameworks` skill). **Audience**: Agents running
checklist items 2 and 4 who need the why; the agent that builds the
prompt-turn hook; agents maintaining framework entries; the commander,
reviewing the adoption.

v1.0 (2026-11-13)

## Source Discipline

Military command and control: mission command (US Army doctrine), which was
modeled on Auftragstaktik, the Prusso-German command philosophy the
Bundeswehr calls Führen mit Auftrag.

Each source below was read in a browser (chrome-devtools) on 2026-11-12 (local
date) by mission S2-Prov; PDFs were text-extracted in the browser with pdf.js,
and words split by a line-end hyphen are joined. Quotes are verbatim.

### ADP 6-0, Command and Control (2026)

Headquarters, Department of the Army, *ADP 6-0 Command and Control*, 07 July
2026 (supersedes the 31 July 2019 edition).
Record: https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=1033415;
PDF: https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN47032-ADP_6-0-000-WEB-1.pdf

- "Successful mission command is enabled by the principles of— • Competence.
  • Mutual trust. • Shared understanding. • Commander's intent. • Mission
  orders. • Disciplined initiative. • Risk acceptance."
- 1-77: "Disciplined initiative refers to the duty individual subordinates
  have to exercise initiative within the constraints of the commander's
  intent to achieve the desired end state. Simply put, disciplined initiative
  is when subordinates have the discipline to follow their orders and adhere
  to the plan until they realize that their orders and the plan are no longer
  suitable for the situation in which they find themselves."
- 1-77 (continued): "The subordinate leader then takes action on their own
  initiative to adjust to the new situation and achieve their commander's
  intent, reporting to the commander about the new situation when able to do
  so."
- 1-78: "Leaders and subordinates who exercise disciplined initiative create
  opportunities by taking action to develop a situation without asking for
  further guidance."
- 1-81: "If time permits, subordinates attempt to communicate their new
  situation and recommended course of action to their commander."
- 1-90: "To the greatest extent possible, they report what they intend to do
  and then execute unless their commander specifically denies them
  permission."

The 2026 edition does not mention Auftragstaktik or the confirmation brief.

### Auftragstaktik as the origin

Trent J. Lythgoe, "Beyond Auftragstaktik: The Case Against Hyper-Decentralized
Command", *Joint Force Quarterly* 96, NDU Press, 2020:
https://ndupress.ndu.edu/Media/News/News-Article-View/Article/2076032/beyond-auftragstaktik-the-case-against-hyper-decentralized-command/

- "Auftragstaktik, a Prusso-German command philosophy that emphasizes
  decentralization, commander's intent, and low-level initiative."
- "The U.S. Army explicitly modeled its mission command doctrine on
  Auftragstaktik for good reason."

Zentrum Innere Führung, *Handbuch Innere Führung*, 1. Auflage 2023, chapter 6
"Führen mit Auftrag", pp. 48-51:
https://www.bundeswehr.de/resource/blob/5688200/28a99fcb8797e1ffab57965beed697a7/100-1-1-handbuch-data.pdf

- p. 48: "Das militärische „Führen mit Auftrag", auch als „Auftragstaktik"
  bekannt, beschreibt nicht nur eine bestimmte Vorgehensweise, sondern steht
  für eine ganze Führungsphilosophie." (Military "leading by mission", also
  known as Auftragstaktik, is a whole philosophy of command, not only a
  procedure.)
- p. 49: "Sie müssen den Auftrag, den ihre unmittelbare Vorgesetzte oder ihr
  unmittelbarer Vorgesetzter erhalten hat, kennen und verstehen." (They must
  know and understand the mission their immediate superior received.)
- p. 49: "Diese Selbständigkeit beinhaltet die Bereitschaft, entgegen einem
  veralteten Befehl zu handeln, sofern die Lage dies erfordert.
  Selbstständigkeit ist dabei allerdings nicht mit Eigenmächtigkeit zu
  verwechseln!" (This independence includes the readiness to act against an
  outdated order when the situation requires it; independence is not to be
  confused with acting without authority.)

### Backbrief and confirmation brief

FM 1-02.1 *Operational Terms*, May 2026:
https://armypubs.army.mil/epubs/DR_pubs/DR_a/ARN46659-FM_1-02.1-000-WEB-1.pdf

- "backbrief – A briefing by subordinates to the commander to review how
  subordinates intend to accomplish their mission. (FM 6-0)"
- "confirmation brief – A brief subordinate leaders give to the higher
  commander immediately after the operation order is given to confirm
  understanding. (ADP 5-0)"

## How We Adopted It

| Doctrine | Harness artifact |
|----------|------------------|
| Confirmation brief, backbrief: confirm understanding of the order before execution | Checklist item 2: mark the prompt's high-impact words and fix their meaning before acting; an unresolved word is carried to items 4 and 5, never guessed |
| Disciplined initiative within the commander's intent (1-77) | Checklist item 4: resolve what you can without the commander; deviate from the process or an order only to accomplish the mission |
| Report the new situation when able (1-77, 1-81, 1-90) | Item 4 "Report every deviation"; item 5 surfaces what stays open, with a suggested answer |
| Act "without asking for further guidance" (1-78) | Item 4 "Do not ask what you can find out" |
| Independence is not acting without authority (Handbuch, p. 49) | Item 4 "Some choices are not yours": intent, priority, preference and hard-to-reverse actions belong to the commander |

The commander's direct order on the prompt turn supersedes every other order
(checklist item 12, "How to respond").

Not adopted: the German *Rückfragepflicht* (duty to ask back). No public
authoritative source was found (the Handbuch Innere Führung has no hit; HDv
100/100 *Truppenführung* is not public), so it is not cited. Risk acceptance,
competence and mutual trust, the other principles of mission command, are not
mapped to a checklist item.

## How It's Maintained

- Re-verify the ADP 6-0 and FM 1-02.1 citations when a new edition supersedes
  them (armypubs.army.mil records the supersession).
- When checklist items 2 or 4 change, update the table above and the
  registry entry together.
- A source for *Rückfragepflicht* found later is added here first, then to
  item 2's "Adopted from" line.

## Implementing Artifacts

- `@reference/prompt-turn-checklist.md` items 2 and 4 (and their "Adopted
  from" lines)
- This file
- Registry entry "Mission command" (`/frameworks` skill)

## Cross-References

- Surfacing what stays open: `@reference/framework-request-for-information.md`
- Reviews in items 8 and 9: `@reference/framework-adversarial-review.md`,
  `@reference/framework-perspective-based-reading.md`
- Adoption lifecycle: `@reference/framework-adoption.md`
- Governed terms: `/glossary` skill (thinking along, mission order)
