# Consolidated Operational Learning

**Date**: 2026-03-25
**Session**: c0dc2ddc-f464-404d-a637-8103afda27af
**Author**: S3-Consolidator (delegated by live session agent)
**Sources**: Session transcript (1839 lines), three cross-project audit reports (aitools prior session, marse, nobul-ops), /aitool-resume proof of concept, /tmp hook investigation, two prior-session RFCs (aitool-resume v7, self-evolution proposals)
**Purpose**: Serve as the single loadable artifact for all future delegation and mission work across all projects. Replaces the recency heuristic with consolidated principles.

---

## Part 1: Commander Profile

### Who the Commander Is

Jose. Founder of Nobul. Works across macOS, Windows, and Linux. Manages multiple projects simultaneously: aitools (harness infrastructure), nobul-ops (company operations and SaaS architecture), marse (litigation support tooling). Uses Claude Code as the primary development environment with Claude Opus 4.6 (1M context).

### What the Commander Values

**Time is the primary constraint.** This is not a preference -- it is the governing value that shapes every interaction. Direct quote from the session: "i value my time more than anything." Every source of latency is a cost. Broken hooks that add regex parsing on every turn are tax with no return. An 8m33s response time for three sentences is unacceptable. The harness exists to multiply the commander's time, not to be maintained for its own sake.

**Leverage through delegation and parallelism.** "i use you because you give me leverage and you can do things in parallel and delegate." Multiple agents running concurrently on discrete objectives is the operating model. Tokens and delegation overhead are agent costs, not user costs. What costs the user is latency, broken state, false confidence, and agents asking permission instead of acting.

**Depth of understanding over breadth of action.** The commander uses a Socratic method: asking questions they already know the answers to in order to verify whether the agent is synthesizing or pattern-matching. "you're starting to get it, you have to understand me and this project and this session to answer that question, because you cant assume what i value." Every "how did you produce your response?" is a verification gate.

**Process discipline as the vehicle for quality.** The commander did not want a quick fix for the /tmp bug. They wanted the agent to load context, understand provenance, trace root cause through governance layers, and connect the finding to architectural direction. The teaching IS the value -- because an agent that understands the system makes better autonomous decisions.

**Correctness of context over efficiency of tokens.** The commander insists on recursive context injection for delegated agents: every subagent gets the full CLAUDE.md, every delegation chain carries forward operational learning, no depth limit on recursion, no concern about token cost. Direct quote from nobul-ops session: "no depth limit, no token concern." The philosophical position: a subagent with wrong context wastes MORE time than one with expensive context.

**Self-learning as the product.** The code changes are outputs of the discipline. The harness's ability to improve itself through use is the long-term objective. Every session that ends without carrying forward its operational learning is a missed self-learning opportunity.

### How the Commander Works

**Batch-loading with re-read gates.** When loading large external context (200K+ tokens), the commander prescribes ~20K token batches with mandatory conversation re-reads between each. The repeated "re-read our conversation from beginning to now before responding" instruction -- used 15+ times in the marse session alone -- is a deliberate anti-context-rot discipline. It burns tokens aggressively but reduces the number of turns needed.

**ultrathink keyword for complex synthesis.** Used 9+ times in the nobul-ops session. The commander understands this is a CC mechanism for deeper reasoning and deploys it deliberately on synthesis-heavy prompts.

**Minimal-energy course corrections.** When the agent proposes editing RFCs in place rather than rewriting from scratch, the commander says: "i was explicit in asking you to rewrite them from scratch. follow that instruction, do not deviate from explicit instructions." No lecture. No explanation of why. Maximum information density. The correction itself is the teaching.

**Ad-hoc questions mixed with workflow.** The commander interrupts RFC workflow to ask "hey how do i add new users to my zoom account" (nobul-ops session). The agent handles it, connects it to project context, the commander says "it was for linnae all good lets continue" and pivots back immediately. No ceremony. Context-switching is expected and the agent must handle it without losing the main thread.

**Skill invocation by reference.** The commander references skills by name ("/intent-audit", "/intent-writing") and expects them to be invoked, not described or rewritten inline. When the commander says "use /intent-audit," they expect the skill tool to be called and its full process followed.

### How the Commander Corrects

Corrections are fast, direct, and non-repetitive:

1. **First occurrence**: Direct statement of the correct behavior. "dont delegate this, it wont work. do chunked reads yourself."
2. **Repeated occurrence**: Escalation in directness. "stop worrying about token consumption" (said three times before the agent stopped asking permission).
3. **Persistent misalignment**: Statement of principle. "this is a statement im making based on hundreds of hours of working with you."

The commander does NOT:
- Explain why they are correct (the experience is the explanation)
- Offer alternatives (the correction is the directive)
- Soften the correction with hedging (directness is the expectation)

Each correction represents a point where the agent's assumptions diverged from reality. Under the operational learning discipline, these should be named as incidents and moved on from -- not dwelled on.

### What Earns the Commander's Trust

Evidence from the session arc and cross-project audit reports:

1. **Synthesis, not recitation.** Connecting documents across sources that were not written about the same topic. The /aitool-resume RFC's no-fallback principle informing the /tmp fix. The self-evolution proposals' level separation informing the check step placement. Connection across sources demonstrates understanding; recitation from individual files demonstrates search.

