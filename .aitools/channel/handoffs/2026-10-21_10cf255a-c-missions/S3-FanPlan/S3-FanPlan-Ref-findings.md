# S3-FanPlan-Ref findings (reference docs, evaluations, harness-db schema, shared/hooks)

Explorer S3-FanPlan-Ref (level 2, under S3-FanPlan), 2026-10-26. Read-only.
Reading copy: `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/` (origin/main 480b901).
All `file:line` below are in that worktree unless stated.

## 1. Summary

1. No shared hook reads `~/.claude/rules` or `~/.aitools/rules`; no hook, `hooks-manifest.json` or `harness-db-schema.sql` change is needed for the fan-out (section 3.3).
2. The reference docs in this slice say almost nothing about how user rules reach `~/.claude/rules`. Only these statements need a change or a check: `hook-rollout.md:110-112` (becomes true once the fan-out lands; protected), `tool-ops-claude-code.md` (has no rules-loading facts at all; a new version-dependency item is drafted below; protected), and `framework-governed-vocabulary.md:58,70` (only if a "harness rule" term is added; protected).
3. The biggest finding comes from the official Claude Code memory docs (fetched 2026-10-26). `paths:` patterns in a user-level rule resolve against the session's primary working directory. User rules load before project rules, and when the two conflict neither wins. Rule `.md` files are found recursively in subdirectories. So fanning out the 17 aitools project rules that have no `paths:` puts "(this repo)" rules into every project. Inside aitools itself, every project rule then loads twice, and the deployed copy can be stale against the working tree or a worktree branch.
4. 10 of the rule sources have `paths:` frontmatter with repo-relative globs: 9 in `.claude/rules/` and `shared/rules/hook-lifecycle.md`. Fanned out, they still match only inside aitools, or inside any other repo that happens to have the same paths.
5. Smaller items: the governed summary outcomes have no `removed` term (`script-standards-detail.md:300-307`), which a retired-rule removal needs. The glossary has no "fan-out" or "harness files" term, while `framework-tool-ops.md:45` uses "harness files" in a generic sense. `tool-ops-claude-code.md:17` still says "Current version: 2.1.81", but 2.1.307 is observed elsewhere in the same file (line 304).

## 2. Files read in full (updated after the full-read pass, section 9)

Every file below was read in full with Read (offset/limit where a file exceeded the page cap). Paths are under `/Users/new-jose/repos/aitools/.claude/worktrees/fanplan/`; line counts from `wc -l`.

