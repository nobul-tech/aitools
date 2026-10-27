# S3-Reconcile-Docs findings (2026-10-26)

Read-only docs audit for S3-Reconcile. Ref: origin/main 8e18ad4. Its docs are byte-identical to 8e490d7: `git diff --stat 8e490d7 origin/main` touches only `.aitools/channel/handoffs/`. Every file:line below is on origin/main unless a branch is named. Any replacement text for a protected file is a draft and needs commander approval.

## Summary (5 lines)
1. Fan-out: three protected docs say `setup-user-claude` fans rules out from `~/.aitools/rules`. Two more name a nonexistent Claude Code path. The approved #100/#110 Manifest drafts repeat the claim. On main, only `setup-user-cursor` reads `~/.aitools/rules`. D-1..D-6 give "today" and "after FAN-PLAN" wording for each.
2. Not in the brief: on main, neither `aitools` nor `aitools install` runs `deploy-harness` (only the MDM path, or a run by hand). The skills that say "`aitools` (deploy-harness) mirrors reference/" are false until PR #106 merges (D-7).
3. Abort: main's D-TS13 says "Runners stop the run on exit 2". No runner on main does that, and PR #106 already rewrites those lines. The profile-mirror menu text "stop the run" is in code (`aitools-lib.sh:2376`, `.ps1:2359`) and stays wrong on #106 (D-8..D-10).
4. Pre-push step 7: no doc on main still describes the old trigger, apart from history (RELEASE_NOTES, plans). The stale items are the pre-commit steps 3 and 10 docs and code (they stage the frozen `aitools/deploy/`), `deploy-paths.mdc`, README and git-safety/CLAUDE.md `deploy/` (D-11..D-16).
5. Parity: v0.54 (`RELEASE_NOTES.md:1087`) dropped parity, but `cursor-rule-parity.mdc`, `cursor-practices.md:153-179` and `documentation-standards.mdc:36` still require it. Of 16 pairs, 7 diverge materially (section 3). Also found 9 more doc/code disagreements (D-17..D-25), including an N-Q2 gap: deploy-harness never commits dotprofile adopts.

## 1. False or stale statements (deployment area)