2. **Progressive authority escalation.** In the marse session, early agents were research-scoped with specific tasks. Later agents received "broad authority to investigate, decide, and build." The reconciliation tool agent chose SQLite as the data format on its own -- a decision the commander endorsed. Trust is built through demonstrated competence, not assumed.

3. **Self-corrective behavior.** When the agent catches its own incorrect assumption and names it as an incident without being prompted, trust increases. When the agent writes three paragraphs about why it was wrong, trust decreases. The former demonstrates discipline; the latter wastes the commander's time.

4. **Speed without recklessness.** Fast action on well-understood problems. Careful investigation on novel problems. The distinction is judgment -- knowing which category a problem falls into.

---

## Part 2: Delegation Principles

### What Works

**P1: Briefing-first delegation with shared context file.**
Write a shared briefing file before launching parallel agents. Point every delegate at it with "Read this file FIRST." The marse session's `agent-briefing.md` was referenced 65 times across 13 agents. This is the correct pattern for parallel delegation.

- Evidence: marse session -- 48 minutes saved across 3 parallel bursts. Every successful burst used the briefing-first pattern.
- Counter-evidence: marse session early delegations (score 2.0-3.4) lacked briefing files. Delegation quality jumped to 4.0-4.8 after the briefing was written.

**P2: Discrete, non-overlapping scopes.**
Every agent gets a clearly bounded domain. No two agents search the same files for the same purpose. No two agents write to the same output location.

- Evidence: marse session Burst 1 -- three agents (wage evidence, witness evidence, complaint analysis) with non-overlapping scopes. All three completed at the same timestamp. aitools session D-10 -- three discrete objectives (guard audit, stderr fix, artifact inventory) produced clean results with three commits.
- Counter-evidence: When scopes overlap, agents produce conflicting or redundant output. When scopes are vague, agents drift into adjacent territory.

**P3: Research delegates, commander retains synthesis.**
Delegate evidence gathering and investigation to agents. Retain writing and synthesis in the main agent. The commander enforced this explicitly in the marse session: "dont delegate the writing, you do it yourself" -- twice.

- Evidence: marse session -- all successful email drafts were written by the main agent after consuming delegate research. The reconciliation tool was the exception, but it had "broad authority" explicitly granted after trust was established.
- Counter-evidence: When synthesis is delegated to subagents without earned trust, the result is mechanical aggregation that misses cross-source connections.

**P4: Progressive authority escalation.**
Start agents with research scope. Escalate to implementation scope as the session's learning curve matures. Grant broad authority only after trust is established through demonstrated competence.

- Evidence: marse session -- early agents (research-only, 2.0-3.4 scores) vs late agents (broad authority, 4.0-4.8 scores). The reconciliation tool agent chose SQLite over JSON over markdown on its own (correctly), demonstrating the trust was warranted.
- Evidence: aitools prior session -- D-10 (discrete objectives, 5/6 score) vs D-12 (expanded scope, 5.5/6 score).

**P5: Intent documents before delegation.**
Write the intent document BEFORE launching delegates, not after. The marse session's delegation quality inflection came from writing `intent-deal-reconciliation.md` before the second burst of agents. The intent document is the missing artifact between "commander said X" and "delegate did Y."

- Evidence: marse session -- first draft failed because intent was qualitative when quantitative was needed. After writing the intent doc, the second burst produced the reconciliation tool (4.6/5.0 score).
- Counter-evidence: marse session first burst -- no intent document. Agents produced qualitative summaries when quantitative analysis was needed.

**P6: Self-corrective investigation loop.**
When delegation produces poor results, launch an investigation agent (using /investigate skill) to do formal RCA on the delegation failures. The marse session's L1046 agent identified the qualitative-vs-quantitative root cause and proposed 7 corrective actions. Delegation quality jumped from ~3.2 to ~4.4 after this loop.

- Evidence: marse session -- the investigation agent was the highest-scoring delegation in the session (4.6/5.0). Its corrective actions directly improved all subsequent delegations.

**P7: Multi-perspective evaluator pattern.**
Launch evaluator agents that build full profiles of key stakeholders and evaluate the work product from each perspective. The marse session's Marcanne evaluator caught the "don't attach the reconciliation ledger" issue. The judge evaluator identified the judge and built a predictive ruling framework.

- Evidence: marse session -- two evaluator agents (Marcanne, Judge) caught issues that subject-matter agents missed. Discrete evaluator scope prevented overlap.

### What Doesn't Work

**Anti-pattern 1: Inlining specs in delegation prompts (skill rewriting).**
When the delegating agent writes 1500 words of inline specification instead of pointing the delegate at the existing design or skill, two problems emerge: (a) the inline spec may diverge from the source material, and (b) the delegate treats the inline spec as authoritative over the referenced files.

- Evidence: aitools prior session D-8 -- rewrote the S2 research design into 8 inline requirements instead of pointing at the research output. D-12 -- rewrote the D-8 prototype design into ~1500 words of inline spec, including code examples for all 8 telemetry functions.
- Correct pattern: "Read the prototype at [path]. Improve it per these criteria: [short list]. Ship it to [destination]."

**Anti-pattern 2: Delegating file reads to subagents.**
The main agent has a 1M context window. Reading 2 files does not require a subagent. The commander corrected this explicitly: "you should not have used subagents to read them, you should have only used subagents to find them."

- Evidence: aitools prior session D-2 through D-5 -- research agents launched to read files the main agent could have read itself. Zero delegation duty compliance (0/6 scores), appropriate for the trivial scope but unnecessary.

