# Rules

**Intent**: **Purpose**: The single reference for harness rules: what a
rule is (governs how things are done; concise directives; points to the
matching skill that holds the process and to the reference that holds the
detail), the rule / skill / reference / registry layering, scope levels
(project, shared, dotprofile, user) and their deployment (deploy-harness →
`~/.aitools/rules` → setup-user-claude / setup-user-cursor fan-out), and the
commander's decision that all project-scope rules and skills are deployed to
user-scope Claude Code. **Scope**: Content inferred from what the repo
already documents — consolidate and cite, do not invent. NOT changing code.
NOT rewriting the source documents. **Audience**: Every agent writing or
deploying a rule, in any repo.

Version 1.0, 2026-10-26. Written by S3-RulesSpec for Session Commander
10cf255a-c. A version, not a draft (D-DEL5, 2026-10-26: in the user rule
`delegation.md` and the `/delegate` skill; the sources-of-truth review-after
change is pending). The intent above was
approved by the commander on 2026-10-26; like every intent statement it is
protected (`@.claude/rules/sources-of-truth.md` "Intent statements").

Every claim cites the file it comes from. "Today" means `origin/main` at
`072c744` (2026-10-26), with section 6.1 re-checked at `e03d490` (2026-10-27,
v0.74.0 scrub: #100, #106, #110 merged); "planned" means a plan or an open PR, named. Where
the repo does not say, this file says "unknown".

## 1. Decisions

| ID | Decision | Date | By | Source |
|----|----------|------|----|--------|
| R-1 | `shared/rules` (and `.claude/rules`, and the dotprofile `claude/rules`) deploy through deploy-harness into one flat `~/.aitools/rules`; setup-user-claude and setup-user-cursor fan them out to the tools. First source wins on a name conflict (`shared/`, then `.claude/`, then dotprofile `claude/rules/`); each skipped duplicate is `log_error` + an ERROR row. A rules manifest records each rule's source | 2026-10-22 | commander | `SC-mission-packet.md` section 6; `@reference/harness.md` "Deployed harness"; PR #100 (manifest) |
| R-2 | Cursor gets user-level rules only (shared + dotprofile; not the aitools `.claude/rules`) | 2026-10-22 | commander | HARNESS Q1 (`.aitools/channel/handoffs/2026-10-22_10cf255a-c.md` section G); PR #110 |
| R-3 | "Put aitools rules in the user space of claude code": the Claude Code fan-out takes every rule in `~/.aitools/rules`, source `aitools` included, minus the ones the manifest retires | 2026-10-22 | commander | `@plans/rules-fanout-claude.md` section 2, D1 and D5 |
| R-4 | All project-scope rules **and skills** are deployed to user-scope Claude Code. The commander removes the duplicate project-level Claude Code rules later | 2026-10-26 | commander | Mission RULES-SPEC launch prompt (Session Commander 10cf255a-c) |
| R-5 | Produced documents are versions, not drafts (D-DEL5: in the user rule `delegation.md` and the `/delegate` skill; the sources-of-truth review-after change is pending); this file is v1.0 | 2026-10-26 | commander | Mission RULES-SPEC launch prompt |

R-4's known cost is in section 7.

## 2. What a rule is

A rule **governs how something is done**. It is a short set of directives
that is in the agent's context whenever it applies, and it **points**:

- to the **skill** that holds the process (loaded on demand), through a
  trigger directive ("When to invoke /<skill>");
- to the **reference** that holds the detail (unlimited length);
- to the **registry** only through its skill, never by JSON path.

Sources: `@.claude/rules/documentation-standards.md` "Layered reference
architecture" (rules are "concise behavioral directives, ~40-100 lines";
references are "implementation detail, unlimited length"; "one authoritative
location per fact"); `@reference/framework-three-layer-governance.md`
"Rule-skill governance" ("Rules govern and enforce process; skills implement
it. Rules are always in context and contain trigger directives stating WHEN
to invoke their corresponding skill.").

What a rule is not:

- Not the process. Steps, menus and checklists live in the skill (a rule
  "states WHEN"; the skill "provides the governed process").
- Not the detail. Over ~20 lines of detail belongs in `reference/`
  (`@.claude/rules/documentation-standards.md` "Reference doc threshold").
- Not data. A rule "contains no data that can drift"
  (`@reference/framework-three-layer-governance.md` "Registry Convention");
  it never names a governed JSON path (`@.claude/rules/governed-data-access.md`).
- Not state. Rules are specs; out-of-spec code is an incident (`/incident`
  skill; `@.claude/rules/documentation-standards.md` "Specs vs state").

## 3. The layering: rule, skill, reference, registry

| Layer | Holds | Loaded | Lives in | Source |
|-------|-------|--------|----------|--------|
| Rule | Intent, governing principle, directives, trigger directive, cross-references | Always (or when a `paths:` glob matches, section 5) | `.claude/rules/`, `shared/rules/`, dotprofile `claude/rules/`, deployed `~/.claude/rules/` | `@.claude/rules/documentation-standards.md` |
| Skill | The governed process; the only access to governed data | On demand | `.claude/skills/`, `shared/skills/`, dotprofile `claude/skills/`, deployed `~/.claude/skills/` | `@reference/framework-governed-data-access.md` "Skill-as-capability pattern" |
| Reference | Implementation detail, rationale, origins | When read | `reference/` | `@.claude/rules/documentation-standards.md` |
| Registry | Structured data, source of truth (protected, governed) | Through its skill only | `registries/` | `@reference/framework-three-layer-governance.md` "Registry Convention" |

The registry pattern is three layers: rule (intent, always in context) +
JSON (data) + skill (access). `@.claude/rules/frameworks.md` "Three-layer
registry pattern". The registries and their skills are listed by the
`/frameworks` skill, not here.

Governance layers (`@reference/framework-three-layer-governance.md` "The
Three Layers"): rules and skills are **prevention**, hooks are
**detection**, `/audit` and `/incident` are **audit**. "A rule without a
trigger directive for its skill is a governance gap. A skill without a
corresponding rule trigger is ungoverned process." When a skill is created
as part of a framework, three artifacts are created together: the skill, the
trigger directive in the governing rule, and a detection hook spec
(`@reference/framework-adoption.md` step 7).

**Reference-card pattern (retired).** A user-level skill used to carry a
read-only, self-contained snapshot of project knowledge for use outside
aitools (`/aitool-ops`, `/aitool-eval`), each with a project trigger rule.
The LAYOUT PR-c re-land retired both cards and their rules: `/tool-ops` and
`/tool-eval` are user-level skills now, so they load in every repo and the
snapshots only drifted from their sources.

## 4. Anatomy of a rule

Built from the approved exemplars: `@.claude/rules/tool-lifecycle.md`,
`@.claude/rules/frameworks.md`, `@.claude/rules/glossary.md`,
`@shared/rules/scratch.md`, `@shared/rules/hook-lifecycle.md`, and the user
rule `delegation.md` (dotprofile `claude/rules/delegation.md`, deployed to
`~/.claude/rules/delegation.md`), which the mission names as the model of a
user rule.

1. **Frontmatter `paths:`** (optional). A list of globs; the rule applies when
   the agent works on matching files (section 5). 9 of the 24
   `.claude/rules/*.md` have it (recounted at `e03d490`) (`grep -L '^paths:'` lists the other
   17), plus `shared/rules/hook-lifecycle.md`.
2. **Title** `## <Name>`. Project rules in aitools end in "(this repo)"
   (every `.claude/rules/*.md`); shared and user rules do not
   (`shared/rules/*.md`, `delegation.md`). The suffix is a convention seen
   in the files; no rule mandates it.
3. **Intent block** `**Intent**: **Purpose**: ... **Scope**: ... NOT ...
   **Audience**: ...` right after the title (`/intent-writing` skill, "Style
   calibration"). Intent statements are protected: draft, present, write
   after approval (`@.claude/rules/sources-of-truth.md`). Not every rule has
   one yet (e.g. `@.claude/rules/deploy-paths.md`, `@.claude/rules/git-safety.md`).
4. **Decisions table** (`| ID | Decision | Date | By |`) when the rule
   records commander decisions (`delegation.md` D-DEL1..D-DEL4,
   `@shared/rules/hook-lifecycle.md` SD-2).
5. **Governing principle**: the one idea the rule enforces.
6. **Directives**: what to do and not do; tables where several cases apply.
7. **Trigger directive** `### When to invoke /<skill>`: "Invoke the `/<skill>`
   skill when ANY of these arise:" + a bullet list ending with the user
   naming the skill (`@.claude/rules/glossary.md`, `@.claude/rules/tool-ops.md`,
   `@.claude/rules/incident-governance.md`, `@shared/rules/scratch.md`).
8. **Enforcement** (optional): the prevention / detection / audit mechanisms
   and their state (`@shared/rules/scratch.md` "Enforcement").
9. **Cross-references**: skills by `/name`, files by `@path`.

Writing conventions (`@.claude/rules/documentation-standards.md` "`@` link
convention", "Function and library attribution"):

- In a rule, `@path` is **not** resolved by Claude Code; it is a plain-text
  pointer, used for grep-based link auditing. In `CLAUDE.md`, `@path` **is**
  resolved and pulls the file into context (Claude Code version dependency
  #18, `@reference/tool-ops-claude-code.md`). So detail goes behind `@` links
  in rules at no context cost.
- Cite functions by name and file, never line numbers.
- A path a rule cites must exist (pre-commit step 20, `scripts/check-path-refs.py`).
- No governed JSON paths (pre-commit step 16, `@.claude/rules/governed-data-access.md`).
- "Trigger directive" is the term for the "When to invoke" section. The
  governed term **trigger** alone means the event that starts the DTCC
  (`/glossary` skill), not this section.

A rule in a scope other than project (shared, dotprofile) writes aitools
paths as "aitools `<path>`", because it is read in any repo
(`@shared/rules/hook-lifecycle.md` "Paths below are relative to the aitools
clone").

## 5. Scopes

Scope modifiers compose with the base artifact `rule`
(`@reference/framework-governed-vocabulary.md` "Composition Convention";
`/glossary` skill):

| Scope | Where | What belongs there | Reaches Claude Code how (today) |
|-------|-------|--------------------|---------------------------------|
| project rule | `.claude/rules/*.md` in a repo | Conventions for that repo ("(this repo)") | Loaded by Claude Code from the repo directly |
| shared rule | aitools `shared/rules/*.md` | Harness rules for every agent in every repo (`scratch.md`, `hook-lifecycle.md`) | Not yet: only through the planned Claude fan-out (section 6) |
| dotprofile rule | `<userRepoPath>/claude/rules/*.md` | The user's personal rules (`delegation.md`, `concurrent-agents.md`) | setup-user-claude copies them to `~/.claude/rules/` |
| user rule | `~/.claude/rules/*.md` | Deployed copy; active in every project on the machine | — (it is the target) |

Cursor has its own scopes: project rules `.cursor/rules/*.mdc` (mirrors of
some `.claude/rules`, kept in step by `.cursor/rules/cursor-rule-parity.mdc`
and the "Rule Correspondence" table in `@reference/cursor-practices.md`), and
user rules in `~/.cursor/rules/*.mdc` written by the setup-user-cursor
fan-out.

How the tools load rules:

- **Claude Code**: user rules in `~/.claude/rules/` load in every project,
  before project rules, with no precedence on conflict; a rule without
  `paths:` loads every session; a user rule's `paths:` globs resolve against
  the session's primary working directory. Source:
  code.claude.com/docs/en/memory, read with WebFetch by S3-FanPlan-Ref on
  2026-10-26 (`@plans/rules-fanout-claude.md` section 8, R1). **UNVERIFIED**:
  not yet re-read with chrome-devtools (`@.claude/rules/web-sources.md`), and
  not yet in `@reference/tool-ops-claude-code.md` (draft item #28,
  `S3-FanPlan/S3-FanPlan-drafts/`).
- **Claude Code sub-agents** do not load project `.claude/rules/` or
  `CLAUDE.md` (version dependency #5, issue #29423); delegation prompts must
  carry the rules (user rule `delegation.md`, element 2).
- **Cursor** loads `<dir>/.cursor/rules/**/*.mdc` for the workspace and every
  ancestor directory, so `~/.cursor/rules` reaches every workspace under
  `$HOME`; `.md` files are ignored and a `.mdc` needs frontmatter (header
  comment of step 4 in `scripts/setup-user-cursor.sh`). The Cursor agent
  CLI does not read `.claude/rules/` (`@reference/cursor-practices.md` "Rule
  Sources"). Whether Claude Code loads an upper-case `.MD` rule is unknown
  (`@plans/rules-fanout-claude.md` R10).

Where a skill goes is decided the same way (`@.claude/rules/documentation-standards.md`
"Skill placement"): user-level skills are project-agnostic and factual;
project skills are project-specific; never the same skill name at both
levels. R-4 changes the deployment of project skills (section 7).

## 6. Deployment

### 6.1 The pipeline

```
aitools shared/rules/      ─┐
aitools .claude/rules/     ─┼─ deploy-harness ─▶ ~/.aitools/rules/ (flat, *.md) ─┬─ setup-user-claude ─▶ ~/.claude/rules/*.md
<dotprofile>/claude/rules/ ─┘   first source wins   + rules manifest              └─ setup-user-cursor ─▶ ~/.cursor/rules/*.mdc
```

| Step | Today (origin/main) | Planned |
|------|---------------------|---------|
| deploy-harness fills `~/.aitools/rules` | Implemented: `scripts/deploy-harness.sh/.ps1` (#88), `add_source rules` for `shared/rules`, `.claude/rules`, dotprofile `claude/rules` in that order; git-tracked files only, `*.bak.*` never, flat `*.md` only, case-insensitive conflicts (`@reference/harness.md` "Deployed harness"), implemented including the rules manifest `~/.aitools/rules/.aitools-rules-manifest` (`<name><TAB>shared\|aitools\|dotprofile\|retired`) and retired-rule removal (#100). MDM: generated `deploy/deploy-harness.*` (#93) | -- |
| Something runs deploy-harness | Installer Step 8b (`run_harness_step`, with `--skip-config` when Step 5 ran the writer) and the first entry of `deploy_configs` / `Deploy-Configs` (#106) | -- |
| Cursor fan-out | Implemented (#87, #110): converts the `shared` and `dotprofile` rules (not aitools `.claude/rules`, R-2) to `~/.cursor/rules/<name>.mdc` (`alwaysApply: true` without `paths:`, globs from `paths:` otherwise) and prunes retired ones against the manifest; adopt not offered | Every non-retired rule (reverses R-2's scope): open PR #123 |
| Claude fan-out | **Not implemented.** setup-user-claude deploys `<userRepoPath>/claude/rules/*.md` straight to `~/.claude/rules/` (additive, `deploy_managed_file`, adopt into the dotprofile) and never reads `~/.aitools/rules` (`scripts/setup-user-claude.sh` "rules deployment" span). MDM: rules embedded at build time (`@.claude/rules/deploy-paths.md`) | Fan out every non-retired `~/.aitools/rules/*.md` into `~/.claude/rules/`, adopt target mapped from the manifest source, retired copies pruned after a byte match and a verified backup, summary tool `claude rules`: `@plans/rules-fanout-claude.md` v1.0 (Batches A-D; gates #103, #112, #100, #106) |

### 6.2 Rules for deploying rules

- Deployed rules are Markdown managed files: `deploy_managed_file` /
  `Deploy-ManagedFile`, one review menu, SOURCE is the source of truth
  (`@.claude/rules/managed-file-deployment.md`; `@.claude/rules/agentic-standards.md`
  "Managed-file review choices and merge"). Directory deploys are additive:
  unmanaged files are preserved and logged (`@.claude/rules/config-file-safety.md`
  "Directory deployment").
- Adopt writes the repo file the rule came from, not the harness copy. A
  dotprofile adopt target is committed and pushed (N-Q2); an aitools adopt
  target is a working-tree change (`@.claude/rules/managed-file-deployment.md`
  "Adopt target"). The Cursor fan-out offers no adopt (converted copy).
- MDM run order: deploy-harness first, then the fan-out consumers; in the
  other order the fan-out reports `n/a (no harness rules)`
  (`@.claude/rules/deploy-paths.md` "MDM run order").
- Package path: the payload is the aitools tree at a pinned ref, run through
  the dev-path scripts, adopt not offered (`@.claude/rules/deploy-paths.md`
  item 3 and "Equivalence"; `@plans/build-package/design.md`).
- Never run `aitools`, `setup-user-*`, `deploy-harness` or `build-deploy.sh`
  against the real `HOME` when testing (`SC-mission-packet.md` section 5;
  #86).

## 7. Project rules and skills at user scope (R-3, R-4)

The decision: every aitools project rule and skill reaches user-scope Claude
Code. For rules, the mechanism is the planned Claude fan-out (section 6.1):
`.claude/rules` is already a deploy-harness source, and the fan-out takes
source `aitools` (`@plans/rules-fanout-claude.md` D5). The duplicate
project-level copies are removed by the commander later (R-4); until then
they stay in `.claude/rules/`.

**Known cost** (S3-FanPlan, `@plans/rules-fanout-claude.md` section 8 R1,
`S3-FanPlan/S3-FanPlan-report.md` summary line 5):

- 17 of the 26 `.claude/rules/*.md` and `shared/rules/scratch.md` had no
  `paths:` when S3-FanPlan measured: about **79 KB (79,048 bytes, roughly
  20k tokens) of "(this repo)" rules loaded in every session in every
  repo**. At `e03d490` there are 24 rule files, 15 without `paths:`; the
  byte count has not been re-measured.
- Inside aitools every project rule loads **twice** (project + user copy)
  until the duplicates are removed; in a worktree or branch that edits a
  rule, the user copy is stale until the next `aitools` run.
- The 9 scoped rules (`scripts/**`, `deploy/**`, ...) also fire in any other
  repo that has those paths.
- Rules that say "this repo" (e.g. `@.claude/rules/sources-of-truth.md`,
  `@.claude/rules/script-standards.md`) would read as governing every repo.
- A costed variant (skip source `aitools` in the Claude fan-out, as Cursor
  does) exists in R1; the decision is to fan out.

**Skills**: today `scripts/setup-user-skills.sh/.ps1` deploy `shared/skills/`
and the dotprofile `claude/skills/` to `~/.claude/skills/` and
`~/.cursor/skills/`; aitools `.claude/skills/` reach only `~/.aitools/skills/`
(deploy-harness), which no tool reads. SD-8 moves 7 governance skills to
`shared/skills/` (`@plans/tool-support-and-machine-profile.md` SD-8-ext).
How the rest of `.claude/skills/` reach `~/.claude/skills/` under R-4 has no
plan yet (unknown).

## 8. Writing or changing a rule

1. Check whether a rule, skill or framework already covers it (`/frameworks`
   skill; `@.claude/rules/frameworks.md` "Governing principle").
2. Pick the scope (section 5). Repo conventions: project rule. Every agent in
   every repo: shared rule (`shared/rules/`). The user's own: dotprofile rule.
3. Pick the file name: unique across `shared/rules`, `.claude/rules` and the
   dotprofile `claude/rules` (a duplicate name is an ERROR on every
   deploy-harness run, `@reference/harness.md` "Conflict handling"); not
   starting with `REPORT`, `SUMMARY`, `FINDINGS` or `ANALYSIS` if a delegate
   writes it (D-DEL1).
4. Decide `paths:`. Without it the rule loads in every session, and under
   R-3/R-4 in every repo (section 7).
5. Write the intent (`/intent-writing`), then the directives and the trigger
   directive for its skill; put detail in `reference/`, process in the skill.
6. Get review: every `.claude/rules/*.md` and every intent statement is
   protected (`@.claude/rules/sources-of-truth.md`).
7. Mirror to `.cursor/rules/*.mdc` where a twin exists
   (`@reference/cursor-practices.md` "Rule Correspondence").
8. Ship: `.claude/rules` and `shared/rules` changes ship by PR in aitools;
   dotprofile rules commit and push to the dotprofile's main (N-Q2). The
   deployed copies update on the next `aitools` run (section 6).

## 9. Gaps and contradictions found

Reported as `INCIDENT:` markers by S3-RulesSpec (not filed; `/incident` skill):

- `@reference/user-repo.md` "Scope guidance" says user-level rules should be
  universal and project rules belong in the project; R-3/R-4 contradict it
  (also `@plans/rules-fanout-claude.md` R1).
- `@.claude/rules/documentation-standards.md` "Skill placement" says
  project-level skills are "not deployed" and never same-name at both
  levels; R-4 deploys project skills to user scope.
- `@.claude/rules/managed-file-deployment.md` "Content sources" calls the
  dotprofile "Primary (wins if present)", while deploy-harness gives rules
  first-source-wins with the dotprofile last.
- `@reference/harness.md` "Not detected" says the fan-out in
  setup-user-claude handles conflicts in `~/.claude/rules/`; that fan-out
  does not exist on main.
- `@reference/cursor-practices.md` says Cursor user rules are UI/SQLite only
  and lists `.claude/rules/cursor-rule-parity.md`, which does not exist; #87 <!-- path-ref: ignore (cited because it is missing) -->
  writes `~/.cursor/rules/*.mdc`.
- `@reference/harness.md` cites an `/artifact-roles` skill that is in neither
  `shared/skills/` nor `.claude/skills/`.
- The Claude Code rule-loading facts in section 5 are UNVERIFIED (WebFetch,
  not chrome-devtools) and absent from `@reference/tool-ops-claude-code.md`.
- "Trigger" (governed: DTCC event) and "trigger directive" (the "When to
  invoke" section) are close; "trigger directive", "fan-out", "harness
  files", "retired" and "removed" are not governed terms. TODO(glossary).

## 10. Cross-references

- Layering and length: `@.claude/rules/documentation-standards.md`
- Three-layer governance, rule-skill governance: `@reference/framework-three-layer-governance.md`
- Registry pattern: `@.claude/rules/frameworks.md`; `/frameworks` skill
- Governed data access: `@.claude/rules/governed-data-access.md`, `@reference/framework-governed-data-access.md`
- Scope modifiers: `@reference/framework-governed-vocabulary.md`; `/glossary` skill
- Intent: `/intent-writing` skill, `@reference/framework-intent-documentation.md`
- Protected files: `@.claude/rules/sources-of-truth.md`
- Deployed harness: `@reference/harness.md`; `scripts/deploy-harness.sh` / `.ps1`
- Managed files: `@.claude/rules/managed-file-deployment.md`, `@reference/managed-file-deployment.md`
- Deployment paths: `@.claude/rules/deploy-paths.md`
- Claude fan-out plan: `@plans/rules-fanout-claude.md`
- Cursor: `@reference/cursor-practices.md`; `scripts/setup-user-cursor.sh` / `.ps1`
- Model user rule: dotprofile `claude/rules/delegation.md`
