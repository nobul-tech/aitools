# Artifact manifests

**Intent**: **Purpose**: Show, in ASCII diagrams, how each harness artifact
kind reaches a machine: how the three manifests (rules, skills, hooks) are
created, reconciled with the previous run and acted upon, and how the two
artifact kinds that have no manifest (reference files and registries) are
deployed and read, so an agent can predict what a run of `aitools` adds,
keeps and removes. **Scope**: Deployment life cycle and the consumers'
decisions only. NOT the managed-file review menu or its outcomes
(`@reference/managed-file-deployment.md`). NOT conflict rules and
file-level assumptions in full (`@reference/harness.md` "Deployed
harness"). NOT which rules and skills are written for which scope
(`@reference/rules.md`, `@reference/skills.md`). NOT a hook's behaviour or
its rollout (`.claude/rules/hook-rollout.md`). NOT registry contents or
how to change them (each registry's skill; `/frameworks` lists them).
**Audience**: Agents and maintainers changing `deploy-harness`, a fan-out
consumer (`setup-user-claude`, `setup-user-cursor`, `setup-user-skills`),
`setup-user-hooks`, a registry skill's "Where the files live" section or
`build-deploy.sh`, and anyone asking why a rule, skill, hook, reference
file or registry copy appeared in, stayed in or vanished from `~/.aitools`,
`~/.claude` or `~/.cursor`.

Version 1.1, 2026-11-07, Session Commander f500b663-7. A version, not a
draft (D-DEL5). Describes `main` at `ab3bc22` (PR #141: rules and skills
from `shared/` only, R-8 / S-7). v1.1: reference and registry artifacts
added (sections 1, 2, 6, 7, 8); commander order 2026-11-07 "update the md file
you just created to also include reference and registry artifacts".

## 1. The three manifests at a glance

```
                 RULES MANIFEST            SKILLS MANIFEST           HOOKS MANIFEST
                 --------------            ---------------           --------------
 file            ~/.aitools/rules/         ~/.aitools/skills/        <aitools>/shared/hooks/
                 .aitools-rules-manifest   .aitools-skills-manifest  hooks-manifest.json
 written by      deploy-harness            deploy-harness            a person (git commit)
                 (generated, every run)    (generated, every run)    (hand-authored)
 format          text, LF, v1 header,      text, LF, v1 header,      JSON: hooks[] = {file,
                 "<name><TAB><source>"     "<name><TAB><source>"     event, matcher},
                                                                     deploy[] = helper files
 records         which rules exist and     which skills exist and    which hooks exist and
                 where each came from;     where each came from;     how each is registered
                 which are retired         which are retired         in settings.json
 retirement      automatic (a "retired"    automatic (a "retired"    manual: STALE_HOOKS /
                 line)                     line)                     removeHookEntry lists
 read by         setup-user-claude,        fanout_harness_skills     setup-user-hooks,
                 setup-user-cursor         (claude + cursor),        build-deploy.sh,
                                           setup-user-skills         check-post-push (parity)
```

The rules and skills manifests are **state**: generated from what the
sources hold plus what the previous run recorded. The hooks manifest is
**spec**: a committed list, never written by a script.

Two more artifact kinds go through deploy-harness **with no manifest at
all**:

```
                 REFERENCE                            REGISTRIES
                 ---------                            ----------
 source          <aitools>/reference/**               <aitools>/registries/**
                 (Markdown, the detail behind         (the five governed JSON registries:
                  the rules)                           /tool-registry, /tool-ops,
                                                       /incident, /glossary, /frameworks)
 deployed to     ~/.aitools/reference/**              ~/.aitools/registries/**
                 (tree: relative paths kept)          (tree: relative paths kept)
 manifest        none                                 none (each registry describes itself
                                                       in its own "meta" section:
                                                       intent, governance, lastUpdated)
 retirement      none: a file removed from the        none: same as reference
                 repo stays as a "preserved" file
 read by         agents and skills, when there is     the registry skills, when there is
                 no aitools clone on the machine      no aitools clone on the machine
                 (section 6)                          (section 6); never edited there
```

## 2. Where they sit in an `aitools` run

```
 aitools  (deploy_configs, in this order; scripts/aitools, scripts/aitools.ps1)
   |
   |  1. deploy-harness ............ COPIES reference/ and registries/ (no manifest)
   |                                 WRITES rules manifest + skills manifest
   |                                  (also copies shared/hooks/* incl. the hooks
   |                                   manifest to ~/.aitools/hooks/ -- nothing
   |                                   reads that copy)
   |  2. setup-user-claude ......... READS rules manifest   -> ~/.claude/rules
   |                                 READS skills manifest  -> ~/.claude/skills
   |  3. setup-user-mcp
   |  4. setup-user-skills ......... READS skills manifest  (reverse discovery
   |                                  only; deploys nothing while
   |                                  ~/.aitools/skills exists)
   |  5. setup-cursor-ide-mcp
   |  6. setup-user-cursor ......... READS rules manifest   -> ~/.cursor/rules/*.mdc
   |                                 READS skills manifest  -> ~/.cursor/skills
   |  7. setup-user-settings
   |  8. setup-user-hooks .......... READS <aitools>/shared/hooks/hooks-manifest.json
   |                                  -> ~/.claude/hooks/ + settings.json "hooks"
   v
```

deploy-harness must run first: the consumers act on what it just wrote.
Run in another order, the rules fan-outs report `n/a (no harness rules)`
and the skills fan-outs leave the rows to `setup-user-skills` (the
fallback). MDM runs the generated `deploy/` copies in the same order
(`.claude/rules/deploy-paths.md` "MDM run order").

## 3. Rules and skills manifests: creation (deploy-harness)

One planner and one writer serve both kinds: `harness_manifest_plan` and
`write_harness_manifest` in `scripts/deploy-harness.sh`
(`Get-HarnessManifestPlan` / `Write-HarnessManifest` in the `.ps1`).

### 3.1 From sources to winners

```
  SOURCES (git-tracked files only)            PLAN (section 4)
  --------------------------------            ----------------
  <aitools>/shared/rules/*.md   --add_source--+
                                              |   unit = file name (rules)
  <aitools>/shared/skills/<n>/** --add_source-+-> unit = directory name (skills)
                                              |   *.bak.*, hidden, nested-in-flat:
  (hooks: shared/hooks, then .claude/hooks;   |   skipped
   not part of either manifest)               |   same unit twice (case-insensitive):
                                              |   first source wins, ERROR row
                                              v
                                      SEEN = winners   LISTED = sources that
                                      (kind, name,     were actually read this
                                       source label)   run (dir found, git work
                                                       tree, ls-files ok)
                                              |
                     each winner is deployed  |  deploy_managed_file per file
                     into ~/.aitools/<kind>/  |  (section 5)
                                              v
                                      manifest planning (3.2)
```

Since R-8 / S-7 (2026-11-06) the only rules source is `shared/rules` and
the only skills source is `shared/skills`. Source labels map to manifest
sources: `shared/rules`, `shared/skills` -> `shared`.

### 3.2 Reconciling with the previous manifest

```
  NEW MANIFEST starts as:  every winner  ->  "<name><TAB>shared"

  PREVIOUS MANIFEST (~/.aitools/<kind>/.aitools-<kind>-manifest)
     |
     +-- absent (first run) ...................... nothing retired
     |
     +-- first line != "# aitools <kind> manifest v1"
     |       ...................................... WARN, nothing retired,
     |                                              manifest rewritten
     |
     +-- for each line "<name><TAB><source>":
            |
            +-- invalid (bad name, *.bak.*, / or \, unknown source)
            |       ............................... WARN "line ignored", dropped
            |
            +-- a winner has this name (case-insensitive)
            |       ............................... the winner's line stands
            |
            +-- source = retired
            |       ............................... stays "retired"   [stale]
            |                                       (a file of that name found
            |                                        again is removed again)
            |
            +-- source = aitools | dotprofile  (WITHDRAWN, R-8 / S-7)
            |       ............................... becomes "retired" [retire]
            |
            +-- source listed this run (e.g. shared/rules was read)
            |       ............................... becomes "retired" [retire]
            |
            +-- source NOT listed this run (dir missing, not git, ls-files failed)
                    ............................... line kept as is  [keep]
                                                    (a missing source never
                                                     deletes anything)
```

Then, per action:

```
  [retire] / [stale]            RULES                          SKILLS
  ------------------            -----                          ------
  ~/.aitools/<kind>/<name>      backup_file -> <name>.bak.TS   cp -R -> <name>.bak.<UTC>/
  exists?                       then rm                        diff -r -q (verified)
                                                               then rm -rf; keep newest 5
                                failure: ERROR row, file kept  failure: ERROR row, dir kept,
                                (next run retries)             half copy removed (or renamed
                                                               <name>.bak.incomplete.<UTC>)
  [retire] only                 DETAIL row "retired: rules/<name>" / "retired: skills/<name>"

  finally   new manifest  ->  <manifest>.tmp  ->  mv  ->  <manifest>
            (dry run: logged, nothing written; a directory at the path: ERROR row)
```

The backups matter downstream: after a retirement the harness copy is gone,
and the consumers recognise their own copy by comparing it with the
backup (section 4).

### 3.3 Format (v1, both kinds)

```
  # aitools rules manifest v1          # aitools skills manifest v1
  scratch.md<TAB>shared                delegate<TAB>shared
  sources-of-truth.md<TAB>retired      governed-data<TAB>retired
  web-sources.md<TAB>shared            tool-eval<TAB>shared

  UTF-8, LF, no BOM; sorted by name (byte order)
  written:  shared | retired
  accepted when read: shared | aitools | dotprofile | retired
           (aitools / dotprofile only appear in manifests from before 2026-11-06)
  rules names: *.md (any case), no / or \, no .bak.
  skill names: no leading ".", no / or \, no .bak.
  no .md extension on the rules manifest, so consumers that copy *.md skip it
```

## 4. Rules and skills manifests: acted upon (the fan-outs)

All consumers read the manifest through `read_harness_manifest` /
`Read-HarnessManifest` in `scripts/aitools-lib.sh` / `.ps1`, which prints
`rule<TAB><name><TAB><source>` per valid line, `invalid<TAB>...` per bad
line, or `header-bad`.

### 4.1 How a consumer reads the manifest

```
  ~/.aitools/<kind>/ missing ............ rules: OK "<tool> rules" n/a (no harness rules)
                                          skills: info log, no row (fallback owns it)
  manifest missing ...................... every entry fanned out, none retired,
                                          adopt not offered
  manifest unreadable ................... ERROR row, every entry fanned out,
                                          none retired
  header-bad ............................ WARN + ACTION "Run aitools to rebuild ...",
                                          every entry fanned out, none retired
  ok:
     "rule <name> retired" .............. name goes to RETIRED (prune candidate)
     "rule <name> <source>" ............. name -> source (used for the adopt target)
     "invalid ..." ...................... WARN "line ignored"
```

### 4.2 Fan out, then prune

```
            ~/.aitools/rules/*.md                     ~/.aitools/skills/<name>/**
                    |                                           |
     +--------------+---------------+            +--------------+---------------+
     |                              |            |                              |
 setup-user-claude          setup-user-cursor   fanout_harness_skills   fanout_harness_skills
 "claude rules"             "cursor rules"      "claude skills"          "cursor skills"
     |                              |            |                              |
     v                              v            v                              v
 ~/.claude/rules/<name>.md  ~/.cursor/rules/    ~/.claude/skills/<name>/  ~/.cursor/skills/<name>/
                            <name>.mdc
                            (converted, with
                             fan-out marker)

 FAN OUT: every entry NOT retired, through deploy_managed_file (review menu
          when the deployed copy differs; non-interactive / --force: overwrite)
          adopt target from the manifest source:
             shared -> <aitools checkout>/shared/<kind>/<name>  (Claude only, and only
                       when run from a git checkout; Cursor never offers adopt)
          skills: a DEST/<name> that is a symlink or a plain file is never written
                  (WARN + ACTION); directories the fan-out did not deploy are preserved

 PRUNE:   every RETIRED name whose copy is found in the tool's directory
          (names compared case-insensitively)
```

### 4.3 The prune decision: is this copy ours?

```
  RETIRED name found in the tool's directory
     |
     v
  does the copy match a harness copy?
     rules  (claude):  same text as ~/.aitools/rules/<name> or <name>.bak.*
                       (fanout_text_equal; trailing CR/LF ignored)
     rules  (cursor):  carries the aitools-fanout marker line, or equals the
                       conversion of the harness copy or of a backup (pre-marker files)
     skills (both):    every file matches ~/.aitools/skills/<name>/ or <name>.bak.*/
                       (fanout_dir_matches; OS junk like .DS_Store ignored;
                        any symlink or special file inside = not ours)
     |
     +-- yes --> back up, verify the backup, then remove      tracker outcome "removed"
     |             rules : <file>.bak.<TS> beside it (same text confirmed)
     |             skills: <DEST>.bak.<UTC>/<name>/ BESIDE the skills directory
     |                     (inside it, the tool would load the backup as a skill);
     |                     newest 5 kept
     |
     +-- no ---> kept; WARN + one ACTION row
                 "<Tool> still loads retired rules|skills in <dir>: <names>
                  -- delete them unless you wrote them"
```

### 4.4 setup-user-skills (fallback and reverse discovery)

```
  ~/.aitools/skills exists?
     |
     +-- yes --> OK "skills" n/a (fanned out); deploys nothing.
     |           Reverse discovery: a directory in ~/.claude/skills is "user-created"
     |           (offered for adoption into the dotprofile) only if its name is in
     |           NEITHER ~/.aitools/skills NOR the skills manifest (any source,
     |           retired included). Manifest unreadable -> ERROR, discovery not run,
     |           so a harness skill is never mistaken for a user's own.
     |
     +-- no ---> fallback: deploys SKILL.md files from shared/skills and the
                 dotprofile claude/skills (dotprofile wins a name clash); owns the
                 "claude skills" / "cursor skills" rows
```

## 5. Hooks manifest: spec, not state

```
  <aitools>/shared/hooks/hooks-manifest.json   (committed by a person)
     |   hooks[]:  { file, event, matcher }   one registration each
     |   deploy[]: helper files copied but not registered
     |             (intelligence-stop.py, ait-harvest.py)
     |
     +--> setup-user-hooks.sh / .ps1   (dev path; reads the REPO copy)
     |       1. file list = hooks[].file + deploy[]
     |          source: shared/hooks/<file>, else scripts/<file>
     |          every file must exist before any is deployed (else ERROR, exit 1)
     |       2. deploy_managed_file each -> ~/.claude/hooks/<file>   (chmod +x)
     |          adopt target: the shared/hooks (or scripts/) file, never the dotprofile
     |          a dotprofile copy of a manifest hook: ignored, WARN row
     |       3. stale cleanup (HAND-MAINTAINED list STALE_HOOKS / $staleHooks):
     |          delete those files and their backups from ~/.claude/hooks
     |       4. settings.json merge (node; only the "hooks" key is managed):
     |            removeHookEntry(...) for each stale hook   (hand-maintained)
     |            mergeHookEntry(event, file, matcher, 'bash "~/.claude/hooks/<file>"')
     |              for every hooks[] entry: update in place, add if missing, dedupe
     |          validate after write: every manifest hook registered exactly once,
     |          command/prompt schema; corrupt file or lost keys need --force
     |       5. reverse discovery: a *.sh in ~/.claude/hooks in neither shared/hooks
     |          nor the dotprofile claude/hooks -> [a]dopt to dotprofile / [s]kip
     |
     +--> build-deploy.sh   (MDM path)
     |       preflight: every manifest file exists; embeds the hook files and the
     |       registration list statically into deploy/setup-user-hooks.*
     |
     +--> check-post-push step 32 (scripts/check-hook-parity.py) + single-source
     |       check: .sh, .ps1 and build-deploy all read the manifest
     |
     +--> deploy-harness: copies it with shared/hooks/* into ~/.aitools/hooks/
             (inert: settings.json points at ~/.claude/hooks, nothing reads this copy)
```

There is no automatic retirement for hooks. Removing a hook takes three
hand edits (`.claude/rules/hook-lifecycle.md` "Retiring a hook"): drop its
manifest entry and file, add it to `STALE_HOOKS` / `$staleHooks`, and add a
`removeHookEntry` call in each merge block. The MDM path removes the
registration but not the file.

## 6. Reference and registries: deployed without a manifest

### 6.1 Creation (deploy-harness, the same plan as rules and skills)

```
  <aitools>/reference/**    --add_source reference  "tree"--+
  <aitools>/registries/**   --add_source registries "tree"--+
                                                            |  git-tracked files only;
                                                            |  *.bak.* never; one source
                                                            |  each, so no conflicts
                                                            v
                         each file -> deploy_managed_file -> ~/.aitools/<kind>/<same rel path>
                            .md (reference)   : text review menu (overwrite / accept & adopt /
                                                merge & adopt / skip / abort)
                            .json (registries): field-by-field review, SOURCE owns every
                                                field, no merge (review_json_fields)
                            adopt target      : the repo file it came from (an aitools
                                                working-tree change; adopting into a
                                                protected file logs a WARN naming it)
                            MDM copy          : no adopt target (the source is the embed)
                                                            |
                                                            v
                         PRESERVED scan (section 6 of deploy-harness):
                           every file under ~/.aitools/<kind> that no source planned
                           this run -> "Preserved: <path> (no source -- kept)", info log,
                           never deleted
```

### 6.2 Reconciliation: there is none

```
  file added to reference/ or registries/   -> deployed (created) next run
  file changed                              -> verified (same) / review menu (differs);
                                               non-interactive or --force: overwrite
  file deleted or renamed in the repo       -> the old copy STAYS in ~/.aitools,
                                               logged "Preserved" on every run
                                               (no manifest records that it was ours)
  edit made in ~/.aitools                   -> next run: review menu; [a]ccept & adopt
                                               copies it back into the repo file
```

Unlike rules and skills, nothing tells deploy-harness that a stale
`~/.aitools/reference/old.md` was once deployed rather than added by a
person, so it is never removed. That is harmless for agents that read a
named file, but `ls ~/.aitools/reference` can show files the repo no
longer has.

### 6.3 Acted upon: who reads the copies

No setup script fans these out; they stay in `~/.aitools`. They are read
in place, and only as a fallback:

```
  a registry skill (/tool-registry, /tool-ops, /incident, /glossary, /frameworks)
  or an agent looking for a reference file -- "Where the files live":
     |
     +-- session on aitools (the clone or a worktree)
     |       read and write the repo files directly
     |
     +-- session on another repo, aitools clone present (repoPath in
     |   ~/.aitools/config.json)
     |       git -C <repoPath> fetch, read origin/main (not the working tree);
     |       a write goes on a new branch in a worktree from origin/main -> PR
     |
     +-- no clone on this machine
     |       read ~/.aitools/registries/** and ~/.aitools/reference/** (READ-ONLY;
     |       never edit; propose a change as an issue on nobul-tech/aitools)
     |
     +-- none of these
             the data is unavailable: say so and stop; never answer from memory
```

Registries are governed data: an agent reads and writes them only through
their skill (`.claude/rules/governed-data-access.md`), in the repo and in
`~/.aitools` alike. An accept & adopt at the review menu for a
`~/.aitools/registries/` file writes the repo registry outside its skill,
so treat an edited registry copy as a mistake to overwrite, not to adopt.

## 7. Side by side

```
                     RULES / SKILLS          HOOKS                  REFERENCE / REGISTRIES
                     MANIFEST                MANIFEST               (no manifest)
  what it is         generated state         committed spec         --
  deployed to        ~/.aitools, then        ~/.claude/hooks +      ~/.aitools only
                     fanned out to           settings.json          (read in place)
                     ~/.claude, ~/.cursor
  diffed against     the previous run's      nothing (settings      nothing
                     manifest                .json is merged)
  new item           appears in a source     entry added by hand    appears in the repo
                     -> line added                                  -> copied
  removed item       "retired": backed up,   STALE list +           stays in ~/.aitools,
                     removed everywhere      removeHookEntry,       logged "Preserved"
                                             by hand                every run
  missing source     lines kept (never       hook file missing      nothing copied;
                     deletes)                -> ERROR, exit 1       logged info
  user's own copies  kept unless they match  reverse discovery      edits get the review
                     a harness copy or       offers adoption to     menu; adopt writes the
                     backup (ACTION row)     the dotprofile         repo file
  MDM path           same code, sources =    embedded at build      same code, sources =
                     build-time snapshot     time                   build-time snapshot
                     (deploy-harness                                (deploy-harness
                      .payload)                                      .payload)
```

## 8. Cross-references

- Deployed harness, conflicts, manifests in prose: `@reference/harness.md`
  "Deployed harness (`~/.aitools`)", "Rules manifest and retired rules",
  "Skills manifest and retired skills"
- Rule and skill decisions (R-8, S-7): `@reference/rules.md`,
  `@reference/skills.md`
- Fan-out contracts: `@reference/skills.md` section 6.3;
  `scripts/setup-user-claude.sh` (rules fan-out span),
  `scripts/setup-user-cursor.sh` step 4
- Managed files, review menu, outcomes: `@reference/managed-file-deployment.md`
- Hook life cycle and retirement: `.claude/rules/hook-lifecycle.md`
- Run order and the MDM path: `.claude/rules/deploy-paths.md`
- Registry access: `.claude/rules/governed-data-access.md`; the inventory of
  registries and their skills: `/frameworks` skill; where a registry skill
  reads its files: that skill's "Where the files live" section
- Workspace layout of `~/.aitools`: `.claude/rules/aitools-workspace.md`
- Code: `scripts/deploy-harness.sh` (`add_source`, `harness_manifest_plan`,
  `write_harness_manifest`), `scripts/aitools-lib.sh`
  (`read_harness_manifest`, `fanout_text_equal`, `fanout_dir_matches`,
  `fanout_harness_skills`), `scripts/setup-user-hooks.sh`; the `.ps1` twins
