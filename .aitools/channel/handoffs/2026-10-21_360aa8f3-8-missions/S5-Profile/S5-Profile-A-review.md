# S5-Profile-A: adversarial review of the S5-Profile design and drafts

**Summary (5 lines)**
1. All 10 fenced `old` blocks in the plan, plus the anchors given in prose, occur exactly once in the current working tree (main + staged S3-Nine hunks). Two anchors need more context (L4).
2. Six high findings. The worst: build-deploy's `inline_lib_ps1` puts the whole PS1 lib into the embedded `aitools-profile.js` (proven), and node's own crash exit code 1 is read as "nothing found". Together they make the Windows deploy/ resolver fail silently.
3. A corrupt config.json now deadlocks `aitools`. build-deploy exits 1 before `setup-user-config` (the only thing that repairs config.json) can run, and neither wrapper logs the resolver error (proven: rc=2, ERRORS=0, nothing in deploy.log).
4. `$env:AITOOLS_USER_REPO_PATH` stays set in the user's pwsh session, so a later pre-push step 7 rebuilds into the real dotprofile. The B4 adopt reverse substitution fails to compile (perl exit 255) whenever a dotprofile exists.
5. Verified: keeping profile.json at version 2 is right, and no config.json reader checks `version`, so config v3 plus `meta` is safe. I also filed 6 INCIDENTs against existing repo code.

Reviewer: S5-Profile-A. Date: 2026-10-20. Repo state reviewed: `/Users/new-jose/repos/aitools` branch `main` (staged S3-Nine changes in `scripts/build-deploy.sh`, check-post-push, check-hook-parity). The plan's base branch `fix/issue-9-manifest-driven-preflight` is checked out in another worktree.
Tests written (all under `tests/review/`, isolated HOME, read-only against real files): `check-old-blocks.py`, `check-old-blocks-2.py`, `test-inline-embed.sh`, `test-adopt-reverse.sh`, `test-review-resolver.sh`, `test-corrupt-config.sh`, `psroot/`. I re-ran `tests/test-resolver.sh` and it gave the same results as recorded.

Tool-call denial (not a write): two read-only `node -e` one-liners were blocked by standing-order-guard (`'||'` and `';'` checks: "USO: Simple Bash commands only"). I did not retry them. I read the same files with the Read tool.

---

## 1. `old` block existence check (work item 1)

Method: `tests/review/check-old-blocks.py` parses every fenced block that follows an `old` label in the plan and counts its occurrences in the target scripts. `check-old-blocks-2.py` checks the anchors the plan gives in prose.

| Plan line | Target | Count |
|---|---|---|
| 57, 72, 100 | scripts/profile-check.js | 1 each |
| 257, 319 (start), 364 | scripts/setup-user-claude.sh | 1 each |
| 332 (interpolation `else ... fi` tail) | scripts/setup-user-claude.sh | 1 |
| 469, 503 (`USER_RULE_COUNT` close), 568, 661, 672, 685 | scripts/build-deploy.sh | 1 each |
| 757 | scripts/aitools | 1 |
| B3 anchors (`# Managed fields: ...`, `not updated (no node)`, `DEPLOY_SCRIPTS="setup-user-claude.sh setup-user-cursor.sh`, `validate_json_config()`) | aitools-install.sh | 1 each |
| B3b anchors (`# Managed fields: ...`, `function ValidateJsonConfig`) | aitools-install.ps1 | 1 each |
| B4 PS1 anchors (`# --- Resolve template source ---`, `template tokens unresolved`) | setup-user-claude.ps1 | 1 each |
| B6 anchors (`# Detect machineAlias ...`, `# Write userRepoPath and machineAlias to config`) | scripts/aitools | 1 each |

**Anchors that will not apply cleanly as written:** see L4. `- Machine: ${OS_NAME} ${ARCH} (${HOSTNAME})` occurs twice in build-deploy.sh (lines 340 and 378). `local deploy_scripts=` occurs 4 times in scripts/aitools (lines 314, 357, 1538, 1539).

---

## 2. Findings

### HIGH

