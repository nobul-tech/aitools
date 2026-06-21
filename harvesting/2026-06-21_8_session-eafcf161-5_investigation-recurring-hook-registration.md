# Investigation: Recurring Hook Registration Drift

**Date:** 2026-06-20 · **Session:** eafcf161 · **Trigger:** Adding `block-explore-agent.sh` to `hooks-manifest.json` had zero effect — `setup-user-hooks.sh` reported "Settings unchanged" because it hardcodes the hook list and never reads the manifest.

**Method:** `/investigate` skill. Evidence: full RELEASE_NOTES hook era (v0.55–v0.70), commit log, gh issue #7, `setup-user-hooks.sh/.ps1`, `hooks-manifest.json`, `.claude/rules/hook-rollout.md`.

---

## 1. Detection

Self-detected during a live change: a manifest edit that *should* have registered a new hook did nothing. Investigation revealed the manifest is documentation/audit-only, not the deploy driver.

## 2. Triage

- **Severity: High.** The failure mode is *silent*: a hook deploys as a file but is never registered, so it never fires — and nothing surfaces it until a check script or a user notices missing behavior. One instance (v0.68.0) ran silently **for 3 months** (Windows harvesting no-op since 2026-03-15).
- **Blast radius:** every hook add/remove/rename, both platforms, both the dev and MDM deploy paths.

## 3. RCA

### The recurring incident class (timeline of recurrences)

**Class A — Hook registration drift / incompleteness** (hand-maintained parallel lists):

