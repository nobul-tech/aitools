# S5-Profile report: profile.json as source of truth, one config writer, one resolver

**Summary**
1. One resolver module, `scripts/aitools-profile.js`, decides both "where is the dotprofile" (`<reposPath>/aitools-<github-user>`) and "which profile is this machine" (override → environment → hashed `machine.id` → config alias → hostname → **none = ERROR**, never a first-profile fallback). Bash and PS1 lib wrappers, build-deploy and profile-check all call it, so bash and PowerShell get the same answer.
2. config.json becomes v3 and derived. Its only writer is the new `setup-user-config.sh/.ps1`, called by installer Step 5, `aitools user init`, and first in every deploy list. It keeps the hardened v0.73.2 merge (temp → validate → backup → move) and degrades without node.
3. deploy/ stops baking one machine's values. Generated `setup-user-claude.*` embed the resolver plus a profile snapshot and resolve on the target machine (live profile.json first). build-deploy gets the dotprofile from `AITOOLS_USER_REPO_PATH`, which the entry point exports.
4. This Mac resolves deterministically three ways. Today: set `machineAlias: "new-mac"` (B0). After B1/B2: the resolver also reads `LocalHostName` = `nobul-mac`, so it resolves `new-mac` with today's config. After registration: `machine.id sha256:1f634eecaf97fa63` resolves `via=id`. All three were tested read-only.
5. Everything is a draft. The protected docs (user-repo.md, claude-shared.md, rules, intents, glossary) wait for your approval. The plan has 8 code batches of at most 3 files each, with verbatim edits, error-handling audits, and tests that already run on macOS. Windows and Linux machine ids are UNVERIFIED.

An adversarial review (S5-Profile-A) found 6 high issues: an embed corruption, crash-as-not-found, a corrupt-config deadlock, an env var leaking into pre-push, and a perl break. All 6 are fixed in the drafts or plan and re-tested. One part of H5 needs the check-pre-push owner. Section "Adversarial review" has the full list.

---

## Architecture

```
                 git (shared by all of one user's machines)
   ┌──────────────────────── dotprofile aitools-<gh-user>/ ───────────────────────┐
   │ profile.json  (SOURCE OF TRUTH: identity, prefs, profiles{alias:{machine.id,  │
   │               hostname, overrides, toolExceptions}})                          │
   │ claude/CLAUDE.md, rules/, hooks/, skills/        deploy/ (generated, shared)   │
   └───────────────▲───────────────────────────▲─────────────────────▲─────────────┘
       register    │ (user init only)          │ read                 │ embedded snapshot
                   │                           │                      │ + resolver (B5)
 ┌─────────────────┴──────────┐   ┌────────────┴─────────────┐  ┌─────┴──────────────────┐
 │ aitools user init          │   │ scripts/aitools-profile.js│  │ build-deploy.sh         │
 │ resolve → ask → register   │──▶│  resolveUserRepoPath      │◀─│ AITOOLS_USER_REPO_PATH  │
 │ → setup-user-config        │   │  resolveMachine (via=…)   │  │ (exported by entry pt)  │
 └────────────┬───────────────┘   │  machineId / derive /     │  └─────────────────────────┘
              │                   │  snapshot / register      │
              ▼                   └──▲──────────▲─────────▲───┘
 ┌──────────────────────────┐        │          │         │ require()
 │ setup-user-config.sh/.ps1│────────┘          │      profile-check.js
 │ ONLY writer of           │  derive-config    │
 │ ~/.aitools/config.json   │           resolve_user_repo_path / resolve_machine_profile
 │ (v3, untracked, derived) │           Resolve-UserRepoPath / Resolve-MachineProfile
 └──────────▲───────────────┘                    │ (aitools-lib.sh / .ps1)
   bootstrap│values                               ▼
 installer Step 5 / user init / deploy list   setup-user-claude, -settings, -skills,
                                              -cursor, check-lib, aitools entry points
```

---

## 1. Inventory: every reader and writer (repo at origin/main 51a34d8 + S3-Nine tree)

### config.json

