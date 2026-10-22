# Install Method Discovery Playbook

Step-by-step process for discovering and selecting install methods for managed tools
and build prerequisites. Referenced by `.claude/rules/tool-lifecycle.md`.

## Purpose

Every install command in the tool registry (`/tool-registry` skill), `BuildPrereqs` entries, and
`BuildFailureSignatures` remedies must be derived from official tool documentation --
never chosen from assumption or memory. This playbook defines the discovery process.

## Scope

- **Managed tools** in the tool registry (`/tool-registry` skill)
- **Build prerequisites** in `aitools-lib.ps1` (`$script:BuildPrereqs`) and `aitools-lib.sh` (`check_build_prereqs`)
- **Any dependency** where we specify install commands in code

## Discovery Steps

### Step 1: Read Official Documentation

Visit the tool's official website. Look for:
- Download page / Getting Started guide
- Platform-specific installation instructions
- Package manager listings (official, not third-party)
- Release page (GitHub Releases, direct downloads)

**Prefer chrome-devtools skill** for reading official docs -- WebFetch summarizes
via a smaller model and may miss install method details.

### Step 2: Catalog All Available Methods Per Platform

For each platform (macOS, Windows, Linux), list every install method mentioned in
official docs. Include methods we don't currently use.

Example (CMake, from cmake.org/download, verified 2026-03-12):

| Method | macOS | Windows | Linux |
|--------|-------|---------|-------|
| Homebrew | Yes | -- | -- |
| pip (PyPI) | Yes | Yes | Yes |
| MSI installer | -- | Yes | -- |
| ZIP archive | -- | Yes | -- |
| DMG | Yes | -- | -- |
| Self-extracting .sh | -- | -- | Yes |
| apt (Kitware repo) | -- | -- | Yes |
| snap | -- | -- | Yes |
| winget | -- | Not listed | -- |

### Step 3: Classify Each Method

Evaluate each method against these criteria (per-method, not ranked globally):

| Criterion | Weight | What to check |
|-----------|--------|---------------|
| **Official support** | Highest | Is this method recommended by the tool's docs? Maintained by the tool's team? |
| **Elevation requirement** | High | Does it need admin/sudo/UAC? Prefer user-level when officially supported |
| **Update model** | Medium | How are updates delivered? Package manager upgrade vs manual re-download |
| **PATH integration** | Medium | Automatically adds to PATH, or requires manual setup? |
| **Existing toolchain** | Medium | Do we already have the package manager? (uv, brew, winget are managed) |
| **Cross-platform** | Low | Same method on both platforms? Bonus, not required |

**Important**: There is no global hierarchy (pip > winget > ZIP). Different tools
have different best methods. NASM's best Windows method is winget (wraps official
Nullsoft installer). CMake's best Windows method is pip (cmake.org lists it, user-level).

### Step 4: Choose Best Fit Per-Tool

Select the method that scores best against the criteria FOR THIS SPECIFIC TOOL.
Document the rationale. If two methods are comparable, prefer the one that:
1. Requires less elevation
2. Uses a package manager we already have
3. Has a built-in update path

### Step 5: Trial Installation

Run the chosen method on the target platform as a sandbox walkthrough:

1. **Install** -- using the chosen method from Step 4
2. **Configure** -- any post-install config the tool requires
3. **Use** -- run the tool's primary function with a realistic input
4. **Break** -- test edge cases, bad input, missing dependencies
5. **Deinstall** -- verify clean removal via the package manager

Record results using this template:

```
## Trial: <Tool> on <Platform>
Date: YYYY-MM-DD
Method: <command>
Official source: <URL>
Result: success / failure
Installed path: <path>
Version: <output of --version>
Elevation needed: yes / no
PATH integration: automatic / manual
Notes: <any issues>
```

**Empirical verification is mandatory.** Do not ship install commands that haven't
been tested on the target platform. See KnownPaths verification rules in
`.claude/rules/script-standards.md`.

