---
name: planning
description: "Session and plan strategy for Claude Code sessions. Use when starting a planning session, deciding session scope, coordinating subagents, or managing context budgets. Covers batch sizing, session flow, subagent parallelization, and user collaboration patterns."
---

## Session Working Convention

### Context budget

Stop building at **60-70% context usage**. Reserve remaining for:
- Commit/push workflow
- Late-session course corrections
- Gap filing and release notes

Check `/context` periodically during long sessions.

### Context windows by model

| Model | Context Window | 10% injection budget |
|-------|---------------|---------------------|
| Opus (extended) | 1M tokens | 100k tokens ≈ 400k chars |
| Opus/Sonnet (standard) | 200k tokens | 20k tokens ≈ 80k chars |
| Haiku | ~100k tokens | 10k tokens ≈ 40k chars |

Subagents inherit the parent's model by default (`model: inherit`).
Override with `model: sonnet` etc. in skill/subagent frontmatter.

### Session flow

1. Read the plan + known-gaps.json + relevant rules
2. Work through implementation steps in order
3. Surface ambiguities as they arise (surfacing duty)
4. At 60-70%: stop building, file gaps, update release notes, commit,
   tag, push
5. If more work remains, note where to resume in the commit message

## Planning Patterns

### When to create a plan file

Create `plans/*.md` when work:
- Spans multiple sessions
- Has phased gates or dependencies
- Needs detailed design beyond a roadmap row
- Modifies 3+ code files or shared libraries

### Batch sizing

Break implementation into **2-3 file chunks** with verification between.
Large batches (10+ files) cause rule fade — cross-cutting concerns get
ignored even when rules are in context.

After each batch:
- Re-read the rules that apply to the next batch
- Run tests/checks
- Verify the completed batch doesn't break existing behavior

### Verbatim code vs pseudocode

- **Verbatim** (exact old_string/new_string): For production code, shared
  libraries, scripts with error-handling requirements
- **Pseudocode** (sketch the approach): Only for exploratory/design phases
  where the exact code depends on findings

Plans with pseudocode that'll need improvisation during implementation
produce more violations than plans with verbatim code.

### Foundational decisions

Every plan that resolves ambiguities should capture them in a
"Foundational Decisions" section — numbered, authoritative, not revisited
unless explicitly reopened.

## Subagent Coordination

### When to use subagents

- **Research tasks**: Exploring codebases, reading docs, searching for patterns
- **Parallel independent queries**: Multiple searches that don't depend on each other
- **Protecting context**: Heavy exploration output stays in the subagent, summary returns

### When NOT to use subagents

- Writing code in projects with cross-cutting rules (subagents don't inherit rules)
- Tasks that need the full conversation context
- Simple, directed searches (use Grep/Glob directly)

### Subagent context gap

Subagents do NOT inherit:
- Project rules (`.claude/rules/*.md`)
- Skills from parent conversation
- CLAUDE.md content

Mitigation: SubagentStart hook injects skills and governance context
via pre-built cache (when deployed). Until then, include critical rules
in the subagent prompt.

### Parallelization

Launch multiple subagents in a single message when queries are
independent. Use `run_in_background` for tasks you don't need results
from immediately.

Do NOT duplicate work — if you delegate research to a subagent, don't
also perform the same searches yourself.

## User Collaboration

### User as co-architect

During planning, actively involve the user:
- **Present options, not conclusions.** "Here are three approaches,
  which fits?" beats "I recommend X."
- **Flag uncertainty explicitly.** "I'm not sure about Y — what's your
  take?" instead of guessing.
- **Ask for domain knowledge.** The user has context that no amount of
  codebase exploration replaces.

### Clarify before complying

If a user response seems to contradict or reverse a prior recommendation,
ask: "Just to confirm — did you mean X or Y?" A quick clarification
avoids wasted work from miscommunication.

### Don't assume

When uncertain about a design decision, file it as an open question
or ask the user. "Probably" is ambiguous — mark it as a gap that needs
resolution, or ask.
