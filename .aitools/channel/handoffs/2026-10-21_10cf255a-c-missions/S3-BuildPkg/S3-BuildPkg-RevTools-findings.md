# S3-BuildPkg-RevTools: run-context review of the managed-tool setup scripts

Author: S3-BuildPkg-RevTools (level 2, delegated by S3-BuildPkg). Date: 2026-10-26.
Read-only review. Nothing was run except read-only `grep`, `gh issue view`, and a scratch
registry summarizer (`.scratch/session-rvtools/reg-summary.py`, read-only `json.load`).

## Summary (5 lines)

1. All 14 tool script pairs (28 files) are user-context installers: every macOS path but rustup needs Homebrew (refuses root), Windows paths call bare `winget` with no `--scope` (47 lines matching `winget install|upgrade|list` in 7 setup .ps1, calls plus log/help text; 13 actual install/upgrade calls listed in R2), and every per-user path (`~/.cargo`, `~/.local/bin`, `~/.cursor`, User PATH) follows whoever runs the script.
2. Nothing in the scripts, the library, the registry schema or the decision tree records or checks run context (elevation, root/SYSTEM, console user): `Test-IsAdmin` exists in aitools-lib.ps1 with zero callers, and only setup-google-chrome.sh checks `id -u`.
3. Linux today: gh, pandoc and google-chrome have apt paths; perl and bash only verify; vercel needs npm; uv, go (fresh), typst have no Linux path (ERROR "Homebrew not found"), which cascades to python and modal; datadog falls back to cargo. The registry claims `linux: supported` for all of them.
4. Prerequisites outside any setup script: Homebrew and git (bootstrap.sh only, interactive), git on Windows (bootstrap.ps1), node and Claude Code (installer inline Steps 8-9; Linux node = WARN only), Cursor CLI (setup-user-cursor), pwsh (Windows Git-Bash forwarding only; never on macOS/Linux), Cursor IDE (nothing).
5. Q6 suggestion: never rely on winget's default scope. A Windows System app installs machine-wide prerequisites with an explicit `--scope machine` (or vendor MSI); a Windows User app runs everything else as the signed-in user with `--scope user`; macOS ships root-only prerequisites (Homebrew, git/CLT, pwsh, node) as vendor .pkg files and runs aitools as the console user.

---

## 1. Per-tool run-context table

Legend: "user ctx" = writes per-user state (HOME, `%USERPROFILE%`, HKCU) so it must run as the target user. "root/SYSTEM" = would it work correctly (for the intended user) under an MDM agent. Scope column for Windows: the scripts never pass `--scope`; the "known scope" note is what the code itself assumes, else "unknown" (the registry has no scope field; see section 4).

