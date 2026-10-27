# S3-FanoutImpl-DocsScan: inventory of doc statements the rules+skills fan-out makes false

Version 1.0, 2026-10-26. By S3-FanoutImpl-DocsScan (level 2, delegated by
S3-FanoutImpl, Session Commander 10cf255a-c). Input for the FO-7 writer
(`plans/skills-and-rules-fanout.md` v1.0 section 4 FO-7). Research only: no
repo file was edited.

## 0. How to use this file

- **Anchor.** Every "Current" block is verbatim from `origin/main` at
  `42ed67e` (fetched 2026-10-26). `feature/fanout-base` (d7f6855) changes
  none of these spans except `reference/managed-file-deployment.md`
  "[x]abort" (not a fan-out span). Re-run the sweep before writing:
  `bash /Users/new-jose/repos/aitools/.claude/worktrees/fo-orch/.scratch/session-fodocs/sweep.sh origin/main`
  (pattern list in the script; output of this run: `sweep-main.txt` beside it).
- **RECONCILE first (R14).** R2a, R2b, R2c, R3, R4 and #100's Manifest
  drafts were NOT on main at this read. Each row below names the RECONCILE
  step that rewrites the same span first. If that step has merged when FO-7
  is written, its NEW text is the OLD text for FO-7: re-anchor, keep the
  "New" content. The "New" texts below are the final state, so they hold
  whatever the intermediate wording was.
- **"New" assumes** FD-1..FD-9 and contract section 3 built (FO-0..FO-6
  merged), plus #100 (rules manifest), #106 (deploy-harness runs first),
  #110 (Cursor fan-out marker/prune) merged.
- **P** = protected (`.claude/rules/sources-of-truth.md`): `.claude/rules/*.md`,
  `.cursor/rules/*.mdc`, `CLAUDE.md`, `reference/harness.md`,
  `reference/user-repo.md`, `reference/managed-file-deployment.md`,
  `reference/tool-ops-*.md`, `reference/framework-*.md`,
  `registries/glossary.json`, every intent statement. FD-8: write as a
  version in the PR and list each P edit old -> new under "Review after".