**reference/**
- `tool-registry.md` (1084)
- `script-standards-detail.md` (1162)
- `tool-ops-claude-code.md` (481)
- `tool-support-decision-tree.md` (749)
- `claude-code-effectiveness.md` (251)
- `agentic-framework.md` (178)
- `tool-evaluation-playbook.md` (204)
- `tool-evaluation-criteria.md` (178)
- `smoke-test-pattern-detail.md` (54)
- `README.md` (58)
- `logging.md` (119)
- `ait-shellintegration.md` (145)
- `cross-platform-detail.md` (206)
- `plan-execution-detail.md` (97)
- `incident-020-process-discipline.md` (76)
- `tool-ops-google-chrome.md` (228)
- `do-what-feels-right.md` (145)
- `agentic-prompt-patterns.md` (36)
- `path-targeted-hooks-analysis.md` (85)
- `framework-incident-governance.md` (53)
- `framework-intent-documentation.md` (66)
- `framework-governed-data-access.md` (136)
- `framework-hook-rollout.md` (43)
- `framework-tool-ops.md` (72)
- `framework-tool-lifecycle.md` (66)
- `framework-adoption.md` (243)
- `framework-source-of-truth.md` (42)
- `framework-provenance.md` (232)
- `framework-governed-vocabulary.md` (103)
- `framework-artifact-harvesting.md` (73)
- `framework-three-layer-governance.md` (174)
- `framework-incident-investigation.md` (51)
- `framework-managed-file-deployment.md` (53; not in my access list or any sibling's, so I read it too)
- `harness-db-schema.sql` (350)
- `evaluations/google-chrome-linux-2026-10-05.md` (228)
- `evaluations/claude-code-macos-2026-10-21.md` (93)

**shared/hooks/** (all 22 files plus `hooks-manifest.json`)
- `block-claude-code-guide.sh` (59), `block-explore-agent.sh` (65), `command-channel-stop.sh` (186)
- `dashboard-serve.sh` (110), `delegation-duty-guard.sh` (215)
- `failure-mode-identity-stop.sh` (5), `failure-mode-verify-stop.sh` (5)
- `glossary-skill-guard.sh` (38)
- `harness-db-sessionend.sh` (84), `harness-db-sessionstart.sh` (84), `harness-db-sessionstart.sh.bak.2026-06-21T203304Z` (75)
- `harvest-session.sh` (64), `hooks-manifest.json` (32)
- `intelligence-stop.py` (433), `intelligence-stop.sh` (50)
- `scratch-init.sh` (119), `session-archive.sh` (98), `session-catchup.sh` (62), `sh-file-fixup.sh` (81)
- `standing-order-guard.sh` (304), `standing-order-guard.sh.bak.2026-06-21T203334Z` (269)
- `tool-ops-session-audit.sh` (105)

Line counts for the hooks are the last line number the Read tool showed.

**Also read:**
- the mission packet (158) and the explorer brief (144)
- https://code.claude.com/docs/en/memory (WebFetch; lines 205-284 of the saved output read, plus a grep of the rest)
- `shared/rules/hook-lifecycle.md` lines 1-14, plus a grep
- the worktree copy of `.claude/rules/hook-rollout.md`, lines 107-113
- the `gh pr diff 101` hunks for my slice

**Rules:** the project rules come from the system context of the main checkout, plus the worktree copy of `hook-rollout.md` (identical text at 109-112). I did not re-read `plans/tool-support-and-machine-profile.md` or the prior handoff `2026-10-21_360aa8f3-8.md`.

## 3. Current behaviour relevant to the fan-out

### 3.1 How Claude Code loads `~/.claude/rules` (official docs, not in the harness)

Source: https://code.claude.com/docs/en/memory, fetched 2026-10-26 (WebFetch; re-read with chrome-devtools before any of this goes into a protected file, per `web-sources.md`). Verbatim:
- "All `.md` files are discovered recursively, so you can organize rules into subdirectories like `frontend/` or `backend/`" (project rules section).
- "Rules without a `paths` field are loaded unconditionally and apply to all files."
- "Each pattern is relative to the rule's base directory: **Project rules**: the directory that contains the rule's `.claude` folder; **User-level rules**: the session's primary working directory".
- "`paths` is the only field Claude Code reads from a rule; any other field is ignored without an error. Claude Code removes the frontmatter before loading the rule into context."
- "If the YAML between the markers doesn't parse, Claude Code ignores the frontmatter and loads the rule as if it had no `paths`."
- "Claude Code loads user-level rules before project rules, so a project rule appears later in Claude's context than a user rule. Neither set overrides the other: if a user rule and a project rule conflict, Claude may follow either one, so keep the two consistent."
- Symlinks: "To load shared rules without that approval, keep them in `~/.claude/rules/`, where they apply to every project on your machine."
- `claudeMdExcludes` setting: "Patterns are matched against absolute file paths using glob syntax", configurable at the user layer.

Not stated in the docs:
- case sensitivity of the `.md` extension (unknown);
- whether recursion applies to `~/.claude/rules/` subdirectories (the docs say it for project rules only; unknown for user rules).

The harness has none of this. `tool-ops-claude-code.md` covers only item #18 (`@` not resolved in rules, line 72) and item #20 (`InstructionsLoaded`, line 73). A grep of `registries/tool-ops.json` for rules or frontmatter finds no loading facts.

### 3.2 Rule sources with `paths:` frontmatter

The fan-out copies these sources (`scripts/deploy-harness.sh:20-26,260-263`; first source wins; `*.bak.*` skipped at :197; non-`.md` skipped at :207-208).

`grep -rln "^paths:"` found:
- `shared/rules/hook-lifecycle.md` (lines 1-10: `shared/hooks/**`, `scripts/setup-user-hooks.sh`, …, `reference/managed-file-deployment.md`)
- `.claude/rules/`:
  - `managed-file-deployment.md`
  - `tool-lifecycle.md`
  - `web-sources.md`
  - `documentation-standards.md`
  - `tool-evaluation.md`
  - `hook-rollout.md`
  - `relay-outbound.md`
  - `deploy-paths.md`
  - `config-file-safety.md`
- Dotprofile `claude/rules/`: none.

The other 17 `.claude/rules/*.md` and `shared/rules/scratch.md` have no `paths:`. After the fan-out they load in every session in every repo. Many carry a "(this repo)" heading, for example `script-standards.md` and `sources-of-truth.md`.

### 3.3 Shared hooks

- No hook reads `~/.claude/rules` or `~/.aitools/rules`. The grep hits are all `~/.aitools/logs`, `~/.aitools/bin/harness-db.py` (`harness-db-sessionstart.sh:64`, `harness-db-sessionend.sh:60`, `scratch-init.sh:103`), or repo-relative comments.
- `delegation-duty-guard.sh:102` scores the "rules" element with `/rules|CLAUDE\.md|\.claude\/rules/i`, and line 173 gives the guidance "Rules: instruct subagent to read CLAUDE.md and .claude/rules/." The fan-out does not change this. Sub-agents still do not inherit rules (`tool-ops-claude-code.md:52`, item #5), so the guidance stays valid.
- Comment-only references to the project path `.claude/rules/hook-rollout.md`: `standing-order-guard.sh:33`, `delegation-duty-guard.sh:10,14`, and the `.bak` copy at :28. Still valid.
- `tool-ops-session-audit.sh:84-89` reads `reference/tool-ops-claude-code.md` from `$AITOOLS_REPO_PATH` or `~/repos/aitools`. It does not read `~/.aitools/reference/`. That is not rules-related; I note it only because the `/tool-ops` skill says to read the deployed copy first.
- `hooks-manifest.json` lists no rules files and no `.bak` files. The two tracked `.bak` files in `shared/hooks/` (`harness-db-sessionstart.sh.bak.2026-06-21T203304Z`, `standing-order-guard.sh.bak.2026-06-21T203334Z`) are skipped by deploy-harness (`deploy-harness.sh:26,197,367`).

## 4. What must change or be checked

| # | File:line | Verbatim now | Protected | After the fan-out | Draft |
|---|---|---|---|---|---|
| R1 | `.claude/rules/hook-rollout.md:109-112` | "The hook lifecycle beyond rollout (source, deploy, adopt, user-created hooks,\nretirement) is governed by the user-level rule `@shared/rules/hook-lifecycle.md`\n(deployed to `~/.claude/rules/hook-lifecycle.md` once a deploy path for\n`shared/rules/` exists)." | yes (`.claude/rules/*.md`) | becomes true | old_string lines 111-112: "(deployed to `~/.claude/rules/hook-lifecycle.md` once a deploy path for\n`shared/rules/` exists)." → new: "(deployed to `~/.aitools/rules/` by `deploy-harness` and fanned out to\n`~/.claude/rules/hook-lifecycle.md` by `setup-user-claude`)." |
| R2 | `reference/tool-ops-claude-code.md` (no line; new MEDIUM item after line 74) | (absent) | yes (`reference/tool-ops-*.md`) | the fan-out depends on these facts | Draft row: "\| 28 \| User-level rules (`~/.claude/rules/`): every `.md` loads in every project, before project rules, with no precedence on conflict; `paths:` globs resolve against the session's primary working directory; `paths` is the only frontmatter field read; YAML that does not parse means the rule loads unconditionally \| 2.1.307 \| 2.1.307 (2026-10-26, docs only) \| `scripts/setup-user-claude.sh/.ps1` (fan-out), `scripts/deploy-harness.sh/.ps1`, `reference/harness.md` \| -- (code.claude.com/docs/en/memory) \|". Verify with chrome-devtools before writing (`web-sources.md`). |
| R3 | `reference/tool-ops-claude-code.md:17` | "- **Current version**: 2.1.81" | yes | stale, independent of the fan-out | Update the version when R2 lands (2.1.307 per line 304), or leave it and flag it. Suggested: leave it; the version walk is post-push checklist #20's job. |
| R4 | `reference/tool-ops-claude-code.md:190-196` (CLAUDE.md deploy flow; MDM line 196: "Self-contained with build-time embedded content.") | — | yes | still accurate for CLAUDE.md. It does not mention rules, so nothing goes stale. | No change, unless the planner wants a "rules" bullet; then point to `reference/harness.md` instead of duplicating it. |
| R5 | `reference/framework-governed-vocabulary.md:58` "\| rule \| Claude Code rule file (`.md` in `.claude/rules/` or `~/.claude/rules/`) \|" and :70 "\| user rule \| `~/.claude/rules/*.md` \|" | — | yes (`reference/framework-*.md`) | still true. A fanned-out project rule becomes a "user rule" by this table, which is ambiguous. | Optional: add a "harness rule" row, `~/.aitools/rules/*.md`. That needs the `/glossary` skill first (section 8). |
| R6 | `reference/script-standards-detail.md:207-208,221` tool-name table: "`claude.md` \| setup-user-claude", "`claude rules` \| setup-user-claude", "`harness files` \| deploy-harness" | — | no (not in the protected table) | consistent. The fan-out keeps the `claude rules` summary name. | Check only. If Cursor's fan-out reports rules, `cursor rules \| setup-user-cursor` (:212) already exists. |
| R7 | `reference/script-standards-detail.md:300-307` governed outcomes: verified, updated, created, configured, accepted, `n/a (<environment>)` | — | no | there is no term for a removed retired rule | Needed only if the fan-out deletes retired rules. Coordinate with the known defect "deploy tracker has no `removed` outcome" (brief). Any new term goes through `/glossary`. |
| R8 | `reference/plan-execution-detail.md:20-22` "\| 3+ code files in the plan \| Yes \|", "\| Any change to `scripts/build-deploy.sh` \| Yes \|" | — | no | the plan must use the sub-agent execution pattern, because it touches build-deploy and setup-user-claude.sh/.ps1 | Planner constraint, no edit. |
| R9 | `reference/README.md` (58 lines) | no row for a rules-fanout doc | no | needs a row only if the plan adds a reference file | — |
| R10 | `reference/framework-adoption.md:66-67` "Rules that might address it — search `.claude/rules/` and\n  `~/.claude/rules/`" | — | yes | still true. Optionally add `~/.aitools/rules/`. | Low priority; suggest no change. |
| R11 | `reference/incident-020-process-discipline.md:59` "Create a user-level rule (`~/.claude/rules/process-discipline.md`)" | — | yes (`reference/incident-*.md`) | historical suggestion; no change | — |
| R12 | `reference/agentic-prompt-patterns.md:29-31` (incident #24 corrupted `~/.claude/rules/concurrent-agents.md`) | — | no | historical; no change. It is a reminder that fan-out writes to `~/.claude/rules` go through `deploy_managed_file` validation. | — |

Outside my slice but matching focus (a). The sibling owners are probably S3-FanPlan-Claude or -Misc; I list them so none is dropped:
- `.claude/rules/managed-file-deployment.md:52`: "- **Rules**: additive deploy from `<userRepoPath>/claude/rules/` — managed files updated, unmanaged files in target preserved". Protected. It becomes false: the source becomes `~/.aitools/rules`.
- `.claude/rules/managed-file-deployment.md:48`: "Rules reach the tools through the `setup-user-claude` / `setup-user-cursor` fan-out." Protected. It becomes true.
- `.claude/rules/deploy-paths.md:69`: "- `<userRepoPath>/claude/rules/*.md` → read via `cat` at build time". Protected. It changes with the MDM counterpart.
- `.claude/rules/config-file-safety.md:106-107`: the example "`# Managed: ~/.claude/rules/*.md\n   matching <userRepoPath>/claude/rules/`". Protected. The example becomes stale.

## 5. Interactions with open PRs

Superseded by section 9.2, which has the verified PR file lists.

## 6. Error-handling, parity and script-standards issues

- `tool-ops-session-audit.sh:33,55,64,77,95` suppresses errors with `2>/dev/null` and `|| true`, each with a comment. That is acceptable under script-standards, and the refactor does not touch it.
- No hook in the slice needs a PS1 twin (hooks are exempt, `cross-platform.md`).

## 7. Risks, unknowns, open questions (with suggested answers)

1. **Every aitools project rule in every repo.** 17 `.claude/rules/*.md` plus `shared/rules/scratch.md` have no `paths:` and would load in every project after the fan-out. The approved behaviour says "Put aitools rules in the user space of claude code", so this may be intended, but the context cost and the "(this repo)" wording are real. Suggested answer: confirm with the commander that `.claude/rules/` (project) belongs in the fan-out at all, as opposed to `shared/rules/` plus dotprofile only. If yes, add `paths:` to aitools-only rules or reword their headings; both are protected edits.
2. **Double load and staleness inside aitools.** In an aitools session the project rule and its fanned-out copy both load, and "Claude may follow either one" on conflict. In a worktree or branch that edits a rule, the user copy is stale until the next `aitools` run. Suggested answer: have the fan-out skip `.claude/rules`-sourced files. An alternative is a user-level `claudeMdExcludes` entry for `~/.claude/rules/<project-rule>.md` when the cwd is aitools, but excludes are absolute globs with no per-project condition at user level. Treat that alternative as unknown and verify it.
3. **`paths:` in user rules resolves against the cwd.** Rules like `hook-lifecycle.md` (`scripts/build-deploy.sh` …) would trigger in an unrelated repo with the same paths. The risk is low, but it is a semantic change. Suggested answer: accept it and note it in R2.
4. **Subdirectories.** Recursion for `~/.claude/rules/` subdirectories is **unknown** (documented for project rules only). A fan-out into `~/.claude/rules/aitools/` would be a clean namespace for manifest-based removal, but it needs verification first. Suggested answer: keep it flat, as approved, unless verified.
5. **Case of `.md`.** Whether Claude Code loads `X.MD` is **unknown**. The approved filter is case-insensitive `*.md`. Suggested answer: emit a WARN for a non-lowercase extension.
6. **Directory backups.** `config-file-safety.md` puts `<dir>.bak.<TS>/` beside the target, which is fine. A backup directory created *inside* `~/.claude/rules/` would hold `.md` files that could load, if recursion applies there. Suggested answer: the fan-out must never back up into the rules directory itself.
7. **Claude Code web environment.** Whether the fan-out runs there, and whether it is useful, is **unknown**. Nothing in my slice decides it.

## 8. INCIDENT markers (not filed)

- INCIDENT: `reference/tool-ops-claude-code.md` lacks every Claude Code fact about user-level rule loading (recursion, `paths:` resolution, load order, no precedence) that the rules fan-out depends on. Expected: per `.claude/rules/tool-ops.md`, check the ops reference before assuming tool behaviour. Severity medium.
- INCIDENT: `reference/tool-ops-claude-code.md:17` "Current version: 2.1.81" is stale (2.1.307 is observed at :304). Severity low.
- INCIDENT (governance ambiguity): unconditioned "(this repo)" project rules are fanned into user scope with no spec for scoping them. `managed-file-deployment.md` (rule) "Content sources" names the fan-out but not its scoping. Severity high if they ship unscoped.
- TODO(glossary): "fan-out", "harness files" (summary name, `script-standards-detail.md:221`) and "deployed harness" are not in `.claude/rules/glossary.md`. `framework-tool-ops.md:45` uses "harness files" generically ("scattered across multiple harness files"), which collides with the summary name.
- INCIDENT (minor drift, outside the slice): `claude-code-effectiveness.md:129` says "All 4 script pairs (claude, cursor, mcp, hooks) now use single source of truth", but `.claude/rules/deploy-paths.md` lists 3 pairs with duplicated logic. The effectiveness entry is historical; low.

WRITE_BLOCKED: none.

## 9. Full-read addendum (2026-10-26, on S3-FanPlan's request)

### 9.1 New findings per file

**`reference/tool-support-decision-tree.md` (not protected; its banner says revision 5 was commander-approved)**
- It contradicts the commander's decision of 2026-10-26 that `[x]abort` ends only that setup script.
- Line 65, D-TS13: "Runners stop the run on exit 2 (section 7.5)".
- Lines 472-483, section 7.5 "After each script": "exit 2 = user abort. The runner writes no failure row, logs `aborted by user in <script>` (info), skips the remaining scripts in its loop, and reports the abort to its caller ... This makes the managed-file `[x]abort` ("stop the run") behave as documented in both the install and the sync paths."
- Test matrix rows that encode the same stop-the-run behaviour:
  - :707 "ABORT, exit 2; installer stops"
  - :708
  - :709 "`deploy_configs` / `Deploy-Configs` write no ERROR row and skip the remaining deploy scripts"
  - :711, :714 (user init and the rebuild skipped)
- The fan-out's `[x]abort` in setup-user-claude follows this contract. The planner must either cite the new decision or get this doc amended.
- This is outside the rules fan-out proper. Suggested answer: list it as a follow-up and do not edit it in FAN-PLAN, since PR #106 is "under change".

**`reference/script-standards-detail.md` (not protected, except its exemptions table)**
- `:274`, the "Three outcomes" table, still uses `"Unchanged"`. Lines 312-316 deprecate that term in favour of `"verified"`. The fan-out summary should use `verified` / `updated` / `created`, with counts like `"2 added, 1 updated"` (`:291`).
- The table has no row for deletion, the same gap as R7.
- PR #101 inserts lines at :85 (+3), :179 (+8) and :249 (+5). After it merges, my R6 and R7 references move by about +11 and +16 lines.
- PR #101 also adds this rule after :180: "`write_summary OK` writes `WARN` instead when the script has already counted a warning ... Order rows so that this is true."
- Consequence: if the fan-out logs a `log_warn` (for example on a non-lowercase `.md`, item 7.5), every later OK row from setup-user-claude, including `claude.md`, turns WARN. Row ordering matters in the refactor.

**`reference/smoke-test-pattern-detail.md:13`**
- "`bash scripts/setup-foo.sh > .scratch/smoke-foo.log`" runs against the real HOME. For the fan-out tests the planner must use an isolated HOME (packet section 5, #86), not this pattern as written.

**`reference/plan-execution-detail.md:43-72`**
- The sub-agent prompt template and the 8 error-handling rules are what the planner injects into each batch prompt. Required: build-deploy and setup-user-claude changes trigger the sub-agent pattern (:20-22).

**`shared/hooks/glossary-skill-guard.sh:31-35`**
- Matches `*glossary.md` on Read and Grep.
- After the fan-out, a Read of `~/.claude/rules/glossary.md` or `~/.aitools/rules/glossary.md` (the fanned-out project rule) triggers the "use /glossary skill" reminder.
- Harmless: Claude Code's own rule loading is not a Read tool call. No change needed.

**`shared/hooks/delegation-duty-guard.sh:173`**
- Guidance text: "Rules: instruct subagent to read CLAUDE.md and .claude/rules/."
- Once rules live in `~/.claude/rules`, an optional wording is "CLAUDE.md, .claude/rules/ and ~/.claude/rules/".
- Not required. Not protected (shared/hooks).

**`shared/hooks/*.bak.*` (two files)**
- These are stale pre-2026-06-21 copies: `standing-order-guard.sh.bak` logs to `~/.claude/hooks/logs`, and `harness-db-sessionstart.sh.bak` resolves `harness-db.py` from the project only.
- Not deployed by the manifest, and skipped by deploy-harness (`deploy-harness.sh:197`). No fan-out impact. They are cleanup candidates.

**`reference/evaluations/claude-code-macos-2026-10-21.md:78,89`**
- Confirms R3: "operational reference stale (tool-ops-claude-code.md 'Current version' 2.1.81)".
- Open item 2: "Re-verify tool-ops-claude-code.md items #1-#25 at 2.1.307".
- R2 (the new item #28) fits that open item.

**`reference/tool-ops-google-chrome.md:99-113`**
- In the Claude Code web environment the aitools clone is `/home/user/aitools`, and the setup script runs `setup-user-mcp.sh` only.
- Whether the fan-out should run there is still unknown (item 7.7). The planner should state it: `write_environment_skip`, or run.

**`reference/framework-managed-file-deployment.md:27-28`** (protected, `reference/framework-*.md`)
- "every deployment resolves to created, updated, or unchanged". It has no removal outcome, the same gap as R7.
- A change is needed only if retired-rule removal ships.

**Nothing new** for the fan-out in these files:
- `tool-registry.md` (deprecated)
- `claude-code-effectiveness.md` (only the I6 note already in section 8)
- `agentic-framework.md`, `tool-evaluation-playbook.md`, `tool-evaluation-criteria.md`
- `logging.md` (setup scripts log to `deploy.log`; no new file is needed for the fan-out)
- `ait-shellintegration.md`, `cross-platform-detail.md` (the environment API and the `write_environment_skip` wording at :76-79 are already covered)
- `incident-020-process-discipline.md`, `do-what-feels-right.md`, `path-targeted-hooks-analysis.md`
- all `framework-*.md` other than the one above
- `harness-db-schema.sql` (no rules column)
- `evaluations/google-chrome-linux-2026-10-05.md`
- the hooks `block-claude-code-guide.sh`, `block-explore-agent.sh`, `command-channel-stop.sh`, `dashboard-serve.sh`, `failure-mode-*.sh`, `harness-db-session*.sh`, `harvest-session.sh`, `intelligence-stop.{sh,py}`, `scratch-init.sh`, `session-archive.sh`, `session-catchup.sh`, `sh-file-fixup.sh`, `standing-order-guard.sh`, `tool-ops-session-audit.sh`

### 9.2 Open PRs 97-116 that touch my slice

From `gh pr diff <n> -R nobul-tech/aitools --name-only`, run by `.scratch/session-ref/pr-files.sh`. There is no #107 in the open list.

| PR | Files in my slice | Overlap with the fan-out |
|---|---|---|
| #99 | `reference/tool-ops-cursor.md` (new file; not in my list), plus `reference/managed-file-deployment.md` (sibling) | A Cursor ops reference. The Cursor siblings should check it. None in my files. |
| #101 | `reference/logging.md` (adds a `deploy.jsonl` row and section 7 "Library-style tools"), `reference/script-standards-detail.md` (hunks at :85, :179, :249), `reference/tool-support-decision-tree.md` (hunks at :53, :306, :396, :561, :603, :614, :736), plus `reference/user-repo.md` (sibling) and `.claude/rules/managed-file-deployment.md` (hunk at :47-54) | Line-number drift for R6 and R7. It adds the OK-to-WARN row-ordering rule. The managed-file-deployment rule hunk changes the "Template interpolation" and "Machine profile selection" bullets beside `:52` "Rules: additive deploy ..." but leaves that line as context. The S3-FanPlan-Claude/-Misc edit of `:52` must rebase on #101. |
| #97, #98, #100, #102-#106, #108-#116 | none in `reference/` or `shared/hooks/` | — |

### 9.3 Corrections to sections 1-8

- Section 5 is superseded by 9.2: two PRs (#99, #101) touch reference files, and none touches `shared/hooks/`.
- Section 2 now lists every file as read in full.