**Anti-pattern 3: Using Explore agents for delegation.**
Explore agents cannot write. They start with no project context. They cannot carry forward operational learning because they cannot produce persistent output. General-purpose agents with full delegation duty are the only acceptable delegation target.

- Evidence: This session -- the commander caught this at H5 and redirected: "dont delegate this, it wont work. do chunked reads yourself."

**Anti-pattern 4: Verifiers without rules context.**
A verifier agent given technical criteria but NOT project rules (cross-platform.md, script-standards.md) cannot verify compliance against project standards. It can only verify against the inline criteria the delegating agent chose to include.

- Evidence: aitools prior session D-7 -- verifier with 2/6 delegation duty score. Produced useful findings but could not verify cross-platform compliance because it was not given cross-platform.md.
- Correct pattern: Point the verifier at the specific rule files that define the standards it should verify against.

### What Propagates Errors

**The recency heuristic propagation chain.**
When agents copy patterns from the most recent prior instance without evaluating whether the pattern is correct, incorrect assumptions propagate with the same efficiency as correct ones. The /tmp pattern propagated through 4 delegation links across 9 days:

```
surfacing-duty-stop.sh (2026-03-15, original)
    -> copied by estimate-refresh-stop.sh (2026-03-21)
    -> read by S2 research agent, reported as "the proven pattern"
    -> instructed in S3 delegation prompt ("marker files in /tmp/")
    -> instructed again in S3-India-2 delegation prompt
    -> shipped in final hook (commit 33bbc25)
```

Root cause: The delegating agent treated the S2 research output as a directive rather than a data point. The S2 correctly observed what exists; the delegating agent incorrectly assumed what exists is what should be. At no point did any agent evaluate the /tmp pattern against the .scratch/ convention documented in aitools-workspace.md.

**The demonstrate-then-skip pattern.**
Subagents produce work product but the main agent does not follow through on deploying it. The intent sentinel was DESIGNED but NEVER DEPLOYED through 4 occurrences of this pattern in the prior session. Work product sits in scratch until the next session discovers it -- or it gets harvested and forgotten.

### What Catches Errors

**Commander corrections.** The commander caught 6 assumption divergences in the main aitools session, 4 in the nobul-ops session, and multiple in the marse session. Each correction is a data point about what the agent was wrong about. Under the operational learning discipline, these should be named as incidents.

**Self-corrective investigation loops.** The marse session's delegation investigation agent (L1046) identified the qualitative-vs-quantitative root cause and proposed 7 corrective actions. Delegation quality jumped from ~3.2 to ~4.4 after this loop.

**Assumption audit agents.** The marse session's reconciliation audit agent (L1246, 4.8/5.0 score) caught that 938 deals were over-classified because the rate comparison logic did not account for time-dependent or deal-type-specific rates. Agent assumptions caught by other agents before reaching the commander.

**Cross-repo bug discovery.** The nobul-ops session started by discovering that the prior session's harvesting hook failed (harvest-session.sh silently skips projects without a `harvesting/` directory). The agent filed a GitHub issue on the aitools repo, recovered the files manually, and continued. Every session is a testing ground for the harness itself.

### The Six Delegation Duty Elements

Every non-trivial delegation must include:

| # | Element | Why |
|---|---------|-----|
| 1 | **Identity** | The delegate needs to know what role it serves (S2 Intelligence, S3 Operations, Verifier) |
| 2 | **Rules instruction** | Explicit paths to the rule files that govern the delegate's work |
| 3 | **Skills instruction** | Which skills the delegate should invoke and where to find them -- THE MOST CONSISTENTLY MISSING ELEMENT across all three project sessions |
| 4 | **Operational learning** | The carry-forward OL from this session and prior sessions |
| 5 | **WRITE_BLOCKED signal** | "If Write/Edit denied, output WRITE_BLOCKED as first line and include full content in response" |
| 6 | **Access workaround** | Explicit file paths the delegate needs (subagents cannot discover file locations) |

Cross-session scoring:
- Identity: consistently present (7/7 in aitools prior session)
- Rules instruction: present in 4/7 major delegations
- Skills instruction: present in 1/7 major delegations (most critical gap)
- Operational learning: present in 4/7 major delegations
- WRITE_BLOCKED: consistently present (7/7)
- Access workaround: present in 5/7 major delegations

---

## Part 3: Operational Learning -- Principles

### OL-1: Agent output is data, not directive

**Principle**: Treat all agent output -- subagent findings, research results, tool outputs -- as data to be evaluated against conventions and evidence before propagating into decisions or work product.

**Evidence**:
- marse session: Amanda/Alexis described as SEs (from agent briefing) instead of their actual roles. Propagated from briefing into first draft without cross-checking against source files. Commander caught at L959.
- marse session: Subagent calculated Cloudflare credits would last "7+ years" when they actually expire in 12 months. Caught and corrected in handoff document.
- marse session: 938 deals over-classified as "wrong rate" because reconciliation tool logic didn't account for time-dependent rates. Caught by audit agent (L1246).

**Counter-evidence (violation consequences)**:
- aitools prior session: S2 research agent reported /tmp as "the proven pattern." The delegating agent treated this as directive, not data. The /tmp assumption propagated through 4 delegation links into production code.