**H1. build-deploy's lib inliner corrupts the embedded resolver in deploy/setup-user-claude.ps1.** (B5.4)
- Evidence: `inline_lib_ps1` replaces any stdin line matching `/aitools-lib\.ps1/` with the whole lib (`scripts/build-deploy.sh:129-142`). The embedded `aitools-profile.js` has that text at line 12 (`// Resolve-UserRepoPath / Resolve-MachineProfile (aitools-lib.ps1),`). `tests/review/test-inline-embed.sh` reproduces it: the 538-line JS comes back as 1523 lines, `node --check` gives exit 1 (`SyntaxError` at line 12), and running it gives exit 1. Exit 1 is the resolver's "nothing found" code (see H2), so the Windows MDM/deploy path reports shared-only mode with no error. The bash side is not affected today (540 = 540 lines) only because no JS line contains both `source` and `aitools-lib.sh`.
- Smallest fix:
  - (a) Drop `(aitools-lib.ps1)` and `(aitools-lib.sh)` from the JS header comment.
  - (b) Widen the B5.2 guard to `grep -nE "^'@|aitools-lib\.ps1|source.*aitools-lib\.sh"` and fail the build on a hit.
  - (c) Durable: anchor both inliners to the real dot-source / source line (INCIDENT I-a).

**H2. The resolver's exit code 1 ("not found, expected") collides with node's own failure code.**
- Evidence: a syntax error, missing module or uncaught crash before the main `try` exits 1 (`tests/review/test-review-resolver.sh` R1: `broken.js` gives exit 1). The wrappers treat rc 1 as shared-only:
  - bash `resolve_user_repo_path` logs only `log_detail "dotprofile: none found"`;
  - `resolve_machine_profile` logs `log "... shared-only mode"`;
  - PS1 does the same (`aitools-lib.ps1.profile-block.ps1:65,124`).
- Smallest fix: accept rc 1 as "not found" only when the output parsed and carries the resolver's own marker (tagged `via\tnone` line / JSON with `via`). Otherwise treat it as rc 2 with `log_error "resolver crashed (exit 1)"`.

**H3. A corrupt `~/.aitools/config.json` deadlocks `aitools`, and the repair step can no longer run.** (B5.1 + B6)
- Evidence: in tagged mode `user-repo-path` exits 2 on a corrupt config (`test-corrupt-config.sh`: exit 2 in all three output forms). B5.1 turns rc ≥ 2 into `blog_error ... exit 1`. In `scripts/aitools:1524-1531`, a build-deploy failure means `return 1` inside the prebuild block, which runs before both the sync and install branches (`scripts/aitools:1461-1566`). So `deploy_configs` (whose first entry is the only config writer) never runs, and `aitools install` never reaches the installer's Step 5. Old behaviour: build-deploy swallowed the error and continued.
- `derive-config` was deliberately made tolerant of a corrupt config (`aitools-profile.js:430-432`); `user-repo-path` was not.
- Smallest fix: make `cmdUserRepoPath` tolerant the same way (warn, then resolve via convention/scan), or have B5.1 treat rc ≥ 2 like "no dotprofile" (`blog_warn` + `exit 0`).

**H4. Neither wrapper logs or counts a corrupt-config resolver error.**
- Evidence: `cmdUserRepoPath` (`aitools-profile.js:381`) emits the config error only when `args.json` is set. In tagged mode (bash) it goes to stderr, which is console only. `test-corrupt-config.sh` shows wrapper `rc=2 ERRORS=0 WARNINGS=0` and no line in deploy.log. In `--json` mode (PS1) it emits `{"error": ...}` (singular), but `Resolve-UserRepoPath` loops over `$r.Data.errors`, so it logs nothing either. That breaks the USO "no silent failures" rule and script-standards (log_error must count).
- Smallest fix: `if (c.error) emit({ via: 'none', errors: [c.error], warnings: [] }, 2)` whenever `args.json || OUTPUT_TAGGED`. Also make both wrappers `log_error` when rc ≥ 2 and no `error` line arrived.

