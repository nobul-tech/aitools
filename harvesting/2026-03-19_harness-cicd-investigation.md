# Investigation: How Does the Harness Verify, Test, and Ship Itself?

**Investigator**: S2 (Intelligence)
**Date**: 2026-03-18
**Session**: Z1IhGrcgGO
**Prerequisite**: aitools-in-tool-ops-investigation.md (concluded: aitools is NOT a tool-ops entry)

---

## 1. Current State: What the Harness Tests, by Layer

The harness has five verification mechanisms, organized as three check
scripts (pre-commit, pre-push, post-push), one compliance audit, and
one functional test spec. There is no CI/CD pipeline (no `.github/workflows/`
directory exists).

### Layer 1: Pre-Commit (16 steps)

`scripts/check-pre-commit.sh` -- runs against staged files only.

| Step | What it checks | Type |
|------|---------------|------|
| 1 | Git identity (Jose/jose@nobul.tech) | Config |
| 2 | Script syntax (.sh via `bash -n`, .ps1 via parser) | Structural |
| 3 | Build freshness (deploy/ regenerated after scripts/ change) | Pipeline |
| 4 | Line endings (.sh files have no CRLF) | Structural |
| 5 | Platform note reminder | Advisory |
| 6 | Executable bit on .sh files | Structural |
| 7 | Install command consistency vs tool-registry | Advisory |
| 8 | Config merge safety (no blind overwrites) | Structural |
| 9 | Release notes present for non-docs changes | Process |
| 10 | Deploy drift (unstaged deploy/ changes) | Pipeline |
| 11 | User repo uncommitted changes | Advisory |
| 12 | Template sync reminder (shared/claude-shared.md) | Advisory |
| 13 | Deploy template logic sync | Pipeline |
| 14 | Build prerequisite framework (cargo scripts use prereq checks) | Structural |
| 15 | Deprecated summary terms ("unchanged" -> "verified") | Style |
| 16 | Capability bypass audit (governed JSON in rules/CLAUDE.md) | Governance |

**Verdict**: Structural checks on staged files. Does NOT test runtime
behavior. Does NOT test skills. Does NOT verify hook functionality.
Step 16 (capability bypass) is the only governance-aware check.

### Layer 2: Pre-Push (10 steps)

`scripts/check-pre-push.sh` -- runs against commits in the push.

| Step | What it checks | Type |
|------|---------------|------|
| 1 | Pre-commit was run (advisory) | Process |
| 2 | No scratch/sensitive files in push | Security |
| 3 | Secret scan (passwords, API keys in diff) | Security |
| 4 | No WIP/fixup commits | Process |
| 5 | Commit message format (imperative mood check) | Style |
| 6 | Cross-platform check reminder | Advisory |
| 7 | Version bump reminder | Advisory |
| 8 | Tag freshness | Release |
| 9 | ROADMAP.md freshness | Process |
| 10 | Protected files review reminder | Advisory |

**Verdict**: Release readiness and hygiene. No functional testing.
Mostly advisory (step_warn). The security checks (steps 2-3) are
the most valuable -- they catch real deployment errors.

### Layer 3: Post-Push (31 steps)

`scripts/check-post-push.sh` -- comprehensive verification after push.

