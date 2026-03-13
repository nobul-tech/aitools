# Governance and Compliance Framework

Implementation plan for the three-layer governance and compliance system.
Produced from design session 2026-03-13. Reference: CLAUDE.md Design Principles.

## Context

This plan covers: gap governance (known-gaps.json lifecycle), tool/process
skills (30 skills), hook specifications (SubagentStart, PreToolUse), permission
strategy, and the integration between all three layers.

Rules and CLAUDE.md changes ship first (this batch). Skills and hooks are
built incrementally after the framework is in place.

## Three-Layer Architecture

| Layer | Mechanism | When | Catches |
|-------|-----------|------|---------|
| Prevention | Rules in context, skills loaded dynamically | Every session | Stops issues from being created |
| Detection | Hooks firing in real-time | During tool calls, session events | Issues as they happen |
| Audit | `/audit` skill, `/gap` skill | On demand | What slipped through |

Skills bridge prevention and detection: they show the right way (prevention)
so hooks don't need to block the wrong way (detection). Hook stderr messages
reference skills to close the remediation loop.

## Skill Inventory

30 skills. Each defined in `shared/skills/<name>/SKILL.md`. Deployed to
`~/.claude/skills/` and `~/.cursor/skills/` by setup-user-mcp.

### Tool skills (one per managed tool)

| Skill | Tool | Key content |
|-------|------|-------------|
| `/claude` | Claude Code CLI | Session management, `-p` flags, model selection, nested session limitations |
| `/agent-cli` | Cursor Agent CLI | Differences from claude CLI, `--mode` vs `--model`, MCP enable/disable scoping |
| `/gh` | GitHub CLI | Issue workflows, PR creation, API queries, auth patterns |
| `/vercel` | Vercel CLI | Deploy, env management, project linking, auth check |
| `/pandoc` | Pandoc | Format conversion, encoding gotchas, template usage |
| `/cargo` | Rust/Cargo | Build prereqs (NASM, CMake, MSVC), cross-platform compilation, cargo install patterns |
| `/typst` | Typst | Document compilation, font paths, npm global install |
| `/pwsh` | PowerShell | Calling from bash dispatch pattern, quoting rules, write-then-execute, macOS Homebrew tap vs Windows WinGet, PS 7 baseline |
| `/modal` | Modal CLI | Auth (`.modal.toml`), container context, deployment patterns |
| `/python` | Python | `python3` vs `python` (platform), pip invocation, venv, uv integration |
| `/pip` | pip | Platform-specific invocation (`pip3` vs `python -m pip`), install patterns |
| `/uv` | uv | Virtual env management, dependency resolution, lock files |
| `/go-lang` | Go | Module management, install patterns, GOPATH vs GOBIN |
| `/pup` | Datadog CLI | Auth status check, log shipping, metric submission |
| `/perl` | Perl | String manipulation patterns replacing sed/awk, PERLIO env var (Strawberry vs Git bundled on Windows), system Perl on macOS/Linux, one-liner patterns, minimum 5.10 |

### Dependency skills

| Skill | Tool | Key content |
|-------|------|-------------|
| `/git` | Git | Project conventions, checklist integration, commit-message-via-file, branch naming, identity setup, pre/post reference file loading |
| `/node` | Node.js/npm | Package management, global installs, npm vs npx policy (never use npx), version management |
| `/bash-skill` | Bash | Cross-platform environments (Git Bash MINGW vs macOS 3.2 vs Linux GNU), pipeline patterns, quoting, PATH differences, BSD vs GNU userland |

### Build tool skills

| Skill | Tool | Key content |
|-------|------|-------------|
| `/nasm` | NASM | Install verification, path detection, required-by list, WinGet vs brew |
| `/cmake` | CMake | Install methods per platform, version requirements, path detection |
| `/msvc` | MSVC Build Tools | Visual Studio components, elevation requirements, detection patterns |

### Process/workflow skills

