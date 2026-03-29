# RFC 0008: Verification and Quality Pipeline

**Status**: Final
**Date**: 2026-03-28
**Author**: Session Commander fbf7decb (with Commander Jose)
**Session**: fbf7decb-9284-466f-a6ec-50abcdca3d62
**Informed by**: 5 check script pairs (pre-commit/pre-push/post-push/script-compliance/prereq-detection, ~3500 lines total), check-lib.sh/.ps1, hook-rollout.md rule, smoke-test-pattern.md rule, CI pipeline (.github/workflows), build prerequisite framework (Check-BuildPrereqs/diagnose_build_failure in aitools-lib), deploy state tracking (manifest + shadows), tool-ops-session-audit.sh, RFCs 0001-0007
**Relationship**: Quality assurance layer. Verifies outputs of 0004-v2 (harness), 0005-v2 (session intelligence), 0006 (delegation), 0007 (cross-platform).

---

## 1. Summary

The verification pipeline is how the harness ensures its own quality. Five check script pairs (10 scripts) run at lifecycle boundaries — pre-commit, pre-push, post-push. A script compliance checker verifies setup scripts follow standards. A prereq detection checker verifies build prerequisite coverage. Hooks enforce standing orders in real-time. The observe-then-enforce cycle graduates hooks from logging to blocking. CI validates on 3 platforms.

This is the detection and audit layers of the three-layer governance model (RFC 0004-v2 section 3). Prevention is rules in context. Detection is hooks and check scripts. Audit is the /audit skill and manual review.

## 2. Check Script Architecture

### The five pairs

| Script pair | When | Steps | Mode |
|------------|------|-------|------|
| check-pre-commit.sh/.ps1 | Before every commit | 19 | --fix available |
| check-pre-push.sh/.ps1 | Before every push | 10 | Read-only |
| check-post-push.sh/.ps1 | After every push | 31 | Extensive mode |
| check-script-compliance.sh/.ps1 | On demand or via post-push step 23 | 12 | Read-only |
| check-prereq-detection.sh/.ps1 | On demand or via post-push | 10 | Read-only |

### Shared infrastructure

**check-lib.sh/.ps1**: Step formatters (PASS/FAIL/WARN/SKIP), counters, check logging (checks.log + checks.jsonl), config resolution, mtime helper. Sources aitools-lib.sh (provides platform detection, logging, read_config_key).

**init-logging.sh/.ps1**: Auto-detects caller name, initializes structured logging before OS guard.

**Bridge pattern**: check_log_init / CheckLogInit overrides aitools-lib logging vars so lib functions (log, ensure_tool_on_path) write to deploy.log alongside check output. The double-init (init-logging -> check_log_init) is safe.

### Step result semantics

| Result | Meaning | Counter |
|--------|---------|---------|
| PASS | Check passed | PASS_COUNT |
| FAIL | Check failed — blocks workflow | FAIL_COUNT |
| WARN | Advisory — doesn't block | WARN_COUNT |
| SKIP | Not applicable (no staged files, tool missing) | SKIP_COUNT |

Exit code: FAIL_COUNT > 0 = exit 1. All others = exit 0.

### Logging

Dual output: checks.log (human-readable, timestamped) + checks.jsonl (machine-readable, structured). Both in AITOOLS_LOG_DIR. Enables automated trend analysis when consumed by MC (RFC 0002 v2).

## 3. Pre-Commit Checks (19 steps)

