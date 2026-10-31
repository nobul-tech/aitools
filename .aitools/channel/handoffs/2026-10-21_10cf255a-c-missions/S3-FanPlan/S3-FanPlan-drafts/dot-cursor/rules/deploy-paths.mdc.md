# Draft: .cursor/rules/deploy-paths.mdc (protected) -- S3-FanPlan-Planner, awaiting commander approval

Base: the text PR #99 writes. Twin of the `.claude/rules/deploy-paths.md`
draft; the `.mdc` keeps one paragraph per line. Apply verbatim.

## Edit 1 -- "### MDM run order", first paragraph (one line)

OLD:

```
`deploy/deploy-harness.sh/.ps1` runs first: it fills `~/.aitools` (rules, reference, registries, hooks, skills, bin, config.json), and the rules fan-out in `setup-user-cursor` (and `setup-user-claude` once it fans out) reads `~/.aitools/rules`. Run in the other order, the fan-out step reports `n/a (no harness rules)` and deploys nothing.
```

NEW:

```
`deploy/deploy-harness.sh/.ps1` runs first: it fills `~/.aitools` (rules, reference, registries, hooks, skills, bin, config.json), and the rules fan-outs in `setup-user-claude` and `setup-user-cursor` read `~/.aitools/rules` (the only way the dotprofile's `claude/rules` reaches an endpoint). Run in the other order, the fan-out steps report `n/a (no harness rules)` and deploy no rules.
```

## Edit 2 -- the setup-user-claude pure-extract bullet (one line)

OLD:

```
- `setup-user-claude.sh/.ps1` (M3 B5): template interpolation, footer, managed-file deploy and rules logic are extracted from `scripts/`. `build-deploy.sh` adds only the profile/template source block (the live dotprofile on the machine wins, else the embedded build-time copies) and the rules fallback.
```

NEW:

```
- `setup-user-claude.sh/.ps1` (M3 B5): template interpolation, footer, managed-file deploy and the rules fan-out are extracted from `scripts/`. `build-deploy.sh` adds only the profile/template source block (the live dotprofile on the machine wins, else the embedded build-time copies); no rules are embedded.
```

## Edit 3 -- "What IS auto-embedded": remove one bullet

OLD (delete):

```
- `<userRepoPath>/claude/rules/*.md` → read at build time (the fallback rules)
```

NEW: (nothing)

## Note

The file name of this draft ends in `.mdc.md` so the draft itself is Markdown;
the target is `.cursor/rules/deploy-paths.mdc`. Other drift between the two
twins (the `.mdc`'s "Verify via pre-commit steps 3+10" and its MDM path
`deploy/`, S3-FanPlan-Checks INCIDENT I-3) is outside this plan.
