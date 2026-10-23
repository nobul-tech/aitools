# Draft: reference/harness.md (protected) -- S3-H2-Manifest, awaiting approval

Two edits, both in "## Deployed harness (`~/.aitools`)". Apply verbatim.

## Edit 1 -- replace the "No deletion" bullet in "### Assumptions and what is not detected"

OLD:

```
- **No deletion.** A file in `~/.aitools` with no source (a renamed or
  removed source, a file the user added) is preserved and logged on
  every run.
```

NEW:

```
- **No deletion, except retired rules.** A file in `~/.aitools` with no
  source (a renamed or removed source, a file the user added) is
  preserved and logged on every run. The one exception is a rule the
  rules manifest retires (next section): it is backed up and removed.
```

## Edit 2 -- new subsection, inserted after "### Assumptions and what is not detected" (before "## Cross-References")

NEW:

```
### Rules manifest and retired rules

After the deploy loop, deploy-harness writes
`~/.aitools/rules/.aitools-rules-manifest` (it is the file's sole owner).
The rules fan-out consumers (`setup-user-claude`, `setup-user-cursor`)
read it to learn each rule's source and which rules to retire.

- **Format v1**: UTF-8, LF, first line `# aitools rules manifest v1`, then
  one line per rule, `<file name><TAB><source>`, sorted by file name
  (byte order). Source: `shared` (aitools `shared/rules/`), `aitools`
  (aitools `.claude/rules/`), `dotprofile` (`<dotprofile>/claude/rules/`),
  or `retired`. Only `*.md` names; never `*.bak.*`. The name has no
  `.md` extension, so a consumer that copies `*.md` never copies it.
- **The winning source is recorded** (first source wins; a skipped
  duplicate is still a `log_error` + ERROR row, as above).
- **Written every run**, temp file then move. A write failure is
  `log_error` + an ERROR row (`rules manifest not written`); the run
  continues and exits 1.
- **Retiring.** A name in the previous manifest that no source has this
  run (names compared case-insensitively) becomes `retired`; its copy in
  `~/.aitools/rules` is backed up (`backup_file()`) and removed, with an
  info log line and a DETAIL row `retired: rules/<name>`. The `retired`
  line stays in later manifests until a source has the name again; while
  it is retired, a file with that name found in `~/.aitools/rules` is
  backed up and removed on each run. A failed backup leaves the file in
  place (`log_error` + ERROR row).
- **Only a listed source retires.** A name whose source was not listed
  this run (directory not found, not a git work tree, `git ls-files`
  failed, or no dotprofile configured) keeps its previous line and its
  file; it is not retired. A temporarily missing dotprofile therefore
  never deletes the user rules.
- **First run** (no previous manifest): nothing is retired. A previous
  manifest whose first line is not the v1 header: a warning, nothing
  retired, and the manifest is rewritten. Invalid lines (not `*.md`, a
  `*.bak.*` name, a `/` or `\` in the name, an unknown source) are
  ignored with a warning.
- **Dry run** logs what would be retired and written; nothing changes.
- **Known limits.** A rule renamed only by case (`Foo.md` to `foo.md`) is
  the same rule, so the old name is not retired; on a case-sensitive file
  system (Linux) the old `Foo.md` stays in `~/.aitools/rules` as a
  preserved file. A rule that moves to a source that is not listed on
  that run is retired on that run and deployed again on the next run that
  lists its new source. Only a file (or a symlink) is removed, never a
  directory with a rule's name.
- **Consumers** take every non-retired name they are entitled to, and
  back up and remove their own deployed copy of every `retired` name.
  Cursor takes user-level rules only, so it also removes its copies of
  names whose source is `aitools`.
- **Not in the preserved report**: the manifest (and its temp file) are
  never logged as preserved files.
- **MDM path**: the generated `deploy/deploy-harness.*` runs the same
  code; its sources are the build-time snapshot, so a rule removed from
  the repos is retired on the endpoint at the first run of a deploy/
  built after the removal.
```

## Why

HARNESS Q2 (approved): a removed source rule stayed in `~/.aitools/rules`
and stayed loaded. PR: feature/harness-rules-manifest.
