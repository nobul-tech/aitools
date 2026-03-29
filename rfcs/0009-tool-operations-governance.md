# RFC 0009: Tool Operations and Governance

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Informed by**: tool-ops.json, tool-ops-claude-code.md (300 lines), reference/framework-tool-ops.md, .claude/rules/tool-ops.md, .claude/rules/aitool-ops.md, .claude/rules/tool-evaluation.md, .claude/rules/tool-lifecycle.md, /tool-ops skill, /tool-eval skill, /tool-registry skill, /aitool-ops reference-card skill, /aitool-eval reference-card skill, tool-ops-session-audit.sh hook, RFCs 0001-0008
**Relationship**: Operational metadata for managed tools. Consumes 0004-v2 (harness components), 0005-v2 (session intelligence for KPIs), 0007 (cross-platform), 0008 (verification). Consumed by 0001 v2 (product surfaces tool health) and 0002 v2 (MC health indicators).

---

## 1. Summary

Tool operations is the SRE discipline applied to managed tools. Every tool with deep harness integration gets operational metadata: governance modes, deny rules, hooks, context injection, KPIs, and verification specs. The current implementation (tool-ops.json + tool-ops-claude-code.md) is severely stale (last updated 2026-03-15, 13 days behind actual state). The planned migration moves operational knowledge from the aitools repo to user-level aitool-ops, making it available in every repo.

This RFC defines the target architecture for tool operations: the three-tier skill taxonomy, the governance mode lifecycle, the per-tool ops reference pattern, and the migration path to aitool-ops.

## 2. The Three-Tier Skill Taxonomy

| Tier | Skill | Scope | Available where |
|------|-------|-------|-----------------|
| Project (full CRUD) | /tool-ops | Read and write tool-ops.json | aitools repo only |
| User (portable) | /aitool-ops | Read-only reference card | Any repo |
| Framework | — | reference/framework-tool-ops.md | aitools repo only |

In the aitools repo, /tool-ops is primary (full CRUD). /aitool-ops is redundant but available. In any other repo, /aitool-ops is the only available skill — it provides operational knowledge without needing the aitools source files.

This pattern (project skill + user reference-card skill) was established by /aitool-ops (first reference-card) and replicated by /aitool-eval (second). Future domains should follow the same pattern.

## 3. What tool-ops Tracks

### Per-tool operational metadata (tool-ops.json)

| Field | Purpose |
|-------|---------|
| governanceModes | audit vs active per category (denyRules, hooks, contextInjection, kpis, versionDeps, verifications) |
| denyRules | Permission patterns blocked and why |
| hooks | What hooks fire, events, matchers |
| contextInjection | Doc URLs injected into subagents |
| kpis | Operational metrics collected |
| versionDeps | CC version dependencies that would break if behavior changes |
| verifications | Mock-json-pipe test specs for hooks and deny rules |

### Current state

tool-ops.json documents 1 hook and 1 deny rule. Actual deployed state: 15 hooks, 3 deny rules. 13 days stale. This is the gap this RFC addresses.

### Governance modes

| Mode | Meaning | Telemetry |
|------|---------|-----------|
| audit | Observe and log, do not enforce | Log drift, count events |
| active | Enforce, block violations | Block + log + count |

All categories currently in audit. Promotion requires zero-drift telemetry evidence via tool-ops-session-audit.sh.

## 4. Per-Tool Ops Reference Pattern

Tools with deep harness integration get a dedicated reference file: reference/tool-ops-&lt;tool&gt;.md. Currently only Claude Code has one (tool-ops-claude-code.md, 300 lines).

### What a per-tool ops reference contains

| Section | Content |
|---------|---------|
| Version dependencies | Items that break if tool behavior changes (CRITICAL/HIGH/MEDIUM/LOW) |
| Session behavior | How the tool manages sessions, state, context |
| Platform workarounds | Known per-platform issues with solutions |
| Setup notes | Post-install requirements (auth, PATH, config) |
| Release notes watch | Notable upstream changes affecting the harness |

### Which tools warrant ops references

Any tool where:
- Harness scripts depend on specific behavior (Claude Code, git)
- Version changes could break hooks or deploy pipeline
- Platform-specific workarounds exist
- Setup requires authentication or configuration beyond install

Currently: Claude Code. Candidates: GitHub CLI (auth flow), Cursor Agent CLI (rule loading differences), Datadog CLI (auth + API key).

## 5. The Verification System

### Mock-json-pipe testing

Hook and deny rule verification uses mock JSON input piped to the hook script:

```bash
# Test: should deny claude-code-guide subagent
echo '{"tool_name":"Agent","tool_input":{"subagent_type":"claude-code-guide"}}' \
  | bash block-claude-code-guide.sh
# Expected: exit 0, stdout contains "permissionDecision.*deny"

# Test: should allow Explore subagent
echo '{"tool_name":"Agent","tool_input":{"subagent_type":"Explore"}}' \
  | bash block-claude-code-guide.sh
# Expected: exit 0, no stdout
```

### tool-ops-session-audit.sh

SessionEnd hook that:
1. Reads tool-ops.json for verification specs
2. Runs mock-json-pipe tests against deployed hooks
3. Checks drift (deny rules vs settings.json, hooks vs registered)
4. Logs results to tool-ops-audit.jsonl
5. Always exits 0 (advisory, never blocks session end)

Current coverage: 2 hooks tested (block-claude-code-guide: deny test + allow test). 13 hooks unverified. Gap identified in RFC 0008.

### Verification expansion target