- Draft source column: `FanPlan` = `S3-FanPlan/S3-FanPlan-drafts/...`;
  `Manifest` = `S3-H2-Manifest/S3-H2-Manifest-drafts/...` (on `feature/fanout-base`
  and #100's branch, not main).

## 1. Summary table

| # | File | Section | P | Change | Draft to reuse | RECONCILE first |
|---|------|---------|---|--------|----------------|-----------------|
| 1 | `.claude/rules/managed-file-deployment.md` | Deployment types, Markdown row | P | skill files: SKILL.md only -> every file of a skill dir | new | -- |
| 2 | same | Content sources, dotprofile row | P | "Primary (wins if present)" for user rules/skills is false | FanPlan Edit 3 (+skills) | R2a step 4 |
| 3 | same | Content sources, deploy-harness row | P | add dotprofile skills; rules AND skills fan out | new | R2a step 1 |
| 4 | same | Content sources, "Rules" bullet | P | Cursor: all minus retired (FD-2) | FanPlan Edit 1 (Cursor clause changed) | R2a step 2, Manifest |
| 5 | same | Content sources, "Skills" bullet | P | from `~/.aitools/skills`, all three sources | new | -- |
| 6 | same | Shared requirements item 4 | P | tracker `removed`, unknown -> failed | FanPlan Edit 2 (+skills) | -- |
| 1m-6m | `.cursor/rules/managed-file-deployment.mdc` | twins of 1-6 (one line each), plus the missing deploy-harness row | P | same | FanPlan `.mdc.md` Edits 1-4 | R2a steps 2-4 |
| 7 | `.claude/rules/deploy-paths.md` | MDM run order | P | both fan-outs present; skills too | FanPlan Edit 1 (+skills) | R4 |
| 8 | same | Scripts with deploy templates, setup-user-claude bullet | P | no rules fallback; skills fan-out | FanPlan Edit 2 | R4 |
| 9 | same | What IS auto-embedded, dotprofile rules bullet | P | delete | FanPlan Edit 3 | R4 |
| 10 | same | What IS auto-embedded, `shared/skills` bullet | P | fallback deployer only (FD-9) | new | -- |
| 11 | same | What IS auto-embedded, deploy-harness sources bullet | P | + `.claude/hooks`, + `<userRepoPath>/claude/skills` | R4 Q1b (+skills) | R4 step 2 |
| 7m-11m | `.cursor/rules/deploy-paths.mdc` | twins (one line each) | P | same | FanPlan `.mdc.md` Edits 1-3 | R4 |
| 12 | `.claude/rules/hook-rollout.md` | last paragraph | P | hook-lifecycle reaches both tools | FanPlan hook-rollout (+Cursor) | R3 step 1 |
| 13 | `.cursor/rules/hook-rollout.mdc` | line 32 | P | "(not yet deployed)" false | new | R3 step 2 |
| 14 | `shared/skills/scratch/SKILL.md` | Cross-references | no | "once deploy-harness ships a path" false | new | R3 step 3 |
| 15 | `.claude/rules/aitools-workspace.md` | User-scoped table, `rules/` row | P | manifest; Cursor converts; minus retired | new | R2b step 3 |
| 16 | same | User-scoped table, `skills/` row | P | + dotprofile, manifest, fan-out | new | -- |
| 17 | `.claude/rules/documentation-standards.md` | Skill placement | P | "not deployed", "never same-name at both levels" false (FX-71) | new | -- |
| 18 | same | Layered reference architecture | P | add `@reference/skills.md` pointer | new | -- |
| 19 | `.claude/rules/config-file-safety.md` | Directory deployment steps 1, 4 | P | example source; retired exception (rules and skills) | FanPlan config-file-safety (+skills) | -- |
| 20 | `.claude/rules/aitool-ops.md` | Skill taxonomy | P | `/tool-ops` "aitools repo only" / "/aitool-ops is the only available skill" false | new | -- |
| 21 | `.claude/rules/aitool-eval.md` | Skill taxonomy | P | same for `/tool-eval` | new | -- |
| 22 | `reference/managed-file-deployment.md` | file header line | P | consumers list | new | -- |
| 23 | same | Functions table | P | tracker `removed`; lib manifest/fan-out helpers | FanPlan Edit 1 (+FO-1/FO-4 functions) | -- |
| 24 | same | Caller Responsibilities, dotprofile bullet | P | "as setup-user-claude does today" | FanPlan Edit 2 | -- |
| 25 | same | Caller Responsibilities, return table | P | `removed` note | FanPlan Edit 5 | -- |
| 26 | same | Caller Responsibilities, "Several LOCALs for one SOURCE" | P | the two skill LOCALs now come from two scripts | new | -- |
| 27 | same | Markdown files: Files, Content source, Adopt target, Scripts | P | rules and skills from `~/.aitools`; adopt from manifest | FanPlan Edit 4 (+skills) | -- |
| 28 | same | Content Sources: intro, User rules row, Skills row | P | dotprofile no longer wins for skills; rules row | FanPlan Edit 3 / Manifest Edit 1 (+skills) | R2c steps 2-3 |
| 29 | same | Deployed harness table, skills row; manifests paragraph | P | + dotprofile skills; skills manifest | Manifest Edit 2 (+skills) | R2c step 1 |
| 30 | same | Shell Script Deployment Detail, reverse discovery | P | setup-user-skills fallback, harness names not user-created | new | -- |
| 31 | `reference/harness.md` | Components, Configuration | P | project content also at user scope (FD-1) | new | -- |
| 32 | same | Deployed harness table, skills row | P | + dotprofile `claude/skills/` | new | -- |
| 33 | same | "No deletion" bullet | P | retired rules AND skills removed | Manifest Edit 1 (+skills) | R2b step 2 |
| 34 | same | "Not detected" bullet | P | fan-outs' own copies; skills dirs | FanPlan Edit 1 (+skills) | R2b step 1 |
| 35 | same | (#100) "Rules manifest" Consumers bullet | P | Cursor no longer prunes `aitools` (FD-2) | FanPlan Edit 2 (Cursor clause changed) | R2b step 2 |
| 36 | same | new subsection "Skills manifest and retired skills" | P | contract 3.2 | new | -- |
| 37 | same | Cross-References | P | + `@reference/skills.md` | new | -- |
| 38 | `reference/user-repo.md` | Directory Structure lines 61-62 | P | via `~/.aitools` | FanPlan Edit 1 (+skills) | R5 (unrelated lines) |
| 39 | same | generated deploy scripts paragraph | P | no embedded rules | FanPlan Edit 2 | -- |
| 40 | same | User Rules Deployment body | P | fan-out | FanPlan Edit 3 | -- |
| 41 | same | Scope guidance + Build-time embedding | P | FD-1 rules and skills | FanPlan Edit 4 (FD-1 wording) | -- |
| 42 | same | new "User Skills Deployment" + What Stays `skills/` row | P | skills fan-out; row stale | new | -- |
| 43 | `reference/tool-ops-claude-code.md` | MEDIUM table, new items #28, #29 | P | user-rule and skill loading facts; re-read with chrome-devtools 2026-10-26 (now VERIFIED) | FanPlan tool-ops-claude-code (verified, extended) | -- |
| 44 | `reference/rules.md` v1.1 | R-2, sections 5, 6.1, 7, 9, FX-58 | intent only | per plan FO-7 bullet 2 | new | -- |
| 45 | `reference/script-standards-detail.md` | Governed summary outcomes | no (exemptions table only) | + `removed` (after glossary approval) | new | -- |
| 46 | `reference/framework-managed-file-deployment.md` | line 28 | P | "created, updated, or unchanged" (flag only) | new | -- |
| 47 | `reference/cursor-practices.md` | scopes table, Rule Sources, Skills | no | user rules files; skills locations; `setup-user-mcp` stale | new | R12 may touch |
| 48 | `reference/tool-registry.md` | Chrome DevTools MCP "Skills" | no (deprecated file) | "deployed by setup-user-mcp" stale twice over | new | -- |
| 49 | `shared/mcp/README.md` | Skills paragraph | no | same | new | -- |
| 50 | `shared/skills/aitool-continue/SKILL.md` | Orient, Per-repo awareness | no | "user-level skills only" now includes aitools project skills | new | -- |
| 51 | `shared/skills/aitool-ops/SKILL.md` | Cross-references line 358 | no | "(aitools repo only)" | new | -- |
| 52 | `CLAUDE.md` | How the harness is organized, `shared/` bullet | P (direct to main, FD-8) | skills now via `~/.aitools`, project skills too | new | -- |
| 53 | `reference/README.md` | index | no | + `skills.md` row | new | -- |
| 54 | `reference/framework-governed-vocabulary.md` | lines 59, 72 | P | skill locations (optional) | new | -- |
| 55 | glossary | 5 new terms + 2 facet updates | P | see `S3-FanoutImpl-DocsScan-glossary.md` | -- | -- |
| C1-C9 | script header comments | code batches own them | -- | verify in the code PRs, not FO-7 | -- | -- |

Counts: 55 doc rows (54 statements + the glossary row), 5 `.mdc` twin rows
(1m-6m, 7m-11m, 13; 13 is counted in the main list), 9 code-comment checks.
Protected files touched: 18 (`.claude/rules/managed-file-deployment.md`,
`.cursor/rules/managed-file-deployment.mdc`, `.claude/rules/deploy-paths.md`,
`.cursor/rules/deploy-paths.mdc`, `.claude/rules/hook-rollout.md`,
`.cursor/rules/hook-rollout.mdc`, `.claude/rules/aitools-workspace.md`,
`.claude/rules/documentation-standards.md`, `.claude/rules/config-file-safety.md`,
`.claude/rules/aitool-ops.md`, `.claude/rules/aitool-eval.md`,
`reference/managed-file-deployment.md`, `reference/harness.md`,
`reference/user-repo.md`, `reference/tool-ops-claude-code.md`,
`reference/framework-managed-file-deployment.md` (flag only),
`reference/framework-governed-vocabulary.md` (optional), `CLAUDE.md`) plus
`registries/glossary.json` and `.claude/rules/glossary.md` (through
`/glossary`), plus the new intent of `reference/skills.md`.

Not found (sweep returned no hits on main): "aitools-rules-manifest",
"aitools-skills-manifest", "no user-level rules", "fan out" (two words),
".aitools/skills" outside `reference/managed-file-deployment.md:415` and
`scripts/deploy-harness.sh:19`. The `n/a (no user-level rules)` text is on
#110's branch only (setup-user-cursor code), FO-5's to remove.

## 2. Items, verbatim

### 1. `.claude/rules/managed-file-deployment.md` -- Deployment types, Markdown row (P)

Current (line 19):

```
| Markdown | Interactive diff review via `deploy_managed_file` (SOURCE is the source of truth; one menu: overwrite / accept & adopt / merge & adopt / skip / abort) | CLAUDE.md, `~/.claude/rules/*.md`, skill SKILL.md files |
```

New:

```
| Markdown | Interactive diff review via `deploy_managed_file` (SOURCE is the source of truth; one menu: overwrite / accept & adopt / merge & adopt / skip / abort) | CLAUDE.md, `~/.claude/rules/*.md`, `~/.cursor/rules/*.mdc` (converted, no adopt), every file of a skill directory (`~/.claude/skills/<name>/**`, `~/.cursor/skills/<name>/**`) |
```

Why: FO-4/FO-5 deploy every regular file under `~/.aitools/skills/<name>/`
(contract 3.4 "deploy"), not only SKILL.md; today 7 skills have
`tests/expected-behaviors.md` (`git ls-tree -r origin/main shared/skills .claude/skills`).
Twin 1m: `.cursor/rules/managed-file-deployment.mdc` line 15, same cell.

### 2. same -- Content sources, dotprofile row (P)

Current (line 46; `.mdc` line 27 identical):

```
| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, user rules, profile.json (preferences, identity, machine profiles) |
```

New:

```
| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, profile.json (preferences, identity, machine profiles); user rules and user skills too, but through `~/.aitools` (row below), where `shared/` and `.claude/` win a name conflict |
```

Why: contract 3.2 / FD-4 (skills: first source wins, dotprofile last);
#100 / R-1 (rules). Today setup-user-skills makes the dotprofile win for
skills (`scripts/setup-user-skills.sh` header: "Dotprofile skills take
priority over shared"): the fan-out reverses that (see open question Q1).
R2a step 4 writes a rules-only version first.

### 3. same -- Content sources, deploy-harness row (P)

Current (line 48):

```
| aitools repo + dotprofile -> `~/.aitools/` (`deploy-harness`) | First source wins on a name conflict: `shared/`, then `.claude/`, then dotprofile `claude/rules/` | reference, registries, hooks, skills, rules (one flat directory), bin; config.json generated from profile.json. Rules reach the tools through the `setup-user-claude` / `setup-user-cursor` fan-out. Detail: `@reference/harness.md` "Deployed harness (`~/.aitools`)" |
```

New:

```
| aitools repo + dotprofile -> `~/.aitools/` (`deploy-harness`) | First source wins on a name conflict: `shared/`, then `.claude/`, then the dotprofile `claude/rules/` / `claude/skills/` | reference, registries, hooks, skills (one directory per skill), rules (one flat directory), bin, and a manifest for rules and one for skills; config.json generated from profile.json. Rules and skills reach the tools through the `setup-user-claude` / `setup-user-cursor` fan-outs: each tool gets every name except the retired ones. Detail: `@reference/harness.md` "Deployed harness (`~/.aitools`)", `@reference/rules.md`, `@reference/skills.md` |
```

Twin: the `.mdc` lacks this row (FanPlan `.mdc.md` Edit 1 adds it): add the
New row there.

### 4. same -- Content sources, "Rules" bullet (P)

Current (line 52; `.mdc` line 32 identical):

```
- **Rules**: additive deploy from `<userRepoPath>/claude/rules/` — managed files updated, unmanaged files in target preserved
```

New (FanPlan Edit 1 with the Cursor clause changed for FD-2):

```
- **Rules**: deploy-harness collects `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/` into `~/.aitools/rules/` (first source wins) and writes `~/.aitools/rules/.aitools-rules-manifest` (each rule's source, or `retired`). The fan-out consumers copy from there, every rule except the retired ones: `setup-user-claude` into `~/.claude/rules/` (adopt target: the rule's source file, when it is on the machine), `setup-user-cursor` into `~/.cursor/rules/` (converted to `.mdc`, no adopt). Both update managed files, preserve unmanaged files, and back up and remove their own copy of a retired rule. Detail: `@reference/harness.md` "Rules manifest and retired rules"
```

Note: FanPlan's draft says "`setup-user-cursor` the user-level ones": false
after FO-5 (FD-2). The Manifest draft's version of this bullet is superseded.

### 5. same -- Content sources, "Skills" bullet (P)

Current (line 53; `.mdc` line 33 identical):

```
- **Skills**: vendored from upstream in `shared/skills/`, deployed to `~/.claude/skills/` and `~/.cursor/skills/`
```

New:

```
- **Skills**: deploy-harness collects `shared/skills/`, `.claude/skills/` and `<userRepoPath>/claude/skills/` into `~/.aitools/skills/<name>/` (first source wins) and writes `~/.aitools/skills/.aitools-skills-manifest` (each skill's source, or `retired`). `setup-user-claude` fans out every non-retired skill directory to `~/.claude/skills/` (adopt target: the source file), `setup-user-cursor` to `~/.cursor/skills/` (no adopt). A skill directory the fan-out did not create (a user's own skill, a symlink) is never overwritten or removed. `setup-user-skills` deploys only when `~/.aitools/skills` does not exist (fallback) and keeps reverse discovery. Detail: `@reference/skills.md`
```

Why: FD-3, FD-4, FD-9, contract 3.2/3.4. "vendored from upstream" is
already false for 13 of the 15 shared skills (only `chrome-devtools`,
`a11y-debugging` are vendored, `reference/tool-registry.md` "Chrome DevTools MCP").

### 6. same -- Shared requirements item 4 (P)

Current (lines 74-78):

```
4. **Outcome tracking**: every deployment must resolve to
   created, updated, or unchanged — and report via `write_summary`.
   `deploy_managed_file` results (created, updated, verified, accept &
   adopt, skipped, failed) are recorded with the deploy tracker; `failed`
   is an ERROR row and the run continues with the next file.
```

New:

```
4. **Outcome tracking**: every deployment must resolve to
   created, updated, or unchanged — and report via `write_summary`.
   `deploy_managed_file` results (created, updated, verified, accept &
   adopt, skipped, failed) are recorded with the deploy tracker; `failed`
   is an ERROR row and the run continues with the next file. A fan-out
   consumer that backs up and deletes its copy of a retired rule or skill
   records `removed`; an outcome the tracker does not know is logged and
   counted as `failed`.
```

Twin 6m: `.mdc` line 43 (one line), same added sentence. Needs the glossary
term `removed` approved first (glossary file, FanPlan Q7).

### 7. `.claude/rules/deploy-paths.md` -- MDM run order (P)

Current (lines 59-64):

```
`deploy/deploy-harness.sh/.ps1` runs first: it fills `~/.aitools` (rules,
reference, registries, hooks, skills, bin, config.json), and the rules fan-out
in `setup-user-cursor` (and `setup-user-claude` once it fans out) reads
`~/.aitools/rules`. Run in the other order, the fan-out step reports
`n/a (no harness rules)` and deploys nothing.
```

New:

```
`deploy/deploy-harness.sh/.ps1` runs first: it fills `~/.aitools` (rules,
reference, registries, hooks, skills, bin, config.json), and the fan-outs in
`setup-user-claude` and `setup-user-cursor` read `~/.aitools/rules` and
`~/.aitools/skills` (the only way the dotprofile's `claude/rules` reaches an
endpoint). Run in the other order, the fan-out steps report
`n/a (no harness rules)` / `n/a (no harness skills)` and deploy no rules or
skills from the harness; `setup-user-skills` then deploys its embedded
skills as the fallback (FD-9).
```

Twin 7m (`.mdc` line 17, one line): same text joined into one line.
R4 rewrites the next paragraph area; this paragraph is untouched by R4.

### 8. same -- Scripts with deploy templates, setup-user-claude bullet (P)

Current:

```
- `setup-user-claude.sh/.ps1` (M3 B5): template interpolation, footer, managed-file
  deploy and rules logic are extracted from `scripts/`. `build-deploy.sh` adds only
  the profile/template source block (the live dotprofile on the machine wins, else
  the embedded build-time copies) and the rules fallback.
```

New:

```
- `setup-user-claude.sh/.ps1` (M3 B5): template interpolation, footer, managed-file
  deploy and the rules and skills fan-outs are extracted from `scripts/` (the skills
  fan-out is the library's `fanout_harness_skills` / `Invoke-HarnessSkillsFanout`,
  inlined with the lib). `build-deploy.sh` adds only the profile/template source
  block (the live dotprofile on the machine wins, else the embedded build-time
  copies); no rules are embedded.
```

Twin 8m: `.mdc` one-line bullet "- `setup-user-claude.sh/.ps1` (M3 B5): ... and the rules fallback." -> same text, one line.

### 9. same -- What IS auto-embedded, dotprofile rules bullet (P)

Current (`.md` and `.mdc` identical):

```
- `<userRepoPath>/claude/rules/*.md` → read at build time (the fallback rules)
```

New: delete the line (FanPlan Edit 3; FO-3 Batch C removes the embed).

### 10. same -- What IS auto-embedded, `shared/skills` bullet (P)

Current (`.md` and `.mdc` identical):

```
- `shared/skills/*.md` → read via `cat` at build time
```

New:

```
- `shared/skills/*/SKILL.md` → read at build time into `deploy/setup-user-skills.*`, the fallback deployer that runs only when `~/.aitools/skills` does not exist (FD-9); on an endpoint the skills normally arrive through `deploy/deploy-harness.*` and the fan-outs
```

Why: FO-6 keeps the generator; the old glob `shared/skills/*.md` was never
exact (`scripts/build-deploy.sh` "31-32. deploy/setup-user-skills.sh and
.ps1 (with dynamically embedded skills)"). If FO-6 also embeds dotprofile
skills, add them; verify in the FO-6 diff.

### 11. same -- What IS auto-embedded, deploy-harness sources bullet (P)

Current (`.md`; `.mdc` same text on one line):

```
- Every `scripts/deploy-harness.*` source (`reference/`, `registries/`,
  `shared/hooks`, `shared/skills`, `.claude/skills`, `shared/rules`,
  `.claude/rules`, `<userRepoPath>/claude/rules`, the bin CLIs) → its
```

New:

```
- Every `scripts/deploy-harness.*` source (`reference/`, `registries/`,
  `shared/hooks`, `.claude/hooks`, `shared/skills`, `.claude/skills`,
  `<userRepoPath>/claude/skills`, `shared/rules`, `.claude/rules`,
  `<userRepoPath>/claude/rules`, the bin CLIs) → its
```

`.claude/hooks` is R4 step 2 (Q1b); `<userRepoPath>/claude/skills` is FO-2
(contract 3.2 `add_source skills "dotprofile/skills" ...`). Reflow only these
lines.

### 12. `.claude/rules/hook-rollout.md` -- last paragraph (P)

Current (lines 109-112):

```
The hook lifecycle beyond rollout (source, deploy, adopt, user-created hooks,
retirement) is governed by the user-level rule `@shared/rules/hook-lifecycle.md`
(deployed to `~/.claude/rules/hook-lifecycle.md` once a deploy path for
`shared/rules/` exists).
```

New:

```
The hook lifecycle beyond rollout (source, deploy, adopt, user-created hooks,
retirement) is governed by the user-level rule `@shared/rules/hook-lifecycle.md`
(copied to `~/.aitools/rules/` by `deploy-harness`, then fanned out to
`~/.claude/rules/hook-lifecycle.md` by `setup-user-claude` and to
`~/.cursor/rules/hook-lifecycle.mdc` by `setup-user-cursor`).
```

FanPlan's draft names only Claude. R3 step 1 writes an interim text.

### 13. `.cursor/rules/hook-rollout.mdc` -- line 32 (P)

Current:

```
Hook lifecycle beyond rollout (source, deploy, adopt, retire): user-level rule `shared/rules/hook-lifecycle.md` (not yet deployed).
```

New:

```
Hook lifecycle beyond rollout (source, deploy, adopt, retire): user-level rule `shared/rules/hook-lifecycle.md` (deployed through `~/.aitools/rules/` to `~/.cursor/rules/hook-lifecycle.mdc` and `~/.claude/rules/hook-lifecycle.md`).
```

### 14. `shared/skills/scratch/SKILL.md` -- Cross-references (not P)

Current (lines 202-204):

```
- Governing rule: user rule `scratch.md` (source `shared/rules/scratch.md`
  in the aitools repo; deployed to `~/.claude/rules/` once
  deploy-harness ships a path for `shared/rules/`)
```

New:

```
- Governing rule: user rule `scratch.md` (source `shared/rules/scratch.md`
  in the aitools repo; copied to `~/.aitools/rules/` by deploy-harness and
  fanned out to `~/.claude/rules/` by setup-user-claude and to
  `~/.cursor/rules/scratch.mdc` by setup-user-cursor)
```

This file is itself a skill: the change reaches users through the skills
fan-out on the next `aitools` run.

### 15. `.claude/rules/aitools-workspace.md` -- User-scoped table, `rules/` row (P)

Current (line 54):

```
| `rules/` | Rules from `shared/rules/`, `.claude/rules/` and the dotprofile `claude/rules/`, one flat directory — deployed by `deploy-harness`; copied to each tool's rules location by `setup-user-claude` / `setup-user-cursor` |
```

New:

```
| `rules/` | Rules from `shared/rules/`, `.claude/rules/` and the dotprofile `claude/rules/`, one flat directory, plus `.aitools-rules-manifest` (each rule's source, or `retired`) — deployed by `deploy-harness`; every non-retired rule is copied to `~/.claude/rules/` by `setup-user-claude` and converted into `~/.cursor/rules/*.mdc` by `setup-user-cursor` |
```

Note: today's text is already the post-fan-out claim; R2b step 3 makes it
"today" first. No `.mdc` twin exists for this rule.

### 16. same -- User-scoped table, `skills/` row (P)

Current (line 55):

```
| `skills/` | Skill directories from `shared/skills/` and `.claude/skills/` — deployed by `deploy-harness` |
```

New:

```
| `skills/` | Skill directories from `shared/skills/`, `.claude/skills/` and the dotprofile `claude/skills/`, plus `.aitools-skills-manifest` (each skill's source, or `retired`) — deployed by `deploy-harness`; every non-retired skill is copied to `~/.claude/skills/` by `setup-user-claude` and to `~/.cursor/skills/` by `setup-user-cursor` |
```

R2b step 4 (`deploy-state/` row) is RECONCILE's, not FO-7's.

### 17. `.claude/rules/documentation-standards.md` -- Skill placement (P; FX-71)

Current (lines 78-93):

```
### Skill placement

- **User-level** (`shared/skills/` → deployed to `~/.claude/skills/`):
  managed tool patterns, project-agnostic conventions, USO enablement.
  Content must be factual (patterns, gotchas, platform behavior), not
  project-specific opinions.
- **Project-level** (`.claude/skills/` in repo): project-specific
  frameworks, governance workflows, development patterns. Auto-discovered
  by Claude Code, not deployed.
- **Split threshold**: A tool needs both user and project skills only
  when it serves two distinct personas (end user vs developer). Use
  `<name>` for user-level and `<name>-dev` for project-level.
- **No project overrides of user skills**: User-level takes priority
  in Claude Code. Never create same-name skills at both levels.
- Full inventory and architecture:
  `@plans/governance-and-compliance-framework.md`
```

New:

```
### Skill placement

Where a skill's source lives decides what it is written for, not where it
is deployed: every skill in `shared/skills/`, `.claude/skills/` and the
dotprofile `claude/skills/` is deployed to user scope (`~/.claude/skills/`,
`~/.cursor/skills/`) through `~/.aitools/skills` (commander, 2026-10-26).

- **Shared** (`shared/skills/`): managed tool patterns, project-agnostic
  conventions, USO enablement. Content must be factual (patterns, gotchas,
  platform behavior), not project-specific opinions, and must work in any
  repo (write aitools paths as "aitools `<path>`").
- **Project** (`.claude/skills/` in the aitools repo): aitools frameworks,
  governance workflows, development patterns. Deployed to user scope too,
  so it loads in every repo; it may cite aitools repo-relative paths only
  if it says it works inside aitools only.
- **Dotprofile** (`<userRepoPath>/claude/skills/`): the user's own skills.
- **Unique names**: a skill name must be unique across the three sources
  (a duplicate is an ERROR on every deploy-harness run; first source wins:
  shared, then project, then dotprofile). Inside aitools each project skill
  exists at both levels until the commander removes the project copies, and
  Claude Code runs the user-level copy, so a branch that edits a project
  skill sees the old copy until the next `aitools` run.
- **Split threshold**: A tool needs two skills only when it serves two
  distinct personas (end user vs developer). Use `<name>` for the shared
  skill and `<name>-dev` for the project one.
- Anatomy, scopes and deployment: `@reference/skills.md`; inventory and
  architecture: `@plans/governance-and-compliance-framework.md`
```

Why: FD-1, FD-3, FD-4; Claude Code "personal over project" (code.claude.com/docs/en/skills
"Same name in", read with chrome-devtools 2026-10-26). No twin: the `.mdc`
has no Skill placement section (`git grep -n "Skill placement" origin/main -- .cursor/rules` = 0).

### 18. same -- Layered reference architecture (P)

Current (lines 69-70):

```
- **Rules** (`.claude/rules/`) = concise behavioral directives, ~40-100 lines
  (what a rule is, its anatomy, scopes and deployment: `@reference/rules.md`)
```

New: add after it:

```
- **Skills** (`.claude/skills/`, `shared/skills/`) = the governed process,
  loaded on demand (what a skill is, its anatomy, scopes and deployment:
  `@reference/skills.md`)
```

Twin: `.cursor/rules/documentation-standards.mdc` lines 31-32 carry the
rules pointer; add the same skills line. Also `.claude/rules/frameworks.md`
"Cross-references" line 53 (`- Rules (anatomy, scopes, deployment): @reference/rules.md`):
add `- Skills (anatomy, scopes, deployment): @reference/skills.md` (P).

### 19. `.claude/rules/config-file-safety.md` -- Directory deployment (P)

Current (lines 106-110):

```
1. Declare managed scope in script header (e.g., `# Managed: ~/.claude/rules/*.md
   matching <userRepoPath>/claude/rules/`)
2. Back up target directory (see "Backup before overwrite")
3. For each source file: compare with target, add new, update changed (with diff
   logging), skip unchanged
4. Preserve unmanaged files (in target but not in source), log each
```

New:

```
1. Declare managed scope in script header (e.g., `# Managed: ~/.claude/rules/*.md
   fanned out from ~/.aitools/rules`)
2. Back up target directory (see "Backup before overwrite")
3. For each source file: compare with target, add new, update changed (with diff
   logging), skip unchanged
4. Preserve unmanaged files (in target but not in source), log each. One
   exception: a rule or skill directory the source retires (a `retired` line
   in the rules or skills manifest) is backed up and removed when it is the
   script's own copy (its content matches a harness copy or its backup); any
   other file or directory of that name is kept with a warning and an ACTION
   row
```

Twin: the `.mdc` "Directory deployment" item 2 ("preserve unmanaged files")
can take ", except the script's own copy of a retired rule or skill" (optional;
FanPlan Checks C15 chose no twin edit).

### 20. `.claude/rules/aitool-ops.md` -- Skill taxonomy (P; new finding)

Current (lines 18-26):

```
| Project (full CRUD) | `/tool-ops` | Read and write tool-ops.json | aitools repo only |
| User (portable) | `/aitool-ops` | Read-only reference card | Any repo (deployed to ~/.claude/skills/) |
| Framework | — | `reference/framework-tool-ops.md` | aitools repo only |

- In the aitools repo, `/tool-ops` is the primary skill (full CRUD).
  `/aitool-ops` is also available but redundant here.
- In any other repo, `/aitool-ops` is the only available skill.
  It provides enough operational knowledge for correct behavior
  without needing the aitools repo's source files.
```

New:

```
| Project (full CRUD) | `/tool-ops` | Read and write tool-ops.json | Listed in every repo (deployed to user scope, FD-1); works only inside the aitools repo (it reads aitools repo-relative paths) |
| User (portable) | `/aitool-ops` | Read-only reference card | Any repo (deployed to ~/.claude/skills/) |
| Framework | — | `reference/framework-tool-ops.md` | aitools repo only |

- In the aitools repo, `/tool-ops` is the primary skill (full CRUD).
  `/aitool-ops` is also available but redundant here.
- In any other repo, use `/aitool-ops`. `/tool-ops` is listed there too
  (every aitools project skill is deployed to user scope) but its paths
  (`registries/tool-ops.json`, `reference/tool-ops-*.md`) do not resolve
  outside the aitools repo.
```

Why: FD-1 deploys `.claude/skills/tool-ops` to `~/.claude/skills/`; measured
in `S3-FanoutImpl-DocsScan-skills-md.md` section 7.2. After #74/#75 re-land
(MERGE-ALL) `tool-ops` moves to `shared/skills/`: the row's tier label
"Project" then also changes (unknown which wording MERGE-ALL picks; re-read
at FO-7 time).

### 21. `.claude/rules/aitool-eval.md` -- Skill taxonomy (P; new finding)

Current (lines 19, 26-29):

```
| Project (full process) | `/tool-eval` | Full evaluation + registry hand-off | aitools repo only |
```

```
- In any other repo, `/aitool-eval` is the only available skill.
  It provides the full evaluation methodology (criteria, discovery
  playbook, health flags) without needing the aitools repo's source
  files.
```

New: same pattern as item 20 (`/tool-eval` listed in every repo, works only
inside aitools: it reads `reference/tool-evaluation-*.md`,
`.claude/rules/tool-*.md`, `reference/evaluations/`).

### 22. `reference/managed-file-deployment.md` -- header (P)

Current (lines 3-5):

```
Specification for the interactive file deployment system used by setup scripts
(`setup-user-claude`, `setup-user-skills`, `setup-user-hooks`, and the skill
blocks that `build-deploy.sh` generates).
```

New:

```
Specification for the interactive file deployment system used by setup scripts
(`deploy-harness`, `setup-user-claude`, `setup-user-cursor`, `setup-user-skills`
(fallback), `setup-user-hooks`, the library's skills fan-out, and the skill
blocks that `build-deploy.sh` generates).
```

### 23. same -- Functions table (P)

Current (lines 34-35):

```
| `Record-DeployOutcome` | `deploy_tracker_record` | Count one outcome (including `failed`) and write its DETAIL row |
| `Write-DeployTrackerSummary` | `deploy_tracker_summary` | Write the loop's summary row (ERROR when any file failed) |
```

New: FanPlan Edit 1's four rows, then (contract 3.3/3.4; names as FO-1/FO-4 ship them, verify in the merged lib):

```
| `Get-SkillNameKind` | `skill_name_kind` | Classify a name in `~/.aitools/skills`, case-insensitively: `hidden`, `backup` (`*.bak.*`), `skill` |
| `Read-HarnessManifest` | `read_harness_manifest` | Read the rules or skills manifest (`-Kind` / KIND `rules` or `skills`); `Read-RulesManifest` / `read_rules_manifest` wrap it |
| `Test-FanoutTextEqual` | `fanout_text_equal` | 0 equal ignoring trailing CR/LF, 1 differ, 2 unreadable |
| `Test-FanoutDirMatches` | `fanout_dir_matches` | 0 when every file of a deployed skill directory matches a harness copy (`*.bak.*` ignored) |
| `Invoke-HarnessSkillsFanout` | `fanout_harness_skills` | Fan `~/.aitools/skills` out to one tool's skills directory (Claude Code, Cursor): deploy, adopt mapping, retired prune, summary row |
```

### 24. same -- Caller Responsibilities, dotprofile bullet (P)

Current (lines 257-258): `repo is committed and pushed to the dotprofile's main automatically, as` / `` `setup-user-claude` does today for adopted and merged rules (kept). An ``
New: FanPlan Edit 2 verbatim (`... automatically (the library does it, `dotprofile_commit_push`; PR #103). An`).
Verify `dotprofile_commit_push` is the merged function name (#103 merged, b30167a).

### 25. same -- return-value table note (P)

FanPlan Edit 5 verbatim, with "a retired rule" -> "a retired rule or skill".

### 26. same -- "Several LOCALs for one SOURCE" (P)

Current (lines 261-264):

```
- **Several LOCALs for one SOURCE** (skills: `~/.claude/skills` and
  `~/.cursor/skills`): each LOCAL goes through `deploy_managed_file`. After
  an adopt into the first, the caller reads SOURCE again for the next, which
  then verifies. Callers do not copy one LOCAL to another.
```

New:

```
- **Several LOCALs for one SOURCE** (a harness rule or skill file and its
  Claude Code and Cursor copies): each LOCAL goes through
  `deploy_managed_file` in its own fan-out (`setup-user-claude`,
  `setup-user-cursor`). Only the Claude Code fan-out offers adopt; it writes
  the repo source, and `~/.aitools` keeps the old copy until the next
  `deploy-harness` run, so the Cursor copy follows one run later. In the
  fallback (`setup-user-skills`, no `~/.aitools/skills`) the old rule holds:
  after an adopt into the first LOCAL the caller reads SOURCE again for the
  next, which then verifies. Callers do not copy one LOCAL to another.
```

Why: contract 3.4 "adopt target" (Cursor passes `""`); FAN-PLAN risk R5
(stale harness copy after adopt) applies to skills too.

### 27. same -- Markdown files (P)

Current (lines 308, 314-318, 320-321, 335-337):

```
**Files**: CLAUDE.md, `~/.claude/rules/*.md`, skill `SKILL.md` files.
```
```
**Content source**: CLAUDE.md and rules from dotprofile repo (primary) or
`shared/claude-shared.md` (fallback). Skills from `shared/skills/`, or the
dotprofile's `claude/skills/` when it has the skill. Template tokens
(`{{PLACEHOLDER}}`) interpolated from `profile.json`. See
`@reference/user-repo.md` "Template Resolution" and "User Rules Deployment".
```
```
**Adopt target**: the file the content was read from (dotprofile or
`shared/`). Adopting into `shared/claude-shared.md` (a protected file) is
```
```
**Scripts**:
- `setup-user-claude.sh/.ps1` — CLAUDE.md + rules
- `setup-user-skills.sh/.ps1` — skill SKILL.md files
```

New:

```
**Files**: CLAUDE.md, `~/.claude/rules/*.md`, `~/.cursor/rules/*.mdc`, every file of a skill directory.
```
```
**Content source**: CLAUDE.md from dotprofile repo (primary) or
`shared/claude-shared.md` (fallback); rules from `~/.aitools/rules/` and
skills from `~/.aitools/skills/` (the fan-outs; first source wins there:
`shared/`, then `.claude/`, then the dotprofile). Without `~/.aitools/skills`
the fallback `setup-user-skills` deploys `shared/skills/`, or the dotprofile's
`claude/skills/` when it has the skill. Template tokens
(`{{PLACEHOLDER}}`) interpolated from `profile.json`. See
`@reference/user-repo.md` "Template Resolution", "User Rules Deployment" and
`@reference/skills.md`.
```
```
**Adopt target**: the file the content was read from (dotprofile or
`shared/`); for a rule or skill file from the fan-out, the source file the
manifest names (none without a manifest, none for Cursor). Adopting into `shared/claude-shared.md` (a protected file) is
```
```
**Scripts**:
- `setup-user-claude.sh/.ps1` — CLAUDE.md, the rules fan-out, the skills fan-out (`claude skills`)
- `setup-user-cursor.sh/.ps1` — the rules fan-out (converted `.mdc`), the skills fan-out (`cursor skills`)
- `setup-user-skills.sh/.ps1` — fallback skill deployer (SKILL.md only) when `~/.aitools/skills` does not exist; reverse discovery
- `deploy-harness.sh/.ps1` — `~/.aitools/**` (`harness files`)
```

### 28. same -- Content Sources (P)

Current (lines 383-384, 389, 395):

```
Deployed content originates from two repos. The dotprofile repo takes
priority when present; the aitools `shared/` directory is the fallback.
```
```
| User rules | `<userRepoPath>/claude/rules/*.md` | (none — no rules deployed) |
```
```
| Skills | `<userRepoPath>/claude/skills/*/SKILL.md` when present | `shared/skills/*/SKILL.md` |
```

New:

```
Deployed content originates from two repos. For templates and profile
values the dotprofile repo takes priority when present and the aitools
`shared/` directory is the fallback. Rules and skills are the exception:
they go through `~/.aitools`, where the first source wins (`shared/`, then
`.claude/`, then the dotprofile).
```
```
| User rules | `~/.aitools/rules/*.md` (deploy-harness fills it from `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/`, first source wins); `setup-user-claude` and `setup-user-cursor` take every non-retired rule | (none — `~/.aitools/rules` absent: no rules deployed, target untouched) |
```
```
| Skills | `~/.aitools/skills/<name>/**` (deploy-harness fills it from `shared/skills/`, `.claude/skills/` and `<userRepoPath>/claude/skills/`, first source wins); `setup-user-claude` and `setup-user-cursor` take every non-retired skill | `setup-user-skills` when `~/.aitools/skills` is absent: `<userRepoPath>/claude/skills/*/SKILL.md` when present, else `shared/skills/*/SKILL.md` |
```

R2c step 2-3 (Manifest Edit 1 + MDM cell) rewrite the User rules row first;
its MDM cell "(dev path: none; MDM path: the build-time copy ...)" is
removed by FO-3 Batch C, so the New above holds.

### 29. same -- Deployed harness (P)

Current (line 415): `` | `~/.aitools/skills/<name>/` | `shared/skills/`, `.claude/skills/` | ``
New: `` | `~/.aitools/skills/<name>/` (+ `.aitools-skills-manifest`) | `shared/skills/`, `.claude/skills/`, `<userRepoPath>/claude/skills/` | ``
and line 416 rules row: append `(+ .aitools-rules-manifest)`.
Plus Manifest Edit 2's "Script-owned text: the rules manifest" paragraph
(R2c step 2) extended: "...the rules manifest and the skills manifest.
deploy-harness writes `~/.aitools/rules/.aitools-rules-manifest` and
`~/.aitools/skills/.aitools-skills-manifest` ... retired rules and skill
directories are backed up and removed by deploy-harness and by the fan-out
consumers. Format and rules: `@reference/harness.md` "Rules manifest and
retired rules", "Skills manifest and retired skills"."

### 30. same -- reverse discovery (P)

Current (lines 484-486):

```
conflict with SD-2, which covers manifest hooks only. `setup-user-skills`
does the same for user-created skills (target
`<userRepoPath>/claude/skills/<name>/SKILL.md`). Prompts, non-interactive
```

New:

```
conflict with SD-2, which covers manifest hooks only. `setup-user-skills`
does the same for user-created skills (target
`<userRepoPath>/claude/skills/<name>/SKILL.md`); a name in `~/.aitools/skills`
or its manifest is never treated as user-created (FD-9). Prompts, non-interactive
```

### 31. `reference/harness.md` -- Components, Configuration (P)

Current:

```
- User (`~/.claude/rules/`, `~/.claude/skills/`, `~/.claude/hooks/`,
  user claude, user settings) — preferences and governance that
  follow the developer across all projects
```

New: append a line after the list:

```
aitools' own project rules and skills are also deployed at user scope
(commander, 2026-10-26: `@reference/rules.md` R-4, `@reference/skills.md`),
so they load in every repo on the machine; inside aitools they exist at
both scopes until the project copies are removed.
```

### 32. same -- Deployed harness table, skills row (P)

Current: `` | `skills/` | `shared/skills/`, `.claude/skills/` | one directory per skill | skill directory name | ``
New: `` | `skills/` | `shared/skills/`, `.claude/skills/`, `<dotprofile>/claude/skills/` | one directory per skill | skill directory name | ``

### 33. same -- "No deletion" bullet (P)

Current:

```
- **No deletion.** A file in `~/.aitools` with no source (a renamed or
  removed source, a file the user added) is preserved and logged on
  every run.
```

New (Manifest Edit 1 extended):

```
- **No deletion, except retired rules and skills.** A file in `~/.aitools`
  with no source (a renamed or removed source, a file the user added) is
  preserved and logged on every run. The exceptions are a rule the rules
  manifest retires and a skill directory the skills manifest retires (next
  sections): each is backed up and removed.
```

### 34. same -- "Not detected" bullet (P)

Current:

```
- **Not detected**: the same content under two different names; a name
  shared across kinds (a skill and a rule both called `scratch`, which
  land in different directories); conflicts with files already in a
  tool's own location (`~/.claude/rules/`), which the fan-out in
  `setup-user-claude` / `setup-user-cursor` handles.
```

New:

```
- **Not detected**: the same content under two different names; a name
  shared across kinds (a skill and a rule both called `scratch`, which
  land in different directories); conflicts with files already in a
  tool's own location (`~/.claude/rules/`, `~/.cursor/rules/`,
  `~/.claude/skills/`, `~/.cursor/skills/`). The fan-outs in
  `setup-user-claude` and `setup-user-cursor` treat such a file or skill
  directory as theirs only when it matches a harness copy (Cursor rules:
  its fan-out marker); they update or remove their own copies and preserve
  every other file, and never write into a skill entry that is a symlink or
  a plain file.
```

### 35. same -- (#100) "Rules manifest" subsection, Consumers bullet (P)

Current: not on main; #100's draft text (Manifest `reference/harness.md` Edit 2):

```
- **Consumers** take every non-retired name they are entitled to, and
  back up and remove their own deployed copy of every `retired` name.
  Cursor takes user-level rules only, so it also removes its copies of
  names whose source is `aitools`.
```

New:

```
- **Consumers** (`setup-user-claude`, `setup-user-cursor`) take every
  non-retired rule (all three sources; without a manifest, every rule, and
  nothing is removed) and back up and remove their own deployed copy of
  every `retired` name. `setup-user-claude` uses the source to find the
  adopt target; Cursor offers no adopt. A consumer recognises its own copy
  of a retired rule by content (Claude Code: the same bytes as
  `~/.aitools/rules/<name>` or one of its `.bak.*` backups) or by its
  fan-out marker (Cursor).
```

FD-2 reverses #110's "user-level only"; FanPlan's draft still says Cursor
removes `aitools` copies: false after FO-5.

### 36. same -- new subsection "Skills manifest and retired skills" (P)

Insert after "Rules manifest and retired rules" (contract 3.2, verbatim
facts; verify against the FO-2 code):

```
### Skills manifest and retired skills

deploy-harness writes `~/.aitools/skills/.aitools-skills-manifest` after the
deploy loop (sole owner; temp file then move), in the same way as the rules
manifest.

- **Format v1**: UTF-8, LF, first line `# aitools skills manifest v1`, then
  `<skill name><TAB><source>` sorted by name (byte order). Source: `shared`
  (aitools `shared/skills/`), `aitools` (aitools `.claude/skills/`),
  `dotprofile` (`<dotprofile>/claude/skills/`) or `retired`. A valid name
  has no `/` or `\`, does not start with `.` and has no `.bak.`.
- **Retiring.** A name in the previous manifest that no source has this
  run becomes `retired`; only a source listed this run retires its names,
  and listing is per kind (a listed dotprofile rules source does not retire
  dotprofile skills). The skill directory `~/.aitools/skills/<name>/` is
  backed up with `backup_dir()` (`<name>.bak.<UTC>/` beside it), the backup
  is verified, then the directory is removed; a failure is `log_error` + an
  ERROR row and the directory stays.
- **A skill that moves source** (e.g. from `.claude/skills/` to
  `shared/skills/`) changes its manifest source and is not retired.
- **Preserved scan** ignores the manifest, its temp file and every path
  with a `*.bak.*` component.
- **Consumers**: the library's `fanout_harness_skills` /
  `Invoke-HarnessSkillsFanout`, called by `setup-user-claude` (`claude skills`)
  and `setup-user-cursor` (`cursor skills`). Detail: `@reference/skills.md`.
```

### 37. same -- Cross-References (P)

Add: `- Skills, their scopes and the skills fan-out: @reference/skills.md`
(after the existing rules.md line).

### 38-42. `reference/user-repo.md` (P)

38. Current (lines 61-62):

```
│   ├── rules/             # User-level Claude Code rules (deployed to ~/.claude/rules/)
│   └── skills/            # User-level skill overrides (deployed to ~/.claude/skills/)
```

New:

```
│   ├── rules/             # User-level rules (via ~/.aitools/rules to ~/.claude/rules/ and ~/.cursor/rules/)
│   └── skills/            # User-level skills (via ~/.aitools/skills to ~/.claude/skills/ and ~/.cursor/skills/; shared/ and .claude/ win a name conflict)
```

"overrides" is false after FD-4 (first source wins, dotprofile last).

39. Current (lines 431-433): `` point `AITOOLS_PROFILE_SH` / `AITOOLS_PROFILE_PS1` at it. `setup-user-claude` also `` / ``embeds the build-time template, rules and a snapshot of `profile.json` (`aitools-json.pl``
New: FanPlan Edit 2 verbatim (drop "rules").

40. Current (lines 446-454, the section body above "**Scope guidance**", verbatim in FanPlan Edit 3 OLD, matches main). New: FanPlan Edit 3 NEW, plus in its first paragraph "`setup-user-claude` then fans out" -> "`setup-user-claude` and `setup-user-cursor` then fan out ... to `~/.claude/rules/` (and `~/.cursor/rules/*.mdc`)".

41. Current (lines 456-460):

```
**Scope guidance**: user-level rules should be universal conventions that apply across all projects. Project-specific rules belong in `.claude/rules/` within the project repo.

**Build-time embedding**: `build-deploy.sh` embeds the dotprofile's rules at build time
as the fallback for a machine without the dotprofile; a machine with the dotprofile
deploys its own `claude/rules/`. If no rules exist at build time, the fallback is empty.
```

New:

```
**Scope guidance**: rules in the dotprofile's `claude/rules/` should be universal conventions that apply across all projects. aitools' own `.claude/rules/` and `.claude/skills/` are deployed to user scope too (commander, 2026-10-26: "ALL project-scope rules AND skills are deployed to user-scope Claude Code"), so they also load in every project on the machine; the cost is in `@reference/rules.md` section 7 and `@reference/skills.md`.

**MDM**: the generated `deploy/setup-user-claude.*` embed no rules. `deploy/deploy-harness.*`
embeds the build-time dotprofile's `claude/rules/` and `claude/skills/` in its snapshot and fills
`~/.aitools/`; run it before `setup-user-claude` and `setup-user-cursor`.
```

FanPlan Edit 4 cited D5 (2026-10-22, rules only); FD-1 (2026-10-26) is the
newer, wider decision.

42. Add after "User Rules Deployment":

```
## User Skills Deployment

The dotprofile's `claude/skills/<name>/` reach the tools like rules:
`deploy-harness` copies them, after aitools `shared/skills/` and
`.claude/skills/` (first source wins), into `~/.aitools/skills/` and writes
the skills manifest; `setup-user-claude` fans them out to `~/.claude/skills/`
(adopt target: the dotprofile file, committed and pushed) and
`setup-user-cursor` to `~/.cursor/skills/` (no adopt). Without
`~/.aitools/skills`, `setup-user-skills` deploys them directly (fallback).
Detail: `@reference/skills.md`.
```

And "What Stays in aitools/shared/" row: current
`` | `skills/` | Chrome DevTools / a11y skills | Vendored from upstream | ``
(pre-existing drift: 15 skills, 2 vendored) -> `` | `skills/` | Harness skills for every repo (2 vendored from upstream: chrome-devtools, a11y-debugging) | Framework process, not personal | ``.

### 43. `reference/tool-ops-claude-code.md` -- new items #28, #29 (P)

FanPlan's #28 was UNVERIFIED (WebFetch). Re-read with chrome-devtools on
2026-10-26 (Claude Code 2.1.309 installed): https://code.claude.com/docs/en/memory
"User-level rules", "Path-specific rules", "Rule frontmatter reference";
https://code.claude.com/docs/en/skills "Choose where skills load",
"Same name in", "Frontmatter reference", invocation table. Page dumps:
`/Users/new-jose/repos/aitools/.claude/worktrees/fo-orch/.scratch/session-fodocs/cc-memory-page.txt`,
`cc-skills-page.txt`. Item numbers: main's highest is #27; re-check.

```
| 28 | User-level rules (`~/.claude/rules/`): apply to every project on the machine; loaded before project rules, and neither set overrides the other (on conflict Claude may follow either); a rule without `paths:` loads at launch; a user rule's `paths:` globs resolve against the session's primary working directory; `paths` is the only frontmatter field read; frontmatter that does not parse loads the rule as if it had no `paths`. Unknown: recursion into subdirectories at user level (project rules are discovered recursively), case of the `.md` extension | 2.1.309 | 2.1.309 (2026-10-26, docs read with chrome-devtools) | `scripts/setup-user-claude.sh/.ps1` (rules fan-out), `scripts/deploy-harness.sh/.ps1`, `reference/rules.md` | -- (code.claude.com/docs/en/memory) |
| 29 | Skills (`~/.claude/skills/<name>/SKILL.md` personal, `.claude/skills/` project): a same-named skill runs personal over project; only `description` (+ `when_to_use`, together capped at 1,536 characters) is in context per skill, the body loads when invoked; `disable-model-invocation: true` keeps the description out of context; a skill entry may be a symlink to a directory; `synced` is a reserved folder name (`~/.claude/skills/synced/` holds claude.ai skills); file changes under `~/.claude/skills/` are picked up in the running session (SKILL.md text only); in a linked worktree without `.claude/skills` at its root, the main checkout's project skills load (2.1.277+) | 2.1.309 | 2.1.309 (2026-10-26, docs read with chrome-devtools) | `scripts/aitools-lib.sh/.ps1` (`fanout_harness_skills`), `scripts/setup-user-claude.sh/.ps1`, `scripts/deploy-harness.sh/.ps1`, `reference/skills.md` | -- (code.claude.com/docs/en/skills) |
```

"Since" is unknown for every clause; 2.1.309 is the version the docs were
read against, not the first version (say so in the row, or put "unknown").

### 44. `reference/rules.md` v1.1 (intent protected; body not in the protected table)

Edits (plan FO-7 bullet 2), current text verbatim from main:

- R-2 row: `| R-2 | Cursor gets user-level rules only (shared + dotprofile; not the aitools `.claude/rules`) | 2026-10-22 | commander | HARNESS Q1 (...); PR #110 |`
  -> keep the row, mark it "Superseded by R-6", add
  `| R-6 | Cursor gets every rule in ~/.aitools/rules minus retired (shared, aitools, dotprofile); reverses R-2's filter, keeps #110's marker and prune safety | 2026-10-26 | commander | RECONCILE Q3; plans/skills-and-rules-fanout.md FD-2 |`
  and `| R-7 | Skills deploy like rules: ~/.aitools/skills -> fan-out; reference/skills.md | 2026-10-26 | commander | plans/skills-and-rules-fanout.md FD-3, FD-4 |`. Version line -> `Version 1.1, <date>`; "Today" anchor -> the merge SHA of FO-6.
- Section 5 table, shared rule row cell `Not yet: only through the planned Claude fan-out (section 6)` -> `deploy-harness -> ~/.aitools/rules -> setup-user-claude fan-out`; dotprofile row `setup-user-claude copies them to ~/.claude/rules/` -> `through ~/.aitools/rules and the setup-user-claude fan-out`; add a project rule note "and, for aitools, the same fan-out (R-3/R-4)".
- Section 5 "How the tools load rules", Claude Code bullet: drop "**UNVERIFIED** ... draft item #28" -> "Verified with chrome-devtools 2026-10-26 (`@reference/tool-ops-claude-code.md` item #28)".
- Section 5 last paragraph ("Where a skill goes ... never the same skill name at both levels. R-4 changes ...") -> "Where a skill goes, how skills are deployed and what they cost: `@reference/skills.md`."
- FX-58 sentence, section 5 after the Cursor bullet: "Claude Code resolves a user rule's `paths:` against the session's primary working directory; Cursor matches a user rule's `globs:` against the path relative to `$HOME` (the directory that owns `~/.cursor/rules`), so the fan-out rewrites each relative pattern as `**/<pattern>` (`@reference/tool-ops-cursor.md` "Glob anchoring"). The same rule therefore scopes slightly differently in the two tools: `**/scripts/**` also matches a `scripts/` nested deeper in the repo."
- Section 6.1: diagram `+ rules manifest (planned)` -> `+ rules manifest`; table: every "Planned" cell moves to "Today" with the PR/merge SHA (#100, #106, #110 + FO-5, FO-3); Cursor row text "User-level rules only (R-2)" -> "every rule minus retired (R-6, FO-5)".
- Section 7 "**Skills**: today ... has no plan yet (unknown)." -> "**Skills**: deployed the same way (R-7): `@reference/skills.md`, with the measured cost of project skills at user scope (about 2 KB of descriptions, section 7 there)."
- Section 9: resolve the user-repo, Skill placement, Primary (wins), harness "Not detected" bullets (items 2, 17, 34, 38-41 above), the UNVERIFIED bullet (item 43); carry the cursor-practices, `/artifact-roles` and glossary bullets (unless FO-7 lands the glossary terms).
- Section 10: + `Skills: @reference/skills.md`.

### 45. `reference/script-standards-detail.md` -- Governed summary outcomes (not P)

Current (lines 316-323): table with `verified`, `updated`, `created`,
`configured`, `accepted`, `n/a (<environment>)`.
New: add after `accepted`:

```
| `"removed"` | A deployed copy backed up and deleted because its source retired it | Fan-out consumers pruning a retired rule or skill (`deploy_tracker_record removed`); the summary counts `N removed` |
```

Only after the glossary term `removed` is approved (glossary file).

### 46. `reference/framework-managed-file-deployment.md` line 28 (P; flag only)

Current: `updated, or unchanged — no silent ambiguity` (the preceding line
holds "created,"). It predates `verified` and does not know `removed`. Not a
fan-out claim; list for the commander, do not edit in FO-7 unless he says so.

### 47. `reference/cursor-practices.md` (not P)

- Line 14: `| User rules | Cursor Settings > Rules | No (local to machine) |` -> add a row `| User rule files | ~/.cursor/rules/*.mdc (written by the setup-user-cursor fan-out; loaded because ~ is an ancestor of the workspace) | No (local to machine) |`.
- Line 130: `| User skills | ~/.cursor/skills/*/SKILL.md | Our deployed skills land here |` -> `... | The setup-user-cursor skills fan-out writes here (every skill in ~/.aitools/skills minus retired) |`.
- Line 133: `**Not read by agent CLI:** ~/.claude/CLAUDE.md, ~/.claude/skills/, .claude/rules/.` -> contradicted for skills by cursor.com/docs/skills (read with chrome-devtools 2026-10-26: "For compatibility, Cursor also loads skills from Claude and Codex directories: .claude/skills/, .codex/skills/, ~/.claude/skills/, and ~/.codex/skills/"). The page does not separate IDE and CLI: write "Cursor's docs say it also loads `.claude/skills/` and `~/.claude/skills/`; whether the agent CLI does is unknown (it did not on <the date of the original check>)".
- Lines 190-191: `We deploy Chrome DevTools skills (chrome-devtools, a11y-debugging) to both locations` / `via setup-user-mcp. ...` -> `Every harness skill (shared/skills, .claude/skills, dotprofile claude/skills) is fanned out to both locations from ~/.aitools/skills (reference/skills.md); chrome-devtools and a11y-debugging are vendored from the upstream repo in shared/skills/.`
- Section 9 of rules.md already flags `cursor-rule-parity.md` missing and "UI/SQLite only".

### 48. `reference/tool-registry.md` lines 227-230, 249 (deprecated; not P)

Current: `**Skills** (deployed by setup-user-mcp):` / `Vendored in shared/skills/ from the upstream repo. Deployed to ~/.claude/skills/ (Claude Code)` / `and ~/.cursor/skills/ (Cursor Agent CLI) by setup-user-mcp.sh/.ps1.` / `- **Post-Install Config:** Skills deployed automatically by setup-user-mcp. No auth required.`
New: replace `setup-user-mcp` with "the skills fan-out (`setup-user-claude`, `setup-user-cursor`; `reference/skills.md`)". The file is deprecated (packet section 6): a one-line fix or leave and list.

### 49. `shared/mcp/README.md` lines 79-81 (not P)

Current: `**Skills:** Chrome DevTools skills (chrome-devtools, a11y-debugging) are vendored` / `in shared/skills/ and deployed to ~/.claude/skills/ (Claude Code) and` / `~/.cursor/skills/ (Cursor Agent CLI) by setup-user-mcp.`
New: last line -> `` `~/.cursor/skills/` (Cursor) by the skills fan-out (`setup-user-claude`, `setup-user-cursor`). ``

### 50. `shared/skills/aitool-continue/SKILL.md` (not P)

Current (lines 110-112): `If this is the aitools repo, you have access to the full harness.` / `If this is another repo, you have user-level skills only` / `` (`~/.claude/skills/`). ``
New: `If this is another repo, you have the user-level skills (~/.claude/skills/): every aitools skill, including the project ones (tool-ops, incident, glossary, ...), which cite aitools repo paths and work only when the aitools repo is reachable.`
Same at line 413 (`You have user-level skills only. Check for:`).

### 51. `shared/skills/aitool-ops/SKILL.md` line 358 (not P)

Current: `` - Full tool-ops registry (CRUD): `/tool-ops` skill (aitools repo only) ``
New: `` - Full tool-ops registry (CRUD): `/tool-ops` skill (listed in every repo; works only inside the aitools repo) ``
Also its embedded snapshot (reference-card pattern) may carry deployment
facts: unknown, not read in full (17 KB); FX-56 already says the card is stale.

### 52. `CLAUDE.md` -- How the harness is organized (P; direct to main per FD-8)

Current (lines 40-41):

```
- `shared/` — source for user-level configs (skills, hooks, claude-shared) that
  `aitools install` deploys to `~/.claude/` and `~/.cursor/`.
```

New:

```
- `shared/` — source for user-level configs (skills, rules, hooks, claude-shared).
  `deploy-harness` collects them, with `.claude/rules/` and `.claude/skills/`,
  into `~/.aitools/`; the fan-outs copy rules and skills to `~/.claude/` and
  `~/.cursor/` (`reference/rules.md`, `reference/skills.md`).
```

Keep CLAUDE.md under 200 lines (documentation-standards).

### 53. `reference/README.md` (not P)

Add after line 12: `` | `skills.md` | Skills: what a skill is, the layering, anatomy, scopes, deployment to user scope and its cost | ``

### 54. `reference/framework-governed-vocabulary.md` lines 59, 72 (P; optional)

Current: `` | skill | Skill definition (`SKILL.md` in `.claude/skills/`, `shared/skills/`, or `~/.claude/skills/`) | `` and `` | user skill | `~/.claude/skills/*/SKILL.md` (deployed) | ``
New: add `~/.aitools/skills/`, `~/.cursor/skills/` to both; ties to the glossary
facet update (glossary file section 3).

### C1-C9. Script header comments (code batches; verify in their PRs, not FO-7)

| # | File:line (main) | Text | Owner |
|---|------------------|------|-------|
| C1 | `scripts/setup-user-skills.sh:2-8` (+ `.ps1:1`) | "Deploys user-level skills ... Dotprofile skills take priority over shared. Deploys to ~/.claude/skills/ and ~/.cursor/skills/." | FO-6 |
| C2 | `scripts/setup-user-claude.sh/.ps1` headers "Managed: ~/.claude/rules/*.md matching <userRepoPath>/claude/rules/" | FAN-PLAN B1/B4 + FO-4 adds `~/.claude/skills/` | FO-3, FO-4 |
| C3 | `scripts/setup-user-cursor.sh:6-21` "Does four things" | FO-5 adds step 5 skills, all-minus-retired | FO-5 |
| C4 | `scripts/deploy-harness.sh:19-20` "~/.aitools/skills/<name>/** <- shared/skills, then .claude/skills" | + dotprofile, manifest | FO-2 |
| C5 | `scripts/build-deploy.sh:11-14`, `:855`, `:895`, `:1914`, `:2064` ("setup-user-cursor, whose rules fan-out reads ~/.aitools/rules") | FAN-PLAN C1/C7/C9/C11 | FO-3 |
| C6 | `scripts/build-deploy.sh:1198`, `:1255`, `:1322`, `:1336` (setup-user-skills generator comments) | fallback wording | FO-6 |
| C7 | `scripts/check-post-push.sh:775`, `.ps1:906` "(skills moved to setup-user-skills)" | check step comments still true for the fallback; review | FO-6 |
| C8 | `shared/skills/intent-writing/SKILL.md:84` example header "setup-user-skills.sh — Deploy user-level skills to ~/.claude/skills/" | an example, not a claim; optional | -- |
| C9 | `README.md` MDM run order (FAN-PLAN C13/C14), FX-74 "MDM-ready" | FO-3 Batch C | FO-3 |

## 3. Not changed (checked, still true after the fan-out)

- `.claude/rules/aitool-ops.md:19` / `aitool-eval.md:20` "Any repo (deployed to ~/.claude/skills/)": true.
- `shared/cursor-rules/user-rules.md:40` `delegate` skill at `~/.cursor/skills/delegate/SKILL.md`: true.
- `reference/managed-file-deployment.md:9` "CLAUDE.md, rules, skills, hooks, deployed JSON": true.
- `reference/tool-ops-cursor.md` "Harness deployment" (lines 69-78): true (conversion unchanged); FO-5 may add "every rule minus retired".
- `.claude/rules/cross-platform.md:113` "Temporary, not deployed": unrelated.
- `shared/claude-shared.md`: no rules/skills deployment claims (grep).

## 4. Provenance

- Sweeps: `sweep.sh`, `sweep2.sh`, outputs `sweep-main.txt` and the tool
  result of sweep2 (in this session), scratch
  `/Users/new-jose/repos/aitools/.claude/worktrees/fo-orch/.scratch/session-fodocs/`.
- Drafts read: every file in `S3-FanPlan/S3-FanPlan-drafts/`; the three
  Manifest drafts (`git show feature/fanout-base:...S3-H2-Manifest-drafts/...`);
  `S3-RulesSpec/S3-RulesSpec-xref-drafts.md` (items 1 and 3 already on main;
  item 2 on main).
- RECONCILE: `plans/fan-plan-reconciliation.md` R2, R2c, R3, R4, R14;
  `S3-Reconcile-Fix-backlog.md` FX-58 (line 222), FX-71 (235), FX-74 (238).
