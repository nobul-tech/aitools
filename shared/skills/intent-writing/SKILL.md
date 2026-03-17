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

## Pre-write audit

Before drafting, perform these checks:

### Governed term audit

Scan draft content for terms. For each term:
1. Is it in the `/glossary` skill's governed vocabulary?
2. If not, is it widely understood without definition?
3. If neither — the term is ambiguous. Replace with a governed
   term, define it, or remove it.

The ambiguity purge from session 84280c8b found "bootstrap",
"calibrate verbosity", and "more weight" as undefined terms that
would have confused executing agents. Four passes were needed to
catch them all. Do at least two passes.

### Exemplar calibration

Read 2-3 recently approved intents (weight recent > old):
- JSON intents: check `meta.intent` in governed JSON files
- Rule intents: check `**Intent**:` blocks in `.claude/rules/`
- Skill intents: check `## Intent` sections in skill files

Calibrate your draft to match the conciseness and structural
patterns of approved exemplars. The best governed JSON intents are
one clause per field. Rule intents use negative scope boundaries
("NOT X. NOT Y.") and name specific consumers in audience.

## Multi-pass ambiguity removal

After drafting the intent, perform at least 2 self-audit passes
before presenting to the user:

**Pass 1 — Undefined terms**: Read every word. Is each term either
(a) in the governed vocabulary, (b) a common English word, or
(c) defined in the file itself? Flag anything else.

**Pass 2 — Vague mechanisms**: Look for phrases that describe
an outcome without specifying the mechanism. "Ensure quality" —
how? "Manage lifecycle" — which gates? Replace with specifics
or remove.

**Pass 3 (if anything changed in passes 1-2)**: Re-read the
complete intent after edits. Edits can introduce new ambiguities.

The 4-pass ambiguity purge in session 84280c8b killed terms at
every level — a word ("bootstrap"), a phrase ("calibrate
verbosity"), and a mechanism ("more weight"). Each pass found
something the previous missed.

## Process

1. Draft the intent statement addressing purpose, scope, and audience
2. Run pre-write audit (governed terms + exemplar calibration)
3. Run multi-pass ambiguity removal (2-3 passes)
4. Present to user for review (protected activity)
5. Iterate — intent often takes 2-3 rounds to get right
6. Write only after user approval
7. If modifying an existing intent, show old → new

## Consolidated presentation

When multiple files in one task need intents, present ALL drafts
in a single message for single-round approval:

1. Draft all intents in the batch
2. Present them together with a tracking table:
   | File | Intent status |
   |------|---------------|
   | `file-a.md` | Draft below |
   | `file-b.json` | Draft below |
3. User reviews and approves the batch, or requests specific
   revisions

In the tool-ops execution session (eaacf9da), batch 1 presented
intents one at a time — 3 rounds, 15 minutes. By batch 5, 4 intents
in one block — 1 round, "beautiful", ~42 seconds. Consolidation
reduced approval friction by 10-15x.

Sub-agents cannot receive user feedback during execution. Every
intent that requires user approval MUST be pre-approved before
delegation. The sub-agent receives verbatim intent text, not
instructions to draft intent.

## Quality criteria

Apply this checklist to every intent before presenting for approval:

| Criterion | Check | Failure mode |
|-----------|-------|--------------|
| **Concrete purpose** | Does purpose name the specific deliverable, not just the topic? | "This file is about deployment" vs "Define which tools are managed and their install methods" |
| **Negative scope** | Does scope include at least one "NOT" exclusion? | Without boundaries, scope creep is inevitable |
| **Specific audience** | Does audience name specific consumers (skills, scripts, agents, hooks)? | "Agents" is too vague — which agents, doing what? |
| **Active verbs** | Does purpose use active verbs (govern, track, define, equip)? | Passive voice ("is used for") hides what the file actually does |
| **No restated title** | Does intent add information beyond the filename/title? | "This section covers the discovery cycle" — the title says that |
| **Exemplar match** | Does the structure match recently approved intents? | Stylistic mismatch signals the drafter didn't calibrate |

## Style calibration

The approved intent style has converged through iteration:

**Markdown rules** (`.claude/rules/*.md`):
- Format: `**Intent**: **Purpose**: ... **Scope**: ... **Audience**: ...`
  as a single flowing paragraph
- Purpose: one clause, active verb, names the specific governance domain
- Scope: "X only. NOT Y. NOT Z." — at least 2-3 exclusions referencing
  skill/framework/data that live elsewhere
- Audience: "Every agent, every session" OR specific consumers + context

**Governed JSON** (`meta.intent` in registry files):
- Format: `{ "purpose": "...", "scope": "...", "audience": "..." }`
- Purpose: one sentence, often a noun phrase with qualifying dash
- Scope: "X only. NOT Y. NOT Z." — same pattern, shorter
- Audience: names specific skills, scripts, hooks by name

**Skills** (`## Intent` section):
- Format: opening paragraph addressing all three, then "NOT X" lines
- More conversational than rules/JSON
- Must name what the skill does NOT do (prevent confusion with related skills)

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
