# 38dc-28-rfi-repeat-rca: report (v1.1)

**Intent**: **Purpose**: Record the root cause analysis of why the
orchestrator M6-Polish asked the commander RFI 38dc-11 after he had already
answered it, with the evidence, the barrier analysis, the other instances in
the session, and the proposed preventive actions. **Scope**: Session 87795dc3
(2026-11-14): M6-Polish, its delegates 38dc-13 and 38dc-19, and the
harness artifacts that should have prevented the repeat. NOT the
implementation of the preventive actions (GitHub issue #171). NOT the OS guards
on `bootstrap.ps1` and `hh.ps1` (decided work, to be assigned by M6-Polish's
successor). **Audience**: The commander; M6-Polish and its successor
M6b-Finish; whoever implements GitHub issue #171.

Mission 38dc-28-rfi-repeat-rca, delegated by M6-Polish (agent
a0c459c8f689338dc) under Session Commander 87795dc3-e, 2026-11-14. Incident
**#180** (`registries/incidents.json`), GitHub issue
**#171** (https://github.com/nobul-tech/aitools/issues/171).

v1.1 (2026-11-14) applies the independent review a50b-01
(https://github.com/nobul-tech/aitools/pull/172#issuecomment-6887197331):
- **Decided by answer 1:** answer 1 alone decided the question; answers 5 and
  7 are precedents from the same exemptions row (B1).
- **Root cause restated:** the check-before-asking steps exist; they faded
  and nothing enforces them (B2).
- **RFI 38dc-7:** its bootstrap/hh `.ps1` item is counted as an earlier
  instance of the same question (B3).
- **Registry fields:** `referenceFile` points at this report (B4); the history
  of the #180 id is recorded (B5).
- **Nits:** counts, timing and wording corrected.

## Summary

1. M6-Polish relayed its delegate's RFI 38dc-19-1 to the commander as RFI
   38dc-11: "Should `bootstrap.ps1` and `hh.ps1` get the Windows OS guard
   too?"
   - The commander's answer 1 had already decided it: ".ps1 on windows" unless
     explicitly marked cross-platform.
   - His answers 5 and 7 had applied that rule to the same exemptions row.
   - The RFI's own body quoted the rule that decided it.
2. **Root cause:** the check-before-asking steps exist (CLAUDE.md "The
   process" steps 2 and 5; prompt-turn checklist items 1 and 4) and applied
   here, but they are behavioural only and they faded. Nothing records or
   enforces them:
   - session RFIs exist only as chat text, with no ledger of the commander's
     answers;
   - the `/delegate` skill's "Verifying what comes back" has no step for a
     delegate's open questions;
   - no hook looks at RFI text.
3. **Contributing causes:**
   - M6-Polish narrowed the decision to its `.sh` half three times: the RFI
     38dc-5 framing, and the 38dc-13 and 38dc-19 briefs.
   - It put the bootstrap/hh `.ps1` item to the commander in RFI 38dc-7 without
     a Suggest line, then closed that RFI as "none" with the item unanswered.
   - It did not run the prompt-turn checklist visibly after 19:00Z.
4. **Recurring:** the question about the bootstrap/hh `.ps1` halves reached the
   commander twice: RFI 38dc-7 at 21:24Z, then RFI 38dc-11 at 23:16Z. RFI 38dc-5
   had the same shape for the `.sh` halves (confirmed, partial). RFI 38dc-12 is
   a candidate. RFI 38dc-1 is not counted.
5. **Preventive actions** (GitHub issue #171): checklist items 4-5, a
   `/delegate` open-questions step, a session RFI ledger, and an observe-mode
   Stop/SubagentStop RFI hook. No harness change ships in this PR.

## Method

- Transcripts (read-only), under
  `C:\Users\jdpal\.claude\projects\C--Users-jdpal-repos-aitools\87795dc3-e9b0-4f82-937b-139b3f13fa81\`:
  - `subagents\agent-a0c459c8f689338dc.jsonl`: M6-Polish ("M6"; meta
    description "M6-Polish: leftover findings mission").
  - `subagents\agent-a133a469c858faca4.jsonl`: 38dc-19
    ("38dc-19-aitools-win-forwarder").
  - `subagents\agent-a615ff0218609e9d6.jsonl`: 38dc-13
    ("38dc-13-windows-ci-ps1-only").
  - The main session `87795dc3-e9b0-4f82-937b-139b3f13fa81.jsonl`: commander
    prompts only.
- `L<n>` below is the JSONL line number in the named transcript. Times are UTC.
- Python readers written for this mission (session scratch, not tracked):
  - `convo.py`: every commander message (mid-turn "The user sent a new
    message" text, and queued commands with origin human) plus every assistant
    text block, in order.
  - `dump.py`: a line range with text, thinking, tool inputs and results.
  - `find.py`: a term search with context.
  - `thinkdump.py`: readable thinking blocks.
- **Thinking blocks:**
  - Most of M6's thinking blocks are empty. The readable ones are one-line
    summaries.
  - Counts: the reviewer found 291 distinct blocks through L3075, 31 of them
    readable, once copies stored inside api-request-blob records are excluded.
  - None is readable at L2649-L2654, L3060 or L3064.
  - M6's reasoning at the moment it raised RFI 38dc-11 is therefore **unknown**
    beyond what its reply text says.
- **Review:** the independent reviewer a50b-01 re-checked 53 quotes and
  citations against the transcripts. All matched.

## The commander's answers on record (verbatim)

| Answer | M6 line, time | Text | Role here |
|---|---|---|---|
| Statement | L830 18:49:44Z | "how are you riding tests? tests should be .ps1 here on windows and executed as powershell scripts, git bash scripts cause known issues." | Background |
| 1 | L932 18:58:47Z | "1) yes, unless a script is explicitly marked as cross-platform for good reasons, such as build-deploy.sh and all perl/python scripts, sh scripts and tests should only run on linux/mac and ps1 on windows.  launch followup mission to add a guard to those .sh scripts that should not run on windows or remove them from the CI through other means.  windows ci tests should have the equivalent mac/linux .sh script in ps1. ..." | **Decides it** ("ps1 on windows") |
| 5 | L1828 20:23:55Z | "5) add an OS guard to all of them" | Precedent. It answers RFI 38dc-5, which named only `hh.sh`, `bootstrap.sh`, `init-hh-hooks.sh` and `analyze-session.sh`; the exemption rows it concerned read `bootstrap.sh/.ps1`, `hh.sh/.ps1` |
| 7 | L2483 22:04:21Z | "7) build-package.sh is approved, relay-outbound.sh/.ps1 need os guards they are not exempt, ..." | Precedent. It guards a `.ps1` half of the same "Entry points sourced or run on any platform" row, and does not mention bootstrap or hh |

## Timeline

| Time | Where | Event |
|---|---|---|
| 18:49:44Z | M6 L830 | The commander's statement on tests (above). |
| 18:53:11Z | M6 L896 | RFI 38dc-1 raised. Its body says: "Your rule is that on Windows, tests are `.ps1` run as PowerShell." This reply carries a turn record. |
| 18:58:47Z | M6 L932 | Answer 1, plus "BEFORE YUOU RESPOND, apply the prompt turn instructions in full line by line". |
| 19:00:00Z | M6 L944 | 38dc-13 brief. Its title names both halves (".sh scripts and tests run only on Linux/macOS, .ps1 only on Windows"). Its purpose, scope and work steps enforce only the `.sh` half: "every `.sh` script or test that is not explicitly marked cross-platform for a good reason refuses to run on Windows". It lists the entry points as "`aitools`, bootstrap.sh, hh.sh, relay-outbound-prompt.sh, init-hh-hooks.sh, aitools-install.sh", without the `.ps1` halves. |
| 19:00:48Z | M6 L979 | The last reply with a turn record. |
| 19:14:24Z | M6 L1034, L1047 | M6 pre-assigns incident ids: "#180 \| 38dc-13". |
| 19:52:19Z | 38dc-13 L986 | RFI 38dc-13-3: "hh.sh, bootstrap.sh, init-hh-hooks.sh, analyze-session.sh never run on Windows (e9d6-01). Suggest: guard analyze-session.sh and hh.sh in a follow-up, keep bootstrap.sh exempt with its own refusal, delete init-hh-hooks.sh ..." Answer 1 is quoted in its brief. |
| 19:53:24Z | M6 L1340 | Relayed as RFI 38dc-5: "Clean up the four `.sh` entry points that never run on Windows?" It ends: "Unrecorded exemptions are the gap your rule closes." |
| 20:16:11Z | M6 L1727 | RFI 38dc-5 restated: "... so under your rule they should not be exempt." |
| 20:23:55Z | M6 L1828 | Answer 5. |
| 20:25:02Z | M6 L1833 | 38dc-19 brief. Its intent says "(2) the four `.sh` entry points that never run on Windows get the canonical OS guard", and its scope lists "scripts/hh.sh, scripts/bootstrap.sh, scripts/init-hh-hooks.sh, scripts/analyze-session.sh (OS guards)". It quotes "... sh scripts and tests should only run on linux/mac and ps1 on windows." |
| 20:25:39Z | M6 L1845 | To 38dc-13: "RFI 38dc-13-3 (hh.sh, bootstrap.sh, init-hh-hooks.sh, analyze-session.sh): \"5) add an OS guard to all of them\". 38dc-19 does this too, including their exemptions-table rows." |
| 20:46:21Z | 38dc-19 L637 | PR #162 body draft: "RFI 38dc-19-1: Guard the Windows-only `.ps1` twins too? ... Suggest: give both the canonical Windows guard in a follow-up (the commander's rule \"ps1 on windows\") ..." |
| 21:24:52Z | M6 L2272 | **RFI 38dc-7: the bootstrap/hh `.ps1` item first reaches the commander.** The RFI lists "`relay-outbound-prompt.sh/.ps1`, plus the `.ps1` halves of `bootstrap` and `hh` (rationale unrecorded)". This is 2.5 hours after answer 1. Its Suggest list has a line for relay-outbound-prompt.sh but none for the bootstrap/hh `.ps1` halves. Restated at L2482. |
| 22:04:21Z | M6 L2483 | Answer 7. It addresses each suggested item and is silent on bootstrap/hh `.ps1`. |
| 22:06:32Z | M6 L2503 | "Items 7, 8 and 9 are all assigned ... Open RFIs: none." RFI 38dc-7 closes with one item unanswered. |
| 23:15:49Z | 38dc-19 L1454 | Hand-back: "RFI 38dc-19-1: should `bootstrap.ps1` and `hh.ps1` get the Windows guard too? Under pwsh on macOS/Linux they would run today. Suggest: yes, in a follow-up (the commander's \"ps1 on windows\")." |
| 23:16:04Z | M6 L2649 | The hand-back reaches M6. |
| 23:16:15Z | M6 L2654 | **The second time:** about 10 seconds later, with no readable thinking in between, M6 asks it as RFI 38dc-11 under "38dc-19 raised two questions:". Text: "RFI 38dc-11: Should `bootstrap.ps1` and `hh.ps1` get the Windows OS guard too? Today they would run under pwsh on macOS and Linux. Your rule is \".ps1 on Windows\" unless explicitly marked cross-platform, and the exemptions table now lists only those two `.ps1` halves (plus the relay prompt, which 38dc-23 is guarding) as entry points that run anywhere. Suggest: yes. ..." The reply has no turn record. |
| 23:47:10Z | M6 L2727 | "Its two open questions are RFI 38dc-11 and 38dc-12, already with you." |
| 00:47:27Z | M6 L3025 | `M6-Polish-report.md` (worktree m6-report, PR #169) lists "RFI 38dc-11: Windows guard on bootstrap.ps1 and hh.ps1? Suggest: yes. ..." as open. |
| 00:49:16Z | M6 L3057 | Commander: "restate open rfis". |
| 00:49:26Z | M6 L3060 | RFI 38dc-11 restated in full ("38dc-19 raised this (RFI 38dc-19-1)"). |
| 00:50:09Z | M6 L3061 | Commander: "11) didnt i answer this already? re-read entire session verbatim line by line.  respond yes/no" |
| 00:50:16Z | M6 L3064 | "Yes. Your general rule already answers it: \"sh scripts and tests should only run on linux/mac and ps1 on windows\" (answer 1). So did item 5, \"add an OS guard to all of them\", whose exemption rows listed `bootstrap.sh/.ps1` and `hh.sh/.ps1`. I'm withdrawing RFI 38dc-11; the Windows guards on `bootstrap.ps1` and `hh.ps1` are decided work, and I'll assign them to a mission." |
| 00:52:50Z | M6 L3065 | Commander orders this mission. |

The check took seven seconds once the commander asked for it (L3061 to
L3064), against about 10 seconds to relay the question unchecked (L2649 to
L2654). The information was available all along; the check was simply not run
before asking.

## RCA

### Immediate cause

M6-Polish forwarded a delegate's open question to the commander (L2654,
"38dc-19 raised two questions:") without resolving it against his recorded
answers. Its RFI body names the deciding rule ("Your rule is \".ps1 on
Windows\" unless explicitly marked cross-platform"). It also names the
precedent from answer 7 ("plus the relay prompt, which 38dc-23 is guarding").

### 5 Whys

1. **Why did the commander get an already-answered question?**
   M6 relayed RFI 38dc-19-1 as RFI 38dc-11 without checking it against
   answer 1 or its applications in answers 5 and 7.
2. **Why was it not checked?**
   - **The steps existed and applied.** CLAUDE.md "The process" step 2 says
     "Check against this conversation" and step 5 "Surface only what you can't
     resolve". Checklist item 4 says "Do not ask what you can find out". M6
     renumbered 38dc-19-1 as its own RFI 38dc-11, so item 4 applied to it
     directly.
   - **They faded.** Only two replies carry a turn record: L896 (after the
     commander's L830 prompt) and L979 (after his L932 order to apply the
     checklist). None of M6's replies in the six hours after L979 carries one.
   - **Nothing enforces them for a relayed question.** M6 treated the
     delegate's question as something to forward. `/delegate` "Verifying what
     comes back" covers files, WRITE_BLOCKED, CONFLICT, claims, scope, shipped
     changes, INCIDENT markers and lifecycle, but not open questions. Checklist
     item 5 only says a delegate's report may go "verbatim" into an RFI body.
     No hook looks at RFI text.
3. **Why did the question look open to M6?**
   M6 had narrowed the decision itself:
   - RFI 38dc-5 named only the `.sh` files of `.sh/.ps1` rows (L1340).
   - The 38dc-13 brief's purpose, scope and work steps applied only the `.sh`
     half of answer 1 (L944); its title names both halves.
   - The 38dc-19 brief scoped answer 5 to the four `.sh` files (L1833).
   - RFI 38dc-7 put the bootstrap/hh `.ps1` halves to the commander without a
     Suggest line, and was closed as "none" when answer 7 did not address them
     (L2272, L2503).
4. **Why could a decision be narrowed and an item dropped unnoticed?**
   - The commander's answers live only in chat and in brief quotes, applied one
     RFI at a time.
   - No record holds a general rule with its full scope (`.sh` off Windows
     AND `.ps1` only on Windows).
   - Closing a multi-item RFI has no per-item accounting.
5. **Why is there no such record?**
   - `reference/framework-request-for-information.md` maps AIA G716's
     "numbered, logged and tracked" to **Number** only: the `<sid4>-<n>` id.
   - It lists the per-turn reprint of every open RFI as harness-native. It
     adopted no log.
   - FM 2-0's "Use intelligence reach first ... to answer requests for
     information" became one sentence in item 4. No mechanism enforces that
     sentence.

### Root cause

The check-before-asking steps exist (CLAUDE.md "The process" steps 2 and 5;
prompt-turn checklist items 1 and 4) and applied to RFI 38dc-11, but they are
behavioural only, and they faded: no reply after L979 carries a turn record.
Nothing records or enforces them:
- session RFIs exist only as chat text, with no ledger of questions, items and
  the commander's answers;
- `/delegate` "Verifying what comes back" has no step for a delegate's open
  questions;
- no hook looks at RFI text.

The orchestrator therefore relied on recall over a conversation then nearly six
hours long (17:33Z to 23:16Z). In that conversation it had narrowed the decision
to its `.sh` half itself, and had already dropped the same question once (RFI
38dc-7).

### Contributing factors (Swiss cheese)

| # | Factor | Layer | Evidence |
|---|---|---|---|
| C1 | CLAUDE.md "The process" steps 2 ("Check against this conversation") and 5 ("Surface only what you can't resolve") were in context and not applied | Prevention (rule fade) | M6 L2654 quotes the rule it asks about |
| C2 | The prompt-turn checklist was not run after 19:00Z: no turn record after L979, about 2,100 transcript lines and six hours | Prevention (rule fade) | `Turn record` appears only in the L896 and L979 replies |
| C3 | No `/delegate` step for a delegate's open questions | Prevention (gap) | `shared/skills/delegate/SKILL.md` "Verifying what comes back" (origin/main) |
| C4 | The briefs applied half of answer 1 and narrowed answer 5 | Prevention (brief quality) | M6 L944 purpose, scope and work steps; M6 L1833 intent and scope |
| C5 | RFI 38dc-7 put the bootstrap/hh `.ps1` item to the commander without a Suggest line, then closed with that item unanswered | Prevention and record (gap) | M6 L2272 Suggest list; L2483 answer 7; L2503 "Open RFIs: none." |
| C6 | Delegates raised RFIs that their briefs' quoted commander words answered. `/delegate`: "Only what the record cannot answer becomes an open question with a suggested answer." | Prevention (delegate side) | 38dc-13 L986 (answer 1 quoted in its brief L944); 38dc-19 L1454 ("the commander's \"ps1 on windows\"") |
| C7 | 38dc-19 was scope-bound: its brief excluded the `.ps1` files, so flagging the gap was correct. But the RFI format gave it no way to say "decided by the commander, outside my scope" other than a question | Prevention (format gap) | M6 L1833 "RFI format for your open questions" |
| C8 | No hook or check looks at RFI text; the prompt-turn hook is not built (`reference/prompt-turn-checklist.md` intent: "NOT the hook that will deliver the checklist (not built yet; ...)") | Detection, audit (absent) | `shared/hooks/hooks-manifest.json` has no such hook |

Recurrence category (`/investigate`): **rule fade** plus **missing
enforcement**. Three instances in one session (below) call for a structural
fix.

## Instances in session 87795dc3

| RFI | Where | Answered before? | Classification |
|---|---|---|---|
| 38dc-11 | M6 L2654 23:16:15Z (from 38dc-19-1) | Yes, by answer 1. Answers 5 and 7 had applied it to the same row. | The incident |
| 38dc-7, bootstrap/hh `.ps1` item | M6 L2272 21:24:52Z, restated L2482 | Yes, by answer 1 (2.5 hours earlier), the same question as RFI 38dc-11. Listed with no Suggest line, unaddressed by answer 7, then dropped at "Open RFIs: none" (L2503). The RFI's other items (approving `build-package.sh`, recording the helper modules, the check-script Git Bash calls) were approvals the commander had to give. | Confirmed, partial (one item) |
| 38dc-5 | M6 L1340 19:53:24Z (from 38dc-13-3) | Yes, by answer 1 (L932, 55 minutes earlier): "launch followup mission to add a guard to those .sh scripts that should not run on windows". M6's restatement: "so under your rule they should not be exempt" (L1727). Its Suggest (keep `bootstrap.sh` exempt) went against the rule; only the option to delete `init-hh-hooks.sh` was new. | Confirmed, partial |
| 38dc-12 | M6 L2654 | `.claude/rules/cross-platform.md` "Dead code from platform guards" decides the removal. Its Suggest says "The repo's rule against dead platform branches below an OS guard applies". The timing is a genuine choice. Not answered by the commander. | Candidate |
| 38dc-1 | M6 L896 18:53:11Z | 3.5 minutes after "tests should be .ps1 here on windows ..." (L830), and its body says "Your rule is that on Windows, tests are `.ps1` run as PowerShell." But "here" did not clearly cover the CI job, so extending it to CI was a genuine scope question. The commander answered "yes" without objection. | Not counted |

The main session's commander prompts were searched for "already answer",
"didnt i", "i already", "answered this", "i told you", "i said" and "asked me".
No other complaint of this kind was found.

**Signature:** every counted instance has an RFI body that cites the
commander's own rule ("Your rule is ...", "under your rule", "what your rule
needs"). So do RFI 38dc-1, RFI 38dc-3 (L1340, a genuine design choice) and the
approval items of RFI 38dc-7. The phrase is a prompt to check, not a verdict.

## Corrective and preventive actions

| # | Type | Action | Artifacts |
|---|---|---|---|
| A1 | Corrective (instance) | Withdraw RFI 38dc-11 (done, L3064). Assign the Windows guards on `bootstrap.ps1` and `hh.ps1` and drop their exemption rows (M6-Polish's successor to assign). Mark RFI 38dc-11 withdrawn in `M6-Polish-report.md` (PR #169). | `scripts/bootstrap.ps1`, `scripts/hh.ps1`, `.claude/rules/cross-platform.md`, `tests/os-guards` |
| P1 | Behavioural, in the checklist | Before raising or relaying a session RFI, search the conversation newest first for the commander's answers on its subject. A settled question is decided work. An RFI whose body gives his rule as its reason is already answered. A delegate's RFI is resolved under item 4 before relaying, with a `Checked:` line. Every item of a multi-item RFI carries its own Suggest line. | `reference/prompt-turn-checklist.md` items 4-5; `shared/rules/prompt-turn.md` (PR #156) |
| P2 | Structural (skill) | Add an "Open questions" step to "Verifying what comes back". Add a skeleton line: report items the brief's quoted commander words decide as `FOLLOW-UP (decided): <quote>`. Add a brief rule: list every instance a commander rule covers (both halves), or name the half left out. | `shared/skills/delegate/SKILL.md` |
| P3 | Structural (record) | A session RFI ledger: one tracked file per session holding id, subject keys, question, Suggest, the verbatim answer per item and status. An RFI closes only when every item is answered or withdrawn. General rules are recorded as decisions with their full scope. | `reference/framework-request-for-information.md`, checklist item 5 |
| P4 | Structural (detection) | A Stop/SubagentStop hook in observe mode: on new `RFI <sid4>-<n>:` headings, inject the already-answered check, flag "your rule" bodies, and, with P3, require a ledger row. Verify the hook events against the Claude Code hooks documentation first. | `shared/hooks/` (new), `shared/hooks/hooks-manifest.json`, `.claude/rules/hook-rollout.md` |

### Barrier replay (L2272 and L2654 with each action in place)

- **P1 and P2.** M6 must run the check before asking or relaying, and must
  give every item a Suggest line, so the bootstrap/hh item could not have gone
  into RFI 38dc-7 bare. M6 already had the answer in context, so these address
  the reasoning failure. But they stay behavioural and can fade like C1 and C2.
- **P3.** The unanswered RFI 38dc-7 item stays open in the ledger, so "Open
  RFIs: none" could not have been written at L2503. A search for
  `bootstrap.ps1` finds RFI 38dc-7, answer 1 and its applications in answers 5
  and 7. This changes the outcome **if** the ledger is consulted (pairs with P1
  and P4).
- **P4.** "Your rule is" in RFI 38dc-11 triggers the reminder. So do RFI 38dc-5
  and RFI 38dc-7. False positives: RFI 38dc-1, RFI 38dc-3, and RFI 38dc-7's
  approval items. It is the only automatic layer.

Recommendation: P3 + P4, with P1 and P2 as their behavioural halves. A
behavioural fix alone is not a fix for a recurring pattern (`/investigate`
"Escalation").

## Why no fix ships in this PR

- The brief allows "any agreed fix you are confident of, small and in scope".
  No fix has been agreed by the commander.
- The natural home of P1, `reference/prompt-turn-checklist.md`, is being edited
  by open PR #156.
- P2-P4 are design choices for the commander.

This PR therefore files the incident and this report only; the fixes are
proposed in GitHub issue #171.

## Deliverables

- **Incident #180:** `registries/incidents.json`, status open, severity
  medium, linked to GitHub issue #171. Its `referenceFile` points at this
  report: keeping the analysis here, rather than copying it to
  `reference/incident-180-*.md`, leaves one copy of it.
- **Id history:**
  - M6-Polish had pre-assigned #180 to 38dc-13 (M6 L1034, L1047), which filed
    nothing.
  - PR #166's `38dc-13-report.md` line 70 still says "INCIDENT (not filed;
    reserved #180)", and `e9d6-13-report.md` line 195 lists "reserved ids #180,
    #182".
  - The successor orchestrator M6b-Finish has asked 38dc-27 to reword both
    before #166 merges.
- **GitHub issue #171:** https://github.com/nobul-tech/aitools/issues/171
- **This report.**
- **RELEASE_NOTES entry v0.77.21** (documentation only).

## Not run

- No harness change was made or tested.
- The Claude Code hooks documentation was not read for P4 (event inputs are
  unverified).
- The 38dc-12, 38dc-23 and other delegates' transcripts were not searched for
  further instances; only M6, 38dc-13, 38dc-19 and the main session's commander
  prompts were.

## Operational learning

- The commander's messages to a subagent arrive in its transcript in two forms:
  user-turn text starting "The user sent a new message while you were
  working:", and `queued_command` attachments with `origin.kind` `human`. A
  search for only one of them misses most of his messages: only 4 of about 30
  were queued commands in M6's transcript.
- An orchestrator's thinking blocks may be empty or one-line summaries, and
  some are stored twice (inside api-request-blob records). An RCA of its
  decision rests on its reply text and tool inputs, and a count of its thinking
  blocks must de-duplicate first.
- An RFI body that cites the commander's own rule as the reason for its
  suggestion is the cheapest detectable sign that the RFI is already answered.
- An RFI item without a Suggest line is easy for the commander to skip and
  easy for the asker to drop.
