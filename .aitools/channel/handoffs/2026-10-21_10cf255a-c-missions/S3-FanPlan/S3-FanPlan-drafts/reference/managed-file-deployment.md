# Draft: reference/managed-file-deployment.md (protected) -- S3-FanPlan-Planner, awaiting commander approval

Base: main. PR #100's S3-H2-Manifest draft rewrites the "User rules" content
source row (Edit 3 supersedes that row). Five edits. Apply after the plan's
Batch A (tracker) and Batch B (fan-out).

## Edit 1 -- "## Functions" table, the two tracker rows

OLD:

```
| `Record-DeployOutcome` | `deploy_tracker_record` | Count one outcome (including `failed`) and write its DETAIL row |
| `Write-DeployTrackerSummary` | `deploy_tracker_summary` | Write the loop's summary row (ERROR when any file failed) |
```

NEW:

```
| `Record-DeployOutcome` | `deploy_tracker_record` | Count one outcome (including `failed`, and `removed` for a deployed copy a fan-out consumer backed up and deleted) and write its DETAIL row; an unknown outcome is logged with `log_error` and counted as `failed` |
| `Write-DeployTrackerSummary` | `deploy_tracker_summary` | Write the loop's summary row (ERROR when any file failed): `N added, N updated, N accepted, N removed, N verified, N failed` |
| `Read-RulesManifest` | `read_rules_manifest` | Read `~/.aitools/rules/.aitools-rules-manifest` (v1): each rule's source or `retired`; invalid lines reported, not fatal |
| `Get-RuleNameKind` | `rule_name_kind` | Classify a name in `~/.aitools/rules`, case-insensitively: `hidden`, `backup` (`*.bak.*`), `rule` (`*.md`), `other` |
```

## Edit 2 -- "## Caller Responsibilities", the dotprofile bullet

OLD:

```
  repo is committed and pushed to the dotprofile's main automatically, as
  `setup-user-claude` does today for adopted and merged rules (kept). An
```

NEW:

```
  repo is committed and pushed to the dotprofile's main automatically (the
  library does it, `dotprofile_commit_push`; PR #103). An
```

## Edit 3 -- "## Content Sources" table, the "User rules" row

OLD:

```
| User rules | `<userRepoPath>/claude/rules/*.md` | (none — no rules deployed) |
```

NEW:

```
| User rules | `~/.aitools/rules/*.md` (deploy-harness fills it from `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/`, first source wins); setup-user-claude takes every non-retired rule | (none — `~/.aitools/rules` absent: no rules deployed, target untouched) |
```

## Edit 4 -- "### Markdown files", **Content source** and **Adopt target**

OLD:

```
**Content source**: CLAUDE.md and rules from dotprofile repo (primary) or
`shared/claude-shared.md` (fallback). Skills from `shared/skills/`, or the
```

NEW:

```
**Content source**: CLAUDE.md from dotprofile repo (primary) or
`shared/claude-shared.md` (fallback); rules from `~/.aitools/rules/` (the
fan-out, "User Rules Deployment" in `@reference/user-repo.md`). Skills from `shared/skills/`, or the
```

OLD:

```
**Adopt target**: the file the content was read from (dotprofile or
`shared/`). Adopting into `shared/claude-shared.md` (a protected file) is
```

NEW:

```
**Adopt target**: the file the content was read from (dotprofile or
`shared/`); for a rule, the source file the rules manifest names (none
without a manifest). Adopting into `shared/claude-shared.md` (a protected file) is
```

## Edit 5 -- "## Caller Responsibilities", return-value table: add the tracker-only outcome under it

OLD:

```
| `failed` | No (library restored and logged) | Record (summary ERROR) |
```

NEW:

```
| `failed` | No (library restored and logged) | Record (summary ERROR) |

`removed` is not a `deploy_managed_file` value: a fan-out consumer records it
itself after it backed up (`backup_file`, result checked) and deleted its own
copy of a retired rule.
```

## Why

Plan `plans/rules-fanout-claude.md` Batches A and B. Spec drift noticed and NOT
fixed here (S3-FanPlan-Lib INCIDENT 1): "Signatures" documents `ADOPT_TRANSFORM`
/ `-AdoptTransform` while the code takes `ADOPT_FILTER` / `-AdoptFilter`.
