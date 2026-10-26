# S3-BuildPkg-RevInstall findings: entry points and installers vs a package-based distribution

Reviewer: S3-BuildPkg-RevInstall (level 2 under S3-BuildPkg). Date: 2026-10-26.
Read-only review: no code changed, nothing committed.

Reading copy: the main checkout `/Users/new-jose/repos/aitools` at 5976553 (branch
main). Every `file:line` is in that copy unless a PR is named. PR code was read with
`git diff main...origin/<head>` after `git fetch origin feature/harness-hookin
fix/mf-installer-relay fix/mf-lib-runner-result`.

## 0. Summary (5 lines)

1. There are four step lists today. Two are for config deploy and they disagree (installer Step 21 vs the sync loop). #106 puts deploy-harness first in the sync loop and adds an installer Step 8b. Recommendation: one generated manifest, split into phases (system, tools, user). Its user phase uses the **sync loop order after #106**.
2. Without a terminal, nothing prompts. Every default is safe except two. First, `aitools user init` with no terminal **creates and pushes a private GitHub repo by default**. Second, an unknown installer flag **prints help and exits 0**, so an MDM run reports success while installing nothing.
3. Neither the installer nor the sync entry point knows about root, SYSTEM or a console user. Every path is `$HOME` / `$env:USERPROFILE`. Homebrew refuses to run as root. A HOME that is not set crashes the bash lib under `set -u`. The sync entry point needs a git checkout of aitools it can write to, so it cannot run on a payload in a system location.
4. The 17 bash and 18 PS "skipping (MDM deploy)" branches are not MDM detection. Each one is a `-f` / `Test-Path` check for a file next to the installer. A package that ships the `scripts/` + `shared/` tree triggers none of them, and nothing branches on the install location.
5. Prerequisites are spread across bootstrap.sh/.ps1 and the installer, and several are broken on a fresh machine. bootstrap.ps1 runs the installer under Windows PowerShell 5.1, which the lib cannot run on. `brew install node@22` is keg-only, so node is "installed but not on PATH". No script installs pwsh on macOS or Linux. Node on Linux is "install manually".

## 1. Files read

Read in full (Read tool): `scripts/aitools` (2298), `scripts/aitools.ps1` (2224),
`scripts/aitools-install.sh` (884), `scripts/aitools-install.ps1` (829),
`scripts/bootstrap.sh` (104), `scripts/bootstrap.ps1` (72), `scripts/init-logging.sh`
(8), `scripts/init-logging.ps1` (7). Also read: the mission packet; the S3-BuildPkg
brief; the rules not already in context (config-file-safety, deploy-paths,
documentation-standards, hook-rollout, managed-file-deployment, relay-outbound,
tool-evaluation, tool-lifecycle, web-sources); `S3-FanPlan-Install-findings.md`;
`S3-MdmPkg-report.md`.
Read in part: `scripts/aitools-lib.sh:240-320, 1340-1390`, `aitools-lib.ps1:550-575, 1290-1330`,
`scripts/aitools-profile.sh:415-474` plus greps, `scripts/setup-user-config.sh` (grep).
PRs: #106 (body; scripts diff in full), #113 (body, file list), #116 (body;
`aitools-install.sh` diff in full).

