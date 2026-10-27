# S3-FanoutImpl-DocsScan: proposed `reference/skills.md` v1.0

By S3-FanoutImpl-DocsScan, 2026-10-26, for the FO-7 writer. Below the line
is the full proposed file. It mirrors `reference/rules.md` v1.0's sections.
Facts not yet true on `origin/main` (`42ed67e`) are marked **planned: FO-n**;
when FO-7 is written after FO-6 merges, the writer drops each marker it can
verify in the merged code (and keeps "unknown" where the code says nothing).
The intent statement is new and protected: list it under "Review after"
(FD-8). Writer's checks before publishing: every `@path` exists (pre-commit
step 20), no governed JSON path (step 16), function names match the merged
lib.

Sources read for this draft (all cited inline): `plans/skills-and-rules-fanout.md`
v1.0; `reference/rules.md` v1.0; `reference/harness.md`; `reference/managed-file-deployment.md`;
`.claude/rules/documentation-standards.md`; `.claude/rules/aitool-ops.md`,
`aitool-eval.md`; `reference/framework-three-layer-governance.md`;
`reference/framework-governed-data-access.md`; `/intent-writing` and
`/glossary` skills; Claude Code docs (https://code.claude.com/docs/en/skills,
read with chrome-devtools 2026-10-26 against Claude Code 2.1.309); Cursor docs
(https://cursor.com/docs/skills, read with chrome-devtools 2026-10-26);
measurements by `skill-cost.pl` (scratch
`/Users/new-jose/repos/aitools/.claude/worktrees/fo-orch/.scratch/session-fodocs/`).

---

# Skills

**Intent**: **Purpose**: The single reference for harness skills: what a
skill is (the governed process, loaded on demand, the only access to
governed data), the rule / skill / reference / registry layering as it
applies to skills, the anatomy of a skill directory, scopes and how Claude
Code and Cursor load skills, and their deployment (deploy-harness →
`~/.aitools/skills` → setup-user-claude / setup-user-cursor fan-out), with
the measured cost of the commander's decision that all project-scope skills
are deployed to user scope. **Scope**: Consolidate and cite what the repo,
the plan and the tools' documentation say; mark what is planned and what is
unknown. NOT the rules counterpart (`@reference/rules.md`). NOT the
managed-file state machine (`@reference/managed-file-deployment.md`). NOT
the content of any one skill. NOT changing code. **Audience**: Every agent
writing, changing or deploying a skill, in any repo, and the reviewers of
fan-out PRs.

Version 1.0, <date of FO-7>. Written by <FO-7 writer> for Session Commander
10cf255a-c, from research by S3-FanoutImpl-DocsScan. A version, not a draft
(D-DEL5). The intent above is protected (`@.claude/rules/sources-of-truth.md`
"Intent statements") and is listed for review in its PR.

Every claim cites its source. "Today" means `origin/main` at <merge SHA of
FO-6>; "planned" names a plan batch or PR. Where nothing says, this file says
"unknown".

## 1. Decisions

| ID | Decision | Date | By | Source |
|----|----------|------|----|--------|
| S-1 | All project-scope rules **and skills** are deployed to user-scope Claude Code; the commander removes the duplicate project copies later. Cost accepted | 2026-10-26 | commander | `@plans/skills-and-rules-fanout.md` FD-1; `@reference/rules.md` R-4 |
| S-2 | `shared/skills`, the aitools `.claude/skills` and the dotprofile `claude/skills` are copied to `~/.aitools/skills/`, then fanned out the same way as rules; one `reference/skills.md` in the format of `reference/rules.md` | 2026-10-26 | commander | FD-3 (commander's words: "both shared/skills and project .claude/skills should be copied to ~/.aitools/skills/ and then a fan-out approach same as rules. same reference/skills.md file. same format.") |
| S-3 | Skill conflicts: first source wins (`shared/`, then `.claude/`, then the dotprofile); each skipped duplicate is `log_error` + an ERROR row; a skills manifest records each skill's source; a user's own skill in `~/.claude/skills` or `~/.cursor/skills` is never overwritten or pruned unless the fan-out created it | 2026-10-26 | commander | FD-4 |
| S-4 | setup-user-skills stops deploying once `~/.aitools/skills` exists; it keeps reverse discovery and stays the fallback deployer | 2026-10-26 | S3-FanoutImpl (orchestrator), listed for the commander | FD-9, plan section 8 Q4 |
| S-5 | Whole skill directories (every tracked file), not SKILL.md only; Cursor gets no adopt | 2026-10-26 | S3-FanoutImpl, suggested answers taken | plan section 8 Q2, Q3 |
| S-6 | SD-8 (extended): 7 governance skills (`tool-ops`, `tool-eval`, `tool-registry`, `harvest`, `incident`, `glossary`, `frameworks`) move from `.claude/skills/` to `shared/skills/` | 2026-10-21 | commander | `SC-mission-packet.md` section 6; re-land of #74/#75 by MERGE-ALL (state at FO-7: <check>) |

S-1's measured cost is in section 7.

## 2. What a skill is

A skill **holds the process**. It is a directory with a `SKILL.md` whose
body is loaded only when the skill is used; until then only its name and
description are in context (section 5). It is:

- the **governed process** a rule points to with its trigger directive
  ("Rules govern and enforce process; skills implement it",
  `@reference/framework-three-layer-governance.md` "Rule-skill governance");
- the **only access to governed data**: "a loaded skill IS the capability"
  (`@reference/framework-governed-data-access.md`; `@.claude/rules/governed-data-access.md`).
  Rules and references name the skill, never the JSON path.

What a skill is not:

- Not the rule. The rule states WHEN; the skill does not need to restate
  the governing principle (`@reference/rules.md` section 2).
- Not the reference. Long rationale and history belong in `reference/`;
  Claude Code's own guidance is "Keep the body itself concise. Once a skill
  loads, its content stays in context across turns, so every line is a
  recurring token cost" (code.claude.com/docs/en/skills).
- Not data. A skill reads a registry; it does not embed one, except the
  **reference-card pattern** (section 4.4), which embeds a dated snapshot on
  purpose.

## 3. The layering, seen from the skill

| Layer | Holds | Loaded | Source |
|-------|-------|--------|--------|
| Rule | Intent, principle, directives, trigger directive "When to invoke /<skill>" | Always (or on `paths:` match) | `@reference/rules.md` section 3 |
| Skill | Governed process, menus, checklists; the gate to governed data | Description always (unless `disable-model-invocation`), body on invocation | this file |
| Reference | Detail, rationale | When read | `@.claude/rules/documentation-standards.md` |
| Registry | Structured data (protected, governed) | Through its skill only | `@.claude/rules/frameworks.md` "Three-layer registry pattern" |

"A rule without a trigger directive for its skill is a governance gap. A
skill without a corresponding rule trigger is ungoverned process"
(`@reference/framework-three-layer-governance.md` "Rule-skill governance").
A skill created for a framework comes with its trigger directive and a
detection hook spec (`@reference/framework-adoption.md` step 7). Naming
convention for registry skills: write `/<singular>`, read `/<plural>`
(`@reference/framework-three-layer-governance.md` "Registry Convention").

## 4. Anatomy of a skill

Built from the 24 skills on `origin/main` (15 in `shared/skills/`, 9 in
`.claude/skills/`; `git ls-tree -r origin/main shared/skills .claude/skills`).

### 4.1 Directory

```
<name>/
├── SKILL.md                    required
└── tests/expected-behaviors.md optional (7 of 24 have it today)
```

- The directory name is the skill name. Every harness skill today has a
  frontmatter `name:` equal to its directory name (`git grep -n "^name:"`).
  Cursor requires that: "Lowercase letters, numbers, and hyphens only. Must
  match the parent folder name" (cursor.com/docs/skills, "Frontmatter
  fields"). Claude Code takes `name` or the directory name as the command
  (code.claude.com/docs/en/skills "How a skill gets its command name").
- Reserved names: `synced` (Claude Code keeps claude.ai skills in
  `~/.claude/skills/synced/` and skips an authored skill of that name) and
  `anthropic-skills` (code.claude.com/docs/en/skills "Choose where skills
  load"). Never start a name with `.` and never include `.bak.` (the
  manifest rejects both, `@plans/skills-and-rules-fanout.md` 3.2).
- Name unique across `shared/skills/`, `.claude/skills/` and the dotprofile
  `claude/skills/` (case-insensitive): a duplicate is an ERROR on every
  deploy-harness run (`@reference/harness.md` "Conflict handling").
- Every tracked file in the directory is deployed (S-5; **planned: FO-4,
  FO-5** for the tools, done for `~/.aitools/skills` by deploy-harness
  today). Untracked files and `*.bak.*` are never deployed.

### 4.2 Frontmatter

```
---
name: <name>
description: <what it does and when to use it, key use case first>
---
```

| Field | Claude Code | Cursor | Harness use |
|-------|-------------|--------|-------------|
| `name` | optional (directory name otherwise) | required, = folder name | always set |
| `description` | recommended; with `when_to_use` truncated at 1,536 characters in the listing | required | always set; the cost driver (section 7) |
| `disable-model-invocation` | `true`: description not in context, user-invoked only | same | `audit` only |
| `paths` | globs, relative to the current working directory | globs | none today |
| `allowed-tools`, `context`, `model`, `effort`, `hooks`, ... | Claude Code extensions | not listed | none today |

Sources: code.claude.com/docs/en/skills "Frontmatter reference" and the
invocation table ("Description always in context, full skill loads when
invoked" / "Description not in context" for `disable-model-invocation:
true`); cursor.com/docs/skills "Frontmatter fields". A field Claude Code
does not know is ignored without an error; frontmatter that does not parse
loads the skill with no fields set (same source).

### 4.3 Body

In the order the approved skills use (exemplars: `/glossary`,
`/intent-writing`, `/delegate`, `/scratch`):

1. `## Intent` (Purpose, Scope with NOT lines naming the neighbouring
   skills, Audience). Protected like every intent statement
   (`/intent-writing` "Style calibration": skills are "more conversational
   than rules/JSON" and "must name what the skill does NOT do").
2. When to use it (mirrors the rule's trigger directive; the rule is the
   authority).
3. The process: numbered steps, menus, checklists, required fields.
4. Cross-references: rules by `@path`, skills by `/name`.

A skill that is deployed to user scope is read in any repo: write aitools
paths as "aitools `<path>`" or say the skill works only inside aitools
(section 7.3; same convention as shared rules, `@reference/rules.md`
section 4).

### 4.4 `tests/expected-behaviors.md`

Seven skills carry one (`audit`, `incident`, `tool-ops`, `delegate`,
`investigate`, `optimize-plan`, `planning`). It is deployed with the skill
(S-5). Its format and who runs it: unknown (no rule or reference governs
it; see section 10).

### 4.5 Reference-card pattern

A shared skill may embed a read-only, dated snapshot of project knowledge
for use outside aitools: `/aitool-ops`, `/aitool-eval`. "Derived",
"Read-only", "Self-contained", "Staleness-aware" (`@.claude/rules/aitool-ops.md`
"Reference-card pattern"). The governing rule says which skill to use in
which repo. With S-1 the full project skill (`/tool-ops`, `/tool-eval`) is
listed in every repo too, so the rules' "in any other repo, `/aitool-ops`
is the only available skill" no longer holds (section 10).

## 5. Scopes and loading

Scope modifiers compose with the base artifact `skill` (`/glossary` skill;
`@reference/framework-governed-vocabulary.md`):

| Scope | Where | What belongs there | Reaches the tools how |
|-------|-------|--------------------|-----------------------|
| shared skill | aitools `shared/skills/<name>/` | Harness process for every agent in every repo | deploy-harness → `~/.aitools/skills` → fan-out (**planned: FO-4, FO-5**; today `setup-user-skills`, SKILL.md only) |
| project skill | `.claude/skills/<name>/` in a repo | That repo's frameworks and governance | Loaded by Claude Code from the repo; for aitools also through the fan-out (S-1, **planned: FO-4, FO-5**) |
| dotprofile skill | `<userRepoPath>/claude/skills/<name>/` | The user's own skills | deploy-harness → fan-out (**planned: FO-2, FO-4, FO-5**; today `setup-user-skills`, and the dotprofile copy wins there) |
| user skill | `~/.claude/skills/<name>/`, `~/.cursor/skills/<name>/` | Deployed copies, plus the user's own and third-party skills | -- (the target) |

### 5.1 Claude Code

From code.claude.com/docs/en/skills (chrome-devtools, 2026-10-26, Claude
Code 2.1.309; to be recorded as `@reference/tool-ops-claude-code.md` item
#29, **planned: FO-7**):

- **Locations**: enterprise (managed settings), personal
  `~/.claude/skills/<name>/SKILL.md` ("All your projects on this machine,
  but not Cowork or cloud sessions"), project `.claude/skills/<name>/SKILL.md`
  (the start directory and every parent up to the repository root), nested
  `<subdir>/.claude/skills/` (loaded once Claude works on files there),
  `--add-dir` directories, plugins, claude.ai account (synced into
  `~/.claude/skills/synced/`).
- **Same name**: "Enterprise over personal, and personal over project. With
  deploy in both ~/.claude/skills/ and the project's .claude/skills/,
  /deploy runs the personal one." Inside aitools every project skill
  therefore runs from its user-level copy (section 7.1).
- **In context**: "skill descriptions are loaded into context so Claude
  knows what's available, but full skill content only loads when invoked";
  `disable-model-invocation: true` keeps the description out too.
- **Live changes**: Claude Code watches `~/.claude/skills/` and the project
  `.claude/skills/` and picks up added, edited or removed skills in the
  running session (SKILL.md text only). A fan-out run during a session
  changes that session's skills.
- **Symlinks**: a skill entry may be a symlink to a directory elsewhere;
  Claude Code loads it once even if several locations point at it. (The
  firecrawl skills in `~/.claude/skills/` on this Mac are symlinks into
  `~/.agents/skills/`, `ls -la` 2026-10-26: the fan-out must keep them,
  contract 3.4 "DEST/<name> is a symlink".)
- **Worktrees**: in a linked worktree, project skills are searched up to the
  worktree root; on 2.1.277+ a worktree without `.claude/skills` at its
  root loads the main checkout's project skills.
- **Sub-agents**: "Subagents with preloaded skills work differently: the
  full skill content is injected at startup." Which skill descriptions a
  general-purpose sub-agent sees: unknown (not stated on the page). Delegation prompts name the skills to invoke
  (user rule `delegation.md`, element 3).

### 5.2 Cursor

From cursor.com/docs/skills (chrome-devtools, 2026-10-26):

- **Locations**: project `.agents/skills/`, `.cursor/skills/`; user
  `~/.agents/skills/`, `~/.cursor/skills/`. "For compatibility, Cursor also
  loads skills from Claude and Codex directories: .claude/skills/,
  .codex/skills/, ~/.claude/skills/, and ~/.codex/skills/." The page does
  not say whether this covers the agent CLI as well as the IDE;
  `@reference/cursor-practices.md` "Rule Sources (Agent CLI)" says the CLI
  does not read `~/.claude/skills/` (date of that check unknown). Unknown.
- **Discovery**: "Cursor walks the skills root recursively and picks up any
  SKILL.md it finds"; nested project skills are scoped to their directory.
- **Duplicates**: with the Claude Code compatibility load, a harness skill
  can reach Cursor from `~/.cursor/skills/`, `~/.claude/skills/` and, inside
  aitools, `.claude/skills/`. How Cursor resolves the same name from several
  locations: unknown (not stated). This was already the case with
  `setup-user-skills`, which writes both directories.
- **Cloud**: `~/.cursor/skills/` stays local unless "Sync Skills for Cloud
  Agents" is on; `~/.agents/skills/` never syncs.

### 5.3 Where a skill goes (placement)

Revised `@.claude/rules/documentation-standards.md` "Skill placement"
(**planned: FO-7**): the source directory decides what the skill is written
for, not whether it is deployed (all three are deployed, S-1/S-2). Shared:
factual, project-agnostic, works in any repo. Project: aitools frameworks
and governance; may cite aitools paths if it says it works inside aitools
only. Dotprofile: the user's own. Names unique across the three.

## 6. Deployment

### 6.1 The pipeline

```
aitools shared/skills/<name>/      ─┐
aitools .claude/skills/<name>/     ─┼─ deploy-harness ─▶ ~/.aitools/skills/<name>/** ─┬─ setup-user-claude ─▶ ~/.claude/skills/<name>/**
<dotprofile>/claude/skills/<name>/ ─┘  first source wins  + .aitools-skills-manifest   └─ setup-user-cursor ─▶ ~/.cursor/skills/<name>/**
                                                                                     (fallback without ~/.aitools/skills: setup-user-skills, SKILL.md only)
```

### 6.2 Built vs planned

| Step | Today (origin/main 42ed67e + open PRs) | After the plan | Batch |
|------|------------------------------------------|----------------|-------|
| deploy-harness fills `~/.aitools/skills` | `shared/skills`, `.claude/skills` → `~/.aitools/skills/<name>/**`, first source wins, git-tracked files only, no deletion (`@reference/harness.md` "Deployed harness") | + dotprofile `claude/skills`; manifest `~/.aitools/skills/.aitools-skills-manifest` (`# aitools skills manifest v1`, `<name><TAB>shared\|aitools\|dotprofile\|retired`); retired skill directories backed up (`backup_dir`) and removed | FO-2 |
| something runs deploy-harness | Nothing on the dev path on main; installer Step 8b and first in `deploy_configs`: PR #106 (in the integration base) | same, merged | #106 (MERGE-ALL) |
| lib helpers | -- | `skill_name_kind`, `read_harness_manifest` (rules and skills), `fanout_text_equal`, `fanout_dir_matches`, tracker `removed` (sh and ps1) | FO-1 |
| lib fan-out | -- | `fanout_harness_skills TOOL DEST AITOOLS_REPO DOTPROFILE` / `Invoke-HarnessSkillsFanout` (contract 3.4) | FO-4 |
| Claude Code skills | `setup-user-skills`: `shared/skills` + dotprofile `claude/skills`, SKILL.md only, dotprofile wins | `setup-user-claude` calls the lib fan-out: summary tool `claude skills`; adopt target from the manifest source (`shared` → `<aitools>/shared/skills/...`, `aitools` → `<aitools>/.claude/skills/...`, `dotprofile` → `<dotprofile>/claude/skills/...`) when the file exists and the run is from a git checkout | FO-4 |
| Cursor skills | `setup-user-skills`, as above | `setup-user-cursor` step 5: summary tool `cursor skills`, no adopt | FO-5 |
| setup-user-skills | deploys to both tools; reverse discovery | when `~/.aitools/skills` exists: `OK skills n/a (fanned out from ~/.aitools/skills)`, no `claude skills` / `cursor skills` rows; reverse discovery kept, names in `~/.aitools/skills` not user-created; otherwise today's behaviour | FO-6 |
| MDM | `deploy/deploy-harness.*` embeds the harness sources (base64 snapshot); `deploy/setup-user-skills.*` embeds `shared/skills` SKILL.md files | + dotprofile skills in the snapshot (`add_source ... "$DOTPROFILE/..."` line parsed by build-deploy); the fan-out reaches MDM because build-deploy inlines the lib; the setup-user-skills generator keeps the fallback | FO-2, FO-4, FO-6 |
| CI | `tests/deploy-harness*` not in CI | every `tests/<dir>/test-*.sh` in CI, checked by a CI step; new `tests/fanout-lib`, `tests/skills-fanout` | FO-0, FO-1, FO-4, FO-5 |

### 6.3 Rules for deploying skills (contract 3.4, **planned: FO-4/FO-5**)

- Each regular file under `~/.aitools/skills/<name>/` (recursive, `*.bak.*`
  skipped) goes through `deploy_managed_file` / `Deploy-ManagedFile` to
  `DEST/<name>/<rel>`: one review menu, SOURCE is the source of truth
  (`@.claude/rules/managed-file-deployment.md`); the executable bit is
  copied from the harness copy.
- **Never overwrite what the fan-out does not own**: `DEST/<name>` that is a
  symlink or a plain file is kept (`log_warn` "Kept <name>: not a directory
  this fan-out owns", tracker `preserved`, one ACTION row). Every directory
  in DEST that was not deployed this run (third-party skills, `synced`) is
  `preserved`.
- **Retired skills**: `DEST/<name>` is removed only when every file in it
  matches `~/.aitools/skills/<name>` or one of its `.bak.*` backups
  (`fanout_dir_matches`), after `backup_dir` and a verified backup; tracker
  `removed`. Otherwise it is kept with an ACTION row "<Tool> still loads
  retired skills in <DEST>: <names> -- delete them unless you wrote them".
- **No manifest**: every skill fanned out, none retired, adopt not offered.
  Bad header: WARN + ACTION "Run aitools to rebuild ~/.aitools/skills and
  its manifest". Unreadable: ERROR `cannot read skills manifest`, fan-out
  continues.
- **No `~/.aitools/skills`**: `OK <tool> n/a (no harness skills)`, DEST
  untouched; `setup-user-skills` then deploys (S-4).
- **Backup**: `backup_dir DEST` once per non-dry run before the first write
  (`@.claude/rules/config-file-safety.md` "Directory deployment").
- **Abort**: `[x]abort` exits 2 from the library (no tool row); the runner's
  handling is `@reference/managed-file-deployment.md` "[x]abort".
- **Testing**: never run `aitools`, `setup-user-*`, `deploy-harness` or
  `build-deploy.sh` against the real `HOME` (`SC-mission-packet.md`
  section 5).

## 7. Project skills at user scope (S-1)

### 7.1 What changes

The 9 aitools `.claude/skills` (`audit`, `frameworks`, `glossary`,
`governed-data`, `harvest`, `incident`, `tool-eval`, `tool-ops`,
`tool-registry`) reach `~/.claude/skills/` and `~/.cursor/skills/` and are
listed in every repo on the machine (**planned: FO-4, FO-5**). After the
#74/#75 re-land (S-6) seven of them come from `shared/skills/` instead; the
cost below does not depend on which source they come from, only on the
deployment.

Inside aitools each of them exists twice (project `.claude/skills/` and
user `~/.claude/skills/`) until the commander removes the project copies.
Claude Code runs the user copy ("personal over project",
code.claude.com/docs/en/skills), so on a branch or worktree that edits a
project skill, Claude Code runs the **old** copy until the next `aitools`
run (plan risk R2). Whether the listing then shows one entry or two:
unknown (the page names which one runs, not the listing).

### 7.2 Measured cost

Measured on `origin/main` 42ed67e with `skill-cost.pl` (bytes of the
frontmatter `name` + `description` values; Claude Code puts the
description, capped at 1,536 characters, in context per skill; tokens
estimated at 4 bytes per token):

| Set | Skills | name + description | ~tokens | whole SKILL.md (loaded only when invoked) |
|-----|--------|--------------------|---------|-------------------------------------------|
| shared (already at user scope today) | 15 | 4,378 B | ~1,100 | 192,416 B |
| aitools project, new at user scope | 9 | 2,001 B | ~500 | 43,797 B |
| of which `audit` (`disable-model-invocation: true`: not in context) | 1 | 258 B | -- | 4,053 B |
| **added to every session in every repo by S-1** | 8 | **1,743 B** | **~440** | -- |
| all harness skills | 24 | 6,379 B | ~1,600 | 236,213 B |

Compared with rules: S-1's rules half adds about 79 KB (~20k tokens) every
session (`@reference/rules.md` section 7); the skills half adds about
1.7 KB (~440 tokens), because only descriptions load. The largest
descriptions: `tool-adopt` 506 B, `delegate` 442 B, `scratch` 359 B,
`mission-control` 334 B. No description is near the 1,536-character cap.
Cursor's cost: unknown (its docs do not say what is in context per skill;
it may see a skill from up to three locations, section 5.2).

### 7.3 Skills that cite repo-relative paths

A skill used outside aitools cannot open `registries/...`, `reference/...`,
`plans/...`, `scripts/...` or `.claude/rules/...` (plan risk R3). Counts of
distinct such paths in each SKILL.md body (`skill-cost.pl`; a mention in
prose counts, so this is an upper bound of what breaks):

| Skill | Source | Paths | Examples | Outside aitools |
|-------|--------|-------|----------|-----------------|
| audit | .claude | 5 | `registries/incidents.json`, `.claude/rules/*.md` | does not work |
| frameworks | .claude | 9 | `registries/framework-registry.json`, `reference/framework-*.md` | does not work |
| glossary | .claude | 4 | `registries/glossary.json`, `.claude/rules/glossary.md` | does not work |
| governed-data | .claude | 5 | `.claude/rules/governed-data-access.md`, `scripts/check-pre-commit.sh/.ps1` | does not work |
| harvest | .claude | 6 | `.claude/rules/artifact-harvesting.md`, `scripts/check-*.sh` | partly (the harvesting folder is per repo) |
| incident | .claude | 4 | `registries/incidents.json` | does not work |
| tool-eval | .claude | 5 | `reference/tool-evaluation-playbook.md`, `reference/evaluations/` | does not work (use `/aitool-eval`) |
| tool-ops | .claude | 7 | `registries/tool-ops.json`, `reference/tool-ops-*.md` | does not work (use `/aitool-ops`) |
| tool-registry | .claude | 6 | `registries/tool-registry.json`, `scripts/setup-` | does not work |
| tool-adopt | shared | 19 | `.claude/rules/tool-lifecycle.md`, `reference/evaluations/` | says "In the aitools repo: run every step" (line 56): partly |
| aitool-continue | shared | 6 | `.aitools/channel/handoffs/`, `reference/harness.md` | branches on the repo (by design) |
| handoff | shared | 6 | `plans/*/handoff-prompt.md`, `.aitools/channel/handoffs/` | relative to the current repo (by design) |
| intent-audit | shared | 8 | `registries/glossary.json`, `registries/incidents.json` | partly |
| aitool-eval, aitool-ops | shared | 5 each | `reference/tool-evaluation-*.md`, `reference/tool-ops-*.md` | reference cards: cite as provenance, content embedded |
| intent-writing, investigate, mission-control, optimize-plan, planning, scratch | shared | 1-3 | `reference/framework-adoption.md`, `scripts/ait-harvest.py`, `plans/*.md` | mostly prose pointers |
| a11y-debugging, chrome-devtools, delegate | shared | 0 | -- | works |

`~/.aitools/reference/` and `~/.aitools/registries/` hold copies of these
trees (`@reference/harness.md` "Deployed harness"), so a skill could cite
`~/.aitools/<path>` to work in any repo (read-only; writes must still go to
the aitools repo). No skill does that today; a decision for later (section 10).

## 8. Writing or changing a skill

1. Check whether a skill, rule or framework already covers it (`/frameworks`
   skill; `@.claude/rules/frameworks.md` "Governing principle").
2. Pick the source (section 5.3): shared, project (aitools), or dotprofile.
   Every one of them is deployed to user scope.
3. Pick the name: lowercase letters, digits, hyphens; equal to the
   directory; unique across the three sources, case-insensitive; not
   `synced`, not `anthropic-skills*`, no leading dot, no `.bak.`; not
   starting with `REPORT`, `SUMMARY`, `FINDINGS` or `ANALYSIS` if a delegate
   writes it (D-DEL1, applies to `*.md`).
4. Write `name` and `description` (key use case first; it is the part that
   is always in context, section 7.2). Use `disable-model-invocation: true`
   for a skill only the user should start (`/audit`).
5. Write the `## Intent` (`/intent-writing`), then the process. Put
   rationale in `reference/`. If the skill cites aitools paths, say it works
   inside aitools only, or cite `~/.aitools/<path>` for read-only lookups.
6. Add the trigger directive to the governing rule
   (`@reference/framework-three-layer-governance.md` "Rule-skill
   governance"); a skill for a framework also needs its detection hook spec
   (`@reference/framework-adoption.md` step 7).
7. Optional: `tests/expected-behaviors.md`.
8. Get review for every intent statement and every protected file the
   change touches (`@.claude/rules/sources-of-truth.md`; a skill's SKILL.md
   body is not in the protected table).
9. Ship: aitools skills by PR; dotprofile skills commit and push to the
   dotprofile's main (N-Q2). The deployed copies update on the next
   `aitools` run (section 6). A renamed or removed skill is retired: the
   harness copy and each tool's matching copy are backed up and removed
   (**planned: FO-2, FO-4, FO-5**).

## 9. Inside aitools (development)

- Edit the repo source, never `~/.claude/skills/` or `~/.aitools/skills/`:
  the next run shows a review menu for the deployed copy (accept & adopt
  writes the repo source; Cursor offers no adopt).
- Until the next `aitools` run Claude Code runs the old user-level copy of
  a project skill you edit (section 7.1). To test the edit, run the setup
  under an isolated `HOME`, or read the repo file directly.
- After accept & adopt in the Claude Code fan-out, `~/.aitools/skills/<name>`
  still holds the old text until deploy-harness runs again (FAN-PLAN risk
  R5 applies to skills); the next deploy-harness review then shows repo =
  adopted text, harness = old.

## 10. Gaps and contradictions found

Reported as `INCIDENT:` markers by S3-FanoutImpl-DocsScan (not filed):

- `@.claude/rules/documentation-standards.md` "Skill placement" says
  project skills are "not deployed" and "Never create same-name skills at
  both levels"; S-1 deploys them, so inside aitools every project skill is
  same-name at both levels (FX-71; rewrite **planned: FO-7**).
- `@.claude/rules/aitool-ops.md` and `@.claude/rules/aitool-eval.md` say
  `/tool-ops` and `/tool-eval` are "aitools repo only" and that the
  reference card is "the only available skill" in other repos; after S-1
  both full skills are listed everywhere and fail outside aitools.
- `@reference/managed-file-deployment.md` "Content Sources" says the
  dotprofile wins for skills (and `scripts/setup-user-skills.sh` does so
  today); S-3 makes `shared/` win. A dotprofile skill that shares a name
  with a shared skill stops reaching the tools and becomes an ERROR row on
  every run (behaviour change: see the commander question in the FO-7 PR).
- `@reference/cursor-practices.md` says the Cursor agent CLI does not read
  `~/.claude/skills/`; Cursor's docs (2026-10-26) say Cursor loads it for
  compatibility. Which is current for the CLI: unknown.
- `@reference/cursor-practices.md`, `@reference/tool-registry.md` and
  `shared/mcp/README.md` say `setup-user-mcp` deploys the skills; it has
  not since skills moved to `setup-user-skills` (`scripts/check-post-push.sh`
  comment "skills moved to setup-user-skills").
- `tests/expected-behaviors.md` in 7 skills has no governing spec (who runs
  it, when, format).
- Cursor duplicate resolution for one skill name seen in `~/.cursor/skills/`,
  `~/.claude/skills/` and `.claude/skills/`: unknown.
- Governed terms missing: `fan-out`, `retired`, `removed`, `harness files`,
  `trigger directive` (proposals: `S3-FanoutImpl-DocsScan-glossary.md`); the
  glossary's base artifact `skill` lists `.claude/skills/`, `shared/skills/`,
  `~/.claude/skills/` only.

## 11. Cross-references

- Rules counterpart: `@reference/rules.md`
- Layering and length: `@.claude/rules/documentation-standards.md`
- Rule-skill governance: `@reference/framework-three-layer-governance.md`
- Skill-as-capability: `@reference/framework-governed-data-access.md`, `@.claude/rules/governed-data-access.md`
- Reference cards: `@.claude/rules/aitool-ops.md`, `@.claude/rules/aitool-eval.md`
- Intent: `/intent-writing` skill
- Deployed harness and manifests: `@reference/harness.md`; `scripts/deploy-harness.sh` / `.ps1`
- Managed files: `@.claude/rules/managed-file-deployment.md`, `@reference/managed-file-deployment.md`
- Deployment paths: `@.claude/rules/deploy-paths.md`
- Plan: `@plans/skills-and-rules-fanout.md`
- Claude Code skill loading: `@reference/tool-ops-claude-code.md` item #29
- Cursor: `@reference/cursor-practices.md`, `@reference/tool-ops-cursor.md`
- Vocabulary: `/glossary` skill
