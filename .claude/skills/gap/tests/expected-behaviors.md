# /gap skill expected behaviors

## Auto-trigger tests

The skill should auto-load when Claude detects:
- A rule says one thing but code does another
- A cross-reference points to a missing section
- Two rules give conflicting guidance
- A spec gap where no rule covers a common decision

## Non-trigger tests

The skill should NOT auto-load for:
- Normal code writing tasks
- Bug fixing with clear repro steps (those are GH issues)
- Feature requests (those are ROADMAP items)
- Tool evaluation (those go in tool-registry.md)

## Filing accuracy

When filing a gap:
- ID must be max(existing IDs) + 1
- All required fields present per gap-governance.md
- Status always "open" for new entries
- Severity matches the definitions (not inflated)
- Type is "gap" or "ambiguity" (not mixed up)
- created/updated both set to current date
- Presents for user review before writing (protected file)

## Classification accuracy

- Code differs from rule → gap (not ambiguity)
- Rule is unclear → ambiguity (not gap)
- No rule exists → ambiguity with "governance gap" note
- Bug with repro → redirect to gh issue create (not filed here)