**H5. A session-persistent `AITOOLS_USER_REPO_PATH` lets pre-push step 7 rebuild into the real dotprofile.** (B7, B6, B5.1)
- Evidence: on Windows, `aitools` is a function that runs `& "$HOME\.local\bin\aitools.ps1"` in the user's session (`aitools-install.ps1:564`). So `$env:` writes outlive the run. B7 sets `$env:AITOOLS_USER_REPO_PATH` on success and clears it only on failure (plan lines 932-934). Pre-push step 7 isolates only `$env:HOME` (`check-pre-push.ps1:140-169`; bash `check-pre-push.sh:120-135`). B5.1 then prefers the env var, so build-deploy `rm -rf`s and rebuilds `<real dotprofile>/deploy`, and step 7 compares two untouched temp copies, a meaningless result. The plan's own B5 verify step tells agents to export the variable, so this bash shell exposure is real too.
- Smallest fix:
  - B7: wrap the bash build-deploy call in try/finally and remove the var afterwards, the way `Deploy-Configs` does for its env vars (`aitools.ps1:350-352`).
  - check-pre-push.sh/.ps1 step 7: set `AITOOLS_USER_REPO_PATH=<d7 dot>` explicitly, and unset `AITOOLS_PROFILE_FILE` / `AITOOLS_MACHINE_ALIAS`, for the build-deploy call.
  - The pre-push fix is outside S5-Profile's listed files. Coordinate it.

**H6. The B4 adopt reverse substitution for `{{USER_REPO_PATH}}` does not compile, and it runs exactly when adopt is offered.**
- Evidence: the plan prescribes `perl -pe "s/\\Q${USER_REPO_DISPLAY}\\E/{{USER_REPO_PATH}}/g"`. `\Q` does not protect the `/` delimiter, so `tests/review/test-adopt-reverse.sh` gets `exit=255` ("Unknown regexp modifier"). `adopt_claude_md` offers adopt only when `USER_REPO_PATH` is set (`setup-user-claude.sh:211-215`), and then the display path always contains `/`. Under `set -e` the failing `content=$(...)` aborts the script mid-adopt with no log line.
- Smallest fix: use the env-var form for this and all four existing lines: `V="$USER_REPO_DISPLAY" perl -pe 's/\Q$ENV{V}\E/{{USER_REPO_PATH}}/g'` (verified exit 0 in the same test). See INCIDENT I-b.

### MEDIUM

**M1. Environment overrides are persisted into config.json, and the env var beats the explicit argument.**
- Evidence: `resolveUserRepoPath` order is env > `--user-repo-path` > config (`aitools-profile.js:205-213`). Test R2: with `AITOOLS_USER_REPO_PATH=other-dot`, `derive-config --user-repo-path <real>` returns `userRepoVia: "env"` and `derived.userRepoPath` = other-dot. Test R4: the writer then writes other-dot into config.json. A test override left exported in a shell, or the B5 verify recipe, permanently re-points config. `AITOOLS_MACHINE_ALIAS` takes the same path into `derived.machineAlias`.
- Fix: put the explicit argument before env. In `cmdDeriveConfig`, do not put a value in `derived` when its via is `env`/`override`; return it as `override` and have the writer log it instead.

**M2. Regressions for MDM endpoints and machines without node.** (B5)
- Old `deploy/setup-user-claude.*` needed no node: values were baked in (`build-deploy.sh:195-249`). New: no node means every token stays unresolved, including identity-level ones (lib block `resolve_machine_profile` returns 1, WARN).
- On an unregistered endpoint (every new MDM machine; no config.json, no machine.id, a random hostname) it is ERROR plus exit 1 on every run, so MDM reports failure.
- Fix: at build time, also embed the identity-level token values (machine-independent: name, git name/email) as a fallback when node is missing. Document `AITOOLS_MACHINE_ALIAS` as the MDM selector. Decide whether "no match" on a deploy/ run should be WARN.

**M3. deploy/setup-user-claude.* can now write and push into the dotprofile.**
- Evidence: the extracted "profile resolution" block sets `USER_REPO_PATH` (plan B4/B5.3). In deploy/ that variable was always unset before. The extracted rules logic then enables adopt-to-profile and `git commit && git push` of merged rules (`setup-user-claude.sh:318-356`). Resolution also runs twice in deploy/ (the B5.3 `_live_rc` call and the extracted block), so warnings, `WARNINGS` and the `dotprofile` ERROR summary rows are duplicated.
- Fix: decide explicitly. If this parity is intended, record it in the protected deploy-paths draft. If not, use a different variable in the runtime block and `USER_REPO_PATH=""` before the rules section. Either way, reuse the first resolution instead of calling it twice.

