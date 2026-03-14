# Governance and Compliance Framework

Implementation plan for the three-layer governance and compliance system.
Produced from design session 2026-03-13, refined same day.
Reference: CLAUDE.md Design Principles.

## Foundational Decisions

Resolved during the design session. Captured here as the authoritative
record — these are not open questions.

1. **End users are developers.** No "dumb user" persona exists. Every
   aitools user benefits from understanding internals.
2. **JSON format for known-gaps.** Not markdown (fragile Edit tool parsing),
   not SQLite (binary blob in git). JSON is structured, git-diff friendly,
   Claude manipulates reliably.
3. **Separate tool harnesses.** Claude Code and Cursor managed independently.
   No parity requirement.
4. **Fail-open for governance hooks.** Detection catches most; audit catches
   rest. Blocking on hook failure would be worse than missing a validation.
5. **Accept-and-audit for concurrency.** Duplicate gap IDs from races are
   rare. `/audit` detects and flags. No file locking.
6. **Subagents are sensors, main agent files.** Subagents report `AMBIGUITY:`
   findings. Main agent triages and invokes `/gap`.
7. **Skill priority: user > project.** Claude Code loads user-level skills
   over project-level when names collide. Never use the same name at both
   levels.
8. **Include-by-default, exclude selectively** for SubagentStart injection.
   Pre-build the full payload at deploy time; exclude to stay under 10%
   of subagent context (100k tokens at 1M window).
9. **invoke_ai is about managed content sync**, not generic AI invocation.
   Skills named for what they teach: `/managed-files` (deployment state
   machine) and `/ai-merge` (AI-assisted conflict resolution).
10. **Resolved ambiguities belong in this plan file** (Decisions section).
    Open gaps belong in `known-gaps.json`. Don't mix them.
11. **Formal eval files per skill.** Each skill gets a `tests/` directory
    with test prompts and expected behaviors. Higher expected value than
    spot-checking; easier to course-correct from (baseline exists).
12. **Incident tracking is project-level** (aitools effectiveness tracker).
    Cross-user aggregation is a future roadmap item — schema must not
    paint us into a corner.
13. **Local SQLite + Datadog for KPIs.** Hooks write to local
    `~/.aitools/telemetry/governance.db` (SQLite, WAL mode). SessionEnd
    ships aggregated KPIs to Datadog via `log_ship`. Local is source of
    truth; Datadog is visualization and alerting.
14. **User as co-architect during planning.** Present options not
    conclusions. Flag uncertainty explicitly. The user has domain
    knowledge no amount of codebase exploration replaces.
15. **Users may be single or multi-platform.** aitools supports all
    combinations (1, 2, or 3 platforms). User-level skills document all
    platforms factually — users consume what's relevant to them. aitools
    the PROJECT enforces cross-platform parity (PSOs). `/optimize-plan`
    does not assume cross-platform — it checks contextually based on
    what the plan touches.

## Three-Layer Architecture

| Layer | Mechanism | When | Catches |
|-------|-----------|------|---------|
| Prevention | Rules in context, skills loaded dynamically | Every session | Stops issues from being created |
| Detection | Hooks firing in real-time | During tool calls, session events | Issues as they happen |
| Audit | `/audit` skill, `/gap` skill | On demand | What slipped through |

Skills bridge prevention and detection: they show the right way (prevention)
so hooks don't need to block the wrong way (detection). Hook stderr messages
reference skills to close the remediation loop.

## Skill Architecture

### Placement framework

**User-level** (`shared/skills/` → deployed to `~/.claude/skills/`):
- About a globally managed tool installed on the machine
- Patterns are project-agnostic (factual: gotchas, platform behavior)
- Referenced by User Standing Orders (USOs)
- Injected into subagents via pre-built cache

**Project-level** (`.claude/skills/` in repo, auto-discovered):
- About this project's specific conventions, frameworks, or files
- Patterns would be wrong or misleading in another project
- References project-specific artifacts (known-gaps.json, build-deploy.sh)

**Split threshold**: A tool needs both levels only when it serves two
distinct personas (end user vs developer of the tool itself). Use
`<name>` for user-level and `<name>-dev` for project-level.

**No same-name overrides**: User-level takes priority. Never create a
project-level skill with the same name as a user-level one.

### Naming conventions

