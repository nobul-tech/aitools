# Rule Effectiveness Audit — 2026-03-17

## Summary

23 project rules. 7 have hook enforcement (detection layer), 6 have
check-script coverage (audit layer), **15 are prevention-only** (honor
system — they work only because agents read them in context).

## Three-Layer Coverage Map

| Rule | Prevention | Detection | Audit |
|------|-----------|-----------|-------|
| agentic-standards.md | always | — | — |
| aitools-workspace.md | always | — | — |
| artifact-harvesting.md | always | harvest-session.sh | — |
| config-file-safety.md | always | — | — |
| cross-platform.md | always | sh-file-fixup.sh | check-script-compliance |
| deploy-paths.md | always | — | — |
| documentation-standards.md | always | — | — |
| frameworks.md | always | — | — |
| git-safety.md | always | — | — |
| glossary.md | always | glossary-skill-guard.sh | check-pre-commit |
| governed-data-access.md | always | glossary-skill-guard.sh (partial) | check-pre-commit |
| hook-rollout.md | always | — | — |
| incident-governance.md | always | surfacing-duty-stop.sh | — |
| interactive-menus.md | always | — | — |
| managed-file-deployment.md | always | — | — |
| plan-execution.md | always | — | — |
| script-standards.md | always | standing-order-guard.sh (partial) | check-script-compliance, check-pre-commit |
| smoke-test-pattern.md | always | — | — |
| sources-of-truth.md | always | — | — |
| tool-evaluation.md | always | — | check-post-push |
| tool-lifecycle.md | always | — | — |
| tool-ops.md | always | block-guide + tool-ops-audit | check-post-push |
| web-sources.md | always | — | — |

## Hook Functional Test Results

### block-claude-code-guide.sh — 5/5 PASS
- Denies claude-code-guide subagent (JSON deny response)
- Allows Explore subagent (silent)
- Allows general-purpose subagent (silent)
- Handles missing subagent_type gracefully
- Handles malformed JSON gracefully

### glossary-skill-guard.sh — 3/3 PASS
- Injects context on glossary.json Read (stderr)
- Injects context on glossary.json Grep (stderr)
- Silent on non-glossary files

### standing-order-guard.sh — 3 enforced, 3+ observe
- ENFORCED: $() command substitution → exit 2, blocks
- ENFORCED: && chaining → exit 2, blocks
- ENFORCED: scratch files (5+ lines) → exit 2, blocks
- OBSERVE: ; chaining → logged, not blocked (perl/pwsh exempt)
- OBSERVE: || chaining → logged, not blocked
- OBSERVE: backticks → logged, not blocked
- OBSERVE: dedicated tools (cat/grep/find/sed/head/tail) → logged
- OBSERVE: glob in rm → logged, not blocked
- Observe log: **1003 entries** — actively collecting data

### sh-file-fixup.sh — 2/2 PASS
- Processes .sh file writes (exit 0)
- Silent on non-shell files

### scratch-init.sh — 1/1 PASS
- Creates session scratch directory with unique ID

### All 9 hooks — syntax validation PASS (bash -n)

## Findings

### F1: Governed data access — single-registry guard
glossary-skill-guard.sh only guards `glossary.json`. Five other governed
registries have **no detection layer**:
- reference/framework-registry.json
- reference/incidents.json
- reference/tool-ops.json
- reference/tool-registry.json
- harvesting/harvest-manifest.json

Agents bypass the skill gate by reading these files directly. This was
observed in this session (tool-ops.json read directly per /tool-ops skill
instruction).

### F2: hookSpecificOutput channel inconsistency
Two hooks produce `hookSpecificOutput` JSON on different channels:
- `block-claude-code-guide.sh` → **stdout** (permissionDecision=deny)
- `glossary-skill-guard.sh` → **stderr** (additionalContext)

May be intentional (deny needs stdout for CC parsing; context injection
uses stderr for model feedback). Needs verification against Claude Code
hook documentation.

### F3: Observe-mode data ready for promotion review
1003 observe-mode log entries. Most frequent violations:
- Dedicated tools: subagents using grep/find/head directly
- Semicolons: common in testing commands (`;echo EXIT:$?`)
- These would benefit from a /tool-ops analysis to decide which to promote

### F4: Git checklist PSO — no enforcement
PSO: "Use check scripts, not ad-hoc" has no hook or check-script coverage.
Git commands exit early via the allowlist (line 132). No reminder to run
check-pre-commit, check-pre-push, etc.

### F5: 15 prevention-only rules
These rules rely entirely on the agent reading and following them:
- agentic-standards, aitools-workspace, config-file-safety, deploy-paths,
  documentation-standards, frameworks, git-safety, hook-rollout,
  interactive-menus, managed-file-deployment, plan-execution,
  smoke-test-pattern, sources-of-truth, tool-lifecycle, web-sources

High-value candidates for detection-layer hooks:
- **sources-of-truth.md**: Protected file gate — a hook could remind on
  Write/Edit of protected files
- **config-file-safety.md**: A hook could guard config file writes
- **frameworks.md**: A hook could remind to check /frameworks before adding

### F6: Cross-reference integrity — clean
All 140+ cross-references across 23 rules resolve correctly.
2 false positives in documentation-standards.md (example `@path/file.md`
in explanatory text).

### F7: Source-deployed parity — clean
- 9/9 hooks match source (shared/hooks/ = ~/.claude/hooks/)
- 8/8 user skills match source × 2 targets (Claude + Cursor)
- 9/9 project skills present
- Settings structure, deny rules, preferences all correct
