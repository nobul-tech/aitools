# S3-MdmPkg-Critic review of the draft MDM packaging recommendation

Reviewer: S3-MdmPkg-Critic (independent, level 2 under S3-MdmPkg). Date: 2026-10-26.
Inputs: S3-MdmPkg-report.md (DRAFT v1), S3-MdmPkg-Intune-notes.md, -Jamf-notes.md, -Build-notes.md,
the repo on main 480b901, and the main build output at
`.claude/worktrees/mdmpkg/.scratch/session-mdmpkg/build/run-main/dotprofile/deploy/`.
Read-only. Web sources were read with WebFetch (labelled `wf`). WebFetch summarises pages, so
these are lower confidence than chrome-devtools.

## Verdicts

| Item | Verdict | One-line reason |
|---|---|---|
| A. One package per OS + new generated run-all | **MODIFY** | Shipping a package is right. But "run every script as the user, with HOME set" is wrong on Windows. The run-all also duplicates an orchestrator that already exists and leaves out the bootstrap steps (pwsh 7, node, Homebrew, config.json bootstrap keys). |
| B. Size gates + library embedded once | **HOLD** (with a scope change) | The facts are verified. Under A the per-file size limit stops mattering, so B is hygiene and headroom work, not a blocker. A gate on all files must not block a package build. |
| C. Small bootstrap that downloads a release asset (later) | **MODIFY** | The stated blocker is overstated. nobul-tech/aitools is PUBLIC, and a ~4.6 KB MDM-aware `bootstrap.sh/.ps1` already exists. Only the ~37 KB personal content needs a private channel. |
| Rejection of split per-tool MDM scripts | **HOLD, but the reasons are wrong on macOS** | The Windows reason holds (7 .ps1 files are 200 KB or more). On macOS every .sh except deploy-harness is under 1 MB. Reject the split there because of sibling files, ordering and parallel execution, not size. |

## Objections (with evidence)

### O1. A on Windows: "run each script as that user with HOME set" does not work under SYSTEM (high)
- The Windows scripts read `$env:USERPROFILE` and `$env:LOCALAPPDATA`, not `HOME`. Examples:
  setup-user-claude.ps1:47,92; setup-user-hooks.ps1:58,100; setup-user-skills.ps1:61-62;
  setup-rust.ps1:96,123; aitools-lib.ps1:2741,3051,3065-3066 (grep output, main).
- They also write the **User** PATH (that is, HKCU): aitools-lib.ps1:2794
  `SetEnvironmentVariable("Path", $newPath, "User")`, aitools-lib.ps1:2907, setup-modal.ps1:30.
  Under SYSTEM these writes land in SYSTEM's hive. Setting HOME changes none of this.
- Windows has no `sudo -u`. Dropping from SYSTEM to the user needs a real user-context
  process: the Intune Win32 "User" install behavior, a scheduled task, or CreateProcessAsUser.
- Conversely, the tool scripts call `winget install` with no `--scope`, 40+ call sites
  (setup-go.ps1:103, setup-perl.ps1:41, setup-rust.ps1:44, setup-typst.ps1:83, setup-gh-cli.ps1:46,
  aitools-install.ps1:550 ...). WinGet docs (wf, learn.microsoft.com/en-us/windows/package-manager/winget/):
  - "WinGet will not be available until you have logged into Windows as a user for the first time"
  - "When running WinGet without administrator privileges, some applications may require elevation ... If you choose not to elevate, the application will fail to install."
- Intune (wf, win32 page) adds: "Applications deployed through Intune must install silently and cannot require user interaction".
- **So no single context works on Windows.** User context breaks the machine-scope installers.
  SYSTEM context breaks the per-user config and may have no winget on PATH (not verified for
  SYSTEM specifically: **unknown**).
- **Suggested modification:** two Win32 apps linked by an Intune dependency (the Win32
  "dependencies" feature is listed on the win32 page, wf):
  - (1) a System-context app: pwsh 7, node, git, and the winget/MSI tool installs;
  - (2) a User-context app (`Install behavior: User`) that runs the config scripts (deploy-harness, setup-user-*).
  - This answers the prompt's question "Is the Intune user-context Win32 install a cleaner answer?" **Yes for the config half, no for the tool half.**

