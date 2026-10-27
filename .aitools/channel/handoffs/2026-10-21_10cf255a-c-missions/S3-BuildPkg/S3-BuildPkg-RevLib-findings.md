# S3-BuildPkg-RevLib findings: shared libraries under a package / MDM (root, SYSTEM, fleet) run

Reviewer S3-BuildPkg-RevLib (level 2, delegated by S3-BuildPkg). 2026-10-26. Read only; no repo file changed.
Reading copy: main checkout `/Users/new-jose/repos/aitools` at `5976553` (main). Line numbers are main @ 5976553 unless a PR is named.
No level-3 delegates used.

## 0. Summary (5 lines)

1. The libraries assume one interactive user who owns the process: every path is `$HOME`-relative and resolved at source time (`AITOOLS_LOG_DIR`, `aitools-lib.sh:72`; `$HOME` is read-only in PowerShell, verified), Windows PATH writes go to HKCU (`aitools-lib.ps1:2794, 2907`), and nothing resolves a console user (grep for `/dev/console|SUDO_USER|ConsoleUser|EUID|query user` over `scripts/` and `shared/hooks/`: no hit; MDM-PKG F5 confirmed).
2. Platform detection is `uname -s` / `$Is*` only; no Linux distro or version is detected anywhere in `scripts/` (apt presence is the proxy). The environment list is closed at `claude-code-web | local`; Cursor cloud has no documented signal I could find (unknown), so `cursor-cloud` must be set explicitly, like Claude Code web's setup script does.
3. The libraries contain no install helpers (brew/winget/apt/npm/pip/cargo calls live inline in the setup scripts; `install_via_brew` / `install_via_apt` named by `cross-platform.md` D-ENV0 do not exist, `reference/tool-support-decision-tree.md:406-408`); `Test-IsAdmin` exists but has no caller.
4. Non-interactive runs (no tty, `[Environment]::UserInteractive` false, or `AITOOLS_FORCE=1`) always overwrite LOCAL from SOURCE with a backup and a warning, and never adopt or merge (`aitools-lib.sh:1646-1656`, `aitools-lib.ps1:1601-1611`); the one non-interactive write-back is `sync_managed_json` auto-adopting live-only settings into `profile.json` with no prompt and no commit (`aitools-lib.sh:2419, 2546-2555`).
5. A fleet machine whose id is not in `profile.json` (every fleet machine with the embedded snapshot, and every container with a missing/random id) gets `ERROR|machine profile|no machine match` plus ACTION `Run: aitools user init`; there is no "first profile" fallback despite two docs saying so; a package needs a "fleet / unregistered" mode in the resolver.

## 1. Files read

In full: `scripts/aitools-lib.sh` (3047), `scripts/aitools-lib.ps1` (3192), `scripts/check-lib.sh` (204), `scripts/check-lib.ps1` (200), `scripts/aitools-profile.sh` (1563), `scripts/aitools-profile.ps1` (1379), `scripts/aitools-json.pl` (311), `scripts/aitools-json.ps1` (175). Mission packet, S3-BuildPkg brief, FanPlan-Lib findings (reused where cited "FanPlan-Lib"), rules in context, plus `reference/cross-platform-detail.md`, `logging.md`, `user-repo.md`, `.claude/rules/deploy-paths.md`, `managed-file-deployment.md`, `config-file-safety.md`, `tool-lifecycle.md` and the rules listed in packet section 1 that were not already loaded.
Not read (deviation): `reference/script-standards-detail.md`, `reference/managed-file-deployment.md`, `reference/plan-execution-detail.md`, `plans/tool-support-and-machine-profile.md`, prior handoff `2026-10-21_360aa8f3-8.md`. Nothing below depends on them except where FanPlan-Lib (which read `reference/managed-file-deployment.md`) is cited.
PRs: `gh pr diff` for #103, #113, #115, #108, saved to `/Users/new-jose/repos/aitools/.scratch/session-rvlib/pr{103,113,115,108}.diff`; lib and resolver hunks read (#103 lib 353-656; #115 lib 1105-1300 and 1455-1746, which contain #113's runner change; #108 json/profile 193-497).
Probes (macOS, pwsh 7): `pwsh -Command '$HOME = "/tmp/x"'` -> `Cannot overwrite variable HOME because it is read-only or constant.`; `env HOME=/tmp/rvlib-home pwsh -Command 'Write-Output $HOME'` -> `/tmp/rvlib-home`.

