VERDICT: MERGEABLE

# S3-Merge3-ReVerify126: independent re-review of PR 126 (FO-7 docs) at its final head, v1.0

Independent re-review by S3-Merge3-ReVerify126 (level 2, delegated by S3-Merge3, mission MERGE-3, Session Commander 10cf255a-c), on the commander's 2026-10-28 order: "launch a mission to serve as an orchestrator and merge open prs in the correct order. learn from past mistakess. give it explicit instructions to fix issues when they arise." I did not write the change and did not read the Prep notes.

- **Head reviewed:** `5d91acc6ed5c29afccf7ff6816babe5691db46f0` (`feature/fanout-docs`)
- **Base:** `origin/main` `40777f8f774e2a41e4551c6c73e4305b4b503a8b` (PR 125 merged); main is an ancestor of the head (`git merge-base --is-ancestor`), so `git diff origin/main HEAD` is the PR's whole net change.
- **Earlier verdict:** S3-Merge2-Review125, BLOCKING B1-B4 at `725b03a`.
- **GitHub:** mergeStateStatus CLEAN (read twice), base main, state OPEN. CI on 5d91acc: macos, linux, windows SUCCESS (run 40823929596); CodeQL actions / javascript-typescript / python / ruby and the CodeQL check SUCCESS (run 40823924918).
- **Blocking findings:** none. Non-blocking: 3, plus one out-of-scope INCIDENT marker.

## Blocking findings from Review125: all fixed

- **B1 (21 conflicts, 3 modify/delete): fixed.** Merges 2f2f059 (main add7a09), 148bb09 (3e00085, PR 121) and e40a7ea (40777f8, PR 125). The three modify/delete files took main's deletion: `.claude/rules/aitool-eval.md`, `.claude/rules/aitool-ops.md` and `shared/skills/aitool-ops/SKILL.md` are absent at the head and absent from the PR's file list. I checked the scrub facts the verdict named as at risk; all are on the head:
  - `dotprofile_commit_push` (`reference/managed-file-deployment.md` Functions row and the N-Q2 bullet);
  - the `Claude settings` content-source row;
  - the `claude settings` / `claude template` tool rows and the `scripts/aitools-profile` logging row (`reference/script-standards-detail.md`);
  - the SD-2 `hooks/` comment and the `rules/` row (`reference/user-repo.md`);
  - the full MDM script list (`README.md`);
  - `--skip-config` and "Dotprofile resolution".

  Main's text survives in the diff against main: every `-` line I read was replaced by an updated statement, and no fact was dropped without a replacement. After e40a7ea the PR changes 29 files, all docs. Nothing changes under `scripts/`, `tests/`, `.github/` or `shared/hooks/`.
- **B2 (7 dead path refs): fixed.** `python3 scripts/check-path-refs.py --root <worktree>`: "dead path references: 0", exit 0. check-pre-commit step 20 also passes.
- **B3 (stale skill inventory): fixed.**
  - `reference/skills.md`: 22 skills (20 + 2), "7 of 22" with tests, S-6 recorded as re-landed by PR 128 (72c94c3) and PR 129 (a63ad2d). Section 7 is redone for `audit` and `governed-data`. Section 4.5 calls the reference cards retired, and section 7.3 lists `tool-eval` and `tool-ops` as shared.
  - `reference/rules.md:99-104` puts the cards in the past tense.
  - `shared/skills/aitool-continue/SKILL.md` no longer says "use `/aitool-*`".
  - I recounted on `40777f8` myself: `git ls-tree` gives 20 skills in `shared/skills` and `.claude/skills` = `audit`, `governed-data`. Seven skills have `tests/expected-behaviors.md`, and the seven names match the doc. `scripts/check-skill-levels.py` prints "20 in shared/skills (user), 2 in .claude/skills (project); names at two levels: 0".
