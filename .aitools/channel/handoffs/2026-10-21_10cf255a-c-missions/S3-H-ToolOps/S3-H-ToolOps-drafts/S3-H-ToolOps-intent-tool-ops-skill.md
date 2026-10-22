# S3-H-ToolOps draft: /tool-ops skill Intent scope (awaiting approval, NOT applied)

File: `.claude/skills/tool-ops/SKILL.md`, `## Intent` section (protected:
intent statement).

Why: this PR adds a "Per-tool ops references (where to read them)" section
to the skill. The current Intent scope says "CRUD operations on
tool-ops.json only ... NOT per-tool ops references." The new section does
not read or write reference content; it only states the lookup order
(deployed copy, then repo). If the commander reads the current scope as
excluding even that pointer, apply this wording; otherwise leave the
Intent as is.

## Old

```
**Scope**: CRUD operations on tool-ops.json only. NOT the governance
principle (`.claude/rules/tool-ops.md`). NOT the framework documentation
(`reference/framework-tool-ops.md`). NOT per-tool ops references.
```

## New

```
**Scope**: CRUD operations on tool-ops.json, and where to read per-tool
ops references (deployed copy first, then the aitools repo). NOT the
governance principle (`.claude/rules/tool-ops.md`). NOT the framework
documentation (`reference/framework-tool-ops.md`). NOT the content of
per-tool ops references.
```