Not read (other delegates' slices; cited only through grep): `deploy-harness.*`,
`build-deploy.sh`, the `setup-*` scripts. The reference subset named in my prompt
(script-standards-detail, cross-platform-detail, logging, managed-file-deployment,
plan-execution-detail, user-repo) was **not** read. Where it matters I relied on the
rules files that summarise it.

## 2. Step order in the four entry points (task 1)

### 2.1 Side by side, main

| # | `aitools-install.sh` | `aitools-install.ps1` | `scripts/aitools` sync (no-args / gitpull) | `aitools.ps1` sync |
|---|---|---|---|---|
| pre | flags 25-53; Windows forwarding to .ps1 (+ winget pwsh bootstrap) 80-121 | flags param 9-15 | brew shellenv 20-26; config dir migrate 1424-1431; repoPath from config.json, else `~/repos/aitools` 1437-1443; **clone nobul-tech/aitools if `.git` missing** 1477-1485; source lib 1492-1503 | config migrate 423-430; repoPath 436-442; clone 472-482; lib 489-502 |
| 0 | brew shellenv (macOS) 346-352 | long-paths check (HKLM read, ACTION only) + `git config --global core.longpaths` 224-257 | Step 1 `git checkout HEAD -- deploy/` + `git pull origin main` 1978-2026 | Step 1 pull 1925-1964 |
| 1 | gh CLI (setup-gh-cli) 357-364 | 262-269 | dotprofile resolve + `git pull --ff-only` 2032-2050 | 1970-1982 |
| 2 | gh auth 369-391 | 274-299 | Step 2 **`build-deploy.sh`** (return 1 on failure) 2054-2060 | Step 2 build-deploy via **hard-coded `$env:ProgramFiles\Git\bin\bash.exe`** 1989-2015 |
| 3 | repos dir 396-433 | 304-345 | smart reload if the deploy list changed 2065-2093 | 2020-2046 |
| 4 | Google Drive 438-482 | 350-377 | Step 3 `deploy_configs` (list 1151; Git Bash list 1108): **config, claude, mcp, skills, cursor-ide-mcp, cursor, settings, hooks**, then relay->AGENTS 1189-1213 | `Deploy-Configs` list 157 (same order), relay sync 207 |
| 5 | config writer (setup-user-config, bootstrap keys) 487-508 | 382-397 | gitpull only: tag 2160-2195 | 2092-2135 |
| 6 | `~/.local/bin/aitools`, `hh`, `~/.aitools/bin` CLIs 514-565 | 402-460 (+ `aitools.ps1`, `hh.ps1`) | self-update `~/.local/bin/aitools` 2238-2278 | self-update 2182-2209 |
| 7 | setup-user-shell + rc-file `source aliases.sh` 570-604 | 465-537 (`$PROFILE` block) | `show_summary`, relay-outbound prompt 2280-2289 | 2211-2218 |
| 8 | Node (brew `node@22`; Linux WARN) 609-640 | Node (winget LTS) 543-564 | | |
| 9 | Claude Code (curl install.sh or `claude update`) 646-679 | 570-608 (irm install.ps1) | | |
| 10-20b | vercel, pandoc, rust, typst, uv, python, modal, go, datadog, perl, bash, chrome 684-826 | 613-753 | | |
| 21 | **claude, cursor, mcp, skills, cursor-ide-mcp, settings, hooks** 831-842 (no config: Step 5 wrote it) | 758-777 (same) | | |
| 22 | relay->AGENTS 847-870 | 782-812 | | |

`aitools install` = sync Steps 1-2 (pull + build-deploy), then the installer
(`scripts/aitools:2100-2146`, `aitools.ps1:2053-2079`). `deploy_configs` does **not**
run in the install path. The installer's Step 21 is the config deploy there.

Verified MDM-PKG F2: the two config lists disagree. In `aitools-install.sh:833` and
`.ps1:760-768`, cursor is 2nd and there is no config writer. In `scripts/aitools:1151`,
`:1108` and `aitools.ps1:157`, the config writer is 1st and cursor is 6th, after
cursor-ide-mcp. FanPlan section 3.3 found the same. Neither list on main runs
deploy-harness (`grep -n deploy-harness` hits neither entry point).

### 2.2 What #106 changes (`feature/harness-hookin`)

- **Installer:** a new Step 8b runs `run_harness_step` / `Invoke-HarnessStep` after
  Node. It does `bash -n`, then `run_child_relayed`. The bin block of Step 6 is
  removed, and `AITOOLS_RUN_ID` is exported. Exit 2 from deploy-harness shows the
  summary and does `exit 2`; exit 1 adds an ERROR row and the install continues.
- **Sync:** the list becomes **deploy-harness, claude, mcp, skills, cursor-ide-mcp,
  cursor, settings, hooks**. setup-user-config is removed from the list because
  deploy-harness runs it. A `deploy_aborted` flag skips the rest of the loop and the
  AGENTS.md sync. All three call sites (install, gitpull, no-args) `return 2` /
  `exit 2`.
- **Not changed:** Step 21's list (cursor stays 2nd), and Step 5 still runs the
  writer. So `aitools install` runs the writer **twice**, at Step 5 and inside
  Step 8b (#106 follow-up 1).
- **Abort semantics:** #106 matches the S3-BuildPkg brief ("only an exit 2 from
  deploy-harness stops a run"). FanPlan's INCIDENT (FanPlan section 8, first bullet)
  says #106 contradicts a 2026-10-26 decision. The brief, also dated 2026-10-26,
  says to keep #106's behaviour. **I follow the brief.** The conflict between the
  two hand-backs is for S3-BuildPkg to settle.
- **#116** does not reorder steps. It replaces the private relay with the lib
  relay (Step 5) and adds `resolve_repos_dir`: when the repos dir is unusable, Step 5
  is skipped with an ERROR row. **#113** touches only user init and the lib runner,
  with no step-order change.

### 2.3 Which list should be the single source of truth for a package run

Suggested: **one generated manifest** (a data file, for example
`scripts/deploy-order` or a registry entry; name to be decided), consumed by
`aitools`, `aitools.ps1`, both installers and build-package, in three phases:

| Phase | Steps (today's numbers) | Run context |
|---|---|---|
| P0 prerequisites | git, pwsh 7, node, Homebrew (macOS), python/uv | SYSTEM / root (Windows Win32 System app; macOS: Homebrew's own .pkg or the console user) |
| P1 tools | 1 gh, 9 Claude Code, 10-20b | SYSTEM/root on Windows/Linux. macOS: console user, because brew refuses root (section 4) |
| P2 user | 3 repos, 4 Drive, 5 bootstrap config, 6 commands, 7 shell, 8b deploy-harness, 21 config scripts, 22 relay mirror | always the target user (console user / Win32 User app / container user) |

For P2's config scripts, use **the sync loop order after #106**: deploy-harness, claude,
mcp, skills, cursor-ide-mcp, cursor, settings, hooks. Why:
- It is what every `aitools` run uses.
- It is what #106 tested (38/38, PR body).
- The only real dependency is setup-user-cursor on `~/.aitools/rules`
  (FanPlan 3.6), and deploy-harness comes first in it.

Step 21 then becomes "run the manifest's P2 config list". Step 5's explicit writer
call stays for the bootstrap keys, and deploy-harness gets the `--skip-config` flag
(#106 follow-up 1), so the writer does not run twice.

## 3. Interactive vs non-interactive (task 2)

### 3.1 How "interactive" is decided

- **bash:** `tty_interactive` (aitools-lib.sh:1357-1362) requires `[ -t 0 ]` and that
  `/dev/tty` can be opened. The installer is interactive only when that holds and
  `AITOOLS_FORCE` is not 1 (`aitools-install.sh:246-249`). User init uses
  `ui_can_ask` (`scripts/aitools:150-153`): the same test, plus `--force`.
- **PowerShell:** `Test-InteractiveConsole` = `[Environment]::UserInteractive -and
  -not [Console]::IsInputRedirected` (aitools-lib.ps1:1304-1306). Installer:
  `aitools-install.ps1:145`. User init: `Test-UiCanAsk` (aitools.ps1:765-768).
- **EOF at a prompt:** `read_tty_choice` and `Read-ConsoleChoice` log a warning and
  return "", so the default applies (aitools-lib.sh:1370-1378, aitools-lib.ps1:1308-1317).
- **Outliers:** bootstrap.sh uses only `[ -t 0 ]` (bootstrap.sh:92), bootstrap.ps1
  only `[Environment]::UserInteractive` (bootstrap.ps1:59), and `check_profile`
  partly `[ -t 0 ]` (`scripts/aitools:100`). So the four entry points do not use one
  test.

### 3.2 Every prompt and its non-interactive default

| Prompt | Where | Without a terminal (or with `AITOOLS_FORCE=1`) |
|---|---|---|
| `gh auth login` | installer Step 2 (sh:377-391, ps1:284-298) | WARN `gh auth` + ACTION "Run: gh auth login"; exit unaffected |
| repos path | Step 3 (sh:405-419, ps1:322-335) | `--repos-path`, else config.json `reposPath`, else `$HOME/repos` |
| managed-file review menus | Step 21 / 8b children (lib) | overwrite: SOURCE wins, backups kept (interactive-menus.md "Non-interactive fallback") |
| Homebrew installer (sudo) | bootstrap.sh:32-35 | not handled: Homebrew's installer is run without `NONINTERACTIVE=1` |
| dotprofile (user init + second `aitools`) | bootstrap.sh:92-102, bootstrap.ps1:58-70 | skipped: "Run 'aitools user init && aitools' later" |
| GitHub username | user init (`scripts/aitools:913-927`, aitools.ps1:1525-1542) | `gh api user`, else config.json `githubUser`, else ERROR + exit 1 |
| which profile / alias / name / company / email | `ui_choose`, `ui_scaffold`, `ui_identity` | ERROR "no terminal to ask" unless `--alias` or `AITOOLS_MACHINE_ALIAS` is given (`scripts/aitools:402-407`) |
| "Create the private GitHub repo ... and push? [Y/n]" | `ui_create_dotprofile` (`scripts/aitools:847-865`, aitools.ps1:1452-1475) | **default yes: `gh repo create --private --push` runs with no prompt** (`ans="y"` at :811) |
| alias used by another machine | `ui_register` (:498-503) | ERROR, not registered |
| profile v1 migrate | `check_profile` (:104-118) | not asked |
| relay outbound `[c/q/s]` | sync 2283-2289; relay-outbound.md | "CI / non-interactive: short hint only" (relay-outbound.md); `AITOOLS_SKIP_RELAY_PROMPT=1` skips it |
| git credentials | user init push uses `GIT_TERMINAL_PROMPT=0` + ssh BatchMode (`scripts/aitools:304`, 864) | **the sync's dotprofile `git pull --ff-only` (2037) and the aitools `git pull` (2006) do not set it** |

### 3.3 Exit codes

| Entry | 0 | 1 | 2 | Notes |
|---|---|---|---|---|
| `aitools-install.sh` | done, warnings allowed (875-884) | any `ERRORS` > 0 | #106: deploy-harness abort | **unknown option, or `--help`, exits 0 having done nothing** (47-51, 56-77). A `set -e` death exits with the failing command's code |
| `aitools-install.ps1` | 820-829 | errors | #106 Step 8b | an unknown parameter is a binding error before the script runs (pwsh exit 1) |
| `aitools` sync | `overall_rc` 0 | deploy or installer errors, build failure (2058-2059), `gitpull` pull failure | relay `[q]` (2288); #106 abort | |
| `aitools user init` | done | any failure, including "not registered" (998-1002) | hooks child abort (1052-1055) | |
| `bootstrap.sh` | **always**, unless `die` | `die` only | | the installer result is printed, not propagated (76-80) |
| `bootstrap.ps1` | unknown | `throw` on git missing | | the installer exit code is not checked (48) |

**Under an MDM agent with no TTY:** no prompt appears and every review takes SOURCE.
Exit 2 can come only from a `set -e` death that carries a 2 (for example a grep or
`bash` syntax error). #106 guards the syntax error in Step 8b with `bash -n`, and
`validate_and_run` does the same for Step 21. An MDM detector that maps non-zero
to failure sees `1` for **any** single ERROR row (for example one tool's winget
failure). There is no "partial" code. A package wrapper needs its own policy (Q4).

## 4. Assumptions that break as root / SYSTEM / deb postinst (task 3)

| Assumption | Where | macOS PKG postinstall (root) | Windows Win32 System | Linux deb postinst / container root |
|---|---|---|---|---|
| Every path comes from `$HOME` / `$env:USERPROFILE` (config, logs, `~/.local/bin`, `~/.claude`, `~/.bashrc`, `~/.zshrc`, `$PROFILE`) | `aitools-install.sh:212, 332, 517-518, 586`; `.ps1:135, 210, 404, 442, 478`; lib `AITOOLS_LOG_DIR` aitools-lib.sh:72, aitools-lib.ps1:565 | goes to root's home, not the user's. Running with HOME pointed at the user but uid 0 leaves root-owned files in the user's home | `C:\Windows\System32\config\systemprofile`. Nothing reaches the user | `/root`. That is correct in Claude Code web, where the user is root (managed-file-deployment.md platform table: `/root/...` as root). It is wrong on a VM with a desktop user |
| `HOME` is set | aitools-lib.sh:72 runs at source time under the caller's `set -u` (aitools-install.sh:10) | launchd / installer environment: unknown, verify | n/a | a maintainer script's environment: unknown, verify. An unset HOME crashes before any logging |
| No console-user resolution | `grep /dev/console\|SUDO_USER\|ConsoleUser scripts/` finds nothing (MDM-PKG F5, re-run by me: no hits) | must be added in the wrapper | must be split into a System app + a dependent User app (MDM-PKG A') | `SUDO_USER` / the logind session must be added in the wrapper |
| Homebrew usable by the caller | aitools-install.sh:346-352, 617-633; bootstrap.sh:32-41 | Homebrew refuses root (MDM-PKG F5 / Critic; not re-verified by me). Step 8 then ERRORs "Homebrew not found" | n/a | n/a (no brew on Linux) |
| `sudo apt-get` works | setup-gh-cli.sh:48-52, 135; setup-pandoc.sh:153; bootstrap.sh:48 (RevTools owns these) | n/a | n/a | **inside dpkg's postinst, a nested apt-get cannot get the dpkg lock** (standard dpkg behaviour; not tested here). In a root container without sudo, `sudo` is not found. With no TTY and no NOPASSWD, sudo fails |
| winget is on PATH | aitools-install.ps1:550; aitools-install.sh:100 | n/a | widely reported that `winget` does not resolve for SYSTEM (WindowsApps path). **Not verified here.** No `--scope` is passed (MDM-PKG Q6) | n/a |
| PowerShell host bitness | | n/a | unknown: whether the Win32 install command runs 32- or 64-bit; PkgWin to verify | n/a |
| aitools repo = a writable git checkout | sync: `git checkout HEAD -- deploy/`, `git pull` (`scripts/aitools:1984-2006`); clone when `.git` is missing (1477-1485); build-deploy every run (2054-2060) | a payload under `/Library/Application Support/aitools` that is not a checkout: the sync's clone fails ("destination exists"), so `aitools` returns 1. A root-owned checkout fails for the user (git "dubious ownership", no write) | same with `C:\Program Files\aitools` | same with `/opt/aitools` or `/usr/share/aitools` |
| `repoPath` = the installer's parent dir | `AITOOLS_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"` (sh:338), ps1:215 | config.json `repoPath` = the payload root. Every later `aitools` run treats it as the repo (above) | same | same |
| gh auth | Step 2 | as root: not authenticated, WARN + ACTION; harmless but meaningless | as SYSTEM: same | same |
| Network | Steps 1, 8, 9-20b (curl/brew/winget/apt); the sync pull | required; no offline mode | required | required |
| Git Bash | aitools.ps1:1989-1993 hard-codes `$env:ProgramFiles\Git\bin\bash.exe`, exit 1 if missing | n/a | sync only. A per-user Git install (not under Program Files) fails the sync. The installer itself needs no bash | n/a |
| pwsh 7 | bootstrap.ps1:48 runs the installer with **`powershell`** (5.1); aitools-lib.ps1:565 uses 3-argument `Join-Path` (PS 6+); setup-user-claude.ps1:37-38 refuses below 7 | n/a | the Win32 install command must call `pwsh.exe` by full path. The bootstrap path is broken (INCIDENT) | n/a |
| Long paths | ps1:224-239 only reads HKLM and asks for admin | n/a | SYSTEM could set it but does not; `git config --global` goes to the SYSTEM profile | n/a |

## 5. The "skipping (MDM deploy)" branches (task 4)

- **Count (grep, verifies MDM-PKG F3):** 17 in `aitools-install.sh` (363, 524, 551,
  578, 603, 690, 702, 714, 726, 738, 750, 762, 774, 786, 798, 810, 825) and 18 in
  `aitools-install.ps1` (268, 414, 424, 449, 472, 536, 619-752). After #106, the bin
  branches (sh:551, ps1:449) go and one is added in each `run_harness_step` /
  `Invoke-HarnessStep` (`deploy-harness.* not found -- skipping (MDM deploy)`),
  which keeps the counts at 17 and 18.
- **Trigger:** only a missing file. Each branch is `if [ -f "$SCRIPT_DIR/<x>" ]` or
  `Test-Path (Join-Path $PSScriptRoot <x>)`, plus `../shared/shell/aliases.*` for
  the rc-file step. No flag, environment variable or install-location test exists.
- **Effect:** each one is `log_warn` / `LogWarn`. The warning is counted, the exit
  code stays 0, and **none of them writes its own summary row** (only the bin loop
  still ends in its aggregate `harness bin` row, sh:565), so the missing tool
  silently disappears from the panel. script-standards.md requires every code
  path to call `write_summary`.
- **Step 21 differs:** a missing config script is `log_warn "<script> not found —
  skipping"` with no MDM label and no row (sh:840, ps1:775).
- **Would a package layout trigger them?**
  - **No**, if the payload is the `scripts/` + `shared/` tree, whatever its root
    (`/Library/Application Support/aitools`, `C:\Program Files\aitools`,
    `/opt/aitools`, `/usr/share/aitools`). Every check is relative to the
    installer's own directory.
  - **Yes**, if the payload is today's dotprofile `deploy/` with an installer added
    next to it (MDM-PKG A'). `deploy/` has the tool setup scripts (MDM-PKG section 3,
    "15 plain tool pairs") but no `aitools`, `hh.*`, `../shared/shell/aliases.*` or
    harness CLIs, so Steps 6-7 would skip with warnings. But it never gets that
    far: deploy/ also has no standalone `aitools-lib.sh` (the library is inlined
    into each script), and the installer sources `$SCRIPT_DIR/aitools-lib.sh`
    (sh:14, ps1:41) with no check, so a `deploy/`-only payload fails at line 14
    under `set -e` before any logging. (Checked on the committed dotprofile:
    `git -C /Users/new-jose/repos/aitools-nobul-jose ls-tree --name-only HEAD deploy/`
    lists 42 `setup-*` files and no `aitools-lib.*`; that tree is stale, so main's
    build output was not listed by me.)
- **Suggested:** rename these to "not in this payload" and give each an
  `OK "<tool>" "n/a (not in payload)"` row, the same pattern as
  `write_environment_skip`. Package builds should ship the full tree, so the branches
  stay dead code there.

## 6. Prerequisite installation today (task 5)

| Prerequisite | Installed by | Notes / defects |
|---|---|---|
| Homebrew | bootstrap.sh:32-35 (official install.sh, interactive) | not by the installer, which only runs `brew shellenv` (sh:346-352; also `scripts/aitools:20-26`). Refuses root (section 4) |
| git | bootstrap.sh:42 (brew), 45-55 (`sudo apt-get` / `dnf`); bootstrap.ps1:21-30 (winget Git.Git, PATH refreshed) | the installer assumes it: ps1:242 calls `git config` unguarded |
| pwsh 7 | aitools-install.sh:96-116, **only** in the Windows Git Bash forwarding (winget via powershell.exe) | not installed on macOS/Linux by any entry point. bootstrap.ps1 does not install it and launches the installer under 5.1 (INCIDENT) |
| Node.js | installer Step 8: macOS `brew install node@22` (sh:617-629); Windows winget `OpenJS.NodeJS.LTS`, no `--scope` (ps1:549-563); Linux: WARN "install manually" (sh:635-637) | **`node@22` is keg-only** (`brew info node@22`, run 2026-10-26: "node@22 is keg-only, which means it was not symlinked"). On a Mac without another node, the result is ERROR "installed but not on PATH" (sh:627-628). Many config scripts need node |
| Python | Steps 14-15 (setup-uv, setup-python) | RevTools |
| Claude Code CLI | Step 9: `curl -fsSL https://claude.ai/install.sh \| bash` (sh:668), `irm https://claude.ai/install.ps1 \| iex` (ps1:592); else `claude update` | per user (installs into the caller's home). As root/SYSTEM it lands in the wrong home |
| gh | Step 1 (setup-gh-cli) | RevTools; Linux uses `sudo apt-get` |
| perl | assumed (sh:591 `perl -i`; aitools-json.pl in user init) | macOS has it; Ubuntu `perl-base` has `/usr/bin/perl`; Windows via Step 19 / Git Bash |

**bootstrap.sh** (macOS/Linux) does four things:
1. Homebrew and git (macOS), or git and curl via apt/dnf (Linux).
2. Clone or `pull --ff-only` `https://github.com/nobul-tech/aitools.git` into
   `${AITOOLS_DIR:-$HOME/repos/aitools}`.
3. `bash scripts/aitools-install.sh "$@"`. A failure is only printed.
4. Only with `[ -t 0 ]`: `aitools user init`, then `aitools`.

**bootstrap.ps1** (Windows):
1. git via winget.
2. Clone or pull.
3. `& powershell -NoProfile -ExecutionPolicy Bypass -File ...\aitools-install.ps1`.
   This uses Windows PowerShell 5.1, and its result is not checked.
4. Only with `[Environment]::UserInteractive` and `Get-Command aitools`: `aitools
   user init; aitools`. On a fresh machine, `Get-Command aitools` probably fails in
   that session, because the profile and PATH were only just written. Not verified.

## 7. Per-user personalisation inputs (task 6)

| Input | Obtained from | Fleet user (not Jose) needs |
|---|---|---|
| `reposPath` | `--repos-path` flag, else config.json, else prompt, else `$HOME/repos` (sh:398-419) | nothing; the default works |
| `repoPath` (the aitools repo) | the installer's own location (sh:338, ps1:215) | the package location; see section 4 for why the sync then breaks |
| `googleDrives` | Step 4: macOS `~/Library/CloudStorage/GoogleDrive-*/My Drive`; Windows `Get-PSDrive` "* - Google*"; Linux none | nothing |
| `githubUser` | user init: `gh api user`, else config.json, else prompt (`scripts/aitools:913-921`) | a signed-in gh, or a value written into config.json |
| `userRepoPath` (dotprofile) | resolver order (aitools-profile.sh:419-473): `AITOOLS_USER_REPO_PATH`, `--user-repo-path`, config.json, `<reposPath>/aitools-<githubUser>`, the only `aitools-*` dir with `profile.json`, else none (shared-only mode, "not an error") | **their own** private `aitools-<user>` repo with `profile.json`, or shared-only mode. Without a terminal, user init creates and pushes one by default (section 3.2) |
| machine id | `aitools-profile machine-id`: macOS IOPlatformUUID via ioreg; Linux `/etc/machine-id`, then `/var/lib/dbus/machine-id`; Windows HKLM MachineGuid (aitools-profile.sh:338-370, .ps1:270-288) | readable by any user. **Containers often have no `/etc/machine-id`, or one shared by every clone** (the comment at aitools-profile.sh:339 says so). Environment profiles (`environment:claude-code-web`, `scripts/aitools:377-381`) cover Claude Code web; Cursor cloud has no environment value (brief) |
| machine alias / profile | user init: `--alias`, `AITOOLS_MACHINE_ALIAS`, the resolver's match, or a menu | `--alias` or `AITOOLS_MACHINE_ALIAS`, or user init ERRORs without a terminal |
| identity (name, email, company) | git config, else `whoami` / `[Environment]::UserName`; asked on a terminal (`scripts/aitools:611-624`) | git identity on the machine |
| GitHub org | **hard-coded** `nobul-tech/aitools` (`scripts/aitools:1480`, aitools.ps1:476, bootstrap.sh:21, bootstrap.ps1:15) | fine for a fleet while the repo stays public (MDM-PKG F7); a fork cannot override it (no variable) |

**Fleet conclusion:** the installer needs no per-user input (shared-only mode works).
Personalisation needs user init, which needs gh auth or `githubUser`, plus `--alias`,
plus a dotprofile repo. Today a package can only provide shared-only mode, unless it
also ships a per-user snapshot (MDM-PKG C').

## 8. What a package entry point can reuse vs must change

**Reuse as is:**
- The installers as the orchestrator, using their flags `--repos-path`,
  `--skip-gh-auth`, `--skip-drive-detection` and `--dry-run`.
- These environment variables: `AITOOLS_FORCE=1`, `AITOOLS_RUN_ID`,
  `AITOOLS_SUMMARY_FILE` + `AITOOLS_SUPPRESS_SUMMARY_DISPLAY`, `AITOOLS_LOG_DIR`,
  `AITOOLS_USER_REPO_PATH`, `AITOOLS_MACHINE_ALIAS`.
- `validate_and_run` / `Invoke-ValidatedScript`: syntax-check first, then ERROR row
  and continue.
- The non-interactive defaults (section 3.2).

**Must change or be wrapped:**
- console-user / SYSTEM-vs-user split (section 4);
- the step list from one manifest (section 2.3);
- prerequisites (section 6);
- the sync path's dependence on a git checkout;
- unknown flag exits 0;
- user init's default repo creation;
- `GIT_TERMINAL_PROMPT=0` for every git call in a package run;
- a status marker file for MDM detection, because exit 1 covers any error and
  Intune macOS hides post-install failures (MDM-PKG A' risks).

## 9. Remediations (task 7)

| # | File:function (line) | Sev | Fix direction | Open PR |
|---|---|---|---|---|
| R1 | aitools-install.sh Step 21 (833), .ps1 (760-768) vs `scripts/aitools` `deploy_configs` (1108, 1151), aitools.ps1 `Deploy-Configs` (157) | medium | one generated manifest with phases; P2 uses the post-#106 sync order | #106 fixes the sync side only; Step 21 is unchanged |
| R2 | installer Step 5 + Step 8b (writer twice) | low | `deploy-harness --skip-config` from Step 8b | none (#106 follow-up 1) |
| R3 | aitools-install.sh flag parse (47-51, 56-77) | high for MDM | an unknown option is `log_error` + exit 1 (help only for `--help`) | none |
| R4 | `ui_create_dotprofile` (`scripts/aitools:811, 847-865`), aitools.ps1 `Invoke-UiCreateDotprofile` (1452-1475) | high for a fleet | non-interactive default = do not create the GitHub repo; WARN + ACTION | none |
| R5 | bootstrap.ps1:48 | high | run the installer with `pwsh` (installing it first via winget, as aitools-install.sh:96-116 does), and check its exit code | none |
| R6 | aitools-install.sh Step 8 (619) | high (fresh Mac) | `brew install node` (or link `node@22`/add the keg to the PATH block), and re-verify with `/tool-eval` | none |
| R7 | entry points: no console-user resolution (grep: none) | critical for MDM | resolve it in the package wrapper (macOS `/dev/console` + `sudo -u <user> -H`; Windows System + User Win32 apps; Linux `SUDO_USER`), and add a root/SYSTEM guard to the installer that refuses unless an explicit override is set (for example, Claude Code web root is allowed) | none |
| R8 | `scripts/aitools` main (1477-1485, 1978-2060), aitools.ps1 (472-482, 1925-2015) | high for packages | a "package mode": repoPath points at a read-only payload, with no clone, pull, `checkout deploy/` or build-deploy. Updates come from the package | none |
| R9 | aitools-lib.sh:72 + `set -u` | medium | `HOME` guard with a logged error in the installer before sourcing (`: "${HOME:?...}"` is not logged, so it needs a printf to stderr plus exit 1) | none |
| R10 | 17/18 "skipping (MDM deploy)" branches | low | rename, and add `OK "n/a (not in payload)"` rows | none (#106 adds one more of the same) |
| R11 | aitools-install.sh:14, ps1:41 (lib sourced with no check) | low | check that the file exists, print to stderr and exit 1 before sourcing | none |
| R12 | aitools.ps1 version stamp (2032, 2197, 2207): `-replace '^...'` on `-Raw` content | medium | use `(?m)^`. Probe (`.scratch/session-rvinst/stamp-probe.ps1`, pwsh 7): unanchored `False` for the ps1 and the bash copy, `(?m)` `True`. **The installed version on the PowerShell path is always "dev"**, so a package cannot use it as a detection marker | none |
| R13 | aitools.ps1:1989 hard-coded Git Bash path | low | resolve via the registry / `Get-Command git` (setup-bash.ps1 already probes known paths, cross-platform.md) | none |
| R14 | sync `git pull`s (`scripts/aitools:2006, 2037`; aitools.ps1:1936, 1974) | medium | `GIT_TERMINAL_PROMPT=0` + ssh BatchMode when not interactive (user init already does this) | none |
| R15 | bootstrap.sh:32-35 Homebrew install | medium | `NONINTERACTIVE=1` when not a TTY; refuse root with a clear message | none |
| R16 | bootstrap.sh:76-80, bootstrap.ps1:48 | low | propagate the installer's exit code | none |
| R17 | aitools-install.sh:211-216 (summary `touch` before `mkdir -p ~/.aitools` at 334) | low | `mkdir -p` first. Today this works only because `logging_init` creates `~/.aitools/logs`; with `AITOOLS_LOG_DIR` relocated, `touch` fails under `set -e` | none |
| R18 | `AITOOLS_DEPLOY` exported and never read (`scripts/aitools:1099`, aitools.ps1:159; grep) | low | delete it, or make it the package-mode signal (R8) | none (FanPlan INCIDENT, also unaddressed by #106) |
| R19 | interactive test differs across entry points (section 3.1) | low | use `tty_interactive` / `Test-InteractiveConsole` everywhere (bootstrap, `check_profile`) | none |
| R20 | private relay copies in the installers | medium | already fixed | **#116** (A-1, A-16, A-17, A-18) |
| R21 | deploy-harness not run by any entry point | high | already fixed | **#106** |
| R22 | user init private resolver runners | low | already fixed | **#113** |

## 10. INCIDENT markers (not filed)

- INCIDENT: `bootstrap.ps1:48` runs `aitools-install.ps1` under Windows PowerShell
  5.1 (`& powershell`). The lib uses 3-argument `Join-Path` (aitools-lib.ps1:565,
  PS 6+) and setup-user-claude.ps1:37-38 refuses below PS 7. cross-platform.md says
  "PS 7 (`pwsh`) is the project baseline". bootstrap.ps1 never installs pwsh. High.
- INCIDENT: `aitools-install.sh:47-51` treats an unknown option as `--help` and exits
  0 at :76. A mistyped flag in an MDM install command reports success and installs
  nothing. Spec: script-standards.md exit footer ("exit 1 on errors"). High for MDM.
- INCIDENT: `brew install node@22` (aitools-install.sh:619) installs a keg-only
  formula (`brew info node@22`, 2026-10-26). On a Mac with no other node, Step 8
  reports ERROR "installed but not on PATH" (:627-628). Install methods must come
  from `/tool-eval` (tool-lifecycle.md "Install method discovery"). Unknown whether
  an evaluation chose `node@22`. Medium.
- INCIDENT: `ui_create_dotprofile` defaults to creating and pushing a private GitHub
  repo when there is no terminal (`scripts/aitools:811, 847-865`; aitools.ps1:1452).
  interactive-menus.md "Non-interactive fallback" covers only the review menus, so
  no spec covers this default. Governance ambiguity, medium (high for a fleet).
- INCIDENT: the aitools.ps1 version stamp is a no-op: the `^` anchor without `(?m)`
  on `-Raw` content (aitools.ps1:2032, 2197, 2207; probe output in R12). The bash
  stamp (`sed`, `scripts/aitools:2245`) works. A parity deviation, medium.
- INCIDENT: none of the 17 bash "skipping (MDM deploy)" branches writes its own
  summary row (they log_warn only). script-standards.md "End-of-run summary": "Every code path
  (success AND failure) must call `write_summary`". The PS1 twins behave the same.
  Low.
- INCIDENT: there is no single interactive test. bootstrap.sh uses `[ -t 0 ]`,
  bootstrap.ps1 uses `UserInteractive`, and the lib uses `tty_interactive` /
  `Test-InteractiveConsole` (section 3.1). interactive-menus.md defines the
  installer rule. Low.
- INCIDENT (confirming MDM-PKG): no script resolves the console user or states its
  run context. A governance gap that blocks every package kind.
- NOTE (not an incident): FanPlan's INCIDENT that #106's abort contradicts a
  2026-10-26 decision conflicts with the S3-BuildPkg brief, which keeps #106's
  behaviour. For S3-BuildPkg to reconcile.

## 11. Open questions (with suggested answers)

- **Q1: Does the package ship the full `scripts/` + `shared/` tree, or `deploy/`?**
  Suggested: the full tree at the pinned tag, plus the per-user snapshot. It
  triggers no MDM branch, reuses the installers as they are, and avoids the
  library-twice size problem (MDM-PKG section 3).
- **Q2: Is `aitools` (the sync) supported on package-installed machines?**
  Suggested: yes, through a package mode (R8) that skips pull, clone and build
  and deploys from the payload. Updates come only from a new package version (this
  answers the brief's Q4 in part).
- **Q3: The Linux package as root in a container vs a VM user.** Suggested:
  postinst does only system-scope work (files under `/opt/aitools`, apt
  dependencies declared in `Depends:`, no nested apt). The user step runs on first
  login or through an explicit `aitools install` by the user. In Claude Code web,
  the user is root, so running the user step from postinst is acceptable there only.
- **Q4: Exit-code policy for MDM.** Suggested: the wrapper maps
  - installer 0 → success;
  - 1 → failure, with the summary copied to `~/.aitools/logs/last-summary.txt`
    (aitools-lib.ps1:3011 already preserves one);
  - 2 → cannot happen without a terminal, so treat it as failure;

  and writes a version marker file for detection.
- **Q5: Cursor cloud environment value.** It is not in the closed list
  (`claude-code-web` | `local`). Suggested: `cursor-cloud`, with a commander decision
  (brief "Operational learning").

## 12. WRITE_BLOCKED

None.
