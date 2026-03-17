# Decision Quality Audit

**Pattern**: Generalized from the improvement of decision #4.
**Criteria**: A=Check scope, B=Trace to source, C=Enumerate components,
D=Add current-session discoveries, E=Merge related, F=Include session references.

## Audit Results

### #1 — Session archive hook must auto-commit and auto-push
- **A (scope)**: PASS — standalone decision, not a sub-component
- **B (source)**: WEAK — references "this session" generically but no session IDs, no quotes. Should reference the Windows session (chat-summary-macos-work.md) where the gap was first surfaced, and this session (b8a9ed4e) where it was confirmed
- **C (components)**: WEAK — auto-commit AND auto-push are separate operations. Should enumerate: (1) git add the transcript, (2) git commit with structured message, (3) git push. Error handling for each (what if push fails? what if remote is ahead?)
- **D (current)**: PASS — discovered this session
- **E (merge)**: N/A
- **F (refs)**: FAIL — no session IDs. Should include: Windows session summary path, this session ID (b8a9ed4e), reference/user-repo.md L147 ("Never runs git operations")

### #2 — Data replication acceptable if clearly defined
- **A (scope)**: PASS
- **B (source)**: WEAK — has user quote but no reference to where in the session. No reference to the overlap analysis we performed
- **C (components)**: WEAK — "clearly defined" is vague. Should enumerate what needs defining: (1) what data lives where (transcripts in dotprofile, artifacts in project repo), (2) privacy boundary (user controls dotprofile visibility), (3) naming consistency between the two systems, (4) what happens when a user opts out of one
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: FAIL — no session IDs

### #3 — Delegation protocol framework needed
- **A (scope)**: PASS — umbrella decision
- **B (source)**: WEAK — references AAR by section but no session transcript. Should include 84280c8b session reference where the framework was conceived (L522: "we need an aitools-claude framework or something like it")
- **C (components)**: PASS — lists rule, skill, reference with intents
- **D (current)**: PASS — includes this session's delegation failures
- **E (merge)**: N/A
- **F (refs)**: WEAK — has AAR but missing: planning session (84280c8b), execution session (eaacf9da), this session (b8a9ed4e)

### #4 — Delegation duty has 8 components (REFERENCE DECISION)
- **A-F**: PASS — this is the exemplar we improved

### #5 — Block Explore agents via hook
- **A (scope)**: PASS
- **B (source)**: PASS — references this session's specific failures
- **C (components)**: WEAK — should specify: what the hook receives (Agent tool call JSON), what it checks (subagent_type field), what it returns (deny + corrective message), what the corrective message should say
- **D (current)**: PASS
- **E (merge)**: N/A — correctly separate from #6 (deny rule)
- **F (refs)**: WEAK — no session IDs. Should reference this session (b8a9ed4e) and the existing hook pattern from 84280c8b (block-claude-code-guide.sh)

### #6 — Explore agent deny rule
- **A (scope)**: PASS
- **B (source)**: PASS
- **C (components)**: PASS — simple, single action
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: WEAK — same as #5

### #7 — Delegation duty is recursive
- **A (scope)**: PASS — property of the duty, not a component
- **B (source)**: WEAK — has AAR reference but no transcript quote. The agent-initiated generalization at L1254-1264 is documented in delegation-evolution.md
- **C (components)**: WEAK — should enumerate what "recursive" means concretely: (1) any agent that delegates follows the duty, (2) the protocol itself must be included in the briefing so the delegated agent can follow it if IT delegates, (3) constraint: depth increases context cost — practical limit is ~2-3 levels
- **D (current)**: PASS
- **E (merge)**: PASS — correctly separate from #4 (property vs components)
- **F (refs)**: FAIL — missing session IDs (84280c8b L1260, this session b8a9ed4e)