### O2. A on macOS: root → user is feasible, but Homebrew is a missing prerequisite (medium)
- The macOS tool scripts depend on brew: setup-gh-cli.sh:89, setup-pandoc.sh:112, setup-uv.sh:76,
  setup-go.sh:84, and aitools-install.sh:619 (node@22).
- No file in deploy/ installs Homebrew. Only `scripts/bootstrap.sh:34` does, and it runs the
  interactive install.sh (`grep -rln Homebrew/install scripts` returns only bootstrap.sh).
- Homebrew docs (wf, docs.brew.sh/Installation):
  - a `.pkg` installer exists (Apple Silicon only): "The selected user must exist before installation and must not be `root`";
  - it falls back to the console user;
  - a `brew as-console-user` command and root switching "through macOS `login`" are described.
  - The tutorial's claim "brew refuses root" may therefore be outdated. Verify with chrome-devtools before relying on either reading.
- setup-go.sh:104 calls `sudo rm -rf` for cleanup. As a non-root user with no tty, sudo fails.
  It logs a warning and does not hang (the code path is warn-only).
- **Suggested modification:**
  - make the Homebrew .pkg a separate MDM package or prerequisite;
  - the A-package postinstall resolves the console user (`stat -f %Su /dev/console`) and runs the scripts with `sudo -u <user> -H` (or `launchctl asuser`);
  - when no console user exists, exit non-zero so the MDM retries.
- Confirmed gap: `grep -rlE "/dev/console|SUDO_USER|ConsoleUser|as-console-user|Win32_ComputerSystem" scripts shared` returns nothing.

### O3. A's "NEW generated run-all" duplicates an existing MDM-aware orchestrator and misses bootstrap steps (high)
- `scripts/aitools-install.sh` is already written to run from a deploy directory. It logs
  "not found — skipping (MDM deploy)" when a sibling is absent (aitools-install.sh:363, 524, 551,
  578, 603, 690-825). It also carries the full order:
  - gh, gh auth (skipped when non-interactive, :387-390);
  - config.json through `setup-user-config.sh` (:500-507), which is the writer deploy-harness needs;
  - shell, node (:609-640), Claude Code (:646-679);
  - the tool scripts in dependency order (uv before python, :730-751);
  - the config scripts (:833).
- It is **not** in deploy/: the 50 files listed by `ls -l run-main/dotprofile/deploy` contain no
  aitools-install, and `grep aitools-install scripts/build-deploy.sh` finds only comments (:1917, :2067).
- Steps the draft's run-all must replicate, which no deploy/ script does:
  - **pwsh 7.** setup-user-claude.ps1 (generated, L8511-8512) does
    `LogError "This script requires PowerShell 7+"`. Intune's host is Windows PowerShell
    (Intune notes L44, inferred). aitools-install.sh:96-116 installs pwsh 7; deploy/ does not.
  - **node.** Needed by the hooks merge and cursor (Build notes L111). It is installed only by
    aitools-install (:609-640, .ps1:550).
  - **Claude Code CLI** (aitools-install.sh:646-679).
  - **config.json bootstrap keys.** The generated deploy-harness header says: "Where aitools-install
    has not run, the harness files still deploy, but the run reports ERROR "config.json not
    generated" and exits 1" (build-deploy.sh:1916-1919). On a clean endpoint the draft's run-all
    therefore exits 1 unless it writes `reposPath`/`repoPath` itself. On an endpoint with no
    repos, what those keys should point at is **unknown** (design question).
- **The deploy-paths.md equivalence rule cuts against a new entry point.**
  - deploy-paths.md:19 says the two paths "must produce equivalent results".
  - Lines 47-52 call parallel copies of setup logic "duplication risk" (incident I6).
  - The dev path already has **two order lists that disagree**:
    - aitools-install.sh:833 runs `claude cursor mcp skills cursor-ide-mcp settings hooks`;
    - scripts/aitools:1151 runs `config claude mcp skills cursor-ide-mcp cursor settings hooks`;
    - neither includes deploy-harness on main, although the build comments say "Run it FIRST in an MDM sequence" (build-deploy.sh:1913).
  - A third, generated list makes the drift worse.