| Step | Check | Fix mode |
|------|-------|----------|
| 1 | Git identity (Jose &lt;jose@nobul.tech&gt;) | — |
| 2 | Script syntax (.sh via bash -n, .ps1 via ParseFile) | — |
| 3 | Build freshness (scripts/ or shared/ changed -> rebuild) | --fix rebuilds + stages |
| 4 | Line endings (.sh files, no CRLF) | --fix converts |
| 5 | Platform note (remind to include tested: platform) | — |
| 6 | Executable bit (.sh files, 100755 in git index) | --fix sets +x |
| 7 | Install command consistency (verify against tool-registry) | — |
| 8 | Config merge safety (detect blind overwrite patterns) | — |
| 9 | Release notes (non-docs changes need RELEASE_NOTES.md) | — |
| 10 | Deploy drift (deploy/ matches rebuilt output) | — |
| 11 | User repo changes (uncommitted in dotprofile) | — |
| 12 | Template sync (shared/claude-shared.md changed -> update dotprofile) | — |
| 13 | Deploy template logic sync (setup-user-* without build-deploy.sh) | — |
| 14 | Build prerequisite framework (cargo install has prereq checks) | — |
| 15 | Deprecated summary terms (no "unchanged" in write_summary) | — |
| 16 | Capability bypass audit (no direct @reference/*.json in rules/CLAUDE.md) | — |
| 17 | Hook portability audit (no banned patterns in hooks) | — |
| 18 | Python syntax validation (.py via py_compile) | — |
| 19 | Harness DB schema file exists | — |

## 4. Pre-Push Checks (10 steps)

| Step | Check |
|------|-------|
| 1 | Pre-commit passed (reminder) |
| 2 | No scratch/sensitive files in push |
| 3 | Secret scan (password/token/key patterns in diff) |
| 4 | No WIP/fixup/squash commits |
| 5 | Release notes current |
| 6 | Roadmap reflects reality (reminder) |
| 7 | deploy/ matches source (scripts/shared changed -> deploy/ updated) |
| 8 | Commit count (>5 = warn) |
| 9 | Branch hygiene |
| 10 | User repo push (unpushed dotprofile commits) |

## 5. Post-Push Checks (31 steps)

The most comprehensive. Includes the always tier (1-5), extended tier (6-31), and nested checks (script-compliance, prereq-detection).

| Tier | Steps | Key checks |
|------|-------|-----------|
| Always | 1-5 | Push landed, deploy smoke-test, MCP integrity, CLI version, session archive readiness |
| Extended | 6-14 | Full syntax (all .sh + .ps1), deploy drift audit, source-of-truth consistency, protected files inventory, cross-platform pairing, CLAUDE.md limits, reference link audit, line ending audit |
| Extended | 15-22 | MCP config deploy, roadmap freshness, hook verification + schema validation, untracked file hygiene, config merge audit, CC version-dep review, tool version freshness, logging hygiene |
| Extended | 23-31 | Script standards compliance (nested), summary panel DETAIL support, CLI tools table sync, deploy scripts list sync, build prerequisites installed, deploy state integrity, deployment menu parity, return value coverage, deployment state machine sync |

### Hook schema validation (step 17b)

Catches type mismatches: prompt-type hooks need "prompt" field, command-type need "command" field. A wrong schema breaks ALL hooks on CC launch. Node-based JSON validation of ~/.claude/settings.json.

### Tool version freshness (step 21)

Python script reads tool-versions.json, runs each tool's version command, compares installed vs manifest. Platform-aware (uses platform key for version lookup). Handles tools that emit warnings before version line.

## 6. The Observe-Then-Enforce Cycle

All PreToolUse hooks go through graduated rollout per .claude/rules/hook-rollout.md:

### Phases

1. **Observe** (1+ week): `MODE="observe"`. Hook logs what it would block but exits 0.
2. **Review**: Audit log for false positives. Fix matching logic.
3. **Enforce**: `MODE="enforce"`. Hook blocks violations (exit 2).

### Per-check granularity

standing-order-guard.sh has per-check mode variables:

| Check | Variable | Current state |
|-------|----------|--------------|
| && | MODE_AND | enforce |
| $() | MODE_SUBSHELL | enforce |
| \|\| | MODE_OR | enforce |
| ; | MODE_SEMICOLON | enforce (pwsh/perl exempt) |
| backticks | MODE_BACKTICK | enforce |
| scratch files | MODE_SCRATCH | enforce |

### When to reset to observe

- After adding new rules or patterns
- After changing matching logic
- After CC version upgrades that may change tool input formats

### Pre-deploy verification

Before deploying any hook change:
1. Syntax check: `bash -n shared/hooks/<hook>.sh`
2. Smoke-test: clean input -> exit 0
3. Violation test: known-bad input -> expected exit code
4. `bash -n` alone is NOT sufficient for `set -euo pipefail` hooks — runtime test required (I12: stale $MODE reference crashed every call, bash -n passed)

## 7. Build Prerequisite Framework

Two-layer prevention + diagnosis for source builds (cargo install, pip install with C extensions):

### Layer 1: Preventive (Check-BuildPrereqs / check_build_prereqs)

Called BEFORE the build. Checks known prerequisites per ecosystem. Missing -> log_error + write_summary ERROR/ACTION, skip the build.

Bash: table-driven in check_build_prereqs() function. Entries: ecosystem, tool name, check command, known install paths, install instruction.

PowerShell: $script:BuildPrereqs hashtable with Check scriptblocks, KnownPaths arrays, Install strings.

### Layer 2: Diagnostic (Diagnose-BuildFailure / diagnose_build_failure)

Called AFTER build failure. Scans output for known signatures (NASM not found, linker not found, cmake not found, etc.). Surfaces specific remedy.

### KnownPaths rule

All hardcoded paths must be empirically verified (RFC 0007 section 6). Verified: date + version comment. Unverified: marked # UNVERIFIED.

## 8. Deploy State Tracking

Manifest + shadow copies detect whether the user has edited a deployed file since last deploy.

### How it works

1. On deploy: record content hash in manifest.json, write shadow copy
2. On next deploy: compare existing file hash to manifest hash
3. If match: user didn't edit -> auto-deploy silently (no prompt)
4. If mismatch: user edited -> interactive diff review (deploy_managed_file)

### Storage

- Manifest: ~/.aitools/deploy-state/manifest.json (file key -> {hash, deployedAt})
- Shadows: ~/.aitools/deploy-state/shadows/<key> (full content copy)

### Three-way merge

When user edited AND source changed, shadow serves as common ancestor for git merge-file (non-agentic 3-way merge). Clean merge -> auto-accept option. Conflicts -> manual choice or AI merge.

## 9. CI Pipeline

.github/workflows/check.yml: 3 runners (macOS-14, ubuntu-latest, windows-2022).

### What CI validates

- bash -n on all .sh files (scripts/, deploy/, shared/hooks/)
- pwsh ParseFile on all .ps1 files
- py_compile on all .py files
- build-deploy.sh runs without error
- deploy/ matches rebuilt output (no drift)
- Line endings correct (.sh = LF)
- Script pairing (.sh has .ps1 and vice versa)

### What CI does NOT validate

- Functional behavior (hooks don't run against mock input in CI)
- Cross-platform command divergences (caught by hook portability check, not CI)
- Tool version freshness (needs installed tools, not in CI)
- Deploy state integrity (needs ~/.aitools/, not in CI)

### CI gap: functional hook testing

RFC 0007 Phase 2 proposes running hooks with mock input on all 3 CI runners. This would catch platform-specific runtime failures that syntax checking misses.

## 10. The Smoke Test Pattern

From .claude/rules/smoke-test-pattern.md: when running setup scripts as functional tests from Claude Code:

1. Redirect output to log file — never parse inline
2. Check exit code
3. Read log only on failure

```bash
# macOS
bash scripts/setup-foo.sh > .scratch/smoke-foo.log 2>&1
echo "exit: $?"

# Windows
pwsh -File scripts/setup-foo.ps1 > .scratch/smoke-foo.log 2>&1
echo "exit: $?"
```

Platform dispatch: pwsh -File for .ps1 on Windows, bash for .sh on macOS.

## 11. Verification Gaps

| Gap | Current state | Impact |
|-----|--------------|--------|
| Schema sync | harness-db-schema.sql and harness-db.py SESSION_SCHEMA/HARNESS_SCHEMA not automatically validated for consistency | Schema drift between spec and runtime |
| Functional hook testing in CI | Only syntax checked | Platform-specific runtime failures undetected |
| KPI verification | tool-ops-session-audit.sh checks 2 hooks; 13 more unverified | Incomplete coverage |
| Skill deployment verification | No check that ~/.claude/skills/ matches shared/skills/ | Stale deployed skills |
| Protected file review automation | Source-of-truth gate is behavioral (agent presents for review) | Depends on agent compliance |
| Incident registry vs session DB | incidents.json and session DB deviations table both track incidents | Dual tracking, possible divergence |

## 12. Phase Plan

### Phase 0: Close verification gaps (1 session)
- Add schema sync check to check-pre-commit (compare .sql and .py schemas)
- Add skill deployment freshness to check-post-push
- Add all hooks to tool-ops-session-audit.sh verification
- **Exit**: Zero unverified hooks, schema always in sync

### Phase 1: Functional hook testing (1-2 sessions)
- Mock input test suite for all 15 hooks
- Run in CI on all 3 platforms
- Cover: clean input (exit 0), violation input (exit 2), edge cases
- **Exit**: Hook portability verified by CI on every push

### Phase 2: Continuous verification (1 session)
- Check script results -> session DB (RFC 0005-v2)
- Check trends in MC (RFC 0002 v2 governance health)
- Alert on regressions (new FAILs in checks that previously PASSed)
- **Exit**: Verification results visible in MC, regressions flagged

## 13. Open Questions

1. **Check frequency**: Post-push runs 31 steps including nested script-compliance (12 more steps). Total ~43 steps per push. Is this too heavy? Currently takes ~30-60 seconds.
2. **Automated fix expansion**: Pre-commit --fix handles line endings, exec bits, and build freshness. Should more steps have auto-fix? Risk: auto-fixing masks root causes.
3. **Check script self-testing**: check-script-compliance checks setup scripts, but who checks the check scripts? Currently manual review only.
4. **Verification KPIs**: Should check pass/fail rates be shipped to Datadog alongside session KPIs? Would enable "is code quality improving?" trends.

## 14. References

### Check scripts
- scripts/check-pre-commit.sh/.ps1 (19 steps)
- scripts/check-pre-push.sh/.ps1 (10 steps)
- scripts/check-post-push.sh/.ps1 (31 steps)
- scripts/check-script-compliance.sh/.ps1 (12 steps)
- scripts/check-prereq-detection.sh/.ps1 (10 steps)
- scripts/check-lib.sh/.ps1 (shared infrastructure)
- scripts/init-logging.sh/.ps1

### Rules
- .claude/rules/hook-rollout.md (observe-then-enforce)
- .claude/rules/smoke-test-pattern.md
- .claude/rules/script-standards.md (what check-script-compliance verifies)

### Hooks (verified by tool-ops-session-audit)
- tool-ops-session-audit.sh (SessionEnd, advisory)
- standing-order-guard.sh (PreToolUse, per-check enforcement state)

### Related RFCs
- 0004-v2: Three-layer governance (this RFC implements detection + audit layers)
- 0005-v2: Session intelligence (check results should feed session DB)
- 0007: Cross-platform (hook portability, CI, platform parity checks)
- 0009 (planned): Tool operations (tool-ops verification specs)