| Step | What it checks | Type |
|------|---------------|------|
| 1 | Push landed (HEAD == origin/main) | Deploy verification |
| 2 | Deploy script syntax (`bash -n` on deploy/*.sh) | Structural |
| 3 | MCP config integrity | Config |
| 4 | CLI entry point + version | Functional |
| 5 | Session archive readiness | Functional |
| 6 | Full syntax (.sh + .ps1 all scripts) | Structural |
| 7 | deploy/ drift | Pipeline |
| 9 | Source-of-truth consistency | Governance |
| 10 | Protected files inventory | Governance |
| 11 | Cross-platform pairing | Structural |
| 12 | CLAUDE.md line limit (< 200) | Style |
| 13 | Reference link audit | Structural |
| 14 | Line ending audit | Structural |
| 16 | Roadmap freshness | Process |
| 17 | Hook verification + schema validation | Functional |
| 18 | Untracked file hygiene | Process |
| 19 | Config merge audit | Structural |
| 20 | CC version-dep review | Config |
| 21 | Tool version freshness | Functional (BROKEN) |
| 22a-b | Logging hygiene | Style |
| 23 | Script standards compliance (delegates to check-script-compliance) | Structural |
| 24 | Summary panel DETAIL support | Structural |
| 25 | CLI tools table sync | Documentation |
| 26 | Deploy scripts list sync | Documentation |
| 27 | Build prerequisites installed | Functional (BROKEN on macOS) |
| 28 | Deploy state integrity | Functional |
| 29 | Deployment menu parity | Cross-platform |
| 30 | Return value coverage | Structural |
| 31 | Deployment state machine sync | Cross-platform |

**Verdict**: The most comprehensive layer. Contains both structural and
some functional checks. But it is BROKEN on macOS (3 bugs: bash 3.2
process-substitution, BSD `paste`, and emergent `set -e` abort -- see
`s2-post-push-aar.md`). Steps 21, 27, 29-31 all fail on macOS. The
script has been unable to complete a clean run since at least 2026-03-12.

### Layer 4: Script Compliance (13 steps)

`scripts/check-script-compliance.sh` -- checks script standards.

| Step | What it checks | Type |
|------|---------------|------|
| 1 | Log format compliance (aitools-lib.sh [level] format) | Style |
| 2 | Exit footer pattern (ERRORS + WARNINGS) | Structural |
| 3 | write_summary coverage | Structural |
| 4 | Counter tracking (log_error increments ERRORS) | Structural |
| 5 | Raw echo/Write-Host detection | Style |
| 6 | grep pipefail safety | Cross-platform |
| 7 | OS guards present | Cross-platform |
| 8 | Logging init | Structural |
| 9 | Cross-platform pairing (.sh/.ps1) | Cross-platform |
| 10 | SilentlyContinue result checks | Error handling |
| 11 | Summary categories (OK/WARN/ERROR/ACTION) | Style |
| 12 | Build prereq detection | Structural |
| 13 | Backup function usage | Structural |

**Verdict**: Thorough structural analysis of script standards. Does not
test runtime behavior. Runs as a sub-step of post-push (step 23).

### Layer 5: Tool-Ops Verification Specs (1 hook)

`reference/tool-ops.json` has verification cases for `block-claude-code-guide.sh`.

```json
"verifications": [{
  "type": "mock-json-pipe",
  "target": "block-claude-code-guide.sh",
  "cases": [
    { "input": {"tool_name":"Agent","tool_input":{"subagent_type":"claude-code-guide"}},
      "expectExit": 0, "expectStdout": "permissionDecision.*deny" },
    { "input": {"tool_name":"Agent","tool_input":{"subagent_type":"Explore"}},
      "expectExit": 0, "expectStdout": null }
  ]
}]
```

**Verdict**: The only functional test spec in the harness. Covers exactly
1 of 9 hooks. The pattern is sound -- JSON piped to the hook script,
check exit code and stdout pattern. But nobody runs these tests
automatically. They exist as specs, not as a test runner.

---

## 2. Gap Analysis: What is NOT Tested, by Artifact Type

### Rules (14 files in `.claude/rules/`)

| What is checked | By whom |
|----------------|---------|
| Governed JSON bypass (step 16) | check-pre-commit |
| Protected file inventory (step 10) | check-post-push |
| Reference link audit (step 13) | check-post-push |

| What is NOT checked | Impact |
|--------------------|--------|
| Rule coherence (do rules contradict each other?) | Agents receive conflicting instructions |
| Rule completeness (are all governed domains covered?) | Gaps in governance |
| Rule-to-skill alignment (does each rule reference the right skill?) | Broken trigger directives |
| Intent quality (purpose/scope/audience present and specific?) | Ambiguity in interpretation |
| Rule effectiveness (do rules actually change agent behavior?) | Governance theater |

### Skills (18 total: 9 project, 9 user-level)

| What is checked | By whom |
|----------------|---------|
| NOTHING | -- |

| What is NOT checked | Impact |
|--------------------|--------|
| Skill file structure (frontmatter, required sections) | Agent fails to parse skill |
| Skill-to-registry alignment (does skill reference correct JSON?) | Skill reads wrong data |
| Skill process completeness (does it cover all governed operations?) | Partial governance |
| Skill intent presence and quality | Agent misuses skill |
| Skill cross-references (do referenced files exist?) | Broken skill workflow |
| Skill functional correctness (does invoking it produce correct output?) | Wrong behavior |
| Skill duplication (do two skills govern the same thing?) | Conflicting governance |

**This is the biggest gap.** 18 skills with zero structural or functional
verification. The `/handoff` skill was the first to use a thorough
verification workflow (9 criteria, independent verifier agent), but that
was ad-hoc and non-repeatable.

### Hooks (9 hooks in `shared/hooks/`)

| What is checked | By whom |
|----------------|---------|
| Hook schema validation (step 17b) | check-post-push |
| 1 hook's functional behavior via mock-JSON-pipe | tool-ops.json verification spec (manual) |

| What is NOT checked | Impact |
|--------------------|--------|
| 8 of 9 hooks have no functional test | Hook regression undetected |
| Hook interaction effects (do hooks conflict?) | Cascading failures |
| Hook performance (latency budget) | Agent slowdown |
| Hook deployment correctness (does setup-user-hooks deploy correctly?) | Hooks not firing |
| Hook stderr/stdout contract (correct format for CC consumption?) | Silent hook failure |

### Deploy Pipeline (build-deploy.sh -> deploy/)

| What is checked | By whom |
|----------------|---------|
| deploy/ syntax (`bash -n`) | check-post-push step 2 |
| deploy/ drift detection | check-pre-commit step 10, check-post-push step 7 |
| Deploy scripts list sync | check-post-push step 26 |

| What is NOT checked | Impact |
|--------------------|--------|
| Deploy script functional correctness (do they install correctly?) | Broken deployment on target machines |
| Self-contained constraint (does each deploy script have all inlined content?) | Runtime dependency on repo |
| Cross-platform deploy correctness (does .sh work on macOS, .ps1 on Windows?) | Platform-specific deployment failure |
| Build reproducibility (same input -> same output?) | Flaky builds |
| Embedded content integrity (did build-deploy.sh inline correctly?) | Wrong config deployed |

### Configuration (setup scripts, config files)

| What is checked | By whom |
|----------------|---------|
| Config merge safety (step 8) | check-pre-commit |
| Config merge audit (step 19) | check-post-push |
| MCP config integrity (step 3) | check-post-push |
| CC version-dep review (step 20) | check-post-push |

| What is NOT checked | Impact |
|--------------------|--------|
| End-to-end setup flow (fresh machine -> working harness) | Broken first-run experience |
| Config interaction effects (does one setup script break another's output?) | Config corruption |
| Idempotency (does running setup twice produce same result?) | Incremental corruption |
| Interactive menu correctness (do all menu options work?) | User-facing bugs |

---

## 3. The Bootstrap Problem

### The paradox stated precisely

The harness uses check scripts to verify itself. But:

1. The check scripts ARE harness code -- they follow script-standards.md,
   use aitools-lib.sh, run on the same platforms.
2. When a check script has a bug (as check-post-push.sh does right now),
   the verification infrastructure is degraded -- and there is no
   meta-verification layer to detect this.
3. Fixing a check script requires the same verification rigor as fixing
   any other harness code -- but the tool that would verify the fix is
   the broken check script itself.

This is not just theoretical. The evidence from THIS session:

- **check-post-push.sh has been broken on macOS since March 2** (16 days).
  Bug 1 (bash 3.2 process-substitution) has existed since introduction.
  Bug 2 (BSD paste) has existed since March 12. The script that is
  supposed to catch cross-platform bugs... has cross-platform bugs.

- **Step 16 caught 28 JSON path bypass vectors** but the finding was
  rationalized as "known failures" rather than actioned. The audit
  layer correctly identified the problem; the human/agent process
  layer dismissed it.

- **The /handoff skill was built with no automated tests.** Its
  verification was thorough (9 criteria, independent verifier), but it
  was a one-time act. If someone modifies the skill tomorrow, the
  9-criteria verification won't re-run automatically.

### What the disciplines say

**G&ouml;del's Incompleteness Theorem (metamathematics)**: A sufficiently
powerful formal system cannot prove its own consistency. Directly
applicable: the harness cannot FULLY verify itself using only its own
verification tools. There will always be properties of the harness that
its check scripts cannot test -- because those properties include "the
check scripts work correctly."

**Implications**: We need at least ONE verification mechanism external
to the check script system. This could be:
- A human running manual smoke tests
- A CI system that runs check scripts in a clean environment
- An independent AI agent that audits check script correctness
- Production monitoring (hooks fire -> we know they work)

**SRE (testing in production)**: The hooks ARE tested in production
because they fire every session. This is actually the strongest
verification the harness has -- if `block-claude-code-guide.sh` stops
working, the user notices because the buggy subagent gets through.
But this is reactive (detects after failure), not preventive (catches
before deployment).

**Safety engineering (independent verification)**: The verifier must
be independent of the thing being verified. Decision #54 captures
this as "same check verifies the fix" -- but the check itself must be
independently validated. The /handoff verification pattern achieves
this: the writer (S3) is different from the verifier (fresh S2). But
the verifier uses the same SKILL.md instructions as the writer, so
it's partially dependent.

**QA (regression testing)**: Every bug fix should produce a regression
test that prevents recurrence. The harness has this for one class of
bug: `check-script-compliance.sh` checks for `grep -P` (a previously
fixed cross-platform bug). But the paste incompatibility -- the same
class of bug -- had no such check. The pattern exists but is not
systematically applied.

### The irreducible minimum

From Godel: we cannot fully self-verify. From SRE: production is a
valid test environment. From safety engineering: independence matters.
From QA: regression tests prevent recurrence.

The practical conclusion: **the harness needs a layered verification
strategy where each layer catches what the previous one misses, and at
least one layer is external to the harness itself.**

This is exactly the three-layer governance pattern the harness already
uses (prevention, detection, audit) -- but applied to the harness's own
verification infrastructure.

---

## 4. Barrier Analysis: Five Options

### Option A: Extend check scripts with skill/rule functional tests

**What it does**: Add steps to check-post-push.sh for skill structure
validation, rule coherence checking, and hook functional testing.

**Solves the bootstrap problem?** Partially. It expands coverage but
doesn't address the "who tests the tester" problem. A bug in the new
check steps would be as invisible as the current paste bug.

**Cost**: Medium. 5-10 new steps per check script. Requires defining
what "correct" means for each artifact type.

**Reibung**:
- check-post-push.sh is already 800+ lines and broken. Adding more
  steps to a broken script is throwing good code after bad.
- Structural checks are easy (file exists, has frontmatter, references
  resolve). Functional checks are hard (does the skill produce the
  right output when invoked?).
- Skills are inherently AI-interpreted -- there is no deterministic
  "correct output" to test against. A skill is correct when an agent
  follows it and produces a good result. That's not checkable by bash.

**Verdict**: Good for structural skill/rule checks. Insufficient alone.

### Option B: Build a new test framework

**What it does**: Create a test runner (possibly Python) that reads
verification specs (like tool-ops.json's mock-json-pipe pattern) and
executes them. Each artifact type gets its own spec format.

**Solves the bootstrap problem?** Partially. The test framework itself
needs testing, but it's a simpler system than the check scripts, so
the meta-verification burden is smaller.

**Cost**: High. New framework = new code, new patterns, new maintenance.
Runs against the project's "prefer simple, minimal solutions" principle.

**Reibung**:
- The tool-ops verification spec pattern already exists and works for
  hooks. Generalizing it to other artifact types is reasonable.
- But skills and rules don't have deterministic input/output contracts
  the way hooks do. A hook gets JSON, produces JSON. A skill gets
  invoked by an agent in conversation -- there's no "pipe input, check
  output" equivalent.
- Building a test framework for a solo developer's harness is high
  ceremony for low volume.

**Verdict**: Justified for hooks (extend the existing pattern). Over-
engineered for skills and rules.

### Option C: Subagent verification pattern from /handoff

**What it does**: Use the 9-criteria verification pattern from /handoff
as the test infrastructure. Launch a verifier agent that reads the
skill/rule/hook and evaluates it against criteria. AI tests AI.

**Solves the bootstrap problem?** Yes, for functional correctness.
The verifier is independent of the writer (different agent, different
context). It can catch semantic errors that bash scripts cannot
(ambiguity, contradictions, missing coverage).

**Cost**: Per-invocation (each verification costs an AI call). Not
automatable without a CI runner. Manual trigger.

**Reibung**:
- The /handoff pattern proved this works: the verifier caught reference
  integrity issues, naming collisions, and scope governance gaps that
  no check script could have found.
- But it requires human initiation. Nobody will remember to run
  verification on every skill change.
- It is non-deterministic. The same verifier might produce different
  results on different runs. This makes it unreliable for CI.
- It is slow. A full 9-criteria verification takes minutes, not
  seconds.

**Verdict**: The right tool for functional/semantic verification of
skills and rules. Must be triggered, not automated.

### Option D: CI/CD pipeline (GitHub Actions)

**What it does**: Run check scripts on every push via GitHub Actions.
Matrix build: macOS + Windows. Catches cross-platform bugs like the
paste issue before they reach production.

**Solves the bootstrap problem?** Partially. CI catches "check scripts
that don't run on platform X" but doesn't test "check scripts that
produce wrong results." The paste bug would have been caught (script
fails on macOS runner). The bash 3.2 bug's silent failure would NOT
have been caught (script appears to pass).

**Cost**: Low to set up. GitHub Actions is free for public repos.
Medium to maintain (CI config drift, runner version changes, macOS
runner availability).

**Reibung**:
- The project has no CI today. Adding it is a step function in
  infrastructure complexity.
- macOS runners on GitHub Actions have newer bash (Homebrew), which
  might NOT reproduce the bash 3.2 bug. The CI might pass while
  production fails -- a false negative.
- Windows runners use Git Bash. The Claude Code shell behavior
  applies.
- CI requires secrets for checks that need config.json (MCP checks,
  session archive checks). Some steps would need to be skipped.
- aitools is a private productivity tool. The CI burden may exceed
  the value for a solo developer.

**Verdict**: Maximum value for cross-platform bugs. Requires careful
runner configuration to match production environments.

### Option E: Combine -- structural (check scripts), functional
(subagent verification), automation (CI)

**What it does**: Layer the mechanisms:

1. **Check scripts** (existing + enhanced): structural validation of
   all artifact types. Add skill structure checks, hook functional
   tests (extend tool-ops verification spec pattern), rule coherence
   checks. These are deterministic, fast, automatable.

2. **Subagent verification** (generalize /handoff pattern): semantic
   validation of skills and rules. Run on-demand when a skill or rule
   changes significantly. Non-deterministic but high-value. Human-
   triggered.

3. **CI pipeline** (GitHub Actions): run check scripts on push.
   Matrix: macOS (with system bash 3.2) + Ubuntu. Catches cross-
   platform bugs automatically. Skips checks requiring local config.

4. **Production monitoring** (existing hooks + KPIs): hooks fire every
   session. When they stop working, the user notices. When KPIs ship
   (decision #32), drift detection becomes proactive.

**Solves the bootstrap problem?** As well as possible. Each layer
catches what the others miss:
- Check scripts catch structural regressions
- Subagent verification catches semantic regressions
- CI catches cross-platform regressions
- Production catches deployment regressions

No layer is self-referential. The check scripts are tested by CI
(external runner). The subagent verifier is independent of the writer.
CI is maintained by GitHub (external infrastructure). Production
monitoring is the user's own experience (the ultimate external test).

**Cost**: Incremental. Each layer is additive. Can be built in priority
order.

**Reibung**:
- The biggest risk is over-engineering. A solo developer's harness
  does not need enterprise-grade CI/CD. The 80/20 is: fix the broken
  check scripts, add skill structural checks, and use subagent
  verification for significant changes.
- CI is valuable but optional. The cross-platform bugs it catches
  can also be caught by disciplined manual testing (which is already
  a PSO: "tested: macOS/Windows" in commit messages). CI just removes
  the human from the loop.

**Verdict**: The right architecture. Implement in priority order per
cost/benefit.

---

## 5. The Skill Testing Gap

### Why skills are the biggest gap

18 skills exist (9 project, 9 user-level). They govern every registry
access, every incident filing, every tool evaluation, every handoff.
They are the primary interface between the agent and the harness's
governed data.

None of them have any test coverage.

### What could be tested structurally (by check scripts)

A `check-skill-compliance` step (or steps added to check-post-push)
could verify:

| Check | What it validates | Deterministic? |
|-------|------------------|----------------|
| Frontmatter present (name, description) | Skill is discoverable by CC | Yes |
| Intent section present (purpose, scope, audience) | Skill has governance metadata | Yes |
| "When to use" section present | Trigger conditions documented | Yes |
| Cross-references resolve (referenced files exist) | Skill won't break on file reads | Yes |
| Governed JSON path is correct (skill references valid JSON) | Skill reads correct data | Yes |
| disable-model-invocation flag present where needed | Skill invocation control | Yes |
| No governed JSON paths in non-skill files | Bypass prevention (already step 16) | Yes |

These checks are all structural. They verify the skill is well-formed,
not that it produces correct behavior. But well-formedness prevents a
large class of failures (skill can't find its JSON, references a
nonexistent file, missing frontmatter so CC doesn't discover it).

### What requires subagent verification (semantic)

| Criterion | What it validates | Deterministic? |
|-----------|------------------|----------------|
| Self-containment | Agent can follow skill without other context | No |
| Process completeness | All governed operations are covered | No |
| Coherence with governing rule | Skill implements what rule says | No |
| Ambiguity scan | No vague instructions or undefined terms | No |
| Registry alignment | Skill's process matches registry schema | Partially |
| Edge case coverage | Skill handles error paths | No |

These are the /handoff verification criteria adapted for skills. They
require AI judgment. They cannot be automated in a check script.

### Can the /handoff pattern generalize?

The /handoff verification pattern has 9 criteria. For skills, 5-6
criteria would suffice:

1. **Structure**: Frontmatter, intent, "when to use" present
2. **Reference integrity**: All file paths exist
3. **Coherence**: Skill aligns with its governing rule
4. **Process completeness**: All governed operations documented
5. **Ambiguity**: No vague or contradictory instructions
6. **Edge cases**: Error paths handled (WRITE_BLOCKED, missing JSON,
   concurrent access)

This could be packaged as a `/skill-verify` skill -- a meta-skill
that verifies other skills. The input is a skill path. The output is
a verification report with PASS/NEEDS AMENDMENT/FAIL per criterion.

**Cost**: Writing the skill (~100 lines). Running it per skill change
(one AI call per verification). Total: 18 initial runs + on-demand.

**Value**: High. It catches the semantic errors that structural checks
miss. It provides the "independent verification" that safety
engineering requires.

**Limitation**: Non-deterministic. Two runs might produce different
results. This is acceptable for on-demand verification but not for
CI gates.

---

## 6. Reconciliation: If Not Tool-Ops, Then What?

The tool-ops investigation concluded that aitools should not be a
tool-ops entry because tool-ops governs tools the harness manages, and
the harness should not recursively manage itself.

But the harness still needs a governance mechanism for its own changes.
What is it?

### Current governance mechanisms for harness changes

| Mechanism | What it governs | Layer |
|-----------|----------------|-------|
| Protected file review gate (sources-of-truth.md) | Changes to authoritative files | Prevention |
| Pre-commit checks (16 steps) | Structural correctness of staged changes | Detection |
| Pre-push checks (10 steps) | Release readiness | Detection |
| Post-push checks (31 steps) | Comprehensive verification | Audit |
| Script compliance (13 steps) | Script standards adherence | Audit |
| Incident governance (/incident skill) | Tracking deficiencies | Process |
| Harness improvement cycle (decision #54) | Finding -> verified fix | Process |
| Governed data access (governed-data-access.md) | Registry access patterns | Prevention |
| Three-layer governance pattern | Prevention/Detection/Audit for all domains | Architecture |

### What is missing: the self-verification governance gap

The table above covers WHAT is governed. The gap is WHO governs the
governors:

1. **Check script correctness is ungoverned.** No mechanism verifies
   that check scripts produce correct results. The paste bug persisted
   for 16 days because nothing checks the checkers.

2. **Skill correctness is ungoverned.** No structural or functional
   verification exists for skills. They are written and deployed
   without testing.

3. **Hook coverage is ungoverned.** 1 of 9 hooks has a verification
   spec. The tool-ops pattern exists but has not been applied.

4. **Deploy pipeline correctness is ungoverned.** build-deploy.sh
   output is committed and deployed without functional verification.

### The governance mechanism for harness self-verification

It is NOT a new entry in tool-ops (that would be self-referential).
It is NOT a new framework (the existing three-layer pattern applies).

It is: **extending the existing three-layer governance to cover the
verification infrastructure itself.**

| Layer | Existing | Gap | Extension |
|-------|----------|-----|-----------|
| Prevention | Protected file review gate | Check scripts not protected | Add check-*.sh to protected files table |
| Detection | Check scripts | Check scripts not checked | CI runs check scripts in clean environment; check-script-compliance gets self-checks |
| Audit | Post-push comprehensive | Skills/hooks not audited | /skill-verify skill; extend tool-ops verification specs to all hooks |

The key insight: **the harness does not need a NEW governance
mechanism. It needs the EXISTING mechanism applied to its own
verification code.** The three-layer pattern was designed to be
recursive -- each layer catches what the previous misses. The gap
is that the pattern has not been applied to the checking layer itself.

---

## 7. Recommended Architecture: The Test/Verify/Ship Pipeline

### Pipeline stages

```
Change -> Structural Check -> Ship -> Verification -> Monitoring
            (deterministic)                (semantic)    (production)
```

#### Stage 1: Structural Checks (pre-commit, pre-push)

**Existing**: 16 + 10 steps covering scripts, configs, governance.

**Extensions needed**:
- Add skill structure checks to check-pre-commit (frontmatter, intent,
  references)
- Add `paste -` portability check to check-script-compliance (prevents
  recurrence of the paste bug class)
- Fix check-post-push.sh bugs (3 fixes from AAR)

#### Stage 2: Ship (commit + push)

**Existing**: git commit with manual check script runs.

**Extension needed**:
- CI runs check scripts on push (GitHub Actions, macOS + Ubuntu matrix)
- CI skips steps requiring local config (MCP, session archive,
  user repo)
- CI uses system bash on macOS runner (catches bash 3.2 bugs)

#### Stage 3: Semantic Verification (on-demand)

**New**: `/skill-verify` skill for on-demand verification of skills.

**Trigger**: When a skill is created or significantly modified, run
`/skill-verify` against it. Not automated -- human-triggered, like
`/handoff` step 5.

**Extension**: Generalize tool-ops verification specs to all 9 hooks.
Add verification cases to tool-ops.json. Build a test runner that
executes them (a simple bash script that pipes JSON and checks output).

#### Stage 4: Production Monitoring (continuous)

**Existing**: Hooks fire every session. User notices failures.

**Extension**: When log_ship is built (decision #32), hooks report
their fire rate. If a hook stops firing, the KPI drops to zero,
and the monitoring alerts. This is the external verification layer
that the bootstrap problem requires -- production observability that
is independent of the check script system.

### The self-check layer

For the check scripts themselves:

1. **CI is the primary verifier.** If check-post-push.sh fails on
   the macOS CI runner, the push fails. This catches platform bugs
   like the paste issue.

2. **check-script-compliance.sh gets self-check capability.** It
   already checks setup scripts for standards compliance. Extending
   it to check check-*.sh scripts (which follow the same standards)
   closes the "quis custodiet" loop partially.

3. **Regression tests.** Every check script bug fix adds a detection
   step to check-script-compliance for the bug class. The paste bug
   fix adds a "paste without stdin file arg" check. The bash 3.2 bug
   fix adds a "process substitution + heredoc" check. These are the
   QA regression tests.

---

## 8. Top 5 Actions (Prioritized by Leverage and Urgency)

### Action 1: Fix check-post-push.sh (URGENT -- test infra broken)

**What**: Fix the 3 bugs identified in `s2-post-push-aar.md`:
- Bug 1: Replace `< <(python3 - <<'PYEOF')` with write-then-execute
- Bug 2: Replace all 11 `paste -sd,` / `paste -sd ', '` with
  `paste -s -d , -` or a `join_lines` helper
- Bug 3: Resolves automatically when Bug 2 is fixed

**Why first**: The test infrastructure is broken. Nothing else matters
until the tester works. A harness that cannot verify itself after a push
is operating blind.

**Leverage**: Restores 31 steps of verification that are currently
non-functional on macOS. Every subsequent improvement depends on this.

**Effort**: 2-3 hours. Well-defined fixes from AAR.

### Action 2: Add skill structural checks to check-pre-commit

**What**: New steps in check-pre-commit.sh (and .ps1) for skills:
- Frontmatter validation (name, description present)
- Intent section present
- "When to use" section present
- Referenced file paths exist
- Governed JSON paths are correct (if skill references a registry)

**Why second**: Skills are the biggest untested artifact class (18
skills, 0 checks). Structural checks are deterministic, fast, and
prevent the most common failure modes (missing frontmatter, broken
references).

**Leverage**: Covers 18 artifacts that currently have zero verification.
Prevents the class of bugs where a skill references a nonexistent file
or missing JSON registry.

**Effort**: 4-6 hours. Pattern exists in other check steps.

### Action 3: Extend tool-ops verification specs to all hooks

**What**: Add verification cases to tool-ops.json for all 9 hooks.
Build a simple test runner (`scripts/check-hook-functional.sh`) that
reads the verification cases and executes them (pipe JSON, check
exit code and stdout).

**Why third**: 8 of 9 hooks have no functional test. The mock-json-pipe
pattern already exists and is proven for one hook. Extending it to all
hooks is mechanical work -- the hard design decisions are already made.

**Leverage**: Hooks are the detection layer. If hooks break silently
(like bash 3.2 bugs in check scripts), the governance layer degrades
without warning. Functional tests catch this.

**Effort**: 6-8 hours (2-3 test cases per hook x 9 hooks + test runner).

### Action 4: Add check-script portability checks for BSD gotchas

**What**: New steps in check-script-compliance.sh:
- Detect `paste -s` without explicit stdin file arg (catches BSD
  `paste` bug class)
- Detect `< <(cmd <<'HEREDOC')` pattern (catches bash 3.2 bug class)
- Consider: `sort` flags, `sed -i` behavior, other known BSD/GNU
  divergences

**Why fourth**: Prevents recurrence of the exact bug class that broke
check-post-push.sh. This is the QA regression test principle: every bug
fix should produce a detection mechanism.

**Leverage**: Prevents the SAME CLASS of bug from recurring in any
future check script. Low effort, high prevention value.

**Effort**: 2-3 hours.

### Action 5: Design the /skill-verify skill (semantic verification)

**What**: Design (not build yet) a `/skill-verify` skill that adapts
the /handoff 9-criteria verification pattern for skills:
1. Structure (frontmatter, required sections)
2. Reference integrity (all paths exist)
3. Coherence with governing rule
4. Process completeness
5. Ambiguity scan
6. Edge case coverage

**Why fifth**: This is the highest-value semantic verification the
harness can have, but it requires design before implementation. The
/handoff pattern proved the approach works. Designing the skill means
defining the criteria, the output format, and the trigger conditions.

**Leverage**: Once built, provides on-demand verification for the
artifact type with the biggest gap. But designing it first (rather than
building immediately) follows the "plan before build" principle.

**Effort**: Design: 2-3 hours. Implementation: 4-6 hours (later).

---

## Appendix A: CI Architecture (if pursued)

If GitHub Actions CI is added (recommended as Action 6, after the
top 5):

```yaml
# .github/workflows/harness-verify.yml
name: Harness Verification
on: [push, pull_request]
jobs:
  check-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Pre-commit checks
        run: bash scripts/check-pre-commit.sh --fix
      - name: Post-push checks (skip config-dependent steps)
        run: AITOOLS_CI=true bash scripts/check-post-push.sh
      - name: Script compliance
        run: bash scripts/check-script-compliance.sh
      - name: Hook functional tests
        run: bash scripts/check-hook-functional.sh
  check-ubuntu:
    runs-on: ubuntu-latest
    steps: [same as above]
```

Key design decisions:
- `AITOOLS_CI=true` env var skips steps requiring local config (MCP,
  session archive, user repo)
- macOS runner uses Homebrew bash by default (5.x) -- would need
  explicit `/bin/bash` invocation to test bash 3.2 compatibility
- No Windows CI initially (pwsh parsing is already tested by
  check-pre-commit step 2 on the developer's Windows machine)
- No secrets needed (all checks are read-only)

## Appendix B: Artifact-Type Verification Matrix (Target State)

| Artifact Type | Structural (check scripts) | Functional (specs/runner) | Semantic (subagent) | Production (monitoring) |
|--------------|---------------------------|--------------------------|--------------------|-----------------------|
| Rules | Step 16 (bypass), step 10 (inventory), step 13 (links) | -- | /skill-verify could extend | Agent behavior (indirect) |
| Skills | **NEW: frontmatter, intent, refs, JSON path** | -- | **NEW: /skill-verify** | Agent invocation (indirect) |
| Hooks | Step 17b (schema) | **NEW: all 9 hooks via tool-ops specs** | -- | Hook fire rate KPI (#32) |
| Deploy scripts | Step 2 (syntax), step 7 (drift), step 26 (list) | -- | -- | Deployment success on target machines |
| Check scripts | Step 23 (compliance, self-referential) | **NEW: CI runs them** | -- | Developer runs them |
| Config files | Step 3 (MCP), step 19 (merge), step 8 (merge safety) | -- | -- | Setup script output |
| Planning artifacts | Step 10 (protected files) | -- | /handoff verification | Session continuity |

## Appendix C: Evidence Index

| Evidence | File | Finding |
|----------|------|---------|
| check-post-push broken | `.scratch/session-Z1IhGrcgGO/s2-post-push-aar.md` | 3 bugs, script unable to complete on macOS since 2026-03-02 |
| tool-ops "no" for aitools | `.scratch/session-Z1IhGrcgGO/aitools-in-tool-ops-investigation.md` | Option C: aitools is the harness, not a managed tool |
| 28 JSON bypass vectors | `scripts/check-pre-commit.sh` step 16 | Step correctly detected but finding was rationalized |
| /handoff verification | `shared/skills/handoff/SKILL.md` step 5 | 9 criteria, independent verifier, PASS/NEEDS AMENDMENT/FAIL |
| Tool-ops verification spec | `reference/tool-ops.json` | mock-json-pipe pattern for 1 of 9 hooks |
| No CI | `.github/workflows/` | Directory does not exist |
| 18 skills, 0 tests | `.claude/skills/*/SKILL.md` + `shared/skills/*/SKILL.md` | Zero structural or functional verification |
| Decision #8 | planning-brief.json | Platform engineering framework, CI patterns from nobul-ops |
| Decision #32 | planning-brief.json | KPI telemetry via log_ship (prerequisite for production monitoring) |
| Decision #41 | planning-brief.json | Plan-gate hook (structural enforcement pattern) |
| Decision #42 | planning-brief.json | Intent-enforcement hook (write-time detection pattern) |
| Decision #53 | planning-brief.json | Governed drift prevention (multi-layer structural enforcement) |
| Decision #54 | planning-brief.json | Harness improvement cycle (finding-to-verified-fix process) |
| 9 hooks | `shared/hooks/*.sh` | 1 has functional test spec, 8 have none |
