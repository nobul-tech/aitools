# Plan: rules and skills fan-out (Claude Code and Cursor)

**Intent**: **Purpose**: The executable plan for mission FANOUT-IMPL: every
rule (aitools `shared/rules`, aitools `.claude/rules`, dotprofile
`claude/rules`) and every skill (aitools `shared/skills`, aitools
`.claude/skills`, dotprofile `claude/skills`) is collected by deploy-harness
into `~/.aitools/rules` / `~/.aitools/skills` with a source manifest, then
fanned out by setup-user-claude into `~/.claude/rules` / `~/.claude/skills`
and by setup-user-cursor into `~/.cursor/rules` / `~/.cursor/skills`, minus
retired names, for both tools. **Scope**: batches FO-0..FO-7 (CI, lib,
deploy-harness skills, Claude rules, Claude skills, Cursor rules and skills,
setup-user-skills and MDM, docs), their contracts, tests, CI, verification,
error-handling audit, PR and merge order. NOT Homebrew, IntuneWinAppUtil or
the `aitools user init` clone change (build-package mission). NOT RECONCILE's
other batches (R8c abort row included). **Audience**: the FANOUT-IMPL
delegates (one per batch), their independent reviewers and logging
auditors, the merge orchestrator, Session Commander 10cf255a-c and the
commander.

Version 1.0, 2026-10-26. Written by S3-FanoutImpl (level-1 orchestrator,
Session Commander 10cf255a-c). A version, not a draft (D-DEL5). Builds on
`plans/rules-fanout-claude.md` v1.0 (FAN-PLAN), which stays the verbatim
source for the Claude rules batch (FO-3).

## 1. Decisions (binding)