### Step 6: Document

Record in the tool registry (`/tool-registry` skill):
- Source URL (where docs were read)
- Chosen method per platform with rationale
- Trial installation results
- Known install paths (verified)

For build prerequisites, also update:
- `aitools-lib.ps1` `$script:BuildPrereqs` entry (with source comment)
- `aitools-lib.sh` `check_build_prereqs()` case block (with source comment)

## Completed Examples

### CMake (2026-03-12)

**Official source:** https://cmake.org/download/

**Discovery:** cmake.org/download lists pip, ZIP, MSI, DMG, self-extracting .sh,
apt (Kitware repo), snap. Does NOT list winget. PyPI package (`cmake` 4.2.3)
maintained by Jean-Christophe Fillion-Robin at Kitware (jcfr@kitware.com).
Source: https://pypi.org/project/cmake/

**Method selection:**

| Method | Official? | Elevation | Update | PATH | Toolchain |
|--------|-----------|-----------|--------|------|-----------|
| `uv tool install cmake` | Yes (cmake.org) | No (user-level) | `uv tool upgrade cmake` | `~/.local/bin` (on PATH) | uv already managed |
| `winget install Kitware.CMake` | No (not on cmake.org) | Yes (admin) | winget upgrade | Auto | winget already managed |
| MSI installer | Yes (cmake.org) | Yes (admin) | Manual | Auto | -- |
| ZIP archive | Yes (cmake.org) | No | Manual | Manual | -- |

**Chosen:** `uv tool install cmake` (Windows), `brew install cmake` (macOS)
**Rationale:** Official method per cmake.org, user-level install, uv already managed,
winget not listed on cmake.org and requires admin. `uv tool` preferred over `uv pip`
because it installs to `~/.local/bin` (already on PATH) vs Python Scripts dir (not on PATH).

**Trial (Windows, 2026-03-12):**
- Method: `uv tool install cmake`
- Result: success
- Installed path: `%USERPROFILE%\.local\bin\cmake.exe`
- Version: cmake 4.2.3
- Elevation: no
- PATH integration: automatic (`~/.local/bin` on user PATH)
- Note: `uv pip install --system cmake` installs to Python Scripts dir which is NOT
  on PATH with pymanager. `uv tool install` is the correct approach.

### NASM (2026-03-11)

**Official source:** https://nasm.us

**Discovery:** nasm.us provides .exe installer (NSIS/Nullsoft format, per-user)
and portable ZIP for Windows. No package manager integration documented on official site.

**Method selection:**

| Method | Official? | Elevation | Update | PATH | Toolchain |
|--------|-----------|-----------|--------|------|-----------|
| `winget install NASM.NASM` | Wraps official | No (per-user) | winget upgrade | Via installer | winget managed |
| Direct .exe download | Yes (nasm.us) | No | Manual | Via installer | -- |
| ZIP archive | Yes (nasm.us) | No | Manual | Manual | -- |

**Chosen:** `winget install NASM.NASM` (Windows), `brew install nasm` (macOS)
**Rationale:** winget wraps the official Nullsoft per-user installer. Same binary,
automated updates via winget. Verified per-user install (no admin needed).

**Trial (Windows, 2026-03-11):**
- Method: `winget install NASM.NASM`
- Result: success
- Installed path: `%LOCALAPPDATA%\bin\NASM\nasm.exe`
- Version: NASM version 3.01
- Elevation: no
- PATH integration: automatic (per-user PATH via Nullsoft installer)

### MSVC Build Tools

**Official source:** https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022

**Method:** `winget install Microsoft.VisualStudio.2022.BuildTools` + Desktop
Development with C++ workload. Always requires admin (VS Installer design).
No user-level alternative exists.

**Chosen:** ACTION (manual install) -- always requires admin, cannot be automated
in a non-elevated context.

## Anti-patterns

