## Cross-Platform Awareness (this repo)

This repo is explicitly cross-platform — it provides tooling for every supported
platform and environment (below).

### Supported platforms and environments

Decided 2026-10-26 (commander): macOS, Windows 11, Linux (Ubuntu 24.04 and
22.04); environments `local`, Claude Code web, Cursor cloud. Each is
first-class; anything else is unsupported. The authoritative list, API values
and per-item detail: `@reference/cross-platform-detail.md` "Supported platforms
and environments". Do not restate the list elsewhere; point to that section.

When writing scripts or paths **in this repo**:
- Provide both `.ps1` and `.sh` variants for setup/utility scripts
- Use forward slashes in paths when possible (works on both platforms)
- Repos live under `~/repos/` (macOS, Linux) / `%USERPROFILE%\repos\` (Windows)
- Use `$HOME` or `~` for user directory references, not hardcoded paths
- After creating `.sh` files on Windows, always run `git update-index --chmod=+x <file>`

### Windows: managed bash (first-class for all agents)

On Windows, the **harness-managed** shell for bash scripts (`build-deploy.sh`,
`aitools` bash dispatch, hooks) is **Git Bash** from **Git for Windows**
(`…\Git\bin\bash.exe`). **Do not** treat **WSL** `bash` as the canonical
managed bash: different paths, lifecycle, and `Get-Command bash` often
resolves to the WSL shim, which breaks version checks and confuses agents.

- **Install / upgrade:** Git for Windows (winget: `Git.Git`).
- **Verification:** `scripts/setup-bash.ps1` only probes known Git Bash paths
  (no generic PATH fallback) so install summaries stay truthful.

### Equal platform visibility

When showing usage examples in docs, always show both macOS/Linux (bash) and
Windows (PowerShell). Never abbreviate one platform as "same but .ps1".
Enforced as a PSO in CLAUDE.md.

### Platform targeting principle

Scripts come in platform pairs: `.sh` targets macOS/Linux, `.ps1` targets
Windows. Every script must have both variants unless listed in the exemptions
table. The OS guard enforces at runtime; header comments document platform.

### One script per tool (D-ENV0)

One `.sh` per tool for every POSIX platform and environment, paired with one
`.ps1`. Do not split scripts per OS or per environment. Divergence (package
managers, paths, environment behaviour) goes into library helpers chosen by
capability or by the environment API (a library helper per package manager,
chosen by capability, e.g. `command -v brew` vs `command -v apt-get`; no such
helper is shared yet). A script may be split only when its OS paths share almost
nothing; record the split as an exception in this file. Decided 2026-10-05.

### Environment branches

**Platform** is the operating system; **environment** is where and how the
agent runs (governed terms, `/glossary` skill). A script may branch on the
environment only where a recorded decision names that environment (e.g.
D-CHR2 for the Claude Code web chrome-devtools args).

- **Detect** only through the library API: `is_claude_code_web` /
  `Test-ClaudeCodeWeb`, `$AITOOLS_ENVIRONMENT` / `$AitoolsEnvironment`
  (`claude-code-web` or `local`; `cursor-cloud` is proposed, pending decision
  P-2, and today detects as `local`), `$AITOOLS_PLATFORM` / `$AitoolsPlatform`.
  Never read `CLAUDE_CODE_REMOTE` directly. Override: `AITOOLS_ENVIRONMENT`.
  `claude-code-web` exists only on Linux. Detail:
  `@reference/cross-platform-detail.md` "Environment detection".
- **PowerShell parity** is at the library level. A `.ps1` behind the Windows
  guard never branches on the environment (always `local` there, so the branch
  is dead code); the `.sh` header says so.
- **Hooks** cannot source the library: copy the block between
  `# --- BEGIN aitools environment block ---` and `# --- END ... ---` in
  `@scripts/aitools-lib.sh` verbatim, markers included.
- **Not applicable here**: report one `OK` row `n/a (<environment>)` with
  `write_environment_skip` / `Write-EnvironmentSkip`. Not `WARN`, not "skipped"
  (a governed deployment outcome).
