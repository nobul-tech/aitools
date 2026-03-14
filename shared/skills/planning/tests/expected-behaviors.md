# /planning expected behaviors

## Auto-trigger tests

Should auto-load when:
- Starting a new session on a multi-session plan
- User asks "how should we structure this work?"
- User asks about context budget or session scope
- User asks about subagent coordination
- Deciding between plan file vs direct implementation

Should NOT auto-load for:
- Reviewing an existing plan (that's /optimize-plan)
- Filing a gap (that's /gap)
- Normal coding tasks

## Context awareness
- Should reference correct context window for current model
- Should adjust injection budget calculations per model
- Should recommend 60-70% stop point

## Batch sizing
- Should recommend 2-3 file chunks
- Should flag plans with 10+ file batches
- Should recommend verification between batches

## Subagent guidance
- Should recommend subagents for research, NOT for code with cross-cutting rules
- Should recommend parallelization when queries are independent
- Should warn about the subagent context gap

## User collaboration
- Should present options rather than conclusions
- Should flag uncertainty as gaps rather than guessing
- Should ask clarifying questions when ambiguous
