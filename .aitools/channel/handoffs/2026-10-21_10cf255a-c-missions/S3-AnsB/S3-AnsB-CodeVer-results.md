# S3-AnsB-CodeVer results: user-repo.md edits A-J and the glossary "profile" edit against code

**Intent**: **Purpose**: State, edit by edit, whether the NEW text of the S3-H2-DraftsM3 drafts is true at origin/main and whether an open PR changes that, with file:line evidence. **Scope**: code facts only. NOT commander intent (S3-AnsB-Transcripts / GitHist). **Audience**: S3-AnsB.

## Summary (5 lines)

1. True as drafted: A, D (strings exact), E, I; B, F, G and J are true but each needs a small precision fix (proposed text below).
2. C is partly true. user init does claim an unowned profile without asking (scripts/aitools:492-496), but the same claim also happens when an alias is typed at the menu or comes from AITOOLS_MACHINE_ALIAS. It fails (ERROR) when this machine already has a profile, or when the profile has machine.environment. The landed bullet "only with `--claim` ... after the user picks that profile at a terminal" (landed user-repo.md:269-271) and the resolver comments (aitools-profile.sh:111-112, :1299; .ps1:1134) are false, so applying C as drafted leaves the doc contradicting itself.
3. H is true: at main, the only config.json content writers are setup-user-config and the entry points' legacy aiToolingRepoPath rename (scripts/aitools:1445-1469, aitools.ps1:444-464). The rename is a one-time legacy migration with no backup and no validation. No open PR touches it. INCIDENT.
4. Decision 2: the switch exists, as one constant per shell: `AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0` (scripts/aitools:143) and `$script:RegisterCachedAliasSilently = $false` (aitools.ps1:761). Today it asks on a terminal and gives ERROR + ACTION without one. setup-user-config never registers.
5. Open PRs: none makes A-J false. #106 makes the landed "Callers" sentence false (the deploy list no longer starts with setup-user-config), and #111 adds `--skip-config`. Both affect edit I's paragraph. #116 shifts scripts/aitools line numbers by about -32 but changes no cited logic. Glossary: "keyed by machine id" is right, and it should get the `environment:<name>` qualifier.

Baseline: origin/main = 480b901. Between 8a9dcb5 and 480b901 only scripts/aitools-lib.ps1 changed among code files (`git diff --stat 8a9dcb5 origin/main`), so every line the drafts cite in scripts/aitools, aitools.ps1, aitools-profile.*, setup-user-config.*, deploy-harness.*, build-deploy.sh is unmoved. Code read in the detached worktree .claude/worktrees/ansb (480b901). Open-PR diffs: `gh pr diff <n> -R nobul-tech/aitools` for #98, #100, #103, #105, #106, #108-#116 (saved under .claude/worktrees/ansb/.scratch/session-codever/diffs/).

## Edit A -- Location convention, build-deploy sentence

| | |
|---|---|
| Verdict on main | TRUE |
| Evidence | scripts/aitools:2032-2050 (`build_env=()`; only when `resolve_user_repo_path` succeeds: `build_env=(AITOOLS_USER_REPO_PATH="$user_repo_path")`), :2055 (`env ${build_env[@]+...} bash .../build-deploy.sh`); aitools.ps1:1970-1982 (`$buildUserRepo` only when `Resolve-UserRepoPath` returns 0), :2001-2008 (set, run, restore in `finally`). check-pre-push.sh:148, :184; check-pre-push.ps1:185, :200. build-deploy.sh:188-209 (env first, else child-bash resolver). Other callers (check-pre-commit.sh:113 / .ps1:112, check-post-push.sh:204 / .ps1:234, githooks/pre-commit, tests/deploy-harness-mdm) do not set it. |
| Not in NEW | When the variable names a missing directory, build-deploy gives a warning and skips the build, exit 0 (build-deploy.sh:214-216). The resolver's "Missing directory = error" rule does not apply there. |
| Open PRs | #112 changes only the child resolver's console fd (pr112 hunk `@@ -199,7 +211,7`: `1>"$_urp_console"`). No effect. |
| Proposed | Draft NEW is fine. Optional precision: `... (the \`aitools\` / \`aitools.ps1\` entry points do, for that one call, with the dotprofile they resolved; check-pre-push step 7 does); otherwise it asks \`resolve_user_repo_path\` in a child bash. A directory that does not exist skips the build with a warning.` |