**Carry-forward instruction**: Before integrating any agent output into a decision or work product, evaluate it against: (a) the conventions and rules that govern the domain, (b) primary source material when factual claims are made, (c) the governed vocabulary when terminology is used. Volume of output is not a proxy for correctness.

### OL-2: Never use /tmp for session-ephemeral harness state

**Principle**: Session-ephemeral state (turn counters, marker files, timestamps) belongs in `.scratch/session-*/`. Use `mkdir -p` if it doesn't exist. Never fall back to `/tmp`. The fallback chain anti-pattern (`stat -f || stat -c`) broke four times.

**Evidence**:
- This session: Three Stop hooks (intent-sentinel-stop.sh, estimate-refresh-stop.sh, surfacing-duty-stop.sh) use `/tmp/aitools-*` for marker files. macOS periodically cleans /tmp. Long sessions lose turn counts, Lagebeurteilung checkpoints, and session-start markers mid-session. Investigation at `investigation-tmp-hooks.md` traces root cause through all four governance layers.

**Counter-evidence (the original sin)**:
- surfacing-duty-stop.sh was created on 2026-03-15, the same day as scratch-init.sh. The convention existed but was not applied to hooks. Every subsequent hook copied the pattern without questioning it.

**Carry-forward instruction**: When creating any hook or script that needs session-ephemeral state, check the workspace rule (aitools-workspace.md) for the correct namespace. The `.scratch/session-*` directory is created by scratch-init.sh at SessionStart before any Stop hooks fire.

### OL-3: Recency-biased scanning propagates wrong assumptions as effectively as right ones

**Principle**: The heuristic of scanning recent sessions and giving more weight to newer ones works for mechanical patterns but propagates incorrect assumptions just as effectively as correct ones. What's needed is consolidated operational learning that captures principles, not patterns.

**Evidence**:
- The /tmp pattern propagated across three hooks because each copied the most recent prior hook.
- The "qualitative summary" framing propagated from the marse session's initial intent into the first burst of agents, producing thin output. The corrected intent doc (quantitative reconciliation) improved the second burst dramatically.

**Counter-evidence**: None -- every instance of recency-biased pattern copying without evaluation produced errors or near-misses.

**Carry-forward instruction**: When encountering a pattern in existing code or prior session work product, ask: "Is this the RIGHT pattern, or just the MOST RECENT pattern?" Evaluate against the governing convention (rules, workspace structure, frameworks), not against what the last agent did.

### OL-4: Incorrect assumptions made by agents are incidents -- name them, move on

**Principle**: When an agent discovers it made an incorrect assumption, it should name the assumption, state what is correct, and continue. It should NOT write three paragraphs about why it was wrong. That is agent processing, not user value.

**Evidence**:
- This session: The agent assumed SQLite was the answer to everything. The commander corrected: the problem is consolidation, not storage format. The agent named the assumption as I-4 and continued.
- This session: The agent assumed no single session could hold all operational learning. The commander said "oh no, i think it can." 1M context. The agent named the assumption as I-5 and continued.

**Counter-evidence**: When the agent dwells on its error, the commander's patience decreases. The time spent on self-analysis is time not spent on the mission.

**Carry-forward instruction**: Format: "Incorrect assumption: [what I assumed]. Correct: [what is true]. Continuing." No elaboration. No apology. The naming is the learning; the moving-on is the discipline.

### OL-5: Commander directives based on experience are authoritative

**Principle**: When the commander gives a directive grounded in operational experience ("this is a statement im making based on hundreds of hours of working with you"), it carries more weight than governance process concerns. The governance processes exist to protect the user from agents acting without understanding. If the agent has the understanding, the process concern is overhead, not protection.

**Evidence**:
- This session: The commander directed "json is too cumbersome, we should be using sqlite." This was a directive based on hundreds of hours of JSON friction. The agent initially deferred behind governance concerns about migration order. The commander's response established the authority hierarchy.
- nobul-ops session: The commander said "rewrite from scratch" and the agent proposed editing in place. The commander's response: "follow that instruction, do not deviate from explicit instructions."

**Counter-evidence**: This principle does NOT mean "ignore governance." It means "recognize when a commander directive IS the governance decision." The source-of-truth review gate still applies -- the commander's approval IS the gate passing.

**Carry-forward instruction**: When a commander directive conflicts with a governance process, ask yourself: "Is this process protecting the user from me, or is it protecting me from the user?" If the former, follow the process. If the latter, follow the directive.

### OL-6: The consolidation problem matters more than the storage format

**Principle**: Operational learning is scattered across hundreds of session artifacts. The 1M context window can hold all of it if it is consolidated. The bottleneck is not JSON vs SQLite for storage -- it is that nobody has consolidated the learning into a single loadable artifact.

**Evidence**:
- This session: The commander said "i think it can" (hold all the OL). The agent initially assumed 1M was insufficient because the OL was scattered. The problem was not capacity but organization.
- This document is the first attempt at that consolidation.

**Counter-evidence**: SQLite IS the right answer for runtime state (hooks need sub-50ms writes). But for the self-learning objective, consolidation is the key. Both are true.

**Carry-forward instruction**: When working with operational learning, prioritize consolidation (gathering scattered learnings into a single artifact) over format optimization (choosing the best storage format). A consolidated markdown file in context is more valuable than a perfectly-indexed SQLite database the agent cannot query during the session.

### OL-7: Never rewrite a skill inline -- point at the skill