**M4. A stale `AITOOLS_PROFILE_FILE` silently selects a deleted snapshot on Windows.**
- Evidence: B5.4 sets `$env:AITOOLS_PROFILE_FILE` / `$env:AITOOLS_PROFILE_JS` in-process, never restores them, and the live branch does not clear a pre-existing `AITOOLS_PROFILE_FILE`. Test R3: a missing `AITOOLS_PROFILE_FILE` gives exit 1 with "profile.json not found", which reads as shared-only.
- Fix: the resolver should treat a set-but-missing `AITOOLS_PROFILE_FILE` as exit 2. The deploy scripts should clear it in the live branch and restore both variables at exit (bash too, for parity).

**M5. `choose_machine_profile` (B6) bypasses the repo's TTY helpers.**
- `[ ! -c /dev/tty ]` is true for the device node even with no controlling terminal. The bare `read -r ... < /dev/tty` aborts under `set -e` at EOF. The lib already has `tty_interactive` and `read_tty_choice` for exactly these cases (`aitools-lib.sh:769-795`), and PS1 has `Test-InteractiveConsole` (`aitools-lib.ps1:766-774`).
- The alias list comes from `< <(node -e ...)` with the exit status unchecked: a corrupt profile.json shows only [n]/[s] and no error.
- Fix: use the helpers, and capture the alias list with `|| rc=$?` plus a check.

**M6. Machines that can only run non-interactively can never be registered.**
- `user init` requires a TTY, and `AITOOLS_FORCE` makes it an error (B6). Claude Code web sessions and MDM therefore error on every run, with an ACTION that cannot be done there.
- Fix: add a non-interactive `aitools user init --alias A` (bash + PS1), or document `AITOOLS_MACHINE_ALIAS` as the supported selector for those environments.

**M7. Pre-push step 7 does not fire when `aitools-profile.js` changes.**
- Its trigger regex is `scripts/(setup-.*|build-deploy|aitools-lib)\.(sh|ps1)` (`check-pre-push.sh:112`, `check-pre-push.ps1:115`), but B5 embeds `aitools-profile.js` into deploy/. A stale deploy/ goes unflagged.
- Fix: add `|aitools-profile\.js` to both regexes.

**M8. PS1 output capture runs through PowerShell redirection.**
- `& node $js @Arguments > $outFile` (PS1 block line 31) writes the file through PowerShell, not through node. `reference/cross-platform-detail.md` "PowerShell pipeline encoding" says to prefer the tool writing the file (`-o`).
- On PS 7.0-7.3 Windows (version on the workstation: unknown), native stdout is decoded with the console codepage, so non-ASCII names or paths would be mangled. I could not reproduce this on macOS (UTF-8 console).
- Fix: add `--out FILE` to the resolver (`fs.writeFileSync`) and pass it from `Invoke-AitoolsProfileJs`.

**M9. B1 adds a crash path that existing callers swallow.**
- `resolveMachine` dereferences `p.profiles[a].machine` without a guard (`aitools-profile.js:303,308,322`). Test R6: a `null` profile entry throws a TypeError at exit 1 through `require`, i.e. via profile-check.js. `check_profile` (`aitools:71`, `|| return 0`) and `Invoke-ProfileCheck` (`aitools.ps1:92-99`, `catch { return }`) then hide it (INCIDENT I-c). The CLI path does catch it (R5: exit 2 "resolve failed").
- Fix: `(p.profiles[a] || {})` in the three filters, plus an explicit "profile X is not an object" error.

**M10. deploy/ skew while machines are partially upgraded.**
- deploy/ lives in the shared dotprofile, and every `aitools` sync rebuilds it (`aitools:1524-1531`). An old machine regenerates the baked-company form; a new machine regenerates the runtime form, which also changes whenever profile.json changes (snapshot). Whoever commits last wins, and pre-push 7 flags the other machine.
- Fix: rollout note in the plan: upgrade all three machines before committing deploy/, or mark the generated header with a format version and have the old path refuse to overwrite a newer format. The second option needs old code, so the note is the realistic fix.

**M11. B3b's open question is answered, and the writer call needs the guard pattern.**
- The installer runs Step 21 children in-process: `Invoke-ValidatedScript` → `& $ScriptPath` (`aitools-install.ps1:92-119`). The plan's `& $configWriter @writerArgs` has no try/catch and no `$global:LASTEXITCODE = 0` reset first, so a stale exit code or a terminating error goes unhandled.
- Fix: mirror `Invoke-ValidatedScript` (ParseFile, reset, try/catch, ERROR summary).

