# CI/CD Feasibility Assessment for aitools

**Date**: 2026-03-18
**Investigator**: S2 (Intelligence)
**Trigger**: check-post-push.sh broken on macOS for 16 days (bash 3.2 heredoc + BSD paste bugs) -- undetected because no automated testing exists

---

## 1. Current CI/CD State

**There is no CI/CD pipeline.** Zero automation.

- No `.github/` directory exists
- No `.github/workflows/` directory
- No GitHub Actions configuration
- No pre-commit hooks configured in `.git/hooks/`
- All check scripts are run manually: `bash scripts/check-pre-commit.sh`, etc.
- Cross-platform testing is informal -- commit messages contain `(tested: macOS)` or `(tested: Windows)` annotations
- The scripts already use `# shellcheck source=` directives (5 scripts), indicating shellcheck was considered but never automated

## 2. Inventory of Existing Check Scripts

| Script | Steps | External deps | CI-runnable? |
|--------|-------|---------------|-------------|
| `check-pre-commit.sh` | 16 | pwsh (optional, step 2 PS1 syntax), git | Mostly -- needs staged files context |
| `check-pre-push.sh` | 10 | git, node (optional) | Mostly -- needs origin/main comparison |
| `check-post-push.sh` | 31 | pwsh, node, python3, claude, cargo, perl | Partially -- many steps check local env state |
| `check-script-compliance.sh` | 13 | perl | YES -- pure static analysis |
| `check-prereq-detection.sh` | ~10 | cargo (optional) | Partially |

All have PS1 counterparts: `check-*.ps1`.

### What runs without any external tools (pure repo analysis)

These steps analyze only repo contents -- no installed tools, no user config, no deployed state:

**check-script-compliance.sh** (all 13 steps): Log format compliance, exit footer pattern, write_summary coverage, counter tracking, raw echo detection, grep pipefail safety, OS guard presence, logging init presence, cross-platform pairing, SilentlyContinue result checks, summary categories, auto-promotion.

**check-post-push.sh** (subset): Steps 2 (bash -n deploy scripts), 6 (full syntax .sh), 7 (deploy/ drift audit), 9 (source-of-truth consistency), 10 (protected files inventory), 11 (cross-platform pairing), 12 (CLAUDE.md limits), 13 (reference link audit), 14 (line ending audit), 22a (winget output filtering), 22b (cloud MCP in setup-user-mcp), 25 (CLI tools table sync), 26 (deploy scripts list sync), 29 (deployment menu parity), 30 (return value coverage), 31 (deployment state machine sync).

**check-pre-commit.sh** (subset, without git staging context): Steps 14 (build prereq framework), 15 (deprecated summary terms), 16 (capability bypass audit).

### What requires external tools or local state

| Dependency | Steps affected | Available in CI? |
|-----------|---------------|-----------------|
| `pwsh` | PS1 syntax validation (pre-commit 2, post-push 6) | Yes -- installable via `brew install powershell` on macOS runners |
| `node` | Hook schema validation (post-push 17b), deploy state (28) | Yes -- pre-installed on all GitHub runners |
| `python3` | Tool version freshness (post-push 21) | Yes -- pre-installed on all GitHub runners |
| `perl` | Various pattern extractions (post-push 25-31) | Yes -- pre-installed on macOS and Ubuntu runners |
| `claude` | CC version-dep review (post-push 20) | No -- commercial CLI, not available in CI |
| `cargo` | Build prereqs (post-push 27) | Installable, but heavy (rust toolchain) |
| `git` context | Staged files (pre-commit), unpushed commits (pre-push), push verification (post-push 1) | Available, but context differs from local |
| Local state | `~/.claude.json` (MCP), `~/.aitools/` (deploy state), `~/.claude/settings.json` (hooks) | Not available -- these check deployed config |

## 3. The Post-Push Bug: Would CI Have Caught It?

### Bug 1: Bash 3.2 process-substitution + heredoc (step 21)

**Would CI catch it?** YES -- if using `macos-latest` (currently macOS 15) or `macos-14`, which ship bash 3.2.57 (same as local macOS). The `< <(python3 - <<'PYEOF' ...)` construct would produce the same "ambiguous redirect" error. The step would fail or silently pass with `0 OK, 0 skipped` -- either way, CI would surface the stderr output.

However: `ubuntu-latest` would NOT catch it. Ubuntu ships bash 5.x where this construct works fine. This is exactly why macOS runners matter for this project.

### Bug 2: BSD `paste -sd,` (11 call sites in steps 27, 29, 30, 31)

