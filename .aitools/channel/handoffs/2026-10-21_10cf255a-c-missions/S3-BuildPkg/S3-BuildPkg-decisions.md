# S3-BuildPkg design decisions (orchestrator synthesis, rev 1, 2026-10-26)

Author: S3-BuildPkg. Basis: the ten wave-1 files in this folder (cited by
short name: RevBuild, RevInstall, RevLib, RevSetup, RevTools, PkgWin, PkgMac,
PkgLinux, Lang, DocsInv) and the MDM-PKG report. These decisions are the
contract every writer follows; a writer that disagrees records a
"Contract change" note with its reason instead of silently diverging.
"Proposed" = needs a commander decision (listed in section 4).

## 1. Decisions

| ID | Decision | Basis |
|----|----------|-------|
| BP-1 | **Payload = the public aitools tree at a pinned ref**, not the dotprofile `deploy/`. build-package stages `git archive <ref>` of tracked files (scripts/, shared/, reference/, registries/, .claude/rules, .claude/skills, .claude/hooks if present) plus a generated `MANIFEST` (the `git ls-files` list) and `BUILD-INFO` (version, commit, date, kind). No personal data in any package: packages are admin-downloadable and the repo is public. | RevBuild summary 2 + incident (deploy/ embeds the build-time dotprofile identity), RevInstall Q1, PkgMac Q2, PkgWin dotprofile note; MDM-PKG F7 |
| BP-2 | **The package path runs the dev-path scripts from the payload** (no third copy of setup logic, no generated scripts). Equivalence with the dev path holds by construction (same scripts, same order). build-deploy.sh and the dotprofile `deploy/` MDM path stay exactly as they are (parallel). build-package never calls build-deploy.sh. | Commander "parallel"; deploy-paths.md I6 duplication debt; Critic O3; DocsInv draft |
| BP-3 | **Language: one bash script `scripts/build-package.sh`** (bash 3.2, `set -euo pipefail`, sources aitools-lib + `logging_init "build-package"`, `--help`, exit footer), one function per kind (`intune`, `pkg`, `deb`) plus `stage`; a kind whose native tool is absent reports OK `n/a (<host>)`. Second bash-only build-script exception (rows drafted for cross-platform.md, which PR #99 owns: apply after it merges). | Lang 1, 3 |
| BP-4 | **Build hosts: native per kind.** `.pkg` on macOS (pkgbuild/productbuild, OS-provided), `.intunewin` on Windows (IntuneWinAppUtil.exe from Git Bash), `.deb` on Ubuntu (dpkg-deb, OS-provided). CI: one new workflow with three jobs (macos-14, windows-2022, ubuntu-24.04). `stage` runs anywhere. | Lang 2, PkgWin 1, PkgMac 1, PkgLinux 1/3 |
| BP-5 | **Package launchers live in `packaging/<os>/`** (new top-level dir): platform-native files that MDM/dpkg run, exempt from .sh/.ps1 pairing as a new exemption category "package launchers" (drafted for cross-platform.md). They are thin: resolve context, lay down state, call `scripts/aitools-install.*` from the payload. | RevInstall (one orchestrator), Critic O3 |
| BP-6 | **Entry point = the existing installer** `scripts/aitools-install.sh/.ps1` with new flags: `--phase system|user|all` (default `all` = today's behaviour) and `--package-mode` (repoPath = read-only payload; no git pull/clone, no build-deploy, adopt disabled, gh auth skipped). The step order comes from ONE data file read by the installer and by `scripts/aitools` sync (`scripts/aitools-order.txt`, proposed name), deploy-harness first in the user phase (post-#106 order). | RevInstall 1, R-list; MDM-PKG F2 |
| BP-7 | **Run context per OS.** macOS: pkg postinstall (root) lays payload + VERSION + stub app, logs to `/Library/Logs/aitools/install.log`, resolves the console user (`stat -f %Su /dev/console`; empty/root/loginwindow/_mbsetupuser = none), runs the user phase detached via `launchctl asuser <uid> sudo -u <user> -H`; if no user, `/Library/LaunchAgents/tech.nobul.aitools.firstrun.plist` runs it at next login (user phase compares `~/.aitools/pkg-version` with payload VERSION). Windows: Win32 App A **System** (payload to `%ProgramFiles%\aitools\`, HKLM `SOFTWARE\aitools` Version, machine-wide prerequisites, NO winget CLI) and Win32 App B **User** (depends on A; `pwsh -File install-user.ps1` → installer `--phase user --package-mode`, user-scope winget). Linux: `.deb` postinst lays files only (`/opt/aitools`, `/usr/bin/aitools-setup`); the user (or root in a container) runs `aitools-setup`. | PkgMac 4/7, PkgWin 3/5/7, PkgLinux 3/4/7, RevSetup 2 |
| BP-8 | **Prerequisites are separate MDM packages / Depends**, not installed by the aitools package. Windows: PowerShell 7.6 LTS MSI (dependency app), Git, Node LTS as their own Intune apps (vendor MSI). macOS: Command Line Tools, Homebrew .pkg (Apple Silicon; Intel unsupported on the package path in v1 unless Homebrew is preinstalled), node, pwsh optional. Linux: `Depends: bash, perl, python3, git, curl, ca-certificates`; `Recommends: jq, sudo`; pwsh/node installed by the user phase (not in Ubuntu archives at usable versions). The launchers check prerequisites and report ERROR + ACTION when one is missing. | PkgWin 5 (winget unsupported in SYSTEM; 7.7 has no MSI), PkgMac Q3/Q5, PkgLinux 2, RevTools 4 |
| BP-9 | **One `.deb`, `Architecture: all`, for Ubuntu 22.04 and 24.04**, no version floors; install-tested on both plus a root `ubuntu:24.04` container and a non-root `ubuntu` user with passwordless sudo (Cursor-cloud-like). | PkgLinux 1/2, RevTools Q3, RevSetup Q6 |
| BP-10 | **Console-user / privileged-run API in aitools-lib** (bash `resolve_target_user`, `is_privileged_run`, `run_as_target_user`; PS1 `Resolve-TargetUser`, `Test-PrivilegedRun`, `Invoke-AsTargetUser`; results in `AITLIB_TARGET_*` / `$script:AitLibTarget*`; return codes 0/1/3, never 2). setup-user-* and user-scope tool scripts refuse with ERROR when privileged and HOME is not the run user's; only launchers switch user. Linux target user: non-root = self; root + SUDO_USER = SUDO_USER; root without SUDO_USER = root; `--user` overrides; never guess UID>=1000. | RevLib 3, RevSetup 1, RevTools Q1, PkgLinux 4 |
| BP-11 | **Personalisation per fleet user at run time, never in the package.** v1: shared-only mode with a neutral fleet template (no Jose identity, tokens resolved from OS identity or left with a single WARN), harness-only content tiered later. A user with a dotprofile runs `aitools user init` interactively (dev path) once; after that the package user phase uses it. Fleet content tiers (fleet vs harness hooks/skills/MCP) and an org profile are proposed (section 4). | RevSetup 3, Q1-Q2; RevLib Q3; RevBuild Q-B1 |
| BP-12 | **Updates (Q4):** one version string for all kinds = the aitools release version (`--version` flag; fix the PS stamp no-op first). Intune Win32: new .intunewin + supersedence, detection on HKLM Version (A) and a user-state script (B). Intune macOS: pkg `--version` + stub app `CFBundleShortVersionString` bumped together, "Ignore app version" = No. Jamf: new package + policy "Once per computer" scoped by a Smart Group on an extension attribute reading `/Library/Application Support/aitools/VERSION`. Linux: new .deb via apt; clouds: the setup/install script pins the version (cache rebuild on change). Package mode never self-updates from git. | PkgWin 3, PkgMac 2/3, PkgLinux 5, RevInstall Q2 |
| BP-13 | **Q5 (overwrite on recurring runs): yes for managed files, with backups (current spec F6), but runs happen per version, not per schedule** (Win32 reruns only on failed detection or update; Jamf once per computer per version; the LaunchAgent and aitools-setup skip when `~/.aitools/pkg-version` equals the payload VERSION). Fix the backup-every-run and user-owned-field resets (RevSetup 4) so recurring runs do not rotate useful backups away. Document the overwrite for users. | RevSetup 4, RevLib 7, PkgWin Q5 inference |
| BP-14 | **Q6 (winget scope): the winget CLI never runs in SYSTEM** (unsupported by Microsoft). Machine-wide tools are separate Intune apps (BP-8). In the user phase every winget call passes `--scope user --exact --source winget` where the package supports it; per-tool scope is decided through `/tool-eval` and recorded per method in the registry (schema field proposed). | PkgWin 5 (verbatim, re-verified by orchestrator via WebFetch), RevTools 5 |
| BP-15 | **Detection rules:** Win A: registry `HKLM\SOFTWARE\aitools` `Version` equals X.Y.Z. Win B: script detection reading `%USERPROFILE%\.aitools\pkg-version` (run-as-user behaviour to be tested on a device). Intune macOS: stub app `tech.nobul.aitools` at X.Y.Z. Jamf: receipt `pkgutil --pkg-info tech.nobul.aitools` + EA. Linux: `dpkg-query -W -f='${Version}' aitools`. | PkgWin 4/7, PkgMac 2/3, PkgLinux 7 |
| BP-16 | **Logging:** build-package → `~/.aitools/logs/deploy.log` via `logging_init` (v1; own `build-package.log` later). Launchers' root/SYSTEM phase → `AITOOLS_LOG_DIR` set to `/Library/Logs/aitools`, `C:\ProgramData\aitools\logs`, `/var/log/aitools`; user phase → `~/.aitools/logs` (unchanged standard). logging.md gets one sentence for the system-phase location (PR #101 owns logging.md: pending draft). | Lang 3, RevLib 4/Q4, PkgWin 5 |
| BP-17 | **Identifier `tech.nobul.aitools`** (pkg id, stub bundle id, LaunchAgent label prefix, Linux package name `aitools`, Windows HKLM key `SOFTWARE\aitools`). | PkgMac Q1 |
| BP-18 | **Supported platforms/environments, one authoritative location:** a new section "Supported platforms and environments" in `reference/cross-platform-detail.md` (not owned by any open PR). Platforms: macOS (Apple Silicon; Intel best-effort), Windows 11, Linux = Ubuntu 24.04 and 22.04. Environments: `local`, `claude-code-web` (Ubuntu 24.04 VM), `cursor-cloud` (proposed value, Ubuntu). Other docs point to it. | DocsInv 3 (adjusted: its preferred host cross-platform.md is owned by #99) |
| BP-19 | **Cursor cloud environment value `cursor-cloud` (proposed):** set explicitly as `AITOOLS_ENVIRONMENT=cursor-cloud` by the `.cursor/environment.json` install command; secondary signal (proposed, preview API): `${CURSOR_AGENT_SOCKET:-/run/cursor/api.sock}` exists on Linux. Lib change after the lib-owning PRs merge. | PkgLinux 5, RevLib 1, DocsInv |
| BP-20 | **Signing:** unsigned in v1; build gates expect `pkgutil --check-signature` exit 1. Signing/notarization (Developer ID Installer, Authenticode) is a later optional batch. | Commander; PkgMac test build |

## 2. Batch IDs (shared by implementation-plan.md and remediation.md)

Each batch is 2-3 files (plan-execution.md); split with a letter suffix if
needed (B3a, B3b). "After" = merge dependency.

| Batch | Scope | After |
|-------|-------|-------|
| B0 | This mission: docs, scaffolding (`scripts/build-package.sh` stub, `packaging/` skeleton) | -- |
| B1 | Approvals and evaluations (no code): cross-platform.md exemption rows; IntuneWinAppUtil `/tool-eval` + Phase 2 gate; `cursor-cloud` value; fleet content tiers; build-host tool class (tool-lifecycle) | -- |
| B2 | `build-package.sh stage` (git archive at ref → staging, MANIFEST, BUILD-INFO, `._*`/xattr hygiene) + tests/build-package/ | B0 |
| B3 | Installer package mode: `--phase`, `--package-mode`, unknown flag exits 1 (not 0, and never 2, which means user abort per D-TS13), single order file read by installer and `scripts/aitools` | #106, #116 |
| B4 | deploy-harness manifest source (no git work tree required in package mode) | #100, #110, #111 |
| B5 | Lib: target-user API (BP-10), privileged-run guard, logging fail-safe, `cursor-cloud` (BP-19), HOME-unset safety | #103, #112, #113, #115, #116 |
| B6 | setup-user-* fleet/root fixes (SHELL under set -u, no-dotprofile template, adopt disabled for read-only payload, backups every run, cursor model reset, hooks settings.json backup) | FAN-PLAN, #109, #110, #112, #114 |
| B7 | Tool scripts: sudo guards, `--scope user`, Linux methods for uv/go/typst/pwsh/node (via `/tool-adopt`, M2) | B5 |
| B8 | macOS backend: `build_pkg` + `packaging/macos/` (postinstall, runner, LaunchAgent, stub app) | B2, B3 |
| B9 | Windows backend: `build_intune` + `packaging/windows/` (install-system, install-user, detect-user, uninstall) | B1 (Phase 2), B2, B3 |
| B10 | Linux backend: `build_deb` + `packaging/linux/` (control, postinst, prerm, aitools-setup) + cloud setup snippets | B2, B3 |
| B11 | CI workflow `.github/workflows/package.yml` (3 jobs) + check-pre-push step 11 (`stage` only, isolated HOME) | B2, B8-B10; check.yml PRs |
| B12 | Test matrix runs (Ubuntu 22.04/24.04 container + VM, Claude Code web, Cursor cloud, macOS VM with Intune and Jamf, Windows VM with Intune) | B8-B11 |
| B13 | Apply pending doc drafts to PR-owned files (cross-platform.md, deploy-paths.md(.mdc), claude-shared.md, decision tree, logging.md, glossary) | each owning PR |
| B14 | Optional: signing/notarization | B12 |

## 3. Files owned by open PRs (do not edit; draft instead)

cross-platform.md, deploy-paths.md, deploy-paths.mdc (#99);
interactive-menus.md/.mdc (#106); managed-file-deployment.md/.mdc,
logging.md, script-standards-detail.md, user-repo.md, glossary.json,
tool-support-decision-tree.md, plans/tool-support-and-machine-profile.md
(#101/#106); reference/managed-file-deployment.md (#99/#106);
shared/claude-shared.md (#105); check.yml (#103 #112 #113 #115 #116); every
script except build-package.sh and the new packaging/ files (see the
mission's PR file list). Source: `gh pr list --json files`, 2026-10-26.

## 4. Proposed (commander decisions needed), each with a suggested answer

- P-1 Approve the two cross-platform.md rows (build-package.sh bash-only build script; package launchers category). Suggested: approve.
- P-2 Environment value `cursor-cloud` with BP-19 signals. Suggested: approve; verify on one Cursor cloud run.
- P-3 Fleet content tiers (`tier: fleet|harness` on hooks, skills, MCP) and a neutral fleet template. Suggested: approve; standing-order-guard and failure-mode hooks stay `harness`.
- P-4 IntuneWinAppUtil as a build-host tool (registry entry, `/tool-eval`, Phase 2) and a new "build-host tool" lifecycle class. Suggested: approve.
- P-5 Intel Macs unsupported on the package path in v1 (dev path unchanged). Suggested: approve.
- P-6 Dotprofile for fleet users: interactive `aitools user init` once vs a run-time fetch. Suggested: interactive once in v1.
- P-7 Personal "I work on both Windows 11 and macOS" line in the dotprofile template: Jose's choice. Suggested: update to the five-item form.
