# Install Method Discovery Playbook

Step-by-step process for discovering and selecting install methods for managed tools
and build prerequisites. Referenced by `.claude/rules/tool-lifecycle.md`.

## Purpose

Every install command in `tool-registry.md`, `BuildPrereqs` entries, and
`BuildFailureSignatures` remedies must be derived from official tool documentation --
never chosen from assumption or memory. This playbook defines the discovery process.

## Scope

- **Managed tools** in `reference/tool-registry.md`
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

Run the chosen method on the target platform. Record results using this template:

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

Record in `reference/tool-registry.md`:
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
| `uv pip install cmake` | Yes (cmake.org) | No (user-level) | `uv pip install --upgrade cmake` | UNVERIFIED | uv already managed |
| `winget install Kitware.CMake` | No (not on cmake.org) | Yes (admin) | winget upgrade | Auto | winget already managed |
| MSI installer | Yes (cmake.org) | Yes (admin) | Manual | Auto | -- |
| ZIP archive | Yes (cmake.org) | No | Manual | Manual | -- |

**Chosen:** `uv pip install cmake` (Windows), `brew install cmake` (macOS)
**Rationale:** Official method per cmake.org, user-level install, uv already managed,
winget not listed on cmake.org and requires admin.

**Trial (Windows):** PENDING -- user will run `uv pip install cmake` and report
installed path, version, and any issues.

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

## Relationship to Existing Gates

This playbook feeds INTO:
- **Install command verification gate** (`.claude/rules/tool-lifecycle.md`) --
  verification of existing commands uses the same discovery process
- **Phase 1 of the evaluation lifecycle** (`reference/tool-evaluation-criteria.md`) --
  "Evaluate & Record Source of Truth" starts with this playbook's steps
- **BuildPrereqs entries** (`.claude/rules/script-standards.md`) -- install fields
  must reference methods derived from this process