## Edit B -- "Which dotprofile" step 1

| | |
|---|---|
| Verdict on main | TRUE, slightly imprecise. Who sets it: same evidence as A. "Missing directory = error" is the resolver's rule (aitools-profile.sh:429-433, `add_err "AITOOLS_USER_REPO_PATH does not exist"`, return 2). build-deploy does not go through this step: it reads the variable itself and gives a warning and skips (build-deploy.sh:214-216). |
| Open PRs | #105 changes only the resolver header comment about the variable (pr105: `+# resolve_user_repo_path, unless its caller sets AITOOLS_USER_REPO_PATH), aitools`). No effect. |
| Proposed | `1. \`AITOOLS_USER_REPO_PATH\` (explicit; set by tests, and for build-deploy by the \`aitools\` entry points and check-pre-push step 7). Missing directory = error (build-deploy, which reads it directly, warns and skips its build instead).` |

## Edit C -- Registration, "An alias already used by another profile" (claim)

Verdict on main: PARTLY TRUE. The trace follows.

**`aitools user init --alias X`, where X names a profile with no machine.id**

- Path 1 (scripts/aitools:957-962) and Path 2 (:963-991): `migrate_profile_v1_to_v2`, then `ui_register_flow DIR true`. With a clean, existing profile.json: `ui_migrate`, `ui_resolve`, then `want=X` leads to `ui_register DIR alias X` (:676-679).
- `register --alias X` (aitools-profile.sh:1329-1352) finds the conflict on the alias field or on the key, ignoring case. The other profile's owner comes from `entry_owner` (:549-567), which returns `unregistered` when `machine.id` is empty, unless the key is environment-kind, or the entry is legacy-kind and its key equals this machine's id. The command then gives exit 4 with `owner unregistered`, `ownerKey K`.
- `ui_register` (aitools:490-497) then runs: `if [ "$owner" = "unregistered" ] && [ -n "$okey" ]; then log "... belongs to no machine -- claiming it for this machine"; extra+=(--claim "$okey"); mode=claim; continue`. This happens before `ui_can_ask` (:498). The behaviour is therefore identical with and without a terminal: no prompt, `--claim` passed. PowerShell matches: aitools.ps1:1083-1090, before `Test-UiCanAsk` at :1091.
- Path 3 (:994, then `ui_create_dotprofile`, then `ui_register_flow DIR false` at :819): the new repo has no profile.json, so `ui_scaffold` (:633-642) runs `register --create`. There is no other profile, so no conflict.
- v1 path (:795-799): after a v1 conversion, `ui_register DIR alias $alias false`. The other v1 machines become `machine1`, `machine2`... with no alias field (:765-773), so `--alias machine1` also claims.

**Who else reaches the auto-claim** (not only `--alias`):

- `AITOOLS_MACHINE_ALIAS` naming an existing profile (via=override sets `want`, :676).
- The interactive menu's `[n]` with a typed alias that names an unowned profile (:712-713, then `ui_register alias`).
- The scaffold/v1 default alias (`""`, so the short hostname, aitools-profile.sh:1324) when that hostname is an unowned profile's alias or key.

The menu's numbered pick claims directly (`UI_CHOICE_KIND=claim`, :442-443, :709-710).

**Which profiles count as "belongs to no machine"**

