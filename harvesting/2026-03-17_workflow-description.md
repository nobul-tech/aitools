# Workflow Pattern: Session RTzBnBupE6

This documents the exact workflow that emerged during this session.
Written by the main agent (S3) who has the full conversation in context.
A subagent should generalize this into a decision.

## The trigger

User noticed `.aitools/channel/` appeared at repo level and questioned
whether it matched their intent. This triggered an investigation.

## Step 1: Investigation (S2 subagent)

Main agent launched S2 to audit session transcript b8a9ed4e for the
decision that created `.aitools/channel/`. S2 produced a structured
investigation report (`channel-placement-investigation.md`).

**Key pattern**: S2 investigated, main agent SPOT-CHECKED the results
(per UCI "Verify subagent audit results"). The spot-check revealed
S2's central claim was wrong (missed queue-operation messages). This
led to incident #49 being filed.

## Step 2: Resolve the actual issue with the user

Main agent and user discussed the workspace design. User clarified
their intent (harness capabilities, cross-machine carry-forward,
project vs user scope). This produced:
- New rule: `.claude/rules/aitools-workspace.md`
- Updated dotprofile CLAUDE.md (carry-forward intent)

## Step 3: Audit the briefing for consistency (S2 subagent)

Main agent launched S2 to audit all 52 decisions against the new rule.
S2 produced structured AAR-format JSON output (`workspace-audit.json`)
with observations, insights, and proposals — each proposal with exact
old/new text and barrier analysis.

**Key pattern**: The output was STRUCTURED (AAR schema with
observations/insights/proposals), not freeform markdown. Each
proposal included barrier analysis and exact replacement text.

## Step 4: User pushes for efficiency

User said "this feels very inefficient" about the 10-amendment
approach. Asked to search the provenance of our frameworks for
institutional approaches. This triggered:

## Step 5: Parallel barrier analysis (3 S2 subagents)

Main agent identified 3 institutional patterns from our framework
provenance:
- FRAGORD (military FM 101-5-2)
- governedBy schema field (configuration management / DRY / ISO 10007)
- Amendment + codification (legal/regulatory)

Launched 3 S2 subagents IN PARALLEL, each performing barrier analysis
on one option. All returned PARTIAL. The synthesis identified
`governedBy` as the strongest long-term fix.

**Key pattern**: Multiple options analyzed in parallel with the SAME
barrier analysis framework. Enables apples-to-apples comparison.

## Step 6: User pushes to think bigger

User said "what about hooks? what about web calls? think outside the
current capabilities." This triggered a deeper investigation.

## Step 7: Full prevention stack investigation (S2 subagent)

Main agent launched S2 to design the complete prevention stack,
thinking beyond current harness capabilities (hooks, Datadog
telemetry, learning loop integration). S2 produced a comprehensive
investigation (`investigate-full-prevention.md`) with:
- 5 Whys root cause chain
- Swiss cheese model mapping
- 5-element combined stack
- Full incident replay with all elements
- Minimal viable stack identification (E1+E2)
- Build sequencing respecting roadmap dependencies

## Step 8: Apply amendments in worktree (S3 subagent)

Main agent launched S3 to apply the 10 mechanical amendments to the
brief. Used the `isolation: "worktree"` parameter. S3 reported
10/10 applied (one partial match with trailing notes preserved).

**Key pattern**: The PROPOSALS from Step 3 contained exact old/new
text. The EDITOR subagent consumed those proposals mechanically.
The audit produced the fix specification; the editor applied it.

## Step 9: Re-audit the edits (S2 subagent)

Main agent launched S2 to re-run the SAME audit that produced the
proposals (Step 3), verifying the amendments were correct and
intent was preserved. S2 reported 14→1 inconsistencies remaining
(the 1 was a cross-decision hook architecture issue, not workspace).
Intent preservation: zero issues.

**Key pattern**: The SAME CHECK that found the problem verified
the fix. The auditor was independent from the editor.

## Step 10: Design the structural fix (S2 subagent)

Main agent launched S2 to investigate the governed document drift
decision — scope of `governedBy`, hook architecture, schema
placement, interaction with existing decisions. S2 produced a
complete draft decision #53 with barrier analysis on each design
choice.

## The generalized workflow

1. **Finding** emerges (from AAR, audit, investigation, check script,
   user observation, or any other source)
2. **S2 investigates** — audit the finding against governing artifacts,
   produce structured output (AAR schema: observations/insights/proposals
   with barrier analysis)
3. **Main agent spot-checks** S2 results (UCI compliance)
4. **Generalization check** — can this finding improve the harness?
   Launch S2 subagent to evaluate adaptation potential
5. **If harness change proposed** — launch PARALLEL S2 subagents for
   barrier analysis on each option (use institutional provenance)
6. **Select approach** — synthesize barrier analyses, present to user
7. **Apply changes** — launch S3 subagent (worktree isolation) with
   exact edit specifications from the audit proposals
8. **Verify changes** — launch S2 subagent to re-run the original
   audit, verify zero inconsistencies and intent preservation
9. **For unresolved items** — launch parallel S2 subagents with
   /investigate + barrier analysis on each option
10. **Iterate** steps 7-9 until clean, then present to user

## Key design principles observed

- **Structured output**: Every subagent produces structured JSON/AAR,
  not freeform prose. Enables mechanical consumption by downstream agents.
- **Same check verifies the fix**: The audit that found the problem is
  re-run to verify the fix. Independent auditor from editor.
- **Parallel barrier analysis**: When multiple options exist, analyze
  them in parallel with the same framework for apples-to-apples comparison.
- **Worktree isolation**: Edits happen in isolation; verification happens
  in the same isolation before merging.
- **Spot-check subagent results**: Main agent always verifies before
  acting on subagent findings (UCI compliance).
- **Provenance-informed options**: Search the source disciplines of our
  frameworks for institutional approaches before inventing from scratch.
- **User as commander**: User sets intent and approves; agents propose
  and execute. The user pushed for efficiency and bigger thinking at
  key moments.
- **Iterate until clean**: Don't present to user until the cycle
  (edit → verify → resolve outstanding) produces a clean result.
