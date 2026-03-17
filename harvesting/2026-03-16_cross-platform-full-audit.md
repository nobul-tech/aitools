# Cross-Platform Full Audit Report

Date: 2026-03-16

## Part 1: aitools Cross-Platform Content Audit

### File 1: `.claude/rules/cross-platform.md`

**Languages/script types covered:** Bash, PowerShell, Perl (Strawberry vs system)

**Platform-specific patterns documented:**

| Pattern | Coverage |
|---------|----------|
| OS guard patterns | Canonical bash + PS1 code blocks |
| Dual-script rule | `.sh` targets macOS/Linux, `.ps1` targets Windows |
| OS guard exemptions | 6 categories (shared libs, init libs, hooks, aliases, build, scratch) |
| Dead code rule | No platform branches for rejected platform below guard |
| OS guard + dispatch | `uname -s` dispatch for .sh calls; `pwsh -File` via cygpath for .ps1 |
| Cross-language exceptions | Only `build-deploy.sh` approved |
| PowerShell 7 baseline | PS 7 required; PS 5.1 workarounds remain |
| ASCII preference for PS1 | Prefer ASCII in PS1 executable code |
| Windows gotchas | Pipeline encoding, .NET clipboard encoding, .NET CWD, Refresh-Path, Git Bash PATH shadowing, Strawberry Perl text mode |
| Pre-validation convention | PS1 syntax via Parser API; bash via `bash -n` |

**All-platform scripts:** Hooks (`shared/hooks/*.sh`) run bash on all platforms (Claude Code design). `build-deploy.sh` produces platform-independent output.

**Gaps:**
- Linux is mentioned as a target in the `.sh` guard ("macOS/Linux") but has no dedicated documentation, platform paths, or log directories in the rule itself (deferred to cross-platform-detail.md).
- No mention of Go, Rust, or Python platform concerns in this rule (those languages are used elsewhere in the repo).

---

### File 2: `.claude/rules/script-standards.md`

**Languages/script types covered:** Bash, PowerShell

**Platform-specific patterns documented:**

| Pattern | Coverage |
|---------|----------|
| Block order | Separate bash and PS1 variants with platform-specific helpers |
| Logging helpers | Dual-table (bash: `log`/`log_ok`/etc., PS1: `Log`/`LogOk`/etc.) |
| Timestamp format | `date -u` (bash) vs `.ToUniversalTime()` (PS1) |
| Error tracking | `ERRORS` (bash) vs `$script:errors` (PS1) |
| External commands | `$LASTEXITCODE` (PS1); `set -e` wrapping (bash) |
| grep portability | `grep -P` banned; use `perl -ne` or `grep -E` |
| Build prereqs | `Check-BuildPrereqs` (PS1) / `check_build_prereqs` (bash); KnownPaths by platform |

**All-platform scripts:** Hooks (`shared/hooks/*.sh`) and `build-deploy.sh` listed in scope.

**Gaps:**
- No coverage of Python, Perl, Go, or Rust scripting standards in this rule.
- No mention of Linux-specific log paths or install methods.

---

### File 3: `reference/cross-platform-detail.md`

**Languages/script types covered:** Bash, PowerShell, Perl

**Platform-specific patterns documented:**

| Pattern | Detail level |
|---------|-------------|
| PS guard rationale | Why `-not $IsWindows` not `$IsMacOS`; PS 5.1 transparency |
| PS 7 legacy workarounds | 5 specific patterns (ternary, Join-Path, WriteAllText, Parser, hashtable) |
| PS pipeline encoding | OEM codepage mangling; temp file workaround |
| .NET clipboard encoding | Windows-1252 re-encode to UTF-8 |
| .NET working directory | `GetUnresolvedProviderPathFromPSPath` for absolute resolution |
| Refresh-Path behavior | Additive PATH merge from Windows registry |
| Git Bash PATH shadowing | Only `perl` confirmed; check-lib.ps1 prepends managed path |
| Strawberry Perl text mode | `:crlf` layer double-CR; `PERLIO=:perlio` fix; per-invocation or script-wide |