- **Suggested modification:**
  - make the entry point the installer itself: inline the lib into aitools-install.sh/.ps1 and add it to deploy/ through build-deploy.sh;
  - or generate both the dev-path loop and the MDM manifest from one order source;
  - add deploy-harness to that single list first (as #106 does for the dev path).
- INCIDENT: the dev-path config order differs between aitools-install.sh:833 and scripts/aitools:1151 (cursor before or after mcp/cursor-ide-mcp; config present or absent).

### O4. A: the macOS unmanaged PKG detection and reporting do not fit a payload of scripts (medium)
Source (wf): learn.microsoft.com/en-us/intune/app-management/deployment/add-unmanaged-pkg-macos.
- "Included app bundle IDs and build numbers are used for detecting and monitoring ... If
  **Included apps** list contains files that aren't applications or if all the listed apps
  aren't installed, app installation status doesn't report success."
  - A deploy/ pkg holds no .app. To get a success status and version-driven updates, it needs a stub .app whose `CFBundleShortVersionString` changes with each build.
  - This is a hidden build cost the draft does not mention.
- "Note that post-install script failure isn't reported. A successful app installation
  followed by a failed post-install script will report the app installation status as "success"."
  - If the setup scripts run from the pkg postinstall, every ERROR is invisible in Intune.
  - Running them from the pkg's own payload `postinstall` (inside the pkg, not the Intune post-install field) has the same reporting gap for Intune. **Unknown** whether a pkg postinstall that exits non-zero fails the Intune install; macOS `installer` does fail on a non-zero postinstall.
- The Intune "post-install script" field is limited to "less than 15360 characters". That is enough for a launcher, not for the scripts.
- The install context of pkg scripts is not stated (Intune notes L110, still unknown).

### O5. A: update path and per-user personalization are not addressed (medium)
- **Updates.** Each change to deploy/ needs a rebuild, a repackage and an upload by an admin:
  - Intune Win32: a new .intunewin plus a detection rule (or supersedence) that sees the new version;
  - macOS PKG: the stub .app version bump (O4);
  - Jamf: a new pkg record plus a policy.
  - The draft defers this to C without naming the per-release manual cost. Today the dev path updates on every `aitools` run.
- **Personalization.** deploy/ is "personalized, generated by build-deploy.sh into the user's dotprofile repo" (deploy-paths.md:23-24).
  - One package therefore equals one user, and each user's package must be assigned to that user's device or group.
  - For Jose's own machines this is fine. For a fleet it means N apps per OS. The draft should say which case it targets: **unknown** from the draft.
- **Non-interactive semantics.** Under MDM, stdin is not a terminal, so every managed file takes SOURCE ("Non-terminal stdin: auto-select overwrite", interactive-menus.md "Non-interactive fallback").
  - A recurring MDM run overwrites local edits to `~/.claude/CLAUDE.md`, rules, skills and hooks (with backups).
  - This matches the spec, but a re-run policy turns it into a fleet-wide overwrite. Choose the re-run frequency with that in mind.

### O6. A: packaging must not use the committed deploy/ (confirmed, low)
- The committed dotprofile deploy/ (525ee49 = 825aed4) has 42 files, and main builds 50 (Build notes L11-15).
- The package must be built from an isolated fresh build. build-deploy.sh replaces DEPLOY_DIR with `rm -rf` + `mv` (Build notes L37-40), so a CI packaging job must point `AITOOLS_USER_REPO_PATH` at a throwaway clone.

### O7. B: right facts, wrong priority under A (low)
- Verified:
  - the library is embedded twice: `grep -c "^logging_init()" setup-user-settings.sh` = 2, `grep -c "Embedded profile resolver"` = 1;
  - `RESOLVER_SH_FILES="aitools-profile.sh aitools-lib.sh aitools-json.pl"` (build-deploy.sh:436-437).
- Once deploy/ ships as a directory, the resolver's copy could be a sibling file, and so could the inlined lib.
  - The "self-contained" requirement (deploy-paths.md:23) would then mean the directory, not each file.
  - Changing that is a protected-rule change (sources-of-truth.md) and needs commander approval.
- Keep the gate, but split it in two:
  - a per-file 200 KB .ps1 limit only for the files meant for the Intune script channel (bootstrap, launcher);
  - a whole-package budget for everything else.
- A blanket 200 KB gate on all 25 .ps1 files fails the build today: 7 are at least 200,000 B (sizes below).

### O8. C: the credential blocker is narrower than stated (medium)
- `gh repo view nobul-tech/aitools --json visibility` returns `{"isPrivate":false,"visibility":"PUBLIC"}`.
- `gh repo view nobul-jose/aitools-nobul-jose --json visibility` returns `{"visibility":"PRIVATE"}`.
- `scripts/bootstrap.sh` (4,687 B) and `bootstrap.ps1` (3,437 B) already clone the public repo and run aitools-install. They skip the dotprofile step when non-interactive: "Skipped automatically in non-interactive/MDM runs" (bootstrap.sh:90-91; bootstrap.ps1:57-59 uses `[Environment]::UserInteractive`).
- Both fit far under the Intune limits (200 KB Windows, 1 MB macOS).
- The private part is small. Build notes 2c: CLAUDE.md 16,093 + claude-shared 11,760 (public) + profile.json 1,683 + rules 7,311. That is about 25 KB private, about 37 KB with claude-shared.
- **Missed option C':** an MDM script (Windows platform script or macOS shell script) or a small package that
  - carries only the personal snapshot (profile.json, claude/CLAUDE.md, claude/rules/) as files,
  - fetches the public aitools at a pinned tag or release,
  - and runs the dev path (`aitools-install` with `--skip-gh-auth`, `AITOOLS_FORCE=1`).
  - The dev path then runs unchanged, so the deploy-paths equivalence rule holds trivially.
  - Unknowns: whether the dev-path scripts accept a userRepoPath that is not a git checkout (adopt and auto-push would fail; non-interactive runs never adopt); git or Homebrew prerequisites (O2); and the Microsoft guidance "Don't include any type of sensitive information in scripts" (Intune notes L100). profile.json holds identity, not secrets (not re-checked).
- Bootstrap caveats:
  - bootstrap.sh:34 runs the interactive Homebrew installer and would fail under root (O2);
  - bootstrap.ps1:48 runs aitools-install.ps1 under `powershell` (5.1), which then needs pwsh 7.

### O9. Draft summary facts (report lines 7-9)
- Line 7, "14 of 50 generated files are over Intune's Windows script limit": **misleading**.
  - 7 of the 14 are .sh files, which never go through a Windows channel.
  - Correct statement: 7 of 25 .ps1 files are 200 KB or more, and only deploy-harness.sh (2,281,252 B) is over the macOS 1 MB limit.
  - The macOS script channel is therefore not closed by size, except for deploy-harness.
- Line 8, "smallest tool script is 141-165 KB": **mixed units**.
  - Measured plain scripts: .sh 144,461-162,153 B; .ps1 156,318-165,295 B.
  - 141 is KiB (144,461/1024), while 165 is KB.
  - The smallest .ps1 is setup-google-chrome.ps1 at 156,318 B, which leaves about 44 KB headroom.
  - The direction of the claim is correct.
- Line 9, "Each one also runs as SYSTEM/root": **partly false**.
  - Intune Win32 supports "System or User" (Intune notes L20, L62).
  - Intune macOS scripts can "Run script as signed-in user" (L23).
  - Windows platform scripts default to user context (L18).
  - Only the pkg-based channels (Jamf, Iru: "Custom scripts are always executed as the root user", wf re-verified) are root-only.

## Claims re-verified

| # | Claim (source) | Method | Result |
|---|---|---|---|
| 1 | Win32 PowerShell script installer "Scripts are limited to 50 KB in size", runs "in the same context as the app installer (system or user context)" (Intune notes L21) | wf, learn.microsoft.com/en-us/intune/app-management/deployment/win32 | **PASS** (verbatim) |
| 2 | Unmanaged PKG: <8 GB, unsigned/payload-free allowed, scripts <15360 chars (Intune notes L26-27, L86) | wf, add-unmanaged-pkg-macos | **PASS**; also found the detection/reporting caveats in O4 |
| 3 | Iru "Custom scripts are always executed as the root user." (Jamf notes L73) | wf, docs.iru.com custom-scripts-overview | **PASS** (verbatim) |
| 4 | 50 files on main, 14 ≥200,000 B; deploy-harness 2,281,252 / 2,312,096 B (Build notes L15, L158) | `ls -l run-main/dotprofile/deploy` | **PASS** (exact sizes match) |
| 5 | Library embedded twice in setup-user-claude/-cursor/-settings via RESOLVER_*_FILES (Build notes L72, build-deploy.sh L436-437) | `sed -n 425,445p build-deploy.sh`; `grep -c` on the generated setup-user-settings.sh | **PASS** |
| 6 | deploy-harness needs aitools-install bootstrap keys, else exit 1 (Build notes L115) | build-deploy.sh:1916-1919 | **PASS** |
| 7 | No console-user resolution exists (orchestrator) | grep over scripts/ and shared/ | **PASS** (no hits) |
| 8 | Smallest tool script 141-165 KB (draft L8) | ls | **PARTIAL** (mixed units, O9) |
| 9 | All MDM channels run as SYSTEM/root (draft L9) | Intune notes + wf | **FAIL** for the Intune Win32 and script channels (O9) |

Not re-verified: Jamf script-object size (community 403), the Jamf `$3` username parameter, and the Intune macOS 1 MB limit. These were verified by the orchestrator, not by me.

## Missed options (ranked by fit)

1. **Ship aitools-install as the entry point inside the package.** Lib-inlined aitools-install.sh/.ps1 is already MDM-aware (O3). This removes the new run-all and keeps one order list.
2. **C': public repo + personal snapshot + dev path** (O8). This needs no package on macOS, and on Windows it fits the Intune platform script (<200 KB). It satisfies deploy-paths equivalence by construction. Its cost is the network at run time; Intune macOS also has "no proxy" (Intune notes L74).
3. **Windows split into a System Win32 app (tools, pwsh 7, node) plus a dependent User Win32 app (config)** (O1).
4. **MDM installs only the prerequisites (git, Homebrew .pkg, pwsh 7, node) and runs the existing bootstrap as the user.** This is the prompt's "MDM installs only aitools CLI + git and runs the dev path". It is blocked only by the dotprofile step being interactive-only (bootstrap.sh:92), which is fixable with C'.

## INCIDENT markers (not filed)

- INCIDENT: there are two dev-path config order lists, and they differ (aitools-install.sh:833 vs scripts/aitools:1151). Neither includes deploy-harness on main, although the generated header says it must run first (build-deploy.sh:1913).
- INCIDENT: deploy/ (the MDM path) has no step that installs pwsh 7, node, the Claude Code CLI or Homebrew, and does not write the config.json bootstrap keys. The dev path does all of these in aitools-install. So the deploy-paths.md:19 "equivalent results" claim does not hold on a clean endpoint.
- INCIDENT: the Windows setup scripts assume a user-context process (USERPROFILE, LOCALAPPDATA, HKCU PATH writes) and also call winget installers that may need elevation. No spec says which MDM context each script needs (governance ambiguity: "No spec exists for: per-script execution context on the MDM path").

## WRITE_BLOCKED

One tool call was blocked, a read-only `sed -n 'A,Bp;C,Dp'` (standing-order-guard, ';'). The text was:
`PreToolUse:Bash hook error: [bash "/Users/new-jose/.claude/hooks/standing-order-guard.sh"]: USO: Simple Bash commands only --: Don't use ';' to chain commands. Make separate Bash tool calls instead.`
I did not retry it in another form; I read the same lines with the Read tool, which is the prescribed tool. No write was blocked.