Every deployed hook should have at least:
- One clean-input test (exit 0)
- One violation test (expected exit code + output)
- One edge case (platform-specific or exemption path)

## 6. Tool Evaluation Criteria

Full evaluation methodology in /tool-eval skill (project) and /aitool-eval reference-card (user).

### Ranked principles

1. Official endorsement
2. Verified provenance and security
3. Latest stable version
4. Cross-platform delivery
5. Same upstream distribution
6. Automation and deployment
7. Maintenance health
8. Build time

### Hard blocks (never recommend)

Unverified publisher, repo inactive 2+ years, security advisories, personal fork when official exists, typosquatting, excessive permissions.

### Health flags (per-platform)

Red (action required): deprecated, security advisory, install broken, unsupported version. Yellow (attention): version unverified >90 days, sole maintainer, active workaround, build from source. Green (healthy): latest stable, verified provenance, no workarounds.

### The Phase 2 gate

After install and test command, MUST wait for user approval before writing integration code. Do not plan Phase 3+ until Phase 2 approved. If rejected: uninstall, remove entry, stop.

## 7. The aitool-ops Migration

### What moves to user level

Operational knowledge that agents need in any repo: deny rules, hook behavior, CC version deps, doc access methods, governance modes, subagent limitations, session management commands, hook portability rules.

### What stays in aitools repo

Full CRUD operations on tool-ops.json, framework documentation, per-tool ops reference files, verification specs, governance mode promotion.

### The reference-card pattern

Content extracted from source files at authoring time (not generated at build time — future enhancement). Read-only, self-contained, staleness-aware. Deployed to ~/.claude/skills/ via setup-user-skills.sh.

### Current staleness

aitool-ops and aitool-eval are manually authored snapshots. When source files update, the reference cards must be manually refreshed. No automated check exists. Gap: add staleness check to check-post-push (compare source mtime to skill mtime).

## 8. Integration with Other RFCs

| RFC | Integration point |
|-----|------------------|
| 0001 v2 | Product surfaces tool health flags in MC |
| 0002 v2 | MC health indicators include tool version freshness |
| 0004-v2 | Managed tools are a harness component; tool-ops is their operational metadata |
| 0005-v2 | Tool version checks produce KPI events; friction from tool issues tracked |
| 0007 | Cross-platform health flags are per-platform; install methods are platform-specific |
| 0008 | Verification specs are the test suite; tool-ops-session-audit.sh is the runner |

## 9. Phase Plan

### Phase 0: Update stale registry (1 session)
- Update tool-ops.json to match actual deployed state (15 hooks, 3 deny rules)
- Add verification specs for all 15 hooks
- Update aitool-ops reference card
- **Exit**: tool-ops.json matches reality. Zero drift.

### Phase 1: Expand per-tool ops (1 session)
- Create tool-ops-gh-cli.md (auth flow, token management)
- Create tool-ops-cursor-cli.md (rule loading, MCP config)
- Add version dep tracking for tools beyond CC
- **Exit**: Every deeply-integrated tool has ops reference

### Phase 2: Automated staleness detection (1 session)
- Add reference-card staleness check to check-post-push
- Add tool-ops.json drift check to check-pre-commit
- Automate reference-card regeneration from source (build-deploy.sh enhancement)
- **Exit**: Stale ops knowledge detected automatically

### Phase 3: Governance mode promotion (1-2 sessions)
- Collect telemetry from tool-ops-session-audit.sh
- Identify categories with zero-drift evidence
- Promote from audit to active with commander approval
- **Exit**: At least one category promoted to active mode

## 10. Open Questions

1. **Reference-card auto-generation**: Should build-deploy.sh generate aitool-ops/aitool-eval content from source files? Reduces staleness risk. Increases build complexity.
2. **Tool-ops scope expansion**: Should tool-ops track MCP servers (chrome-devtools, vercel, webflow)? Currently not tracked. MCP servers have operational concerns (auth, concurrency, --isolated flag).
3. **Governance mode granularity**: Per-tool or per-category? Currently per-category (all tools share the same mode for denyRules, hooks, etc.). Per-tool would allow CC to be active while others remain audit.
4. **Tool retirement**: No lifecycle phase for removing a tool. What happens when a managed tool is deprecated upstream? Need a sunset phase.

## 11. References

### Registry and rules
- reference/tool-ops.json (operational metadata)
- reference/tool-ops-claude-code.md (CC ops reference, 300 lines)
- reference/framework-tool-ops.md (SRE discipline source)
- .claude/rules/tool-ops.md (governance principle + trigger)
- .claude/rules/aitool-ops.md (reference-card trigger)
- .claude/rules/tool-evaluation.md (evaluation principles)
- .claude/rules/tool-lifecycle.md (Phase 2 gate, onboarding checklist)

### Skills
- .claude/skills/tool-ops/SKILL.md (project, full CRUD)
- .claude/skills/tool-eval/SKILL.md (project, evaluation process)
- .claude/skills/tool-registry/SKILL.md (project, registry access)
- shared/skills/aitool-ops/SKILL.md (user, reference card)
- shared/skills/aitool-eval/SKILL.md (user, reference card)

### Verification
- shared/hooks/tool-ops-session-audit.sh (SessionEnd, advisory)
- RFC 0008 (verification pipeline, mock-json-pipe pattern)

### Related RFCs
- 0004-v2: Managed tools component
- 0005-v2: KPIs from tool verification
- 0007: Cross-platform install methods
- 0008: Verification pipeline (runs the tests this RFC defines)
