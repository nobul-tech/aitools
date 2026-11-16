# 874d-3-spec-verify: traceability of issue #180 v5.2 into RFC 0011, the plan and the 874d-2 brief

v1.0 (2026-11-16), mission 874d-3-spec-verify. Line numbers: RFC = rfcs/RFC-0011-structured-reports.md,
plan = plans/structured-reports/implementation-plan.md, brief = .scratch/session-dbd05b0c-.../874d-2-structured-reports-brief.json.
Citation lines from data/cites.txt (cites.py). Verdict: OK = carried faithfully; SUP = superseded, and how it is carried;
GAP = not carried where it should be; MIS = carried with a misstatement. OBS-n = observation in the AAR.

## Decisions D874d-1 to D874d-53

| ID | RFC | Plan | Brief | Verdict |
|---|---|---|---|---|
| 1 | 3.2.2 L191 (barrier analysis) | - | L249 | OK for barrier analysis; node set superseded (D874d-19/-22/-29) is not said in RFC: SUP not carried (OBS-1) |
| 2 | - | - | - | SUP by D874d-22; not carried as superseded (OBS-1) |
| 3 | - | - | - | SUP by D874d-22/-28; not carried (OBS-1) |
| 4 | - | - | - | SUP by D874d-29; not carried (OBS-1) |
| 5 | - | - | L262 | GAP in RFC: post-merge learning = observations/OL not stated (OBS-1) |
| 6 | - | - | - | GAP: SALUTE FINDING retired, SPOTREP (shipped PR #181); uncited (OBS-1) |
| 7 | 3.7.1 (content, uncited) | WP-1 | L275 | OK in substance; uncited in RFC (OBS-1) |
| 8 | 3.5.1 L320 | - | L288 | OK in RFC; brief quote is the commander's question, not his decision (OBS-15) |
| 9 | 3.5.1 L320 | - | L150, L301 | OK |
| 10 | - | - | L150 (constraint) | GAP in RFC (out of scope not stated) (OBS-1, OBS-20) |
| 11 | - | - | L150 | GAP in RFC (OBS-1, OBS-20) |
| 12 | - (objectives[] carry it) | - | - | OK in substance, uncited (OBS-1) |
| 13 | 3.3.5 L271, 3.9.1 | - | L314 | OK |
| 14 | 3.2.2 L164, 3.4.2 | - | L327 | OK |
| 15 | 3.2.2 L173 | - | L340 | OK |
| 16 | via D-DEL9 (3.2.3, 3.4.6) | - | - | OK in substance, uncited (OBS-1) |
| 17 | 3.2.2 L164, section 2 | - | L353 | OK |
| 18 | section 2 (synonyms) | - | - | OK in substance, uncited (OBS-1) |
| 19 | 3.1.3 L106, 3.4.4 L288 | - | L366 | OK |
| 20 | 3.2.2 L159 | - | L379 | OK |
| 21 | 3.2.3 L209 | - | L392 | OK |
| 22 | 3.1.3, 3.2.2 L149, 5 | - | L405 | OK |
| 23 | 3.2.2 L143, 3.4.4 | - | L418 | OK (3.4.4 bullet has no RFC 2119 keyword) |
| 24 | 3.2.2 L191 | - | L431 | OK |
| 25 | 3.2.1 L121, 3.6.3 | - | L444 | OK for DB rows; S-18 relaxes the issue's "Fields every item carries" in documents (OBS-5) |
| 26 | 3.1.3, 3.3.7, 5 | - | L457 | OK |
| 27 | 3.3.5 L270-272 | 4.1 (hook) | L470 | OK; hook update not normative in RFC, only in section 8 table (low, folded in OBS-1 proposal) |
| 28 | 3.6.7 L388, 5 | - | L483 | OK (RFI 874d-13 suggested findings -> observations; transcript L897) |
| 29 | 3.1.4, 3.2.2, 3.2.3, 3.4.5 | - | L496 | OK |
| 30 | - | - | L509 | GAP: no rule that schema fields are governed terms; `objective` is not a governed term (glossary.json has none) (OBS-2) |
| 31 | 3.6.3, 3.6.5 | 3.2 | L522 | OK |
| 32 | 3.1.3, 3.3.4 | - | L535 | OK |
| 33 | 3.4.9, 5, 6 | 3.5 | L548 | OK; fallback circular (OBS-22) |
| 34 | 3.2.2, 3.4.4 | - | L561 | OK |
| 35 | 3.5.1, 5 | - | L574 | OK |
| 36 | 3.3.1 L228 | - | via D874d-42 text | SUP (name/format) by D874d-42; location stands; OK |
| 37 | section 2 list | 2.2 | L587 | OK in substance, uncited in RFC (OBS-1) |
| 38 | - | - | - | session-process decision; uncited (OBS-1) |
| 39 | - | - | via D874d-41 text | SUP by D874d-41; not carried as superseded in RFC (OBS-1) |
| 40 | - | - | - | session-process decision (limited by D874d-46); uncited (OBS-1) |
| 41 | 3.2.4, 3.8 | 2.3 | L600 | OK; WP-2 grep misses D-SR / "RFI 874d-" instances (OBS-11) |
| 42 | 3.3.1, 3.8, 5 | 2.1 | L613 | OK (AAR part SUP by -47, carried) |
| 43 | 3.2.2 L181 only | - | L626 | GAP/MIS: item type enum (3.2.1) and v4->v5 mapping (3.6.7) omit `fact` (OBS-3) |
| 44 | 3.5.5, 3.6.1, 3.8 | 3.4 | L639 | OK |
| 45 | section 8 L527 | G0 | - | OK |
| 46 | - | - | - | session-process, "for this version only"; uncited (OBS-1) |
| 47 | 3.3.3, 3.4.1, 3.4.7, 5 | 2.1 | L652 | OK |
| 48 | 3.6.1 | - | L665 | OK |
| 49 | 3.9.2, 8 | WP-2 | L678 | OK; WP-2 scope misses stale ids and PERMISSION_DENIED (OBS-11) |
| 50 | 3.3.3, 3.4.1 | 2.1 | L691 | OK |
| 51 | 3.5.5 L344 | 4.3 | L704 | OK; brief quote elided with an ellipsis (OBS-16) |
| 52 | 3.5.5, 5, 7 | 4.3 | L717 | OK in RFC; RFC 0010 section 7 and aitools-workspace.md still say the export is tracked (OBS-10); brief constraint widened to "the commander's words" (OBS-13) |
| 53 | 3.5.5, 3.8, 6 | 4.3 | L730 | OK; "Paths MUST NOT contain spaces" over-generalizes (OBS-21) |

## Points the issue left open (section 6) and WP-0

| ID | RFC | Plan | Brief | Verdict |
|---|---|---|---|---|
| ASM-1 | 3.4.9 | 3.5 probe | ASM-1 | OK; fallback circular (OBS-22) |
| ASM-2 | S-10, 3.6.6 | 3.3 test | ASM-2 | OK; brief status "unverified" vs issue "Partly verified" (OBS-18) |
| ASM-3 | S-9, 3.4.8 | 3.5 probe, 2.1 fallback | ASM-3 | OK |
| ASM-4 | S-9, 3.3.8 | no probe | ASM-4 | GAP: issue says "WP-2 probe" (OBS-9) |
| ASM-5 | 3.6.5 | - | ASM-5 | OK |
| ASM-6 | S-11, 3.6.2 | 3.3 test | ASM-6 | OK |
| ASM-7 | S-6, 3.7.2 | 1.4 | omitted | OK in RFC; brief omits (OBS-19) |
| ASM-8 | - | G1 | ASM-8 | OK; G1 extends R874d-27 to the RFC/plan (OBS-7) |
| AMB-1 | 3.4.1 | 2.1 | AMB-1 | OK; brief source.kind agent for the commander's words (OBS-17) |
| AMB-2 | S-1, 3.7.1 | WP-1 | AMB-2 | OK (matches issue suggestion) |
| AMB-3 | S-2, 3.5.3 | - | AMB-3 | OK (RFC widens to intent and objectives; no defect) |
| AMB-4 | 3.5.5 | 4.3 | omitted | OK in RFC; brief omits (OBS-19) |
| AMB-5 | S-3, 3.3.6 | - | AMB-5 | OK |
| AMB-6 | 3.6.11 | - | omitted | OK in RFC; brief omits (OBS-19) |
| AMB-7 | S-4, 3.2.5 | - | AMB-7 | OK |
| AMB-8 | S-5, 3.6.4 | 3.1 | AMB-8 | OK; RFC 0010 citation does not support the JSON-function claim (OBS-23) |
| AMB-9 | 3.2.4 (partly) | - | omitted | rule ids not stated (low, OBS-19) |
| AMB-10 | 3.8 | 4.3 | AMB-10 | OK |
| WP-0 | sections present | WP-0 status | out_of_scope | Done-when "Every decision of section 1 is cited" fails (OBS-1); "verdict posted on the PR" has no PR (OBS-26); ROADMAP row not moved, and none exists (OBS-8) |
| WP-1..6 | section 8 | WP-1..6 | OBJ-2..7 | Retirement leaves 6 referrers outside every batch (OBS-10); type changes skip framework-intelligence-types maintenance (OBS-12); WP-6 glossary check dropped (OBS-25) |

## Quotes in the 874d-2 brief

check_quotes.py: every `quote` and every quoted span in `source.location` of the brief's decisions, objectives,
assumptions, ambiguities, constraints and operational learning was found verbatim in the commander's prompts
(transcript L79-L2553) or in issue #180 (body and comments). The six OBJ-2..7 location spans are plan section
headings, verbatim against the plan (L52, L64, L77, L89, L98, L105). Defects are of choice, not of text: OBS-15
(D874d-8 quotes the question), OBS-16 (D874d-51 elides with "…"), OBS-17 (ambiguity passages marked agent).