## 2. Platform and environment detection

| What | bash | PowerShell |
|---|---|---|
| Platform | `aitools-lib.sh:35-40` `uname -s`: `Darwin*`->macos, `Linux*`->linux, `MINGW*/MSYS*/CYGWIN*`->windows, else unknown. `IS_MACOS/IS_WINDOWS/IS_LINUX` (54-61) | `Resolve-AitoolsPlatform` (`aitools-lib.ps1:34-41`): PS<6 or `$IsWindows`->windows, `$IsMacOS`, `$IsLinux`, else unknown |
| Environment | `aitools-lib.sh:41-52`: an existing `AITOOLS_ENVIRONMENT` of `claude-code-web|local` wins; else `CLAUDE_CODE_REMOTE=true` -> claude-code-web; else local; forced to local off Linux | `Resolve-AitoolsEnvironment` (43-53), same rule, `-ceq`; re-exports the resolved value (61) |
| Logged | `_log_aitools_environment` (672-677): detail line, warns on an ignored override; `CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE` logged, not used | `Write-AitoolsEnvironmentLog` (579-584) |
| Predicates | `is_claude_code_web`, `is_local_environment` (64-65); `write_environment_skip` (878-882) | `Test-ClaudeCodeWeb`, `Test-LocalEnvironment` (64-65); `Write-EnvironmentSkip` (768-772) |
| Resolver | `aitools-profile.sh:328-335` `--environment` accepts only `local|claude-code-web` | `aitools-profile.ps1:262-268` same |

Linux distro / version: **not detected anywhere** (`grep -rn 'os-release|lsb_release|VERSION_ID|ubuntu'` over `scripts/` hits only comments in `setup-pandoc.sh:7`, `setup-perl.sh:101`, `setup-bash.sh:117`). Scripts branch on `command -v apt-get` and, for Chrome, `dpkg --print-architecture` (`setup-google-chrome.sh:168`). Ubuntu 22.04 vs 24.04 cannot be told apart by the library today. The only privilege probe in `scripts/` is `setup-google-chrome.sh:165` (`id -u`).

Machine identity (resolver): macOS `IOPlatformUUID` via `/usr/sbin/ioreg` (`aitools-profile.sh:354-362`), Linux `/etc/machine-id` then `/var/lib/dbus/machine-id` (364-369), Windows `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` (`aitools-profile.ps1:279-290`, marked UNVERIFIED in its own comment, 270-272). Hostname: macOS `scutil --get LocalHostName` (`aitools-profile.sh:384-386`), Linux `uname -n` (387-389), Windows `$env:COMPUTERNAME` (`aitools-profile.ps1:300-305`); all short, ASCII lower-cased.

Adding a `cursor-cloud` value touches (no decision exists; cross-platform-detail.md:60 says the list is closed and a hosted Cursor agent is added "by decision"):
1. `aitools-lib.sh:41-52` (the canonical "aitools environment block", which hooks must copy verbatim; `aitools-lib.sh:29-31` says no hook embeds it yet) and the "claude-code-web only on linux" rule (50-52): decide whether `cursor-cloud` is Linux-only (likely; unknown).
2. Warning text `aitools-lib.sh:675` / `aitools-lib.ps1:582` ("valid: local; claude-code-web on Linux only").
3. New predicates `is_cursor_cloud` / `Test-CursorCloud`, next to `aitools-lib.sh:64-65` / `aitools-lib.ps1:64-65`.
4. `Resolve-AitoolsEnvironment` (`aitools-lib.ps1:43-53`) and its tests.
5. Resolver: `--environment` validation (`aitools-profile.sh:330-333`, `aitools-profile.ps1:264-266`); the environment-keyed profile (`environment:claude-code-web` is hard-coded at `aitools-profile.sh:665-682, 1260-1261, 1282, 1290, 1386-1388` and `aitools-profile.ps1:534-543, 1099-1101, 1122, 1208-1209`). These should become `environment:$THIS_ENV` for any non-local environment.
6. Spec: `reference/cross-platform-detail.md` "API" table and "Resolution"; `.claude/rules/cross-platform.md` "Environment branches" (protected); `/glossary` (environment is governed).
7. Signal: **unknown**. Nothing in `scripts/`, `reference/`, `.claude/rules/`, `plans/`, `shared/` names one (grep for `CURSOR_AGENT|CURSOR_CLOUD|cursor-cloud|CURSOR_TRACE|background agent|cloud agent` hit only delegation prose and cross-platform-detail.md:60). A web search (2026-10-26) found no documented Cursor variable that marks a cloud-agent run; Cursor's cloud agents are configured through `.cursor/environment.json` install/start commands ([Cursor forum: start script](https://forum.cursor.com/t/cloud-agent-start-script-not-blocking/158583), [Cursor forum: env variables](https://forum.cursor.com/t/cursor-agents-with-access-to-our-vpn-or-environment-variables/150497)); a third-party crate lists `CURSOR_TRACE_ID` as a Cursor session id, not a cloud flag ([is-ai-agent](https://docs.rs/crate/is-ai-agent/0.5.0)). Proposal: the Cursor environment.json install command sets `AITOOLS_ENVIRONMENT=cursor-cloud` explicitly, as the Claude Code web Setup script does for `claude-code-web` (cross-platform-detail.md:44-46). Verify against cursor.com/docs/cloud-agent with chrome-devtools before it feeds a protected file (WebSearch was used here; chrome-devtools was not).

