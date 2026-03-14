# /rca expected behaviors

## Auto-trigger tests

Should auto-load when:
- User asks "why did this happen?"
- Investigating a failure or unexpected behavior
- Analyzing a pattern of recurring issues

Should NOT auto-load for:
- Full incident lifecycle (that's /incident-response)
- Filing a gap (that's /gap)
- Normal debugging without investigation intent

## Investigation depth
- Should apply 5 Whys (at least 3 levels deep)
- Should identify contributing factors (not just single root cause)
- Should categorize the root cause (rule fade, missing enforcement, etc.)
- Should recommend corrective action TYPE, not just "fix it"

## Output quality
- Should distinguish symptoms from causes
- Should identify which defense layer failed
- Should recommend verification step for the fix