**Would CI catch it?** YES on macOS runners (BSD paste), NO on Ubuntu runners (GNU paste). The BSD vs GNU paste behavior difference is the exact kind of cross-platform issue that matrix testing catches.

### Bug 3: Emergent `set -e` abort from paste failure

**Would CI catch it?** YES -- same as Bug 2. The `pipefail` propagation would abort the script with exit code 1, and CI would report the workflow as failed.

**Verdict**: A macOS CI runner running `bash scripts/check-post-push.sh` would have caught all three bugs on day one (2026-03-02 for Bug 1, 2026-03-12 for Bugs 2+3). The 16-day blind spot would not have existed.

## 4. Design Options

### Option A: Minimal -- shellcheck + syntax validation on every push

**What it does:**
- Run `shellcheck` on all `.sh` files (pre-installed on Ubuntu runners)
- Run `bash -n` on all `.sh` files
- Run `pwsh -NoProfile -Command '[Parser]::ParseFile(...)'` on all `.ps1` files

**Runner**: `ubuntu-latest` only (1x multiplier)

**Cost**: ~1-2 minutes Ubuntu = 1-2 minutes/push. Free plan has 2,000 min/month for private repos. At ~5 pushes/day, ~30-60 min/month. Negligible.

**What it catches**: Syntax errors in both languages, common shell pitfalls (SC2086 unquoted variables, SC2155 declare+assign, SC2059 printf format, etc.). Would NOT have caught the post-push bugs (those are runtime failures, not syntax errors).

**What it misses**: Runtime failures (heredoc+process-sub interaction), BSD vs GNU behavioral differences, all structural/governance checks.

**Complexity**: Low. Single workflow file, ~30 lines YAML.

### Option B: Structural checks -- check-script-compliance + static subset on every push

**What it does:**
- Everything in Option A
- Run `bash scripts/check-script-compliance.sh` (all 13 steps, pure repo analysis)
- Run a new CI-subset script that extracts the repo-only steps from check-post-push.sh (steps 2, 6, 7, 9-14, 22a-b, 25-26, 29-31)

**Runner**: `macos-latest` (10x multiplier) for bash 3.2 fidelity + `ubuntu-latest` for shellcheck

**Cost**: ~3-5 min macOS = 30-50 min equivalent/push. At 5 pushes/day = 150-250 min equivalent. With private repo on Free plan (2,000 min), this is 7.5-12.5% of quota. Manageable but worth monitoring.

**What it catches**: Everything in A, plus all structural/compliance violations (cross-platform pairing, OS guards, logging standards, deployment state machine sync, return value coverage, menu parity). Would also catch BSD-specific runtime issues because macOS runner uses bash 3.2.

**What it misses**: Steps requiring local deployed state (MCP config, session archive, deploy state), tool version freshness, external tool availability checks.

**Complexity**: Medium. Two-runner matrix, one new CI-subset script (~150 lines), ~60 lines YAML.

### Option C: Full matrix -- macOS + Windows runners, all check scripts

**What it does:**
- Everything in Options A and B
- macOS runner: run all `.sh` check scripts
- Windows runner: run all `.ps1` check scripts via `pwsh`
- Install `pwsh` on macOS runner for PS1 syntax validation
- Steps requiring missing tools (`claude`, local config) gracefully skip

**Runner**: `macos-latest` + `windows-latest`

**Cost**: macOS ~5 min (50 min equiv) + Windows ~5 min (10 min equiv) = 60 min equiv/push. At 5 pushes/day = 300 min equiv/day. **This would consume the Free plan quota in ~7 days.** Requires Pro plan ($4/month, 3,000 min) or limiting to PR-only triggers.

**What it catches**: Everything in B, plus PS1-specific issues, Windows-specific path handling, actual cross-platform behavioral differences.

**What it misses**: Steps requiring deployed local state, commercial tools (`claude`).

**Complexity**: High. Matrix strategy with OS-specific shell selection, pwsh installation step on macOS, tool installation steps, conditional step execution. ~120 lines YAML.

### Option D: Staged -- A on push, B on PR, C nightly

**What it does:**
- **On every push**: Option A (shellcheck + syntax, Ubuntu only) -- fast feedback, ~1 min
- **On PR**: Option B (structural checks, macOS runner) -- catches BSD-specific issues before merge
- **Nightly**: Option C (full matrix, macOS + Windows) -- comprehensive cross-platform, catches drift