| Skill | Purpose | Key content |
|-------|---------|-------------|
| `/gap` | File gaps/ambiguities | Reads known-gaps.json, classifies, formats, writes. Model-invocable. |
| `/audit` | Deep governance review | Reads all rules/refs, reports gaps, cross-ref breaks, staleness. User-invocable only. |
| `/tool-eval` | Tool evaluation/onboarding | 5 lifecycle phases, chrome-devtools verification, Phase 2 gate, onboarding checklist |
| `/scratch` | Temp file conventions | Naming (session+agent prefix), cleanup, when to use, permission pre-approvals |
| `/nested-claude` | Nested session workarounds | CLAUDECODE env var, `claude mcp add` failure, `--addmcp` alternative, safe/unsafe operations |
| `/cross-platform` | Platform dispatch | OS detection, path conventions, dispatch patterns, equal visibility |
| `/dotprofile` | User repo management | profile.json fields, template tokens, template resolution, session archiving |
| `/mcp-skill` | MCP server config | Enable/disable patterns, Claude vs Cursor asymmetry, isolation mode, auth, `--addmcp` |

### Naming conventions

- Tool skills use the tool's CLI command name (e.g., `/perl`, `/cargo`, `/pwsh`)
- Three exceptions to avoid conflicts or ambiguity:
  - `/mcp-skill` — `/mcp` is a built-in Claude Code command
  - `/bash-skill` — `Bash` is a Claude Code tool name
  - `/go-lang` — `/go` is ambiguous as an English word
- Process skills use descriptive names (`/gap`, `/audit`, `/tool-eval`, etc.)

### Skill template

Every tool skill follows this structure:

```yaml
---
name: <tool-name>
description: "<tool> usage patterns, platform gotchas, and project conventions. Use when working with <tool>."
---

## Patterns
Common invocation patterns for this project.

## Platform Gotchas
Per-platform issues — every tool skill covers all managed platforms (Windows,
macOS, Linux) with platform-specific sections, not just the current platform.

## Anti-Patterns
What the standing-order-guard hook blocks and why.

## Cross-References
- Tool registry: `reference/tool-registry.md` (install, versions, lifecycle)
- Setup script: `scripts/setup-<tool>.sh/.ps1`
```

Process skills follow a task-oriented structure (steps, decision trees,
validation) instead of the patterns/gotchas/anti-patterns layout.

## Hook Specifications

### SubagentStart hook (command type)

Injects context into every subagent:

```
GOVERNANCE: Report ambiguities with "AMBIGUITY:" prefix in your response.
The main agent will triage and file via /gap. Do not file directly.

SCRATCH: Use .scratch/{session_id}_{agent_type}_ prefix for all temp files.

SKILLS: Available compliance skills — /scratch, /perl, /pwsh, /git,
/cross-platform, /bash-skill, /go-lang, /mcp-skill.
Load when relevant to your task.
```

Subagents are sensors (report findings), not filers (don't write to
known-gaps.json). Main agent reviews AMBIGUITY: items and invokes /gap.

This hook subsumes the planned "Subagent context hook & CLAUDE.md trim"
roadmap item — both inject context into subagents. Combine into one hook
that handles CLAUDE.md injection AND governance context.

### PreToolUse agent hook on known-gaps.json

- Event: PreToolUse, matcher: Edit|Write on `reference/known-gaps.json`
- Type: agent (spawns subagent with Read/Grep/Glob)
- Validates: required fields, valid enums, sequential IDs, well-formed JSON
- **Fail-open**: on timeout or error, allow the edit. /audit catches later.
- Timeout: 30 seconds

### PreToolUse prompt hook on protected files

- Event: PreToolUse, matcher: Edit|Write on sources-of-truth files
- Type: prompt (lightweight Haiku check)
- Injects reminder: "Protected file — verify cross-references and
  downstream dependencies"
- Does not block, context injection only

### Standing order guard updates

Update hook stderr messages to reference skills when blocking:
- `sed` blocked → "Use Perl for string manipulation. Load /perl for patterns."
- 5+ line inline → "Write to .scratch/ file. Load /scratch for conventions."
- `&&` blocked → "Use separate Bash tool calls."
- Standalone `grep` → "Use the Grep tool."

