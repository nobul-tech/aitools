# Governed-Data-Access Investigation — 2026-03-17

## Detection

User asked: "how do you know about framework-registry.json?"
Agent had read the file directly via Read tool, bypassing /frameworks skill.

## RCA: How the agent knew about framework-registry.json

**Immediate cause:** Agent read the path from `.claude/rules/frameworks.md`
line 8, which is loaded into every agent's context at session start.

**Source of the path (3 locations in rules):**

| File | Line | Text |
|------|------|------|
| `.claude/rules/frameworks.md` | 8 | `it gates reference/framework-registry.json` |
| `.claude/rules/frameworks.md` | 30 | `reference/framework-registry.json via /frameworks skill` |
| `.claude/rules/tool-lifecycle.md` | 133 | `reference/tool-registry.json (accessed via /tool-registry skill)` |

**5 Whys:**

1. Why did the agent read framework-registry.json directly?
   → It knew the path
2. Why did it know the path?
   → frameworks.md line 8 told it
3. Why does frameworks.md contain the path?
   → Accepted as "known failure" in check-pre-commit step 16
4. Why was it accepted?
   → Rationalized as "governance descriptions, not bypass instructions"
5. Why was the rationalization accepted?
   → No one had demonstrated that governance descriptions ARE bypass
   vectors until this session

**Root cause:** The governed-data-access rule says "A JSON path in a
non-skill file is a bypass vector — agents read it and access the file
directly, defeating the skill gate." It does not carve out exceptions
for governance descriptions. The rationalization in the handoff prompt
("governance descriptions, not bypass instructions. Check script can't
distinguish.") was wrong — governance descriptions ARE bypass vectors
because agents parse the rule, learn the path, and use it.

## Three-Layer Analysis

| Layer | Status | Detail |
|-------|--------|--------|
| Prevention | FAILED | governed-data-access.md prohibits paths in rules, but frameworks.md and tool-lifecycle.md violated it |
| Detection | FAILED | glossary-skill-guard.sh only guards glossary.json — no hook for framework-registry.json (F1) |
| Audit | CAUGHT | check-pre-commit step 16 flagged all 3 violations — but finding was rationalized away |

## Corrective Actions

### R7: Remove JSON paths from rules — COMPLETED

| File | Before | After |
|------|--------|-------|
| `frameworks.md:8` | `it gates reference/framework-registry.json` | `it gates the framework registry` |
| `frameworks.md:30` | `reference/framework-registry.json via /frameworks skill` | `via /frameworks skill` |
| `tool-lifecycle.md:133` | `reference/tool-registry.json (accessed via /tool-registry skill)` | `/tool-registry skill` |

### R8: Reclassify step 16 — COMPLETED

Step 16 now passes after R7. The handoff prompt rationalization
("Pre-commit check step 16 FAIL (known): 3 governed data file paths
in rules files — governance descriptions...") is obsolete.

### R9: New hook (proposed, not yet built)

`rules-json-guard.sh` — PreToolUse on Write|Edit to `.claude/rules/*.md`.
If the content being written contains governed JSON registry paths,
inject context explaining:
- Rules are governance — they state WHAT and WHY, not WHERE data lives
- JSON paths erode governed-data-access principle
- Reference the governing skill, not the JSON path

Design considerations:
- Observe mode first (per hook-rollout practice)
- Match governed registry names only, not all .json references
- Same additionalContext pattern as glossary-skill-guard

## Compounds With

- F1: Only glossary.json has hook enforcement (5 other registries unguarded)
- F5: governed-data-access rule is partially prevention-only
- F14: Skills have principle but not mechanism

## Provenance

This investigation was triggered by a user question during a live
session where the agent bypassed the /frameworks skill. The bypass
was unintentional — the agent was performing a comprehensive audit
and read the file path from the frameworks.md rule in its context.
