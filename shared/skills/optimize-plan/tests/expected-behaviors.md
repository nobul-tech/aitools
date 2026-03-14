# /optimize-plan expected behaviors

## Auto-trigger tests

Should auto-load when:
- User says "review the plan" or "optimize the plan"
- User says "is this plan still accurate?"
- User asks "what should we work on next?" (leverage assessment)
- Starting a new session on a multi-session plan

Should NOT auto-load for:
- Writing a new plan from scratch (that's /planning or /aitools-planning)
- Normal coding tasks unrelated to plan review
- Filing a gap (that's /gap)

## Detection accuracy

### Stale sections
- Should detect count mismatches (header says N, table has M)
- Should detect done markers that are wrong
- Should detect cross-references to deleted files

### Dependencies
- Should identify blocking relationships between steps
- Should flag when a completed step's scope changed

### Leverage
- Should identify which steps unblock the most downstream work
- Should NOT rank by priority (user decides priority)

### Scope
- Should detect when a plan has grown beyond its original scope
- Should suggest splits when workstreams are independent

### Missing content
- Should detect undocumented decisions (gaps in foundational decisions)
- Should cross-check known-gaps.json Open Questions

## Context awareness
- In 1M context: should load referenced rules and reference files
- In 200k context: should skip deep cross-reference validation
- Should NOT exceed context budget chasing completeness