- **B4 (fallback adopt sync): fixed.** `reference/managed-file-deployment.md` "Several LOCALs for one SOURCE" now says the fan-outs never copy one LOCAL to another, and the fallback does. That matches main: `scripts/setup-user-skills.sh:171-189` (`backup_file "$_other"`, `cp "$dest" "$_other"`, `write_summary ERROR "$tool_name" "sync failed: $skill_name"`) and `scripts/setup-user-skills.ps1:182`.

Review125 N1 (the answered questions) is done: they are recorded in skills.md section 10 and in the PR body's "Answered questions". N3 is done: Skill placement keeps the FD-1 deployment statement, main's step 21 and the "Governed data" bullet, and names the 2 remaining project skills. N4 is done: README keeps main's list plus the fan-out comments. N5 (the CLAUDE.md `shared/` bullet) is deferred to a direct-to-main commit, as ordered, and is not counted here.

CONFLICT: documentation-standards "`.claude/skills/` ... never deployed" (SD-8, 2026-10-21) vs FD-1/R-4 "ALL project-scope rules AND skills are deployed" (2026-10-26) -- resolved by tier 1 (the commander's newer words): the PR's deployment statement is correct; I did not count it against the PR.

## Statements spot-checked against the code on origin/main 40777f8 (independent of the Prep's factcheck)

| Doc statement (file) | Code |
|---|---|
| setup-user-skills reports `n/a (fanned out)` when `~/.aitools/skills` exists (README, skills.md 6.2, script-standards-detail `skills` row) | `scripts/setup-user-skills.sh:66-70`, `.ps1:63` |
| Fallback copies the adopted LOCAL to the other targets, ERROR `sync failed: <skill>` (managed-file-deployment.md) | `scripts/setup-user-skills.sh:171-189`, `.ps1:182` |
| Retired `aitool-ops` / `aitool-eval` never offered for adoption; log line quoted verbatim (skills.md 10) | `scripts/setup-user-skills.sh:268`, `.ps1:315` |
| Cursor step 5: `fanout_harness_skills "cursor skills" "$CURSOR_DIR/skills" "" ""` (skills.md 6.2) | `scripts/setup-user-cursor.sh:960`; `.ps1:947` |
| Lib signature `TOOL DEST AITOOLS_REPO DOTPROFILE` / `-ToolName -DestDir -AitoolsRepo -Dotprofile` | `scripts/aitools-lib.sh:3091-3092`, `scripts/aitools-lib.ps1:3090-3091` |
| setup-user-claude calls the lib fan-out in an extracted `skills fan-out` span, tool `claude skills`, adopt only from a git checkout (deploy-paths, skills.md 6.2) | `scripts/setup-user-claude.sh:318-320,729-737`; `.ps1:707-715` |
| No `~/.aitools/skills`: no row, info log only (deploy-paths, skills.md 6.3) | `scripts/aitools-lib.sh:3112-3116` |
| Empty `~/.aitools/skills`: `OK <tool> n/a (no harness skills)` | `scripts/aitools-lib.sh:3201`, `.ps1:3191` |
| Bad header: WARN + ACTION "Run aitools to rebuild ~/.aitools/skills and its manifest"; unreadable manifest: ERROR `cannot read skills manifest` | `scripts/aitools-lib.sh:3138-3142`, `.ps1:3144-3149` |
| ACTION texts "not updated (a symlink or a file, not a directory the fan-out owns)" and "still loads retired skills in" | `scripts/aitools-lib.sh:3387,3488`, `.ps1:3389,3515` |
| Reserved names `synced` / `anthropic-skills*` are a failed item | `scripts/aitools-lib.sh:3240`, `.ps1:3237` |
| Binary copy `_fanout_copy_binary` / `Copy-FanoutBinary` | `scripts/aitools-lib.sh:2927`, `.ps1:2939` |
| Rules fan-outs report `n/a (no harness rules)` | `scripts/setup-user-claude.sh:368,483`, `.ps1:385`; `scripts/setup-user-cursor.sh:529` |
| Ordinal order (`LC_ALL=C sort`, `CompareOrdinal`) in both fan-outs (rules.md 6.1) | `scripts/setup-user-claude.sh:463`, `.ps1:391`; `scripts/setup-user-cursor.sh:634`, `.ps1:538` |
| Tracker summary: WARN `N skipped (user review)`, `n/a (nothing to deploy)` | `scripts/aitools-lib.sh:2639,2645`, `.ps1:2669,2675` |
| `backup_dir` reason `no top-level *.md`; `.bak.incomplete.` rename | `scripts/aitools-lib.sh:1061,1096`, `.ps1:993` |
| `read_harness_manifest` reports `header-bad` | `scripts/aitools-lib.sh:2741`, `.ps1:2745` |
| `rule_name_kind`: hidden / backup / rule / other; `fanout_text_equal` 0/1/2 | `scripts/aitools-lib.sh:2786` and the `rule_name_kind()` body |
| deploy-harness: `harness_manifest_plan` / `Get-HarnessManifestPlan`, `write_harness_manifest` / `Write-HarnessManifest` (rules, then skills), `retire_skill_dir` / `Remove-RetiredSkill`, `prune_skill_backups`, `diff -r -q`, the header `# aitools skills manifest v1`, ERROR `rules manifest not written` (`$kind manifest not written`) | `scripts/deploy-harness.sh:416,425,533,591,611,630,641,695-696`; `.ps1:396,628,679,692,759-760` |
| Source order shared → `.claude` → dotprofile for rules and skills, plus `.claude/hooks` (managed-file-deployment rule, harness.md, deploy-paths) | `scripts/deploy-harness.sh:304-312` |
| build-deploy embeds no rules in setup-user-claude, and setup-user-skills embeds SKILL.md (deploy-paths) | `scripts/build-deploy.sh:241-243,1359` |
| CI step "Every test suite is in CI"; `tests/fanout-lib`, `skills-fanout`, `skills-legacy`, `rules-fanout`, `rules-fanout-cursor` exist | `.github/workflows/check.yml:384-425`; `git ls-tree origin/main tests/<dir>` |
| Rule counts: 24 `.claude/rules`, 9 with `paths:`, 15 without; 74,633 + 3,573 = 78,206 bytes (rules.md 4, 7) | `git ls-tree` / `git grep -l/-L '^paths:'` on 40777f8; `wc -c` at the head: 74633 and 3573 |
| Merge SHAs named in rules.md / skills.md: PR 118 b5a881a, 119 fac2dbc, 124 ba8ec2c, 123 207f1a6, 121 3e00085, 125 40777f8, 128 72c94c3, 129 a63ad2d, 100 89e2953; commits 44cdcb2, c5d1bd8 | `git log -1` (each "Merge pull request #N"), all ancestors of origin/main |

Every cited section heading exists: I checked 28 headings, among them harness.md "Conflict handling" and the two manifest sections, managed-file-deployment "Functions", "Caller Responsibilities" and "[x]abort", tool-ops-cursor "Glob anchoring", and plans/skills-and-rules-fanout.md "8) shared/ wins" and "9) setup-cursor-cli should do the fan-out".

## Protected files and intent

- `git diff --name-only origin/main...origin/feature/fanout-docs` (29 files) checked against the sources-of-truth table. Every protected file the PR changes is in the PR body's "Review after" (the original section plus the MERGE-3 section):
  - `.claude/rules/` aitools-workspace, config-file-safety, deploy-paths, documentation-standards, frameworks, glossary, hook-rollout, managed-file-deployment;
  - `.cursor/rules/` deploy-paths, documentation-standards, hook-rollout, managed-file-deployment;
  - reference/ harness, managed-file-deployment, user-repo, framework-governed-vocabulary, tool-ops-claude-code, tool-ops-cursor;
  - registries/glossary.json;
  - the new reference/skills.md intent.

  The unprotected files changed are README.md, reference/README.md, cursor-practices.md, rules.md (body), script-standards-detail.md (not its exemptions table), tool-registry.md, shared/mcp/README.md, and the aitool-continue and scratch skills. They are listed too, except tool-registry.md and shared/mcp/README.md, which appear under "Changes".
- **Intent statements:** no existing intent statement changed. A grep of the diff for changed `**Intent**` / `**Purpose**` / `**Scope**` / `**Audience**` lines finds none; rules.md's intent is unchanged and only its version line moved. The one new intent, reference/skills.md, fits its file. Purpose: definition, layering, anatomy, scopes and loading, deployment, measured cost, which are sections 2-7. Scope: it cites sources and marks unknowns, and changes no code. Audience: writers and reviewers. It is listed for review.
- **Governed data access:** no governed JSON path was added to rules or reference. check-pre-commit step 16 PASS. The added text names skills or says "incidents registry" (skills.md 7.3). Glossary terms went through `registries/glossary.json` itself (it parses, and the 5 terms are present).
- **Messages:** no close keyword followed by `#N` or a PR URL in this PR's own commits (first-parent 725b03a..5d91acc). The one hit in the range is in main's 2f7ccdb (the brief v1.1 incident with PR 123), which came in through a merge and is already on main.

## Non-blocking

- **N1. The PR body is partly stale for the commander's review-after.** Its original "Changes" and "Review after" sections still list edits to `.claude/rules/aitool-ops.md`, `aitool-eval.md` and `shared/skills/aitool-ops/SKILL.md`, which are no longer in the PR (main's deletion was taken). The MERGE-3 "Review after" bullet for rules.md gives the anchor as add7a09, while the file now says 40777f8 (5d91acc). "Not run: ... phase B re-check" remains, although the phase B bullet says it was done. Suggested fix: Land or the orchestrator edits the body (`gh pr edit --body-file`) before merging. It does not block: the merge content is right.
- **N2. `reference/harness.md` (new paragraph under Configuration)** says the project rules and skills "exist at both scopes until the project copies are removed". That is true under R-4. documentation-standards and skills.md 7.1 now name the two project skills; harness.md could too. Optional.
- **N3. `reference/rules.md:101-102`** says "The LAYOUT PR-c re-land retired both cards", while skills.md says "PR 129". Same fact, two names; optional alignment.