- Tool skills use the tool's CLI command name (e.g., `/perl`, `/cargo`)
- Three exceptions to avoid conflicts or ambiguity:
  - `/mcp-skill` — `/mcp` is a built-in Claude Code command
  - `/bash-skill` — `Bash` is a Claude Code tool name
  - `/go-lang` — `/go` is ambiguous as an English word
- Process skills use descriptive names (`/gap`, `/audit`, etc.)
- Project-level counterparts to user-level skills use `aitools-` prefix
  (`/aitools-dev` for `/aitools`, `/aitools-planning` for `/planning`)
- Project-level skills without a user-level counterpart use descriptive
  names (`/gap`, `/audit`, `/logging`)

### Skill template

Every tool skill follows this structure:

```yaml
---
name: <tool-name>
description: "<tool> usage patterns, platform gotchas, and conventions.
  Use when working with <tool>."
# Optional:
# inject: false          # Exclude from SubagentStart pre-built cache
# disable-model-invocation: true  # User-invocable only, zero context cost
---

## Patterns
Common invocation patterns.

## Platform Gotchas
Per-platform issues — every skill covers all managed platforms.

## Anti-Patterns
What the standing-order-guard hook blocks and why.

## Cross-References
- Tool registry: `reference/tool-registry.md`
- Setup script: `scripts/setup-<tool>.sh/.ps1`
```

Process skills follow a task-oriented structure (steps, decision trees,
validation).

### Skill eval convention

Every skill directory includes a `tests/` folder:

```
shared/skills/perl/
├── SKILL.md
└── tests/
    ├── test-sed-replacement.md    # Prompt that should trigger skill
    ├── test-no-trigger.md         # Prompt that should NOT trigger skill
    └── expected-behaviors.md      # What correct output looks like
```

- Auto-triggering skills: test both trigger and non-trigger prompts
- `disable-model-invocation: true` skills: manual invocation tests only
- `/audit` scope includes: "does this skill have test cases?"
- Run evals in fresh sessions (no context bleed from prior conversation)

### User-level skills (32)

#### Managed tool skills (15)

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

#### Dependency skills (3)

| Skill | Tool | Key content |
|-------|------|-------------|
| `/git` | Git | Project conventions, checklist integration, commit-message-via-file, branch naming, identity setup, pre/post reference file loading |
| `/node` | Node.js/npm | Package management, global installs, npm vs npx policy (never use npx), version management |
| `/bash-skill` | Bash | Cross-platform environments (Git Bash MINGW vs macOS 3.2 vs Linux GNU), pipeline patterns, quoting, PATH differences, BSD vs GNU userland |

#### Build tool skills (3)

| Skill | Tool | Key content |
|-------|------|-------------|
| `/nasm` | NASM | Install verification, path detection, required-by list, WinGet vs brew |
| `/cmake` | CMake | Install methods per platform, version requirements, path detection |
| `/msvc` | MSVC Build Tools | Visual Studio components, elevation requirements, detection patterns |

#### Cross-cutting skills (11)

| Skill | Purpose | Key content |
|-------|---------|-------------|
| `/aitools` | CLI usage | Subcommands, flags, env vars (AITOOLS_FORCE, DRY_RUN, RUN_ID), deploy menus, troubleshooting |
| `/managed-files` | Deployment system | State machine, menu options (overwrite/adopt/merge/skip), deploy state tracking, what happens to customizations |
| `/ai-merge` | AI-assisted conflict resolution | How merge prompt works (RCFT), 5-check validation, refinement loop, debugging from deploy.log, speed tiers, clip2md naming |
| `/scratch` | Temp file conventions | Naming (session+agent prefix), cleanup, when to use, permission pre-approvals |
| `/nested-claude` | Nested session workarounds | CLAUDECODE env var, `claude mcp add` failure, `--addmcp` alternative, safe/unsafe operations |
| `/cross-platform` | Platform dispatch | OS detection, path conventions, dispatch patterns, equal visibility |
| `/error-handling` | Error suppression patterns | Canonical bash/PS1 patterns: suppression-with-check, null guards, external command capture, exit footers |
| `/mcp-skill` | MCP server config | Enable/disable patterns, Claude vs Cursor asymmetry, isolation mode, auth, `--addmcp` |
| `/planning` | Session and plan strategy | Context budgets (1M=100k injectable, 200k=20k), session flow (60-70% stop), subagent coordination and parallelization, when to create plans vs work directly, model-dependent context windows (Opus 1M, Sonnet 200k, Haiku 100k), batch sizing (2-3 files), what works vs fails from session history, user as co-architect |
| `/incident-response` | Incident lifecycle | Detection → triage → investigation (5 Whys, Swiss cheese model, timeline, barrier analysis) → remediation → corrective action (behavioral vs structural) → verification → dissemination → follow-up. Recurrence = wrong fix, not wrong person. |
| `/optimize-plan` | Living plan review | Reads plan file + known-gaps.json + recent git log + referenced rules + ROADMAP.md. Outputs: stale sections, dependency graph, leverage map (what unblocks most downstream work), scope assessment (still coherent or split?), missing decisions. Invoke periodically after major batches, not one-shot. |