## 3. Install helpers, privilege, PATH

Library content (both languages): **no install helper**. What exists:
- bash: `ensure_tool_on_path` (2920-2943, session PATH only), `ensure_gopath_bin_on_path` (2813-2820, session PATH, `$HOME/go`), `harness_python` (2952-2967, `$HOME/.local/bin/python3`), `repair_uv_tool_env` (2689-2735, runs `uv tool install --force`, per-user), `check_build_prereqs` / `diagnose_build_failure` (2973-3047, text remedies "brew install ... / apt-get install ..."), `detect_go_provenance` (2785-2807).
- PS1: `Refresh-Path` (2652-2662, reads Machine + User PATH, session only), `Test-IsAdmin` (2664-2668, **no caller** in `scripts/`), `Log-WingetOutput` (2673-2680), `Repair-UvToolEnv` (2689-2729), `Remove-OrphanedPythonDirs` (2738-2805: `%LOCALAPPDATA%\Programs\Python`, removes dirs, rewrites **User** PATH at 2794), `Ensure-GopathBinOnPath` (2901-2910: `%USERPROFILE%\go\bin`, writes **User** PATH at 2907), `$script:BuildPrereqs` KnownPaths under `%LOCALAPPDATA%`, `%USERPROFILE%\.local\bin`, `%APPDATA%` (3051, 3065-3066), `Ensure-ToolOnPath` (3080-3102), `Get-HarnessPython` (3104-3119, `$HOME\.local\bin`).

Installs are inline in setup scripts (RevSetup/RevTools own them); seen while grepping: `brew install` with no root check (setup-pandoc/perl/bash/uv/go/gh-cli/typst/vercelcli/datadog .sh, `aitools-install.sh:619`, `setup-user-cursor.sh:88`); `sudo apt-get` (setup-pandoc.sh:153, setup-gh-cli.sh:48-52/135, bootstrap.sh:48) and root-only apt (setup-google-chrome.sh:165); `winget install` with **no `--scope`** anywhere (`grep -- '--scope'` hits only `claude mcp --scope user`); `setup-modal.ps1:30` writes User PATH.

Privilege consequences in a package run:
- macOS as root (Jamf/Intune): Homebrew refuses to run as root, so every brew call in the setup scripts fails; the lib offers no "run as console user" wrapper.
- Windows as SYSTEM (Intune): HKCU PATH writes (`aitools-lib.ps1:2794, 2907`) land in SYSTEM's hive (`S-1-5-18`), not the user's; `%LOCALAPPDATA%`/`%USERPROFILE%` point to `C:\Windows\System32\config\systemprofile` (OS behaviour, not verified here); winget without `--scope` under SYSTEM has machine-vs-user semantics that are unknown for these packages (Q6 for this mission).
- Linux: `sudo` inside a root run is harmless when sudo exists; in containers sudo is often absent (unknown per image), so `sudo apt-get` fails where plain `apt-get` would succeed.

