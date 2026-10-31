# Draft: .claude/rules/deploy-paths.md (protected) -- S3-FanPlan-Planner, awaiting commander approval

Base: the text PR #99 (`docs/harness-approved-drafts`) writes. Main's current
text (before #99) is already stale for setup-user-claude (S3-FanPlan-Claude
INCIDENT 1: it still lists it as duplicated); merge #99 first, then apply these
three edits verbatim. Lands with or after the plan's Batch C (build-deploy no
longer embeds dotprofile rules into setup-user-claude).

## Edit 1 -- "### MDM run order", first paragraph

OLD:

```
`deploy/deploy-harness.sh/.ps1` runs first: it fills `~/.aitools` (rules,
reference, registries, hooks, skills, bin, config.json), and the rules fan-out
in `setup-user-cursor` (and `setup-user-claude` once it fans out) reads
`~/.aitools/rules`. Run in the other order, the fan-out step reports
`n/a (no harness rules)` and deploys nothing.
```

NEW:

```
`deploy/deploy-harness.sh/.ps1` runs first: it fills `~/.aitools` (rules,
reference, registries, hooks, skills, bin, config.json), and the rules fan-outs
in `setup-user-claude` and `setup-user-cursor` read `~/.aitools/rules` (the
only way the dotprofile's `claude/rules` reaches an endpoint). Run in the
other order, the fan-out steps report `n/a (no harness rules)` and deploy no
rules.
```

## Edit 2 -- "### Scripts with deploy templates", the setup-user-claude pure-extract bullet

OLD:

```
- `setup-user-claude.sh/.ps1` (M3 B5): template interpolation, footer, managed-file
  deploy and rules logic are extracted from `scripts/`. `build-deploy.sh` adds only
  the profile/template source block (the live dotprofile on the machine wins, else
  the embedded build-time copies) and the rules fallback.
```

NEW:

```
- `setup-user-claude.sh/.ps1` (M3 B5): template interpolation, footer, managed-file
  deploy and the rules fan-out are extracted from `scripts/`. `build-deploy.sh` adds
  only the profile/template source block (the live dotprofile on the machine wins,
  else the embedded build-time copies); no rules are embedded.
```

## Edit 3 -- "What IS auto-embedded": remove one bullet

OLD (delete this line; the `deploy-harness` bullet below it already lists
`<userRepoPath>/claude/rules`):

```
- `<userRepoPath>/claude/rules/*.md` → read at build time (the fallback rules)
```

NEW: (nothing)

## Why

Commander decisions 2026-10-22 (setup-user-claude fans out `~/.aitools/rules`,
stops deploying dotprofile rules directly; build-deploy MDM counterpart).
Plan: `plans/rules-fanout-claude.md` Batches B and C. Twin:
`.cursor/rules/deploy-paths.mdc` (draft beside this one).
