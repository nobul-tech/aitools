# /incident skill expected behaviors

## Auto-trigger tests

The skill should auto-load when Claude detects:
- A rule says one thing but code does another
- A cross-reference points to a missing section
- Two rules give conflicting guidance
- No spec covers a common decision point
- Something went wrong in production with real impact

## Non-trigger tests

The skill should NOT auto-load for:
- Normal code writing tasks
- Bug fixing with clear repro steps (those are GH issues)
- Feature requests (those are ROADMAP items)
- Tool evaluation (those go in tool-registry.md)

## Filing accuracy

When filing an incident:
- ID must be max(existing IDs) + 1
- All required fields present per incident-governance.md
- Status always "open" for new entries
- Severity matches the definitions (not inflated)
- rootCause/correctiveAction/preventionLayer null for new filings unless already known
- created/updated both set to current date
- Presents for user review before writing (protected file)

## Classification accuracy

- Code differs from rule → incident (spec deviation)
- Rule is unclear → incident (ambiguity)
- No rule exists → incident with governance gap note
- Something broke in production → incident (operational) with rootCause
- Bug with repro → redirect to gh issue create (not filed here)