### Project-level skills (8)

Located in `.claude/skills/` within the aitools repo.

| Skill | Purpose | Key content |
|-------|---------|-------------|
| `/gap` | File gaps/ambiguities | Reads known-gaps.json, classifies, formats, writes. Model-invocable. |
| `/audit` | Deep governance review | Rules/refs consistency, cross-ref breaks, staleness, skill budget, TODO(gap) markers. User-invocable only. |
| `/tool-eval` | Tool evaluation/onboarding | 5 lifecycle phases, chrome-devtools verification, Phase 2 gate, onboarding checklist |
| `/dotprofile` | User repo management | profile.json fields, template tokens, template resolution, session archiving |
| `/logging` | Structured logging framework | All 7 log functions, levels, when to use each, JSONL dual-output, deploy tracker, counter contract, write_summary |
| `/build-deploy` | Build pipeline | Sentinel extraction, lib inlining, profile interpolation, CRLF handling, standalone blog logging |
| `/aitools-dev` | aitools development | Entry point dispatch, how to add tools/deployment types, return value contracts, validation callbacks |
| `/aitools-planning` | aitools plan standards | Foundational decisions pattern, verbatim code requirement, platform annotations (Windows PS1 / macOS bash), batch verification checklist, cross-reference audit, test plan with expected counts |

Total: **40 skills** (32 user-level + 8 project-level).

## Skill Deployment

### User-level deployment

`setup-user-mcp.sh/.ps1` deploys user-level skills from `shared/skills/`
to `~/.claude/skills/` (and `~/.cursor/skills/` — see gap #12 for Cursor
verification status). After deploying all skills, builds the SubagentStart
pre-built cache (see below).

### SubagentStart pre-built cache

At deploy time (not hook runtime), concatenate all injectable skill
content into a single file:

**Build step** (in `setup-user-mcp.sh/.ps1`, after skill deployment):
1. Read all `~/.claude/skills/*/SKILL.md` files
2. Read all `.claude/skills/*/SKILL.md` files (project-level, if in aitools)
3. Exclude skills with `inject: false` in frontmatter
4. If total exceeds 10% of context budget (100k tokens ≈ 400k chars):
   exclude `disable-model-invocation: true` skills first, then
   largest-first until under budget. Log what was excluded.
5. Concatenate remaining skill content + governance context + scratch
   namespace into `~/.aitools/hooks/subagent-context.json`

**Format:**
```json
{
  "hookSpecificOutput": {
    "additionalContext": "<all skill content + governance>"
  }
}
```

**SubagentStart hook** (`shared/hooks/subagent-context.sh`):
```bash
#!/usr/bin/env bash
cat ~/.aitools/hooks/subagent-context.json
```

Two lines. One syscall. ~20ms macOS, ~155ms Windows (bash startup
overhead unavoidable for command hooks).

**Rebuild triggers**: `aitools install`, `aitools` (sync), skill
file changes during deploy.

### Exclusion criteria

When total injectable content exceeds 10% budget:

1. Skills with `inject: false` frontmatter (explicit author opt-out)
2. Skills with `disable-model-invocation: true` (already hidden from
   auto-discovery; loaded on demand only)
3. Largest skills first (a 50k char skill consuming 5% alone should be
   on-demand, not bulk-injected)

`/audit` skill scope includes skill budget analysis: total size, headroom,
skills approaching threshold, recommendations for splitting large skills.

## Hook Specifications

### SubagentStart context injector (command type)