## 4. HOME, user identity, console user

Every per-user location derives from the process's own HOME / profile:

| Use | Where |
|---|---|
| Log dir `~/.aitools/logs` | `aitools-lib.sh:72` (computed once at source time), `aitools-lib.ps1:562-566`, `check-lib.ps1:40`, `check-lib.sh:39` (via lib) |
| config.json | `aitools-profile.sh:400`, `aitools-profile.ps1:311`, `check-lib.sh:166`, `check-lib.ps1:171` |
| Default repos dir `~/repos` (dotprofile discovery) | `aitools-profile.sh:449`, `aitools-profile.ps1:361`; `~` expansion `aitools-profile.sh:232-239`, `.ps1:169-173` |
| deploy-state notice | `aitools-lib.sh:967` (`$HOME`), `aitools-lib.ps1:863` (`$env:USERPROFILE`) |
| Tool paths | `aitools-lib.sh:2814, 2953`; `aitools-lib.ps1:2741, 2903, 3051, 3065-3066, 3110` |
| User PATH (HKCU) | `aitools-lib.ps1:2654` (read), `2777/2794`, `2905/2907` (write) |
| Temp files | `mktemp` (sh 174, 598, 1041, 1578, 1828, 1949, 2449-2450), `[IO.Path]::GetTempPath()` (ps1 970, 1516, 2066, 2427-2429, 2565) -- the runner's temp, i.e. root's/SYSTEM's |
| Identity | none from the OS: git identity comes from `profile.json` `identity.git` (`aitools-profile.sh:975-982`, `.ps1:803-812`); jsonl host = `hostname -s` / `MachineName` (`aitools-lib.sh:507-524`, `.ps1:420-433`) |

