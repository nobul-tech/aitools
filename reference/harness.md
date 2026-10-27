# Harness

The harness is aitools and the tools, context, state, artifacts,
frameworks, and provenance it manages for aitools users working on
any project on any platform, including aitools developers who are
themselves users working on both aitools and other projects.

**Intent**: **Purpose**: Define the harness, its components, and how
they relate. **Scope**: Architecture and component definitions only.
NOT artifact roles — what each artifact type is for and what it must
not contain (see `/artifact-roles` skill). NOT how to adopt new
frameworks (`@reference/framework-adoption.md`). NOT operational
guides for any specific component (see implementing artifacts).
**Audience**: Any agent working within the harness, framework
adoption work, `/audit` skill.

## Components

**Environment** — the agent runtime the harness runs in (Claude Code
locally on a platform, or a hosted service such as Claude Code web or
Cursor cloud; supported list: `@reference/cross-platform-detail.md`
"Supported platforms and environments")
provides the infrastructure: CLAUDE.md
(5-level hierarchy), rules, skills, hooks, settings, commands, agents,
session management. Full capability set documented upstream. Our
reference files track what we depend on and what's available but not
yet adopted (`@reference/tool-ops-claude-code.md`).

**Configuration** — our use of the platform. The rules we write,
skills we build, hooks we configure, claude content we author,
settings we set. Exists at two deployment scopes:
- Project (`.claude/rules/`, `.claude/skills/`, `.claude/commands/`,
  project claude) — conventions for this repo
- User (`~/.claude/rules/`, `~/.claude/skills/`, `~/.claude/hooks/`,
  user claude, user settings) — preferences and governance that
  follow the developer across all projects

aitools' own project rules and skills are also deployed at user scope
(commander, 2026-10-26: `@reference/rules.md` R-4, `@reference/skills.md`
S-1), so they load in every repo on the machine; inside aitools they exist
at both scopes until the project copies are removed.

**Orchestration** — aitools manages the full lifecycle of harness
content: authoring, building, deploying, and maintaining configuration
across machines and users. This includes:
- Sourcing harness context from `shared/` (templates, hooks, skills,
  shell aliases) and dotprofile repos (`@reference/user-repo.md`)
- Resolving priority between shared templates and user customizations
  (dotprofile wins; shared is fallback and MDM source)
- Interactive deployment review with adoption/merge logic
  (`@reference/managed-file-deployment.md`)
- Build pipeline generating self-contained deploy scripts
  (`@.claude/rules/git-safety.md`)
- Package build generating installable packages for a fleet (the
  package path, `build-package`: Windows `.intunewin`, macOS `.pkg`,
  Linux `.deb`), a distribution parallel to the dev and MDM paths that
  runs the same `scripts/` from a payload of the aitools tree
  (`@plans/build-package/design.md`)
- Setup scripts, shared libraries, entry points, verification
  checklists, AI-assisted operations, incident tracking (via
  `/incident` skill), plans, and reference files

See `@CLAUDE.md` for the full project description.

**Managed tools** — CLI tools, dependencies, and build tools governed
by `/tool-registry` skill. Each gets setup scripts, platform lifecycle
tracking, and operational metadata (via `/tool-ops` skill). Standing
orders and hooks enforce tool selection. See
`@.claude/rules/tool-lifecycle.md` for the onboarding process.

**Frameworks** — governance structures built by adopting concepts from
established disciplines. Each bridges a discipline and the harness
artifacts that implement it. Discipline → framework → artifacts. A gap
in a framework means an entire class of decisions has no governing
structure. A gap in an artifact means the framework exists but a
specific implementation is missing or broken. The framework registry
is governed by `/frameworks` skill. Individual framework documentation
lives in `reference/framework-*.md` files. See
`@.claude/rules/frameworks.md` for the rule.

**Provenance** — every piece of operational learning, every decision,
every work product has provenance: what it was based on, when, by whom,
and whether the basis has been superseded. The provenance component
tracks dependency chains between knowledge items, propagates
invalidation when assumptions are falsified, records known
contradictions (nogood sets) to prevent rediscovery of dead ends, and
maintains temporal validity windows so stale knowledge is surfaced
before it causes harm. Provenance is not a feature layered on top of
the other five components — it is the connective tissue that makes
the harness a knowledge system rather than a configuration manager.
See `@reference/framework-provenance.md` for the discipline source
and adoption rationale.

## How the Components Relate

The six components form a dependency chain:

```
Environment (external, e.g. Claude Code)
    -> Configuration (our use of the platform)
        -> Orchestration (manages configuration lifecycle)
            -> Managed Tools (governed by orchestration)
            -> Frameworks (governing structures for decisions)
            -> Provenance (tracks what everything is based on)
```

