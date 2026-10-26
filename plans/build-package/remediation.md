# build-package remediation list

Author: S3-BuildPkg-RemedWriter for S3-BuildPkg, version 1.0, 2026-10-26

**Intent**: **Purpose**: One consolidated, de-duplicated list of every change the existing
codebase needs for the package distribution (`build-package`), and of the defects found on
the way. Each item gives a file:function citation, a severity, the batch that fixes it, and
the open PR that already fixes it. **Scope**: The remediation lists and INCIDENT markers in
the five S3-BuildPkg code reviews (RevBuild, RevInstall, RevLib, RevSetup, RevTools), the
packaging notes (PkgWin, PkgMac, PkgLinux), the language evaluation (Lang), the docs
inventory (DocsInv) and S3-MdmPkg report section 8. NOT the design or the implementation
plan (`design.md`, `implementation-plan.md`). NOT code. NOT filed incidents (candidates
only; `registries/incidents.json` is protected and the orchestrator triages). **Audience**:
Jose (the commander) and the mission that executes the batches.

(Protected-file review of this intent statement waived by the commander for this mission.)

Contract: `S3-BuildPkg-decisions.md` rev 1 (BP-1..BP-20, batches B0-B14). No contract
changes are proposed here.

## 1. How this list was built

- **Sources.** Every remediation row, INCIDENT marker and open question with a defect in:
  `S3-BuildPkg-RevBuild-findings.md` (RevBuild), `-RevInstall-findings.md` (RevInstall),
  `-RevLib-findings.md` (RevLib), `-RevSetup-findings.md` (RevSetup),
  `-RevTools-findings.md` (RevTools), `-PkgWin-notes.md`, `-PkgMac-notes.md`,
  `-PkgLinux-notes.md`, `-Lang-evaluation.md`, `-DocsInv-inventory.md` (all in
  `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-BuildPkg/`), and
  `S3-MdmPkg/S3-MdmPkg-report.md` section 8. In the Source column, "R7" means the
  reviewer's remediation 7 and "INC" means its INCIDENT marker list.
- **Code re-checked, not reports.** Reviewers cited main at 5976553. Main is now 0ddd127.
  Between the two, only `scripts/check-pre-push.sh/.ps1` changed
  (`git diff --stat 5976553 0ddd127 -- scripts shared`), so the line numbers below hold at
  0ddd127. Each citation marked "yes" was re-read with grep or a line-range read
  (scripts: `.scratch/session-remedwr/verify.sh`, `verify2.sh`, `verify3.sh`; outputs `*.out`
  beside them). "unverified" means I did not re-read it, usually because it is registry
  data (skill-gated, `governed-data-access.md`), a run-time behaviour, or an upstream page.
- **PRs checked.** `gh pr diff <n> -R nobul-tech/aitools` for #98-#106 and #108-#116,
  saved under `.scratch/session-remedwr/prs/`. I grepped the added lines for each fix
  (`pr-scan.sh`, `pr-ctx.sh`). "none" in the PR column means no open PR's added lines
  fix it.