What breaks when root/SYSTEM acts for a console user:
- All deployed files (`~/.claude`, `~/.cursor`, `~/.aitools`) go to root's home (`/var/root`, `/root`) or the SYSTEM profile, not the user's, unless HOME is changed **before** the lib is sourced (bash `AITOOLS_LOG_DIR` is frozen at line 72).
- PowerShell `$HOME` cannot be reassigned in-process (probe above). Pointing `.ps1` scripts at another user's profile needs a child `pwsh` started with that user's environment (on macOS/Linux `HOME=` works, probe above; on Windows `$HOME` follows the process profile, so a SYSTEM process cannot retarget it -- unverified) or replacing `$HOME` uses with a lib function.
- Files written as root into the user's home are root-owned; the next interactive run as the user cannot back them up or overwrite them (`_managed_write` fails cleanly -> `failed`/ERROR, `aitools-lib.sh:1052-1062, 1078-1081`).
- git in the user's dotprofile as root: git's `safe.directory` ownership check refuses repos owned by another user (git >= 2.35.2; known git behaviour, not verified here); the lib would read that as "not a repo" (`aitools-lib.sh:982, 1011`; #103 `dotprofile_commit_push` 572-583).
- `tty_interactive` / `Test-InteractiveConsole` correctly report non-interactive under launchd/IME (no tty; `[Environment]::UserInteractive` false for a service -- the latter is .NET behaviour, unverified under Intune).

Proposed minimal console-user API (library style: results in `AITLIB_` globals / `$script:AitLib*`, return codes 0/1/3, never 2):

```
bash (aitools-lib.sh)                       PowerShell (aitools-lib.ps1)
resolve_target_user                         Resolve-TargetUser
  sets AITLIB_TARGET_USER, AITLIB_TARGET_HOME,  sets $script:AitLibTargetUser, AitLibTargetHome,
  AITLIB_TARGET_UID, AITLIB_TARGET_VIA          AitLibTargetSid, AitLibTargetVia
  (env|self|console|sudo|none)                  (env|self|console|none)
  returns 0 found, 1 none (no console user:     same
  defer), 3 error
is_privileged_run                           Test-PrivilegedRun   (root / SYSTEM or elevated admin)
run_as_target_user CMD ARGS...              Invoke-AsTargetUser -Script -Args
  (sudo -u / launchctl asuser on macOS,         (scheduled task in the user's session or
   runuser on Linux; returns CMD's exit)         "run as logged-on user" contract -- design TBD)
```

Order of resolution: `AITOOLS_TARGET_USER` override (env), else self when not privileged, else macOS `stat -f %Su /dev/console` (skip `root`/`loginwindow`), Linux `SUDO_USER` then `loginctl`/none, Windows `Win32_ComputerSystem.UserName` / the explorer.exe owner; HOME from `dscl . -read /Users/<u> NFSHomeDirectory` / `getent passwd` / the profile list in `HKLM\...\ProfileList\<SID>`. The lib then computes `AITOOLS_LOG_DIR` and every `~` path from `AITLIB_TARGET_HOME`, not `$HOME`. Every concrete command above is a proposal from platform knowledge, not verified in this review.

## 5. Logging

- Location: `~/.aitools/logs` only (`aitools-lib.sh:72`, `aitools-lib.ps1:562-567`), override `AITOOLS_LOG_DIR` (both). `deploy.log`, `deploy.jsonl` (`jsonl_record`, sh 531-540; `Write-JsonlRecord`, ps1 449-463), `checks.log`/`checks.jsonl` (check-lib).
- Rotation: 5 MB x 5 in `_rotate_log` (sh 632-656) / `Rotate-Log` (ps1 541-555); `deploy.jsonl` is never rotated (only `deploy.log`, sh 663 / ps1 571).
- Fail-safe gaps: `log`/`log_detail` (sh 682-699) append with no error handling, and `logging_init` runs `mkdir -p "$LOG_DIR"` unchecked (sh 662): under `set -e` an unwritable log dir aborts the script; PS1 `Log`/`LogDetail` (589-607) call `[IO.File]::AppendAllText` with no try/catch, and `New-Item` (569) unchecked. logging.md section 5 says a failed log write is swallowed; the code does not do that (INCIDENT 4).
- A package-level log is possible without breaking logging.md's single source of truth: the override already exists. The package wrapper sets `AITOOLS_LOG_DIR` to `/Library/Logs/aitools` (macOS), `/var/log/aitools` (Linux), `C:\ProgramData\aitools\logs` (Windows) for its own root/SYSTEM phase, and to the console user's `~/.aitools/logs` for the per-user phase. logging.md section 1 ("ALL aitools logging goes to ~/.aitools/logs") needs one added sentence for the package runner's system phase (protected reference; draft only). Intune's IME already collects `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`; whether to also log there is a design choice (unknown).

## 6. Profile resolver on a fleet

Machine profile lookup (`resolve_machine`, `aitools-profile.sh:631-765`; `Resolve-Machine`, `aitools-profile.ps1:510-603`), first decisive step wins: override (`--alias`, `AITOOLS_MACHINE_ALIAS`) -> `environment:claude-code-web` -> `profiles[<machine id>]` (or a legacy profile with that `machine.id`) -> config.json `machineId` (only when the id is undetectable) -> config.json `machineAlias` (legacy) -> hostname -> **error** "no profile matches this machine ... run: aitools user init" (exit 2). The wrappers turn that into `log_error` x2, `ERROR|machine profile|no machine match` and ACTION `Run: aitools user init` (`aitools-lib.sh:362-368`, `aitools-lib.ps1:294-304`), and the identity-level values only.

Dotprofile lookup (`resolve_user_repo`, `aitools-profile.sh:426-473`): `AITOOLS_USER_REPO_PATH`, `--user-repo-path`, config.json `userRepoPath`, `<reposPath or ~/repos>/aitools-<githubUser>`, the only `aitools-*` with profile.json, else none (rc 1, shared-only mode, not an error).

Fleet consequences:
- A fleet machine whose id is not in `profile.json` always lands in the error branch: one ERROR row and one ACTION on every run, and identity values from the profile's `identity` (Jose's name/email, when the deploy snapshot is Jose's, `build-deploy.sh:665-670, 759-764` set `AITOOLS_PROFILE_FILE` to the embedded snapshot). There is no "fleet / unregistered machine" outcome. `.claude/rules/managed-file-deployment.md:51` and `reference/user-repo.md:84` say "Fallback: hostname match, then first profile"; the code has no first-profile fallback (INCIDENT 6; the code's behaviour is the safer one).
- Run as root with no dotprofile in root's home: rc 1, shared-only mode, `machine profile: no dotprofile` detail (`aitools-lib.sh:360`), no ERROR. So a root run silently becomes shared-only, while a user run on the same box finds the dotprofile: the result depends on who runs it.
- Linux containers: `/etc/machine-id` is frequently absent or empty in container images (unknown per image) -> id unavailable warning -> config/alias cache (lost on reclaim) -> hostname (random per container) -> no match -> ERROR. When an image does ship a fixed `/etc/machine-id`, every container from it shares one id (the resolver's own comment, `aitools-profile.sh:339`). Only `environment:claude-code-web` avoids this, and only for that environment.
- `exception-set`, `register`, `migrate` refuse snapshots (`aitools-profile.sh:1046-1048, 1453-1455`) and commit/push only from an interactive `user init` path; `tool_exception_record` has no caller in `scripts/` today (grep). No package-run write path into profile.json exists through the resolver.

Direction: a resolver outcome `owner=fleet` (or `via=fleet`) selected by an explicit package flag (`AITOOLS_ENVIRONMENT`-style env var or `--fleet`), returning `identity`-free defaults with rc 0 and no ERROR, plus environment-keyed profiles for every non-local environment.

## 7. Dotprofile write-back in a non-interactive package run

- Text adopt / merge: only reachable from the menu. `prompt_diff_review` returns `overwrite` for `AITOOLS_FORCE=1`, `FORCE=true` or no tty before any menu (`aitools-lib.sh:1646-1656`); PS1 the same for `$env:AITOOLS_FORCE`, `$Force`, `-not Test-InteractiveConsole` (`aitools-lib.ps1:1601-1611`). Confirmed: a non-interactive run cannot adopt.
- JSON field adopt: `review_json_fields` sets `can_prompt=0` without a tty or with force (`aitools-lib.sh:2140`, `.ps1:2120`); `prompt_json_field_review` returns overwrite/skip non-interactively (sh 2354-2363, ps1 2338-2345); local-only fields are kept, not adopted (sh 2145-2154). Cannot adopt.
- **Exception**: `sync_managed_json` / `Sync-ManagedJson` (settings.json <-> profile.json, used by setup-user-settings) auto-adopts every key or permission rule that exists only in the live `settings.json` into `profile.json` with no prompt, in any run (`aitools-lib.sh:2419, 2503, 2496, 2546-2555`; ps1 2482, 2475, 2520-2528). It writes profile.json directly from node (2585), backs it up first (2649), does not use `_managed_write`, and never commits or pushes. In a package run this can only reach the dotprofile's `profile.json` (`setup-user-settings.sh:69-70`); under root with no dotprofile it skips with `WARN|claude settings|profile.json missing` (`setup-user-settings.sh:79-81`). A package must not point it at a shipped (read-only) profile, or the auto-adopt will write into the package's copy.
- N-Q2 auto-commit/push (#103, open): `dotprofile_commit_push` / `Invoke-DotprofileCommitPush` is called only from `_managed_adopt_notice` / `Write-ManagedAdoptNotice` (#103 diff 633-637 / 492-496), i.e. only after an adopt or merge, so it is unreachable non-interactively. With no git: detail line, `not-dotprofile`, return 0 (#103 diff 558-561). No credentials: push runs with `GIT_TERMINAL_PROMPT=0` and ssh `BatchMode=yes` (609), fails, `push-failed` + `log_warn` + ACTION, result stays `accept & adopt`. Not handled: the commander's 2026-10-26 decision "Dotprofile pushes from a non-main branch are an ERROR" (brief) -- #103 pushes whatever branch is checked out and treats every failure as WARN (INCIDENT 2). The resolver's `commit_profile` / `Invoke-ProfileCommit` (`aitools-profile.sh:959-1005`, `.ps1:788-847`) has the same gap.

## 8. `deploy_managed_file` non-interactive behaviour (F6) and backups

Confirmed:
- No tty / EOF / force -> `log_warn "Diff in <file> -- overwriting (non-interactive|--force)"` and `overwrite` (sh 1647-1656, ps1 1602-1611); EOF at a prompt -> `read_tty_choice` / `Read-ConsoleChoice` log_warn and the default overwrite (sh 1370-1378, ps1 1308-1317).
- The overwrite goes through `_managed_write` / `Write-ManagedFiles`: snapshot, `backup_file` to `<file>.bak.<UTC>` keeping 20 (sh 889-916, ps1 781-812), a failed backup fails the step with nothing written (sh 1057-1062, ps1 991-997), write, validate non-empty (+ JSON keys via node), restore on failure (sh 1035-1128, ps1 946-1072). Result `updated`; `failed` is log_error + the caller's ERROR row.
- Side effect for recurring MDM runs (Q5): each run where the user edited a managed file overwrites it again with a WARN, and the WARN promotes the script's later OK rows (`write_summary`, sh 864-866; ps1 755-757). 20 backups per file accumulate in the user's directories. LOCAL equal to SOURCE writes nothing and makes no backup (sh 1863-1866).
- Requirements the package must ship: `git` for the review diff (only when interactive, sh 1593), `node` for any `.json` DEST and for `sync_managed_json` (sh 1088, 1942, 2443; ps1 1031, 2061, 2422), `perl` in bash (sh 1805 on every call; the resolver, `aitools-profile.sh:148-152`). On a bare macOS endpoint node is absent, so every JSON managed file is `failed` (brief: deploy/ lacks prerequisites).

## 9. Remediations

| # | File:function | Severity | Fix direction | Open PR |
|---|---|---|---|---|
| R1 | `aitools-lib.sh` / `.ps1` (new): `resolve_target_user`, `is_privileged_run`, `run_as_target_user` / PS1 twins | critical | Add the console-user API (section 4); derive `AITOOLS_LOG_DIR` and every `~` path from the target home | none |
| R2 | `aitools-lib.sh:72` `AITOOLS_LOG_DIR`, `aitools-lib.ps1:562-566` `Initialize-Logging`, all `$HOME` uses in section 4 table | high | Route through one `aitlib_home` / `Get-AitLibHome` helper (PowerShell `$HOME` is read-only) | none |
| R3 | `aitools-lib.ps1:2794` `Remove-OrphanedPythonDirs`, `:2907` `Ensure-GopathBinOnPath`; `setup-modal.ps1:30` | high | Under SYSTEM, write the target user's hive (`HKU\<SID>\Environment`) or Machine PATH by decision; never SYSTEM's HKCU | none |
| R4 | lib (missing) `install_via_brew` / `install_via_apt` / winget helper | high | Build the planned helpers with privilege rules: brew as target user only, apt without sudo when root, winget `--scope` per Q6 | none (planned in tool-support-decision-tree.md:406-408) |
| R5 | `aitools-lib.sh:35-52` env block, `aitools-lib.ps1:43-53`, resolver `--environment` and `environment:claude-code-web` literals | medium | Add `cursor-cloud` by decision; generalise `environment:<env>` keys; signal = explicit `AITOOLS_ENVIRONMENT` | none |
| R6 | lib (missing) Linux distro detection | medium | `AITOOLS_DISTRO` / `AITOOLS_DISTRO_VERSION` from `/etc/os-release` (`ID`, `VERSION_ID`) next to the platform block | none |
| R7 | `aitools-profile.sh:resolve_machine` / `.ps1:Resolve-Machine`; `aitools-lib.sh:resolve_machine_profile` | high | Explicit fleet mode: no match -> `owner=fleet`, rc 0, no ERROR/ACTION, no identity from another person's profile | none (#115 only adds the ACTION for a missing resolver) |
| R8 | `aitools-lib.sh:sync_managed_json` / `.ps1:Sync-ManagedJson` | high | Disable auto-adopt (and any profile write) in non-interactive or package runs; use `_managed_write` for both files | none |
| R9 | `aitools-lib.sh:682-699, 662` `log`/`log_detail`/`logging_init`; `aitools-lib.ps1:589-607, 568-570` | medium | Make log writes fail-safe as logging.md section 5 requires; check `mkdir`/`New-Item` | none |
| R10 | #103 `dotprofile_commit_push` / `Invoke-DotprofileCommitPush`; `aitools-profile.sh:commit_profile`, `.ps1:Invoke-ProfileCommit` | medium | Refuse (ERROR) a push from a non-main branch per the 2026-10-26 decision; detect `safe.directory` refusal and report it instead of "not a repo" | #103 (partly: commit/push exists, branch rule missing) |
| R11 | `aitools-lib.sh:2449-2450` `sync_managed_json` | low | Check each `mktemp`; check `backup_file` result before the apply (2648-2649) | none |
| R12 | `aitools-lib.ps1:2664` `Test-IsAdmin` | low | Either use it in R1's `Test-PrivilegedRun` or remove it (dead code) | none |
| R13 | `aitools-lib.sh:_rotate_log` callers | low | Rotate `deploy.jsonl` too (only deploy.log is rotated at sh 663 / ps1 571) | none |
| R14 | `.claude/rules/managed-file-deployment.md:51`, `reference/user-repo.md:84` | low | Remove "then first profile" (protected; draft only) | none |
| R15 | `aitools-lib.sh:backup_dir` / `.ps1:Backup-Dir`; `aitools-lib.sh:deploy_tracker_record` | low | FanPlan-Lib INCIDENTs 2 and 8 (unchecked prune, silent unknown outcome); reused, not re-verified beyond reading the same lines (sh 921-945, 2281-2297) | none |

## 10. INCIDENT markers (not filed)

1. INCIDENT (critical, governance gap): no spec or helper for running as root/SYSTEM on behalf of a console user; every library path is the process's own HOME (section 4), PowerShell `$HOME` is read-only, Windows PATH writes go to the runner's HKCU (`aitools-lib.ps1:2794, 2907`). A fleet package deploys to root's/SYSTEM's profile.
2. INCIDENT (medium, spec deviation, open PR): the 2026-10-26 commander decision "Dotprofile pushes from a non-main branch are an ERROR" is implemented neither in #103 `dotprofile_commit_push` (#103 diff 609-622: any push failure is WARN, no branch check) nor in the resolver's `commit_profile` (`aitools-profile.sh:993-1004`).
3. INCIDENT (high, silent write-back): `sync_managed_json` auto-adopts live-only settings into `profile.json` in non-interactive runs without commit, push or `_managed_write` (`aitools-lib.sh:2546-2555, 2585`), contrary to the managed-file model "a field only in LOCAL is never written to SOURCE without a review" (agentic-standards.md, which keeps the profile-mirror exception -- so this is an ambiguity for package runs rather than a code bug).
4. INCIDENT (medium, spec deviation): logging is not fail-safe (`aitools-lib.sh:662, 686, 698`; `aitools-lib.ps1:569, 593, 606`) versus `reference/logging.md` section 5.
5. INCIDENT (medium, governance gap): no Linux distro/version detection although Ubuntu 22.04 and 24.04 are now supported targets (section 2).
6. INCIDENT (low, doc drift): "Fallback: hostname match, then first profile" (`.claude/rules/managed-file-deployment.md:51`, `reference/user-repo.md:84`) vs the resolver, which errors after hostname (`aitools-profile.sh:763-764`).
7. INCIDENT (medium, spec deviation): `install_via_brew` / `install_via_apt` named by `.claude/rules/cross-platform.md` D-ENV0 do not exist (already noted in `reference/tool-support-decision-tree.md:406-408`); no lib helper owns install privilege rules.
8. INCIDENT (low): `deploy.jsonl` is never rotated (`aitools-lib.sh:532, 663`; `aitools-lib.ps1:458, 571`) versus logging.md section 4 ("5 MB x 5 everywhere").

## 11. Open questions (with suggested answers)

- Q1. One process as root/SYSTEM that writes into the user's home, or a root phase plus a per-user phase run as the user? Suggest two phases: root installs system tools; the per-user phase runs the existing setup-user-* scripts as the console user (R1 `run_as_target_user`), so ownership, brew, HKCU and `$HOME` are right without rewriting every script.
- Q2. `cursor-cloud` signal? Suggest an explicit `AITOOLS_ENVIRONMENT=cursor-cloud` from `.cursor/environment.json`, Linux only, profile key `environment:cursor-cloud`; confirm with Cursor's docs via chrome-devtools.
- Q3. Fleet identity: what does a fleet user's CLAUDE.md get when no dotprofile exists? Suggest shared-only mode (`shared/claude-shared.md`) with an organisation profile shipped in the package, never Jose's snapshot (`build-deploy.sh:665-670` embeds the commander's profile).
- Q4. Package log location? Suggest `AITOOLS_LOG_DIR` set by the package wrapper per phase (section 5) and a one-sentence addition to logging.md (draft for approval).

WRITE_BLOCKED: none.
