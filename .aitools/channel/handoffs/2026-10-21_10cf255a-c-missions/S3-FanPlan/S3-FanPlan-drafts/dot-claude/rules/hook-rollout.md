# Draft: .claude/rules/hook-rollout.md (protected) -- S3-FanPlan-Planner, awaiting commander approval

Base: main (lines 109-112). Apply verbatim once the plan's Batch B has merged
(and #106, which runs deploy-harness). Source: S3-FanPlan-Ref R1.

OLD:

```
The hook lifecycle beyond rollout (source, deploy, adopt, user-created hooks,
retirement) is governed by the user-level rule `@shared/rules/hook-lifecycle.md`
(deployed to `~/.claude/rules/hook-lifecycle.md` once a deploy path for
`shared/rules/` exists).
```

NEW:

```
The hook lifecycle beyond rollout (source, deploy, adopt, user-created hooks,
retirement) is governed by the user-level rule `@shared/rules/hook-lifecycle.md`
(deployed to `~/.aitools/rules/` by `deploy-harness` and fanned out to
`~/.claude/rules/hook-lifecycle.md` by `setup-user-claude`).
```