Columns: **P** = protected per `.claude/rules/sources-of-truth.md:8-34` (Y/N). **PR** = effect of the open PRs (#99 docs/harness-approved-drafts, #100 feature/harness-rules-manifest, #101 docs/m3-approved-drafts, #106 feature/harness-hookin, #110 feature/harness-cursor-user-rules, #111 feature/harness-mdm-followups), from `git diff origin/main...origin/<branch>`.

### A. Rules fan-out (FAN-PLAN area)

Code facts used below:
- `scripts/setup-user-claude.sh:13,288-292` and `.ps1:12,310` deploy `<userRepoPath>/claude/rules` to `~/.claude/rules`. Neither script mentions `~/.aitools/rules`.
- `scripts/setup-user-cursor.sh:10,378-390` and `.ps1:9,372-383` read `~/.aitools/rules` and write `~/.cursor/rules/*.mdc`. On main they read every name in that directory, so the aitools `.claude/rules` project rules land too. #110 limits this to user-level rules.
- `scripts/deploy-harness.sh:260-263` fills `~/.aitools/rules` from `shared/rules`, `.claude/rules` and the dotprofile `claude/rules`.
- No open PR adds a `~/.aitools/rules` read to setup-user-claude (S3-AnsA §Q2, re-checked: `git grep -i fan origin/main -- scripts/` gives only cursor and build-deploy hits).

**D-1** `.claude/rules/managed-file-deployment.md:48` (P=Y)
- Quote: "Rules reach the tools through the `setup-user-claude` / `setup-user-cursor` fan-out."
- Evidence: the code facts above.
- PR: #101 edits lines 50-51 but leaves 48. The #100/#110/#111 Manifest draft (`S3-H2-Manifest-drafts/dot-claude/rules/managed-file-deployment.md:14`, approved) adds "the fan-out consumers update managed files ... remove the copies of retired rules". That repeats the claim for Claude Code.
- Today: "Rules reach Cursor from `~/.aitools/rules/` through the `setup-user-cursor` fan-out; Claude Code still gets the dotprofile `claude/rules/` from `setup-user-claude` directly." (Once #110 merges: "User-level rules reach Cursor ...".)
- After FAN-PLAN: keep the current sentence. It becomes true. Add "(Cursor: user-level rules only)" if #110 has merged.

**D-2** `.claude/rules/managed-file-deployment.md:52`, `.cursor/rules/managed-file-deployment.mdc:32`, `reference/user-repo.md:183-188` (P=Y)
- Quote: "**Rules**: additive deploy from `<userRepoPath>/claude/rules/` — managed files updated, unmanaged files in target preserved".
- Evidence: true today (the setup-user-claude lines above).
- PR: #101's user-repo.md:446-451 keeps it.
- Today: no change.
- After FAN-PLAN: "**Rules**: additive deploy from `~/.aitools/rules/` (filled by `deploy-harness`) to `~/.claude/rules/` and `~/.cursor/rules/` — managed files updated, unmanaged files in target preserved". Apply the same change to user-repo.md "User Rules Deployment" Source/Target.

**D-3** `.claude/rules/aitools-workspace.md:52` (P=Y)
- Quote: "... — deployed by `deploy-harness`; copied to each tool's rules location by `setup-user-claude` / `setup-user-cursor`".
- Evidence: the code facts above. No PR touches this line.
- Today: "... — deployed by `deploy-harness`; `setup-user-cursor` converts them into `~/.cursor/rules/*.mdc` (Claude Code still gets the dotprofile `claude/rules/` from `setup-user-claude` directly)".
- After FAN-PLAN: "... — deployed by `deploy-harness`; copied to `~/.claude/rules/` by `setup-user-claude` and converted into `~/.cursor/rules/*.mdc` by `setup-user-cursor`".

**D-4** `reference/harness.md:152-155` (P=Y)
- Quote: "conflicts with files already in a tool's own location (`~/.claude/rules/`), which the fan-out in `setup-user-claude` / `setup-user-cursor` handles."
- Evidence: `~/.claude/rules` gets nothing from `~/.aitools`. setup-user-cursor writes `~/.cursor/rules`, not `~/.claude/rules`, and keeps files it did not produce (`setup-user-cursor.sh:19,591`).
- PR: the Manifest draft (`S3-H2-Manifest-drafts/reference/harness.md:33`) adds "The rules fan-out consumers (`setup-user-claude`, `setup-user-cursor`) read it". That is false until FAN-PLAN.
- Today: "conflicts with files already in a tool's own rules location: `setup-user-cursor` reviews the `~/.cursor/rules/<name>.mdc` files it produces and keeps every other file there; `~/.claude/rules/` is not fed from `~/.aitools/rules/` yet (`setup-user-claude` deploys the dotprofile `claude/rules/` directly)."
- After FAN-PLAN: "conflicts with files already in a tool's own rules location (`~/.claude/rules/`, `~/.cursor/rules/`), which the fan-out in `setup-user-claude` / `setup-user-cursor` handles."

**D-5** `.claude/rules/hook-rollout.md:109-112` (P=Y), `.cursor/rules/hook-rollout.mdc:32` (P=Y), `shared/skills/scratch/SKILL.md:202-204` (P=N)
- Quotes:
  - md: "(deployed to `~/.claude/rules/hook-lifecycle.md` once a deploy path for `shared/rules/` exists)"
  - mdc: "user-level rule `shared/rules/hook-lifecycle.md` (not yet deployed)"
  - skill: "deployed to `~/.claude/rules/` once deploy-harness ships a path for `shared/rules/`"
- Evidence:
  - deploy-harness already ships `shared/rules` (`deploy-harness.sh:260`).
  - setup-user-cursor fans it out to `~/.cursor/rules/hook-lifecycle.mdc`, so the mdc's "not yet deployed" is false whenever deploy-harness has run. The MDM order runs it first (`build-deploy.sh:855`).
  - The missing piece is setup-user-claude, not deploy-harness. Caveat: on main's dev path nothing runs deploy-harness (D-7).
- PR: none touch these.
- Today: "(copied to `~/.aitools/rules/` by `deploy-harness` and on to `~/.cursor/rules/hook-lifecycle.mdc` by `setup-user-cursor`; it reaches `~/.claude/rules/` once `setup-user-claude` fans out `~/.aitools/rules/`)". Skill and mdc use the same wording.
- After FAN-PLAN: "(deployed to `~/.claude/rules/hook-lifecycle.md` and `~/.cursor/rules/hook-lifecycle.mdc` through `~/.aitools/rules/`)".

**D-6** `scripts/build-deploy.sh:1913-1914` and `:2063-2064` (generated deploy-harness header; code comment, P=N)
- Quote: "setup-user-cursor (and the other rules fan-out consumers) read ~/.aitools/rules".
- Evidence: there are no other consumers on main.
- PR: #111 keeps it (`build-deploy.sh:1949,2171` on the branch).
- Today: "setup-user-cursor reads ~/.aitools/rules, which this script fills."
- After FAN-PLAN: the current text becomes true.

### B. Who runs deploy-harness

**D-7** `.claude/skills/tool-ops/SKILL.md:50-52` and `shared/skills/aitool-ops/SKILL.md:63-65` (P=N)
- Quotes: "`aitools` (deploy-harness) mirrors the repo `reference/` tree there" and "`aitools` (deploy-harness) mirrors the aitools repo `reference/` tree there."
- Evidence:
  - The deploy_configs lists on main have no deploy-harness: `scripts/aitools:1108` (.ps1 list) and `:1150` (.sh list) start with `setup-user-config`.
  - `git grep deploy-harness origin/main -- scripts/` finds no call in `aitools`, `aitools.ps1` or `aitools-install.*`.
  - #106 adds it: `scripts/aitools:1121,1174` and `aitools-install.sh:661-669` ("Step 8b") on its branch.
- PR: #106 makes these lines true. #99 edits only the tool-ops skill intent (lines 7-11).
- Today: "`deploy-harness` (`scripts/deploy-harness.sh` / `.ps1`, or the MDM `deploy/deploy-harness.*`) mirrors the repo `reference/` tree there."
- After #106: no change. Suggest leaving these lines alone and merging #106.
- The same caveat applies to every "deployed by `deploy-harness`" row in `aitools-workspace.md:49-54`. Those rows are correct about which script deploys. They do not say that the dev path never runs it before #106.

### C. Abort

**D-8** `reference/tool-support-decision-tree.md:65` (D-TS13 row), `:442-482` (section 7.5), `:707-718` (section 10 rows) (P=N; the file is not in the protected table)
- Quotes:
  - "Runners stop the run on exit 2 (section 7.5)"
  - "exit 2 = user abort. The runner writes no failure row ... skips the remaining scripts in its loop"
  - "sync path, managed-file `x` | ... write no ERROR row and skip the remaining deploy scripts"
- Evidence on main:
  - `deploy_configs` (`scripts/aitools:1136-1140`, `:1171-1176`) and `validate_and_run` (`aitools-install.sh:235-239`) log any non-zero exit as ERROR and continue.
  - Only `aitools user init` handles 2 (`scripts/aitools:1052-1053`).
  - Commander 2026-10-26: keep #106's behaviour (only a deploy-harness exit 2 stops a run).
- PR: #106 rewrites all three spots and `plans/tool-support-and-machine-profile.md` T-Q3. Its text is the replacement. No further draft is needed.

**D-9** `.claude/rules/interactive-menus.md:113-120` (P=Y) and code `scripts/aitools-lib.sh:2376`, `scripts/aitools-lib.ps1:2359`
- Quote (profile-mirror menu): "[x]abort    : stop the run"
- Evidence: false on main. On main, setup-user-settings' exit 2 gets an ERROR row from either runner, and the run goes on. It is also false on #106: the menu text is unchanged there (`git grep "stop the run" origin/feature/harness-hookin -- scripts/aitools-lib.*`), and #106 only adds a disclaimer at `interactive-menus.md:133-135`: "Despite the menu text, the run does not stop".
- Proposed fix: change the string in both libs (menu parity) and in the rule to "[x]abort    : stop this script (exit 2)". That matches `prompt_diff_review` (`aitools-lib.sh:1735`, `.ps1:1692`) and `reference/managed-file-deployment.md:136,149,164`. Then #106's disclaimer can drop "Despite the menu text". This is a code change plus protected text.

**D-10** `.claude/rules/interactive-menus.md:58-60`, `:122-123`; `.cursor/rules/interactive-menus.mdc:23`; `reference/managed-file-deployment.md:171-176` (P=Y)
- Quote: "Abort ends this setup script; the installer continues with the next script."
- Evidence: true on main. It names only the installer, and the `aitools` sync also continues (`scripts/aitools:1136-1140`). It becomes false for deploy-harness once #106 merges.
- PR: #106 rewrites all four places, .md and .mdc consistently. No extra draft. This also answers the brief's abort item: on main and on #106, every doc that says abort "stops the run" is either rewritten by #106 or is D-9.

### D. Pre-push / pre-commit / build-deploy

**D-11** Old step-7 trigger.
- No doc on main still says step 7 runs "only when shared/ changes" or similar.
- Checked with `git grep -i -E "step 7|deploy-relevant|pre-push"` over `.claude/rules`, `.cursor/rules`, `reference`, `shared`, `.claude/skills`, `CLAUDE.md` and `README.md`.
- The only hits are the updated `reference/pre-push-checklist.md:40` and the updated `check-pre-push.sh:110-116` / `.ps1:113-120` comments.
- History, not to fix: `RELEASE_NOTES.md:2327,2339-2340`; `plans/linux-install-hardening.md:3852-3855,4180-4272`.
- S3-AnsA's INCIDENT ("step 7 trigger misses deploy-harness sources") is resolved by 8e490d7. Do not file it.

**D-12** `.cursor/rules/deploy-paths.mdc:24` (P=Y)
- Quote: "3. Verify via pre-commit steps 3+10"
- Evidence:
  - `.claude/rules/deploy-paths.md:39` says steps 3+10 "no longer apply".
  - `check-pre-commit.sh:106-120` runs build-deploy, then `git add deploy/` in aitools.
  - build-deploy writes `<dotprofile>/deploy` (`build-deploy.sh:218`). The last commit to touch aitools `deploy/` is bda38a2 (`git log -2 origin/main -- deploy/`).
- PR: #99 keeps this line. S3-AnsA Q4 limit 2 says #99 inherited it rather than introduced it.
- Replacement: "3. Verify the dotprofile `deploy/` includes the change (pre-commit steps 3+10 look only at the frozen `aitools/deploy/`; pre-push step 7 rebuilds into a temporary copy of the dotprofile on every push and FAILs on a stale dotprofile `deploy/`)"

**D-13** `.cursor/rules/deploy-paths.mdc:12,18,23` (P=Y)
- Quotes:
  - "2. **MDM path** (`deploy/setup-*.sh/.ps1`): self-contained with build-time embedded content. Generated by `build-deploy.sh`."
  - "3. Run `build-deploy.sh` to regenerate `deploy/`" (twice)
- Evidence: `deploy-paths.md:23-25` and `build-deploy.sh:218`.
- PR: #99 keeps :12 and :18. On :23 it appends a note but keeps "`deploy/`".
- Replacements:
  - :12: "2. **MDM path** (`<userRepoPath>/deploy/setup-*.sh/.ps1`): self-contained, generated by `build-deploy.sh` into the dotprofile repo. The shared `aitools/deploy/` is frozen."
  - :18 and :23: "Run `build-deploy.sh` to regenerate `<userRepoPath>/deploy/`".

**D-14** `.claude/rules/deploy-paths.md:47-63` and `.cursor/rules/deploy-paths.mdc:32-41` (P=Y)
- Quotes: "Three script pairs have **duplicated setup logic**" (.md, which lists setup-user-claude and -cursor) and "Four script pairs" (.mdc, which also lists `setup-user-mcp` "Settings.json merge, validation").
- Evidence: `setup-user-mcp.sh:6,10` says "does NOT write ~/.claude/settings.json". The approved #99 text records claude and cursor as pure extract (M3 B5).
- PR: #99 fixes both (approved, "1d").
- Replacement: none beyond #99.

**D-15** `reference/pre-commit-checklist.md:20-22` and `:54-57` (P=N)
- Quotes:
  - "If any file in `scripts/` or `shared/` was modified, run `bash scripts/build-deploy.sh` and include the regenerated `deploy/` in the commit."
  - "If step 3 ran (build freshness), verify no unstaged deploy/ changes remain after staging"
- Evidence: as D-12. The build no longer writes aitools `deploy/`, so step 10 passes vacuously.
- Replacements:
  - step 3: "If any file in `scripts/` or `shared/` was modified, run `bash scripts/build-deploy.sh` and commit the regenerated `deploy/` in the dotprofile repo (`<userRepoPath>`). The shared `aitools/deploy/` is frozen; `--fix` still stages it (see INCIDENT)."
  - step 10: "Checks for unstaged changes in the frozen `aitools/deploy/` only; the dotprofile `deploy/` is checked by pre-push step 7."

**D-16** `.claude/rules/git-safety.md:3-11`, `.cursor/rules/git-safety.mdc:12-20`, `CLAUDE.md:42` (P=Y)
- Quotes:
  - "`deploy/` is 100% generated by `build-deploy.sh`."
  - "After running `build-deploy.sh`, `deploy/` will have uncommitted diffs (newly generated content). These are expected. They are committed as part of the normal release flow and cleared by the pre-pull reset on the next run."
  - CLAUDE.md: "`deploy/` — generated by `build-deploy.sh`; ephemeral, reset on each `aitools` run."
- Evidence: `build-deploy.sh:218`, `deploy-paths.md:25`, `README.md:11`. The pre-pull reset still exists (`scripts/aitools:1984,2005`, `aitools.ps1:1932`).
- Replacements:
  - git-safety (.md and .mdc): "### deploy/ is frozen\n\n`deploy/` in this repo is a frozen historical baseline: `build-deploy.sh` writes the generated deploy scripts into the dotprofile repo (`<userRepoPath>/deploy/`, `@.claude/rules/deploy-paths.md`), not here. The `aitools` entry points still reset `deploy/` to HEAD before every pull (`git checkout HEAD -- deploy/`), so uncommitted changes in it do not survive an `aitools` run."
  - CLAUDE.md:42: "- `deploy/` — frozen historical baseline (`build-deploy.sh` now writes `<userRepoPath>/deploy/` in the dotprofile repo); reset to HEAD on each `aitools` run."
- Note: CLAUDE.md is under the channel exception for the commit path, but its content is still protected.

### E. config.json writer, deploy state, profile resolution, adopt

**D-17** "Only config writer" (low severity)
- Where (P=Y unless noted): `reference/harness.md:109-110` ("calling the only config writer, `scripts/setup-user-config.sh` / `.ps1`"), `.claude/rules/config-file-safety.md:166` and `.mdc:60` ("Single config writer"), and the code comments `aitools-install.sh:498`, `aitools-install.ps1:384`, `deploy-harness.sh:7`.
- Evidence: `scripts/aitools:1445-1458` and `scripts/aitools.ps1:444-457` rewrite `~/.aitools/config.json` (the `aiToolingRepoPath` → `repoPath` migration, before the library loads).
- Option A (code): delete the legacy migration. The docs then become true.
- Option B (docs), harness.md: "by calling its writer, `scripts/setup-user-config.sh` / `.ps1` (the only other write is the entry points' legacy `aiToolingRepoPath` → `repoPath` migration)".
- Suggest A.

**D-18** `.claude/rules/aitools-workspace.md:48` (P=Y)
- Quote: "| `deploy-state/` | Last-deployed file hashes for drift detection |"
- Evidence: `aitools-lib.sh:961-968` ("Deploy state (~/.aitools/deploy-state/) is no longer used"), `aitools-lib.ps1:857`, `check-post-push.sh:740`, `agentic-standards.md:58`.
- Replacement: "| `deploy-state/` | Unused since 2026-10-21 (no deploy state: SOURCE is the source of truth); older machines keep the directory and nothing reads or writes it |". Or delete the row.
- Related, low: `reference/logging.md:38` lists "deploy-state" among the namespace contents.

**D-19** `reference/agentic-framework.md:170-178` (P=Y)
- Quote: "## Deploy state migration ... Pattern: when `get_deploy_shadow` returns empty but file exists on disk, seed shadow with current content before attempting auto-merge."
- Evidence: `reference/managed-file-deployment.md:40-42,274-276` ("Removed 2026-10-21 ... `Get-DeployShadow`").
- Replacement: "## Deploy state migration\n\nRemoved 2026-10-21: there is no deploy state, shadow or ancestor (`@reference/managed-file-deployment.md` \"Deploy State\")."

**D-20** `.claude/rules/managed-file-deployment.md:50-51` and `.mdc:30-31` (P=Y)
- Quotes: "replaced with `profile.json` values at deploy time" and "`config.json` `machineAlias` → `profile.json` `profiles[alias]`. Fallback: hostname match, then first profile".
- Evidence: `aitools-profile.sh:475-489` ("6 none: error; never another profile's values").
- PR: #101 fixes both, with approved M3 text. No draft needed.

**D-21** `reference/managed-file-deployment.md:393` (P=Y)
- Quote: "| Machine profile | `<userRepoPath>/profile.json` `profiles[machineAlias]` section | hostname match, then first profile |"
- Evidence: same as D-20. No open PR changes this line.
- Replacement: "| Machine profile | `<userRepoPath>/profile.json` `profiles[<machine id>]`, chosen by the resolver (`aitools-profile.sh` / `.ps1`) | none: no match is an ERROR, never another machine's profile |". Add the cross-ref `@reference/user-repo.md` "Resolution" once #101, which adds that heading, merges.

**D-22** `reference/user-repo.md:195` (P=Y)
- Quote: "`build-deploy.sh` reads user rules at build time and embeds them in deploy scripts via heredocs. If no rules exist at build time, deploy scripts skip rules deployment."
- Evidence: `build-deploy.sh:692-700`. The embedded copy is only a fallback, used when the machine has no dotprofile.
- PR: #101 fixes it (branch `user-repo.md:458-460`). No draft needed.

**D-23** `.claude/rules/managed-file-deployment.md:34-35` and `.mdc:21` (P=Y), against `deploy-harness`
- Quote: "An adopt target in the dotprofile repo is committed and pushed to its main automatically (N-Q2)."
- Evidence:
  - deploy-harness passes the dotprofile rule file as the adopt target (`deploy-harness.sh:263,309`).
  - Neither `deploy-harness.sh` nor `deploy_managed_file` commits: `git grep -E "git .*(commit|push)" origin/main -- scripts/aitools-lib.sh scripts/deploy-harness.sh` gives no hit.
  - Only some callers commit, e.g. `setup-user-claude.sh:373-386` for rules.
  - `reference/harness.md:163-165` says "the library never commits or pushes".
- Today the statement is false for deploy-harness adopts. N-Q2 is binding (packet §6), so fix the code, not the doc (INCIDENT).

### F. Cursor-side and template docs

**D-24** `shared/cursor-rules/user-rules.md:7` (P=Y)
- Quote: "The `setup-user-cursor` script copies this to your clipboard automatically."
- Evidence: no clipboard code (`git grep -i -E "clipboard|pbcopy|Set-Clipboard" origin/main -- scripts/setup-user-cursor.*` gives no hit). `reference/cursor-practices.md:139` says it was removed.
- PR: #99 edits line 28 of this file (S3-AnsA Q3), not line 7.
- Replacement: "Copy it by hand; no setup script copies it (the clipboard step was removed)."

**D-25** `reference/cursor-practices.md:125-133` and `:149` (P=N)
- Quotes:
  - The Rule Sources table has no user-level rule files.
  - :149: "`deploy/setup-user-claude.sh/.ps1` have the shared content embedded at build time."
- Evidence: Cursor loads `~/.cursor/rules/*.mdc` for every workspace, and setup-user-cursor deploys there (`setup-user-cursor.sh:378-390`). The deploy scripts live in `<userRepoPath>/deploy/` (`build-deploy.sh:218`).
- Replacements:
  - Add the row "| User rules (files) | `~/.cursor/rules/*.mdc` | Deployed by `setup-user-cursor` from `~/.aitools/rules/` (converted from `.md`) |".
  - :149: "`<userRepoPath>/deploy/setup-user-claude.sh/.ps1` (the dotprofile repo) have the shared content embedded at build time."
- #99 adds `reference/tool-ops-cursor.md`. Check it for overlap.

### G. Low-severity extras (item 8)
- `README.md:129,137` say "12 steps" for pre-commit; the code has steps 1-20. `README.md:131,139` say post-push has "all 20 steps"; the code emits steps up to 32. `README.md:101` says the optional githook "regenerates `deploy/`", but `scripts/githooks/pre-commit:13-16` builds into the dotprofile and `git add`s aitools `deploy/`. P=N.
- `.claude/rules/tool-lifecycle.md:97` ("`CLAUDE.md` — deploy list") and `.cursor/rules/tool-lifecycle.mdc:58` ("add `setup-<tool>` to "Deploy using MDM" tool scripts list"): CLAUDE.md has no such list (`git grep -i "deploy using mdm|deploy list" origin/main -- CLAUDE.md` gives no hit; `shared/skills/tool-adopt/SKILL.md:161-162` says so too, incident #65). P=Y. Replacement: delete the bullet in both.
- `reference/managed-file-deployment.md:389`: "User rules ... Fallback (none — no rules deployed)". The MDM path does have the embedded fallback (`build-deploy.sh:692-700`). P=Y. Replacement: "(dev path: none; MDM path: the build-time copy when the machine has no dotprofile)".
- `reference/harness.md:156-158` "**No deletion.**" is true on main. It becomes false for rules when #100/#110/#111 merge (retired rules), and the approved Manifest draft covers that.

## 2. Fan-out wording, both variants (for the plan)
| Doc | Today (FAN-PLAN not landed) | After FAN-PLAN |
|---|---|---|
| managed-file-deployment.md:48 | D-1 today text | current text (true) |
| managed-file-deployment.md:52, user-repo.md:183-188 | unchanged | D-2 text |
| aitools-workspace.md:52 | D-3 today | D-3 after |
| harness.md:152-155 | D-4 today | D-4 after |
| hook-rollout.md:111-112, .mdc:32, scratch SKILL:202-204 | D-5 today | D-5 after |
| build-deploy.sh:1913-1914, 2063-2064 | D-6 today | current text |
| Manifest drafts (#100: dot-claude managed-file-deployment.md:14, harness.md:33) | reword "the fan-out consumers" to "`setup-user-cursor` (and `setup-user-claude` once it fans out)" | as drafted |

## 3. Parity verdict

What the docs require, verbatim:
- `.cursor/rules/cursor-rule-parity.mdc:9` (alwaysApply: true): "When modifying rules in `.claude/rules/*.md`, also update the corresponding `.cursor/rules/*.mdc` file (and vice versa). See the Rule Correspondence table in `reference/cursor-practices.md`."
- `reference/cursor-practices.md:153`: "Cursor project rules mirror Claude Code rules for consistency. When changing rules, update both sets."
- `reference/cursor-practices.md:173-179` ("Changing rules"): "1. Make the change in the primary file 2. Mirror or update the corresponding file in the other rules directory 3. Update the table above if the correspondence changes".
- `.cursor/rules/documentation-standards.mdc:36`: "**Cursor parity** — `.cursor/rules/*.mdc` mirrors `.claude/rules/*.md`. See `@.claude/rules/cursor-rule-parity.md`". That target file was deleted in v0.54 (`.claude/skills/audit/tests/expected-behaviors.md:13`).
- Local parity duties that still exist: `.claude/rules/managed-file-deployment.md:100-102` (a new row also updates the .mdc), `.cursor/rules/tool-lifecycle.mdc:138` ("plus Cursor `.mdc` parity") and `.claude/rules/interactive-menus.md:16-20` (PS1/bash menu parity; a different meaning).
- Against all of these: `RELEASE_NOTES.md:1087` (v0.54, 2026-03-13): "**Cursor rule parity killed**: Removed `cursor-rule-parity.md` rule. Claude Code and Cursor are separate tool harnesses managed independently — no parity requirement." `.claude/rules/documentation-standards.md` has no parity bullet.
- Whether the v0.54 decision was the commander's own words is unknown. The commander's "1d) approved" treats `deploy-paths.mdc` as a maintained twin.

The correspondence table (`cursor-practices.md:155-171`) is itself stale:
- It lists `.claude/rules/cursor-rule-parity.md`, which does not exist.
- It shows smoke-test-pattern as "—", but `.cursor/rules/smoke-test-pattern.mdc` exists.
- It omits the agentic-standards, git-safety and managed-file-deployment pairs.
- It calls sources-of-truth and tool-lifecycle "Near-identical", which is false (below).

Pairs (16), read on origin/main. Line counts come from the scratch script `pair-compare.sh` (md/mdc):
| Pair | Material divergence |
|---|---|
| deploy-paths (82/41) | mdc:12,18,23,24 (D-12, D-13); mdc:32-39 "Four pairs" incl. mcp (D-14, fixed by #99); mdc lacks the "What IS auto-embedded" list and the I6 note |
| config-file-safety (172/66) | mdc:62 "PowerShell merge: `scripts/setup-user-mcp.ps1` (settings.json)": false, setup-user-mcp writes no settings.json (`setup-user-mcp.ps1:5,9`); md:168 names `setup-user-settings` "Settings sync". mdc:66 "Inline Node.js validation: `scripts/setup-user-mcp.sh`" vs md:172 `setup-user-hooks.sh`. Replace mdc:62 with "- Settings sync (field-level review): `scripts/setup-user-settings.sh` via `sync_managed_json` (settings.json <-> profile.json)"; mdc:66 with "`scripts/setup-user-hooks.sh`" |
| documentation-standards (114/46) | mdc:36 parity bullet with a broken reference (md has none); mdc lacks "Skill placement" |
| hook-rollout (112/32) | mdc:32 "(not yet deployed)" vs md:111-112 (both stale, D-5) |
| sources-of-truth (60/44) | mdc lacks 12 protected rows (`.claude/rules/managed-file-deployment.md`, `.claude/rules/frameworks.md`, `reference/managed-file-deployment.md`, `reference/harness.md`, `reference/framework-*.md`, `reference/framework-tool-ops.md`, `reference/incident-*.md`, `reference/tool-ops-*.md`, `registries/incidents.json`, `framework-registry.json`, `glossary.json`, `tool-ops.json`) and the "Intent statements" section, so Cursor agents are not gated on them |
| tool-lifecycle (133/139) | Structurally different: mdc has "Lifecycle field completeness", "Install command verification gate", "Cross-platform vetting", "MCP server isolation/disable scope" and "Deployment pattern updates", none of which are in md. Both carry the stale CLAUDE.md deploy-list bullet (G). mdc:9 points at `reference/tool-evaluation-criteria.md` |
| managed-file-deployment (114/68) | mdc lacks the md:48 `~/.aitools` (`deploy-harness`) content-sources row, so it also lacks the false fan-out claim. #101 edits both consistently |
| interactive-menus (131/30) | consistent on main; #106 edits both |
| git-safety (27/36) | identical body (both stale, D-16) |
| cross-platform (200/82) | condensed; md:9 `C:\repos` (fixed in md only by #99; mdc has no repos line) |
| agentic-standards, script-standards, plan-execution, relay-outbound, smoke-test-pattern, web-sources | no material divergence in the deployment area. agentic-standards and web-sources bodies match; the others were read condensed |

No .mdc twin: aitool-eval, aitool-ops, aitools-workspace (deployment-relevant), artifact-harvesting, frameworks, glossary, governed-data-access, incident-governance, tool-evaluation, tool-ops. Only .mdc: cursor-rule-parity, general.

Observation (#110 territory): on main, setup-user-cursor fans out all of `~/.aitools/rules`, which includes the aitools project rules from `.claude/rules`. They land at user level in `~/.cursor/rules` for every workspace, and the aitools repo also loads its own `.cursor/rules` twins. #110 limits the fan-out to user-level rules.

## 4. INCIDENT markers (not filed)
- INCIDENT (medium): five protected docs (managed-file-deployment.md:48, aitools-workspace.md:52, harness.md:152-155, hook-rollout.md:111-112 and .mdc:32) and the approved Manifest drafts describe a `setup-user-claude` `~/.aitools/rules` fan-out, or a missing deploy path, that is not how main works. Same as the S3-AnsA marker, now extended.
- INCIDENT (medium): `check-pre-commit.sh:106-120` / `.ps1` (steps 3, 10) and `scripts/githooks/pre-commit:13-16` run build-deploy (which writes the dotprofile) and then `git add deploy/` in the aitools repo. That stages the frozen directory, and step 10 passes vacuously. Docs: D-12, D-15.
- INCIDENT (medium): deploy-harness adopts into the dotprofile `claude/rules/` are not committed or pushed, contrary to N-Q2 (`managed-file-deployment.md:34-35`). D-23.
- INCIDENT (low): the profile-mirror menu text "stop the run" (`aitools-lib.sh:2376`, `.ps1:2359`) misstates the abort scope on main and on #106. D-9.
- INCIDENT (low): the parity record contradicts itself (v0.54 "parity killed" vs cursor-rule-parity.mdc / cursor-practices.md / documentation-standards.mdc:36 with a broken reference). The correspondence table is stale. No check enforces either position.
- INCIDENT (low): `.cursor/rules/sources-of-truth.mdc` lacks 12 protected files and the intent-statement gate.
- INCIDENT (low): stale deploy-state docs (`aitools-workspace.md:48`, `agentic-framework.md:170-178`).
- INCIDENT (low): config.json "only writer" is not true while the entry points' legacy migration exists (D-17).
- INCIDENT (low, governance): `shared/rules/*.md` (user-level rules deployed through `~/.aitools/rules`) are not in the protected table (`sources-of-truth.md:8-34`).

## 5. Open questions (with suggested answers)
1. Fan-out docs now, or after FAN-PLAN? Suggest: apply the "today" variants in one protected batch now, written so they read correctly before and after (the "once it fans out" pattern, S3-AnsA Q2). Reword the Manifest drafts the same way before #100/#110 merge.
2. Are .mdc twins still required? Suggest: yes, for twins that exist (the commander's "1d" maintains `deploy-paths.mdc`). Delete `cursor-rule-parity.mdc` only if he confirms v0.54. Either way, fix `documentation-standards.mdc:36` (broken reference) and the correspondence table.
3. D-9 menu text: change the code string, or keep #106's disclaimer? Suggest: change the code (both libs) to "stop this script (exit 2)". It is a one-line parity fix, and the docs then need no "despite the menu text".
4. D-17: delete the legacy `aiToolingRepoPath` migration, or reword the docs? Suggest: delete it. The rename is old, and "one writer" is a stated design.
5. D-23: fix the code or the doc? Suggest: the code. N-Q2 (dotprofile writes auto-commit and push) is a binding decision.
6. Pre-commit steps 3/10: retarget them to the dotprofile, or drop them now that pre-push step 7 always runs? Suggest: drop the `git add deploy/` and turn step 3 into a WARN that names the dotprofile rebuild. Step 7 is the real check.

## 6. Method and limits
- Scratch: `/Users/new-jose/repos/aitools/.scratch/session-rcdocs/`. Sweeps: `sweep.sh` (hits in `sweep-hits.txt`), `sweep2.sh` (`sweep2-hits.txt`), `prfiles.sh` (`prfiles.txt`), `dump-mdc.sh` (`mdc-dump.txt`), `pair-compare.sh` (`pair-compare.txt`, copies in `pairs/`).
- Not done:
  - `plans/*.md` not audited (only grepped for step 7).
  - The #99 `reference/tool-ops-cursor.md` not read.
  - The #101 user-repo.md rewrite read only around rules.
  - script-standards.mdc read condensed.
  - No transcript reads; I rely on the decisions in the common brief.
- Caution for S3-Reconcile: the `.claude/rules` text injected into my context at session start was older than origin/main. For example, its aitools-workspace.md lacked rows 49-53. Every quote above comes from `git show origin/main:` or from the working tree, which `git diff --stat origin/main -- .claude/rules/` shows equals main.
- No sub-delegates used.
- WRITE_BLOCKED: none. standing-order-guard refused two Bash commands because each had a backtick inside a quoted pattern: one grep, and one perl substitution on this file. I reran the grep as a scratch script and made the edits with the Edit tool instead.
- Line numbers were checked with the scratch script `verify-lines.sh`.