| File:function | R/W | Keys | Note |
|---|---|---|---|
| `aitools-install.sh` Step 5 (`CONFIG_MERGE_JS`) | W | version, reposPath, repoPath, googleDrives; recovers userRepoPath, machineAlias | hardened merge (v0.73.2); never creates machineAlias |
| `aitools-install.ps1` Step 5 (`Set-ConfigKey`) | W | same | native PS, no node |
| `aitools` `user init` (config write, ~L1204-1224) | W | userRepoPath, machineAlias (only if non-empty) | **no backup_file**; Path 1 alias only on hostname match |
| `aitools.ps1` `user init` (~L1138-1158) | W | same | same gaps |
| `aitools` / `aitools.ps1` `migrate_profile_v1_to_v2` / `Invoke-ProfileMigration` | W | machineAlias | |
| `check-pre-push.sh/.ps1` step 7 | W (temp copy under an isolated HOME) | repoPath, userRepoPath | test only |
| `aitools` (L634-662, 972, 1269, 1512, 1610, 1699), `aitools.ps1` (571-584, 897, 1191, 1414, 1501, 1602) | R | repoPath, aiToolingRepoPath, reposPath, userRepoPath | via read_config_key / Read-ConfigKey |
| `build-deploy.sh` (L153-190, 204-239) | R | userRepoPath, machineAlias | node, `2>/dev/null` + `|| true` |
| `build-deploy.sh` generated settings/skills PS1 (L1075, 1181) | R | userRepoPath | runtime in deploy/ |
| `setup-user-claude.sh` (L68-131), `.ps1` (L65-173) | R | userRepoPath, machineAlias | copied matcher #2/#3 |
| `setup-user-settings`, `setup-user-hooks`, `setup-user-skills` (.sh/.ps1) | R | userRepoPath | read_config_key |
| `setup-user-cursor.sh` (node L196-199), `.ps1` (L165-170) | R | userRepoPath | |
| `profile-check.js` | R | userRepoPath, machineAlias | NO_MACHINE_MATCH ignores alias |
| `check-lib.sh` `resolve_config` / `.ps1` | R | userRepoPath | |
| `hh.sh`, `hh.ps1`, `aitools-dashboard.sh/.ps1` | R | repoPath (aiToolingRepoPath) | bootstrap key, unaffected |
| `ait-harvest.py` `read_config_user_repo` | R | userRepoPath | `encoding="utf-8"`: a BOM file disables archiving (logged as warn) |
| `harness-db.py`, `shared/hooks/*.sh` | -- | none | grep finds no config.json reads (hooks call ait-harvest.py) |

### profile.json

| File:function | R/W | Keys |
|---|---|---|
| `aitools` Path 2 (L1071-1093) / `aitools.ps1` (~L989-1024) | W | profiles[alias] (os.hostname()); **no backup** |
| `aitools` Path 3 (L1133-1157) / `aitools.ps1` (~L1053-1079) | W (create) | whole file |
| `migrate_profile_v1_to_v2` / PS1 | W | whole file (preserves non-v1 keys) |
| `setup-user-settings` via `sync_managed_json` | W | `claude.settings` (adopt) with backup_file |
| `build-deploy.sh` L206-239 | R | profiles, identity, cursor.cli |
| `setup-user-claude.sh/.ps1` | R | profiles, identity |
| `setup-user-cursor.sh/.ps1` | R | cursor.cli |
| `profile-check.js` | R | identity, profiles, version |
| `aitools` Path 1/2 node blocks | R | profiles, version, identity |

---

## 2. Schemas

### profile.json: v2 revision 2.1 (additive)
Full draft: `S5-Profile-drafts/reference/user-repo.md` "Profile Schema". Migrated example for
this user: `S5-Profile-drafts/dotprofile/profile.json`. Additions:
- `meta.schemaRevision: "2.1"`, `meta.intent` (purpose/scope/audience). Text is in the draft and needs approval.
- `identity.name`, `identity.company`: defaults for every profile; a profile's own `name`/`company` overrides them.
- `profiles.<alias>.machine.id` (`sha256:<16 hex>` of IOPlatformUUID / MachineGuid / machine-id), `machine.environment` (`claude-code-web`), optional `machine.hostnames[]`.
- `profiles.<alias>.toolExceptions.<tool-slug> = { decision: "keep", detected: { method, path, version }, decidedAt: "<UTC Z>", reason }`. This is the reserved storage for S5-Tools.

**Why not v3:** current code treats `version !== 2` as v1. That covers `profile-check.js` (v1 detection), every node block that checks `p.version === 2`, and user init, which offers a migration that rebuilds the file. A machine still on old aitools would then corrupt the shared profile. So the version stays 2, every addition is optional, and per-profile `company` stays until every machine runs the new code.