**Cost**: Push ~1 min/push. PR ~40 min equiv/PR (maybe 1-2/day). Nightly ~60 min equiv/night. Total: ~200-300 min equiv/month. Well within Free plan.

**What it catches**: Same as C, with tiered latency (minutes for syntax, hours for structural, daily for full cross-platform).

**Complexity**: High (three trigger configurations), but each stage is independently valuable and can be rolled out incrementally.

## 5. Tool-Ops Verification in CI

### Current state

`reference/tool-ops.json` defines verification cases for the `block-claude-code-guide.sh` hook:

```json
"verifications": [
  {
    "type": "mock-json-pipe",
    "target": "block-claude-code-guide.sh",
    "cases": [
      {
        "input": {"tool_name":"Agent","tool_input":{"subagent_type":"claude-code-guide"}},
        "expectExit": 0,
        "expectStdout": "permissionDecision.*deny"
      },
      {
        "input": {"tool_name":"Agent","tool_input":{"subagent_type":"Explore"}},
        "expectExit": 0,
        "expectStdout": null
      }
    ]
  }
]
```

The verification method is documented as: `echo JSON | bash hook.sh -- check exit code and stdout`.

### CI feasibility: HIGH

These tests are perfectly suited for CI:
- Zero external dependencies (bash only)
- Deterministic (pure input/output, no side effects)
- Fast (~100ms per test case)
- Self-describing (JSON spec drives the test runner)

### Implementation sketch

A generic test runner could read `tool-ops.json`, iterate over all `verifications` entries, and for each `mock-json-pipe` case:

```bash
# For each case in tool-ops.json verifications:
result=$(echo "$input_json" | bash "shared/hooks/$target" 2>/dev/null)
exit_code=$?

# Check exit code
[ "$exit_code" -eq "$expectExit" ] || fail "exit $exit_code != $expectExit"

# Check stdout pattern (if expectStdout is not null)
if [ -n "$expectStdout" ]; then
    echo "$result" | grep -qE "$expectStdout" || fail "stdout does not match $expectStdout"
fi
```

This pattern scales to any hook with mock-json-pipe verification cases. As more hooks get verification specs in tool-ops.json, CI coverage grows automatically.

### Coverage potential

Currently: 1 hook (block-claude-code-guide.sh) with 2 test cases.

Other hooks that could gain verification specs:
- `standing-order-guard.sh` -- fires on PreToolUse, could test detection patterns
- `glossary-skill-guard.sh` -- fires on PreToolUse, could test term detection
- `sh-file-fixup.sh` -- fires on PostToolUse, could test CRLF detection
- `tool-ops-session-audit.sh` -- fires on PreToolUse, could test audit triggers

This could become the foundation for harness functional testing -- a test harness for the harness.

## 6. Reibung (Friction) Inventory

| Friction point | Severity | Mitigation |
|---------------|----------|------------|
| macOS runner 10x minute multiplier | Medium | Use macOS only for PR/nightly, not every push |
| Private repo minute quota (2,000 on Free) | Medium | Option D staging keeps usage within quota |
| check-pre-commit.sh needs git staging context | Low | Skip in CI, or simulate with `git diff HEAD~1` |
| check-pre-push.sh needs origin/main comparison | Low | Available in CI -- GitHub provides base ref |
| check-post-push.sh steps need local state | Medium | Graceful skip (already coded -- steps check for tool presence) |
| `pwsh` not pre-installed on macOS runners | Low | One `brew install` step, ~60 seconds |
| `claude` CLI not available in CI | Low | Steps already skip gracefully |
| shellcheck may flag existing code patterns | Medium | Initial run may produce many findings -- use baseline exclusions |
| Windows runners use Git Bash, not pwsh default | Low | Use `shell: pwsh` for PS1 steps, `shell: bash` for SH steps |
| Maintaining CI config alongside check scripts | Low | CI runs existing scripts, minimal coupling |
| BSD `paste` bug exists in current scripts | Blocking | Must fix check-post-push.sh before CI can run it on macOS |

## 7. Recommendation

### Recommended: Option D (Staged), rolled out incrementally

**Phase 1 (immediate, before the current plan):**
- Add shellcheck + `bash -n` + PS1 syntax validation on every push (Ubuntu runner)
- Add tool-ops verification cases (mock-json-pipe) on every push
- Cost: ~1-2 min/push, negligible
- Catches: syntax errors, shell pitfalls, hook behavior regressions
- This is pure value-add with near-zero cost and complexity

**Phase 2 (after post-push bugs are fixed):**
- Add `check-script-compliance.sh` + CI-subset of post-push on PR (macOS runner)
- Cost: ~40 min equiv/PR
- Catches: all structural/governance violations, BSD-specific runtime issues

