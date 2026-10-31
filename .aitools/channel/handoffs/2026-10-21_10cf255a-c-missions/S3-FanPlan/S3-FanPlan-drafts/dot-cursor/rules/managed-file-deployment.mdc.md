# Draft: .cursor/rules/managed-file-deployment.mdc (protected) -- S3-FanPlan-Planner, awaiting commander approval

Base: the text PR #101 (`docs/m3-approved-drafts`) writes. Twin of the
`.claude/rules/managed-file-deployment.md` draft. Apply verbatim.

## Edit 1 -- "### Content sources" table: add the deploy-harness row (the `.md` has it, the `.mdc` does not; S3-FanPlan-Checks C13)

OLD:

```
| aitools repo (`shared/`) | Fallback | claude-shared.md template, hook scripts, skills, shell aliases |
```

NEW:

```
| aitools repo (`shared/`) | Fallback | claude-shared.md template, hook scripts, skills, shell aliases |
| aitools repo + dotprofile -> `~/.aitools/` (`deploy-harness`) | First source wins on a name conflict: `shared/`, then `.claude/`, then dotprofile `claude/rules/` | reference, registries, hooks, skills, rules (one flat directory), bin; config.json generated from profile.json. Rules reach the tools through the `setup-user-claude` / `setup-user-cursor` fan-out. Detail: `@reference/harness.md` "Deployed harness (`~/.aitools`)" |
```

## Edit 2 -- the "Rules" bullet

OLD:

```
- **Rules**: additive deploy from `<userRepoPath>/claude/rules/` — managed files updated, unmanaged files in target preserved
```

NEW:

```
- **Rules**: deploy-harness collects `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/` into `~/.aitools/rules/` (first source wins) and writes `~/.aitools/rules/.aitools-rules-manifest` (each rule's source, or `retired`). The fan-out consumers copy from there: `setup-user-claude` takes every rule except the retired ones into `~/.claude/rules/` (adopt target: the rule's source file, when it is on the machine), `setup-user-cursor` the user-level ones into `~/.cursor/rules/`. Both update managed files, preserve unmanaged files, and back up and remove their own copy of a retired rule. Detail: `@reference/harness.md` "Rules manifest and retired rules"
```

## Edit 3 -- "### Shared requirements (all types)", item 4 (one line)

OLD:

```
4. **Outcome tracking**: every deployment must resolve to created, updated, or unchanged — and report via `write_summary`. `deploy_managed_file` results (created, updated, verified, accept & adopt, skipped, failed) are recorded with the deploy tracker; `failed` is an ERROR row and the run continues with the next file.
```

NEW:

```
4. **Outcome tracking**: every deployment must resolve to created, updated, or unchanged — and report via `write_summary`. `deploy_managed_file` results (created, updated, verified, accept & adopt, skipped, failed) are recorded with the deploy tracker; `failed` is an ERROR row and the run continues with the next file. A fan-out consumer that backs up and deletes its copy of a retired rule records `removed`; an outcome the tracker does not know is logged and counted as `failed`.
```

## Edit 4 -- "### Content sources" table, the dotprofile row (review non-blocking 4)

OLD:

```
| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, user rules, profile.json (preferences, identity, machine profiles) |
```

NEW:

```
| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, profile.json (preferences, identity, machine profiles); user rules too, but through `~/.aitools` (row below), where `shared/` and `.claude/` rules win a name conflict |
```

## Note

Draft file name ends in `.mdc.md` (the draft is Markdown); the target is
`.cursor/rules/managed-file-deployment.mdc`.