Provenance cuts across the other components: it tracks the basis for
configuration decisions, the history of orchestration changes, the
evaluation chain for tool selections, and the adoption rationale for
frameworks. It is both a component (with its own tables, schema, and
processing) and a cross-cutting concern (every other component
produces provenance data).

## Deployed harness (`~/.aitools`)

`scripts/deploy-harness.sh` / `.ps1` builds the deployed harness in
`~/.aitools` (Windows `%USERPROFILE%\.aitools`) from the repos. Every
file goes through `deploy_managed_file()` in `@scripts/aitools-lib.sh` /
`Deploy-ManagedFile` in `@scripts/aitools-lib.ps1`, with the summary tool
name `harness files` and the repo file it came from as the adopt target.
`config.json` is generated from `profile.json` by calling the only config
writer, `scripts/setup-user-config.sh` / `.ps1`.

| Deployed to | Sources, in order | Layout | Conflict unit |
|-------------|-------------------|--------|---------------|
| `reference/` | `reference/` | tree (relative paths kept) | none (one source) |
| `registries/` | `registries/` | tree | none (one source) |
| `hooks/` | `shared/hooks/`, `.claude/hooks/` | flat (top-level files) | file name |
| `skills/` | `shared/skills/`, `.claude/skills/`, `<dotprofile>/claude/skills/` | one directory per skill | skill directory name |
| `rules/` | `shared/rules/`, `.claude/rules/`, `<dotprofile>/claude/rules/` | flat (top-level `*.md`) | file name |
| `bin/` | `scripts/harness-db.py`, `read-session.py`, `read-session-full.py` | flat | none (fixed list) |

### Conflict handling

- **First source wins.** Sources are read in the order above. The first
  source that has a unit (a file name for rules and hooks, a directory
  name for skills) deploys it; the same unit in a later source is
  skipped.
- **Each skipped duplicate is an error**: `log_error` naming both
  sources, plus one ERROR row under `harness files`. The run continues
  and exits 1. The duplicate stays an error on every run until it is
  renamed or removed in one of the sources.
- **Case-insensitive.** Names that differ only in case are duplicates
  (the macOS and Windows file systems are case-insensitive).
- **Skills are whole directories.** The winning source's skill directory
  is deployed as it is; files are never merged from two sources.

### Assumptions and what is not detected

- **Git-tracked files only**, in every source (`git ls-files`). Untracked
  and ignored files, including the `*.bak.*` backups an adopt leaves in
  the repo, are never deployed. A source directory outside a git work
  tree is an error and is skipped. A missing source directory (for
  example `.claude/hooks/`) is logged as info.
- **`*.bak.*` names are never deployed**, even when tracked: that is the
  library's backup naming (`backup_file()`).
- **Nested files in a flat source** (rules, hooks), non-`.md` files in a
  rules source, and files outside a skill directory are skipped with a
  detail log line; they are not reported as conflicts. A skill directory
  whose name starts with `.` or contains `.bak.` is not deployed either
  (the skills manifest's name rule).
- **Order, not content, picks the winner.** Two copies with identical
  content are still a duplicate; a later copy is never preferred because
  it is newer.
- **Not detected**: the same content under two different names; a name
  shared across kinds (a skill and a rule both called `scratch`, which
  land in different directories); conflicts with files already in a
  tool's own location (`~/.claude/rules/`, `~/.cursor/rules/`,
  `~/.claude/skills/`, `~/.cursor/skills/`). The fan-outs in
  `setup-user-claude` and `setup-user-cursor` treat such a file or skill
  directory as theirs only when it matches a harness copy (Cursor rules:
  its fan-out marker or legacy content); they update or remove their own
  copies and preserve every other file, and never write into a skill
  entry that is a symlink or a plain file.
- **No deletion, except retired rules and skills.** A file in `~/.aitools`
  with no source (a renamed or removed source, a file the user added) is
  preserved and logged on every run. The exceptions are a rule the rules
  manifest retires and a skill directory the skills manifest retires (next
  sections): each is backed up and removed.
- **Backups live next to deployed files** (`<file>.bak.<timestamp>`, by
  the library). Anything that copies out of `~/.aitools` skips `*.bak.*`.
- **Trailing newlines are normalized**: a deployed copy ends with exactly
  one newline.