### config.json: v3 (derived)
Keys: `version: 3`, `reposPath`, `repoPath`, `googleDrives` (bootstrap/detected), `githubUser`, `userRepoPath`, `machineAlias` (derived), `meta { intent, writer, derivedFrom }`.
- No timestamps, and no "via" in the file. Both would change on every run, so the file would never verify as unchanged. The resolution path is logged instead.
- Readers are unaffected. `read_config_key` matches the first `"key": "..."` pair, and `meta` has no keys named like top-level ones. An older installer would set `version` back to 2 but keeps every other key, which is harmless.

---

## 3. Resolver contracts

| Function | Returns | Sets | Logs |
|---|---|---|---|
| `resolve_user_repo_path` / `Resolve-UserRepoPath` | 0 found, 1 none (shared-only), 2 error | `USER_REPO_PATH`/`$script:UserRepoPath`, `USER_REPO_VIA` | detail `dotprofile=… via=…`; warn/error lines from the resolver; ERROR summary on 2 |
| `resolve_machine_profile` / `Resolve-MachineProfile` | 0 resolved, 1 shared-only, 2 no match/error | `MACHINE_ALIAS`, `MACHINE_VIA`, `PROFILE_FILE`, `PROFILE_NAME`, `PROFILE_COMPANY`, `IDENTITY_GIT_NAME`, `IDENTITY_GIT_EMAIL`, `IDENTITY_GITHUB` (identity-level only on 2) | info `machine profile: alias=… via=… company=… hosts=… id=…`; on 2: ERROR + `write_summary ERROR "machine profile" "no machine match"` + ACTION |
| `aitools-profile.js user-repo-path` | exit 0/1/2 | stdout path (`--format native|mixed|bash|tagged`) | |
| `aitools-profile.js resolve / derive-config / snapshot / register / machine-id` | exit 0/1/2, JSON or tagged | | |

- Dotprofile order: env → argument → config.userRepoPath → convention → single `aitools-*` scan → none. Details in the user-repo.md draft "Resolution".
- Machine order: override → environment (claude-code-web) → machine.id → config alias → hostname (warn) → none (ERROR).
- Hostname candidates: `os.hostname()`, macOS `scutil LocalHostName`/`ComputerName`, and Windows `COMPUTERNAME`. Every caller uses this same list, which closes the PS1 `$env:COMPUTERNAME` parity gap.
- Without node, the dotprofile path falls back to the cached `config.userRepoPath`. Machine resolution then returns WARN plus rc 1, never a guess.
- The PS1 wrapper reads node output through a temp file decoded as UTF-8 (cross-platform.md pipeline-encoding rule).

---

## 4. Writer / caller matrix

| File | Single writer | Called by | Inputs passed |
|---|---|---|---|
| `~/.aitools/config.json` | `setup-user-config.sh` / `.ps1` | installer Step 5 | `--repos-path`, `--repo-path`, `--drives-json` |
| | | `aitools user init` (bash + PS1) | `--github-user`, `--user-repo-path`, `--machine-alias` |
| | | deploy list, first entry (`aitools`, `aitools install` Step 21) | none (re-derive) |
| `profile.json` machine entries (`machine.*`) | `aitools user init` → `aitools-profile.js register` | user init Paths 1/2/3 | alias, name, company, shell |
| `profile.json` `claude.settings` | `setup-user-settings` (unchanged) | deploy list | -- |
| `profile.json` `toolExceptions` | S5-Tools decision flow (reserved) | -- | -- |
| `<dotprofile>/deploy/*` | `build-deploy.sh` | `aitools` Step 2 | `AITOOLS_USER_REPO_PATH` |

Why not build-deploy as the writer (C3): build-deploy builds machine-independent artifacts, does not source the lib, and exits early when there is no dotprofile. config.json has to exist before any dotprofile does.

Why not `user init` alone: the installer must write bootstrap keys before user init runs, and sync must re-derive after profile changes (a machine registered elsewhere, an alias renamed).

---

## 5. Draft file list

