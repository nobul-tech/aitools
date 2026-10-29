# Reference

Implementation detail, specs and knowledge base behind the rules in `.claude/rules/`.
Governed registries (tools, incidents, frameworks, glossary, tool-ops) are reached
through their skills, not listed here.

## Harness and frameworks

| File | Topic |
|------|-------|
| `harness.md` | Harness definition: the components and how they relate |
| `rules.md` | Rules: what a rule governs, the rule / skill / reference / registry layering, scopes, deployment to user scope |
| `skills.md` | Skills: what a skill is, the layering, anatomy, scopes, deployment to user scope and its cost |
| `framework-adoption.md` | Discovery-to-continuation cycle (DTCC) and the cross-reference convention |
| `framework-artifact-harvesting.md` | Artifact harvesting: source discipline and adoption |
| `framework-governed-data-access.md` | Skill-gated access to governed registries |
| `framework-governed-vocabulary.md` | Governed vocabulary: composition convention, glossary maintenance |
| `framework-hook-rollout.md` | Observe-then-enforce hook rollout |
| `framework-incident-governance.md` | Incident tracking (defect management) |
| `framework-incident-investigation.md` | Root-cause analysis: 5 Whys, Swiss cheese, barrier analysis |
| `framework-intent-documentation.md` | Intent statements: purpose, scope, audience |
| `framework-managed-file-deployment.md` | Configuration management behind managed file deployment |
| `framework-provenance.md` | Provenance tracking: dependency chains, staleness, invalidation |
| `framework-source-of-truth.md` | Source-of-truth review gate (change management) |
| `framework-three-layer-governance.md` | Prevention / detection / audit layers and the registry convention |
| `framework-tool-lifecycle.md` | Tool lifecycle: phases, gates, health flags |
| `framework-tool-ops.md` | Tool operations: SRE-grounded per-tool ops metadata |
| `harness-db-schema.sql` | SQLite schema for the session and harness databases |
| `incident-020-process-discipline.md` | Incident #20 discovery context (process discipline) |

## Scripts and deployment

| File | Topic |
|------|-------|
| `script-standards-detail.md` | Script standards: patterns, summary rows, error handling, exemptions |
| `logging.md` | Logging standard: location, rotation, format |
| `cross-platform-detail.md` | Cross-platform background: OS guards, Windows gotchas, PERLIO |
| `managed-file-deployment.md` | Managed file deployment state machine, menus, return values |
| `user-repo.md` | Dotprofile repo pattern, profile/config schemas, session archive |
| `ait-shellintegration.md` | Shell integration and PATH ownership (managed login-profile block) |
| `plan-execution-detail.md` | Sub-agent execution pattern and error-handling audit checklist |
| `smoke-test-pattern-detail.md` | Running setup scripts as smoke tests (redirect-and-check) |
| `pre-commit-checklist.md` | Pre-commit checklist (`check-pre-commit`) |
| `pre-push-checklist.md` | Pre-push checklist (`check-pre-push`) |
| `post-push-checklist.md` | Post-push checklist (`check-post-push`) |
| `path-targeted-hooks-analysis.md` | 2026-03-13 analysis of path-targeted PreToolUse hooks |

## Tools and agents

| File | Topic |
|------|-------|
| `tool-registry.md` | DEPRECATED (T-Q7): use the `/tool-registry` skill (`registries/tool-registry.json`) |
| `tool-evaluation-criteria.md` | Tool evaluation framework and lifecycle phases |
| `tool-evaluation-playbook.md` | Install method discovery process |
| `tool-support-decision-tree.md` | The decision tree every tool setup script follows (design; implementation status at the top) |
| `tool-ops-claude-code.md` | Claude Code operations: version dependencies, session behavior, workarounds |
| `tool-ops-cursor.md` | Cursor operations: user rule files, loader behaviour, verification |
| `tool-ops-google-chrome.md` | Google Chrome for chrome-devtools-mcp, Claude Code web args (D-CHR1-3) |
| `evaluations/` | Dated install-method evaluation records (`/tool-eval`) |
| `cursor-practices.md` | Cursor rules system, MCP config, CLI, skills |
| `agentic-framework.md` | `invoke_ai` / `Invoke-AI`: speed and permission tiers, retries, telemetry |
| `agentic-prompt-patterns.md` | Prompt patterns for AI CLI calls in scripts |
| `claude-code-effectiveness.md` | Historical copy (2026-02/03) of the effectiveness tracker; the maintained one is the dotprofile `claude/effectiveness.md` |
| `do-what-feels-right.md` | The original failure-mode briefing, preserved verbatim |