- **Existing incidents checked.** `registries/incidents.json` (open max id 145) and PR #102's
  drafts (#146-#167), so that duplicates are linked, not re-proposed (`inc-scan.py`).
- **Commander decisions applied (2026-10-26).** Abort stays as #106 implements it: only an
  exit 2 from deploy-harness stops a run. A dotprofile push from a non-main branch is an
  ERROR (RevLib found no PR that enforces it; see RM-47).
- **De-duplication.** One item per deficiency, with every source listed. The biggest merge
  is console-user / run-context resolution (RM-39). Six sources raise it: RevBuild R3,
  RevInstall R7, RevLib R1/R2, RevSetup R1, RevTools R3 and MdmPkg F5.

## 2. Legends

**Severity** (`.claude/rules/incident-governance.md` "Severity"):

| Level | Meaning |
|---|---|
| critical | Deployment, data loss, security, cross-machine propagation |
| high | Silent wrong behaviour, rule violations in production code |
| medium | Documentation drift, minor behavioural inconsistency |
| low | Cleanup, style, future-proofing |

**Columns:**

| Column | Meaning |
|---|---|
| ID | RM-n, stable for this mission |
| Deficiency | Names the deficiency, not the symptom |
| Where (0ddd127) | file:function and line(s) on main 0ddd127 |
| Sev | Severity, legend above |
| Blocks pkg | yes = a package kind cannot ship correctly until this is fixed |
| Fix direction | One line; the plan owns the detail |
| Batch | B-id from the decisions file (primary; secondary in brackets). `--MDM` = MDM-path follow-up with no package batch (BP-2: build-package never calls build-deploy.sh). `--dev` = dev-path follow-up with no package batch. `--PR` = an open PR fixes it fully; the batch only depends on it |
| PR | Open PR whose added lines fix it: `#n` (fully), `#n partial`, or `none` |
| Source | Review file plus item number |
| Ver | yes = citation re-checked at 0ddd127; unverified = not re-checked (reason in the row) |

## 3. Build and deploy (build-deploy.sh, deploy-harness)

| ID | Deficiency | Where (0ddd127) | Sev | Blocks pkg | Fix direction | Batch | PR | Source | Ver |
|---|---|---|---|---|---|---|---|---|---|
| RM-1 | A build embeds the build-time dotprofile's identity (profile.json snapshot with github, email and hostnames; CLAUDE.md template; rules) as the run-time fallback for every endpoint without a dotprofile | build-deploy.sh top level: `PROFILE_JSON` :258-310, embed :516, :564, fallback :667-673 | critical | no (BP-1: packages never ship deploy/) | MDM: `--no-personal`, or mark deploy/ single-user. Package: B2 `stage` asserts no dotprofile content in the payload | --MDM (B2 gate) | none | RevBuild R1 + INC 1; RevLib section 6, Q3; MdmPkg section 5 A' risks; related open incident #78 | yes |
| RM-2 | The dev deploy-harness deploys only git-tracked files and refuses any source outside a git work tree, so a payload gives one ERROR per source, deploys only bin, and exits 1 | deploy-harness.sh `add_source` :181-186; deploy-harness.ps1 `Add-Source` :161-168 | high | yes (a `git archive` payload has no .git) | Source-listing mode that reads the payload `MANIFEST` (BP-1) when no work tree exists | B4 | none (#100, #110, #111 add no non-git source mode) | RevBuild R2 + INC 2; RevInstall section 4 | yes |
| RM-3 | A first run without config.json bootstrap keys (`reposPath`, `repoPath`) fails: setup-user-config writes ERROR "missing bootstrap values" and deploy-harness ERRORs | setup-user-config.sh bootstrap check :298-330 (row :330), .ps1 :300-328; deploy-harness.sh config writer :100-116 | high | yes (first user phase of every package) | Package-mode installer writes the keys before deploy-harness, with `repoPath` = read-only payload root (decide its meaning) | B3 | #111 partial (MDM variant only: n/a row, `--skip-config`) | RevBuild R15, Q-B4; RevSetup R3, Q4; MdmPkg F4 | yes |
| RM-4 | No single step-order source: the installer's Step 21 list and the sync lists disagree, and deploy/ has no run-order manifest (comments only) | aitools-install.sh Step 21 `DEPLOY_SCRIPTS` :835, .ps1 :760-768; scripts/aitools `deploy_configs` :1151 (:1108); aitools.ps1 `Deploy-Configs` :157; build-deploy.sh comments :855, :895, :1913 | medium | yes (BP-6 order file) | One order file (`scripts/aitools-order.txt`, proposed) read by both installers and both sync entry points; user phase = the post-#106 sync order | B3 | #106 partial (sync lists put deploy-harness first; Step 21 unchanged) | RevInstall R1, 2.3; RevBuild R16; MdmPkg F2 + INC 5 | yes |
| RM-5 | No entry point runs deploy-harness on main | scripts/aitools, aitools-install.sh (grep `deploy-harness`: 0 hits) | high | yes | -- | --PR | #106 | RevInstall R21; MdmPkg INC 5 | yes |
| RM-6 | `aitools install` runs the config writer twice after #106 (Step 5, then inside Step 8b) | aitools-install.sh Step 5 :487-508; #106 Step 8b | low | no | Step 8b calls `deploy-harness --skip-config` | B3 | none (#111 adds the flag; #106 does not pass it; it is only a handback question) | RevInstall R2; RevBuild section 5 | yes |
| RM-7 | Without git, the PS1 work-tree guard passes on a stale `$LASTEXITCODE`, and the ls-files error is empty | deploy-harness.ps1 `Add-Source` :163-164, :174-176 | low | no (git is a BP-8 prerequisite) | Set `$global:LASTEXITCODE = 1` before the call, or check `Get-Command git` once | B4 | none | RevBuild R14 + INC 6 | yes (code; reproduction is RevBuild's) |
| RM-8 | build-deploy.sh exits 0 on every skip (node missing, no dotprofile, resolver error), and PS1 validation is optional | build-deploy.sh :86-89, :203-217, :2279 | high | no (BP-2) | `--strict` / `AITOOLS_BUILD_STRICT=1`; build-package has its own strict exits | --MDM | none | RevBuild R4 + INC 4 | yes |
| RM-9 | A dirty working tree is embedded with only a WARN | build-deploy.sh :1772-1774 | medium | no (B2 stages `git archive <ref>`) | `--strict` fails it | --MDM | none | RevBuild R5 | yes |
| RM-10 | Generated output carries no version or commit stamp | build-deploy.sh (grep `BUILD-INFO\|rev-parse HEAD`: 0) | medium | no for packages (B2 writes BUILD-INFO) | `--stamp`; BUILD-INFO | B2 (--MDM) | none | RevBuild R6 + INC 7 | yes |
| RM-11 | The library is inlined 27 times per platform, twice in setup-user-claude, -cursor and -settings, so 7 .ps1 files exceed Intune's 200 KB script limit | build-deploy.sh `inline_lib_bash` :124, `inline_lib_ps1` :151; `RESOLVER_SH_FILES` / `RESOLVER_PS1_FILES` :436-437 | high | no (BP-2 ships the lib once) | `--lib sibling` | --MDM | #111 partial (deploy-harness size only) | RevBuild R7; MdmPkg section 3 + INC 3 | yes |
| RM-12 | Skills and hooks are embedded as heredocs (about 192 KB and 130 KB) | build-deploy.sh :1254-1634 (`__SKILL_` heredocs) | medium | no | Sibling data files, as in #111's payload | --MDM | none | RevBuild R8; MdmPkg section 3 | yes |
| RM-13 | Only deploy-harness gets a size gate, and only with #111; on main 7 .ps1 files are 200,000 B or more and the build passes | build-deploy.sh (grep `200000`: 0 on main) | medium | no | Per-channel gates | --MDM | #111 partial | RevBuild R9; MdmPkg INC 2 | yes |
| RM-14 | The MDM trap replaces the BUILD_TMP trap, so BUILD_TMP leaks on every build | build-deploy.sh :1706 vs :320 | low | no | -- | --PR | #111 | RevBuild R10 + INC 3; MdmPkg INC 4 | yes |
| RM-15 | The deploy/ swap is not atomic: `rm -rf` then `mv`, so a failed `mv` leaves no deploy/ | build-deploy.sh :2298-2305 | medium | no | Move the old dir aside, move the new one in, then remove the old one | --MDM | none | RevBuild R11 | yes |
| RM-16 | `chmod +x "$DEPLOY_DIR"/*.sh 2>/dev/null \|\| true` has no comment and no check | build-deploy.sh :2288 | low | no | Check each file, or comment the exemption | --MDM | none | RevBuild R12 + INC 5 | yes |
| RM-17 | The Windows pwsh parse check uses `2>/dev/null` with no comment | build-deploy.sh :2239 | low | no | Capture stderr as the macOS branch does | --MDM | none | RevBuild R13 + INC 5 | yes |
| RM-18 | check-post-push step 7 runs build-deploy.sh with the real HOME and config, so it rebuilds the real dotprofile deploy/ | check-post-push.sh :204 | medium | no | Isolated HOME and a temp dotprofile copy, as in pre-push step 7 (check whether #86 tracks it) | --dev | none | Lang section 5 observation | yes |
| RM-19 | Whether Ubuntu images carry the perl modules the scripts need (Digest::SHA, MIME::Base64, File::Path; JSON engine) is unknown | run-time perl on Ubuntu 22.04/24.04 | low | unknown until measured | `Depends: perl` (not perl-base, BP-8); B12 runs `perl -MDigest::SHA -MMIME::Base64 -MFile::Path -e1` in both images | B10 | none | RevBuild R18 | unverified (no container here) |

## 4. Installers and entry points

| ID | Deficiency | Where (0ddd127) | Sev | Blocks pkg | Fix direction | Batch | PR | Source | Ver |
|---|---|---|---|---|---|---|---|---|---|
| RM-20 | An unknown installer option is treated as `--help` and exits 0 having installed nothing, so a mistyped MDM command reports success | aitools-install.sh flag loop :44-51, help exit :76 | high | yes | Unknown option = `log_error` + exit 1 (never 2, D-TS13); help only for `--help` | B3 | none | RevInstall R3 + INC 2 | yes |
| RM-21 | The sync entry point needs a writable git checkout: it clones when `.git` is missing, then pulls, resets deploy/ and runs build-deploy every run | scripts/aitools :1477-1485, :1978-2060 (pulls :1985, :2006); aitools.ps1 :472-482, :1925-2015 | high | yes | `--package-mode` (BP-6): no clone, pull, reset or build; updates come only from a new package | B3 | none | RevInstall R8, Q2; RevBuild section 3d | yes |
| RM-22 | The PowerShell version stamp is a no-op (`^` without `(?m)` on `-Raw` content), so the installed version on the PowerShell path stays "dev" | aitools.ps1 :2032, :2197, :2207 | medium | yes (BP-12 version source) | `(?m)^` | B3 | none | RevInstall R12 + INC 5 | yes (code; .NET `^` without Multiline anchors only at string start; RevInstall probe) |
| RM-23 | With no terminal, user init creates and pushes a private GitHub repo by default; no spec covers that default | scripts/aitools `ui_create_dotprofile` :811 (`ans="y"`), :847-870; aitools.ps1 :1445-1476 | high (fleet) | no (the package user phase never runs user init, BP-11) | Non-interactive default = do not create; WARN + ACTION | B3 | none | RevInstall R4 + INC 4 | yes |
| RM-24 | The 17 bash and 18 PS "skipping (MDM deploy)" branches log a warning but write no summary row, so the tool vanishes from the panel | aitools-install.sh :363, :524-825; aitools-install.ps1 :268-752 | low | no (a full payload triggers none) | `OK "<tool>" "n/a (not in payload)"` | B3 | none (#106 adds one more of the same) | RevInstall R10, section 5 + INC 6; MdmPkg F3 | yes (17 / 18) |
| RM-25 | The installer sources the lib with no existence check | aitools-install.sh :14; aitools-install.ps1 :41 | low | no | Check, print to stderr, exit 1 | B3 | none | RevInstall R11 | yes |
| RM-26 | An unset HOME crashes the bash lib at source time under `set -u`, before any logging | aitools-lib.sh :72 | medium | yes (launchd and maintainer-script environments unknown) | Logged HOME guard before sourcing; lib fail-safe | B5 (B3) | none | RevInstall R9; RevLib section 4 | yes |
| RM-27 | The summary file is touched before `~/.aitools` is created | aitools-install.sh :214-216 vs `mkdir -p "$CONFIG_DIR"` :334 | low | no | `mkdir -p` first | B3 | none | RevInstall R17 | yes |
| RM-28 | The sync's git pulls do not set `GIT_TERMINAL_PROMPT=0` or ssh BatchMode | scripts/aitools :1985, :2006, :2037; aitools.ps1 :1936, :1974 | medium | no (package mode skips pulls) | Set both when non-interactive | B3 | none (#103/#116 set them only for the dotprofile push) | RevInstall R14 | yes |
| RM-29 | Git Bash path hard-coded to `$env:ProgramFiles\Git\bin\bash.exe` | aitools.ps1 :1989 | low | no | Known-path lookup, as in setup-bash.ps1 | B3 | none | RevInstall R13 | yes |
| RM-30 | `AITOOLS_DEPLOY` is exported and never read | scripts/aitools :1099, :1215; aitools.ps1 :159, :209 | low | no | Delete it, or reuse it as the package-mode signal | B3 | none (#106 only adds an unset) | RevInstall R18 | yes |
| RM-31 | The entry points use different interactive tests | bootstrap.sh :92 (`[ -t 0 ]`); bootstrap.ps1 :59 (`UserInteractive`); scripts/aitools `check_profile` :100 | low | no | `tty_interactive` / `Test-InteractiveConsole` everywhere | --dev | none | RevInstall R19 + INC 7 | yes |
| RM-32 | bootstrap.ps1 runs the installer under Windows PowerShell 5.1, never installs pwsh, and does not check the exit code | bootstrap.ps1 :48 | high | no (launchers call pwsh by full path, BP-7/BP-8) | Install pwsh, run the installer with pwsh, check its exit | --dev | none | RevInstall R5 + INC 1; RevTools R9 | yes |
| RM-33 | bootstrap.sh runs the Homebrew installer without `NONINTERACTIVE=1` and does not refuse root | bootstrap.sh :34 | medium | no | `NONINTERACTIVE=1` when no TTY; clear refusal as root | --dev | none | RevInstall R15 | yes |
| RM-34 | The bootstrap scripts do not propagate the installer's exit code | bootstrap.sh :76-80; bootstrap.ps1 :48 | low | no | Propagate it | --dev | none | RevInstall R16 | yes |
| RM-35 | Node is not installed usably on any platform: macOS installs keg-only `node@22` (ERROR "not on PATH" on a fresh Mac), Linux only WARNs "install manually", Windows winget has no `--scope` | aitools-install.sh Step 8 :619, :633-637; aitools-install.ps1 :549-563 | high | yes on Linux (vercel, cursor-ide-mcp and hooks need node); Windows/macOS via BP-8 prerequisite packages | `/tool-eval` node per platform; a Linux method for the user phase | B7 | none | RevInstall R6 + INC 3; RevTools R8, section 2; existing incident #91 | yes |
| RM-36 | LongPathsEnabled (HKLM) and MSVC Build Tools need admin, but only user-context scripts check or warn about them | aitools-install.ps1 :219-239; setup-rust.ps1 :66-85 | medium | yes (Windows App A must own them) | Machine prerequisites in Win32 App A (System); user scripts keep PREREQ checks | B9 | none | RevTools R14 | yes |
| RM-37 | The installers carry private relay copies | aitools-install.sh/.ps1 relay blocks | medium | no | -- | --PR | #116 | RevInstall R20 | yes (PR files) |
| RM-38 | User init has private resolver runners | scripts/aitools, aitools.ps1 user init | low | no | -- | --PR | #113 | RevInstall R22 | yes (PR files) |

## 5. Shared library (aitools-lib, aitools-profile)

| ID | Deficiency | Where (0ddd127) | Sev | Blocks pkg | Fix direction | Batch | PR | Source | Ver |
|---|---|---|---|---|---|---|---|---|---|
| RM-39 | No console-user or privileged-run resolution anywhere, and no guard: every path is the process's own HOME / USERPROFILE, so root or SYSTEM runs deploy into root's or SYSTEM's profile, or leave root-owned files in the user's home (PowerShell `$HOME` is read-only) | aitools-lib.sh :72 and every `$HOME` use; aitools-lib.ps1 :562-566; deploy-harness.sh :79 / .ps1 :78; every setup-user-* target; grep `/dev/console\|SUDO_USER\|ConsoleUser` over scripts/ and shared/hooks: 0 hits | critical | yes (every package kind) | BP-10 API (`resolve_target_user`, `is_privileged_run`, `run_as_target_user`; PS1 twins). setup-user-* and user-scope tool scripts refuse when privileged and HOME is not the run user's. Only the launchers switch user | B5 (B6, B7 callers; B8-B10 launchers) | none | RevLib R1, R2 + INC 1; RevBuild R3, section 6; RevInstall R7, section 4 + INC 8; RevSetup R1, section 4.1; RevTools R3, section 3 gap 8; MdmPkg F5 + INC 7 | yes |
| RM-40 | Windows User-PATH writes go to the runner's HKCU, which under Intune System is SYSTEM's hive | aitools-lib.ps1 `Remove-OrphanedPythonDirs` :2794, `Ensure-GopathBinOnPath` :2907; setup-modal.ps1 :30 | high | no once the RM-39 guard refuses SYSTEM | User phase only (RM-39 guard) | B5 (B7) | none | RevLib R3; MdmPkg F5 | yes |
| RM-41 | No install helpers own privilege rules: `install_via_brew` / `install_via_apt` (named by D-ENV0) and `as_root` do not exist | aitools-lib.sh/.ps1 (grep: 0) | high | yes (Linux user phase and sudo handling) | Helpers: brew only as the target user; apt directly as uid 0, else `sudo -n`, else PREREQ ERROR; winget per BP-14 | B5 (B7) | none | RevLib R4 + INC 7; RevTools R4, section 3 gap 3; issue #14 | yes |
| RM-42 | The environment list is closed at `claude-code-web \| local`, although Cursor cloud is a supported environment; there is no value, no signal, and no `environment:<env>` profile key | aitools-lib.sh environment block :41-52, warning :675; aitools-lib.ps1 `Resolve-AitoolsEnvironment` :43-53, :582; aitools-profile.sh `--environment` :330-333 and the `environment:claude-code-web` literals; .ps1 :264-266 | medium | yes | BP-19: `cursor-cloud` set explicitly by `.cursor/environment.json`, secondary socket signal, `is_cursor_cloud` / `Test-CursorCloud`, `environment:<env>` keys | B5 (B1 P-2) | none | RevLib R5; RevSetup R15 (chrome-devtools runs headed in Cursor cloud); RevTools R16; PkgLinux section 5 + INC 2; DocsInv rows 11, 18 | yes |
| RM-43 | No Linux distro or version detection | aitools-lib.sh platform block (grep `os-release\|VERSION_ID`: 0) | medium | no (BP-9: one .deb, no floors) | `AITOOLS_DISTRO` / `AITOOLS_DISTRO_VERSION` from /etc/os-release | B5 | none | RevLib R6 + INC 5 | yes |
| RM-44 | A machine not in profile.json gets ERROR + ACTION "Run: aitools user init" on every run; there is no fleet outcome | aitools-profile.sh `resolve_machine` :631-765 (error :763); aitools-lib.sh `resolve_machine_profile` :362-368 | high | no in v1 (no dotprofile means shared-only, no ERROR); yes for a fleet user with a dotprofile on an unregistered machine or container | Explicit fleet mode: no match gives `owner=fleet`, rc 0, no identity from another person's profile | B5 | none (#115 only adds an ACTION for a missing resolver) | RevLib R7, section 6 | yes |
| RM-45 | In any run, non-interactive included, `sync_managed_json` auto-adopts live-only settings into profile.json with no prompt, outside `_managed_write`, with no commit | aitools-lib.sh `sync_managed_json` auto-adopt loop :2546-2558, write :2585; aitools-lib.ps1 `Sync-ManagedJson` :2520-2528 | high | no in v1 (setup-user-settings is a no-op without a dotprofile) | Disable auto-adopt in non-interactive and package runs; write through `_managed_write` | B5 | none | RevLib R8 + INC 3 | yes |
| RM-46 | Logging is not fail-safe: `mkdir` / `New-Item` unchecked, log appends unguarded, so under `set -e` an unwritable log dir aborts the script | aitools-lib.sh `logging_init` :662, `log` :686, `log_detail` :698; aitools-lib.ps1 :569, :593, :606 | medium | yes (system-phase `AITOOLS_LOG_DIR`, BP-16) | Fail-safe writes per logging.md section 5; check mkdir | B5 | none | RevLib R9 + INC 4 | yes |
| RM-47 | A dotprofile push from a non-main branch is not refused (commander, 2026-10-26: ERROR), and git's `safe.directory` refusal reads as "not a repo" | #103 `dotprofile_commit_push` / `Invoke-DotprofileCommitPush`; aitools-profile.sh `commit_profile` :959-1005; .ps1 `Invoke-ProfileCommit` :788-847 | medium | no (non-interactive runs cannot adopt) | ERROR on a non-main branch; detect the safe.directory refusal | B5 (after #103) | #103 partial (commit+push exists; added lines have no branch check); see draft incident #165 in PR #102 | RevLib R10 + INC 2; brief decision | yes (PR #103 diff scan) |
| RM-48 | `sync_managed_json` does not check three of its four mktemp calls, nor the backup result before apply | aitools-lib.sh :2450, :2648-2649 | low | no | Check each | B5 | none | RevLib R11 | yes |
| RM-49 | `Test-IsAdmin` has no caller | aitools-lib.ps1 :2664 | low | no | Use it in `Test-PrivilegedRun`, or remove it | B5 | none | RevLib R12; RevTools R3 | yes |
| RM-50 | deploy.jsonl is never rotated (only deploy.log is) | aitools-lib.sh `jsonl_record` :532 vs `_rotate_log` :663; aitools-lib.ps1 :458 vs :571 | low | no | Rotate deploy.jsonl too | B5 | none | RevLib R13 + INC 8 | yes |
| RM-51 | `backup_dir` counts only `*.md`, so a `.mdc` directory (`~/.cursor/rules`) is never directory-backed-up | aitools-lib.sh `backup_dir` :925-928 (caller setup-user-cursor.sh :517) | low | no | Count every regular file, or take a pattern | B5 | none | RevSetup R23 + INC | yes |
| RM-52 | `backup_dir` prunes without checking the result, and `deploy_tracker_record` records an unknown outcome silently | aitools-lib.sh :921-945, :2281-2297 | low | no | As in FanPlan-Lib INCIDENTs 2 and 8 | B5 | none | RevLib R15 (reused from FanPlan-Lib) | unverified (not re-read) |
| RM-53 | Only setup-user-claude.ps1 checks for PowerShell 7; the lib and the other seven setup-user-*.ps1 do not | setup-user-{config,cursor,hooks,mcp,settings,shell,skills}.ps1; aitools-lib.ps1 | low | no (launchers call pwsh by full path; Intune's own host is 32-bit Windows PowerShell, PkgWin section 2) | PS 7 guard in the lib | B5 | none | RevSetup R22; RevInstall section 4 | yes |

## 6. setup-user-* scripts and deployed hooks

| ID | Deficiency | Where (0ddd127) | Sev | Blocks pkg | Fix direction | Batch | PR | Source | Ver |
|---|---|---|---|---|---|---|---|---|---|
| RM-54 | The CLAUDE.md footer expands `$SHELL` under `set -u`, so with SHELL unset the script exits 1 with no claude.md summary row | setup-user-claude.sh :178 | high | yes (containers; launchd/Jamf environments unknown) | `${SHELL:-unknown}` | B6 (after FAN-PLAN, which owns the file) | none (#112 changes only the hostname source) | RevSetup R2 + INC (probe) | yes (code; probe is RevSetup's) |
| RM-55 | setup-user-shell writes `~/.bash_profile`, which on Ubuntu shadows `~/.profile` for login shells (the block does not source it) and never reaches macOS zsh users | setup-user-shell.sh :39-40 | high | yes (Ubuntu) | Source `~/.profile` first or write `~/.profile`; `~/.zprofile` on macOS; or machine-wide `/etc/profile.d` from the package | B6 | none | RevSetup R4 + INC | yes (code; bash(1) behaviour not tested here) |
| RM-56 | The user-level SessionStart/SessionEnd hooks run the session repo's own `scripts/ait-harvest.py` before the deployed copy, so any cloned repo can execute code outside Claude Code's trust prompt | shared/hooks/session-archive.sh :63-64; shared/hooks/session-catchup.sh :45-46 | critical (fleet security) | yes (fleet) | Run only `~/.claude/hooks/ait-harvest.py` or the configured aitools repoPath | B6 | none | RevSetup R5 + INC | yes |
| RM-57 | Fleet users get Jose's harness: all 18 hooks (standing-order-guard in enforce mode), his three MCP servers, every harness skill, and a template with nobul-jose links and literal `{{...}}` tokens | hooks-manifest.json; setup-user-mcp.sh :150-199; shared/claude-shared.md :29-30; shared/skills/aitool-continue/SKILL.md :120 | high | yes (fleet neutrality, BP-11) | `tier: fleet\|harness` and a neutral fleet template (P-3) | B6 (B1 P-3) | none | RevSetup R6, section 4.2, Q1; RevBuild R17; RevLib Q3 | yes |
| RM-58 | Cursor step 4 fans out every `~/.aitools/rules/*.md`, including the aitools repo's project rules, to every workspace | setup-user-cursor.sh step 4 :378-389 onward | high | yes | Fan out user-level sources only | --PR | #110 (on #100) | RevSetup R7 | yes (PR files and manifest hits) |
| RM-59 | Adopt targets point into the payload (hooks and skills adopt into the aitools tree), which is read-only in a package | setup-user-hooks.sh :166 (`$hook_src`) / .ps1 :132; setup-user-skills.sh :122-124, :218 / .ps1 :118 | medium | yes (BP-6 disables adopt) | Package mode passes `""` as adopt target | B6 (B3 flag) | none | RevSetup R8 | yes |
| RM-60 | Without a dotprofile, setup-user-settings syncs nothing and WARNs on every run; fleet users get no permissions or deny rules | setup-user-settings.sh :76-78 / .ps1 :62-64 | high | no (WARN only) | A fleet policy source (Claude Code managed settings: verify paths first, or an org profile); OK `n/a` in package mode | B6 (B1 P-3, P-6) | none | RevSetup R9, Q2 | yes |
| RM-61 | setup-user-hooks writes `~/.claude/settings.json` with no `backup_file` / `Backup-File` in either language | setup-user-hooks.sh :383 (`fs.writeFileSync`) / .ps1 :376 | medium | no | Back up before the write (config-file-safety.md) | B6 | none | RevSetup R10 + INC; existing incident #2 (says the .ps1 backs up; grep finds no `Backup-File`) | yes |
| RM-62 | setup-user-cursor logs "node not found" as a warning and writes no summary row | setup-user-cursor.sh :185-187 | medium | no | WARN row | B6 | none (#109 lists it as a follow-up); PR #102 draft incident #167 | RevSetup R11 + INC | yes |
| RM-63 | setup-user-mcp.ps1 exits 1 with no summary row when claude or node is missing (the .sh writes ERROR rows) | setup-user-mcp.ps1 :33-41 | medium | no | ERROR rows, as in .sh :49, :56 | B6 | none | RevSetup R13 + INC | yes |
| RM-64 | setup-user-mcp removes a server before adding it, so a failed add leaves it removed; chrome-devtools-mcp is unpinned (`@latest`) | setup-user-mcp.sh :128-139; .ps1 :88-118 | medium | no | Add, then replace, or restore on failure; pin a version for the fleet | B6 | none | RevSetup R14 | yes |
| RM-65 | The local chrome-devtools command omits `npx -y`, unlike the spec table | setup-user-mcp.sh :68; .ps1 :128 | low | no | Add `-y` | B6 | none | RevSetup INC; existing incident #66 | yes |
| RM-66 | Backups are taken on every run, even when nothing changes, so 20 recurring runs leave only no-op copies; the shell row is never `verified` | setup-user-shell.sh :68, :100-101, :117-119; setup-user-cursor.sh :179-181 / .ps1 :209-211 | medium | no (BP-13 needs it for recurring runs) | Compare first; back up and write only on change | B6 | none | RevSetup R16, section 4.3 + INC; BP-13 | yes |
| RM-67 | The Cursor model is forced back to Auto on every run, reverting the user's choice | setup-user-cursor.sh :263-274 / .ps1 :255-265 | medium | no | Manage it only when the profile sets it explicitly | B6 | none | RevSetup R17, Q3; BP-13 | yes |
| RM-68 | setup-user-shell has no dry-run handling, so it writes during `aitools --dry-run` | setup-user-shell.sh / .ps1 (grep `DRY_RUN`: 0) | low | no | Honour `AITOOLS_DRY_RUN` | B6 | none | RevSetup R18 + INC (cf. incident #89 for the tool scripts) | yes |
| RM-69 | setup-user-cursor runs `mkdir -p` during a dry run | setup-user-cursor.sh :183 | low | no | Guard it, as in .ps1 :214-219 | B6 | none | RevSetup R19 | yes |
| RM-70 | setup-user-config.ps1 uses `$HOME`; the other seven .ps1 use `$env:USERPROFILE` | setup-user-config.ps1 :113 | low | no | One lib variable | B6 | none | RevSetup R20 + INC | yes |
| RM-71 | setup-user-hooks reads config.json `userRepoPath` directly instead of the single resolver (SD-7) | setup-user-hooks.sh :70 / .ps1 :58 | low | no | `resolve_user_repo_path` / `Resolve-UserRepoPath` | B6 | none | RevSetup R21 + INC | yes |
| RM-72 | Two `.bak.*` files are tracked in shared/hooks, so they would enter a `git archive` payload | shared/hooks/standing-order-guard.sh.bak.2026-06-21T203334Z, harness-db-sessionstart.sh.bak.2026-06-21T203304Z | low | yes (BP-1 payload = tracked files) | `git rm`; `.gitignore` `*.bak.*`; B2 stage excludes `*.bak.*` | B2 | none | RevSetup R24 + INC | yes (`git ls-files`) |
| RM-73 | setup-user-skills deploys only SKILL.md, so supporting files never reach the user | setup-user-skills.sh :110-120 | low | no | Deploy the whole skill directory when skills gain files | B6 | none | RevSetup R30 | yes |
| RM-74 | Hook commands bake the absolute home path into settings.json | setup-user-hooks.sh :276 | low | no (RM-39: run as the user) | Covered by RM-39; `$HOME`-relative commands only if Claude Code expands them (unknown) | B6 | none | RevSetup R31 | yes |
| RM-75 | ripgrep is installed only through Homebrew, also on Linux (WARN on Ubuntu) | setup-user-cursor.sh :85-108 | medium | no | apt through the RM-41 helper, or a prerequisite; registry entry | B7 | none | RevSetup R12 + INC; existing incident #107 | yes |
| RM-76 | Wrong rows from setup-user-skills.ps1 on a resolver error (A-22) | setup-user-skills.ps1 :48-52 | low | no | -- | --PR | #109 | RevSetup R25 | yes (PR files) |
| RM-77 | Wrong setup-user-cursor rows on a resolver error (A-23) and wrong cli-config dry-run rows (A-26) | setup-user-cursor.sh/.ps1 | low | no | -- | --PR | #109 | RevSetup R26 | yes (PR files) |
| RM-78 | setup-user-claude carries a private commit+push block (the .ps1 commits without a pathspec) | setup-user-claude.sh :370-389 / .ps1 :400-422 | medium | no | -- | --PR | #103 | RevSetup R27 | yes (PR files) |
| RM-79 | Wrong hostname source and dry-run rows in setup-user-claude | setup-user-claude.sh :98-109, :216-238 / .ps1 :171-175, :230-254 | low | no | -- | --PR | #112 | RevSetup R28 | yes (PR files) |
| RM-80 | The hooks merge rewrites a user's own hook entry when its command contains a managed file name as a substring | setup-user-hooks.sh :306-337 (`h.command.includes(hookId)`) | low | no | Match the exact deployed path, not a substring | B6 | none | RevSetup section 3.4 item 5 | yes |

## 7. Tool setup scripts and the tool registry

| ID | Deficiency | Where (0ddd127) | Sev | Blocks pkg | Fix direction | Batch | PR | Source | Ver |
|---|---|---|---|---|---|---|---|---|---|
| RM-81 | No winget call passes `--scope`; setup-go and setup-typst also omit `--exact`; and the winget CLI is unsupported in the System context | setup-gh-cli.ps1 :29, :46; setup-go.ps1 :52, :103; setup-pandoc.ps1 :29, :58; setup-perl.ps1 :41; setup-rust.ps1 :44, :116; setup-typst.ps1 :60, :83; setup-uv.ps1 :26, :47; aitools-install.ps1 :550; aitools-install.sh :100; bootstrap.ps1 :26 | high | yes (Windows user phase, BP-14) | Render winget commands from the registry with `--scope user --exact --source winget`; never run them as SYSTEM | B7 (B1 schema) | none | RevTools R2, R17, section 4; RevLib section 3; MdmPkg F5, Q6; PkgWin section 2 + INC 4 | yes (grep `--scope`: only `claude mcp`) |
| RM-82 | The registry records no per-method scope or privilege, so machine vs user scope per winget id is unknown | registry schema (`/tool-registry`); decision tree section 6 | high | yes (BP-14 records scope per method) | Add `scope` and `requiresRoot` fields; settle each id with `winget show` in a `/tool-eval` trial | B1 | none | RevTools R1 + INC 1 | unverified (registry is skill-gated; not read) |
| RM-83 | `sudo` is called unconditionally in the apt paths, and non-interactively in cleanups, so a root container without sudo fails and a non-root run without NOPASSWD hangs or fails | setup-gh-cli.sh `add_github_cli_apt_repo` :48-52, :135; setup-pandoc.sh :153; setup-go.sh :104 (`sudo rm -rf`); setup-pandoc.sh :104 (`sudo port uninstall`) | high | yes (root container; Cursor-cloud-like user) | RM-41 `as_root`: direct as uid 0, `sudo -n` otherwise, PREREQ ERROR when neither works | B7 | none | RevTools R4, R12 + INC 4; RevInstall section 4 | yes |
| RM-84 | No Linux install method for uv, typst, go (fresh), pwsh or node, although the registry says `linux: supported`; python and modal fail in cascade; pandoc comes from the distro archive | setup-typst.sh (no OS branch after the guard :16); setup-uv.sh :7, :71-88; setup-go.sh :77-79; aitools-install.sh :633-637; registry `install.linux` | high | yes (Ubuntu user phase) | Linux methods via `/tool-adopt` (M2, issue #14); until then EVALUATING / NO-METHOD rows; no distro versions of managed tools | B7 | none | RevTools R5, R8, R9, section 3 gaps 1, 4, 6 + INC 2; RevInstall section 6; PkgLinux section 2; existing incidents #54, #57 (planned) | yes (scripts); registry side unverified |
| RM-85 | The registry's datadog Linux method is Homebrew while the script uses a cargo fallback; `platformStatus.windows` holds a value outside the enum | registry `datadog-pup`; setup-datadog.sh :6, :126-156 | medium | no | Choose one via `/tool-eval`; drop the fallback (T-Q4) | B7 | none | RevTools R6, R18 + INC 5 | yes (script); registry side unverified |
| RM-86 | modal falls back to `pip install --user` (T-Q4 says no fallbacks) | setup-modal.sh :129-145 / .ps1 :150-189 | medium | no | Remove it; PREREQ ERROR when uv is absent | B7 | none | RevTools R7 | yes |
| RM-87 | setup-cursor-ide-mcp parity: the .sh runs `agent mcp remove` (WARN on failure), the .ps1 runs `agent mcp disable` (ERROR), and both headers still say "disable" | setup-cursor-ide-mcp.sh :9, :190-209; .ps1 :8, :169-178 | medium | no | Make the .ps1 match the .sh | B7 | none | RevTools R10 + INC 3 (cf. incident #4) | yes |
| RM-88 | setup-cursor-ide-mcp exits 1 with no summary row when node is missing (both languages) | setup-cursor-ide-mcp.sh :51-53; .ps1 :37-39 | low | no | ERROR row | B7 | none | RevTools R11 + INC 6 | yes |
| RM-89 | setup-gh-cli installs wget before any `apt-get update`, so it can fail on a fresh container's empty lists | setup-gh-cli.sh :48 | low | no | Update first (setup-google-chrome `apt_install` pattern) | B7 | none | RevTools R13 | yes |
| RM-90 | On Linux, perl and bash are only verified; the T-Q5 update is not implemented | setup-perl.sh :87-106; setup-bash.sh :106-126 | low | no (BP-8 Depends: bash, perl) | Record as `system` kind with .deb Depends | B7 | none | RevTools R15 | yes |
| RM-91 | PowerShell 7.7+ ships no MSI (MSIX only, per user), which neither the brief nor the registry records; nothing installs pwsh on macOS or Linux | registry powershell entry; aitools-install.sh :96-116 (Windows forwarding only) | medium | yes (Windows System prerequisite app) | 7.6 LTS MSI dependency app now; plan a ZIP install before 7.6 end of support; record in the registry | B9 (B1) | none | PkgWin section 2 + INC 3; RevTools R9 | unverified (registry not read; upstream fact from PkgWin via chrome-devtools) |
| RM-92 | In Claude Code web, `GH_TOKEN` is `proxy-injected` and the proxy refuses GraphQL, so a gh auth check misreports there | setup-gh-cli / installer Step 2 auth check | medium | no | Environment-aware auth check, or skip it in `claude-code-web` | B7 | none | PkgLinux section 5 + INC 1 | unverified (behaviour from the Claude Code docs, not run) |

## 8. Docs and specs

DocsWriter owns the doc edits (`doc-edits-pending.md`). Rows marked "applied, uncommitted"
already have a working-tree change from a parallel writer (`git status`, 2026-10-26); I
did not review that content. Row numbers are DocsInv section 1.

| ID | Deficiency | Where (0ddd127) | Sev | Blocks pkg | Fix direction | Batch | PR | Source | Ver |
|---|---|---|---|---|---|---|---|---|---|
| RM-93 | README describes two platforms and two paths | README.md tagline, "How it works" (rows 1-3) | medium | no | Five-item list plus the package path; "Install from a package" once packages exist | B0 (applied, uncommitted) | none | DocsInv rows 1-3 | yes (working tree) |
| RM-94 | CLAUDE.md says "both machines (Windows 11, macOS)", and its Intent names one user | CLAUDE.md "What aitools is" (row 4) | medium | no | Body: point to the supported list. Intent: `/intent-writing` draft for the commander | B0 (draft; protected) | none | DocsInv row 4, Q4 | yes |
| RM-95 | The fleet template's Cross-Platform section is Jose-personal and two-platform | shared/claude-shared.md :34 and the Managed/Per-Platform tool rows (rows 5-7) | medium | yes (fleet template, BP-11) | Five-item form citing `~/.aitools/rules/cross-platform.md` | B13 (#105) | none | DocsInv rows 5-7 | yes (:34) |
| RM-96 | The Cursor user-rules template has the same two-platform line | shared/cursor-rules/user-rules.md (row 8) | medium | no | Same text as RM-95 | B0 (applied, uncommitted) | none | DocsInv row 8 | yes (working tree) |
| RM-97 | cross-platform.md says "both machines", has a closed environment list, lacks the two exemption rows (P-1), and at 200 lines is past the 40-100 line guideline | .claude/rules/cross-platform.md (rows 9-11) | medium | yes (P-1 rows for build-package.sh and package launchers) | Apply drafts after #99; move "Hook portability" to the reference | B13 (#99) | none | DocsInv rows 9-11 + INC 1; Lang section 1 | yes (`wc -l` = 200) |
| RM-98 | deploy-paths.md/.mdc describe two paths; the .mdc twin has drifted ("Four script pairs", "steps 3+10") | .claude/rules/deploy-paths.md; .cursor/rules/deploy-paths.mdc :24, :32 (rows 12-13) | medium | yes (equivalence claim for the third path) | Third-path section and equivalence (DocsInv section 3a) | B13 (#99) | #99 partial (removes "Four script pairs"; "steps 3+10" stays) | DocsInv rows 12-13, section 3a + INC 3 | yes |
| RM-99 | cross-platform.mdc targets two platforms and lists two environment values | .cursor/rules/cross-platform.mdc (rows 14-15) | medium | no | Point to the supported list; three values | B0 (applied, uncommitted) | none | DocsInv rows 14-15 | yes (working tree) |
| RM-100 | No single authoritative supported-platforms location; the detail doc's environment API is closed | reference/cross-platform-detail.md "Environment detection", "API" (row 18) | medium | yes (BP-18) | New "Supported platforms and environments" section (BP-18 host); environment changes after B5 | B0 (applied, uncommitted) | none | DocsInv section 2, row 18; BP-18 | yes (working tree) |
| RM-101 | Tool-evaluation criteria and playbook name two platforms | reference/tool-evaluation-criteria.md; reference/tool-evaluation-playbook.md (rows 19-20) | medium | no | Supported list; check Ubuntu, Claude Code web, Cursor cloud | B0 (criteria applied, uncommitted; playbook pending) | none | DocsInv rows 19-20 | yes (working tree) |
| RM-102 | The decision tree lists only `local` or `claude-code-web` and treats dnf as in scope | reference/tool-support-decision-tree.md :38 (row 21) | medium | no | Three values; dnf schema-only | B13 (#101/#106) | none | DocsInv row 21 | yes (:38) |
| RM-103 | ROADMAP has no build-package row and keeps dnf in scope | ROADMAP.md (row 22) | low | no | New In Progress row; dnf deferred | B0 (applied, uncommitted) | none | DocsInv row 22 | yes (working tree) |
| RM-104 | harness.md, aitools-workspace.md and tool-lifecycle.mdc name two platforms and omit Cursor cloud and the package path | reference/harness.md; .claude/rules/aitools-workspace.md; .cursor/rules/tool-lifecycle.mdc (rows 16, 17, 23) | low | no | Wording per DocsInv | B0 (harness.md and aitools-workspace.md applied, uncommitted; .mdc pending) | none | DocsInv rows 16, 17, 23 | yes (working tree) |
| RM-105 | Three docs say "Fallback: hostname match, then first profile"; the resolver errors after hostname | .claude/rules/managed-file-deployment.md :51; reference/user-repo.md :84; reference/managed-file-deployment.md :393 | low | no | Remove "then first profile"; update incident #76 | B13 (#101/#106 own these files) | none (#101's added text still says "then the first profile") | RevLib R14 + INC 6; existing incident #76 | yes |
| RM-106 | logging.md has no location for the launchers' root/SYSTEM phase | reference/logging.md section 1 | low | yes (spec for B8-B10 launcher logs) | One sentence: `/Library/Logs/aitools`, `C:\ProgramData\aitools\logs`, `/var/log/aitools` | B13 (#101) | none | RevLib section 5, Q4; BP-16 | yes |
| RM-107 | tool-ops-claude-code.md says nothing about cloud setup scripts, snapshot caching, the GitHub proxy's GraphQL refusal, or `GH_TOKEN=proxy-injected` | reference/tool-ops-claude-code.md "Session Behavior" | medium | no | Add the facts via `/tool-ops` (protected) | B0 (draft) | none | PkgLinux INC 1 | yes (grep `proxy-injected\|GraphQL`: 0) |
| RM-108 | The logging-overrides table omits build-deploy's `blog_warn` | reference/script-standards-detail.md :163 | low | no | Add `blog_warn` | B13 (#101) | none | Lang section 3 note | yes |
| RM-109 | "package" now means two things (package-manager package, aitools package), and the package path has no governed terms | registries/glossary.json (via `/glossary`) | low | no | `/glossary`: aitools package, package path, deployment path, fleet user, console user; amend platform and environment | B13 (#101 owns glossary.json) | none | DocsInv section 4 + INC 4 | yes (draft list) |

## 9. Governance gaps (no spec, or a spec that does not fit the package path)

| ID | Deficiency | Where | Sev | Blocks pkg | Fix direction | Batch | PR | Source | Ver |
|---|---|---|---|---|---|---|---|---|---|
| RM-110 | No spec says which run context (user, root, SYSTEM) each script needs, or what a script does in the wrong one | script-standards.md, decision tree, registry schema (none cover it) | high | yes | A run-context section in script-standards.md (or the decision tree) that states BP-10; record each script's run context in the registry or decision tree | B1 (B5 code) | none | MdmPkg INC 7; RevSetup INC; RevTools INC 1; RevInstall INC 8; RevLib INC 1 | yes (grep: no spec) |
| RM-111 | No lifecycle class for build-host-only tools (IntuneWinAppUtil, pkgbuild/productbuild, dpkg-deb): Phases 3-5 and the onboarding checklist assume endpoint integration | .claude/rules/tool-lifecycle.md; reference/tool-evaluation-criteria.md Phases 3-5; decision tree section 6 | medium | yes (B9 needs IntuneWinAppUtil through Phase 2) | "Build-host tool" class: registry entry, `/tool-eval`, Phase 2 gate, then a build-host acquisition step (P-4) | B1 | none | Lang section 4 INC; PkgWin Q5 | yes (grep `build-host` in tool-lifecycle.md: 0) |
| RM-112 | No spec for MDM argument conventions: `$3` is the username in a Jamf script object but the target volume in a pkg script | none | medium | yes (B8 runner) | State it in the B8 launcher header and the design; never read `$3` as the user | B8 | none | PkgMac INC 2 | unverified (searched rules/reference for Jamf only) |
| RM-113 | Claude Code web setup scripts must exit 0 ("append `\|\| true`"), which conflicts with the USO "no silent failures"; no rule covers cloud setup snippets | cloud setup snippets (B10) | low | yes (B10 snippets) | Each non-critical step logs its failure before continuing; one rule line | B10 | none | PkgLinux INC 3 | unverified (no rule search beyond the rules in context) |
| RM-114 | No framework governs the package path (release engineering / software distribution); deploy-paths.md is no framework's artifact | framework registry (`/frameworks`) | low | no | `/frameworks` entry | B1 | none | DocsInv INC 2 | unverified (registry skill-gated) |
| RM-115 | No exit-code or status-marker policy for MDM detection: exit 1 covers any ERROR row, there is no "partial" code, and Intune macOS reports a pkg postinstall as success regardless | installer exit footers (aitools-install.sh :875-884) | medium | yes | Launcher exit policy plus version markers (BP-15); copy the run summary to a collectable log | B8 (B9, B10) | none | RevInstall section 3.3, Q4; MdmPkg A' risks; PkgMac section 3 | unverified (design gap; footer read by RevInstall) |
| RM-116 | pkgbuild archives AppleDouble `._*` entries generated from `com.apple.provenance` xattrs; `xattr -cr`, `COPYFILE_DISABLE=1` and `--filter` do not remove them | build host (agent session on macOS 27) | medium | yes (B8) | Build from a clean CI checkout; try `ditto --norsrc --noextattr` (untested); gate `pkgutil --payload-files \| grep -c '/\._'` = 0 | B8 (B2 hygiene) | none | PkgMac section 1 + INC 1 | unverified (PkgMac test build, not re-run) |

## 10. INCIDENT candidates

Not filed. The orchestrator triages them via `/incident`. Every candidate shares this
discoveryContext: "S3-BuildPkg remediation consolidation, 2026-10-26; re-checked at main
0ddd127; sources and audit list in plans/build-package/remediation.md section 1". Field
rules: `.claude/rules/incident-governance.md` "Required fields" (affected, suggestedResolution
and the rest are in the RM row named).

### 10a. Already filed or drafted: update, do not file again

| Candidate | Existing | Action |
|---|---|---|
| RM-61 hooks settings.json written without backup | #2 (open, medium) says the .ps1 twins back up | Update #2: setup-user-hooks.ps1 :376 has no `Backup-File` either (grep 0) |
| RM-62 cursor "node not found" without a row | PR #102 draft #167 | No new filing; #102 carries it |
| RM-47 non-main branch push not refused | PR #102 draft #165 (bare `git push` pushes the current branch) | Add the 2026-10-26 commander decision (ERROR) to #165's expected field |
| RM-65 chrome-devtools without `npx -y` | #66 (open) | None |
| RM-35 node@22 keg-only | #91 (open) | Add the Linux (WARN only) and Windows (no `--scope`) halves |
| RM-84 Linux methods missing, registry claims support | #54, #57 (planned) | Add pwsh and node to #57's scope |
| RM-105 "then first profile" | #76 (open) | Update: the code now errors after hostname (aitools-profile.sh :763); only the three docs are left |
| RM-75 ripgrep via Homebrew | #107 (open) | Add the Linux consequence |
| RM-1 identity embedded in deploy/ | #78 (open, per-machine values baked) | File separately (fleet identity, critical) or widen #78; suggested: separate, cross-linked |

### 10b. New candidates

**IC-1 (critical, governance gap): No spec or helper for running as root/SYSTEM on behalf of a console user** (RM-39, RM-110)
- Observation: grep `/dev/console|SUDO_USER|ConsoleUser` over scripts/ and shared/hooks returns nothing. Every path derives from the process HOME (aitools-lib.sh :72; deploy-harness.sh :79; deploy-harness.ps1 :78). `Test-IsAdmin` (aitools-lib.ps1 :2664) has no caller. User-PATH writes go to the runner's HKCU (aitools-lib.ps1 :2794, :2907).
- Expected: No spec exists for: the run context each script needs and what it does in the wrong one.
- Impact: every package kind (pkg postinstall as root, Intune System, dpkg postinst) deploys into root's or SYSTEM's profile, or leaves root-owned files in the user's home that break Claude Code and the next dev-path run.

**IC-2 (critical, security for a fleet): User-level session hooks execute the session repo's `scripts/ait-harvest.py`** (RM-56)
- Observation: shared/hooks/session-archive.sh :63-64 and session-catchup.sh :45-46 pick `$PROJECT_ROOT/scripts/ait-harvest.py` before `~/.claude/hooks/ait-harvest.py`.
- Expected: No spec exists for: which code a deployed user-level hook may execute.
- Impact: for a fleet user, any cloned repository containing that path runs its code on every SessionStart and SessionEnd, outside Claude Code's project-trust prompt.

**IC-3 (critical): build-deploy.sh embeds one person's identity as the fallback for every endpoint without a dotprofile** (RM-1)
- Observation: build-deploy.sh embeds the dotprofile profile.json snapshot (:516, :564; github, email, three hostnames for aitools-nobul-jose), the CLAUDE.md template and the rules. It selects the embedded snapshot when no live dotprofile exists (:669-670). Nothing marks a deploy/ as single-user.
- Expected: deploy-paths.md "MDM path ... personalized" (one user). For a fleet: no spec exists for distributing personal content.
- Impact: a fleet package built from deploy/ would apply Jose's identity, email and rules to every user.

**IC-4 (high): The dev deploy-harness cannot run outside a git work tree** (RM-2)
- Observation: deploy-harness.sh `add_source` :181-186 logs ERROR and writes "not a git checkout" for any source outside a work tree; only the bin CLIs (:266) are ungated.
- Expected: BP-2 (the package path runs the dev-path scripts from the payload).
- Impact: a package that ships scripts/ as is gets one ERROR per source and exit 1 on first run.

**IC-5 (high): An unknown installer option exits 0** (RM-20)
- Observation: aitools-install.sh :49 sets SHOW_HELP for any unknown option; :76 exits 0.
- Expected: script-standards.md "Exit footer" (exit 1 on errors).
- Impact: a mistyped flag in an MDM install command reports success while installing nothing.

**IC-6 (high): bootstrap.ps1 runs the installer under Windows PowerShell 5.1** (RM-32)
- Observation: bootstrap.ps1 :48 `& powershell ... aitools-install.ps1`; pwsh is never installed; the exit code is not checked.
- Expected: cross-platform.md "PowerShell 7 baseline".
- Impact: the documented Windows bootstrap fails or misbehaves on a fresh machine (the lib uses PS 6+ syntax; setup-user-claude.ps1 refuses below 7).

**IC-7 (high): setup-user-claude.sh crashes when SHELL is unset** (RM-54)
- Observation: setup-user-claude.sh :178 `$(basename "$SHELL")` under `set -u`; RevSetup's probe: "SHELL: unbound variable", exit 1.
- Expected: script-standards.md "End-of-run summary" (every code path writes a row).
- Impact: containers and agents without SHELL get no CLAUDE.md and no summary row.

**IC-8 (high on Ubuntu): setup-user-shell creates ~/.bash_profile, which shadows ~/.profile** (RM-55)
- Observation: setup-user-shell.sh :39-40 always targets `.bash_profile`; the block does not source `~/.profile`.
- Expected: cross-platform.md (Linux first-class); bash(1) INVOCATION order.
- Impact: Ubuntu login shells stop reading `~/.profile` (and so `.bashrc`); macOS zsh users never get the block.

**IC-9 (high, ambiguity): sync_managed_json writes profile.json without review in non-interactive runs** (RM-45)
- Observation: aitools-lib.sh :2546-2558 auto-adopts every live-only key and permission rule into the mirror and writes it from node (:2585), not through `_managed_write`, with no commit.
- Expected: agentic-standards.md "a field only in LOCAL is never written to SOURCE without a review" (the profile-mirror exception does not say whether it applies to unattended runs).
- Impact: an MDM or package run can rewrite a user's dotprofile profile.json, possibly as root.

**IC-10 (high): winget is called with no scope, and the winget CLI is unsupported as SYSTEM** (RM-81, RM-82)
- Observation: no `--scope` on any winget call (grep); the registry has no scope field. Microsoft: "the WinGet CLI is not supported in the system context" (PkgWin [winget-ts], read 2026-10-26).
- Expected: tool-evaluation.md principle 6 (automation and deployment); BP-14.
- Impact: Windows installs land per-user or per-machine depending on each manifest, and fail under an Intune System installer.

**IC-11 (medium, ambiguity): user init creates and pushes a GitHub repo by default without a terminal** (RM-23)
- Observation: scripts/aitools :811 `ans="y"`, then `gh repo create --private --push` (:862-864); aitools.ps1 :1471.
- Expected: No spec exists for: non-interactive defaults outside the review menus (interactive-menus.md covers only the menus).
- Impact: an unattended run creates a GitHub repository under the signed-in account.

**IC-12 (medium): The PowerShell version stamp never matches** (RM-22)
- Observation: aitools.ps1 :2032, :2197, :2207 use `-replace '^...'` on `-Raw` content without `(?m)`.
- Expected: parity with the bash stamp (scripts/aitools :2245), cross-platform.md pairs.
- Impact: the installed version on Windows is always "dev", so it cannot serve as a detection or update marker (BP-12).

**IC-13 (medium): Logging is not fail-safe** (RM-46)
- Observation: aitools-lib.sh :662 unchecked `mkdir -p`, :686 and :698 unguarded appends; aitools-lib.ps1 :569, :593, :606.
- Expected: reference/logging.md section 5 (a failed log write is swallowed).
- Impact: under `set -e`, an unwritable log directory (a relocated `AITOOLS_LOG_DIR` in a system phase) aborts the script.

**IC-14 (medium): The closed environment list excludes a supported environment** (RM-42)
- Observation: aitools-lib.sh :41-52 accepts only `claude-code-web|local`; cross-platform-detail.md "API" calls the list closed.
- Expected: the commander's 2026-10-26 decision (Cursor cloud supported).
- Impact: Cursor cloud runs as `local` (for example, chrome-devtools MCP runs headed with no display, setup-user-mcp.sh :63-69).

**IC-15 (medium): The library helpers that D-ENV0 names do not exist** (RM-41)
- Observation: grep `install_via_brew|install_via_apt|as_root` over scripts/: 0.
- Expected: cross-platform.md "One script per tool (D-ENV0)".
- Impact: privilege handling is reimplemented inline per script (unconditional sudo, RM-83).

**IC-16 (medium): Unconditional sudo in apt paths** (RM-83)
- Observation: setup-gh-cli.sh :48-52, :135; setup-pandoc.sh :153; setup-go.sh :104.
- Expected: script-standards.md "External command error handling" (prerequisite failures are reported, not undefined).
- Impact: a root container without sudo fails; a non-interactive non-root run hangs or fails.

**IC-17 (medium): setup-cursor-ide-mcp .sh and .ps1 disagree** (RM-87)
- Observation: .sh :198 `agent mcp remove` (WARN), .ps1 :171 `agent mcp disable` (ERROR); both headers say "disable".
- Expected: cross-platform.md "Cross-platform parity".
- Impact: Windows reports ERROR for a subcommand Cursor dropped.

**IC-18 (medium): setup-user-mcp.ps1 exits without summary rows** (RM-63)
- Observation: setup-user-mcp.ps1 :33-41 `LogError` + `exit 1`; the .sh writes ERROR rows.
- Expected: script-standards.md "End-of-run summary"; parity.
- Impact: the MCP failure disappears from the Windows panel.

**IC-19 (medium): Backups on every run consume the retention window** (RM-66)
- Observation: setup-user-shell.sh :68 and setup-user-cursor.sh :180 back up before comparing.
- Expected: config-file-safety.md "Retention" and "Diff logging on overwrite" (identical: skip the write).
- Impact: after 20 recurring MDM runs, only no-op copies remain.

**IC-20 (medium): build-deploy.sh exits 0 on every skip** (RM-8)
- Observation: :86-89 (node), :203-217, :2279 (pwsh optional).
- Expected: script-standards.md "Exit footer".
- Impact: CI cannot tell a skipped build from a build without inspecting output.

**IC-21 (medium): Generated output carries no version** (RM-10). Observation: grep `BUILD-INFO|rev-parse HEAD` in build-deploy.sh: 0. Expected: no spec exists for: build provenance of generated scripts. Impact: an endpoint cannot report what it runs; updates cannot be detected.

**IC-22 (medium): No build-host tool class** (RM-111). Observation: tool-lifecycle.md Phases 3-5 and the onboarding checklist require a setup script, an installer step and a build-deploy copy block. Expected: No spec exists for: tools only a build host needs. Impact: IntuneWinAppUtil cannot pass the lifecycle without wrong endpoint integration.

**IC-23 (medium): No spec for MDM argument conventions** (RM-112). Observation: `$3` is the username in Jamf scripts and the target volume in pkg scripts (PkgMac section 2). Expected: No spec exists for: MDM script arguments. Impact: a runner reused across channels can treat `/` as a username.

**IC-24 (medium): tool-ops-claude-code.md lacks cloud-environment facts** (RM-107). Observation: grep `proxy-injected|GraphQL`: 0. Expected: tool-ops.md (check the ops reference before assuming behaviour). Impact: a gh auth check in Claude Code web misreports.

**IC-25 (medium): PowerShell 7.7+ has no machine-wide MSI and nothing records it** (RM-91). Observation: PkgWin [pwsh-win] (read 2026-10-26): "Beginning with the PowerShell 7.7.0 release, there is no MSI package available." Expected: tool-evaluation.md principle 6. Impact: no System-context pwsh after 7.6, which the Windows package path needs.

**IC-26 (medium): AppleDouble entries in built pkgs** (RM-116). Observation: PkgMac test builds list `._*` entries for every payload file (`pkgutil --payload-files`). Expected: No spec exists for: payload hygiene. Impact: unknown at install time; stray `._*` files may land on endpoints.

**IC-27 (medium): check-post-push step 7 rebuilds the real dotprofile deploy/** (RM-18). Observation: check-post-push.sh :204 `bash build-deploy.sh` with the real HOME. Expected: mission packet section 5 (never run build-deploy against the real HOME) and the isolated-HOME pattern of pre-push step 7. Impact: running the check rewrites the real dotprofile deploy/. Check #86 first.

**IC-28 (medium): cross-platform.md exceeds the rule size guideline** (RM-97). Observation: 200 lines (`wc -l`). Expected: documentation-standards.md "Layered reference architecture" (~40-100). Impact: context cost; new sections make it worse.

**IC-29 (low): deploy-harness.ps1 trusts a stale $LASTEXITCODE when git is missing** (RM-7). Observation: .ps1 :163-164. Expected: script-standards.md "Error handling requirements". Impact: a misleading empty error instead of "git not found".

**IC-30 (low): Uncommented error suppression in build-deploy.sh** (RM-16, RM-17). Observation: :2288 `2>/dev/null || true`, :2239 `2>/dev/null`. Expected: script-standards.md "Error handling requirements". Impact: a failed chmod or a hidden parse message goes unnoticed.

**IC-31 (low): "skipping (MDM deploy)" branches write no summary rows** (RM-24). Observation: 17 bash / 18 PS branches log_warn only. Expected: script-standards.md "End-of-run summary". Impact: missing tools vanish from the panel.

**IC-32 (low): The entry points use different interactive tests** (RM-31). Observation: bootstrap.sh :92, bootstrap.ps1 :59, scripts/aitools :100. Expected: interactive-menus.md installer rule. Impact: an entry point prompts, or fails to, inconsistently.

**IC-33 (low): setup-user-shell ignores dry run** (RM-68). Observation: grep `DRY_RUN` in setup-user-shell.*: 0. Expected: every other setup-user-* honours `AITOOLS_DRY_RUN`. Impact: `aitools --dry-run` writes the shell profile.

**IC-34 (low): backup_dir counts only `*.md`** (RM-51). Observation: aitools-lib.sh :925-928. Expected: config-file-safety.md "Directory deployment" step 2. Impact: `~/.cursor/rules` is never directory-backed-up.

**IC-35 (low): Tracked backup files in shared/hooks** (RM-72). Observation: `git ls-files 'shared/hooks/*.bak.*'` lists two files. Expected: backups are local artifacts. Impact: they reach git and any `git archive` payload.

**IC-36 (low): setup-user-hooks bypasses the single resolver** (RM-71). Observation: setup-user-hooks.sh :70 / .ps1 :58 read `userRepoPath` directly. Expected: SD-7. Impact: the hooks dotprofile can differ from the other scripts'.

**IC-37 (low): setup-user-config.ps1 uses $HOME** (RM-70). Observation: .ps1 :113. Expected: the other seven .ps1 use `$env:USERPROFILE`. Impact: a wrapper that overrides USERPROFILE splits config.json from the rest.

**IC-38 (low): deploy.jsonl is never rotated** (RM-50). Observation: only deploy.log goes through `_rotate_log` (:663). Expected: logging.md section 4 (5 MB x 5). Impact: unbounded growth.

**IC-39 (low, ambiguity): Cloud setup scripts versus "no silent failures"** (RM-113). Observation: Claude Code web requires exit 0 (PkgLinux section 5). Expected: USO "No silent failures in reusable code". Impact: the B10 snippets need a recorded rule.

**IC-40 (low, governance): No framework for the package path** (RM-114). Observation: per DocsInv, the "Managed file deployment" framework lists no deploy-paths.md artifact. Expected: frameworks.md (check before assuming). Impact: package-path decisions have no governing discipline.

S3-MdmPkg section 8 markers still open (section 10c):

**IC-41 (high): The library is embedded twice in three generated scripts** (RM-11). Observation: build-deploy.sh :436-437 put aitools-lib.* into `RESOLVER_SH_FILES` / `RESOLVER_PS1_FILES`, so setup-user-claude, -cursor and -settings carry the lib in the resolver block as well; 27 copies per platform. Expected: No spec exists for: per-channel script size. Impact: 7 generated .ps1 files exceed Intune's 200 KB script limit, so the MDM script channel cannot carry them.

**IC-42 (medium): No size gate for generated scripts except deploy-harness, and only with #111** (RM-13). Observation: grep `200000` in build-deploy.sh on main: 0. Expected: No spec exists for: size gates per delivery channel. Impact: a build that is too large for its channel passes silently.

**IC-43 (medium): deploy/ lacks its prerequisites, so the deploy-paths.md equivalence claim fails on a clean endpoint** (MdmPkg INC 6; RM-3, RM-35). Observation: no pwsh 7, node, Claude Code CLI or Homebrew install in deploy/, and no config.json bootstrap keys (MdmPkg F4). Expected: deploy-paths.md "Two deployment methods must produce equivalent results". Impact: the MDM path fails on a fresh machine. The package path avoids this through BP-8 prerequisite packages; the MDM path stays as is (BP-2).

**IC-44 (medium): The step-order lists still disagree after #106** (MdmPkg INC 5; RM-4). Observation: Step 21 `DEPLOY_SCRIPTS` (aitools-install.sh :835) puts cursor second and has no deploy-harness; #106's sync lists put deploy-harness first and cursor sixth. Expected: deploy-paths.md equivalence. Impact: `aitools install` and `aitools` deploy in different orders; only the sync order satisfies setup-user-cursor's dependency on `~/.aitools/rules`.

**IC-45 (low): The committed dotprofile deploy/ is stale** (MdmPkg INC 1). Observation: 42 files at 825aed4 blobs vs 50 from a main build, with no deploy-harness or resolver. Expected: deploy-paths.md "When changing scripts/" step 2 (rebuild deploy/). Impact: anything taken from the committed deploy/ ships old scripts. The fix belongs to the dotprofile repo (section 11).

Route to `/glossary`, not `/incident`: RM-109 ("package" has two meanings).

### 10c. S3-MdmPkg report section 8 markers: status at 0ddd127

| MdmPkg marker | Status | Where now |
|---|---|---|
| Committed dotprofile deploy/ stale (42 vs 50 files) | open; dotprofile repo | IC-45; fix in section 11 |
| No size gate except deploy-harness, and only with #111 | open; #111 partial | RM-13, IC-42 |
| Library embedded twice | open (MDM path) | RM-11, IC-41 |
| BUILD_TMP trap leak | fixed by #111 (unmerged); nothing to file | RM-14 |
| Order lists disagree; neither runs deploy-harness | #106 fixes the sync side and adds Step 8b; Step 21 still differs | RM-4, RM-5, IC-44 |
| deploy/ lacks prerequisites and bootstrap keys | open; the package path solves it by BP-8 prerequisite packages and RM-3 | IC-43 (RM-3, RM-35, RM-91); the MDM path stays as is (BP-2) |
| No run-context spec; no console-user resolution | open | IC-1 (RM-39, RM-110) |
| Old Intune URLs (`/intune/intune-service/...`) | no harness file cites them (grep of reference/, .claude/, plans/, shared/ hits only worktree scratch session files) | Not remediated here |

## 11. Not remediated here (out of scope)

| Item | Why not here | Owner / where |
|---|---|---|
| Intune supersedence page says both 10 and 11 nodes; IME check-in "every hour" vs "every 8 hours" | Upstream Microsoft doc inconsistencies (PkgWin INC 1, 2); plan for 10 nodes and about 24 h | design.md assumptions |
| Apple's installer-script argument table exists only in a retired 2010 document | Upstream (PkgMac INC 3); B12 VM test confirms `$1..$4` | B12 test matrix |
| Old Intune URL paths | Upstream redirects; no harness file cites them (section 10c) | none |
| Committed dotprofile deploy/ is stale | Dotprofile repo, MDM path (BP-2 keeps it as is) | Session Commander |
| setup-user-claude.sh :360-366 no `*)` branch; .ps1 `Get-ChildItem -ErrorAction Stop` without try | The file belongs to FAN-PLAN (brief) | S3-FanPlan-Claude-findings section 8 items 4-5 |
| Jose's personal "I work on both Windows 11 and macOS" line in the dotprofile template | Commander's choice (P-7) | Commander |
| CLAUDE.md Intent (one user) | Intent change; `/intent-writing`, commander approval | Commander (RM-94 body only) |
| FanPlan's INCIDENT that #106's abort contradicts a decision | Settled: the commander kept #106's behaviour (2026-10-26) | none |
| Signing and notarization | Not a defect; optional B14 | B14 |
| Graph API upload automation for .intunewin | Research follow-up (PkgWin Q4) | follow-up research |
| Unofficial packagers (svrooij/ContentPrep, bomutils, apepkg, fpm) and nfpm | Not adopted (PkgWin, PkgMac, PkgLinux, Lang); no remediation | none |
| Install-time unknowns: Gatekeeper on agent installs, Intune detection outside /Applications, HKCU detection run as the user, release-asset 403 in Claude Code web, Cursor cloud's default user | Test items, not code defects | B12 test matrix |
| Tool scripts ignore `AITOOLS_DRY_RUN` | Already incident #89; not package-specific | #89 |

## 12. Summary counts

**By severity** (116 items):

| Severity | Count | Items |
|---|---|---|
| critical | 3 | RM-1, RM-39, RM-56 |
| high | 24 | RM-2, 3, 5, 8, 11, 20, 21, 23, 32, 35, 40, 41, 44, 45, 54, 55, 57, 58, 60, 81, 82, 83, 84, 110 |
| medium | 46 | RM-4, 9, 10, 12, 13, 15, 18, 22, 26, 28, 33, 36, 37, 42, 43, 46, 47, 59, 61, 62, 63, 64, 66, 67, 75, 78, 85, 86, 87, 91, 92, 93-102, 107, 111, 112, 115, 116 |
| low | 43 | RM-6, 7, 14, 16, 17, 19, 24, 25, 27, 29, 30, 31, 34, 38, 48-53, 65, 68-74, 76, 77, 79, 80, 88, 89, 90, 103, 104, 105, 106, 108, 109, 113, 114 |

**By area:** build/deploy 19, installers 19, library 15, setup-user-* and hooks 27, tool
scripts 12, docs 17, governance 7.

**Blocks the package path:** 37 items marked yes (build/deploy 4, installers 6, library 4,
setup-user-* 7, tool scripts 5, docs 5, governance 6). RM-44 blocks only a fleet user who
has a dotprofile on an unregistered machine; RM-19 is unknown until measured.

**By batch** (primary batch):

| Batch | Count | Items |
|---|---|---|
| B0 | 9 | RM-93, 94, 96, 99, 100, 101, 103, 104, 107 |
| B1 | 4 | RM-82, 110, 111, 114 |
| B2 | 2 | RM-10, 72 |
| B3 | 13 | RM-3, 4, 6, 20, 21, 22, 23, 24, 25, 27, 28, 29, 30 |
| B4 | 2 | RM-2, 7 |
| B5 | 16 | RM-26, 39-53 |
| B6 | 20 | RM-54, 55, 56, 57, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 73, 74, 80 |
| B7 | 12 | RM-35, 75, 81, 83, 84, 85, 86, 87, 88, 89, 90, 92 |
| B8 | 3 | RM-112, 115, 116 |
| B9 | 2 | RM-36, 91 |
| B10 | 2 | RM-19, 113 |
| B11, B12, B14 | 0 | (B12 tests confirm RM-19 and the section 11 unknowns) |
| B13 | 8 | RM-95, 97, 98, 102, 105, 106, 108, 109 |
| --MDM | 9 | RM-1, 8, 9, 11, 12, 13, 15, 16, 17 |
| --dev | 5 | RM-18, 31, 32, 33, 34 |
| --PR | 9 | RM-5 (#106), 14 (#111), 37 (#116), 38 (#113), 58 (#110), 76 and 77 (#109), 78 (#103), 79 (#112) |

**Open-PR coverage:** 9 items fully fixed by an open PR (the --PR row); 6 partly fixed
(RM-3, RM-4, RM-11, RM-13 and RM-47 by #111, #106 or #103; RM-98 by #99). The rest
have no PR.

**Unverified items (14):** RM-19, RM-52, RM-82, RM-84 (registry side), RM-85
(registry side), RM-91, RM-92, RM-112, RM-113, RM-114, RM-115, RM-116, plus the reproductions
behind RM-7 and RM-54, which belong to their reviewers (code re-checked; run not
repeated).
