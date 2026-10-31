# Draft: .claude/rules/config-file-safety.md (protected) -- S3-FanPlan-Planner, awaiting commander approval

Base: main. One edit in "### Directory deployment (additive pattern)". Apply
verbatim. The `.cursor/rules/config-file-safety.mdc` twin has no rules example
and no step list for directories (S3-FanPlan-Checks C15): no twin edit.

OLD:

```
1. Declare managed scope in script header (e.g., `# Managed: ~/.claude/rules/*.md
   matching <userRepoPath>/claude/rules/`)
2. Back up target directory (see "Backup before overwrite")
3. For each source file: compare with target, add new, update changed (with diff
   logging), skip unchanged
4. Preserve unmanaged files (in target but not in source), log each
```

NEW:

```
1. Declare managed scope in script header (e.g., `# Managed: ~/.claude/rules/*.md
   fanned out from ~/.aitools/rules`)
2. Back up target directory (see "Backup before overwrite")
3. For each source file: compare with target, add new, update changed (with diff
   logging), skip unchanged
4. Preserve unmanaged files (in target but not in source), log each. One
   exception: a file the source retires (a `retired` line in the rules
   manifest) is backed up and removed when it is the script's own copy (its
   content matches a source copy); any other file of that name is kept with a
   warning
```

## Why

The example names the old rules source (setup-user-claude no longer reads
`<userRepoPath>/claude/rules/`), and the additive pattern now has the
retired-rule exception (PR #100 consumer contract; plan Batch B).