- Every non-environment-keyed profile with an empty `machine.id`, except one whose key equals this machine's id (kind legacy, aitools-profile.sh:525-528 and :556-558). That covers an unregistered 2.1 alias-keyed profile, a v1-converted `machineN`, and an id-shaped key whose `machine.id` was removed: the last is kind legacy, so `--claim` accepts it (:1313) and re-keys it to this id.
- An id-shaped key cannot itself be an alias (`looks_like_id`, :1224, :1326), so it is reached only through its alias field.

**Where the NEW text is wrong or incomplete**

1. If this machine already has a profile (`src` set), the auto-claim produces `--claim: this machine already has profile "..."`, exit 2 (aitools-profile.sh:1309-1311; .ps1:1140-1141). user init then reports ERROR `machine profile` `register failed` (aitools:519-527). It does not claim.
2. A 2.1 profile with `machine.environment` but no id is `unregistered` to `entry_owner`, but `--claim` refuses it with exit 4 (aitools-profile.sh:1313-1316). In claim mode, `ui_register` breaks on any rc (:490) and reports ERROR `registration refused`.
3. The landed bullet right below (landed user-repo.md:269-271: "moved under this id only with `--claim <key>`, which user init passes after the user picks that profile at a terminal") is false at main, and so are aitools-profile.sh:111-112 ("after an interactive choice only"), :1299 and aitools-profile.ps1:1134 ("passed by user init only after the user picked KEY at a terminal"). INCIDENT: the resolver comments contradict the user init code. Edit C as drafted would leave the two bullets contradicting each other.

**Cached config.json machineAlias (resolver step 4L, via=alias; decision 2)**

- The resolver matches it only when config.json has no `machineId` and the cached alias equals a legacy-kind profile's key exactly (aitools-profile.sh:722-738). A profile with another machine's id is ignored with a warning (:730-731).
- user init (aitools:695-701, aitools.ps1:1296-1304): with the switch at 0, `sug=$UI_KEY; rc=100`, then `ui_choose`.
  - On a terminal: the menu, that profile marked `(suggested)`.
  - Without one: ERROR `not registered (no terminal)` + ACTION (aitools:402-406).
  - So it asks or gives ERROR. It never registers silently.
- setup-user-config never writes profile.json. With via=alias, derive-config yields `machineAlias` (aitools-profile.sh:1183-1184), and the warning "has no machine.id -- run: aitools user init" (:603-604) sets `NEED_INIT` (setup-user-config.sh:178-179). The result is the config row plus ACTION `Run: aitools user init (registers this machine)` (setup-user-config.sh:372-380): a WARN-level advice, not ERROR, and no registration.

**Open PRs**: no open PR changes `ui_register`, `cmd_register`'s claim or conflict code, or `ui_choose`. The only hits in changed lines are the `--no-machine` plumbing (#113/#115/#116) and the `--alias` value check (#116: `_pre_lib_errors+=("--alias needs a value ...")`). #116 deletes 32 lines in `ui_profile_run` (hunk `@@ -189,52 +189,20 @@`), so the cited scripts/aitools line numbers shift by about -32. The logic is unchanged.

**Proposed** (replaces both bullets; the commander-intent question stays with the other delegates):

```
- **An alias already used by another profile** (its alias or key, ignoring case) is
  refused with exit 4 and that profile's `owner` / `ownerKey`. When that profile
  belongs to another machine, interactive user init may ask the user to confirm and
  then pass `--allow-duplicate-alias`; the other profile is not touched and every
  resolve of that alias then warns (when the two aliases are identical; one that
  differs only in case does not warn). Without a terminal it is refused (ERROR
  `alias used by another machine`).
- **A profile with no `machine.id`** (unclaimed: a 2.1 alias-keyed profile, or one
  left by the v1 migration) is moved under this id only with `--claim <key>`. user
  init passes it when the user picks that profile in the menu, and also, without
  asking (with or without a terminal), when the alias it registers (`--alias`,
  `AITOOLS_MACHINE_ALIAS`, an alias typed at `[n]ew`, or the default hostname) names
  that profile. The claim fails when this machine already has a profile (exit 2,
  ERROR `register failed`). `--claim` of a profile with a `machine.id` or
  `machine.environment` is refused (exit 4).
```