- **Choosing install methods without reading official documentation** --
  the prior CMake entry used `winget install Kitware.CMake` which required admin
  and wasn't listed on cmake.org. Discovery would have found pip immediately.
- **Assuming any package manager is universally best** -- winget is right for NASM
  but wrong for CMake. pip is right for CMake but wrong for Node.js.
- **Applying a fixed priority list across all tools** -- each tool has its own
  best method based on what the tool's maintainers officially support.
- **Hardcoding install commands from memory** -- always verify against current
  official docs, even for well-known tools.
- **Skipping trial installation** -- methods must be tested empirically on the
  target platform. Paths, elevation behavior, and PATH integration can differ
  from documentation.
- **Evaluating only one platform** -- check macOS, Windows, AND Linux.
  Platform gaps must be disclosed.
- **Assuming system-bundled = good enough** -- system tools may be outdated,
  lack features, or have platform-specific limitations. Evaluate the upgrade path.
- **Confusing "code is correct" with "feature is operational"** -- a tool that
  installs but has not been tested on the target platform is not verified.

## Special Evaluation Contexts

### System tool upgrades

When evaluating whether to upgrade a system-bundled tool (e.g., macOS system
bash, system Python), apply additional considerations:

- **System dependency risk** -- does the OS or other system tools depend on
  the bundled version?
- **Side-by-side installation** -- can the upgraded version coexist with the
  system version? (e.g., `brew install bash` installs to `/opt/homebrew/bin/bash`
  or `/usr/local/bin/bash`, leaving `/bin/bash` intact)
- **Shell default changes** -- upgrading a shell requires updating `/etc/shells`
  and `chsh`; evaluate whether this is appropriate
- **Evaluation still applies** -- a system tool upgrade is still a tool
  evaluation. Apply the full `/tool-eval` process to the upgrade method.

### Governed capabilities of existing tools