### LOW

- **L1. Machine id privacy.** The hash is plain SHA-256(raw id), truncated to 64 bits, with no key (`aitools-profile.js:167-172`). From memory, not verified this session (firecrawl was out of credits): systemd's machine-id(5) advises treating /etc/machine-id as confidential and deriving application-specific keyed ids. Fix: HMAC-SHA256 keyed with a constant such as `"aitools"`. Same cost.
- **L2. PS1 home-prefix check lacks a boundary.** The B4 PS1 `StartsWith($env:USERPROFILE)` also matches `C:\Users\joseph` for `C:\Users\jose`. Bash uses `(?=\/|$)`. Fix: also require the next char to be `\` or end of string.
- **L3. PS1 temp dir can leak.** The B5.4 `$embedDir`, which holds a copy of identity and profiles, is removed only at the end. Early `exit` paths leak it to %TEMP% (bash has an EXIT trap).
- **L4. Two anchors are not unique.**
  - `- Machine: ${OS_NAME} ${ARCH} (${HOSTNAME})` occurs twice (`build-deploy.sh:340,378`). The "write heredoc" edit only becomes unique after the B5.3 block edit, so give it the `cat > "$CLAUDE_MD" << CLAUDE_EOF` context.
  - `local deploy_scripts=` has 4 hits (`aitools:314,357,1538,1539`). Quote the full strings.
- **L5. MDM scripts now carry every machine's profile.** The deploy/ snapshot embeds identity email and all machines' hostnames and ids into scripts meant for MDM distribution. Before, only the interpolated values were in them.
- **L6. Writer rough edges.**
  - It creates `~/.aitools/` during `--dry-run` (`setup-user-config.sh:79`).
  - A `repo.error` (bad `AITOOLS_USER_REPO_PATH`) is summarized as "machine profile: no machine match" (`setup-user-config.sh:123`).
  - `meta.derivedFrom` says `profile.json` even when derivation failed and an old `userRepoPath` was kept.
- **L7. profile-check after B1 is half-converted.** It still decides "unconfigured" from `config.userRepoPath` alone (`profile-check.js:55-59`), while the resolver would find the dotprofile by convention, scan or env. It also spawns ioreg/scutil twice (two `resolveMachine` calls).
- **L8. B8 leaves direct config readers, and deploy/ copies lack the resolver.**
  - B8 leaves the build-deploy skill-template readers (`build-deploy.sh:1075,1181`) on `read_config_key`.
  - The deploy/ copies of the B8 scripts have no embedded resolver, so `resolve_user_repo_path` falls to its degraded path and logs "node not available" (lib block lines 64/68) even when node exists.
- **L9. Protected docs drift after B2/B6 (drafts needed).**
  - `config-file-safety.md` says `validate_json_config` is "Defined inline in each script" and cites aitools-install.sh as the reference.
  - `managed-file-deployment.md` (rule) and `reference/user-repo.md` still say "Fallback: hostname match, then first profile".
- **L10. Path 3 commit timing.** Calling `register_machine_profile` at the Path 3 profile-creation point (before `git init` at `aitools:1170`) makes its `git add/commit` fail. That logs a misleading "commit profile.json by hand" WARN, even though the init commit at `aitools:1173-1174` picks the file up.

---

## 3. Design questions checked and found sound

- **profile.json stays at version 2: correct.** Old `user init` auto-migrates any profile whose version is not `"2"` (`aitools:1008-1014`, `aitools.ps1:930,954`). profile-check flags `version !== 2` as v1 (`profile-check.js:82`). A v3 profile would trigger the destructive v1 migration on machines that have not upgraded.
- **The additive fields are safe for old code.** `machine.id`, `machine.environment` and `machine.hostnames` do not break it, because `register` always sets `machine.hostname`. Old code calls `machine.hostname.split` (`aitools:992`, `build-deploy.sh:218`, `setup-user-claude.sh:118`), and the PS1 code calls `ContainsKey("hostname")`.
- **config.json v3 plus `meta`: no reader checks `version`.** Readers checked:
  - `read_config_key` (lib, aitools, installer)
  - `Read-ConfigKey` (aitools.ps1:67-78)
  - `ReadConfigKey` (lib.ps1:69-84)
  - setup-user-claude.ps1 `ConvertFrom-Json`
  - hh.sh / hh.ps1
  - ait-harvest.py:197-218
  - check-lib.sh:151-159 and check-lib.ps1:158
  - check-pre-push.sh/.ps1 step 7
  - aitools-dashboard.sh/.ps1
  - profile-check.js

  The grep- and regex-based readers take the first `"key": "..."` match. `meta` is appended last and its strings contain no quoted key names, so nothing is shadowed. An old installer re-run writes `version: 2` back and preserves `meta` (Object.assign at `aitools-install.sh:458`), which is harmless.
- **`$PSScriptRoot` fallback works.** In `Get-AitoolsProfileJs`, a function in a dot-sourced lib sees the lib's directory (`tests/review/psroot`: `fromLibFunction=.../liba`).
- **Resolution is deterministic and loud.** Duplicate ids, duplicate hostname matches and an unknown override all exit 2, and there is no first-profile fallback (T7, T8 re-run). The id-over-config-alias precedence is logged (T5).
- **Bootstrap without node:** the writers degrade (bash writes bootstrap keys only when config is absent; PS1 merges natively), and the wrappers fall back to the cached pointer. No deadlock other than H3.

---

## 4. INCIDENTs in existing repo code (not the drafts)

- **INCIDENT I-a (medium): the lib inliners match too broadly.** `inline_lib_ps1` / `inline_lib_bash` (`scripts/build-deploy.sh:112-142`) replace any line containing `aitools-lib.ps1` (or `source...aitools-lib.sh`) with the whole lib. That includes embedded content: the template, user rules, skills, and the new JS. Latent today: no current shared/ or dotprofile `claude/rules` file matches, by grep.
- **INCIDENT I-b (medium): `adopt_claude_md` interpolates profile values into perl code.** `setup-user-claude.sh:167-174` builds the perl program from shell values. `@` is interpolated as an array, so `jose@nobul.tech` is never turned back into `{{IDENTITY_GIT_EMAIL}}` (`test-adopt-reverse.sh`: exit 0, text unchanged). `/` in a value is a compile error (exit 255; company `A/B`). Every occurrence of a short value such as `Jose` is tokenized.
- **INCIDENT I-c (medium): profile-check failures are swallowed silently.** `check_profile` runs `result=$(node ... 2>/dev/null) || return 0` with no comment or check (`scripts/aitools:71`). `Invoke-ProfileCheck` uses `catch { return }` (`scripts/aitools.ps1:92-99`). `hh.ps1:41` has an empty `catch {}`. All violate script-standards "Error handling requirements".
- **INCIDENT I-d (high, existing): the current `user init` config write breaks config-file-safety.** `scripts/aitools:1204-1224` rewrites config.json with no backup. On invalid JSON it starts from `{}` and drops every other key, and its validation then fails on missing `reposPath`, after the write. The plan's B6 replaces this block, which closes it.
- **INCIDENT I-e (low): the repo rules disagree on where Windows repos live.** `cross-platform.md` says Windows repos live under `C:\repos\`, while the user CLAUDE.md and the resolver default to `%USERPROFILE%\repos`. Two specs, one fact.
- **INCIDENT I-f (already in RCA §2 #13, confirmed): build-deploy bakes one machine's identity.** It hardcodes personal defaults and `eval`s node output (`build-deploy.sh:195-239`). B5.2 removes both.

---

## 5. Suggested order of fixes before approval

1. H1 + H2: guard plus wrapper rc semantics. Without these, the deploy/ PS1 path cannot be verified at all.
2. H3 + H4: make `user-repo-path` tolerate a corrupt config, and tag its errors.
3. H5: clear the env var in B7; set it explicitly in pre-push step 7 (coordinate the file owner).
4. H6 + I-b: env-var perl form for all reverse substitutions.
5. M1, M4: env overrides are never persisted, and a missing override file is an error.
6. Decide M2, M3 and M6. These are policy, so they are the commander's call. My suggestion: M2 identity-level fallback plus WARN, M3 keep it read-only in deploy/, M6 add `--alias`.