## Edit D -- "Without a terminal and without `--alias`"

| | |
|---|---|
| Verdict on main | TRUE: strings exact. scripts/aitools:404 `write_summary ERROR "machine profile" "not registered (no terminal)"`, :405 `ui_action "Run: aitools user init --alias <name> (or on a terminal)"` (`ui_action`, so `write_summary ACTION ""`, :177-183); aitools.ps1:1004-1005 identical. |
| Not in NEW | (a) This branch is reached only when profile.json exists and nothing matched by id or environment (via none or hostname, or alias with the switch at 0; aitools:681-706). (b) "Nothing is guessed" is not true of the no-profile.json scaffold and the v1 path. Without a terminal they register under the short hostname (aitools:637-641, :795-799; aitools-profile.sh:1324), which the "Alias" bullet documents. (c) `AITOOLS_MACHINE_ALIAS` counts as `--alias` (:676). |
| Open PRs | #116 adds only an `--alias` without-value error. No effect. |
| Proposed | `- **Without a terminal and without \`--alias\`** (or \`AITOOLS_MACHINE_ALIAS\`), when profile.json exists and no profile matches this machine by id: ERROR \`machine profile\` \`not registered (no terminal)\` + ACTION \`Run: aitools user init --alias <name> (or on a terminal)\`; nothing is guessed (a hostname match or the cached alias is only a suggestion in the menu).` |

## Edit E -- "No profile.json" bullet

| | |
|---|---|
| Verdict on main | TRUE. Path 1 (:961-962) and Path 2 (:990-991) call `ui_register_flow DIR true`, then `ui_scaffold` (:655-656), then `ui_register ... commit=true`, then `ui_commit` (:550-552). Path 3: `ui_register_flow DIR false` (:819) runs before `git init` (:828). The `git add -A` / initial commit (:831-832) includes profile.json. Push: `gh repo create --private --source DIR --push` (:862/864). On a terminal it asks first, default yes (:847-851); without a terminal it proceeds. With gh missing, the user declining, or a failure: WARN `dotprofile` `created, not pushed` + ACTION (:841-845, :855-858, :867-871). |
| Open PRs | None touch these lines. |
| Proposed | Draft NEW is fine. Optional precision: `(commander decision 6; on Path 3 in the new repo's initial commit, pushed with \`gh repo create --push\` -- WARN \`created, not pushed\` + ACTION when gh is missing, the user declines, or it fails).` |

## Edit F -- menu sentence

| | |
|---|---|
| Verdict on main | TRUE, with one omission. Evidence: scripts/aitools:408-427, aitools.ps1:1008-1027. |
| Menu lines | Prompt `Which profile is this machine?`. Profiles appear in file order. `unregistered`: `  [N] <alias>`, plus ` (suggested)` when its key is the suggestion. `other`: `  [-] <alias> (registered to another machine)`, or `(suggested, registered to another machine)`. `this`: no line. Then `  [n] new profile for this machine`, `  [s] skip`. Picking a number claims (:442-443). |
| Omission | A third kind: `unknown` prints `  [-] <alias> (owner unknown: this machine's id cannot be detected)` (:422-423; .ps1:1021-1022). It is reachable when the id is undetectable and nothing matched (register would then refuse with exit 3 anyway). |
| What makes a profile suggested | `sug` is set only for via=`alias` with the switch at 0 (:699-700), or via=`hostname` (:702). It is the resolver's matched key. via=`none` gives no suggestion. |
| "Not already this machine's" | Correct: no case branch for `this` (:413-424). The menu is reached only when not via id/environment/config (:681-706). |
| Open PRs | None touch `ui_choose` / `Read-UiChoose`. |
| Proposed | `The interactive menu lists, in file order and by alias, every profile not already this machine's, then \`[n]ew\` and \`[s]kip\`, identically in bash and PowerShell: a profile that belongs to no machine is numbered (picking it claims it); one registered to another machine is shown as \`[-] <alias> (registered to another machine)\` and cannot be picked; when this machine's id cannot be detected, a profile with a \`machine.id\` is shown as \`[-] <alias> (owner unknown: ...)\`; the resolver's suggestion (the cached alias or a hostname match) is marked \`(suggested)\`.` |