**Platform log directories:**

| Platform | Directory |
|----------|-----------|
| Windows | `$env:LOCALAPPDATA\aitools` |
| macOS | `~/Library/Logs/aitools` |
| Linux | `${XDG_STATE_HOME:-$HOME/.local/state}/aitools` |

**Gaps:**
- Linux appears only in the log directory table and the PS guard rationale.
- No Linux-specific gotchas documented (package manager differences, systemd integration, etc.).

---

### File 4: `reference/script-standards-detail.md`

**Languages/script types covered:** Bash, PowerShell, JavaScript (Node.js merge blocks)

**Platform-specific patterns documented:**

| Pattern | Detail level |
|---------|-------------|
| Shared library functions | Full dual-column table (bash/PS1) with 16 function pairs |
| Logging overrides | Per-entry-point override patterns (bash and PS1) |
| Exit footer | Exact code blocks (bash and PS1) |
| External command handling | 4 standards with dual code examples |
| Python uv-first install | Bash `pip3` fallback; PS1 `pip` fallback (different order due to platform conventions) |
| Post-install auth patterns | 3 patterns (exit code, output content, file presence) with dual code |
| Build prereq validation | Two-layer framework with dual code |
| Known-paths table | Windows: NASM (winget), CMake (uv tool); macOS: NASM/CMake (homebrew/system) |
| grep portability table | 5 alternatives to `grep -P` |
| Bridge pattern | Double-init safety explained per platform |
| Exemptions table | 8 entries with specific line numbers |

**All-platform scripts:** Build-deploy logging override documented as exception.

**Gaps:**
- No Rust, Go, or Python platform-specific scripting guidance.
- JavaScript is only covered for Node.js merge blocks (not standalone scripts).

---

### File 5: `CLAUDE.md` cross-platform content

**Cross-platform sections found:**
- Cross-Platform Paths table (Windows vs macOS for repo, CLAUDE.md, shared config, user repo)
- Platform dispatch pattern (case `uname -s` for Windows; bash vs pwsh)
- Both `.sh` and `.ps1` mentioned throughout build/run section
- CLI tools table (same commands both platforms; `python3` macOS / `python` Windows; `pip3` macOS / `python -m pip` Windows)
- PSO: Platform-native dispatch (never .sh on Windows, never .ps1 on macOS)
- PSO: Equal platform visibility (always show both macOS/bash and Windows/PS1)
- PSO: Dual-script rule (every setup script gets both variants)

**Gaps in CLAUDE.md:**
- Linux not mentioned as a platform in paths or dispatch patterns.
- No Rust, Go, or Python cross-platform guidance at the CLAUDE.md level.

---

## Part 2: nobul-ops Platform-Specific Patterns

### Repository Overview

nobul-ops is a Rust CLI for operational automation. Cross-platform support is handled primarily at the **Rust compilation level**, not via script pairs.

**Key architectural difference from aitools:** Per CLAUDE.md KD #4: "One script per task -- no paired `.sh`/`.ps1` rewrites of the same operation. Cross-platform support is in the Rust binary."

### File Inventory

| Directory | Files | Languages |
|-----------|-------|-----------|
| `src/` | 24 `.rs` files | Rust |
| `scripts/` | `release.sh` (bash), `generate-manifest.py` (Python) | Bash, Python |
| `tests/` | 11 `.rs` files + `common/` + `fixtures/` | Rust |
| `.github/workflows/` | `release.yml` | YAML (GitHub Actions) |
| `build.rs` | 1 file | Rust |