- **Test** both values with `CLAUDE_CODE_REMOTE` / `AITOOLS_ENVIRONMENT` set
  per case, under an isolated `HOME`; never against the live user config.

### OS guard patterns

Canonical, copyable patterns. Rationale: `@reference/cross-platform-detail.md`

**PowerShell (Windows scripts):**

```powershell
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    LogError "This script is for Windows. On macOS/Linux, use the .sh version."
    exit 1
}
```

**Bash (macOS/Linux scripts):**

```bash
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use the .ps1 version."
        exit 1 ;;
esac
```

Guards MUST use structured logging. Source `init-logging` before the guard.

**Test suites** (commander, 2026-11-14: "sh scripts and tests should only run
on linux/mac and ps1 on windows"). Every `tests/<dir>/test-*.sh` carries the
POSIX guard, every `tests/<dir>/test-*.ps1` the Windows guard, unless the suite
is listed in the exemptions table below as cross-platform. A suite that tests a
`.sh`/`.ps1` pair has two harnesses with the same cases and golden files: the
`.sh` runs the `.sh` scripts on macOS and Linux, the `.ps1` runs the `.ps1`
scripts on Windows with native pwsh (helpers: `@tests/lib/platform-lib.ps1`).
Test harnesses have no logging library: the guard prints to stderr, first
thing after `set` / `param`. The bash guard adds a second case on
`BASH_VERSINFO[5]`, bash's compiled-in machine type, which neither a `uname`
shim on PATH nor an exported `OSTYPE` can change:

```bash
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/<dir>/test-<name>.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/<dir>/test-<name>.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
```

```powershell
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    [Console]::Error.WriteLine("This script is for Windows. On macOS/Linux, run tests/<dir>/test-<name>.sh with bash.")
    exit 1
}
```

On Windows, agents run only `.ps1` suites (and the cross-platform suites in
the table below); a `.sh` suite is never run past its guard, and `uname`,
`OSTYPE` or `BASH_VERSINFO` are never spoofed.

### OS guard exemptions

| Category | Scripts | Rationale |
|----------|---------|-----------|
| Shared libraries | `aitools-lib.sh/.ps1`, `check-lib.sh/.ps1` | Dot-sourced, never invoked directly |
| Init libraries | `init-logging.sh/.ps1` | Sourced for initialization |
| Hooks | `shared/hooks/*.sh` | CC hooks run bash on all platforms |
| Shell alias modules | `shared/shell/aliases.sh/.ps1` | Sourced into shell profiles |
| Build scripts | `build-deploy.sh`, `build-package.sh` (P-1, pending approval) | Bash-only builders, run in Git Bash on Windows; see cross-language exceptions |
| Scratch/test files | `.scratch/*.sh` | Temporary, not deployed |
| Entry points sourced or run on any platform (rationale unrecorded, pending approval) | `bootstrap.sh/.ps1`, `hh.sh/.ps1`, `relay-outbound-prompt.sh/.ps1`, `init-hh-hooks.sh` | Bootstrap/shell helpers; each `.sh` also runs in Git Bash |
| Helper modules (rationale unrecorded, pending approval) | `aitools-json.ps1`, `_validate-ps1.ps1` | Dot-sourced / called by other scripts, never a setup entry point |
| Analysis tools (rationale unrecorded, pending approval) | `analyze-session.sh` | Read-only session analysis |
| Entry points with Windows branches (2026-11-01, review-after) | `aitools-install.sh`, `aitools`, `scripts/githooks/pre-commit` | Run on every platform: on Windows (Git Bash) `aitools-install.sh` forwards to `aitools-install.ps1`, `aitools` (the extensionless bash entry point) dispatches the `.ps1` setup scripts, the git hook runs in Git Bash |
| Package launchers (2026-11-01, review-after) | `packaging/macos/*`, `packaging/linux/*`, `packaging/windows/*.ps1` | Run by the package installer on its one platform (design: `@plans/build-package/design.md`) |
| Cross-platform test suites (2026-11-14, review-after) | `tests/hooks/test-*.sh`, `test-build-deploy-backup.sh`, `tests/build-package/test-cli.sh`, `tests/pywinpty/test-setup-pywinpty.sh` | They test bash code that runs in Git Bash on Windows, so they run in all three CI jobs: the hooks (Claude Code runs hooks in bash on every platform), `build-deploy.sh` (approved cross-language exception) and `build-package.sh`; the pywinpty suite's Windows cases test `build-deploy.sh`'s pin embed |
| Perl and Python scripts (2026-11-14, commander) | `scripts/*.pl`, `scripts/*.py`, `tests/os-guards/classify-guards.pl`, `tests/*/test-*.py` | The commander, verbatim: "unless a script is explicitly marked as cross-platform for good reasons, such as build-deploy.sh and all perl/python scripts, sh scripts and tests should only run on linux/mac and ps1 on windows". They run on every platform (Perl ships with Git for Windows; Python suites run natively in all three CI jobs) and carry no OS guard |
| Test suites pending a decision (2026-11-14, RFI 38dc-3) | `tests/logging/test-logging.sh`, `tests/menus/test-menu-choice.sh` | They test `aitools-lib.sh` code that the bash entry point `scripts/aitools` runs on Windows (the `dashboard-serve.sh` SessionStart hook runs it in Git Bash). They stay on all three CI jobs until the commander decides whether `scripts/aitools` forwards to `aitools.ps1` on Windows; their `.ps1` twins test the PowerShell library |

`tests/os-guards/test-os-guards.sh` (macOS, Linux) and
`tests/os-guards/test-os-guards.ps1` (Windows) enforce this table, with one
classifier (`tests/os-guards/classify-guards.pl`) over every product script
and every test suite: on macOS and Linux every Windows-guarded `.ps1` must
refuse to run (exit 1, guard message, only logs written), on Windows every
POSIX-guarded `.sh` must refuse, a test suite's POSIX guard must have the
`BASH_VERSINFO[5]` case, and a script or suite with no guard that this table
does not list fails the suite. There is no guard override: a test runs a
script only on the platforms its guard allows. `scripts/check-ci-suites.pl`
(CI step "Every test suite is in CI") checks the other side: a `.ps1` suite
runs in the windows job only, a POSIX-guarded `.sh` suite in the macos and
linux jobs only, an unguarded (cross-platform) `.sh` suite in all three.

### Dead code from platform guards

Do not write platform branches for the rejected platform below an OS guard.
After the guard, branch on capability (`command -v pwsh`) not identity
(`$IS_MACOS`, `$IS_LINUX`, `$AITOOLS_PLATFORM`). Environment branches follow
"Environment branches" above.

### OS guard + dispatch rule

- Never call `.sh` setup scripts without a `uname -s` dispatch
- On Windows, call `.ps1` via `pwsh -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$path")"`
- When adding a command to `@scripts/aitools`, add the equivalent to `@scripts/aitools.ps1`

### Cross-language script calls require explicit approval

Crossing languages is an exception. Before planning any cross-language call:
ask the user, get approval, document the exception.

#### Approved exceptions

| Script | Why | Approved | Invocation |
|--------|-----|----------|------------|
| `build-deploy.sh` | Platform-independent output, result committed | 2026-02-17 | `& $bashExe "$path/build-deploy.sh"` |
| Shared check helpers called from `check-*.ps1`: python `scripts/check-path-refs.py`, `check-skill-levels.py`, `check-hook-parity.py`; perl `scripts/check-menu-parity.pl` and the perl one-liners of the check steps | One implementation per check for both twins (no regex or sort-order drift between bash and PowerShell); perl and python are managed tools on every platform. A check step whose interpreter is missing reports SKIP or FAIL, never PASS | 2026-11-14 (commander, RFI fa81-16) | `& $python <script> ...` / `& perl <script> ...` |

#### Unrecorded (in the code, approval pending)

| Script | Why | Approved | Invocation |
|--------|-----|----------|------------|
| `check-pre-commit.ps1`, `check-post-push.ps1`, `check-pre-push.ps1` → Git Bash | They check `.sh` files (`bash -n`), the bash entry point's `--version`, and the bash-only `build-deploy.sh` | unrecorded (needs approval) | `& $bashExe ...` |

### PowerShell 7 baseline

PS 7 (`pwsh`) is the project baseline. Deploy scripts error on PS 5.1.
Legacy PS 5.1 workarounds remain — harmless, cleanup deferred.
Patterns: `@reference/cross-platform-detail.md`

### ASCII preference for PS1 executable code

Prefer ASCII in PS1 strings and expressions for consistency.

### Windows platform gotchas

Brief rules — full details and code examples in
`@reference/cross-platform-detail.md`.

- **PowerShell pipeline encoding**: Prefer temp files over piping for non-ASCII
- **.NET clipboard encoding**: Re-encode Windows-1252 → UTF-8 for clipboard HTML
- **.NET working directory**: Resolve to absolute paths before .NET file APIs
- **Refresh-Path**: Additive PATH merge from registry; safe to call repeatedly
- **Git Bash PATH shadowing**: Git's `usr/bin/` can shadow managed tools (perl).
  Use explicit PATH prepend; no fallback to bundled versions
- **Strawberry Perl text mode**: Defaults to `:crlf` layer (double-CR on
  explicit `\r\n` writes). Fix: `export PERLIO=:perlio` or per-invocation prefix

### Pre-validation convention

Before committing scripts, validate syntax on the current platform:
- PS1: `pwsh -NoProfile -Command '$e = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile("path", [ref]$null, [ref]$e); if ($e) { $e }'`
- Bash: `bash -n path/to/script.sh`
- Note untested platform in commit message: `(tested: Windows)` or `(tested: macOS)`

### Hook portability (all-platform bash)

Hooks (`shared/hooks/*.sh`) run in bash on ALL platforms — macOS,
Linux, and Windows Git Bash. They are exempt from the dual-script
rule (no `.ps1` pair needed) but MUST be portable across all bash
environments. Hooks cannot source `aitools-lib.sh` or `check-lib.sh`
— they are standalone deployed files.

**Known command divergences in hooks:**

| Command | macOS (BSD) | Linux/Git Bash (GNU) | Correct pattern |
|---------|-------------|---------------------|-----------------|
| `stat` modification time | `stat -f %m file` | `stat -c %Y file` | `uname -s` dispatch |
| `stat` birth time | `stat -f %B file` | `stat -c %W file` (0 if unsupported) | `uname -s` dispatch |
| `stat` formatted date | `stat -f "%SB" -t "%Y-%m-%d"` | `date -d "@$(stat -c %Y)"` | `uname -s` dispatch |
| `find` formatted output | `find -printf` not available | `find -printf '%T@'` | Use `find -print0` + `stat` loop |
| `grep` Perl regex | Not available | `grep -P` | Use `perl -ne` or `grep -E` |
| `date` parsing | `date -j -f fmt` | `date -d string` | `uname -s` dispatch |

**Canonical `stat` dispatch pattern for hooks** (hooks cannot use the library's
`get_mtime()` in `@scripts/check-lib.sh`, so they dispatch on `uname -s`):

```bash
if [ "$(uname -s)" = "Darwin" ]; then
    mod_time=$(stat -f %m "$file" 2>/dev/null || echo "0")
else
    mod_time=$(stat -c %Y "$file" 2>/dev/null || echo "0")
fi
```

**NEVER use the fallback chain pattern** `stat -f %m "$file" || stat -c %Y "$file"`.
On Git Bash, GNU `stat -f` means `--file-system` (not format). It
partially succeeds with wrong multiline output, contaminating the
variable. Under `set -u`, bash arithmetic then crashes with
"File: unbound variable". This bug recurred 4 times before this
rule was written.

**All hooks must use `set -euo pipefail`** (code style default).
The `-u` flag catches unset variables, which is the correct behavior
— it surfaces bugs as crashes rather than allowing silent wrong
results.