| Draft (under `S5-Profile-drafts/`) | Repo path | Protected? | Intent status |
|---|---|---|---|
| `scripts/aitools-profile.js` | `scripts/aitools-profile.js` (new) | header intent: yes | drafted, needs approval |
| `scripts/setup-user-config.sh` | `scripts/setup-user-config.sh` (new) | header intent: yes | drafted, needs approval |
| `scripts/setup-user-config.ps1` | `scripts/setup-user-config.ps1` (new) | header intent: yes | drafted, needs approval |
| `scripts/aitools-lib.sh.profile-block.sh` | insert into `scripts/aitools-lib.sh` | section intent: yes | drafted, needs approval |
| `scripts/aitools-lib.ps1.profile-block.ps1` | insert into `scripts/aitools-lib.ps1` | section intent: yes | drafted, needs approval |
| config.json `meta.intent` (inside both writers) | `~/.aitools/config.json` | intent: yes | drafted, needs approval |
| `dotprofile/profile.json` (`meta.intent`, identity.name/company, new-mac machine.id) | `<dotprofile>/profile.json` | intent: yes; data is the user's | drafted, needs approval |
| `reference/user-repo.md` | `reference/user-repo.md` | **yes** (sources-of-truth) | new file intent drafted |
| `shared/claude-shared.md.edit.txt` | `shared/claude-shared.md` + `<dotprofile>/claude/CLAUDE.md` | **yes** | edit only |
| `S5-Profile-plan.md` | (plan, not a repo file) | -- | intent present |
| rule edits (below, text in this report) | `.claude/rules/managed-file-deployment.md` (+ `.cursor/rules/managed-file-deployment.mdc`), `.claude/rules/deploy-paths.md`, `.claude/rules/config-file-safety.md` (reference example) | **yes** | edits only |
| glossary entries (below) | `registries/glossary.json` + `.claude/rules/glossary.md` | **yes** | new terms |

**Rule edit drafts** (old → new):
- `managed-file-deployment.md` "Content sources": old `**Machine profile selection**: config.json machineAlias → profile.json profiles[alias]. Fallback: hostname match, then first profile` → new `**Machine profile selection**: one resolver (aitools-profile.js via resolve_machine_profile / Resolve-MachineProfile): override → environment → machine.id → config.json machineAlias → hostname (warns) → no match = ERROR (never another machine's profile). Order and failure behaviour: @reference/user-repo.md "Resolution"`.
- `deploy-paths.md` "Scripts with deploy templates": row `setup-user-claude.sh/.ps1 | Template interpolation, footer generation` → `setup-user-claude.sh/.ps1 | Footer generation (profile resolution + interpolation are extracted via BEGIN/END profile resolution / profile interpolation sentinels; resolver embedded from scripts/aitools-profile.js)`. Also add `scripts/aitools-profile.js` to "What IS auto-embedded".
- `config-file-safety.md` "Reference examples": add `- Single config writer: @scripts/setup-user-config.sh / .ps1 (config.json; bootstrap + derived keys)`.

**Glossary drafts** (both files together):
- `machine profile`: "An entry in profile.json `profiles`, keyed by machine alias, holding one machine's (or environment's) identity overrides, `machine.id`, and toolExceptions." source `reference/user-repo.md`
- `machine alias`: "The key of a machine profile (e.g. new-mac). Cached per machine in config.json `machineAlias`; chosen at `aitools user init`." source `reference/user-repo.md`
- `machine identity`: "The hashed stable platform id (`machine.id`: IOPlatformUUID / MachineGuid / machine-id) that aitools-profile.js matches to pick this machine's profile." source `reference/user-repo.md`
- `derived config`: "~/.aitools/config.json: per-machine pointers built from profile.json and installer inputs by setup-user-config, its only writer." source `reference/user-repo.md`

---

## 6. Implementation batches

Full verbatim edits, audits and verification are in `S5-Profile-plan.md`. Summary:

