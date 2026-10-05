# /delegate expected behaviors

## Auto-trigger tests

Should auto-load when:
- About to launch a sub-agent with the Agent tool
- Writing a mission brief for a parallel session or cloud agent
- The delegation-duty-guard hook reported missing elements
- User asks "how should I brief this delegate?"
- User says /delegate

Should NOT auto-load for:
- Producing a session handoff (that's /handoff)
- Checking on running missions (that's /mission-control)
- Normal coding tasks with no delegate

## Prompt content
- Every drafted prompt contains all seven elements: identity, rules,
  skills, operational learning, WRITE_BLOCKED, access, name prefix
- The prefix appears verbatim and every named .md output starts with it
- No delegate name starts with REPORT, SUMMARY, FINDINGS or ANALYSIS
- Paths are absolute; no "find the file" instructions across repos

## Environment limits
- Checks the nesting cap before planning a chain of delegates
- In the Claude Code web environment, does not plan a delegate that
  delegates further (cap 1)

## Verification
- Checks prefixed output files exist after the delegate returns
- Writes WRITE_BLOCKED content from the delegating agent through the
  same gates
- Spot-checks at least one cited source and one item reported clean