### #8 — Portable scripting framework
- **A (scope)**: PASS — umbrella decision for the framework
- **B (source)**: WEAK — references "this session" generically. Should reference the Windows session where the stop hook crashed, the cross-platform audit findings from subagent research
- **C (components)**: WEAK — "framework needed" but should enumerate what the framework covers: (1) rule governing portable bash authoring, (2) compatibility registry (JSON), (3) wrapper functions in aitools-lib.sh, (4) check script validation, (5) skill for guided authoring
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: FAIL — no session IDs. Should include: Windows session (chat-summary), this session (b8a9ed4e), cross-platform audit report (.scratch/session-952OZxWICI/cross-platform-audit.md — was inline, not saved to scratch because Explore agent couldn't write)

### #9 — Centralized compat layer
- **A (scope)**: WEAK — is this a sub-component of #8 (framework)? The compat layer is the implementation mechanism for the framework. Consider: should #8 enumerate its components (including the compat layer) and #9 be merged into #8?
- **B (source)**: WEAK — no specific audit findings cited
- **C (components)**: WEAK — should enumerate the specific wrappers needed: get_mtime (stat -f %m / stat -c %Y), get_birthtime (stat -f %B / stat -c %W), epoch_to_date (date -r / date -d), and any others found in the audit
- **D (current)**: PASS
- **E (merge)**: CANDIDATE — could merge into #8 as a component
- **F (refs)**: FAIL — no session IDs, no audit references

### #10 — Registry of all-platform scripts
- **A (scope)**: WEAK — same as #9, could be a component of #8
- **B (source)**: WEAK — references cross-platform.md exceptions list but not by line
- **C (components)**: WEAK — should enumerate the current known all-platform scripts: 9 hooks (list each), build-deploy.sh, init-logging.sh, check-lib.sh, aitools-lib.sh
- **D (current)**: PASS
- **E (merge)**: CANDIDATE — could merge into #8 as a component
- **F (refs)**: FAIL — no session IDs

### #11 — Fix surfacing-duty-stop.sh
- **A (scope)**: PASS — specific fix, correctly separate from framework
- **B (source)**: PASS — has specific line numbers and error message
- **C (components)**: WEAK — should enumerate: (1) line 53 stat -f %m needs dispatch, (2) line 56 stat -f %B needs dispatch, (3) consider using centralized wrappers once #9 is implemented
- **D (current)**: PASS
- **E (merge)**: N/A — correctly separate (specific fix vs framework)
- **F (refs)**: WEAK — should reference Windows session with the error

### #12 — Shared session ID/date derivation
- **A (scope)**: PASS
- **B (source)**: PASS — has specific mismatch example
- **C (components)**: WEAK — should enumerate: (1) session ID prefix (first 8 chars), (2) session date (birth time of transcript, not current date), (3) project name derivation, (4) where the shared utility lives (aitools-lib.sh or a hook-utils.sh)
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: FAIL — no session IDs

### #13 — Fix harvest manifest
- **A (scope)**: PASS — specific fix
- **B (source)**: PASS — has investigation trail
- **C (components)**: WEAK — should enumerate: (1) change 2Hb40B0VEu to eaacf9da in 2 entries, (2) resolve date mismatch (2026-03-16 vs 2026-03-15), (3) deduplicate the 3 entries at lines 79-108 that are re-harvested copies
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: WEAK — should reference this session (b8a9ed4e)

### #14 — Intent-writing skill improvements
- **A (scope)**: PASS
- **B (source)**: WEAK — has AAR reference but not the specific user quotes. AAR L1122: "i dont think our skill is good enough yet. i think my explicit instructions are better." Should also reference L1101 where the user described the weight-by-recency pattern
- **C (components)**: WEAK — should enumerate the specific improvements: (1) reference recent conversation history, more recent = more weight, (2) multi-pass ambiguity removal (4 passes per AAR), (3) pre-write governed term audit, (4) read skill as reference but don't invoke mechanically, (5) match conciseness of existing governed JSON intents
- **D (current)**: PASS — user added "try to generalize from the AAR"
- **E (merge)**: N/A
- **F (refs)**: FAIL — no session IDs. Should reference 84280c8b (L1101, L1122), this session (b8a9ed4e)

### #15 — Mission analysis framework
- **A (scope)**: PASS
- **B (source)**: WEAK — references AAR lesson and user quote but generically
- **C (components)**: WEAK — should enumerate what the framework covers: (1) planning brief schema (the JSON artifact), (2) decision capture process (during conversation), (3) review workflow (print, discuss, refine), (4) plan-brief linkage (plan references its brief), (5) the /analyze skill
- **D (current)**: PASS — this planning brief is the first instance
- **E (merge)**: RELATED to #17 — #15 says "needs a framework" and #17 says "adopt MDMP for it". Could merge: the decision IS to adopt MDMP, the framework IS mission analysis
- **F (refs)**: FAIL — no session IDs

### #16 — Scratch cleanup
- **A (scope)**: PASS — simple directive
- **B (source)**: WEAK — "user directive" but no quote
- **C (components)**: WEAK — should enumerate: (1) SessionEnd hook deletes session dir, (2) SessionStart hook prunes dirs >24 hours, (3) both must work cross-platform (verify find -mmin on Git Bash)
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: FAIL — no session IDs

### #17 — Adopt MDMP Mission Analysis
- **A (scope)**: PASS
- **B (source)**: WEAK — generic reference to "this session"
- **C (components)**: PASS — references MDMP step 2 concepts
- **D (current)**: PASS
- **E (merge)**: CANDIDATE — could merge with #15 (see #15 audit)
- **F (refs)**: FAIL — no session IDs

### #18 — "Delegation protocol" naming
- **A (scope)**: PASS
- **B (source)**: PASS — has user quote
- **C (components)**: PASS — simple naming decision
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: WEAK — should reference this session (b8a9ed4e)

### #19 — Naming conventions
- **A (scope)**: PASS
- **B (source)**: PASS — has user quote about "rules are just about governance"
- **C (components)**: PASS — enumerates conventions per artifact type
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: WEAK — should reference this session (b8a9ed4e)

### #20 — Framework creation gatekept by /frameworks
- **A (scope)**: PASS
- **B (source)**: PASS — has user quote
- **C (components)**: PASS — simple governance decision
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: WEAK — should reference this session (b8a9ed4e)

### #21 — Plan files should be archived
- **A (scope)**: PASS
- **B (source)**: PASS — traced from decision #4 session references
- **C (components)**: WEAK — should enumerate options: (1) harvest hook checks ~/.claude/plans/ at SessionEnd, (2) plan skill copies plan to .scratch/ before session ends, (3) planning brief references the plan location
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: WEAK — should reference the plan file path and session

### #22 — Delegation duty references must include session IDs
- **A (scope)**: PASS
- **B (source)**: PASS
- **C (components)**: PASS — enumerates reference types
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: PASS — meta-decision about references

### #23 — One hook per feature
- **A (scope)**: PASS
- **B (source)**: PASS — has user quote
- **C (components)**: PASS — simple design principle
- **D (current)**: PASS
- **E (merge)**: N/A
- **F (refs)**: WEAK — should reference this session (b8a9ed4e)

## Summary

| Criterion | Pass | Weak | Fail | Candidate |
|---|---|---|---|---|
| A — Check scope | 19 | 2 (#9, #10) | 0 | 2 merge candidates |
| B — Trace to source | 10 | 11 | 0 | — |
| C — Enumerate components | 7 | 14 | 0 | — |
| D — Current-session discoveries | 22 | 0 | 0 | — |
| E — Merge related | — | — | — | 3 pairs: #9/#10→#8, #15/#17 |
| F — Include session refs | 2 | 9 | 10 | — |

### Top findings

1. **F (session references) is the weakest criterion** — 10 decisions have NO session IDs at all. Only #4 and #22 fully pass. Every decision should reference which sessions produced it.

2. **C (enumerate components) is the second weakest** — 14 decisions say WHAT to do but don't break it down into concrete sub-steps. This matters because executing agents need specificity, not directives.

3. **Merge candidates**: #9 and #10 could fold into #8 as components of the portable scripting framework. #15 and #17 are nearly the same decision stated differently.

### Recommended actions

1. Add session ID `b8a9ed4e` (this session) to every decision that was formulated here
2. Add Windows session reference (chat-summary path) to decisions #1, #8, #11
3. Add planning session `84280c8b` reference to decisions #3, #7, #14
4. Enumerate components for the 14 WEAK decisions
5. Merge #9/#10 into #8 and #15/#17 into one decision