When evaluating a capability that is part of an existing managed tool (e.g.,
Python's sqlite3 module, Node.js built-in test runner), the evaluation scope is
the capability, not the parent tool:

- **Maintenance** -- is the capability actively maintained within the parent
  project?
- **Platform support** -- does the capability work on all target platforms?
  (e.g., Python sqlite3 may link against different system SQLite versions)
- **Versioning** -- is the capability's version tied to the parent tool's
  version, or independently versioned?
- **Alternatives** -- are there standalone packages that provide the same
  capability with better maintenance or features?

## Exemplar: Deep Cross-Platform Discovery (Perl)

This case study illustrates what thorough cross-platform evaluation looks like
in practice. The Perl tool lifecycle uncovered four layers of problems that
surface-level evaluation would miss.

**Discovery timeline:**

1. **Surface**: Git Bash on Windows bundles perl at `/usr/bin/perl` (v5.38.2).
   Appears to work. Initial evaluation: "perl available, no action needed."
2. **First failure**: Perl one-liners in setup scripts produce double-CR
   (`\r\r\n`) on Windows. Investigation reveals Git Bash's bundled perl uses
   `:unix:perlio` layers, but Strawberry Perl (the managed version installed via
   winget) defaults to `:unix:crlf`.
3. **PATH shadowing**: After installing Strawberry Perl via winget, Git Bash's
   `/usr/bin/perl` still wins in PATH. Managed tool is installed but invisible.
   Fix: `check-lib.ps1` prepends `C:\Strawberry\perl\bin` to PATH explicitly.
4. **PERLIO fix**: `export PERLIO=:perlio` disables CRLF translation for
   Strawberry Perl. Added to `build-deploy.sh` (build-time) and recorded in the
   registry entry's `platformGotchas.windows` (`/tool-registry` skill).

**Lessons:**

- **Surface evaluation is not evaluation.** `command -v perl` returning true
  tells you nothing about which perl, what version, or what I/O behavior it has.
- **Platform-specific I/O layers matter.** The same perl version can behave
  differently depending on how it was compiled and which PerlIO layers are active.
- **PATH shadowing is a class of bug.** Any tool that exists in both Git Bash's
  bundled `/usr/bin/` and a managed location will have this problem. Evaluate
  PATH ordering for every Windows-managed tool.
- **The fix chain was 4 steps deep.** A single "install perl" step was not
  enough. Discovery -> install -> PATH fix -> I/O layer fix.

Carry-forward (as last recorded in the retired `/aitool-eval` card; check the
registry's perl entry for the current state): perl on macOS was not fully
evaluated. Is system perl (5.30) adequate for aitools, does Homebrew perl bring
the same PATH shadowing as Windows, are there PerlIO differences, and should
aitools manage perl on macOS as it does on Windows?

## Platform-Specific Gotcha Catalog

### macOS

- **System tools are ancient**: bash 3.2.57 (2007, GPLv2 -- Apple will never
  update), system Python deprecated (removed in recent macOS), system perl 5.30
  (adequate but not current)
- **Homebrew PATH ordering**: `/opt/homebrew/bin` (ARM) or `/usr/local/bin`
  (Intel) must appear before `/usr/bin` for Homebrew-managed tools to take
  precedence. `#!/usr/bin/env bash` resolves via PATH, so ordering is critical.
- **SIP (System Integrity Protection)**: `/bin/bash`, `/usr/bin/perl`, and other
  system binaries cannot be replaced. Side-by-side installation via Homebrew is
  the only option.
- **Login shell vs script shell**: macOS default login shell is zsh. Upgrading
  bash via Homebrew does NOT change the login shell (nor should it -- aitools
  uses bash for scripts, not interactive use).
- **Xcode Command Line Tools**: Many build tools (clang, make, git) come from
  CLT, not Homebrew. Version and availability depend on whether CLT is installed.

### Windows

- **Git Bash PATH shadows managed tools**: Git for Windows includes `/usr/bin/`
  with perl, python, and other tools. These shadow winget/choco-installed
  versions. Must explicitly prepend managed tool paths. Affects: perl,
  potentially node, python.
- **PowerShell encoding**: Pipeline output uses OEM codepage (CP437). Non-ASCII
  characters get mangled. Fix: use temp files + `[IO.File]::ReadAllText(..., UTF8)`
  instead of piped output.
- **CRLF everywhere**: Git, editors, and Windows tools default to CRLF. Scripts
  must handle both. `set -euo pipefail` + CRLF input can cause subtle failures.
  Hook scripts must normalize.
- **winget vs choco vs scoop**: No single package manager is best for all tools.
  winget is Microsoft-official but limited catalog. choco has broader catalog.
  scoop is user-level only. Evaluate per tool.
- **Long path limit**: Windows 260-char path limit affects cargo, git, node. Must
  enable `LongPathsEnabled` registry key and `git config --global core.longpaths true`.

### Linux

- **Distro packages lag upstream**: apt/dnf packages are often months or years
  behind. Evaluate whether the distro version is sufficient or whether an
  upstream install method (pip, cargo, official repo) is needed.
- **Distro detection**: `apt` vs `dnf` vs `pacman` vs `apk`. Scripts need distro
  detection (`/etc/os-release` or `command -v apt`).
- **bash 5.x is usually present**: Unlike macOS, most Linux distros ship bash
  5.x. Ubuntu 20.04+ has bash 5.0+.
- **No elevation by default**: Many CI runners and containers run as root, but
  developer machines require sudo. Install methods must handle both.

## Relationship to Existing Gates

This playbook feeds INTO:
- **Install command verification gate** (`.claude/rules/tool-lifecycle.md`) --
  verification of existing commands uses the same discovery process
- **Phase 1 of the evaluation lifecycle** (`reference/tool-evaluation-criteria.md`) --
  "Evaluate & Record Source of Truth" starts with this playbook's steps
- **BuildPrereqs entries** (`.claude/rules/script-standards.md`) -- install fields
  must reference methods derived from this process