**No `.go` files anywhere.** No Makefiles. No Dockerfiles. No `.ps1` scripts (by design -- KD #4).

### Rust Platform-Specific Code (`#[cfg]` and `cfg!()`)

| File | Pattern | Purpose |
|------|---------|---------|
| `src/paths.rs:12` | `cfg!(target_os = "macos")` | Log directory: `~/Library/Logs/nobul-ops` vs `XDG_STATE_HOME/.local/state` |
| `src/config.rs:159` | `#[cfg(unix)]` | Set credentials dir to chmod 700 (Unix only) |
| `src/self_update.rs:425` | `cfg!(windows)` | Archive format: `.zip` (Windows) vs `.tar.gz` (Unix) |
| `src/self_update.rs:825` | `std::env::consts::OS, ARCH` | Target triple detection for binary download |
| `src/self_update.rs:843` | `cfg!(windows)` | Binary name: `nobul-ops.exe` vs `nobul-ops` |
| `src/self_update.rs:1012` | `cfg!(windows)` | Binary replacement: rename-aside (Windows) vs overwrite (POSIX) |
| `src/self_update.rs:1029` | `#[cfg(unix)]` | Set binary permissions to 755 after replacement |
| `src/self_update.rs:1095` | `cfg!(windows)` | Binary name in tests |
| `src/tools/stripe_tool.rs:31,51` | `cfg!(target_os = "macos")` | Stripe CLI install/update via brew (macOS only; other platforms: manual) |
| `src/tools/gws_tool.rs:259-261` | `cfg!(target_os = "macos/windows")` | Browser open: `open` (macOS), `cmd /C start` (Windows), `xdg-open` (Linux) |

### Cross-Compilation (CI)

The release workflow (`.github/workflows/release.yml`) cross-compiles for 4 targets:

| Target Triple | Runner | Archive | Cross? |
|---------------|--------|---------|--------|
| `aarch64-apple-darwin` | `macos-14` | tar.gz | No (native) |
| `x86_64-pc-windows-msvc` | `windows-2022` | zip | No (native) |
| `aarch64-pc-windows-msvc` | `windows-2022` | zip | Yes (`rustup target add`) |
| `x86_64-unknown-linux-gnu` | `ubuntu-latest` | tar.gz | No (native) |

**Packaging step is platform-aware:**
- Unix: `tar czf` + `shasum -a 256` + `stat -f%z` (macOS) with `stat -c%s` fallback (Linux)
- Windows: `Compress-Archive` (PS1) + `Get-FileHash` (PS1)

**Checksum computation in self_update.rs:** Tries `shasum` first (macOS), falls back to `sha256sum` (Linux). No Windows path (Windows uses binary distribution, not source).

### Platform Path Conventions (reference/cross-platform.md)

| Resource | macOS | Windows |
|----------|-------|---------|
| Config dir | `~/.nobul-ops/` | `%USERPROFILE%\.nobul-ops\` |
| Log dir | `~/Library/Logs/nobul-ops/` | `%USERPROFILE%\.local\state\nobul-ops\` |
| Credentials | chmod 700/600 | Best-effort NTFS ACLs |
| Google Drive | `/Users/.../Library/CloudStorage/GoogleDrive-...` | `G:\Shared drives\...` |

### Binary Replacement Strategy

| Platform | Strategy |
|----------|----------|
| POSIX (macOS/Linux) | Copy new binary over running binary (kernel holds inode reference) + chmod 755 |
| Windows | Rename-aside to `.old`, copy new binary, best-effort delete `.old` |

### nobul-ops Platform Gaps

1. **Stripe CLI install** only automated on macOS (brew). Windows/Linux = manual. Documented as known limitation.
2. **No Windows-specific log path using LOCALAPPDATA.** Uses `XDG_STATE_HOME` or `~/.local/state` for both Windows and Linux (different from aitools which uses `$env:LOCALAPPDATA\aitools` on Windows).
3. **`generate-manifest.py`** has no platform checks -- pure data processing.
4. **`release.sh`** is bash-only -- no PS1 pair. By design per KD #4 (no paired scripts).
5. **Log directory on Windows** uses `%USERPROFILE%\.local\state\` which is unusual for Windows (normally `%LOCALAPPDATA%` or `%APPDATA%`). The Rust code falls through from the macOS branch to a generic XDG path that works but is non-standard on Windows.

---

## Part 3: All Languages with Platform Concerns in aitools

### Language Inventory

| Language | Files in aitools | Platform concerns? |
|----------|-----------------|-------------------|
| **Bash (.sh)** | 28 in scripts/, 9 in shared/hooks/, 2 in shared/shell/ | Primary scripting language; extensive cross-platform docs |
| **PowerShell (.ps1)** | 28 in scripts/, 1 in shared/shell/ | Windows counterpart; parity enforced |
| **Python (.py)** | ~21 files (scratch, harvesting) | No platform checks found; all scratch/utility scripts |
| **Perl (.pl)** | 0 files | Used inline via `perl -pe/-ne` in bash scripts; not standalone |
| **Go (.go)** | 0 files | Not present in aitools |
| **Rust (.rs)** | 0 files | Not present in aitools (Rust is installed by aitools but code lives in nobul-ops) |
| **JavaScript (Node.js)** | Inline in bash/PS1 scripts | Used for JSON merge blocks; no standalone files |
| **YAML (.yml)** | 0 CI configs | No GitHub Actions in aitools |

### .sh / .ps1 Parity Status

**Fully paired (26 script pairs):**
All setup, check, and library scripts have both `.sh` and `.ps1` variants.

**Intentionally unpaired:**

| Script | Why | Documented? |
|--------|-----|-------------|
| `build-deploy.sh` | Produces platform-independent output; approved cross-language exception | Yes (cross-platform.md exemptions) |
| `analyze-session.sh` | Development utility | Not in exemptions table |
| `aitools.ps1` | Windows entry point; pairs with `scripts/aitools` (no .sh extension) | Implicit (CLAUDE.md) |
| `_validate-ps1.ps1` | PS1-only validation helper | Not documented as exemption |

**Deploy directory:** All 17 deploy scripts have both `.sh` and `.ps1` pairs. No gaps.

### Perl Cross-Platform Patterns

Perl is used inline in bash scripts for regex-heavy tasks. Platform concerns documented:

- **Strawberry Perl text mode** (Windows): Defaults to `:crlf` layer causing double-CR. Fix: `PERLIO=:perlio` env var.
- **Git Bash PATH shadowing**: Git bundles perl v5.38 which can shadow Strawberry Perl v5.42. `check-lib.ps1` explicitly prepends managed path.
- **grep -P ban**: macOS BSD grep lacks `-P`; use `perl -ne` instead.
- **Files referencing PERLIO/Strawberry:** 12 files across rules, reference, deploy, scripts.

### Python Cross-Platform Patterns

Python files in the repo are all utility/scratch scripts with no platform-specific code. The setup scripts for Python itself (`setup-python.sh/.ps1`) handle:
- `python3` (macOS) vs `python` (Windows) binary name
- `pip3` (macOS) vs `python -m pip` (Windows)
- uv-first install pattern with platform-aware fallbacks

### Hooks (All-Platform Bash)

9 hook scripts in `shared/hooks/`:
- `session-archive.sh` -- session archiving
- `standing-order-guard.sh` -- USO enforcement
- `glossary-skill-guard.sh` -- glossary skill trigger
- `scratch-init.sh` -- scratch directory init
- `harvest-session.sh` -- artifact harvesting
- `sh-file-fixup.sh` -- CRLF/chmod/git-index fixup
- `block-claude-code-guide.sh` -- block guide references
- `surfacing-duty-stop.sh` -- surfacing duty reminder
- `tool-ops-session-audit.sh` -- tool ops audit

All run under bash on every platform (Claude Code design constraint). No PS1 pairs needed (documented exemption).

---

## Gap Analysis and Findings

### Documented and Governed

1. **Dual-script parity** for setup/check scripts -- fully enforced, 26 pairs, 0 gaps in deploy/
2. **OS guard patterns** -- canonical code provided for both bash and PS1
3. **Perl portability** -- Strawberry vs system perl, PERLIO, PATH shadowing all documented
4. **grep portability** -- `-P` ban with 5 alternatives documented
5. **PS encoding gotchas** -- 5 Windows-specific issues documented with fixes
6. **Build prereqs** -- KnownPaths verified on actual platforms with dates
7. **Cross-language exceptions** -- approval process with 1 approved exception

### Gaps Identified

| # | Gap | Severity | Location |
|---|-----|----------|----------|
| 1 | **Linux is a third-class platform.** Mentioned in guards and log paths but no dedicated documentation, install paths, package manager patterns, or CI. macOS and Windows have detailed coverage; Linux has XDG path defaults only. | Medium | All cross-platform files |
| 2 | **`analyze-session.sh` not in exemptions table.** Has no `.ps1` pair and is not listed in the OS guard exemptions in `cross-platform.md`. | Low | `.claude/rules/cross-platform.md` |
| 3 | **`_validate-ps1.ps1` not in exemptions table.** PS1-only script not listed in exemptions. | Low | `.claude/rules/cross-platform.md` |
| 4 | **No Python scripting standards.** Python files exist in the repo but no platform-aware coding standards are documented for Python scripts. | Low | `.claude/rules/script-standards.md` |
| 5 | **No Rust platform patterns in aitools.** Rust is a managed tool (cargo install compiles from source) with build prereqs, but the cross-platform rule only covers bash/PS1. nobul-ops has its own comprehensive Rust patterns. | Low | `.claude/rules/cross-platform.md` |
| 6 | **nobul-ops Windows log path is non-standard.** Uses `~/.local/state/nobul-ops/` instead of `%LOCALAPPDATA%\nobul-ops\` on Windows. Inconsistent with aitools which uses `$env:LOCALAPPDATA\aitools`. | Medium | `nobul-ops/src/paths.rs` |
| 7 | **nobul-ops Stripe CLI install is macOS-only.** Other platforms get a bail with manual install message. | Low | `nobul-ops/src/tools/stripe_tool.rs` |
| 8 | **nobul-ops `shasum` fallback to `sha256sum`.** No Windows path for checksum. Binary distribution on Windows doesn't use this code path, but it would fail if invoked on Windows for source builds. | Low | `nobul-ops/src/self_update.rs` |

### Cross-Repo Platform Consistency

| Aspect | aitools | nobul-ops | Consistent? |
|--------|---------|-----------|-------------|
| Home dir | `$HOME` / `~` | `dirs::home_dir()` | Yes |
| Config | `~/.aitools/config.json` | `~/.nobul-ops/config.json` | Yes (pattern) |
| Log dir (macOS) | `~/Library/Logs/aitools` | `~/Library/Logs/nobul-ops` | Yes |
| Log dir (Windows) | `$env:LOCALAPPDATA\aitools` | `~/.local/state/nobul-ops` | **No** |
| Log dir (Linux) | `${XDG_STATE_HOME}/.local/state/aitools` | `${XDG_STATE_HOME}/.local/state/nobul-ops` | Yes |
| Script parity | Mandatory .sh/.ps1 pairs | No pairs (Rust binary handles) | Intentional difference |
| Cross-compilation | N/A (scripts) | 4 targets via GH Actions | N/A |
| PS baseline | PS 7 required | PS only for Exchange/Entra | Different scope |

---

## Summary Statistics

| Metric | Count |
|--------|-------|
| aitools paired scripts | 26 |
| aitools unpaired (documented exemptions) | 2 (build-deploy.sh, hooks) |
| aitools unpaired (undocumented) | 2 (analyze-session.sh, _validate-ps1.ps1) |
| aitools hook scripts (all-platform bash) | 9 |
| nobul-ops platform-specific Rust blocks | 10 |
| nobul-ops CI build targets | 4 |
| Cross-platform documentation files in aitools | 4 (rule, detail, script-standards rule, detail) |
| Identified gaps | 8 |