| ID | Decision | Date | Source |
|----|----------|------|--------|
| FD-1 | All project-scope rules AND skills deploy to user-scope Claude Code; the commander removes the duplicate project copies later. Known cost (~79 KB / ~20k tokens of "(this repo)" rules every session, double load inside aitools) accepted | 2026-10-26 | FANOUT-IMPL launch prompt; `reference/rules.md` R-4 |
| FD-2 | Cursor gets every rule in `~/.aitools/rules` minus `retired` (shared, aitools, dotprofile): reverses PR #110's user-level filter, keeps its marker / prune safety | 2026-10-26 | RECONCILE Q3 ("cursor should get project level rules too in user space"), `plans/fan-plan-reconciliation.md` section 4 |
| FD-3 | Skills: shared/skills and project .claude/skills (and the dotprofile claude/skills) are copied to `~/.aitools/skills/`, then fanned out the same way as rules; one `reference/skills.md` in the format of `reference/rules.md` | 2026-10-26 | launch prompt (commander's words: "both shared/skills and project .claude/skills should be copied to ~/.aitools/skills/ and then a fan-out approach same as rules. same reference/skills.md file. same format.") |
| FD-4 | Skill conflicts: first source wins (shared/, then .claude/, then dotprofile); each skipped duplicate `log_error` + ERROR row; a skills manifest records each skill's source; a user's own skill in `~/.claude/skills` or `~/.cursor/skills` is never overwritten or pruned unless the fan-out created it | 2026-10-26 | launch prompt |
| FD-5 | FAN-PLAN Q2-Q12 take their suggested answers; Q1/Q13 answered: fan out everything | 2026-10-26 | launch prompt; `plans/rules-fanout-claude.md` section 9 |
| FD-6 | Small PRs, one per batch, base `main`, each with tests and an independent verifier; merged in order with merge commits only when every check is green and `mergeStateStatus` is CLEAN; main CI checked after each merge. A later branch merges the earlier branch's head with `--no-ff`; never base a PR on another PR's branch | 2026-10-26 | launch prompt |
| FD-7 | Abort: PR #106's behaviour (only deploy-harness exit 2 stops the run); RECONCILE R8c adds WARN `aborted by user` -- not ours | 2026-10-26 | launch prompt |
| FD-8 | Versions, not drafts (D-DEL5): protected files written as a version in the PR, each protected edit listed old -> new under "Review after"; plans/handoffs/relay/CLAUDE.md direct to main | 2026-10-26 | launch prompt; CLAUDE.md "Channel exception" |
| FD-9 | setup-user-skills stops deploying once `~/.aitools/skills` exists (the fan-out owns `claude skills` / `cursor skills`); it keeps reverse discovery (adopt a user-created skill to the dotprofile) and stays the fallback deployer when deploy-harness has not run | 2026-10-26 | this plan (orchestrator decision, section 4.6 "why") |

## 2. Today (integration base) and the target

Integration base `feature/fanout-base` (local, not pushed) = `origin/main`
03b833f + the open MERGE-ALL heads in MERGE-ALL's order: #109 1692959,
#113 2419d23, #112 52821bd, #100 699eba8, #110 adcf4a7, #111 8caa79e,
#115 2ae798a, #106 3de51d6 (merged clean, d7f6855). Every FO branch starts
from it so the code builds on what MERGE-ALL is about to merge; before each
merge the branch merges `origin/main` (which by then holds those PRs).
Reviewers diff against the base: `git diff d7f6855...HEAD` (or the previous
FO head).

| Piece | On the base | After this plan |
|---|---|---|
| deploy-harness rules | 3 sources -> `~/.aitools/rules`, manifest `.aitools-rules-manifest` (#100), retired rules removed | unchanged |
| deploy-harness skills | `shared/skills`, `.claude/skills` -> `~/.aitools/skills/<name>/**`, first source wins; no dotprofile source, no manifest, no retire | + dotprofile `claude/skills`; manifest `.aitools-skills-manifest`; retired skills backed up and removed (FO-2) |
| Claude rules | dotprofile `claude/rules` -> `~/.claude/rules` | `~/.aitools/rules` minus retired -> `~/.claude/rules` (FO-3 = FAN-PLAN B-D) |
| Claude skills | setup-user-skills: shared + dotprofile SKILL.md only | `~/.aitools/skills` minus retired -> `~/.claude/skills/<name>/**` (FO-4) |
| Cursor rules | `~/.aitools/rules` shared+dotprofile only (#110), bash loop never prompts | all minus retired, prompt fixed (FO-5) |
| Cursor skills | setup-user-skills: shared + dotprofile SKILL.md only | `~/.aitools/skills` minus retired -> `~/.cursor/skills/<name>/**` (FO-5) |
| setup-user-skills | deploys to both tools | fallback only + reverse discovery (FO-6) |
| MDM | build-deploy embeds dotprofile rules into setup-user-claude; setup-user-skills embeds shared skills | rules via deploy-harness only (FO-3); setup-user-skills generator keeps the fallback, skips when `~/.aitools/skills` exists (FO-6) |

## 3. Contract (pinned; a batch that must change it writes a "Contract change" section in its PR body)

### 3.1 Rules (unchanged from FAN-PLAN)

`plans/rules-fanout-claude.md` sections 3 and 4 are the rules contract:
manifest `~/.aitools/rules/.aitools-rules-manifest`, header
`# aitools rules manifest v1`, lines `<name><TAB>shared|aitools|dotprofile|retired`;
`rule_name_kind` / `Get-RuleNameKind`; `read_rules_manifest` /
`Read-RulesManifest`; tracker outcome `removed`; unknown outcome -> logged +
`failed`; summary tool `claude rules`.

Cursor (FO-5): the same manifest; entitled = every source except `retired`;
prune list = `retired` only. No manifest -> every rule fanned out, none
removed (Claude parity, FAN-PLAN Q3); header-bad -> same + `log_warn` +
ACTION `Run aitools to rebuild ~/.aitools/rules and its manifest`; unreadable
-> ERROR row `cannot read rules manifest`, fan-out continues, manifest counted
as a `failed` item. #110's marker line, legacy-content recognition and
verified-backup removal stay. Removal is recorded with tracker outcome
`removed` (lib), not a private counter. Summary tool `cursor rules`;
`n/a (no harness rules)` when nothing to do (the `n/a (no user-level rules)`
text goes away).

### 3.2 Skills manifest (FO-2 writes, FO-4/FO-5 read)

- Path `~/.aitools/skills/.aitools-skills-manifest` (`%USERPROFILE%\.aitools\skills\...`).
- UTF-8, LF, first line `# aitools skills manifest v1`, then
  `<skill name><TAB><source>` sorted by name (byte order); source `shared`
  (aitools `shared/skills`), `aitools` (aitools `.claude/skills`), `dotprofile`
  (`<dotprofile>/claude/skills`), `retired`. Source = the winner (first source
  wins, names compared case-insensitively).
- Valid name: no `/` or `\`, does not start with `.`, no `.bak.`; written as
  found on disk.
- Retired: a name in the previous manifest that no source has this run;
  only a source listed this run retires its names (same rule as rules, #100
  section 5b). Listed-source bookkeeping is per kind (`<kind><TAB><label>`),
  so a listed dotprofile rules source does not retire dotprofile skills.
- A retired skill's directory `~/.aitools/skills/<name>/` is backed up with
  `backup_dir` / `Backup-Dir` (`<name>.bak.<UTC>/` beside it), the backup is
  verified to exist, then the directory is removed; failures `log_error` +
  ERROR row, directory kept.
- deploy-harness preserved scan ignores `.aitools-skills-manifest(.tmp)` and
  every path with a `*.bak.*` component (a backed-up skill directory).
- Labels: `add_source skills "dotprofile/skills" "$DOTPROFILE/claude/skills" "$HARNESS_DIR/skills" units`
  inside the existing `if [ -n "$DOTPROFILE" ]` block (build-deploy's MDM
  parser reads `add_source ... "$DOTPROFILE/..."` lines: FO-2 verifies with
  `tests/deploy-harness-mdm`).

### 3.3 Lib (FO-1; parity sh/ps1)

| bash | PowerShell | Contract |
|---|---|---|
| tracker `removed` + `*)` default | `Record-DeployOutcome` `removed` + `default` | FAN-PLAN A1-A4 verbatim |
| `RULES_MANIFEST_HEADER`, `SKILLS_MANIFEST_HEADER` | `$rulesManifestHeader`, `$skillsManifestHeader` | `# aitools rules manifest v1`, `# aitools skills manifest v1` |
| `lower_name`, `in_list` | (n/a: HashSet) | FAN-PLAN A2 |
| `rule_name_kind NAME` | `Get-RuleNameKind` | hidden / backup / rule / other (FAN-PLAN A2/A4) |
| `skill_name_kind NAME` | `Get-SkillNameKind` | hidden (leading dot) / backup (`*.bak.*`) / skill (anything else); case-insensitive; the caller checks it is a directory |
| `read_harness_manifest FILE KIND` | `Read-HarnessManifest -Path -Kind` | KIND `rules` or `skills`: header per kind; rules names must match `\A[^/\\]+\.md\z`, skills names `\A[^/\\.][^/\\]*\z`; both reject `.bak.`, unknown sources and case-insensitive duplicates. Output as FAN-PLAN's reader (`rule<TAB>name<TAB>source` lines, `invalid<TAB>...`, `header-bad`); ps returns `@{Status; Rules; Invalid}` |
| `read_rules_manifest FILE` | `Read-RulesManifest` | thin wrappers over the above (KIND rules), byte-for-byte FAN-PLAN's output |
| `fanout_text_equal A B` | `Test-FanoutTextEqual` | 0 equal ignoring trailing CR/LF, 1 differ, 2 unreadable (FAN-PLAN's `rule_text_equal`, moved to the lib) |
| `fanout_dir_matches TARGET CAND` | `Test-FanoutDirMatches` | 0 when TARGET is a real directory, every regular file under it whose base name is not `*.bak.*` exists at the same relative path under CAND and is `fanout_text_equal`, and it holds at least one such file; 1 otherwise; 2 unreadable |

### 3.4 Skills fan-out (FO-4 lib function, consumed by FO-4 Claude and FO-5 Cursor)

`fanout_harness_skills TOOL DEST AITOOLS_REPO DOTPROFILE` /
`Invoke-HarnessSkillsFanout -ToolName -DestDir -AitoolsRepo -Dotprofile`
(lib; build-deploy inlines the lib into MDM scripts, so MDM gets it too).

| Case | Behaviour |
|---|---|
| no `~/.aitools/skills` | log, `OK <TOOL> n/a (no harness skills)`, DEST untouched |
| unreadable dir | `log_error`, `ERROR <TOOL> cannot read harness skills` |
| manifest absent | every skill fanned out, none retired, adopt not offered (info log) |
| manifest header-bad | `log_warn` + ACTION `Run aitools to rebuild ~/.aitools/skills and its manifest`; as absent |
| manifest unreadable | `log_error` + ERROR row `cannot read skills manifest`; fan-out continues; counted as a `failed` item `.aitools-skills-manifest` |
| entry kinds | `hidden`, `backup` skipped silently; a plain file at top level -> log "Ignoring non-skill file"; a dangling symlink -> `failed`; a retired name -> "Not fanned out" log |
| deploy | each regular file under `~/.aitools/skills/<name>/` (recursive, `*.bak.*` base names skipped) -> `DEST/<name>/<rel>` via `deploy_managed_file`, item `<name>/<rel>`, list read on fd 3 (review menu can prompt); executable bit copied from the harness copy; unexpected result -> `log_error` + `failed` |
| adopt target | from the manifest source: `shared` -> `<AITOOLS_REPO>/shared/skills/<name>/<rel>`, `aitools` -> `<AITOOLS_REPO>/.claude/skills/<name>/<rel>`, `dotprofile` -> `<DOTPROFILE>/claude/skills/<name>/<rel>`, only if that file exists and the repo arg is non-empty; AITOOLS_REPO is passed only from a git checkout (FAN-PLAN's `.git` test); Cursor passes `""` for both (no adopt, as Cursor rules) |
| DEST/<name> is a symlink or a file | not written: `log_warn` "Kept <name>: not a directory this fan-out owns", tracker `preserved`, plus one ACTION row listing them (the user's own skill is never overwritten) |
| case-only duplicate names | first wins, second `failed` |
| retired prune | for each retired name not deployed this run: `DEST/<name>` (found case-insensitively, real directory only) is removed only when `fanout_dir_matches DEST/<name> CAND` is 0 for CAND = `~/.aitools/skills/<name>` or any `~/.aitools/skills/<name>.bak.*`; then `backup_dir`, verify a `<DEST>/<name>.bak.*` directory exists with the same files (else `log_error` + `failed`, kept), `rm -rf`, verify gone, tracker `removed`. Not matching -> `log_warn "Kept ..."` + one ACTION row `<Tool> still loads retired skills in <DEST>: <names> -- delete them unless you wrote them`. Dry run: log only |
| preserved | every directory in DEST not deployed this run (third-party skills, symlinks such as the firecrawl ones) -> `preserved`, never touched |
| DEST missing | created (`mkdir -p`; ps re-checks with `Test-Path -PathType Container`), failure -> ERROR `cannot create skills dir` |
| backup | `backup_dir DEST` once per non-dry run before the first write (config-file-safety "Directory deployment") |
| summary | `deploy_tracker_summary TOOL` (OK `N added, ...` / WARN `N skipped (user review)` / ERROR `N failed`); dry run `OK dry run (no files written)` or `ERROR N failed (dry run)` |
| abort | `[x]abort` exits 2 from the library inside the loop (no TOOL row; the caller's loop reports it, FD-7) |

Tool names: `claude skills` (setup-user-claude), `cursor skills`
(setup-user-cursor). setup-user-skills must not write these two rows when
`~/.aitools/skills` exists (FO-6).

## 4. Batches

Common to every batch (each delegate prompt carries these; shared text in
`.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanoutImpl/S3-FanoutImpl-delegate-brief.md`):
own worktree `/Users/new-jose/repos/aitools/.claude/worktrees/fo-<short>`,
branch `feature/fanout-<batch>` from `feature/fanout-base` (or the previous
FO head, merged `--no-ff`); scratch `<worktree>/.scratch/session-fo<x>`;
`.ps1` CRLF; bash 3.2; isolated HOME only; `bash -n` + pwsh parser;
`check-pre-commit.sh`; `check-pre-push.sh` (step 7 known FAIL recorded);
the error-handling block of `reference/plan-execution-detail.md` verbatim;
push, `gh pr create --base main`. Each PR gets one independent reviewer and
two logging auditors before merge.

### FO-0 -- CI: every suite in CI (branch `feature/fanout-ci`)

- Files: `.github/workflows/check.yml`.
- Add jobs/steps for the suites not in CI: `tests/deploy-harness`,
  `tests/deploy-harness-mdm`, `tests/rules-fanout-cursor`, `tests/hookin`,
  `tests/b8-consumers` (macOS bash 5 + /bin/bash 3.2 where the suite supports
  `--bash-only`, Linux). `tests/build-package` only if it passes on the base
  (else list it, with the reason).
- New CI step "Every test suite is in CI": fails when a
  `tests/<dir>/test-*.sh` path is not named in check.yml (inline perl; no new
  script pair). Cheap, catches the S3-FanPlan Checks I-2 class of gap.
- Verification: each added suite run locally on the base under isolated HOME
  (the suites do it themselves); YAML parses
  (`ruby -e 'require "yaml"; YAML.load_file(ARGV[0])'`); CI green on the PR.
- If a suite fails on the base: do not add it; record the failure (it is
  another mission's bug) in the PR body.

### FO-1 -- lib helpers (branch `feature/fanout-lib`)

- Files: `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`,
  `tests/fanout-lib/test-fanout-lib.sh` (new, 100755; drives bash and pwsh,
  `--bash-only`, `--help`, `AITOOLS_TEST_BASH`), `.github/workflows/check.yml`
  (its steps; merge FO-0's head first).
- Content: section 3.3. FAN-PLAN A1-A4 apply verbatim (re-check each
  old_string is unique on the base before editing); the rest per contract.
- Error-handling audit: FAN-PLAN Batch A table + every new function returns
  a code the caller must check; no `2>/dev/null` / `|| true` without comment
  and check.
- Tests: tracker removed/unknown rows sh=ps; name kinds (case, dots, bak);
  manifest reader cases (ok, header-bad, BOM, CRLF, invalid lines, duplicates,
  unreadable, rules vs skills name rules) sh=ps; text_equal; dir_matches
  (match, extra file, missing file, `*.bak.*` ignored, empty dir, symlink).
- Verification: the new suite; `tests/managed-files`, `tests/profile/test-lib.sh`,
  step-31 tracker parity extraction (FAN-PLAN A verification 2).

### FO-2 -- deploy-harness skills manifest and retired skills (branch `feature/fanout-harness-skills`)

- Files: `scripts/deploy-harness.sh`, `scripts/deploy-harness.ps1`,
  `tests/deploy-harness/test-deploy-harness.sh`; `scripts/build-deploy.sh`
  and `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` only if the MDM
  generator needs a change for the new source line / manifest (verify by
  running that suite).
- Content: section 3.2. Generalise #100's section 5b to both kinds (one perl
  planner taking the kind, or two calls), not a copy-paste.
- Tests (extend the suite, both languages): skills manifest written with the
  right sources; same-name skill in shared/ and .claude/ -> shared wins,
  ERROR row, manifest `shared`; the #74/#75 layout move (a skill moves from
  .claude/skills to shared/skills between runs) -> manifest source changes,
  nothing retired; a skill removed from its source -> `retired`, harness dir
  backed up and removed, backup exists; source not listed -> kept; dotprofile
  skills source; preserved scan does not report backup dirs; dry run writes
  nothing.

### FO-3 -- Claude rules fan-out (branch `feature/fanout-claude-rules`)

- = `plans/rules-fanout-claude.md` Batches B, C, D (setup-user-claude.sh/.ps1,
  build-deploy.sh, tests/claude-mdm, README.md, tests/rules-fanout, check.yml),
  with section 12 amendments, on top of FO-1 (which already carries Batch A)
  and FO-0. Re-check every old_string on the branch (C11 vs C11b: #111 is in
  the base, so C11b applies). Use the lib's `fanout_text_equal` instead of a
  local `rule_text_equal` (contract change allowed: say so). The `.ps1`
  `Test-RuleTextEqual` likewise -> `Test-FanoutTextEqual`.
- Three PR-sized commits (B, C, D) in one PR, as FAN-PLAN planned.
- FX-74 note: README C13 points to deploy-paths "MDM path limits" if that
  section exists on main at merge time; otherwise keep C13's text and list it.

### FO-4 -- Claude skills fan-out (branch `feature/fanout-claude-skills`)

- Files: `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1` (section 3.4
  function), `scripts/setup-user-claude.sh`, `scripts/setup-user-claude.ps1`
  (one call each after the rules span, outside the build-deploy markers'
  extracted rules spans but inside an extracted body so MDM gets it -- the
  delegate checks build-deploy's extraction and adds the call where MDM
  carries it), `tests/skills-fanout/test-skills-fanout.sh` (new),
  `.github/workflows/check.yml`.
- Claude passes AITOOLS_REPO = the `RULES_AITOOLS_REPO` / `$rulesAitoolsRepo`
  of FO-3 and DOTPROFILE = `USER_REPO_PATH` / `$userRepoPath`.
- Tests (sh=ps tree and rows): missing / empty / fanout (shared, aitools,
  dotprofile sources, nested files, `*.bak.*`, hidden, top-level file) /
  rerun verified / edited -> review (`--force` overwrite) / same name in
  shared and .claude in the harness manifest -> adopt to shared / retired
  matching harness backup -> removed with backup / retired user-modified ->
  kept + ACTION / symlink skill in DEST preserved (firecrawl case) / third-party
  dir preserved / dry run / adopt (pty) writes the repo file / abort (pty)
  exit 2 / nocreate / manifest unreadable / payload (no `.git`) adopt none.

### FO-5 -- Cursor: all rules, skills, prompt fix (branch `feature/fanout-cursor`)

- Files: `scripts/setup-user-cursor.sh`, `scripts/setup-user-cursor.ps1`,
  `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` (+ its `.ps1`
  drivers as needed), `tests/skills-fanout/test-skills-fanout.sh` (cursor
  cases), `.github/workflows/check.yml` if steps change.
- Content: section 3.1 Cursor; drop the script's own `lower_name`, `in_list`,
  `read_rules_manifest`, `Read-RulesManifest` (lib; FAN-PLAN F1) and use
  `rule_name_kind` (case-insensitive filter); read the deploy list on fd 3
  (S3-FanPlan high finding: the here-string loop never prompts); pruning
  records tracker `removed`; add step 5 "Cursor user skills" calling
  `fanout_harness_skills "cursor skills" "$CURSOR_DIR/skills" "" ""` /
  ps twin. Header comment and step list updated.
- Tests: an aitools-source rule is now fanned out (was pruned); an
  aitools .mdc created by #110's run is re-added/verified; retired still
  pruned with marker / legacy match; user .mdc of a retired name kept +
  ACTION; no manifest -> all fanned out, none removed; pty test proving the
  bash review menu prompts (fd-3 fix); skills to `~/.cursor/skills`.

### FO-6 -- setup-user-skills becomes the fallback; MDM (branch `feature/fanout-skills-legacy`)

- Files: `scripts/setup-user-skills.sh`, `scripts/setup-user-skills.ps1`,
  `scripts/build-deploy.sh` (setup-user-skills generator, only if the
  harness check must live outside the "skill discovery (replaced by
  build-deploy)" block), a test (new `tests/skills-fanout/` case or a
  `tests/skills-legacy/` suite).
- Behaviour: when `~/.aitools/skills` exists, do not deploy and do not write
  `claude skills` / `cursor skills` rows; write `OK skills n/a (fanned out
  from ~/.aitools/skills)` and log which scripts own it. Reverse discovery
  stays and treats any name in `~/.aitools/skills` (or its manifest) as not
  user-created. Without `~/.aitools/skills`: today's behaviour (fallback).
  The check sits where the MDM generator keeps it.
- Why FD-9 (not removal): with #106 deploy-harness runs before every setup
  script on the dev path and in the installer, so the fan-out is the only
  writer; but an MDM endpoint run in the wrong order, or a machine where
  deploy-harness failed, would otherwise lose skill updates. One writer at a
  time (the existence of `~/.aitools/skills` decides) avoids two review
  menus and two adopt targets for one file. Reverse discovery has no other
  home.

### FO-7 -- docs (branch `feature/fanout-docs`)

- New `reference/skills.md` v1.0, same sections as `reference/rules.md`:
  Intent, version line, decisions with dates, what a skill is, layering,
  anatomy, scopes and loading (Claude Code and Cursor), deployment table
  built-vs-planned, project skills at user scope with cost, checklist for
  writing a skill, gaps, cross-references. Its intent statement is new and
  protected: written as a version and listed under "Review after" (FD-8).
- `reference/rules.md` v1.1: R-2 -> Cursor gets all minus retired (FD-2);
  section 6.1 table "today" after FO-1..FO-6; section 7 skills paragraph
  points to skills.md; section 9 contradictions resolved or carried; FX-58
  sentence (tool-ops-cursor "Glob anchoring", Claude vs Cursor scoping).
- Every doc that says "user-level only", "once it fans out", "setup-user-claude
  once it fans out", "not deployed" (skills): `.claude/rules/documentation-standards.md`
  "Skill placement" (FX-71), `reference/user-repo.md` scope guidance,
  `.claude/rules/deploy-paths.md` (+ `.mdc`), `.claude/rules/managed-file-deployment.md`
  (+ `.mdc`) and `reference/managed-file-deployment.md` (tracker `removed`,
  content sources), `reference/harness.md`, `.claude/rules/hook-rollout.md`
  (+ `.mdc`), `.claude/rules/aitools-workspace.md`, `shared/skills/scratch/SKILL.md`,
  `.claude/rules/config-file-safety.md`, `reference/script-standards-detail.md`
  (outcome `removed`), `reference/tool-ops-claude-code.md` item #28
  (UNVERIFIED marker kept unless re-read with chrome-devtools). Start from
  FAN-PLAN's drafts in `S3-FanPlan/S3-FanPlan-drafts/`, re-anchored on
  whatever RECONCILE R2/R2c/R3/R4 merged (R14).
- Glossary: `fan-out`, `retired`, `removed`, `harness files`, `trigger
  directive` through the `/glossary` skill (governed; written as a version
  in this PR, listed under Review after).
- Split into two commits (rules/refs; skills.md + glossary) if the diff is
  large; still one PR.

## 5. PR and merge order

FO-0 -> FO-1 -> FO-2 -> FO-3 -> FO-4 -> FO-5 -> FO-6 -> FO-7. Each later
branch merges the previous FO head `--no-ff` before its PR is marked ready.
Parallel build: FO-0, FO-1, FO-2 and FO-7 research start together; FO-3
after FO-1; FO-4 after FO-3 (same files); FO-5 after FO-4 (the lib
function); FO-6 after FO-4; FO-7 written last against the merged behaviour.

Merge gate (merge orchestrator S3-FanoutImpl-Merge): MERGE-ALL's report
`S3-MA-report.md` is on `origin/main`. Then per PR: merge `origin/main` into
the branch, resolve, rerun the touched suites, push, CI green,
`mergeStateStatus` CLEAN, base `main`, independent verdict posted and no
open blocking finding, logging-audit findings fixed; `gh pr merge --merge`;
wait for main's CI; run the touched suites on main; next. Red main ->
fix-forward PR or revert-forward, then continue.

## 6. Verification (every batch)

1. `bash -n` on every touched `.sh`; PowerShell parser on every `.ps1`.
2. The batch's suites + `tests/managed-files`, `tests/profile/test-lib.sh`
   (lib batches), `tests/claude-mdm` (setup-user-claude / build-deploy
   batches), `tests/deploy-harness*` (deploy-harness / build-deploy batches).
3. `bash scripts/check-pre-commit.sh`; `bash scripts/check-pre-push.sh`
   (step 7 FAIL known until MERGE-ALL rebuilds the dotprofile `deploy/`).
4. Never: `check-post-push` against the real HOME before merge,
   `check-pre-commit --fix`, any setup script against the real HOME.

## 7. Risks

- R1: FD-1 cost (rules.md section 7).
- R2: same-name skill at both levels inside aitools; Claude Code's user copy
  wins, so a branch editing a project skill sees the stale user copy until
  the next `aitools` run (skills.md documents it).
- R3: project skills that cite repo-relative paths (`registries/...`) fail
  outside aitools when invoked there (skills.md documents it).
- R4: FO-5 re-adds the aitools `.mdc` that #110 pruned (intended, FD-2).
- R5: MERGE-ALL fix-forwards to the base PRs may conflict with FO branches
  when `origin/main` is merged in; resolved by the merge orchestrator.
- R6: #74/#75 re-land moves 7 skills from `.claude/skills` to
  `shared/skills`: manifest source flips, adopt target follows, nothing is
  retired (FO-2 test).

## 8. Open questions (suggested answers taken; listed for the commander)

**Commander answers, 2026-10-28 (session 10cf255a-c; binding) to the
hand-back's Q1-Q4:**

| Q | Answer (commander's words) | Effect |
|---|---|---|
| Hand-back Q1: deploy-harness builds green while over the Intune size limit | "7) accept the deploy-harness" | Accepted (WARN under D3) until FX-35 dedupes the inlined lib |
| Hand-back Q2: shared/ beats the dotprofile for skills | "8) shared/ wins" | Accepted (FD-4) |
| Hand-back Q3: keep a Cursor skills fan-out although Cursor also loads `~/.claude/skills` | "9) setup-cursor-cli should do the fan-out for cursor skills/rules" (clarified: setup-user-cursor, verify) | setup-user-cursor owns the Cursor rules and skills fan-out (FO-5, #123); mission CURSOR-VERIFY verifies it end to end |
| Hand-back Q4: tracker rows over 30 characters | "10) yes" | Amend the spec for tracker rows (follow-up) |

- Q1: dotprofile `claude/skills` as a third skills source? Taken: yes (FD-4
  names the order with dotprofile; setup-user-skills reads it today).
- Q2: whole skill directories or SKILL.md only? Taken: every tracked file
  (deploy-harness already collects them; skills hold `tests/` files).
- Q3: Cursor adopt for skills? Taken: none (as Cursor rules).
- Q4: setup-user-skills -- remove or fallback? Taken: fallback (FD-9).