| Tool | macOS method | Windows method (winget id, scope flags) | Linux method today | Needs elevation? | Needs user ctx? | Works as root/SYSTEM? | Citation |
|---|---|---|---|---|---|---|---|
| bash | `brew install bash` (Homebrew required, else ERROR + exit 1) | none: detection only, Git for Windows at `C:\Program Files\Git\bin\bash.exe`, `C:\Program Files (x86)\...`, `%LOCALAPPDATA%\Programs\Git\bin\bash.exe`; advises `winget upgrade Git.Git` | verify `bash >= 5.0` only; below = WARN + ACTION with `sudo apt-get install -y bash` text (no install) | macOS no (brew must NOT be root); Windows n/a; Linux would need sudo to upgrade | macOS yes (brew is per-user-owned prefix) | macOS: no (Homebrew refuses root, MDM-PKG F5). Windows: yes (detection only; LOCALAPPDATA path is SYSTEM's profile, misses a per-user Git). Linux: yes (verify only) | setup-bash.sh:56-104 (Darwin), :106-126 (Linux); setup-bash.ps1:27-49 |
| datadog (pup) | `brew install datadog-labs/pack/pup`; migrates old tap; fallback `cargo install --git ...` when brew missing or fails (fallback removed by T-Q4, not yet in code) | `cargo install --git https://github.com/datadog-labs/pup` (no winget); CMake auto-install via `uv tool install cmake` | no brew on Linux -> cargo fallback (needs rust + C toolchain); registry says Linux preferred = homebrew | no (brew), no (cargo) | yes: `~/.cargo/bin`, `%USERPROFILE%\.cargo\bin`, uv tool dir | macOS root: brew fails; cargo fallback would build into `/var/root/.cargo`. Windows SYSTEM: builds into systemprofile `.cargo` (wrong user). Linux root container: works into `/root/.cargo` if cargo exists | setup-datadog.sh:108-162 (fallback 126-161); setup-datadog.ps1:20-63, :75, :107 |
| gh-cli | `brew install gh` / `brew upgrade gh` (Homebrew required, exit 1) | `winget install --source winget --exact --id GitHub.cli`; `winget upgrade --exact --id GitHub.cli`; no `--scope`; known scope unknown | YES: cli.github.com apt repo + keyring via `sudo`, then `sudo apt-get install -y gh`; non-apt = ERROR | Linux: sudo (unconditional `sudo`, fails where sudo absent, e.g. minimal root container); Windows: unknown | no state written by install; auth (`gh auth login`) is per-user (installer Step 2) | macOS root: no (brew). Windows SYSTEM: unknown (depends on winget availability under SYSTEM and installer scope). Linux root: only if `sudo` binary exists | setup-gh-cli.sh:47-54 (`add_github_cli_apt_repo`), :58-101, :103-153; setup-gh-cli.ps1:29, :46 |
| go | `brew install go`; replaces pkg/manual `/usr/local/go` with `sudo rm -rf` after verify; goenv kept | `winget install GoLang.Go` / `winget upgrade GoLang.Go` (no `--exact`, no `--scope`); provenance assumes MSI under `\Program Files\Go\` (machine location); chocolatey uninstall attempted | keeps go.dev tarball at `/usr/local/go` (OK); a fresh Linux box with no Go = ERROR "Homebrew not found" (no Linux install path) | macOS: sudo for the cleanup only; Windows: machine MSI location implies elevation (unknown whether winget elevates) | yes: GOPATH/bin -> User PATH (Windows `[Environment]::SetEnvironmentVariable(...,"User")`), session PATH only on macOS/Linux | macOS root: no (brew). Windows SYSTEM: Go itself plausibly (machine MSI, unverified), but GOPATH PATH lands in SYSTEM's HKCU and `%USERPROFILE%\go`. Linux: verify-only works; install does not exist | setup-go.sh:28-118 (sudo rm :104); aitools-lib.sh:`detect_go_provenance`, `ensure_gopath_bin_on_path`; setup-go.ps1:19, :52, :103; aitools-lib.ps1:`Get-GoProvenance`, `Ensure-GopathBinOnPath` |
| google-chrome (+ nss-tools) | n/a (environment skip) | n/a: `Write-EnvironmentSkip` only | Claude Code web only: download Google .deb, `apt-get install` (no sudo), `libnss3-tools`, import proxy CA into `$HOME/.pki/nssdb`; any other Linux environment = n/a row | requires root: ERROR "requires root" if `id -u` != 0 | NSS store is `$HOME/.pki/nssdb` of the running user (root in CC web) | Linux root: yes, designed for it. Ubuntu VM / Cursor cloud: n/a today (D-CHR1) | setup-google-chrome.sh:162-172 (gates), :48-53 (paths); setup-google-chrome.ps1:21 |
| modal | `uv tool install/upgrade modal`; else `pip install --user modal` (fallback removed by T-Q4, not yet in code) | same; plus `python -m pip install --user`; writes Python user Scripts to User PATH | same as macOS (works if uv exists; uv has no Linux path, so only pip --user remains) | no | yes: uv tool dir / `~/.local/bin`, `~/.modal.toml` auth, User PATH | root/SYSTEM: installs into root's/SYSTEM's profile (wrong user); auth file checked in that HOME | setup-modal.sh:62-149; setup-modal.ps1:22-36, :98-193 |
| pandoc | `brew install pandoc`; migrates conda/MacPorts (`sudo port uninstall`)/cabal | `winget install --source winget --exact --id JohnMacFarlane.Pandoc`; scope unknown | YES: `sudo apt-get update -qq && sudo apt-get install -y pandoc` (distro version) | Linux: sudo (unconditional); macOS: sudo only for MacPorts cleanup | no (binary only) | macOS root: no (brew). Windows SYSTEM: unknown. Linux root: only if `sudo` exists | setup-pandoc.sh:44-143, :145-169; setup-pandoc.ps1:29, :58 |
| perl | present -> version check only; absent -> `brew install perl` | `winget install --exact --id StrawberryPerl.StrawberryPerl`; known path `C:\Strawberry\perl\bin\perl.exe` (verified 2026-03-12) = machine location | verify only; absent = ERROR + ACTION (no install); T-Q5 "update" not implemented | Windows: `C:\Strawberry` suggests elevation (unknown); macOS: no | no | macOS: yes in practice (system `/usr/bin/perl` always present, so brew is never reached). Windows SYSTEM: plausibly (machine path; unverified). Linux: verify only | setup-perl.sh:40-106; setup-perl.ps1:41, :49-51 |
| python | `uv python install 3.14 --default [--upgrade] --preview-features python-install-default` | same (uv from winget) | same command, but uv has no Linux path, so ERROR "uv not installed" | no | yes: shims in `~/.local/bin` / `%USERPROFILE%\.local\bin`; uv's Python store in HOME | root/SYSTEM: installs into root's/SYSTEM's HOME (wrong user) | setup-python.sh:31-92; setup-python.ps1:34-93 |
| rust (cargo) | `curl ... https://sh.rustup.rs \| sh -s -- -y`; removes Homebrew `rust` formula | `winget install -e --id Rustlang.Rustup`; checks `%USERPROFILE%\.cargo\bin\cargo.exe`; NASM `winget install -e --id NASM.NASM` (user scope `%LOCALAPPDATA%\bin\NASM`, verified 2026-03-12); MSVC Build Tools only warned (machine, admin); `.cargo\bin` must be in persistent PATH | same rustup script (works); no check for a C linker (build-essential) | no for rustup; MSVC Build Tools need admin (not installed) | yes: `~/.cargo`, `~/.rustup`, rustup edits the running user's shell profile | root: installs to `/var/root/.cargo` (macOS) or `/root/.cargo` (Linux), works for root only. SYSTEM: systemprofile `.cargo` | setup-rust.sh:25, :44-82; setup-rust.ps1:20-64, :66-85, :87-132, :134-142 |
| typst | `brew install typst` (no Homebrew presence check); removes cargo `typst-cli`, npm `typst` | `winget install --id Typst.Typst` / `winget upgrade --id Typst.Typst` (no `--exact`, no `--scope`); scope unknown | NONE: script has no OS branch, calls `brew` on Linux -> ERROR (issue #14) | no | no (binary), but cleanup touches user cargo/npm | macOS root: no (brew). Windows SYSTEM: unknown. Linux: no | setup-typst.sh:39-104; setup-typst.ps1:60, :83 |
| uv | `brew install uv` / `brew upgrade uv`; non-brew uv kept (WARN) | `winget install --id=astral-sh.uv -e` / `winget upgrade --id=astral-sh.uv`; scope unknown; persistent PATH check | NONE: "Homebrew-only until Linux support lands (#14)"; existing non-brew uv kept as WARN, fresh = ERROR | no | install dir unknown on Windows; consumers (python, modal) are user ctx | macOS root: no. Windows SYSTEM: unknown. Linux: only an existing uv | setup-uv.sh:5-7, :25-88; setup-uv.ps1:26, :47, :65-73 |
| vercel-cli | `brew install vercel-cli`; migrates from npm (`npm uninstall -g vercel`) | `npm install -g vercel` (no winget); persistent PATH check of npm prefix | `npm install -g vercel`; requires node (installer does not install node on Linux) | Linux: `npm -g` into a root-owned prefix needs root (not handled); Windows: unknown | yes: npm global prefix and `vercel login` auth are per-user | macOS root: no. Windows SYSTEM: installs into SYSTEM's npm prefix (wrong user, unverified). Linux root container: yes | setup-vercelcli.sh:51-132, :134-165, :169-178; setup-vercelcli.ps1:39-91 |
| cursor-ide-mcp (config, not a tool) | node merge into `~/.cursor/mcp.json`; `agent mcp remove vercel/webflow` | PowerShell merge into `%USERPROFILE%\.cursor\mcp.json`; `agent mcp disable vercel/webflow` (ERROR on failure) | same as macOS; CC web adds `--headless --chromeArg=--no-sandbox` | no | YES: entirely per-user config | root/SYSTEM: writes root's/systemprofile's `.cursor` (wrong user) | setup-cursor-ide-mcp.sh:51-56, :59-161, :194-209; setup-cursor-ide-mcp.ps1:37-43, :46-52, :169-178 |

Notes on the table:
- Every one of these scripts ships into the MDM `deploy/` unchanged apart from the inlined library (scripts/build-deploy.sh:912-1175), so every row applies to the MDM path as is.
- The decision tree says the installer skips tool setup scripts on the MDM path "today" (reference/tool-support-decision-tree.md section 7.5, last bullet). I did not verify that claim; build-deploy.sh does generate all 28.
- Homebrew refusing root comes from MDM-PKG F5 (S3-MdmPkg-report.md:89, Critic via WebFetch, "not re-checked in a real browser"). Unverified here too.
- Winget behaviour under SYSTEM (whether `winget` resolves on PATH, whether user-scope installers land in `C:\Windows\System32\config\systemprofile`) is not documented in the repo: unknown. Every script calls bare `winget` by name.

## 2. Harness prerequisites not installed by any setup script

| Prerequisite | macOS | Windows | Linux | Citation |
|---|---|---|---|---|
| Homebrew | bootstrap.sh only: official `install.sh` via `/bin/bash -c "$(curl ...)"` (interactive; needs a user with sudo) | n/a | none (issue #10 plans `setup-brew`, skipped as root) | bootstrap.sh:31-41; issue #10 "Decisions" |
| git | bootstrap.sh: `brew install git` if missing | bootstrap.ps1: `winget install --id Git.Git --source winget` (no `--scope`) | bootstrap.sh: `sudo apt-get install -y git curl` or `sudo dnf install -y git curl` | bootstrap.sh:42-55; bootstrap.ps1:21-30. Not in the registry |
| Git Bash (bash on Windows) | n/a | comes with Git for Windows; setup-bash.ps1 only detects | n/a | setup-bash.ps1 |
| pwsh 7 | NOTHING installs it (only a hint in check-lib.sh:200 and build-deploy.sh:2279) | aitools-install.sh Windows forwarding: `powershell.exe ... winget install --id Microsoft.PowerShell --source winget` (no `--scope`). bootstrap.ps1 launches `aitools-install.ps1` with `powershell` (5.1) and never installs pwsh | NOTHING; registry `install.linux: []` | aitools-install.sh:96-116; bootstrap.ps1:48 |
| node | installer Step 8 inline: `brew install node@22` (keg-only, handoff G19) | Step 8 inline: `winget install OpenJS.NodeJS.LTS` (no `--exact`, no `--scope`) | Step 8: WARN "install manually" only; registry method `nodesource-or-nvm`, command null | aitools-install.sh:609-640; aitools-install.ps1:543-564 |
| Claude Code CLI | Step 9 inline: `curl -fsSL https://claude.ai/install.sh \| bash` (user, `~/.local/bin`) or `claude update` | Step 9 inline: `irm https://claude.ai/install.ps1 \| iex` (registry: "No Administrator needed") | Step 9 inline: same as macOS | aitools-install.sh:646-679; aitools-install.ps1:570-608 |
| Cursor Agent CLI (`agent`) | setup-user-cursor.sh Step 2: `curl https://cursor.com/install -fsS \| bash` | setup-user-cursor.ps1: `irm 'https://cursor.com/install?win32=true' \| iex` | same as macOS | setup-user-cursor.sh:115-149; setup-user-cursor.ps1:129 |
| Cursor IDE | NOTHING (no installer, no registry entry) | NOTHING | NOTHING | grep for `anysphere` / `Cursor.Cursor` in scripts/: no hits |
| MSVC Build Tools (Windows, for cargo) | n/a | warned only (`winget install Microsoft.VisualStudio.2022.BuildTools` text) | n/a (C linker for cargo not checked) | setup-rust.ps1:66-85 |
| Windows LongPathsEnabled (HKLM) | n/a | checked; ACTION "run as admin" (cannot be set by a user run) | n/a | aitools-install.ps1:219-239 |

All prerequisites except Homebrew run in user context today. Node, pwsh and git on Windows go through winget with the default scope.

## 3. Linux and environments: what the decision tree and plan say, and the gaps

What exists (reference/tool-support-decision-tree.md):
- Platform values `macos`, `linux`, `windows`; on Linux the package-manager family (`apt`, `dnf`) also selects methods (section 1 "platform", section 6 `.family`).
- Environment values are only `local` and `claude-code-web` (section 1 "environment"; aitools-lib.sh environment block lines 41-52 force `local` off Linux).
- Node T0 reads `lifecycle.environments.<env>.status` for non-local environments (google-chrome uses it).
- Node P: `system` / `bundled` kinds absent -> PREREQ `not provided by <platform or environment>` / `not in <env> image` (section 3).
- T-Q4: no fallback methods; a missing manager is a PREREQ ERROR + ACTION.
- Registry kinds include `apt`, `dnf`, `deb-url`, `script-url` (section 6), but no field says whether a method needs root.
- The plan (plans/tool-support-and-machine-profile.md) has no Linux-specific or run-context decision; S2L-Q4 touches Claude Code web skills only.

Gaps for Ubuntu 22.04/24.04 (containers and VMs):
1. No Linux install method for uv, go (fresh), typst, pwsh, node in either the registry (`install.linux: []` or `command: null`) or the scripts, while `platformStatus.linux = "supported"` for all (registry; issue #19 "registry claims unverified support"). Python and modal fail as a cascade of uv.
2. Datadog Linux: registry preferred method is Homebrew (`brew install datadog-labs/pack/pup`), which refuses root and is absent in containers; the script uses cargo instead (setup-datadog.sh:9, :126). Registry and script disagree.
3. Privilege: gh and pandoc call `sudo` unconditionally (setup-gh-cli.sh:48-52, :135; setup-pandoc.sh:153). A root container without the `sudo` binary fails; a non-root VM run with no tty and no NOPASSWD sudo hangs or fails. setup-google-chrome.sh instead requires root and calls apt-get directly. There is no shared `as_root` helper (issue #14 proposes `as_root`, `detect_pkg_manager`, `install_release_binary`; none exist, and decision-tree section 7.2 notes `install_via_apt` does not exist).
4. apt freshness: pandoc uses the distro package. Evaluation principle 3 (latest stable) and issue #10 ("distro packages only when they track latest stable") argue against it; 22.04 and 24.04 ship different pandoc versions (exact versions not verified here). One Linux package for both releases must not depend on distro versions of managed tools.
5. Stale apt lists: setup-gh-cli.sh installs `wget` before any `apt-get update` (line 48); a fresh container's empty lists can fail it. setup-google-chrome.sh already retries after `apt-get update` (`apt_install`).
6. node on Linux is a WARN only (aitools-install.sh:635-637), but vercel (npm) and cursor-ide-mcp (node) need it, so they ERROR on a fresh Ubuntu.
7. perl/bash on Linux verify only; T-Q5 says the harness updates them below minVersion. Not implemented (setup-perl.sh:87-106, setup-bash.sh:106-126).
8. HOME targets: as root (CC web, an MDM agent, or `sudo aitools`) every per-user path lands in `/root`. In CC web that is correct (the session user is root); in a VM provisioned by root it is wrong. No script resolves the target user.

Gaps for Cursor cloud:
- No environment value, no detection signal, no `lifecycle.environments.cursor-cloud` entries. The value list is closed (`claude-code-web` | `local`, S3-BuildPkg brief "Operational learning"). Detection mechanism: unknown (not in the repo).
- Whether Cursor cloud runs as root, has sudo, has a proxy CA (as CC web does for Chrome), or reclaims the container: unknown.

## 4. Q6: winget scope under SYSTEM (suggested answer)

Facts from the repo:
- No setup script, installer or bootstrap passes `--scope` (grep of scripts/ for `--scope`: only `claude mcp ... --scope user`, unrelated).
- The registry has no scope or elevation field, so machine-scope availability per winget id is not recorded anywhere: unknown for GitHub.cli, GoLang.Go, JohnMacFarlane.Pandoc, StrawberryPerl.StrawberryPerl, Rustlang.Rustup, NASM.NASM, Typst.Typst, astral-sh.uv, OpenJS.NodeJS.LTS, Microsoft.PowerShell, Git.Git. The way to settle each is `winget show --id <id> --exact` (installer type and Scope per installer) during a `/tool-eval` trial on Windows, recorded in the registry.
- Code-level hints only: Go is detected under `\Program Files\Go\` (machine location, aitools-lib.ps1:`Get-GoProvenance`); Strawberry Perl at `C:\Strawberry` (setup-perl.ps1:50); NASM at `%LOCALAPPDATA%\bin\NASM` "winget user-scope" (setup-rust.ps1:94); Git Bash at both Program Files and `%LOCALAPPDATA%` (setup-bash.ps1:27-31); Claude Code native "No Administrator needed" (registry).

Suggested approach:
1. Always pass an explicit `--scope` (and `--exact`, `--source winget`): the default depends on each manifest, so the same command can install per-user on one id and per-machine on another. Record the chosen scope per method in the registry (new field, protected; `/tool-eval` + `/tool-registry`), and have the decision tree's `tool_install` / `Install-ToolMethod` render it.
2. Windows System app (Intune Win32, SYSTEM, machine scope), only for tools whose files are per-machine and hold no per-user state, each confirmed by `winget show` to have a machine installer: Git for Windows (+ Git Bash), PowerShell 7, Node.js LTS, Go, Strawberry Perl, and candidates pending the scope check: gh, pandoc, typst, uv. Also MSVC Build Tools and HKLM LongPathsEnabled, which a user run cannot do. Under SYSTEM, resolving `winget.exe` itself is a separate unknown to test (it is an App Installer package, and the scripts call it by name).
3. Windows User app (signed-in user, no elevation), `--scope user` where winget is used: rustup/cargo and anything built with cargo (pup), uv tools (modal, cmake), uv python, vercel (npm -g into the user's prefix), NASM (verified user scope), Claude Code, Cursor CLI, GOPATH PATH entry, gh auth, all `setup-user-*` and `setup-cursor-ide-mcp`. The User app depends on the System app (Intune app dependency).
4. Tools to ship as MDM prerequisites outside aitools rather than via aitools scripts:
   - macOS: Homebrew (it refuses root and needs an owner user; vendor .pkg availability unknown, check Homebrew's releases), git (Xcode Command Line Tools or Homebrew), PowerShell 7 (Microsoft .pkg), Node.js (nodejs.org .pkg, which also avoids the keg-only `node@22` issue G19). Then the PKG postinstall runs aitools as the console user (`sudo -u <user> -H`, MDM-PKG report line 105), where the brew-based scripts work unchanged.
   - Windows: Git for Windows, PowerShell 7, Node.js LTS as vendor MSI/winget machine scope in the System app (bootstrap.ps1 cannot run under SYSTEM: it launches the installer with `powershell` 5.1 and installs no pwsh).
   - Linux: the .deb's `Depends`/`Pre-Depends` (git, curl, perl, bash, ca-certificates) plus vendor apt repos for gh (cli.github.com) and node (NodeSource or another `/tool-eval` choice); user-level tools (uv, rustup, claude, cursor agent) installed per user after.
5. Do not install user-scope tools from SYSTEM or root "on behalf of" the user: they land in the wrong profile (systemprofile, `/var/root`, `/root`).

## 5. Remediations

| # | File:function / location | Severity | Fix direction |
|---|---|---|---|
| R1 | registry schema (`/tool-registry`), decision tree section 6 | high | Add per-method `scope` (user/machine) and `requiresRoot` (or `privilege`) fields; T1/P read them; INCIDENT below |
| R2 | all setup-*.ps1 winget calls (setup-gh-cli.ps1:29,46; setup-go.ps1:52,103; setup-pandoc.ps1:29,58; setup-perl.ps1:41; setup-rust.ps1:44,116; setup-typst.ps1:60,83; setup-uv.ps1:26,47) + aitools-install.ps1:550, aitools-install.sh:100, bootstrap.ps1:26 | high | Render winget commands from the registry with explicit `--scope`, `--exact`, `--source winget` (via `Install-ToolMethod`), never hand-written |
| R3 | aitools-lib.ps1:`Test-IsAdmin` (no callers); aitools-lib.sh (no equivalent) | high | Add a run-context API (`is_root` / `Test-IsSystem`, console-user resolution) and gate each script: user-scope script under root/SYSTEM = ERROR "run as user", not a silent install into the wrong profile |
| R4 | setup-gh-cli.sh:`add_github_cli_apt_repo` and :135; setup-pandoc.sh:153 | high | Replace unconditional `sudo` with an `as_root` helper: run directly as uid 0, `sudo -n` otherwise, PREREQ ERROR when neither works |
| R5 | setup-typst.sh (whole body), setup-uv.sh:71-88, setup-go.sh:77-79 | high | Linux install methods via `/tool-eval` (issue #14); until then report EVALUATING/NO-METHOD per the tree instead of calling brew; set registry `linux` status to `evaluating` (issue #19) |
| R6 | registry `datadog-pup.install.linux` vs setup-datadog.sh:9,126 | medium | Align: registry says Homebrew (unusable as root), script uses cargo; pick one via `/tool-eval`; remove the macOS/Linux cargo fallback (T-Q4) |
| R7 | setup-modal.sh:129-145, setup-modal.ps1:150-189 | medium | Remove pip fallback (T-Q4); PREREQ ERROR when uv absent |
| R8 | aitools-install.sh:635-637 (Step 8 Linux) | high | Install node on Linux by a registry method (or declare it a .deb dependency); today vercel and cursor-ide-mcp ERROR on fresh Ubuntu |
| R9 | pwsh: no installer on macOS/Linux; bootstrap.ps1:48 runs `powershell` 5.1 | medium | Decide whether pwsh is required on macOS/Linux; ship it as a prerequisite; bootstrap.ps1 must install and use pwsh (already noted in tree section 7.5) |
| R10 | setup-cursor-ide-mcp.sh:194-209 vs setup-cursor-ide-mcp.ps1:169-178 | medium | Parity bug: .sh uses `agent mcp remove` (WARN on failure), .ps1 uses `agent mcp disable` (ERROR on failure); the .sh comment says `disable` no longer exists. Make the .ps1 match |
| R11 | setup-cursor-ide-mcp.sh:51-53, setup-cursor-ide-mcp.ps1:37-39 | low | `exit 1` without `write_summary` when node is missing (script-standards: every path writes a summary row) |
| R12 | setup-go.sh:104 (`sudo rm -rf`), setup-pandoc.sh:104 (`sudo port uninstall`) | medium | Non-interactive `sudo` can hang under MDM/CI; use `sudo -n` or the tree's guarded `tool_remove` (section 7.3, interactive-only sudo) |
| R13 | setup-gh-cli.sh:48 | low | Run `apt-get update` before installing wget on a fresh container (reuse the retry pattern of setup-google-chrome.sh `apt_install`) |
| R14 | setup-rust.ps1:66-85, aitools-install.ps1:219-239 | medium | MSVC Build Tools and LongPathsEnabled need admin: move to the Windows System app; keep the user scripts' checks as PREREQ |
| R15 | setup-perl.sh:87-106, setup-bash.sh:106-126 | low | Implement T-Q5 on Linux (update via apt) or record perl/bash as `system` kind with a .deb dependency |
| R16 | aitools-lib.sh environment block (lines 41-52), aitools-lib.ps1 equivalent | medium | Add a decided environment value and detection for Cursor cloud (needs a commander decision; suggested `cursor-cloud`) |
| R17 | setup-go.ps1:52,103; setup-typst.ps1:60,83 | low | Add `--exact` to winget calls (the others have it); a non-exact id can match another package |
| R18 | registry `datadog-pup.lifecycle.platformStatus.windows = "supported (source build)"` | low | Value outside the tree's enum (section 6); move the note elsewhere |

## INCIDENT markers (not filed)

- INCIDENT: No spec (decision tree, registry schema, script-standards) defines the run context (user vs root/SYSTEM, elevation) a managed-tool setup script needs, or what a script does when run in the wrong one; `Test-IsAdmin` exists with zero callers (aitools-lib.ps1). Governance ambiguity, high.
- INCIDENT: Registry marks `linux: supported` for uv, go, typst, pwsh and node with no Linux install method (`install.linux: []` or `command: null`), contrary to tool-evaluation-criteria "supported" (issue #19 already tracks it). Spec deviation, high.
- INCIDENT: setup-cursor-ide-mcp .sh/.ps1 disagree on `agent mcp remove` vs `agent mcp disable` and on failure severity (WARN vs ERROR). Spec deviation (cross-platform parity), medium.
- INCIDENT: setup-gh-cli.sh and setup-pandoc.sh call `sudo` unconditionally; behaviour in a root container without sudo and in a non-interactive non-root run is undefined. Spec deviation (external command error handling: PATH/prereq failure must be reported as PREREQ), medium.
- INCIDENT: Registry datadog Linux preferred method (Homebrew) contradicts setup-datadog.sh (cargo) and cannot work as root. Spec deviation, medium.
- INCIDENT: setup-cursor-ide-mcp exits 1 without a summary row when node is missing (both variants). Spec deviation (script-standards "Every code path must call write_summary"), low.

## Open questions (with suggested answers)

1. Should a user-scope setup script run under root/SYSTEM refuse (ERROR) or re-exec as the console user? Suggested: refuse in the script; the package's entry point (PKG postinstall, Intune User app) is the only place that switches user.
2. Is pwsh required on macOS/Linux? Suggested: no for running aitools (the .sh path never calls pwsh), yes only for check scripts' PS1 validation; keep it out of the Linux package.
3. One Linux .deb for 22.04 and 24.04? Suggested: yes, if managed tools come from vendor repos or user-level installers, never from distro package versions (pandoc today is the exception to fix).
4. Cursor cloud environment value? Suggested `cursor-cloud`, detection signal to be found by a `/tool-eval`-style trial in a Cursor cloud agent.

## WRITE_BLOCKED

None.

## Sources

All file:line citations are against the main checkout at commit 5976553 (2026-10-26). GitHub issues #10, #14, #19 read with `gh issue view <n> -R nobul-tech/aitools` on 2026-10-26 (all OPEN). Registry read through the `/tool-registry` skill procedure with the scratch summarizer.
