# Hook Rollout

**Intent**: **Purpose**: Document the framework for safely deploying
detection hooks using graduated rollout. **Scope**: What release
engineering principles we adopted and why. NOT the operational
deployment steps or enforcement state table (those are in
`@.claude/rules/hook-rollout.md`). **Audience**: Agents building new
hooks, framework adoption work.

## Source Discipline

Release engineering — canary deployment and graduated rollout. Deploy
to a small scope first, verify behavior, then widen. Applied to hooks:
observe first, then enforce.

## How We Adopted It

- **Observe-then-enforce** → hooks deploy in observe mode (log but
  don't block), graduate to enforce after zero false positives
- **Per-check granularity** → each check within a hook has its own
  mode variable, allowing independent rollout
- **Pre-deploy verification** → syntax check + smoke test + violation
  test before any deployment
- **Reset to observe** → new patterns, logic changes, and CC version
  upgrades reset to observe for re-verification

## How It's Maintained

- Enforcement state table in `@.claude/rules/hook-rollout.md` tracks
  current mode per check
- Log review identifies false positives before promotion
- Mode promotion requires zero false positives in the log

## Implementing Artifacts

- `@.claude/rules/hook-rollout.md` (operational rule + state table)
- `@shared/hooks/standing-order-guard.sh` (primary hook using this)
- `~/.claude/hooks/logs/` (observation logs)

## Cross-References

- Framework registry: `@reference/framework-registry.json`
- Three-layer governance: `@reference/framework-three-layer-governance.md`