- **Adopt** writes the winning source file only. Adopting into a file in
  its repo's protected-files table (`@.claude/rules/sources-of-truth.md`)
  logs a WARN naming the file; the library never commits or pushes.

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
  never deletes the user rules. Listing is per kind: a listed dotprofile
  rules source does not count for dotprofile skills.
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
- **Consumers** (`setup-user-claude`, `setup-user-cursor`) take every
  non-retired rule (all three sources; without a manifest, every rule, and
  nothing is removed) and back up and remove their own deployed copy of
  every `retired` name. `setup-user-claude` uses the source to find the
  adopt target; Cursor offers no adopt. A consumer recognises its own copy
  of a retired rule by content (Claude Code: the same text as
  `~/.aitools/rules/<name>` or one of its `.bak.*` backups) or, for
  Cursor, by its fan-out marker or the legacy converted content; it
  removes it only after a backup with the same text is confirmed, and
  records the outcome `removed`. Any other file of that name is kept, with
  a warning and an ACTION row.
- **Not in the preserved report**: the manifests (and their temp files)
  are never logged as preserved files.
- **MDM path**: the generated `deploy/deploy-harness.*` runs the same
  code; its sources are the build-time snapshot, so a rule removed from
  the repos is retired on the endpoint at the first run of a deploy/
  built after the removal.

### Skills manifest and retired skills

deploy-harness writes `~/.aitools/skills/.aitools-skills-manifest` after the
deploy loop (sole owner; temp file then move), the same way as the rules
manifest; one planner and one writer serve both kinds
(`harness_manifest_plan` / `Get-HarnessManifestPlan`,
`write_harness_manifest` / `Write-HarnessManifest` in
`@scripts/deploy-harness.sh` / `.ps1`).

- **Format v1**: UTF-8, LF, no BOM, first line `# aitools skills manifest
  v1`, then `<skill name><TAB><source>` sorted by name (byte order).
  Source: `shared` (aitools `shared/skills/`), `aitools` (aitools
  `.claude/skills/`), `dotprofile` (`<dotprofile>/claude/skills/`) or
  `retired`. The name is the directory name as found on disk; a valid name
  has no `/` or `\`, does not start with `.` and has no `.bak.`. Invalid
  previous lines are warned and dropped.
- **Retiring.** As for rules, per kind. deploy-harness copies the skill
  directory itself, not through `backup_dir()` (`retire_skill_dir` in
  `@scripts/deploy-harness.sh`, `Remove-RetiredSkill` in
  `@scripts/deploy-harness.ps1`): `cp -R` to
  `~/.aitools/skills/<name>.bak.<UTC>/` beside it (any skill directory, no
  `*.md` precondition), `diff -r -q` against the directory, and only then
  `rm -rf` of the directory, checked gone; then the newest 5
  `<name>.bak.<UTC>` backups are kept (`prune_skill_backups`, names matched
  literally). A failed or unproven copy is removed again; when it cannot be
  removed it is renamed `<name>.bak.incomplete.<UTC>` (never counted by the
  prune; `.bak.` keeps it from being deployed or fanned out) with an ERROR
  row. Any failure is `log_error` + an ERROR row and the directory stays
  (the next run tries again). A file or symlink with a retired name is left
  alone with a warning. Dry run: logged only.
- **A skill that moves source** (e.g. from `.claude/skills/` to
  `shared/skills/`) changes its manifest source and is not retired.
- **The last dotprofile skill removed**: git drops the empty
  `claude/skills/`, the source is "not found", so its skills are kept, not
  retired (the same rule as dotprofile rules).
- **Preserved scan** ignores both manifests, their temp files and every
  path with a `*.bak.*` component (retired-skill backups).
- **Consumers**: the library's `fanout_harness_skills` /
  `Invoke-HarnessSkillsFanout`, called by `setup-user-claude` (`claude
  skills`) and `setup-user-cursor` (`cursor skills`). A consumer backs up
  its own copy of a retired skill to `<DEST>.bak.<UTC>/<name>/` beside its
  skills directory, not inside it (a backup inside would still load as a
  skill). Detail: `@reference/skills.md`.

## Cross-References

- Glossary definition: `/glossary` skill (term: harness)
- How the harness grows: `@reference/framework-adoption.md`
- Artifact roles: `/artifact-roles` skill
- Governed vocabulary: `@reference/framework-governed-vocabulary.md`
- Registry convention: `@reference/framework-three-layer-governance.md`
- Framework rule: `@.claude/rules/frameworks.md`
- Project description: `@CLAUDE.md`
- Provenance framework: `@reference/framework-provenance.md`
- Deployed harness: `@scripts/deploy-harness.sh` / `.ps1`;
  managed-file model: `@reference/managed-file-deployment.md`
- Rules, their scopes and the rules fan-out: `@reference/rules.md`
- Skills, their scopes and the skills fan-out: `@reference/skills.md`
- Skills: `/frameworks`, `/glossary`, `/audit`, `/intent-audit`, `/incident`