## Edit J -- "user init runs migrate"

| | |
|---|---|
| Verdict on main | TRUE, with two precision points. aitools:655-671: no profile.json leads to the scaffold (no migrate). A dirty profile.json (`ui_profile_dirty`: tracked and with staged or unstaged changes, :350-357) leads to no migrate. Otherwise `ui_migrate` runs every time (:671). |
| Precision | `migrate` is a no-op (`unchanged`) not only when every profile is id-keyed, but whenever no 2.1 profile has a `machine.id` or `machine.environment`. Unclaimed profiles are left as they are (aitools-profile.sh:1476-1481, :1510). |
| Open PRs | #114 splits migrate's "not v2 / no profiles object" message (pr114 hunk `@@ -1455,9 +1466,8 @@ cmd_migrate`). No effect. |
| Proposed | ``aitools user init` runs `migrate` on every run whose existing profile.json has no uncommitted changes (a no-op when no 2.1 profile has a `machine.id` or `machine.environment` to re-key by).`` |

## Edit G -- dirty-file paragraph

| | |
|---|---|
| Verdict on main | TRUE, with one precision point. |
| Resolver commands | `exception-set`: `profile_dirty_before` is checked before the move, then `commit_profile ... "$dirty"`, which warns "profile.json had uncommitted changes before this write -- not committed automatically; review and commit profile.json in DIR by hand" and returns without committing or pushing (aitools-profile.sh:1125-1132, :969-971). `migrate`: same (:1537-1545). PowerShell: aitools-profile.ps1:798. `register` writes only `--out` and never commits (:57-59). user init commits. |
| user init | aitools:657-669 / aitools.ps1:1256-1268. A dirty file leads to `ui_resolve` and no write. If `UI_OWNER=this` and via is `id` **or `environment`**: WARN `not refreshed (local edits)`. Otherwise ERROR `not registered (local edits)`. Both come with ACTION `commit or discard the changes to profile.json in DIR, then run: aitools user init`. The v1 conversion is skipped too: WARN `v1 profile not migrated` + the same ACTION (:746-750). |
| Open PRs | #108 (exception-set write error text) and #114 (messages) do not change the dirty logic. |
| Proposed | Draft NEW, with "matches by id" changed to "matches by id (or environment on Claude Code web)". Optionally append: `A v1 profile.json with uncommitted changes is not converted (WARN \`v1 profile not migrated\` + the same ACTION).` |

## Edit H -- "only writer" exception

Verdict on main: TRUE (see the inventory below). The drafted wording "Known exception, to be removed" is a plan statement, not a code fact. No open PR removes it.

Proposed (keeps the draft and adds the fact that matters):

```
(Known exception, to be removed: the `aitools` entry points still rename the legacy
key `aiToolingRepoPath` to `repoPath` in config.json themselves, once, before the
library loads -- without a backup or validation.)
```

## Edit I -- deploy-harness sentence

| | |
|---|---|
| Verdict on main | TRUE as a fact about deploy-harness. deploy-harness.sh:99-115 runs `"${BASH:-bash}" "$CONFIG_WRITER"` bare, or with `--dry-run`. A failure gives ERROR `harness files` `config.json not generated`. deploy-harness.ps1:89-108 runs `& $configWriter` / `-DryRun`. Bare means re-derive from profile.json and keep the bootstrap keys (setup-user-config.sh:63, :263-282), so "to generate config.json from profile.json" is accurate. |
| Not true yet | On main no entry point or installer runs deploy-harness. `grep -rn deploy-harness` over scripts/aitools, aitools.ps1 and aitools-install.* returns nothing. The MDM path's generated deploy-harness calls deploy/setup-user-config (build-deploy.sh:1637-1642, :1929). |
| Open PRs | **#106** makes deploy-harness installer Step 8b and the first entry of the `aitools` deploy list, and removes setup-user-config from that list (pr106 body: "`setup-user-config` is no longer in the list. `deploy-harness` runs the writer itself with the same bare arguments"; hunks `+local deploy_scripts="deploy-harness.sh setup-user-claude.sh ..."`, `$deployScripts = @("deploy-harness.ps1", ...)`). After #106 the landed "Callers" sentence ("the first entry of every `aitools` deploy list") is false. **#111** adds `--skip-config` / `-SkipConfig`: the writer is not run, and the row is OK `config.json` `n/a (written by installer)`. On the MDM copy it also skips when the bootstrap keys are absent: `n/a (no bootstrap)` (pr111: `+if [ -n "$SKIP_CONFIG" ]; then ... write_summary OK "config.json" "$(short "n/a ($SKIP_CONFIG)")"`). |
| Proposed (main) | `` `deploy-harness` calls it too, without flags (`--dry-run` / `-DryRun` in a dry run), to re-derive config.json from profile.json. Write path: ... `` |
| Proposed (after #106 + #111) | `` Callers: installer Step 5 (bootstrap values), `aitools user init` (...), and `deploy-harness` (installer Step 8b and the first entry of every `aitools` deploy list), which runs it without flags to re-derive config.json from profile.json (not with `--skip-config` / `-SkipConfig`). `` |

## Glossary "profile"

- **origin/main** registries/glossary.json terms["profile"]: "... (one entry of its 'profiles' object, keyed by machine alias) ...". This is false for revision 2.2.
- **#101** (origin/docs/m3-approved-drafts): "profile" is unchanged ("keyed by machine alias"). The draft is not applied. On #101 the "machine profile" term already says "keyed by machine id (environment:<name> for a hosted environment without one)". The "machine alias" term on main still says "The key of a machine profile"; #101 fixes it. (Read with `git show`, read-only, through a scratch script.)
- **Code**:
  - Register writes exactly one key: `key=$(lc "$THIS_ID")`, or `environment:claude-code-web` on Claude Code web (aitools-profile.sh:1258-1270; header :25-30 "keyed by this machine's raw id, lower-cased (`profiles.<machineId>`) ... or `environment:<name>`").
  - `migrate` re-keys to `machine.id` or `environment:<name>` (:1476-1477).
  - 2.1 alias-keyed profiles are still read (:29-30, :525-527).
- **Verdict**: "keyed by machine id" is TRUE. The `environment:<name>` qualifier is needed for parity with the landed "machine profile" term.
- **Proposed fragment**: `(one entry of its 'profiles' object, keyed by machine id, or environment:<name> for a hosted environment)`.

## config.json writer inventory (origin/main 480b901)

Method: grep of every file in scripts/, shared/hooks, shared/shell and scripts/githooks that mentions config.json, for write primitives (writeFileSync, WriteAllText, Set-Content, Out-File, Move-Item, mv, cp, redirects, `pj edit`, Set-JValue). Scan script: .claude/worktrees/ansb/.scratch/session-codever/writers.sh.

| # | File:line | What it writes | Notes |
|---|---|---|---|
| 1 | scripts/setup-user-config.sh:291 (`pj edit` to temp), :341-342 (`backup_file`, `mv`) | managed keys: version, meta, reposPath, repoPath, googleDrives, githubUser, userRepoPath, machineId, machineAlias; deletes a stale machineId (:279) | the designated writer; read-then-merge, validate, backup |
| 2 | scripts/setup-user-config.ps1:291 (WriteAllText temp), :341 (Move-Item) | same | twin |
| 3 | scripts/aitools:1445-1469 (node `fs.writeFileSync(f, ...)`, in place) | adds `repoPath` (from `aiToolingRepoPath`, `ai-tooling`->`aitools`) when absent; deletes `aiToolingRepoPath` | **exception**; runs on every invocation while the old key exists, so it is effectively one-time; legacy rename (repo renamed ai-tooling -> aitools); node required, else silently not migrated (the read falls back, :1440); failure only `_pre_lib_warnings` |
| 4 | scripts/aitools.ps1:444-464 (`ConvertTo-Json`, `[IO.File]::WriteAllText` in place) | same | **exception**; ConvertTo-Json re-formats the file (not the node layout the other writers keep) |
| 5 | scripts/aitools:1427-1428, aitools.ps1:426-427 | `mv ~/.ai-tooling ~/.aitools` (directory move, carries config.json) | not a content write; legacy |
| -- | callers only, no direct write: aitools-install.sh:498-505 / .ps1:384-388 (Step 5), scripts/aitools:1018-1033 / aitools.ps1:1638-1652 (user init), deploy list scripts/aitools:1108, :1151, aitools.ps1:157, deploy-harness.sh:99-115 / .ps1:89-108, build-deploy.sh:1637-1642 (copies the writer into deploy/) | | |
| -- | writes into a temp HOME only: check-pre-push.sh:146, :204; check-pre-push.ps1:177, :223; tests | | not ~/.aitools |
| -- | readers only: ait-harvest.py:198-224, hh.sh:54-62, hh.ps1:34, profile-check.js:19-57, aitools-lib read_config_key, check-lib | | |
| -- | aitools-profile.sh/.ps1 write only profile.json (`--out` / PF) | | |
| -- | scripts/aitools:1723-1730, aitools.ps1:715-722 write `.cursor/mcp.json` (project), not config.json | | |

- **Conclusion**: setup-user-config is the only writer of config.json content except rows 3 and 4. Those rows are a one-time legacy migration.
- **Open PRs**: no changed line in any open PR (#97-#116) mentions `aiToolingRepoPath`, per a grep of the saved diffs. No PR removes or moves it.
- **INCIDENT** (not filed): rows 3 and 4 write config.json without `backup_file` and without post-write validation. The PowerShell twin re-formats the file. Both contradict .claude/rules/config-file-safety.md ("Backup before overwrite", "Post-write validation") and the writer's own claim to be "the only writer" (setup-user-config.sh:2; aitools-lib.sh:117; aitools-lib.ps1:95; aitools:733, :902, :1006). Suggested fix: move the rename into setup-user-config's merge (it already salvages known keys) and delete it from the entry points, or document it as a pre-lib exception.

## Decision 2 switch (M3Lead plan section 2 item 2)

- **What the plan requires** (origin/docs/m3-lead-plan, S3-M3Lead-plan.md section 2 item 2): "keep today's behaviour (ask on a terminal, ERROR without one) behind a one-line switch (a single named variable/constant at the top of the code path, documented in a comment)".
- **What exists**:
  - bash: `AITOOLS_REGISTER_CACHED_ALIAS_SILENTLY=0`, scripts/aitools:143, comment :137-142, read at :696.
  - PowerShell: `$script:RegisterCachedAliasSilently = $false`, aitools.ps1:761, comment :755-760, read at :1297.
  - Each is assigned unconditionally at load, so an environment variable of the same name does not override it.
  - At 1, user init runs `ui_register DIR claim KEY`: a silent claim, with or without a terminal.
- **Flipping**: the decision is one line per shell, two lines in total. Both comments say so.
- **Scope**: the switch covers only via=alias (the cached machineAlias). It does not cover the separate silent claim when an explicit alias names an unowned profile (edit C, scripts/aitools:492-496), which has no switch.