INCIDENT (out of scope, pre-existing on main, not this PR): `reference/README.md:52` and `reference/tool-registry.md:4` cite `registries/tool-registry.json` by path in `reference/*.md`, which `.claude/rules/governed-data-access.md` "What MUST NOT reference JSON file paths" forbids. Pre-commit step 16 checks only rules and CLAUDE.md, so it does not catch them.

## What I ran (worktree `/Users/new-jose/repos/aitools/.claude/worktrees/m3-rr126`, detached at 5d91acc)

| What | Result |
|---|---|
| `gh pr view 126 --json headRefOid,baseRefName,mergeStateStatus,statusCheckRollup,body` (twice) | head 5d91acc, base main, CLEAN both reads, every check SUCCESS |
| `git ls-remote origin` | main 40777f8, feature/fanout-docs 5d91acc |
| `git diff --stat origin/main HEAD` = `origin/main...HEAD` | 29 files, docs only |
| `git show --remerge-diff` 2f2f059 / 148bb09 / e40a7ea and `git show` e304469, 84c8a04, 6a3d44f, c970d56, 5d91acc | read; resolutions as their messages state |
| Scratch fact scripts (`facts.sh`, `facts2.sh`) with `git grep` / `git show` on origin/main | every statement in the table above found |
| `python3 scripts/check-path-refs.py --root <worktree>` | dead path references: 0, exit 0 |
| `python3 scripts/check-skill-levels.py` | 20 shared, 2 project, 0 at two levels |
| `bash scripts/check-pre-commit.sh` from the worktree | 8 PASS, 12 SKIP, 1 WARN (11, dotprofile has uncommitted changes), 1 FAIL (step 6, known); step 16, 20, 21 PASS |
| Heading check (28 cited section names) | all present |

**Not run:** test suites (no code in the PR; the head has no diff from main under scripts/ or tests/); check-pre-push; Windows; /intent-audit as a skill run (the new intent was audited by hand against sections 1-11, and no existing intent changed).

-- S3-Merge3-ReVerify126 (level 2: S3-Merge3 -> Session Commander 10cf255a-c)
