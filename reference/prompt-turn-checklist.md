# Prompt-turn checklist

**Intent**: **Purpose**: Define, item by item, the checklist an agent runs
at every prompt turn. It formalizes the ad-hoc checklist the commander kept
repeating in prompts, and it is the specification a hook will deliver to
every agent. **Scope**: The checklist items: what each one requires, why, and
how a skipped item shows. NOT the hook that will deliver the checklist (not
built yet; rollout practice: `@.claude/rules/hook-rollout.md`). NOT the
seven-step process in `CLAUDE.md` "The process (every prompt)": its steps
are merged into this checklist, and that section is left as it is. NOT
delegation prompts (`/delegate` skill). **Audience**: Every agent at every
prompt turn; the agent that builds the prompt-turn hook; the commander,
reviewing what the hook will enforce.

v1.8 (2026-11-13)

A **prompt turn** is one prompt from the commander and everything the agent
does until its reply is printed.

The checklist was inferred from the commander's prompts in sessions 8236ca9c
(2026-03-26; `.aitools/channel/8236ca9c-full-session.md`) and fbf7decb
(2026-03-28; the dotprofile's `sessions/aitools/2026-03-28_fbf7decb.jsonl`).
The checklist has thirteen items. This version holds items 1 to 5. The rest
are added on the commander's order.

## 1. Re-read the whole conversation, start to now, at full fidelity

Before acting on the prompt, re-read the conversation from its first turn to
the current prompt. Read every turn on both sides, in order, word for word.

- **Full scan**: every turn, not only the recent ones, and not a search for
  the parts that look relevant.
- **Full fidelity**: work from the verbatim text in context, not from a
  summary or from what you remember of earlier turns. Thinking compresses
  what it reads; the raw text is still in context, so go back to it.
- **In context**: the conversation is already in context, so the re-read
  happens in thinking and needs no tool call. If part of it was compacted
  away, say so. Do not reconstruct it.
- **Every turn, including the easy ones**: the checklist tends to be dropped
  on prompts that feel easy. A three-word prompt gets the same re-read.
- **Reverse order helps, it does not replace**: a second pass from the newest
  turn back finds the latest word on a point fastest. It is an extra pass,
  not a substitute for the full scan.

Why: the current conversation is the source with the most weight, because it
is the most recent. Words take their meaning from the conversation: orders,
decisions, corrections and the meaning of terms agreed earlier in the session
all live there. An agent that skips the re-read answers from its defaults.

A skipped item shows as:

- an answer built on a summary of earlier turns, or a quotation that does not
  match the text in context;
- an order, decision or correction from earlier in the session that the reply
  ignores or contradicts;
- a summary where the commander asked for full fidelity.

## 2. Parse the prompt for high-impact words and fix their meaning

Read the current prompt word by word and mark its high-impact words: the
words that decide what you do and what you deliver.

- **The order**: the verbs that say what to do (write, load, compare,
  propose, delegate, stop).
- **The deliverable**: the nouns that name what to produce or act on (a file,
  a list, a number, an answer).
- **Scope and quantity**: "all", "only", "first", "each", "the rest", and any
  limit on what is in or out.
- **The form of the reply**: "be brief", "yes/no answer", "print only the
  number", "verbatim", "in full", "no summaries". These govern the reply as
  much as the content does.
- **Changes of state**: "decision", "order", "correction", "from now on",
  "deferred". They change what holds for the rest of the session.

Fix the meaning of each high-impact word, by weight:

- **First, the conversation**: a meaning agreed or used earlier in the
  session wins. Item 1 put it in front of you.
- **Then, files in context**: the governed vocabulary, rules and CLAUDE.md
  files. They are evidence, and they can be stale.
- **Last, your defaults**: the meaning your training gives the word. A word
  you can read only through your defaults is unresolved.

A word is also unresolved when the conversation, the governed vocabulary and
your defaults give it different meanings, or when a typo leaves two plausible
readings. Do not settle an unresolved word by picking the likeliest meaning
and going on. Carry it forward to items 4 and 5.

Short prompts get the same parse. The fewer the words, the more each one
carries.

A skipped item shows as:

- a reply that breaks the requested form (long when asked to be brief, prose
  when asked for yes/no or a number);
- a deliverable other than the one the prompt named, or more or less of it
  than its scope words allowed;
- a word read with its default meaning where the session had fixed another;
- an assumption about an ambiguous word stated as fact.

## 3. Re-read the sources that inform the work

Find every source that bears on what the prompt asks, and re-read each one at
full fidelity before acting. Look for:

- **Earlier versions of the work**: the file as it stands now, what you wrote
  earlier in the session, and any version you replaced.
- **What has been decided**: decisions, orders, operational learning and open
  items that apply, from the session and from files.
- **Related work that must stay consistent**: sibling documents, and the code
  or specifications the work depends on or that depend on it.
- **What governs this kind of work**: the rules, standards and skills that
  apply.

For each source, ask how it informs the work: what it requires, what it rules
out, and where it disagrees with the prompt.

- **Context first**: re-read what is already in context, in thinking. If a
  source the work needs is not in context, load it. If the session restricts
  which files you may read, name the source and why you need it instead.
- **Current text, not memory**: a file read earlier may have changed since,
  whether by you, a delegate or the commander. If it may have changed, read
  it again from disk.
- **Weight**: these sources rank below the conversation (item 1), and they
  can be stale. When one disagrees with the conversation, the conversation
  wins, and the disagreement is carried forward to items 4 and 5.
- **Evidence, not a template**: read existing code and documents as evidence
  of how things work. Do not copy them as the pattern for new work, or their
  bugs travel with the copy. Design from the specification.
- **Scale to the work**: a yes/no question may need only the conversation; a
  document or code change needs its full set of sources. Either way, decide
  which sources apply. Do not skip that decision.

A skipped item shows as:

- output that contradicts an earlier version, a decision or a sibling document
  without saying so;
- a broken rule or standard that governs the work;
- a file described from memory, where the description does not match the file;
- an existing pattern copied with its bugs;
- work built on a stale read of a file that has since changed.

## 4. Resolve what you can with disciplined initiative

Take everything items 2 and 3 carried forward: words whose meaning is not
fixed, sources that disagree, and the assumptions the work would rest on.
Resolve what you can without the commander.

**Disciplined initiative** is deliberate deviation from the process or an
order, made to accomplish the mission and reported. It is not appearing to
know what you do not know. A guess presented as a resolution is the failure
this item exists to prevent.

Ways to resolve, nearest first:

- **Reason over context**: the conversation and the sources already re-read
  often settle the point.
- **Read**: load a source that is not yet in context.
- **Test**: run the command, check the file, try the tool, measure.
- **Delegate**: hand a large or parallel verification to a delegate, under
  the delegation duty (`/delegate` skill).

Each unresolved point ends in one of three states: **verified**,
**invalidated** or **open**. Know which, and on what evidence.

- **Evidence or it is open**: a resolution points to text, a file or a test
  result. "Probably" is not resolved; it goes to item 5.
- **Do not ask what you can find out**: the commander's time is the scarcest
  resource. A question that the conversation, a file or one command could
  answer spends it for nothing.
- **Some choices are not yours**: intent, priority, preference, and any
  action that is hard to reverse or reaches outside the session belong to
  the commander. Carry them to item 5 even when you could pick.
- **Depth follows impact**: verify every assumption that changes what you
  deliver. Note the ones that do not, and move on.
- **Report every deviation**: when you deviate from the process or an order
  to accomplish the mission, the reply says what you deviated from and why.

A skipped item shows as:

- a question to the commander whose answer was in the conversation, in a
  file, or one command away;
- an assumption stated as fact with no evidence behind it;
- a deviation from an order or the process that the reply does not mention;
- a choice that belonged to the commander, made silently.

## 5. Surface what you cannot resolve

The surfacing duty: what item 4 left open, and what you found along the way,
goes to the commander as **session RFIs** (requests for information):

```
RFI <sid4>-<n>: <title>
<the question, with its context>
Suggest: <action> (why)
```

- **Number**: `<sid4>` is the last 4 hex digits of the session id. `<n>`
  rises through the session and is never reused.
- **Always a question**: every session RFI asks the commander for something.
  An observation that asks for nothing belongs in the reply.
- **Context in the body**: the evidence, problems found, your own mistakes,
  observations about your own processing, and a delegate's report verbatim.
- **One issue, standing alone**: the title and body name what the question is
  about and what the answer changes.
- **Suggest an answer**: the action you would take and why, so one word can
  confirm it.
- **Before you build on it**: hold the work that depends on an open session
  RFI. Do the rest.
- **Batch**: raise every new session RFI in the same reply, not one per turn.
- **Carry forward**: end every turn by reprinting every open session RFI in
  full. One closes when the commander answers it, or when you withdraw it and
  say why.
- **Track what must outlive the session**: also record a deficiency where the
  harness tracks it (an incident or an issue).
