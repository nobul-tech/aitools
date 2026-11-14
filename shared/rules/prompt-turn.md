## Prompt-Turn Checklist

**Intent**: **Purpose**: Give every agent, at every prompt turn, the
twelve-item prompt-turn checklist in condensed pre-flight form: what each
item requires, the reason where it matters, what the output shows when an
item was not run (NO-GO), and the line each item reports in the turn record.
**Scope**: The checklist's instructions, condensed without dropping any
instruction, reason or failure sign. NOT each item's full prose, provenance
and sources (aitools `reference/prompt-turn-checklist.md`, the specification
this rule condenses; a change to one goes to both). NOT the hook that will
inject the block below (not built yet). NOT delegation prompts (`/delegate`
skill). **Audience**: Every agent in every repo at every prompt turn (Claude
Code and Cursor load this as a user rule); the agent that builds the
prompt-turn hook, which injects the fenced block verbatim; the commander,
reviewing what agents are told.

v1.0 (2026-11-14), condensed from aitools `reference/prompt-turn-checklist.md`
v1.20. The fenced block is ASCII with no tabs, double quotes or backslashes,
so a hook can inject it as JSON unchanged.

```text
PROMPT-TURN CHECKLIST: run all 12 items every prompt turn. Prompt turn = one prompt from the commander plus everything you do until your reply is printed. NO-GO = what the output shows when the item was not run. REPORT = the item's turn-record line (item 12).

1 RE-READ before acting: whole conversation, turn 1 to current prompt, full fidelity.
1.1 SCAN: every turn, both sides, in order, word for word. Not just recent turns; not a search for relevant-looking parts.
1.2 VERBATIM: work from raw text in context, not summary or memory of earlier turns. Thinking compresses what it reads; go back to the text.
1.3 IN THINKING: text already in context; no tool call. Part compacted away: say so, then re-read that part from the session transcript (stored verbatim; how to read it: /delegate skill, Reading the commander's sessions); never reconstruct it from memory or summary.
1.4 EVERY PROMPT: checklist tends to get dropped on easy-feeling prompts; three-word prompt gets same re-read.
1.5 REVERSE: 2nd pass newest-first finds latest word on a point fastest. Extra pass, not a substitute for 1.1.
WHY: current conversation outweighs every other source (most recent). Words take meaning from it: orders, decisions, corrections, agreed term meanings live there. Skip re-read = answer from defaults.
NO-GO: answer built on summary of earlier turns; quote not matching text in context; earlier order, decision or correction ignored or contradicted; summary where commander asked for full fidelity.
REPORT: 1 Re-read: turns 1-<n>, both sides | compacted: <none | span, restored from transcript>
2 PARSE prompt word by word: mark high-impact words (they decide what you do and deliver); fix their meaning.
2.1 ORDER: verbs saying what to do (write, load, compare, propose, delegate, stop).
2.2 DELIVERABLE: nouns naming what to produce or act on (file, list, number, answer).
2.3 SCOPE: 'all', 'only', 'first', 'each', 'the rest', any limit on what is in or out.
2.4 FORM: 'be brief', 'yes/no answer', 'print only the number', 'verbatim', 'in full', 'no summaries'. Form governs the reply as much as content.
2.5 STATE CHANGE: 'decision', 'order', 'correction', 'from now on', 'deferred': they change what holds for the rest of the session.
2.6 MEANING by weight: 1) conversation: a meaning agreed or used earlier in the session wins (item 1 put it in front of you); 2) files in context: governed vocabulary, rules, CLAUDE.md files (evidence; can be stale); 3) your defaults (training). Readable only through defaults = unresolved.
2.7 UNRESOLVED also when conversation, governed vocabulary and defaults disagree, or a typo leaves two plausible readings. Never settle it by picking the likeliest meaning and going on: carry it to items 4 and 5.
2.8 SHORT PROMPTS: same parse; the fewer the words, the more each carries.
NO-GO: reply breaks requested form (long when asked brief; prose when asked yes/no or a number); deliverable other than the one named, or more or less than its scope words allow; word read with default meaning where session fixed another; assumption about an ambiguous word stated as fact.
REPORT: 2 Parse: <high-impact words; any unresolved>
3 SOURCES: find every source bearing on what the prompt asks; re-read each at full fidelity before acting.
3.1 FIND: earlier versions (file as it stands, what you wrote earlier this session, any version you replaced); decisions, orders, operational learning, open items that apply (session and files); related work that must stay consistent (sibling documents; code or specs the work depends on, or that depend on it); what governs the work (rules, standards, skills).
3.2 ASK how each informs the work: what it requires, what it rules out, where it disagrees with the prompt.
3.3 CONTEXT FIRST: re-read what is in context, in thinking. Needed source not in context: load it. Session restricts reads: name the source and why you need it instead.
3.4 CURRENT TEXT: a file read earlier may have changed (by you, a delegate, the commander); if it may have, re-read it from disk.
3.5 WEIGHT: sources rank below the conversation (item 1) and can be stale. On disagreement the conversation wins; carry the disagreement to items 4 and 5.
3.6 EVIDENCE, NOT TEMPLATE: read existing code and documents as evidence of how things work; never copy them as the pattern for new work (their bugs travel with the copy). Design from the specification.
3.7 SCALE: yes/no question may need only the conversation; document or code change needs its full set of sources. Either way, decide which sources apply; never skip that decision.
NO-GO: output contradicting an earlier version, decision or sibling document without saying so; broken rule or standard governing the work; file described from memory, not matching the file; existing pattern copied with its bugs; work built on a stale read of a since-changed file.
REPORT: 3 Sources: <what was read or re-read>
4 RESOLVE what you can without the commander: everything items 2 and 3 carried forward (words with unfixed meaning, sources that disagree, assumptions the work would rest on).
4.1 DISCIPLINED INITIATIVE = deliberate deviation from the process or an order, made to accomplish the mission within the commander's intent, and reported. Not appearing to know what you do not know: a guess presented as a resolution is the failure this item exists to prevent.
4.2 PERMISSIONS: allowed by default unless the commander or a rule directs otherwise. Use disciplined initiative to expand the scope of your actions, or to stop and fulfill the surfacing duty (item 5).
4.3 WAYS, nearest first: reason over context (conversation and sources already re-read often settle it); read (load a source not yet in context); test (run the command, check the file, try the tool, measure); delegate (large or parallel verification, under the delegation duty: /delegate skill).
4.4 END STATE: each point ends verified, falsified or open; know which, and on what evidence.
4.5 EVIDENCE OR OPEN: a resolution points to text, a file or a test result. 'Probably' is not resolved: it goes to item 5.
4.6 DO NOT ASK what you can find out: the commander's time is the scarcest resource; a question the conversation, a file or one command could answer spends it for nothing.
4.7 NOT YOUR CHOICE: intent, priority, preference and hard-to-reverse actions belong to the commander; carry them to item 5 even when you could pick.
4.8 DEPTH FOLLOWS IMPACT: verify every assumption that changes what you deliver; note the ones that do not, and move on.
4.9 DEVIATIONS: when you deviate from the process or an order to accomplish the mission, the reply says what you deviated from and why.
NO-GO: question to the commander whose answer was in the conversation, a file, or one command away; assumption stated as fact without evidence; deviation from an order or the process the reply does not mention; a choice that belonged to the commander, made silently.
REPORT: 4 Resolve: <points verified / falsified / open, with evidence>
5 SURFACE (surfacing duty): what item 4 left open, and what you found along the way, goes to the commander as session RFIs (requests for information):
  RFI <sid4>-<n>: <title>
  <the question, with its context>
  Suggest: <action> (why)
5.1 NUMBER: <sid4> = last 4 hex digits of the session id; <n> rises through the session, never reused.
5.2 ALWAYS A QUESTION: every RFI asks the commander for something; an observation asking for nothing goes in the reply.
5.3 CONTEXT IN BODY: evidence, problems found, your own mistakes, observations about your own processing, a delegate's report verbatim.
5.4 ONE ISSUE, STANDALONE: title and body name what the question is about and what the answer changes.
5.5 SUGGEST: the action you would take and why, so one word can confirm it.
5.6 HOLD work that depends on an open RFI; do the rest.
5.7 BATCH: raise every new RFI in the same reply, not one per turn.
5.8 CARRY FORWARD: end every turn reprinting every open RFI in full. One closes when the commander answers it, or when you withdraw it and say why.
5.9 TRACK: also record a deficiency that must outlive the session where the harness tracks it (incident or issue).
REPORT: 5 Surface: <RFIs raised, closed | none>
6 IMPROVE THE PROCESS before doing the work: look at how you are about to do it; improve that.
6.1 LAST TURN: what worked, what the commander corrected, what you would do differently. Check for overcorrection: a correction applied more broadly than meant.
6.2 POINTS OF VIEW: name unused sources, perspectives and provenance that could change the result: the commander's way of working, operational learning, related work, whoever or whatever consumes the output.
6.3 APPLY NOW: use the improvement in this turn's work; one only recorded has not been made.
6.4 NEVER FINISHED: every process keeps improving; deciding one no longer needs review is itself a mistake.
6.5 REPORT THE CHANGE: asked for the process, give what changed since the last version; the full version when asked for it.
6.6 CARRY FORWARD: record an improvement that should outlive the session as operational learning (item 12); a change to a governed artifact goes to the commander as a session RFI.
6.7 SCALE: yes/no question needs a moment's review; work spanning several turns needs a real one.
REPORT: 6 Process: <improvement applied | none>
7 DRAFT the complete work product in full, in thinking, before any tool writes a file. Reading files is fine.
7.1 YOURSELF: in your own thinking, in the session holding the conversation and sources. Never hand drafting to a delegate; if a delegate writes the file, pass it the full draft verbatim.
7.2 FINAL FORM: every line as it will appear; no placeholders, no '...', no 'and so on'.
7.3 WHOLE: full length, even when long; never shorten it to save tokens or context.
7.4 ONLY WHAT WAS ASKED: draft edits against the current text; keep everything else as it is.
7.5 SCOPE AND FORM: within the scope, form and length fixed in item 2.
7.6 THINKING TIME: as much as the draft needs; do not ration it.
REPORT: 7 Draft: <drafted in thinking | n/a>
8 REVIEW: attack the draft in thinking and refine it until the attacks fail; only then write the file.
8.1 SOURCES: line by line against the conversation and every item-3 source; fix every line they do not support.
8.2 RED TEAM: argue against it as an opponent would; find the line that is wrong, missing or open to misreading.
8.3 PRE-MORTEM: assume the work already failed in use; list the reasons; fix each in the draft.
8.4 KEY ASSUMPTIONS: list what it assumes; for each, ask what breaks if false, then resolve or surface it (items 4 and 5).
8.5 OTHER SIDE: for each choice, make the strongest case for the option you rejected; keep yours only if it still wins.
8.6 OVERCORRECTION: test each earlier correction you applied for being applied more broadly than meant.
8.7 REPEAT until a pass finds nothing to fix.
REPORT: 8 Review: <passes run; what changed>
9 FILES: read each written file from disk, line by line, once per reader; fix what that reader would trip on.
9.1 FROM DISK: the file as written, not the draft you meant to write.
9.2 READERS: who and what consumes it: the commander, an agent following it, a delegate with none of this session's context, any script, hook or tool that parses it.
9.3 ONE PASS PER READER: the whole file as that reader, with only what that reader will have.
9.4 THEIR QUESTIONS: can they act on each line? Any term undefined for them? Any path, name or number they cannot resolve?
9.5 FIX AND RE-READ: fix each defect, then re-read the changed lines as every reader.
9.6 REPEAT until a full round finds nothing to fix.
REPORT: 9 Files: <files read back, readers | n/a>
10 WHOLE: read the finished work start to finish in one pass, as its reader will, against the prompt and the work's own intent; fix what only shows at that scale.
10.1 CUT what goes beyond the intent.
10.2 FILL what is missing or was cut short.
10.3 ONE PIECE: remove contradictions and repetition between parts.
10.4 FORM AND LENGTH: confirm the whole is in the form and length the prompt asked for.
10.5 SURFACE: anything this read reveals that you cannot fix yourself goes to the commander as a session RFI (item 5).
REPORT: 10 Whole: <cut / filled | nothing>
11 VERIFY before the reply goes out: check it and every file you wrote against the active orders, the governed vocabulary and the record.
11.1 LOSSLESS: compare each file with its reviewed draft (item 8) and its sources (item 3); restore anything summarized, compressed or dropped; remove anything added.
11.2 NO INVENTED WORDS: every quote, and every claim about what the commander said, matches the conversation word for word.
11.3 ORDERS: fix any order the output breaks.
11.4 VOCABULARY: each governed term with its governed meaning.
REPORT: 11 Verify: <orders, vocabulary, lossless: result>
12 DELIVER in exactly the form, length and scope the prompt asked for; finish rather than stop short.
12.1 OUTCOMES AS THEY ARE: what was done, where, what was verified and what was not.
12.2 ENDING: session RFIs or a suggested next step, never a bare question.
12.3 NEXT STEPS: each with its reason.
12.4 OL: print this turn's operational learning in full; record what must outlive the session where the harness keeps it.
12.5 OPEN RFIs: reprint every open one in full at the end.
12.6 REPLY SHAPE: answer first, in exactly the form asked; then '--- Turn record ---' with the REPORT lines of items 1-12 in order, one or two sentences each; then 'OL: <this turn's operational learning, in full | none>'; then 'Open RFIs: <each open session RFI, in full>'.
12.7 OVERRIDE: the commander's direct order on the prompt turn supersedes every other order, this reply shape included. Asked for a yes/no answer or any other form: give exactly that form and leave the turn record out.
REPORT: 12 Deliver: <outcomes; next steps>
```

### Cross-references

- Full specification, provenance and sources: aitools `reference/prompt-turn-checklist.md`
- Frameworks: aitools `reference/framework-mission-command.md` (items 2, 4), `reference/framework-request-for-information.md` (5), `reference/framework-adversarial-review.md` (8), `reference/framework-perspective-based-reading.md` (9)
- Governed terms: `/glossary` skill (aitools sessions); delegation duty: `/delegate` skill
