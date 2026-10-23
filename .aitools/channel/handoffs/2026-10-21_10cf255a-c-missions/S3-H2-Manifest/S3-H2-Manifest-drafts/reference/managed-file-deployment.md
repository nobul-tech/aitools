# Draft: reference/managed-file-deployment.md (protected) -- S3-H2-Manifest, awaiting approval

Two edits. Apply verbatim.

## Edit 1 -- "## Content Sources" table, the "User rules" row

OLD:

```
| User rules | `<userRepoPath>/claude/rules/*.md` | (none — no rules deployed) |
```

NEW:

```
| User rules | `<userRepoPath>/claude/rules/*.md`, collected with `shared/rules/` and `.claude/rules/` into `~/.aitools/rules/` by deploy-harness (first source wins) | (none — no dotprofile rules deployed) |
```

## Edit 2 -- "### Script-owned JSON (no review)": add a paragraph after the table

NEW (after the table that ends with the `JSON deployed via deploy_managed_file` row):

```
**Script-owned text: the rules manifest.** deploy-harness writes
`~/.aitools/rules/.aitools-rules-manifest` on every run without review
(it is the file's sole owner; temp file then move; a failure is
`log_error` + an ERROR row). It is not deployed through
`deploy_managed_file`: it is generated, not copied from a source. It
lists each rule's source or `retired`; retired rules are backed up and
removed by deploy-harness and by the fan-out consumers. Format and rules:
`@reference/harness.md` "Rules manifest and retired rules".
```

## Why

HARNESS Q2 (approved). The deployment spec should name the one file in
`~/.aitools` that is not written through `deploy_managed_file`, and the one
case where a deployed file is removed.
