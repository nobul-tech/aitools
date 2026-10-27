# S3-MdmPkg report: getting generated deploy/ to an endpoint within MDM payload limits

Author: S3-MdmPkg (orchestrator, level 1 under Session Commander 10cf255a-c). Date: 2026-10-26. Status: final (v2, after the critic pass). Read-only mission: no code changes, no commits, no PR.

Delegate notes in this folder: `S3-MdmPkg-Intune-notes.md`, `S3-MdmPkg-Jamf-notes.md`, `S3-MdmPkg-Build-notes.md`, `S3-MdmPkg-Critic-review.md`.

## 1. Summary (5 lines)

1. **Windows scripts are over the limit.** The Intune Windows script channel ("less than 200 KB (ASCII)") cannot carry today's output: on main, 7 of 25 generated .ps1 files are over 200,000 B, and deploy-harness is over 2.2 MB on both OSes. Every plain tool script is already 144-165 KB, about 97% of it the inlined library.
2. **Use a package per OS.** Each MDM channel that fits is a package: an Intune Win32 .intunewin (30 GB), an Intune unmanaged PKG (8 GB), or a .pkg for Jamf, Iru or WS1. Jamf documents no script size limit, and pasting ~450 KB scripts into it is unsafe.
3. **Packaging is not the hard part; run context is.** Jamf and Iru run as root, and Windows needs SYSTEM for winget but the user's context for USERPROFILE/HKCU. No deploy script resolves the console user today, and deploy/ lacks prerequisites (pwsh 7, node, Homebrew, the config.json bootstrap keys).
4. **Recommendation (A'):** one package per OS, with the existing installer (aitools-install, lib-inlined into deploy/) as the entry point rather than a new run-all. On Windows, a System Win32 app plus a dependent User Win32 app; on macOS, a postinstall that runs as the console user. Also: embed the library once and gate size per channel.
5. **Strategic alternative (C'), commander's decision:** nobul-tech/aitools is public, so a small MDM script could carry only the private personal snapshot and run the normal dev path at a pinned tag. Equivalence would then hold by construction, but it changes the MDM-path definition in deploy-paths.md (a protected file).

## 2. Verified limits

The read method was chrome-devtools (cd) by the delegate, then spot-checked by me with WebFetch (wf) where noted. Read date for all rows: 2026-10-26.

| Mechanism | Platform | Limit (verbatim) | Run context | Source | Verified by |
|---|---|---|---|---|---|
| Intune platform script (PowerShell) | Windows | "The script must be less than 200 KB (ASCII)." | user (default) or system | https://learn.microsoft.com/en-us/intune/device-management/tools/run-powershell-scripts-windows | Intune (cd) |
| Intune Remediations | Windows | script size not stated (unknown); output "2,048 characters"; needs E3/E5-class licences | user or system | https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations | Intune (cd) |
| Intune Win32 app (.intunewin) | Windows | "Windows application size must not be greater than 30 GB per app." | System or User | https://learn.microsoft.com/en-us/intune/app-management/deployment/win32 | Intune (cd), orchestrator (wf) PASS |
| Intune Win32 PowerShell script installer | Windows | "Scripts are limited to 50 KB in size" | same as the app installer | same page | Intune (cd), orchestrator (wf) PASS, Critic (wf) PASS |
| Intune shell script | macOS | "The script file must be less than 1 MB in size."; needs a direct Internet connection, "through a proxy is not supported" | root by default, or the signed-in user | https://learn.microsoft.com/en-us/intune/device-management/tools/run-shell-scripts-macos | Intune (cd) |
| Intune LOB .pkg | macOS | "maximum size limit of 2 GB per app"; signed with a Developer ID Installer certificate | not stated | https://learn.microsoft.com/en-us/intune/app-management/deployment/add-lob-macos | Intune (cd) |
| Intune unmanaged PKG | macOS | "smaller than 8 GB"; pre/post-install scripts "less than 15360 characters"; detection uses the bundle IDs under "Included apps", and a post-install failure "isn't reported" | not stated (unknown) | https://learn.microsoft.com/en-us/intune/app-management/deployment/add-unmanaged-pkg-macos | Intune (cd), Critic (wf) PASS |
| Jamf Pro script object | macOS | **unknown**: none documented, and the API `scriptContents` is a string with no maxLength. Community reports 80 KB working and a 403 error saving a ~10k-line script | root ("Scripts deployed from Jamf Pro are automatically run as the root user.", Jamf 100 Lesson 25) | learn.jamf.com/r/en-US/jamf-pro-documentation-current/Scripts ; developer.jamf.com/jamf-pro/reference/post_v1-scripts | Jamf (cd). The orchestrator's re-fetch of Lesson 25 hit an access redirect, so it was not re-verified |
| Jamf policy log | macOS | "truncates the output of policy logs after they reach 25 KB" | | Jamf Scripts page | Jamf (cd) |
| Jamf package / cloud DP | macOS | no package limit stated; CloudFront "files larger than 30 GB may not download successfully"; community reports a 5 GiB Jamf Sync cap | root (installer) | .../Package_Management ; .../Cloud_Distribution_Point | Jamf (cd) |
| Iru (Kandji) custom script | macOS | no limit stated; "Custom scripts are always executed as the root user." | root | docs.iru.com/en/endpoint/library/library-items-profiles/custom-scripts-overview | Jamf (cd), Critic (wf) PASS |
| Workspace ONE Scripts | macOS | no limit stated; the tutorial uses the System context | system | techzone.omnissa.com/distributing-scripts-macos-workspace-one-operational-tutorial | Jamf (cd) |
| Mosyle | macOS | not checked (unknown) | | | |

## 3. Current generated sizes (measured)

**Commands.** The committed dotprofile size comes from `git -C /Users/new-jose/repos/aitools-nobul-jose ls-tree -l HEAD deploy/` (run by me; it matches the Build delegate). The per-ref builds come from `/Users/new-jose/repos/aitools/.claude/worktrees/mdmpkg/.scratch/session-mdmpkg/build/measure.sh <label> <ref>`. That script builds a detached worktree per ref and a `git clone` of the dotprofile, then runs `env HOME=<iso> TMPDIR=<iso> AITOOLS_USER_REPO_PATH=<clone> bash scripts/build-deploy.sh`. All four builds exited 0. I verified the main row against `run-main/sizes.txt`.

**Committed dotprofile deploy/ (HEAD = the same blobs as 825aed4) is stale.** It has 42 files to main's 50, and no deploy-harness or resolver. Its largest files are setup-user-skills.sh at 448,561 B and setup-user-hooks.sh at 395,400 B; nothing is over 1 MB.

**Built from aitools main 480b901, bytes (.sh / .ps1):**

| File | .sh | .ps1 | Over 200 KB | Over 1 MB |
|---|---|---|---|---|
| deploy-harness | 2,281,252 | 2,312,096 | both | both |
| setup-user-claude | 431,160 | 463,901 | both | no |
| setup-user-cursor | 402,104 | 434,311 | both | no |
| setup-user-settings | 378,526 | 409,815 | both | no |
| setup-user-skills | 339,747 | 357,436 | both | no |
| setup-user-hooks | 285,189 | 302,599 | both | no |
| aitools-profile | 216,961 | 231,854 | both | no |
| setup-user-config | 160,517 | 175,181 | no | no |
| 15 plain tool pairs + mcp/shell | 144,461-162,153 | 156,318-165,295 | no | no |
| aitools-json | 12,670 (.pl) | 9,025 | no | no |

**Other refs (Build notes):**
- #106 does not change deploy/.
- #111 brings deploy-harness down to 177,181 / 190,907 B, plus a sibling `deploy-harness.payload` of 2,085,269 B, and adds a 200 KB/1 MB gate for deploy-harness only.
- #112 (stacked on #103) adds about 6.0 K (.sh) and 6.7-7.2 K (.ps1) to every file. With #111 as well, deploy-harness.ps1 comes to about 198 K, close enough to the gate to warn (inferred, not measured).

**What drives the size:**
- **The library.** `scripts/aitools-lib.sh` is 140,653 B and `.ps1` is 154,937 B (`wc -c`, by me). It is inlined into every script by `inline_lib_bash` / `inline_lib_ps1` (build-deploy.sh L124-173).
- **The library twice.** setup-user-claude, -cursor and -settings embed it a second time inside the profile resolver (`RESOLVER_SH_FILES` / `RESOLVER_PS1_FILES`, build-deploy.sh L436-437, confirmed by me). That is about 281 K of the 431 K setup-user-claude.sh.
- **Embedded content.** setup-user-skills adds about 192 K of skills, setup-user-hooks about 130 K of hooks, and deploy-harness carries base64 of 134 harness files.

## 4. Facts that constrain every option

- **F1: deploy/ is a directory, not one file per tool.**
  - deploy-harness calls its sibling `setup-user-config.*`, which reads `aitools-profile.*` and `aitools-json.*`. With #111 it also reads `deploy-harness.payload`.
  - setup-user-cursor reads `~/.aitools/rules`, which deploy-harness fills.
  - Sources: Build notes §1, build-deploy.sh L855, L895, L1905.
- **F2: there is no run-all in deploy/.**
  - The order exists only in comments ("Run deploy-harness first", build-deploy.sh L1913).
  - The dev path has two order lists that disagree, and neither includes deploy-harness:
    - `scripts/aitools-install.sh:833` (no setup-user-config; cursor after claude)
    - `scripts/aitools:1151` (setup-user-config first; cursor after cursor-ide-mcp)
  - I read both.
- **F3: aitools-install already handles an MDM layout.** It has 17 `skipping (MDM deploy)` branches, for example aitools-install.sh:363 and 524-825 (grep, by me). It is not copied into deploy/.
- **F4: deploy/ does not install its own prerequisites.**
  - pwsh 7: the generated setup-user-claude.ps1 stops with "requires PowerShell 7+" (Critic, generated L8511).
  - node and the Claude Code CLI are not installed.
  - Homebrew is installed only by `scripts/bootstrap.sh:34`.
  - deploy-harness exits 1 without the config.json bootstrap keys (build-deploy.sh:1916-1919, Critic PASS).
- **F5: run context.**
  - Jamf, Iru and WS1 scripts and packages run as root.
  - Windows scripts write `$env:USERPROFILE`, `LOCALAPPDATA` and per-user PATH (HKCU), for example aitools-lib.ps1:2794 `SetEnvironmentVariable("Path", $newPath, "User")`.
  - Windows scripts also call `winget install` with no `--scope` at 40+ sites, and some installers need elevation.
  - No script resolves the console user: my grep of `scripts/` for `/dev/console|SUDO_USER|ConsoleUser` found nothing.
  - Homebrew refuses to run as root (Critic, wf of the Homebrew docs, not re-checked in a real browser).
- **F6: non-interactive runs overwrite local edits.** Without a terminal, every managed file takes SOURCE, so a recurring MDM run overwrites local edits; backups are kept (interactive-menus.md "Non-interactive fallback"; agentic-standards.md).
- **F7: repo visibility.** `gh repo view nobul-tech/aitools --json visibility` returns PUBLIC (by me); the Critic reports aitools-nobul-jose as PRIVATE.

## 5. Options

### Option A': one package per OS; the entry point is the existing installer (RECOMMENDED near-term)

- **Shape:** build-deploy also emits a lib-inlined `aitools-install.sh/.ps1` into deploy/ as the single entry point.
  - Its order list is generated from one source, deploy-harness first, so the two existing lists collapse into one.
  - Prerequisites (pwsh 7, node, git, and on macOS the official Homebrew .pkg) ship as separate MDM prerequisite apps or packages.
- **Windows:**
  - Win32 app #1 runs in System context: prerequisites and tool installs (winget).
  - Win32 app #2 runs in User context and depends on #1: the config scripts (claude, cursor, mcp, skills, settings, hooks, deploy-harness, user-config).
  - Detection uses a version marker file.
- **macOS:**
  - A .pkg with deploy/ under a fixed path. Its postinstall resolves the console user via `/dev/console`, then runs the entry point with `sudo -u <user> -H`, because brew refuses root.
  - For Intune unmanaged PKG, a stub .app whose version changes each build, needed for detection (Critic O4).
  - The same .pkg serves Jamf, Iru and WS1.
- **Fits the limits:** yes, everywhere. The whole directory is about 10 MB (estimate from the table) against limits of 2-30 GB.
- **Effort:** medium.
  - Packaging scripts (IntuneWinAppUtil, pkgbuild/productbuild) and an entry-point generator in build-deploy.
  - Console-user resolution for macOS.
  - Splitting tool and config steps by context on Windows.
- **Cross-platform parity:** good. One entry point per OS with the same order list. Packaging tools differ by OS, which is inherent to MDM.
- **Equivalence (deploy-paths.md):** improves on today. Reusing aitools-install means the MDM path and the dev path share one orchestrator rather than three order lists.
- **Risks:**
  - Every change to deploy/ means an admin rebuild, repackage and upload (Critic O5).
  - deploy/ is personalised from one dotprofile, so a fleet needs one package per user. Target scope is unknown; see Q2.
  - Post-install failures are invisible in Intune macOS, so the entry point should write logs (~/.aitools/logs) and a status marker that detection reads.
  - Unsigned .pkg behaviour under Gatekeeper when installed by the jamf binary is unverified.

### Option B: build hygiene (do with A' or C'; not a delivery option by itself)

- **Embed the library once.** Have the resolver reuse the inlined copy, or ship aitools-lib as a sibling file inside the package. This removes about 140-155 K from each of claude, cursor and settings.
- **Gate size per channel** (Critic B):
  - Scripts that go through a script channel (a bootstrap, or the Win32 installer script, 50 KB) get a hard per-file gate.
  - Package contents get a whole-package budget.
  - A blanket 200 KB gate on every file would fail today on 7 .ps1 files.
- **Effort:** low-medium. **Risk:** low.
- Shipping the library as a sibling file breaks the "self-contained per script" property, which no longer matters once the delivery is a package (F1).

### Option C': small bootstrap plus the personal snapshot, running the dev path at a pinned public tag (STRATEGIC, needs a decision)

- **Shape:** the MDM script channel carries only:
  - the private personal content: profile.json, the CLAUDE.md template and the user rules. The Critic puts this at about 25-37 KB; I have not measured it.
  - a few KB of bootstrap logic.

  At run time it downloads the public nobul-tech/aitools at a pinned tag (a release tarball, or git), writes the snapshot as userRepoPath, and runs the normal dev path with `AITOOLS_FORCE=1`. The existing `scripts/bootstrap.sh` (4,687 B) and `bootstrap.ps1` (3,437 B) already skip the dotprofile step in non-interactive runs (bootstrap.sh:90-92, Critic).
- **Fits the limits:** yes. It stays under 200 KB on Windows and 1 MB on macOS if the snapshot stays small; gate it in the build.
- **Effort:** medium. Unknown: whether the dev path accepts a userRepoPath that is not a git checkout, given that dotprofile writes auto-commit and push (N-Q2).
- **Cross-platform parity:** good. The same dev-path scripts run on both OSes.
- **Equivalence:** holds by construction, because there is only one path. It would also retire the duplicated build-deploy templates (incident I6).
- **Risks:**
  - It needs network access at run time to GitHub; Intune macOS scripts need a direct connection with no proxy.
  - Run context (F5) still applies.
  - The tag must be pinned, or the fleet runs unreviewed main.
  - It redefines "MDM path" in `.claude/rules/deploy-paths.md`, a protected file that needs review.
  - Updates become cheap: a recurring script frequency or a new tag, with no repackaging.

### Option C (original): bootstrap downloads a packaged deploy/ release asset

- Same shape as C', but it fetches the built deploy/ instead of running the dev path.
- It needs a place to host a private asset (the dotprofile repo is private), so a credential on the endpoint. Intune says "Don't include any type of sensitive information in scripts".
- **Dominated by C'**: C' needs no private download.

### Option D: per-tool MDM scripts (REJECTED)

- **Windows:** the smallest generated .ps1 is 156,318 B and grows about 7 K with each library change (#103/#112). Seven are already over 200,000 B, and the Win32 script installer is 50 KB.
- **macOS:** everything except deploy-harness fits under 1 MB, but sibling files (F1), the order (F2) and Intune's parallel macOS script execution (Intune notes) make independent per-tool scripts unsafe.
- Rejected on Windows for size and on macOS for structure.

### Option E: MDM installs only prerequisites, and the user runs the bootstrap

- Lowest effort, but not hands-off: it needs a user action and an interactive login for gh and the dotprofile.
- Valid for Jose's own machines today, and not an MDM answer for a fleet.

## 6. Recommendation

1. **Now:** Option B. Embed the library once, add per-channel gates, and generate the order list once with deploy-harness first. It is low risk, it helps every option, and it fixes F2.
2. **Then decide Q1.**
   - If the commander wants a fully offline, self-contained endpoint package, do **A'**.
   - If network at install time is acceptable, **C'** is the better long-term design. It removes the second deployment path and its duplication debt, and makes updates cheap. My lean is C', because the equivalence rule is what keeps breaking (I6, F2, F4) and C' deletes the thing that breaks.
3. **Either way, first:**
   - specify the run context per script (SYSTEM/root vs user) and the console-user resolution;
   - supply the missing prerequisites (F4).

   These block every option.

## 7. Open questions (each with a suggested answer)

- **Q1:** Self-contained package (A') or bootstrap plus dev path (C')? *Suggested:* C', with A' kept only if an offline or air-gapped requirement exists. It needs a reviewed edit to deploy-paths.md.
- **Q2:** Is the target Jose's own machines, or a fleet of users? *Suggested:* Jose's machines first (one dotprofile). Fleet support needs per-user snapshots, a reason to prefer C' (small per-user payload).
- **Q3:** Which MDM is real: Intune, Jamf, or both? *Suggested:* name it before building packaging, since detection and update mechanics differ (Win32 detection rule vs PKG stub app vs Jamf policy).
- **Q4:** How do updates reach endpoints? *Suggested:* for C', a pinned tag bumped per release, plus a recurring run (macOS script frequency; Windows Win32 supersedence or Remediations if licensed). For A', a version marker plus supersedence.
- **Q5:** Should recurring MDM runs overwrite local edits (F6)? *Suggested:* yes for managed files, with backups (current non-interactive behaviour); document it for users.
- **Q6:** Should winget installs use `--scope machine` under SYSTEM? *Suggested:* evaluate per tool through `/tool-eval`. Do not change it blind.

## 8. INCIDENT markers (not filed; for the Session Commander to triage)

- INCIDENT: The committed dotprofile deploy/ (825aed4 blobs) is stale versus main: 42 vs 50 files, with no deploy-harness or resolver. A package built from it today would ship old scripts. (Build)
- INCIDENT: No size gate exists for any generated script except deploy-harness, and that gate only arrives with #111. On main, 7 .ps1 files are at least 200,000 B and the build passes silently. (Build)
- INCIDENT: The library is embedded twice in setup-user-claude, -cursor and -settings (build-deploy.sh L436-437). (Build, confirmed by orchestrator)
- INCIDENT: `trap 'rm -rf "$MDM_TMP"' EXIT` at build-deploy.sh L1706 overrides the BUILD_TMP trap at L320, so BUILD_TMP leaks on every build on main (fixed by #111). (Build; not re-verified by me)
- INCIDENT: The dev-path order lists disagree (aitools-install.sh:833 vs scripts/aitools:1151), and neither runs deploy-harness, though the generated header says to run it first. (Critic, confirmed by orchestrator)
- INCIDENT: deploy/ lacks the pwsh 7, node, Claude Code CLI and Homebrew installs and the config.json bootstrap keys, so the deploy-paths.md "equivalent results" claim fails on a clean endpoint. (Critic)
- INCIDENT: No spec says which run context (SYSTEM/root or user) each MDM-path script needs, and no script resolves the console user. Governance ambiguity. (Jamf + Critic, grep by orchestrator)
- INCIDENT (low): Intune doc URLs under `/intune/intune-service/...` redirect to `/intune/device-management/...` and `/intune/app-management/...`. Any harness file citing the old paths should be updated. (Intune)

## 9. Delegates used and how I verified them

| Delegate | Role | Output | How I verified it |
|---|---|---|---|
| S3-MdmPkg-Intune | Intune limits (chrome-devtools) | S3-MdmPkg-Intune-notes.md | Re-fetched the Win32 page (wf): "30 GB per app" and "Scripts are limited to 50 KB in size" PASS verbatim. The Critic independently re-verified the unmanaged PKG limits |
| S3-MdmPkg-Jamf | Jamf, Iru, WS1 limits (chrome-devtools) | S3-MdmPkg-Jamf-notes.md | Lesson 25 re-fetch blocked by an access redirect (not verified). Iru root quote re-verified by the Critic (wf). Its HOME-resolution concern confirmed by my grep (no console-user code) |
| S3-MdmPkg-Build | build-deploy mechanics and sizes (isolated HOME, cloned dotprofile) | S3-MdmPkg-Build-notes.md | Committed sizes match my own `ls-tree` exactly. Main-build sizes read from run-main/sizes.txt. L436-437 library-twice confirmed by grep. Real dotprofile untouched (`git status`: only a pre-existing sessions/.DS_Store change) |
| S3-MdmPkg-Critic | independent refutation of the v1 draft | S3-MdmPkg-Critic-review.md | Confirmed aitools is PUBLIC (`gh repo view`), the 17 "MDM deploy" branches in aitools-install.sh (grep), and the order-list disagreement (Read of both lines). I accepted its corrections to v1: units, 7 of 25 .ps1 files rather than "14 files", and Intune Win32 offering a User context |

**Left in place by S3-MdmPkg-Build (cleanup is for the Session Commander; I did not remove another agent's worktrees):**
- worktrees `/Users/new-jose/repos/aitools/.claude/worktrees/mdmpkg-b-main`, `mdmpkg-b-pr106`, `mdmpkg-b-pr111`, `mdmpkg-b-pr112` (detached)
- refs `refs/mdmpkg/pr106`, `refs/mdmpkg/pr111`, `refs/mdmpkg/pr112`
- my worktree `/Users/new-jose/repos/aitools/.claude/worktrees/mdmpkg` (its scratch holds build logs and measure.sh)

**WRITE_BLOCKED:** none on writes. Two delegates had a Bash command refused by standing-order-guard (a multi-line perl command; `sed -n` with `;`). Both used Edit or Read instead; no write was denied.
