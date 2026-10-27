# Draft: .claude/rules/managed-file-deployment.md (protected) -- S3-H2-Manifest, awaiting approval

One edit, in "### Content sources". Apply verbatim.

OLD:

```
- **Rules**: additive deploy from `<userRepoPath>/claude/rules/` — managed files updated, unmanaged files in target preserved
```

NEW:

```
- **Rules**: deploy-harness collects `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/` into `~/.aitools/rules/` (first source wins) and writes `~/.aitools/rules/.aitools-rules-manifest` (each rule's source, or `retired`); the fan-out consumers update managed files, preserve unmanaged files, and back up and remove the copies of retired rules. Detail: `@reference/harness.md` "Rules manifest and retired rules"
```

## Why

HARNESS Q2 (approved). The current bullet predates deploy-harness and says
nothing is ever removed; with the manifest, retired rules are backed up and
removed (deploy-harness now; the consumers in S3-H2-Claude / S3-H2-Cursor).