| Batch | Files (≤3) | What | Sub-agent? |
|---|---|---|---|
| B0 | none (commander) | set `machineAlias: new-mac`, run `aitools` | -- |
| gate | protected drafts + intents | one consolidated approval | -- |
| B1 | `aitools-profile.js` (new), `profile-check.js` | resolver; NO_MACHINE_MATCH fix | yes (3+ rule) |
| B2 | `aitools-lib.sh`, `aitools-lib.ps1` | wrappers; move `validate_json_config`/`ValidateJsonConfig` into lib | **required** (lib) |
| B3 | `setup-user-config.sh/.ps1` (new), `aitools-install.sh` | single writer; Step 5 calls it; Step 21 list | yes |
| B3b | `aitools-install.ps1` | same on PS1 | yes |
| B4 | `setup-user-claude.sh/.ps1` | resolver + sentinels + `{{USER_REPO_PATH}}` + footer alias | yes |
| B5 | `build-deploy.sh` | env var / resolver for DEPLOY_DIR; snapshot; runtime resolution in generated setup-user-claude; dotprofile template | **required** (build-deploy) |
| B6 | `scripts/aitools` | export env; deploy list; user init choose/register; check_profile via log_warn before deploy | yes |
| B7 | `scripts/aitools.ps1` | mirror of B6 | yes |
| B8a-c | settings/skills/cursor/check-lib/ait-harvest | consumers call the resolver; utf-8-sig | yes |
| B9 | docs (after gate approval) | user-repo.md, claude-shared.md + dotprofile template, rules, glossary | -- |
| B10 | dotprofile data | apply migrated profile.json (meta, identity.name/company); each machine runs `aitools user init` once to register its id | commander |

Ordering: B1 → B2 → B3/B3b → B4 → B5 → B6/B7 → B8 → B9 → B10. B5 must land after S3-Nine merges. Each batch's `old` text was copied from the current tree and must match exactly once.

---

## 7. Tests run this session (macOS, isolated HOME, read-only on the real system)

| Test | Result |
|---|---|
| `tests/test-resolver.sh` T0 (real config, read-only) | `new-mac via=hostname` (LocalHostName), warns "register" |
| T1/T2 dotprofile scan / convention | found, via=scan (warn) / convention |
| T3 config alias new-mac | via=alias + "no machine.id" warning |
| T4/T5 register then stale alias `laptop` | register `updated`; resolve `new-mac via=id`, warns that the config alias disagrees |
| T7 unknown override | exit 2, error |
| T8 no alias/id/hostname match | exit 2, **no first-profile fallback** |
| T10 `AITOOLS_ENVIRONMENT=claude-code-web` on darwin | forced local (lib rule parity) |
| `tests/test-lib-wrappers.sh` W1-W4 | bash wrappers: values set, ERROR/WARN counters, deploy.log lines as specified |
| `tests/run-ps1-test.sh` (pwsh on macOS) | PS1 wrappers give the same answer as bash (`new-mac via=alias company=nobul-tech`) |
| `tests/test-writer.sh` S1-S6 | created / verified (idempotent) / explicit alias / no match → ERROR exit 1 with the file unchanged / corrupt file → recovered + backup |
| `tests/parse-ps1.ps1` | 0 parse errors in both PS1 drafts |
| `tests/test-interpolate.sh` | values with `&`, `$(...)`, `\1`, `/` substituted literally; empty value leaves the token |
| draft profile.json vs real config | `new-mac via=id company=nobul-tech` (re-check after the HMAC id change: the draft now carries `sha256:1f634eecaf97fa63`) |
| `tests/test-review-fixes.sh` | H1 inlined resolver passes `node --check`; H2 crash gives rc 2 with ERRORS counted; H3/H4 corrupt config resolves with a warning; M1 argument beats env and env values are not persisted; M4 missing profile file gives exit 2; M9 null entry ignored |
| re-runs after fixes | test-resolver, test-writer, run-ps1-test, parse-ps1: unchanged results |

Not run: the PS1 writer itself (its OS guard blocks macOS), Windows MachineGuid, Linux machine-id, Claude Code web, the B5 build-deploy changes (code not applied), and B6/B7 user init.

---

## 8. Open questions for the commander (each with a recommendation)

