# Draft: .claude/rules/managed-file-deployment.md (protected) -- S3-FanPlan-Planner, awaiting commander approval

Base: main's text, with PR #101's edits to the neighbouring bullets (#101
leaves the "Rules" line as context). PR #100's S3-H2-Manifest draft rewrites
the same "Rules" line; Edit 1 below supersedes it (it contains #100's text
plus the Claude/Cursor split). Apply verbatim.

## Edit 1 -- "### Content sources", the "Rules" bullet

OLD (main; if #100's draft was applied first, the OLD line is that draft's NEW
line instead -- replace it the same way):

```
- **Rules**: additive deploy from `<userRepoPath>/claude/rules/` — managed files updated, unmanaged files in target preserved
```

NEW:

```
- **Rules**: deploy-harness collects `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/` into `~/.aitools/rules/` (first source wins) and writes `~/.aitools/rules/.aitools-rules-manifest` (each rule's source, or `retired`). The fan-out consumers copy from there: `setup-user-claude` takes every rule except the retired ones into `~/.claude/rules/` (adopt target: the rule's source file, when it is on the machine), `setup-user-cursor` the user-level ones into `~/.cursor/rules/`. Both update managed files, preserve unmanaged files, and back up and remove their own copy of a retired rule. Detail: `@reference/harness.md` "Rules manifest and retired rules"
```

## Edit 2 -- "### Shared requirements (all types)", item 4

OLD:

```
4. **Outcome tracking**: every deployment must resolve to
   created, updated, or unchanged — and report via `write_summary`.
   `deploy_managed_file` results (created, updated, verified, accept &
   adopt, skipped, failed) are recorded with the deploy tracker; `failed`
   is an ERROR row and the run continues with the next file.
```

NEW:

```
4. **Outcome tracking**: every deployment must resolve to
   created, updated, or unchanged — and report via `write_summary`.
   `deploy_managed_file` results (created, updated, verified, accept &
   adopt, skipped, failed) are recorded with the deploy tracker; `failed`
   is an ERROR row and the run continues with the next file. A fan-out
   consumer that backs up and deletes its copy of a retired rule records
   `removed`; an outcome the tracker does not know is logged and counted
   as `failed`.
```

## Edit 3 -- "### Content sources" table, the dotprofile row (review non-blocking 4)

The row calls the dotprofile "Primary (wins if present)" for user rules, which
contradicts the deploy-harness row under it (first source wins: `shared/`,
then `.claude/`, then the dotprofile).

OLD:

```
| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, user rules, profile.json (preferences, identity, machine profiles) |
```

NEW:

```
| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, profile.json (preferences, identity, machine profiles); user rules too, but through `~/.aitools` (row below), where `shared/` and `.claude/` rules win a name conflict |
```

## Why

Plan `plans/rules-fanout-claude.md` Batches A and B (commander decisions
2026-10-22). The word `removed` is not yet a governed term (open question Q7:
file it through `/glossary` before this edit lands). Twin: the `.mdc` draft.