Pre-built cache served via single `cat` command. Contains:
- All injectable skill content (user-level + project-level)
- Governance duty: `AMBIGUITY:` prefix convention
- Scratch namespace: `.scratch/{session_id}_{agent_type}_` prefix
- Key project rules (if in aitools repo)

Subagents receive the full skill library. No smart routing per agent
type — inclusive by default, exclude selectively at build time.

This hook subsumes the planned "Subagent context hook & CLAUDE.md trim"
roadmap item. Combine into one hook.

### PreToolUse agent hook on known-gaps.json (agent type)

- Event: PreToolUse, matcher: Edit|Write on `reference/known-gaps.json`
- Validates: required fields, valid enums, sequential IDs, well-formed JSON
- **Fail-open**: on timeout or error, allow the edit. /audit catches later.
- Timeout: 30 seconds

### PreToolUse prompt hook on protected files (prompt type)

- Event: PreToolUse, matcher: Edit|Write on sources-of-truth files
- Injects reminder: "Protected file — verify cross-references and
  downstream dependencies"
- Does not block, context injection only

### PreToolUse prompt hook for error suppression (prompt type)

- Event: PreToolUse, matcher: Edit|Write
- Scans content for: `2>/dev/null`, `SilentlyContinue`, `|| true`,
  empty `catch {}` without result checks within 3 lines
- Warns (does not block): "Error suppression detected without result
  check. See `/error-handling` skill."
- Addresses recurring incidents I5, I7, I11, I17

### PreToolUse prompt hook for git workflow (prompt type)

- Event: PreToolUse, matcher: Bash matching `git commit|git push`
- Checks: were check-pre-commit or check-pre-push scripts invoked
  earlier in this session?
- Warns if not: "Pre-commit checklist not run. Execute check scripts
  first per PSO."
- Addresses incident I12

### Stop prompt hook for ambiguity check (prompt type)

- Event: Stop (fires on every Claude response)
- Lightweight check: "Did this response touch rules or references?
  Were any ambiguities surfaced or filed?"
- Context injection only, does not block

### Standing order guard updates (update existing)

Update stderr messages to reference skills when blocking:
- `sed` blocked → "Use Perl for string manipulation. Load /perl."
- 5+ line inline → "Write to .scratch/ file. Load /scratch."
- `&&` blocked → "Use separate Bash tool calls."
- Standalone `grep` → "Use the Grep tool."

Closed loop: hook blocks → stderr references skill → agent loads
skill → correct pattern used.

## Telemetry and KPIs

### Local storage

SQLite database at `~/.aitools/telemetry/governance.db` (WAL mode for
concurrent async hooks):

```sql
-- Raw events from hooks
CREATE TABLE events (
  timestamp TEXT, session_id TEXT, event_type TEXT,
  tool_name TEXT, skill_name TEXT, hook_name TEXT,
  outcome TEXT, details TEXT
);
-- Session summaries (populated by SessionEnd hook)
CREATE TABLE sessions (
  session_id TEXT PRIMARY KEY, start TEXT, end TEXT,
  project TEXT, model TEXT, context_window INT,
  skills_loaded INT, tools_used INT, gaps_filed INT
);
-- Daily aggregated KPIs (populated by SessionEnd hook)
CREATE TABLE kpis (
  date TEXT, metric TEXT, value REAL
);
```

### Telemetry hooks

| Hook | Event | Async | What it captures |
|------|-------|-------|-----------------|
| telemetry-init | SessionStart | no | Create session row, capture model/context window |
| telemetry-instructions | InstructionsLoaded | yes | Skill/rule load events |
| telemetry-tool | PostToolUse | yes | Tool usage, hook fire/block events |
| telemetry-summary | SessionEnd | no | Aggregate session KPIs, ship to Datadog via `log_ship` |

All telemetry hooks are async except SessionStart (needs to init before
other hooks fire) and SessionEnd (must complete before session closes).

### KPI definitions

| KPI | Metric | Source |
|-----|--------|--------|
| Hook fire rate | Events per session by hook | events table |
| Hook block rate | Blocked / total by hook | events table |
| Skill load frequency | Loads per session by skill | events table |
| Skill coverage | Skills with SKILL.md / total managed tools | filesystem |
| Eval coverage | Skills with tests/ / total skills | filesystem |
| Gap closure velocity | Closed gaps / open gaps over time | known-gaps.json |
| Incident recurrence | Same root cause repeat count | effectiveness tracker |
| Corrective action hold rate | Non-recurring / total incidents | effectiveness tracker |