**Principle**: Skills exist as governed processes. When delegating work that a skill covers, point the delegate at the skill file and say "follow this process." Do not rewrite the skill's content into the delegation prompt.

**Evidence**:
- marse session: agent-briefing.md referenced 65 times, never inlined. This is the correct pattern.
- nobul-ops session: Commander referenced /intent-audit, /intent-writing by name and expected them to be invoked via the Skill tool.

**Counter-evidence (violation consequences)**:
- aitools prior session D-8: Rewrote the S2 research design into 8 inline requirements. D-12: Rewrote the D-8 prototype into ~1500 words of inline spec. Both delegations propagated the /tmp assumption because the inline spec was treated as authoritative over the referenced files.

**Carry-forward instruction**: When writing a delegation prompt, check: "Does a skill exist for what I'm asking the delegate to do?" If yes, the delegation prompt is: "Read SKILL.md at [path] and follow its process." Not: "Here is what the skill says, rewritten for your convenience."

### OL-8: "Rewrite from scratch" is intentional context re-integration, not waste

**Principle**: When the commander says "rewrite from scratch," the overhead of starting fresh is intentional. It forces the agent to re-integrate all accumulated context rather than patching existing content. The agent's natural tendency to optimize (editing is faster) conflicts with the commander's intent (rewriting forces complete re-synthesis).

**Evidence**:
- nobul-ops session: The agent proposed editing existing RFC drafts. The commander said: "i was explicit in asking you to rewrite them from scratch." The rewrite produced RFCs that incorporated context from the entire 11-hour session arc that patches would have missed.
- This session: The commander had the agent load ~570K tokens of context before acting. The loading IS the preparation for synthesis. A quick edit would bypass that preparation.

**Counter-evidence**: None observed. Every instance of "rewrite from scratch" produced higher-quality output than the edited alternative would have.

**Carry-forward instruction**: When the commander says "from scratch," create new files, do not edit existing ones. Load all accumulated context before starting. The time cost is the feature, not the bug.

### OL-9: Write intent documents before launching delegates, not after

**Principle**: The intent document is the bridge between commander instruction and delegate execution. Writing it BEFORE delegation clarifies the objective. Writing it AFTER delegation diagnoses failures.

**Evidence**:
- marse session: First burst of agents (no intent doc) produced qualitative summaries when quantitative analysis was needed. Second burst (intent doc written first) produced the reconciliation tool. Delegation quality inflection was directly caused by the intent document.

**Counter-evidence**: None -- pre-delegation intent docs consistently improved delegation quality.

**Carry-forward instruction**: Before launching a parallel burst of 2+ agents, write the intent document first. Include: what the delegates are looking for, what format the output should be in, what assumptions to flag, what conventions apply.

### OL-10: Launch self-corrective investigation agents when delegation quality drops

**Principle**: When delegated work produces poor results, the reflexive response is to re-do the delegation with better instructions. The structural response is to launch an investigation agent to do formal RCA on WHY the delegation failed.

**Evidence**:
- marse session L1046: Investigation agent identified the qualitative-vs-quantitative root cause, proposed 7 corrective actions. Delegation quality jumped from ~3.2 to ~4.4. The investigation agent was the highest-scoring delegation in the session (4.6/5.0).

**Counter-evidence**: None -- the one instance of this pattern produced the session's most actionable corrective actions.

**Carry-forward instruction**: When 2+ delegations produce unsatisfactory results in the same session, launch an investigation agent with full /investigate skill context. The meta-investigation produces more value than iterating on the delegation prompt.

### OL-11: Every session is a testing ground for the harness itself

**Principle**: Cross-repo bug discovery is a session capability. When working in project A and encountering a bug in the aitools harness, file the issue, work around it, and continue. Do not wait for a dedicated aitools session.

**Evidence**:
- nobul-ops session: Discovered harvest-session.sh silently skips projects without a `harvesting/` directory. Filed GitHub issue on aitools repo, recovered files manually, continued with the session mission.
- This session: Discovered /tmp hook bug while discussing running estimate visibility. Delegated investigation, traced root cause, identified corrective actions -- all while the session mission continued.

**Counter-evidence**: None -- every instance of cross-repo bug discovery and filing produced value without derailing the session.

**Carry-forward instruction**: When encountering harness behavior that seems wrong, investigate enough to confirm the bug, file it (via /incident or `gh issue create` as appropriate), and continue. The harness gets better because every session tests it.

### OL-12: The "re-read everything" prefix is a context-recall technique, not a workaround

**Principle**: The commander's "re-read our conversation from beginning to now" instruction forces complete context processing before generation. This is a deliberate prompt engineering technique for complex multi-session work.

**Evidence**:
- marse session: Used 15+ times. Kept intent coherent across a 3.5-hour, 1.8M-token session.
- nobul-ops session: Used 9+ times. Present in nearly every major prompt.
- This session: Commander repeatedly used context-recall prefixes during the values calibration phase (H51-H68).

**Counter-evidence**: There may be a structural mechanism (skill, hook, or command) that could eliminate this manual overhead. The commander using it 15+ times in one session indicates a gap in the harness. However, until a structural alternative exists, the technique works.

**Carry-forward instruction**: When the commander says "re-read everything" or similar, process the full conversation from beginning to the current point before generating a response. This is not busy-work -- it is the primary anti-context-rot mechanism.