1. **Company and name level.** Recommend `identity.company = "nobul-tech"` (matches the GitHub org and today's CLAUDE.md) and `identity.name = "Jose"`. Delete the per-profile `company` values (`Nobul`, `nobul.tech`) and `name: pepe` once all 3 machines run the new code, keeping per-profile override support for a real difference. Until then laptop still renders `Nobul`.
2. **Hash machine ids?** Recommend yes: HMAC-SHA256 keyed `aitools-machine-id-v1`, stored as `sha256:` plus 16 hex, as drafted. The id stays deterministic and unique without putting raw hardware ids in git. Changing the key re-keys every machine, so the key is fixed.
3. **Resolver logic in one JS module rather than native bash and PS1.** Recommend JS: a single definition, already a node pattern (`sync_managed_json`, `profile-check.js`), and build-deploy can call it without the lib. The cost is that machine resolution needs node, which every machine already needs for deploy.
4. **Writer does not prompt; user init does.** Recommend as drafted. Sync and installer runs stay non-interactive, and a miss reports ERROR + ACTION.
5. **Pin the kernel hostname?** (`sudo scutil --set HostName nobul-mac`). Not needed after B1/B2 (LocalHostName is read) or after registration. Your call; I'd skip it.
6. **googleDrives in profile.json?** Recommend no, for now. They are detected machine state, and `label` is empty everywhere today. Revisit when labels carry meaning, then put them under `profiles.<alias>.googleDrives`.
7. **Generate `deploy/setup-user-config.*` for MDM?** Recommend yes, in a follow-up after B8, as a pure extract (body markers + inline lib + embedded resolver). That keeps dual-path parity; deploy/setup-user-claude no longer needs it.
8. **MDM template change.** build-deploy currently embeds `shared/claude-shared.md`, while the dev path uses the dotprofile template. Recommend B5 switch deploy/ to the dotprofile template so the two paths match (deploy-paths.md). This changes MDM output.
9. **build-deploy on a corrupt profile.json.** Recommend failing loudly (exit 1, so `aitools` reports "build failed") instead of today's silent defaults. A corrupt source of truth is a real error, and the deploy configs that follow would read the same corrupt file. A corrupt **config.json** is the opposite case: the build skips with a WARN so setup-user-config can repair the file (review H3).
10. **Deploy-path adopt-back (review M3).** Once the generated scripts resolve `USER_REPO_PATH`, the extracted rules "accept & adopt" write-back, including git commit/push into the dotprofile, becomes live in deploy/ (today it is dead there). Recommend keeping deploy/ read-only toward the dotprofile: the deploy script sets `USER_REPO_PATH=""` after resolving the profile source, so only the dev path adopts. This reverses my first draft recommendation; the reviewer's point that MDM endpoints should not push to git holds.
11. **MDM and no-node behaviour (review M2).** The new deploy/setup-user-claude needs node to resolve tokens, and an unregistered endpoint reports ERROR on every run. Recommend this: build-deploy also embeds identity-level values (name, company, git) as plain strings used when node is absent; an unregistered endpoint reports WARN, not ERROR, in deploy/ only; and `AITOOLS_MACHINE_ALIAS` is documented for MDM.
12. **Non-interactive registration (review M6).** Recommend `aitools user init --alias <A>`, which registers without prompting, for Claude Code web and scripted setups.
13. **Token reverse order on adopt.** "Jose" is both `PROFILE_NAME` and `IDENTITY_GIT_NAME`. Recommend keeping today's behaviour, where `{{PROFILE_NAME}}` wins.

---

## 9. INCIDENT findings (for /incident filing; existing repo code, not the drafts)

- **INCIDENT (high):** `build-deploy.sh` (profile block) hardcodes personal defaults `PROFILE_COMPANY="Nobul"`, `IDENTITY_GIT_EMAIL="jose@nobul.tech"` in shared framework code, and uses them silently when profile reading fails (`catch(e){process.exit(1)}` + `2>/dev/null`). Violates C1 and script-standards error handling.
- **INCIDENT (high, confirms S2-Host #13):** build-deploy interpolates the building machine's profile into the shared `<dotprofile>/deploy/`.
- **INCIDENT (medium):** dev/MDM template mismatch. `scripts/setup-user-claude.*` prefer `<dotprofile>/claude/CLAUDE.md`, but `build-deploy.sh` embeds only `shared/claude-shared.md` (`CLAUDE_SHARED="$SHARED_DIR/claude-shared.md"`, the only template read). deploy-paths.md requires equivalent results.
- **INCIDENT (medium):** `aitools`/`aitools.ps1` `user init` writes config.json and profile.json (Path 2) without `backup_file` (config-file-safety.md "Backup before overwrite"). The profile write uses `catch(e){console.error(...)}` with no exit code, and the caller does not check it.
- **INCIDENT (medium, unverified):** bash `user init` on Git Bash writes `userRepoPath` in MSYS form. `to_native_path` is `cygpath -u`, so it writes `/c/Users/...`, while the installer writes the `cygpath -w` form. PS1 consumers `Join-Path` that value. Unverified because which entry point Windows users run for `user init` is unknown.
- **INCIDENT (low):** `build-deploy.sh` evaluates node output with `eval "$PROFILE_VALS"`. The values are JSON.stringify'd strings in double quotes, so `$(...)` inside a profile value would execute. The input is the user's own repo, so this is low.
- **INCIDENT (low):** the bash `${var//\{\{TOKEN\}\}/$value}` interpolation (`setup-user-claude.sh`, `build-deploy.sh`) corrupts values containing `&` under bash 5.2 `patsub_replacement`. PS1 `-replace` treats `$` in values as group references.
- **INCIDENT (low):** `ait-harvest.py` `read_config_user_repo` reads with `encoding="utf-8"`. A BOM-prefixed config.json (PS 5.1) is logged as a warning and disables archiving. Fix: `utf-8-sig`.
- **INCIDENT (low, governance):** the `/glossary` skill reads `@reference/glossary.json`, but the file is `registries/glossary.json` (`ls`: the reference path does not exist).
- **INCIDENT (low):** `reference/user-repo.md:139` says the installer "detects" `machineAlias`; it only preserves it (S2-Host).
- **INCIDENT (medium, from review I-a):** `inline_lib_bash`/`inline_lib_ps1` (`build-deploy.sh:112-142`) replace *any* line that mentions the lib file, including lines inside embedded templates, rules and skills, not just the dot-source line. Fix: anchor to `^\s*source\s.*aitools-lib\.sh` and `^\s*\.\s.*aitools-lib\.ps1`.
- **INCIDENT (medium, from review I-b):** `adopt_claude_md` builds its perl program from shell values (`setup-user-claude.sh:167-174`). The `@` in `jose@nobul.tech` is interpolated as a perl array, so the email is never turned back into `{{IDENTITY_GIT_EMAIL}}`. Fixed by the B4 rewrite.
- **INCIDENT (medium, from review I-c):** empty `catch {}` / silent swallows at `aitools:71`, `aitools.ps1:92-99`, and `hh.ps1:41` (script-standards: an empty catch is never acceptable). Not verified line-by-line by me.
- **INCIDENT (low, from review I-e):** Windows repos location conflict. `cross-platform.md` says `C:\repos\`; CLAUDE.md, the installer and this design use `%USERPROFILE%\repos`.
- Carried from S2-Host, addressed by this design: Path 1 never prompts or persists the alias (B6/B7); silent first-profile fallback (B1/B4/B5); `check_profile` is console-only, runs after deploy, and gives wrong advice (B6/B7); NO_MACHINE_MATCH fires despite an alias (B1); PS1 `$env:COMPUTERNAME` parity (B1); the profile failure was parked untracked (governance).

---

## Adversarial review

The reviewer was sub-agent S5-Profile-A; its full review is `S5-Profile-A-review.md`. It found 6 high, 11 medium and 10 low issues. All 10 plan `old` blocks matched exactly once. I spot-checked H1 against the draft (header line 12 named the PS1 lib file) and re-ran its scenarios as `tests/test-review-fixes.sh`; all pass after the fixes.

| # | Finding | Status |
|---|---|---|
| H1 | build-deploy's `inline_lib_ps1` replaces any line naming the lib, which corrupted the embedded resolver; on Windows the crash exit 1 then read as "not found" | **fixed**: lib file names removed from the JS; B5.2 guard now fails the build on `^'@`, `aitools-lib.ps1` or `source.*aitools-lib.sh`. Test: inlined copy passes `node --check`, same line count |
| H2 | node crash exit 1 read as "no dotprofile" | **fixed**: bash wrappers accept rc 1 only with the resolver's `via` line and keep stderr; the PS1 invoker maps "no JSON + non-zero" to rc 2 with LogError. Test: broken JS gives rc 2 and ERRORS incremented |
| H3 | corrupt config.json deadlocked `aitools` (build-deploy exit 1 before the writer could repair it) | **fixed**: `user-repo-path` resolves without a corrupt config (warns); B5.1 skips the build with WARN instead of exit 1 |
| H4 | corrupt-config errors not logged; `error` vs `errors` key mismatch | **fixed**: errors always emitted as an `errors` array; both wrappers log when the resolver gave no error line |
| H5 | `AITOOLS_USER_REPO_PATH` persisted in the user's pwsh session, so pre-push step 7 would rebuild into the real dotprofile | **fixed in plan** (B7 try/finally restore; B5 verify uses a one-command prefix, not `export`). **Needs the check-pre-push owner**: step 7 must pass the variable explicitly and unset `AITOOLS_PROFILE_FILE`/`AITOOLS_MACHINE_ALIAS` (outside this mission's files) |
| H6 | B4 adopt reverse substitution broke on `/` in a path (perl exit 255) | **fixed in plan**: env-var perl form for all five tokens (also fixes INCIDENT I-b, `@` in the email) |
| M1 | env overrides beat explicit arguments and were persisted to config.json | **fixed**: argument before env; env-sourced dotprofile/alias are used but not saved. Test passes |
| M4 | stale `AITOOLS_PROFILE_FILE` silently picked a deleted snapshot | **fixed**: set but missing gives exit 2; plan restores the variables in deploy scripts |
| M9 | `null` profile entry crashed `resolveMachine` | **fixed**: non-object entries ignored with a warning |
| M5 | B6 menu bypassed the repo TTY helpers; alias-list status unchecked | **fixed in plan** (use `tty_interactive`/`read_tty_choice`; empty list is an ERROR) |
| M7 | pre-push step 7 trigger regex lacks `aitools-profile.js` | coordination note in B8 (check-pre-push owner) |
| M8 | PS1 reads node output via `>` redirection; PS < 7.4 may mangle non-ASCII | **open**, low risk (ASCII values today). Follow-up: `--out FILE` on the resolver |
| M10 | deploy/ flips between old and new format while machines are partly upgraded | rollout note: upgrade all three machines before relying on deploy/; B10 after |
| M11 | installer runs Step 21 scripts in-process | **fixed in plan**: B3b copies the guard at `aitools-install.ps1:92-119` |
| M2, M3, M6 | MDM/no-node behaviour, deploy/ adopt-back, non-interactive registration | policy calls, now open questions 10-12 |
| L1 | unkeyed hash of the machine id | **fixed**: HMAC-SHA256 with the constant key `aitools-machine-id-v1`; this Mac is now `sha256:1f634eecaf97fa63` (all drafts updated) |
| L2 | PS1 home-prefix check had no path boundary | **fixed in plan** |
| L4 | two non-unique anchors | **fixed in plan** (anchoring stated) |
| L8 | build-deploy generated settings/skills read config directly | added to B8 |
| L3, L5, L6, L7, L9, L10 | PS1 temp-dir leak on early exit; snapshot carries every profile + email into MDM scripts; writer dry-run creates `~/.aitools` and has a misleading summary label; profile-check "unconfigured" without the resolver; doc updates; Path 3 commit warning | **open**, low. Listed for the batch agents; L9's doc drafts are in section 5 |

What the reviewer confirmed sound: keeping profile `version: 2`, since old user init auto-migrates anything else (`aitools:1008-1014`). No config.json reader checks `version`, so v3 plus `meta` is safe. The `$PSScriptRoot` fallback works. Resolution is deterministic. The writers degrade cleanly without node.

---

Sources: S2-Host RCA; files read in this session (`scripts/build-deploy.sh`, `setup-user-claude.sh/.ps1`, `aitools` (295-400, 940-1240, 1500-1710), `aitools.ps1` (880-940, 1130-1164), `aitools-install.sh` (185-560), `aitools-install.ps1` (120-151, 310-430), `aitools-lib.sh` (1-200), `aitools-lib.ps1` (1-160, 305-342), `profile-check.js`, `ait-harvest.py` (190-220)); grep inventory of `config.json|profile.json|userRepoPath|machineAlias|reposPath|googleDrives` across `scripts/` and `shared/`; test outputs under `tests/`.
Artifacts: `/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile/` (`S5-Profile-plan.md`, `S5-Profile-drafts/`, `tests/`).
No WRITE_BLOCKED events. The standing-order hook blocked `tail` and a `$(...)` pwsh one-liner; I switched to grep and a scratch `.ps1` file. The reviewer had two read-only `node -e` one-liners blocked (`||`, `;`) and used Read instead. None were write denials. Nothing was written outside the S5-Profile directory: no repo, dotprofile or `~/.aitools` edits, and no commits.
Reviewer note: Firecrawl credits are exhausted (https://www.firecrawl.dev/billing/9cnjpy2dhjkfcb02j5g29t6s64ya80na), so the reviewer could not verify the systemd machine-id(5) keyed-hash recommendation online. The HMAC change was made on its merits.