**Phase 3 (when stable):**
- Add nightly full matrix (macOS + Windows)
- Cost: ~60 min equiv/night
- Catches: PS1-specific issues, full cross-platform behavioral parity

### Priority: Phase 1 BEFORE the plan

The post-push bug went undetected for 16 days. Phase 1 is:
- ~30 lines of YAML
- ~50 lines of test runner (tool-ops verification)
- Zero risk (read-only analysis, no deployments)
- Catches an entire class of bugs (syntax errors, shell pitfalls) that currently have zero automated detection
- The tool-ops verification runner is reusable infrastructure that grows with the harness

Phase 1 should be done before the current plan resumes. It is the governance layer that the governance project lacks -- automated detection for the detection scripts themselves.

## 8. Implementation Sketch (Phase 1)

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint-and-syntax:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: ShellCheck
        run: |
          find scripts/ shared/hooks/ -name '*.sh' -print0 \
            | xargs -0 shellcheck --severity=warning \
                --exclude=SC1091  # sourced files not followed
          # SC1091: check-lib.sh, aitools-lib.sh sourced dynamically

      - name: Bash syntax validation
        run: |
          errors=0
          for f in scripts/*.sh deploy/*.sh shared/hooks/*.sh; do
            [ -f "$f" ] || continue
            if ! bash -n "$f" 2>&1; then
              errors=$((errors + 1))
            fi
          done
          [ "$errors" -eq 0 ] || exit 1

      - name: PowerShell syntax validation
        shell: pwsh
        run: |
          $errors = 0
          Get-ChildItem -Path scripts/*.ps1,deploy/*.ps1 | ForEach-Object {
            $e = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
              $_.FullName, [ref]$null, [ref]$e)
            if ($e.Count -gt 0) {
              Write-Host "FAIL: $($_.Name)"
              $e | ForEach-Object { Write-Host "  line $($_.Extent.StartLineNumber): $($_.Message)" }
              $script:errors++
            }
          }
          if ($errors -gt 0) { exit 1 }

      - name: Tool-ops hook verification
        run: |
          # Run mock-json-pipe verification cases from tool-ops.json
          # Requires: python3 (pre-installed), bash
          python3 -c "
          import json, subprocess, re, sys
          with open('reference/tool-ops.json') as f:
              data = json.load(f)
          failures = 0
          for tool_name, tool_data in data.get('tools', {}).items():
              for v in tool_data.get('verifications', []):
                  if v['type'] != 'mock-json-pipe':
                      continue
                  target = v['target']
                  for i, case in enumerate(v['cases']):
                      input_json = json.dumps(case['input'])
                      result = subprocess.run(
                          ['bash', f'shared/hooks/{target}'],
                          input=input_json, capture_output=True, text=True
                      )
                      # Check exit code
                      if result.returncode != case['expectExit']:
                          print(f'FAIL [{tool_name}] case {i}: exit {result.returncode} != {case[\"expectExit\"]}')
                          failures += 1
                          continue
                      # Check stdout pattern
                      expect = case.get('expectStdout')
                      if expect and not re.search(expect, result.stdout):
                          print(f'FAIL [{tool_name}] case {i}: stdout does not match {expect}')
                          failures += 1
                      elif expect is None and result.stdout.strip():
                          print(f'FAIL [{tool_name}] case {i}: expected no stdout, got: {result.stdout[:100]}')
                          failures += 1
                      else:
                          print(f'PASS [{tool_name}] case {i}: {target}')
          sys.exit(1 if failures else 0)
          "

  # Phase 2: uncomment when post-push bugs are fixed
  # structural-checks:
  #   if: github.event_name == 'pull_request'
  #   runs-on: macos-latest
  #   steps:
  #     - uses: actions/checkout@v4
  #       with:
  #         fetch-depth: 0  # needed for origin/main comparison
  #     - name: Script compliance
  #       run: bash scripts/check-script-compliance.sh
```

### Open questions for the user

1. **Repo visibility**: `nobul-jose/aitools` -- is this public or private? Public repos get unlimited free minutes, which changes the cost calculus entirely.
2. **shellcheck baseline**: The scripts already have `# shellcheck source=` directives but have never been through a full shellcheck run. The first run will likely produce findings. Should we establish a baseline exclusion list, or fix findings first?
3. **Phase 1 timing**: Should Phase 1 be implemented now (before resuming the current plan), or queued as a follow-on?
