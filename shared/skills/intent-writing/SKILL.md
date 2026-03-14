---
name: intent-writing
description: "Writing intent statements for markdown files, code files,
  and sections. Use when creating or modifying intent statements in any
  file."
---

## Intent

Equip the agent with the process for drafting intent statements —
declarations that state a file's purpose, scope, and audience. Intent
guides what content belongs in a file and is the basis for intent
verification (`/intent-audit`).

NOT for auditing existing intents against content (see `/intent-audit`).
NOT for deciding file placement (that's a design decision informed by
`@reference/framework-adoption.md`). Consumed by: any agent creating
new files, any agent modifying intent statements, any agent prompted
by the intent protection gate in `@.claude/rules/sources-of-truth.md`.

## What an intent statement must answer

1. **Purpose** — what this file exists to deliver (adopted from
   ISO/ITIL/CMMI purpose statement)
2. **Scope** — what's covered and what's explicitly excluded (adopted
   from ISO/IEC scope statement)
3. **Audience** — who consumes it and what they expect to find
   (adopted from ISO intended audience)

## When intent is needed

- **File-level**: Every markdown file (reference, plan, rule, skill)
  and every code file
- **Section-level**: When a section could be misread in isolation,
  serves a different audience than the parent file, or defines a
  concept that will be referenced from elsewhere

## Markdown files

File-level: bold `**Intent**:` block immediately after the `#` title.
Must address all three components: purpose, scope, audience.

Section-level: opening paragraph under the `##` heading that addresses
the three components. Does not need the bold `**Intent**:` marker
but must clearly state purpose, scope, and audience.

## JSON files

Intent in JSON uses a structured object in the `meta` section:

```json
"intent": {
  "purpose": "What this file exists to deliver",
  "scope": "What's covered. NOT x. NOT y",
  "audience": "Who consumes it"
}
```

Same three components as markdown, expressed as JSON fields.

## Code files

Intent in code uses the file's header comment block in whatever
comment syntax the language provides. The three components (purpose,
scope, audience) are the same as markdown.

The format adapts to the language:

- `#` — bash, PowerShell, Python, Ruby, Perl, YAML
- `//` — TypeScript, JavaScript, Go, Rust, C/C++
- `--` — SQL, Lua, Haskell
- `/* */` — CSS, Java (or Javadoc `/** */`)

Example (Python):
```python
# intent: Define the CLI entry point for aitools. NOT a library —
# not importable by other modules. Consumed by: pip install
# (console_scripts), direct invocation.
```

Example (bash):
```bash
#!/usr/bin/env bash
# setup-user-skills.sh — Deploy user-level skills to ~/.claude/skills/
#
# Intent: Deploy skill definitions from shared/skills/ to the user's
# Claude Code skills directory. NOT for project-level skills (those
# are auto-discovered from .claude/skills/). NOT for MCP server config
# (see setup-user-mcp.sh). Consumed by: aitools install, aitools sync.
# Safe to re-run. macOS/Linux only (see .ps1 for Windows).
```

Code intents follow the same protection rule as markdown intents:
draft, present for user review, write only after approval.

## Common failure modes

- **Describes content instead of purpose**: "This file contains a list
  of tools" — rejected. "Define which tools are managed, their install
  methods, and platform lifecycle — the source of truth that setup
  scripts read before modifying installers" — accepted.
- **Sells instead of documents**: "This powerful framework enables..."
  — rejected. Write for the team, not for outsiders.
- **Too vague**: "This file is about deployment" — rejected. Which
  deployment? For whom? What decisions does it inform?
- **Restates the title**: "This section is about the discovery cycle"
  — rejected. The title already says that. The intent says WHY the
  cycle exists and WHEN it applies.
- **Missing scope**: No exclusions stated. Without scope boundaries,
  every future session may add tangentially related content until the
  file loses focus.
- **Missing audience**: Not stating who consumes it. A file read by
  scripts has different requirements than one read by agents.

## Process

1. Draft the intent statement addressing purpose, scope, and audience
2. Present to user for review (protected activity)
3. Iterate — intent often takes 2-3 rounds to get right
4. Write only after user approval
5. If modifying an existing intent, show old → new

## Anti-patterns

- Writing intent after the content is complete. Intent should guide
  what goes in, not describe what ended up there.
- Copying intent from a similar file without adapting it
- Skipping section-level intent because "the file intent covers it"

## Cross-References

- Intent audit: `/intent-audit` skill
- Framework: `@reference/framework-adoption.md`
- Protection rule: `@.claude/rules/sources-of-truth.md`
- Design principle: `@CLAUDE.md` "Document intent"