### Datadog integration

Telemetry ships to Datadog via the `log_ship` helper from the Datadog
roadmap item (`plans/datadog-log-integration.md`). The SessionEnd hook
calls `log_ship` with aggregated KPIs. Local SQLite is source of truth;
Datadog provides dashboards, alerting, and cross-machine aggregation.

Future: cross-user aggregation when aitools.nobul.tech ships (roadmap
item). Schema designed to support per-user metrics without code changes.

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

### Hook-based permission decisions

PreToolUse hooks can return `permissionDecision: "allow"` for patterns
too complex for glob rules. Implement only if permission prompts become
recurring friction.

## Edge Cases

- **Concurrency (gap IDs)**: Accept-and-audit. /audit detects duplicates.
- **Fail-open**: All governance hooks fail-open.
- **Partial edits**: Validate required fields only.
- **Hook timeout**: 30s explicit for agent hooks.
- **Scratch collisions**: SubagentStart injects unique prefix.
- **Closed gaps**: Move to `closed` array with version and date.
- **TODO(gap) markers**: /audit scans for unfiled markers.
- **Skill priority conflict**: Never use same name at user and project
  level. User-level always wins.
- **Subagent skill gap**: SubagentStart pre-built cache injects all
  skill content. Subagents don't inherit skills otherwise.
- **SubagentStart overhead**: Pre-built cache = one file read (~5ms
  incremental). Bash startup (~150ms Windows) is baseline for all hooks.

## Relationship to Existing Infrastructure

- **Skills extend tool-registry.md**: Registry = install/version/lifecycle
  (static). Skill = usage patterns/gotchas (dynamic). No duplication.
- **Hooks extend standing-order-guard.sh**: Guard blocks bad patterns.
  Skills show good patterns. Stderr messages bridge the two.
- **`/gap` respects sources-of-truth gate**: known-gaps.json is protected.
- **`/pre-update` command**: May migrate to skill format.
- **SubagentStart consolidation**: Combines governance injection with
  the planned CLAUDE.md injection roadmap item.
- **Claude Code maintenance workarounds**: Feed into `/claude` and
  `/nested-claude` skills.

## Implementation Notes

Dependency-aware sequencing:

1. **Rules and CLAUDE.md** (v0.54 — done)
2. **Plan corrections** (v0.54.1 — done)
3. **`/gap` and `/audit` skills** — governance filing and review
4. **SubagentStart hook** — pre-built cache + context injection
5. **Telemetry hooks + SQLite** — local KPI collection infrastructure
6. **User-level tool skills** — all 32
7. **Project-level skills** — all 8
8. **PreToolUse hooks** — known-gaps validator, protected file reminder,
   error suppression, git checklist
9. **Standing order guard updates** — stderr → skill references
10. **Stop hook** — ambiguity check
11. **Permission updates** — .scratch pre-approvals

### Session working convention

Each session picks up this plan, works through the next steps, and
stops at **60-70% context usage** to leave room for commit/push workflow,
late-session course corrections, and gap filing. Check `/context`
periodically.

**Session flow:**
1. Read this plan + known-gaps.json + relevant rules
2. Work through implementation steps in order
3. Surface ambiguities as they arise (surfacing duty)
4. At 60-70% context: stop building, file any new gaps, update release
   notes, commit, tag, push both repos
5. If more work remains, note where to resume in the commit message

Steps 1-2 marked "done" can be skipped. Resume from the first
incomplete step.

## Verification

After each implementation step:
- Invoke the skill manually with realistic input
- Verify hook fail-open behavior
- Check SubagentStart injection appears in subagent context
- Run /audit to verify detection of known test cases
- Smoke-test per hook-rollout.md patterns
- Check `/context` for skill budget impact

## Open Questions

Tracked as gaps in `known-gaps.json`. Key unresolved items:
- Gap #12: Cursor skill deployment mechanism unverified
- Gap #13: Skill priority correction (planned, linked to v0.54.1)
- Gap #14: Subagent skill preloading via `skills:` field vs hook injection
- Gap #15: setup-user-mcp scaling from 2 to 33+ user-level skills
- Gap #16: Meta-skill for ambiguity detection