| # | Version | Incident |
|---|---------|----------|
| 1 | v0.60 (Gap #25) | `deploy/setup-user-hooks` embedded 2 of 6 hook scripts; settings.json referenced 4 missing paths on MDM machines |
| 2 | v0.60 #10 | `setup-user-hooks.ps1` didn't deploy scratch-init/harvest-session — bash↔PS1 drift |
| 3 | v0.67.0 #5 | harness-db-sessionstart/sessionend deployed but never registered via `mergeHookEntry` → invisible to CC |
| 4 | v0.67.1 #1 | stale Stop hooks deleted but still referenced in the deployment pipeline → orphans |
| 5 | v0.68.0 #1 (High) | Windows harvest no-op — scratch-init + harvest-session deployed but never registered in settings.json **for ~3 months** |
| 6 | v0.66.0 / v0.68.0 #2 | check step 32 (the parity audit meant to catch this) itself false-failed on Windows |
| 7 | **This session** | manifest entry for `block-explore-agent` ignored — setup-user-hooks hardcodes the list |

That is **7 instances of the same class.** Per the skill's escalation rule (*"same root cause category 3+ times → structural fix required"*), this is unambiguously structural.

> Note — a *parallel* class exists but is distinct: **Class B, hook-body portability/runtime crashes** (v0.29.2 `$MODE`, v0.31.0 `find -printf`, bc2429e hook-type, v0.64.0 `stat -f` = "4th hook crash instance"; v0.67.0 `CLAUDE_EFFORT_LEVEL` unbound; v0.65.1 missing `set -euo pipefail`). Class B is addressed (partially) by check-pre-commit step 17 + the hook-rollout smoke-test rule and is **out of scope** for the registration fix below. Calling it out so the structural fix isn't overclaimed.

### 5 Whys (Class A)

1. **Why did the manifest edit do nothing?** → `setup-user-hooks.{sh,ps1}` hardcode the hook list (~10 touchpoints/hook: resolve, existence-check, dest var, deploy-pair, `*_CMD`, positional `argv[N]`, `mergeHookEntry`, validation count) and never read the manifest.
2. **Why hardcoded when a manifest exists?** → The manifest (v0.68.0) was introduced only as an **audit** source for check-post-push step 32 (parity), not as the **generator**.
3. **Why only an audit source?** → The "manifest as generator" refactor was explicitly deferred — tracked in **issue #7** as "the deeper refactor that fully removes the parallel hand-maintained lists" (plan `imperative-gliding-newell.md` §5 full vision).
4. **Why has the duplication survived 7 incidents?** → Each corrective action was either **point Remediation** ("add the missing registration") or **Detection** ("add/fix the parity audit") — never **Prevention**. Adding detection (step 32) reduced the pain enough to keep deferring the structural fix.
5. **Why does detection-without-prevention keep producing these?** → Because the drift can still *happen* — step 32 only tells you *after the fact*, at check time, and twice the audit itself was broken. The single source of truth exists as a document but nothing **generates** from it. **The recurrence is the proof the corrective action was wrong.**

### Swiss cheese (v0.68.0 — 3-month silent failure)

```
Prevention: no single source — registration hand-copied per language ........ FAILED
Detection:  step-32 parity audit didn't exist yet (added in response); when
            it did, it false-failed on Windows (v0.66.0, v0.68.0) ............ FAILED
Audit:      no on-machine "is this hook actually registered + firing" check .. FAILED
Review:     diff showed the file deployed; a *missing* registration is an
            absence — invisible in a diff .................................... FAILED
```

All four layers failed → systemic gap, not a one-off.

### Root cause

**Hook registration is hand-maintained as parallel lists across `setup-user-hooks.sh`, `setup-user-hooks.ps1`, and `build-deploy.sh` (sections 13-14), in two languages, with ~10 touchpoints per hook. `hooks-manifest.json` is the declared single source of truth but is consumed only as an audit input — nothing generates the deploy + registration from it.** Prevention was never built; only detection and point-remediation.

## 4. Remediation (immediate, this session)

`block-explore-agent.sh` is written, tested (allow/block verified), and committed-ready. Two ways to land it:
- (a) Hardcode-mirror it through the 3 files (perpetuates the debt — an 8th instance waiting to happen), or
- (b) Build the generator (below) — which registers `block-explore-agent` *for free* as its first proof.

## 5. Corrective Action — STRUCTURAL (the permanent fix)

**Make `hooks-manifest.json` the generator, not just the audit source.** This is already designed and tracked (issue #7, plan §5).

`setup-user-hooks.{sh,ps1}` and `build-deploy.sh` **loop over the manifest** to produce:
1. **Deploy** — copy each `hooks[].file` (+ `deploy[]` helpers) to `~/.claude/hooks/`.
2. **Register** — `mergeHookEntry(event, file, matcher, cmd)` per entry.
3. **Reconcile/deregister** — remove any registered or on-disk hook whose `file` is not in the manifest (replaces today's hardcoded stale-hook cleanup list).
4. **Validate** — assert exactly-one registration per manifest entry (replaces the hand-written per-hook count checks).

Result: **adding a hook = one manifest line** (exactly what was attempted this session). The positional-`argv` node block and the parallel `*_SCRIPT`/`*_DEST`/`*_CMD` lists are deleted.

### Barrier analysis (replay each incident with the generator in place)

| Incident | Prevented? |
|----------|-----------|
| v0.68.0 Windows no-op | ✅ generation emits deploy **and** registration from one entry, both languages |
| v0.67.0 harness-db unregistered | ✅ |
| v0.67.1 stale orphans | ✅ reconcile step deregisters anything not in the manifest |
| v0.60 PS1 parity drift | ✅ both languages generate from the same manifest |
| This session's block-explore no-op | ✅ |
| **Class B portability crashes** | ❌ **NOT prevented** — body bugs are caught by check step 17 + smoke tests, not by generation. Do not overclaim. |

Coverage statement: *manifest-as-generator prevents Class A (registration drift/incompleteness). It does not prevent Class B (hook-body portability/runtime crashes), which retain their own barriers.*

### Why this is the right type

- Behavioral ("remember to update all lists") — already implicitly relied on; failed 7×.
- Detection (step 32 parity audit) — already built; necessary but insufficient (drift still happens; audit twice broke).
- **Structural (generate from the single source)** — removes the ability to drift. This is the escalation the recurrence demands.

## 6. Verification (how to confirm the fix)

- Add a throwaway manifest entry → run setup-user-hooks → assert it deploys + registers with zero other code changes; remove it → assert reconcile deregisters it.
- `block-explore-agent` registers via the generator with no hardcoding.
- check-post-push step 32 parity passes (bash + ps1 + manifest agree by construction).
- Re-run on a settings.json with a stale hook → assert it's removed.

## 7. Dissemination

- File this as an **incident** (`/incident`) — spec deviation: manifest declared "single source of truth" but consumed audit-only.
- Update **issue #7** check-box "Hooks-manifest as the generator" → in progress / link this investigation.
- RELEASE_NOTES entry on implementation.

## 8. Follow-up

- After shipping: next 3 hook changes must require **only** a manifest edit. If any still needs a code edit, the refactor was incomplete → re-investigate.

---

## Bottom line

The recurring hook issue **can** be solved permanently, and the fix is already specified (issue #7 / plan §5): **hooks-manifest.json must generate the deploy + registration + validation, not merely be audited against them.** Every prior fix was detection or point-remediation; the 7× recurrence is the proof those were the wrong layer. The structural fix also delivers `block-explore-agent` as its first dogfood, with no hardcoding.
