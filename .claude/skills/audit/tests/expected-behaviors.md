# /audit skill expected behaviors

## Invocation tests

- User types `/audit` → skill loads and runs full governance review
- Model should NOT auto-invoke (disable-model-invocation: true)
- Works in both plan mode and normal mode (read-only operations only)

## Detection accuracy

### Cross-references
- Should detect `@reference/nonexistent.md` as broken
- Should detect `@.claude/rules/cursor-rule-parity.md` as broken (deleted in v0.54)
- Should NOT flag valid references as broken

### Incidents.json
- Should detect duplicate IDs if two incidents share an ID
- Should flag incidents open > 90 days without a linked plan
- Should verify all required fields per incident-governance.md
- Should reject invalid severity/status values

### TODO(incident) markers
- Should find `TODO(incident):` in any file via Grep
- Should report file path and line content

### Skill health
- Should count skills in shared/skills/ and .claude/skills/
- Should flag skills missing tests/ directory
- Should estimate pre-built cache size

### Plan consistency
- Should detect count mismatches (e.g., header says 30 but table has 41)
- Should detect duplicate sections
- Should verify done markers on implementation steps

## Non-interference
- Must NOT write to any file
- Must NOT file incidents (report only — user files via /incident)
- Must NOT modify rules or references