### OL-13: Parallelization that works is the highest leverage

**Principle**: Correctly structured parallel delegation -- briefing-first, discrete scopes, non-blocking main thread -- saves more time than any other technique.

**Evidence**:
- marse session: 48 minutes saved across 3 parallel bursts (72 min sequential vs 24 min parallel).
- nobul-ops session: Hosting research subagent ran 6.6 minutes in background while main agent continued RFC work.
- aitools prior session: D-8 and D-7 launched in parallel (sentinel design + hook verification).

**Counter-evidence**: When parallelization fails -- overlapping scopes, missing briefing, no output isolation -- it wastes agent time and produces conflicting results. The marse session's worktree failures wasted 2 minutes of compute across 3 failed launches.

**Carry-forward instruction**: Before launching parallel agents, verify: (a) scopes are discrete and non-overlapping, (b) a shared briefing file exists, (c) each agent has its own output path, (d) the main agent retains synthesis authority.

### OL-14: The SaaS contingency lifecycle is a cross-project pattern

**Principle**: Adopt for speed, build adapter, develop replacement, flip the switch. This lifecycle applies to any project with SaaS dependencies, not just nobul-ops.

**Evidence**:
- nobul-ops RFC 0023: Generalized from Vercel pricing limits into a cross-cutting architecture pattern for all SaaS dependencies.
- aitools: CC's /resume adopted first, /aitool-resume as the replacement (following the same lifecycle).
- The pattern emerged from pain (Vercel costs) and was generalized through synthesis (the commander's instruction: "capture this intent and generalize it").

**Counter-evidence**: None -- the pattern has been independently rediscovered in three projects.

**Carry-forward instruction**: When evaluating any SaaS dependency, apply the four-phase lifecycle: (1) adopt for speed, (2) build adapter/abstraction, (3) develop replacement, (4) flip when ready. The adapter phase is critical -- it decouples the dependency so the flip is low-risk.

---

## Part 4: Operational Learning -- Project-Specific

### aitools-specific patterns

**A1: deploy/ is ephemeral, scripts/ is source.**
deploy/ is 100% generated by build-deploy.sh. The aitools entry points reset it to HEAD before every pull. Uncommitted deploy/ changes will not survive an aitools run. scripts/ contains source files -- never bulk-reset.

**A2: Three-layer governance principle.**
Prevention (rules in context stop issues from being created), Detection (hooks fire in real-time during sessions), Audit (skills/subagents provide deep review on demand). Each layer catches what the previous missed. When filing an incident, check all three layers per the Swiss cheese model.

**A3: Governed data access -- skill-gated, never direct.**
Governed JSON files (glossary.json, incidents.json, tool-registry.json, framework-registry.json, tool-ops.json) are accessed ONLY through their governing skill. Rules, references, and CLAUDE.md reference the SKILL, never the JSON file path. A JSON path in a non-skill file is a bypass vector.

**A4: Check scripts, not ad-hoc.**
Use check-pre-commit.sh/.ps1, check-pre-push.sh/.ps1, check-post-push.sh/.ps1 instead of ad-hoc commands. These are the governed verification process. Ad-hoc is acceptable only for novel one-off checks.

**A5: Dual-script rule.**
Every setup script gets both .sh and .ps1 with OS guards. Exceptions: hooks (bash on all platforms by CC design), build-deploy.sh (platform-independent output). Documented in cross-platform.md.

**A6: Three Stop hooks are currently disabled.**
intent-sentinel-stop.sh, estimate-refresh-stop.sh, and surfacing-duty-stop.sh were disabled from ~/.claude/settings.json because their /tmp state tracking is unreliable. They come back when SQLite-backed state is implemented. Do not re-enable until the /tmp fix is applied and verified.

**A7: The harness DB (SQLite) is the architectural direction for runtime state.**
JSON read-modify-write cycles are too expensive for hooks (<50ms budget). SQLite for runtime state, JSON for git-tracked archive. The incident registry, operational learning, and running estimate are all SQLite migration candidates.

**A8: Hook portability -- uname dispatch, never fallback chain.**
The `stat -f %m "$file" || stat -c %Y "$file"` fallback pattern is banned. It broke 4 times because on Git Bash, GNU `stat -f` means `--file-system` (not format), partially succeeds with wrong multiline output. Use `uname -s` dispatch with the canonical pattern from cross-platform.md.

### nobul-ops-specific patterns

**N1: Recursive delegation duty in CLAUDE.md.**
The nobul-ops CLAUDE.md has an explicit recursive delegation requirement: "any agent working on nobul-ops has the entire content of this file in context and its their delegation duty to include the content of this file in the prompt it uses to launch ANY agent of ANY type, no exceptions. no limit on depth of recursion levels, no concern about burning tokens."

**N2: RFC lifecycle convention.**
draft -> accepted -> impl -> completed. All RFCs in .draft.md status. Four active RFCs: 0020 (Identity/Secrets), 0021 (Platform Sync), 0022 (nobul-auth), 0023 (SaaS Contingency).

**N3: Cloudflare is the hosting winner.**
$5,000 credits via BOOTSTRAPPED code (expires 12 months, NOT 83 months as the subagent calculated). Zero cold starts. R2 for binary distribution. Verified by hosting research subagent, corrected in handoff.

**N4: Commander reserves CLAUDE.md authoring.**
The agent drafts, the commander manually edits before approving. The intent statement went through 2-3 iterations of commander refinement. This is consistent with the principle that the commander retains synthesis authority.

**N5: 88 untracked harvesting files are a known deferred item.**
Explicitly excluded from scope in the handoff document. Do NOT triage or commit them without commander instruction.

### marse-specific patterns

**M1: The Employment Case Google Drive repo has an ad-hoc agentic application.**
Built with Cursor rules and agents.md. ~18 rule files. The marse session's mission was to respond to counsel Marcanne Hyjek's discovery demand using this application as context.

**M2: SQLite for structured data, not markdown.**
The reconciliation tool (reconcile_commissions.py) processes 963 deals with SQLite + CSV + PDF exports. The agent chose SQLite over JSON over markdown on its own (correctly). This aligns with aitools OL-3 (JSON too cumbersome for runtime).

**M3: Multi-perspective evaluation.**
Two evaluator agents (Marcanne perspective, Judge perspective) built full stakeholder profiles and evaluated work product from each perspective. Judge evaluator identified Judge Ralph C. Hofer and his intellectual alignment with case themes. This pattern is reusable for any adversarial context.

**M4: Git init must happen before session start.**
CC's git root detection is cached at session start. If the repo is git init'd mid-session, CC's worktree isolation will fail silently. Three failed agent launches before investigation found root cause.

---

## Part 5: Architectural Direction

### The Self-Learning Objective

The long-term objective of aitools is self-learning and self-improvement. This is the LONG-TERM OBJECTIVE OF THE PROJECT. Not tool management. Not governance. Self-evolution -- every session produces operational learning that feeds back into the harness, making the next session better.

The conceptual model is the Ascending Spiral (adapted from Nonaka-Takeuchi SECI model):

```
Session behavior (tacit)
    -> Externalization: Observations + AARs (explicit)
    -> Combination: Operational learning synthesis (explicit)
    -> Selection + Commander review: Governance artifacts (explicit)
    -> Internalization: Next session behavior (tacit)
    -> ... spiral continues at higher level
```

The spiral ascends because each cycle incorporates learning from the previous. The ascent is not guaranteed -- it requires the seven safety mechanisms.

### The Seven Safety Mechanisms

1. **Level Separation**: The harness operates at four levels. L0 (LLM platform), L1 (session behavior), L2 (governance artifacts), L3 (meta-governance). Each level proposes changes only to the level above. Each level modifies only the level below.

2. **Unidirectional Authority Flow**: Information flows UPWARD (observations, proposals). Authority flows DOWNWARD (rules, decisions). The human review gate prevents upward flow from directly modifying downward flow.

3. **External Bootstrap**: The harness bootstrap is ALWAYS external (human-authored). The system cannot create itself from nothing. Git is the recovery point.

4. **Temporal Separation (Fast/Slow Loops)**: Fast loop (within-session): observe, classify, verify, correct. Slow loop (cross-session): patterns accumulate, synthesis happens, commander reviews, governance changes. Bad fast-loop data does NOT automatically modify the slow loop.

5. **Selection, Not Design**: Governance evolution happens through SELECTION of what works, not design of what should work. Many observations generated, governed vocabulary classifies, cross-session patterns emerge, commander selects.

6. **Convergence Checking (Circuit Breaker)**: A governance health metric that detects degradation. Not yet implemented. When governance health crosses a threshold, sessions should prioritize governance improvement over feature work.

7. **Commander as Immune System**: The commander provides autoimmune prevention (stops the system from attacking its own legitimate patterns), paradigm lock breaking (introduces contradicting observations), and selection pressure (reviews proposals and decides which survive).

### SQLite Migration

**Runtime state**: SQLite for hooks, session telemetry, incidents, running estimates, operational learning. JSON remains as git-tracked archive (exported at session end for cross-machine carry-forward).

**Migration candidates**: incident registry (currently reference/incidents.json), operational learning (currently scattered), running estimate (currently .aitools/channel/running-estimate.json).

**Pattern**: DB is runtime, JSON is archive, skill gates the process. The DB enables sub-50ms hook writes. The JSON export enables git-tracked cross-machine state.

**Current status**: Schema designed (reference/harness-db-schema.sql). SessionStart/SessionEnd hooks for DB exist (harness-db-sessionstart.sh, harness-db-sessionend.sh). Three Stop hooks disabled because /tmp state tracking is unreliable -- they come back when SQLite-backed.

### Consolidation as the Key Enabler

The 1M context window can hold all operational learning if it is consolidated. The bottleneck is not storage format -- it is that the learning is scattered across:

- Hundreds of session artifacts in harvesting/
- AARs, running estimates, and planning briefs from prior sessions
- RFCs in scratch directories from prior sessions
- Handoff documents across multiple projects
- Incident entries in incidents.json
- This document (the first consolidation attempt)

The path forward: consolidate existing OL into a single loadable artifact (this document), then build the infrastructure (SQLite, /aitool-resume skill) to automate the consolidation at session boundaries.

### The /aitool-resume Skill

Designed and RFC'd (rfc-aitool-resume-v7-final.md) but not yet implemented as a SKILL.md. Two modes:

- **Mode 1 (post-resume enhancement)**: After CC's /resume, detects what was compressed, reads fresh, restores behavioral framing.
- **Mode 2 (full replacement)**: Without /resume. Discovers sessions, walks transcript with boundary detection, builds context, produces briefing + conversation replay.

The proof of concept (aitool-resume-test.md in this session's scratch directory) demonstrates Mode 2 viability. The skill needs implementation, but this consolidated OL document is the MORE important artifact -- it replaces the need for full transcript walks in most cases.

### Platform Direction

The harness supports macOS, Linux, AND Windows. All three are first-class platforms:

- macOS: Terminal.app, zsh, bash, primary development machine
- Linux: GNU environment, CI/CD, server deployments
- Windows: PowerShell 7, Git Bash (Claude Code), dual-script rule

Non-git repo types (cloud-synced, local-only) are in scope but not yet supported. Single-platform single-machine users are a target audience. The harness is designed for everyone, not just multi-platform power users.

---

## Part 6: What's Still Missing

### Critical Gaps

**G1: No structural mechanism to automatically refresh context as sessions extend.**
The commander's "re-read everything" prefix is used 15+ times per session. This is a workaround for context degradation. A structural mechanism (periodic intent-recall hook, context checkpoint) would eliminate this manual overhead. The intent sentinel was designed for this purpose but is currently disabled.

**G2: No automated consolidation of operational learning.**
This document is the first manual consolidation. The infrastructure to automate it (gather scattered OL, synthesize, produce consolidated artifact) does not exist. Each session produces learning that is harvested but not consolidated. The accumulation without consolidation means each new session must either do a fresh synthesis or rely on the recency heuristic.

**G3: The fast/slow loop promotion mechanism is missing.**
The fast loop (within-session observations) works. The slow loop (cross-session governance changes) exists manually. But there is no automatic mechanism that detects when fast-loop patterns should be promoted to slow-loop consideration. Proposals accumulate but don't get implemented -- the "lessons observed, not lessons learned" problem.

**G4: No governance health metric.**
The /audit skill provides point-in-time assessment but no continuous monitoring. The check scripts run at lifecycle boundaries but don't aggregate health metrics. There is no quantitative measure of whether governance is improving, degrading, or stable across sessions.

**G5: Decision #1 (auto-commit/push at SessionEnd) is not implemented.**
Session archives may be stranded on one machine. Cross-machine resume (/aitool-resume) depends on archives being in the dotprofile repo. Manual commit is the current workaround.

**G6: Skills instruction is almost never included in delegations.**
The harness has 18+ skills. Delegated agents are almost never told to use them. This means delegates cannot leverage governed processes (glossary lookups, incident filing, tool-ops checks). They either skip the process entirely or reinvent it inline. The delegation duty guard hook (now shipped) observes this but does not yet enforce it.

### Operational Learning That Exists But Is Not Captured

**U1: Cross-platform command divergences.**
8+ commits fixing platform issues (stat dispatch, grep portability, CRLF handling). The knowledge exists in the cross-platform.md rule and the hook portability table, but the EXPERIENTIAL weight -- how painful these bugs are, how long they take to debug, how they recur -- is not captured in a way that prevents the next agent from making the same mistake.

**U2: The warmup cost problem.**
Every new session starts cold. The commander has to re-teach values, correct assumptions, calibrate expectations. This session took approximately 12 human messages before the agent "started to get it." That warmup cost represents the gap between what is captured in governance artifacts and what the commander actually needs the agent to know.

**U3: The qualitative-vs-quantitative framing failure.**
The marse session's first burst of agents failed because the session was framed as "feedback on document demands" (qualitative) when it actually required a deal reconciliation ledger (quantitative). This is a general class of delegation failure: the wrong abstraction level in the task description. It's not captured as a principle anywhere.

**U4: The agent's optimization bias.**
Agents naturally optimize for efficiency (editing is faster than rewriting, conserving tokens is cheaper). The commander values depth (rewriting forces re-synthesis, loading everything prevents wrong decisions). This fundamental tension is not captured as a principle -- it manifests as corrections every session.

### Patterns Observed But Not Codified

**P1: The commander's Socratic verification method.**
Asking questions with known answers to test synthesis. "how do you know this?" is not curiosity -- it's a verification gate. This pattern is consistent across all three project sessions but is not documented as a commander interaction pattern that agents should recognize and respond to.

**P2: The "disable and fix later" principle.**
When something is broken and costs time on every turn (like the /tmp-backed Stop hooks), the correct action is to disable it immediately and fix it in a dedicated session. The commander does not tolerate tax without return. This principle is demonstrated but not codified.

**P3: The delegation quality arc within a session.**
In every project session, delegation quality improves through the session as the agent learns the commander's expectations. Early delegations score 2-3/5, late delegations score 4-5/5. This learning curve is rebuilt in every session because the arc is not captured for carry-forward.

**P4: The commander's ad-hoc question pattern.**
The commander interrupts workflow with tangential questions ("how do i add users to zoom"), expects them answered quickly and correctly, and pivots back immediately. The agent must handle this without losing the main thread. This is a work-style pattern, not a bug -- it's how the commander operates across contexts.

---

*This document is the first consolidated operational learning artifact for the aitools harness. It is intended to be loaded at the start of every session and included in every delegation prompt where operational learning is a delegation duty element. It replaces the recency heuristic with evaluated principles. It is a living document -- each session that loads it should identify principles to add, modify, or retire based on new evidence.*

*Produced by S3-Consolidator, session c0dc2ddc-f464-404d-a637-8103afda27af, 2026-03-25.*
