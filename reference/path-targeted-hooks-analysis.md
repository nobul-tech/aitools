# Path-Targeted Hook Analysis

Produced during governance design session 2026-03-13. Subagent audit of
all files where PreToolUse hooks targeting specific paths would prevent
mistakes, enforce conventions, or eliminate ambiguity.

## 9 Generalizable Patterns

### 1. Protected Files Gate
Pattern: Edit|Write on sources-of-truth protected files
Type: prompt (context injection, no block)
Injects: file-specific reminder (cross-references, downstream deps)

### 2. Error Suppression Detection
Pattern: Edit|Write on scripts/**/*.sh, scripts/**/*.ps1, deploy/*, shared/hooks/*
Type: prompt
Scans for: 2>/dev/null, SilentlyContinue, || true, empty catch {}
Injects: "Error suppression without result check. See /error-handling."

### 3. Platform Dispatch Parity
Pattern: Write on scripts/setup-*.sh or scripts/setup-*.ps1
Type: prompt
Checks: counterpart exists? same logic? same block order?
Injects: "Dual-script rule. Block order reminder."

### 4. Dual-Language Audit
Pattern: Edit|Write on (scripts|deploy|shared)/**/*.sh or *.ps1
Type: prompt
Validates: log_error increments ERRORS, exit footer checks both counters
Injects: "Bash and PS1 logging must mirror."

### 5. Dual-Script Completeness
Pattern: Write on scripts/(setup-|aitools-install.|check-)*.sh or *.ps1
Type: prompt
Checks: pair exists? tool lifecycle phase? wired into aitools-install? build-deploy?
Injects: "Setup scripts need both .sh + .ps1. Verify all 5 integration points."

### 6. Skill Frontmatter Validation
Pattern: Write on (shared/skills|.claude/skills)/*/SKILL.md
Type: prompt
Validates: name, description present. Name unique across user+project. tests/ exists.
Injects: "Frontmatter required. No same-name overrides. Add tests/."

### 7. Deploy File Generation Warning
Pattern: Edit|Write on deploy/**
Type: prompt + BLOCK on Edit
Injects: "deploy/ is 100% generated. Edit scripts/ instead, rebuild."

### 8. Reference Cross-Reference Audit
Pattern: Edit|Write on reference/**/*.md, plans/**/*.md, .claude/rules/**/*.md
Type: prompt
Checks: @links resolve, section references exist, gap IDs in range
Injects: "Verify all @path/file links exist."

### 9. Script Exit Footer Completeness
Pattern: Edit|Write on scripts/**/*.sh, scripts/**/*.ps1 (except build-deploy.sh)
Type: prompt
Validates: exit footer present, checks both ERRORS and WARNINGS
Injects: "Exit footer must check both counters."

## 12 Specific File-Path Hooks

| File | What it prevents | What it injects |
|------|-----------------|-----------------|
| reference/tool-registry.md | Incomplete lifecycle fields | "6 required fields. Verify upstream via chrome-devtools." |
| reference/tool-versions.json | Stale versions | "Per-platform manifest. Audit when tool-registry changes." |
| reference/incidents.json | Invalid schema | Agent validation (separate, fail-open) |
| shared/skills/*/SKILL.md | Deployment path gap | "Won't be discoverable until deployed. Gap #15." |
| .claude/skills/*/SKILL.md | Name collision | "No same-name overrides with user-level." |
| scripts/setup-*.sh | Missing .ps1 pair | "Dual-script + block order." |
| scripts/setup-*.ps1 | Missing .sh pair | "Dual-script + block order." |
| scripts/aitools-install.sh | New tool not wired in | "Add validate_and_run for new setup script." |
| scripts/build-deploy.sh | Missing copy block | "New tools need 2 numbered blocks." |
| shared/shell/aliases.sh | Parity loss | "Update .ps1 too." |
| shared/hooks/*.sh | Undocumented hook | "Document trigger, matcher, action." |
| plans/*.md | Missing foundational decisions | "Plan structure: decisions → steps → verification." |

## Key Insight

All patterns reduce to one principle: when you write to a file, inject
reminders about what that file feeds into and depends on. Dependency-aware
context injection.

Implementation: reference/dependency-map.json read by hooks at runtime.
/audit validates the map for completeness.