Closed loop: hook blocks → stderr references skill → agent loads skill →
correct pattern used.

## Permission Strategy

### Project settings.json additions

```json
{
  "permissions": {
    "allow": [
      "Edit(/.scratch/**)",
      "Write(/.scratch/**)"
    ]
  }
}
```

Eliminates permission prompts for scratch file operations. Other permissions
(Edit/Write on project files, Bash commands) remain as-is — the existing
allow rules in settings.local.json cover most Bash patterns.

### Hook-based permission decisions

PreToolUse hooks can return `permissionDecision: "allow"` for patterns
too complex for glob rules (e.g., Bash commands touching temp directories).
Implement only if permission prompts become a recurring friction point.

## Edge Cases

- **Concurrency (gap IDs)**: Accept duplicate IDs from rare races.
  /audit detects and flags for renumbering.
- **Fail-open**: All governance hooks fail-open. Detection catches most;
  audit catches rest.
- **Partial edits**: Validate required fields only. plannedFix and linked
  are optional.
- **Hook timeout**: 30s explicit. known-gaps.json is small; agent reads
  and checks fields in <10s.
- **Scratch collisions**: SubagentStart hook injects unique prefix per
  session+agent type. Eliminates concurrent write conflicts.
- **Closed gaps**: Move to `closed` array with version and date.
  Lightweight history preserved in JSON.
- **TODO(gap) markers**: Deferred filing pressure valve. /audit scans
  for unfiled markers across the codebase.

## Relationship to Existing Infrastructure

- **Skills extend tool-registry.md**: Registry = install/version/lifecycle
  (static). Skill = usage patterns/gotchas (dynamic). No duplication.
- **Hooks extend standing-order-guard.sh**: Guard blocks bad patterns.
  Skills show good patterns. Stderr messages bridge the two.
- **`/gap` respects sources-of-truth gate**: known-gaps.json is protected.
  Skill presents entry for review before writing.
- **`/pre-update` command**: Existing command may migrate to skill format.
  Both coexist — commands are legacy, skills are the new path.
- **SubagentStart consolidation**: The governance SubagentStart hook and
  the planned "Subagent context hook & CLAUDE.md trim" roadmap item serve
  the same purpose. Combine into one hook.
- **RFC-0002 portability**: Governance patterns should be repo-agnostic
  where possible. nobul-ops can adopt the same three-layer model.
- **Claude Code maintenance workarounds**: Feed into `/claude` and
  `/nested-claude` skills. Maintenance file remains the tracker; skills
  provide runtime guidance.

## Implementation Notes

No priority ordering. Dependency-aware sequencing only:

1. **Rules and CLAUDE.md** (this batch) — foundation everything builds on
2. **`/gap` and `/audit` skills** — governance filing and review
3. **SubagentStart hook** — context injection for all subagents (combine
   with existing CLAUDE.md injection roadmap item)
4. **Tool skills** — all 15 managed tools
5. **Dependency skills** — `/git`, `/node`, `/bash-skill`
6. **Build tool skills** — `/nasm`, `/cmake`, `/msvc`
7. **Process skills** — remaining 6 (`/tool-eval`, `/scratch`,
   `/nested-claude`, `/cross-platform`, `/dotprofile`, `/mcp-skill`)
8. **PreToolUse hooks** — known-gaps.json validator, protected file reminder
9. **Standing order guard updates** — stderr → skill references
10. **Permission updates** — .scratch pre-approvals in settings.json

Steps 2-10 can be done in any order within each step. Between steps,
verify the previous step works before proceeding.

## Verification

After each implementation step:
- Invoke the skill manually with realistic input
- Verify hook fail-open behavior (kill the hook process mid-run)
- Check that SubagentStart injection appears in subagent context
- Run /audit to verify it detects known test cases
- Smoke-test per hook-rollout.md patterns
