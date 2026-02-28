## Real-world cost of no PowerShell tool on Windows: a cross-platform repo's workaround inventory

I maintain [aitools](https://github.com/nobul-jose/aitools), a cross-platform CLI and deployment framework for managing AI development tooling, configs, and context across Windows 11 and macOS. It covers tool lifecycle management (evaluation, install, config, update), MDM-ready deployment scripts, Claude Code and Cursor configuration, MCP server setup, shell integration, auxiliary CLI tools, and cross-tool interoperability. macOS is supported with bash, Windows with native PowerShell (5.1 -- the version that ships with Windows). The repo serves both a dev-install path (runtime) and an MDM path (self-contained deploy scripts with build-time embedded content). Claude Code is my primary development tool.

What aitools manages today:

| Category | Items |
|----------|-------|
| **CLI tools** (installed + maintained) | Claude Code, Vercel CLI, Cursor Agent CLI, Pandoc, pwsh (macOS) |
| **MCP servers** (configured for Claude Code + Cursor) | Chrome DevTools, Vercel, Webflow |
| **Configs deployed** | `~/.claude/CLAUDE.md`, `~/.claude/settings.json` (hooks, preferences), `~/.claude.json` (MCP), `~/.cursor/mcp.json`, `~/.cursor/cli-config.json`, shell aliases |
| **Context managed** | `.claude/rules/` (13 rule files), `.cursor/rules/` (12 rule files), `shared/claude-shared.md` (user template with profile interpolation), session archive hooks |
| **Runtimes** | Node.js (dependency for Claude Code + MCP) |
| **Auxiliary CLI tools** | `clip2md` -- clipboard-to-markdown converter (HTML clipboard capture, pandoc conversion, optional AI-powered naming) |
| **Under evaluation** | Typst (PDF engine for pandoc) |

After ~1 month of building this with Claude Code on both Windows and macOS, here's a concrete accounting of the cost of having no PowerShell tool. The problem goes beyond the shell default -- Claude's training makes it lean heavily on bash idioms (sed/awk for file editing, long inline pipelines instead of temp files, complex string manipulation in bash rather than native tools), and without a PowerShell tool there's no way to natively execute or test Windows code paths during development.

### Workaround code and behavioral issues

| Category | Count | Notes |
|----------|-------|-------|
| MINGW/MSYS/CYGWIN dispatch blocks | 19 files, ~20 blocks | Every `.sh` that calls a `.ps1` needs one. Miss one and the Windows code path is silently skipped. |
| `powershell.exe -File` / `-Command` invocations | 12 | Bash shelling out to PowerShell because the Bash tool can't run PS1 natively |
| `cygpath -w` path conversions | 22 | Git Bash paths (`/c/repos/...`) must be converted for PowerShell |
| `InvokeGit` wrapper calls | ~15 call sites | Suppress git stderr warnings that crash PowerShell under `$ErrorActionPreference=Stop` |
| `powershell.exe Get-Command` for tool discovery | standing rule | `which`/`command -v` only search Git Bash's PATH subset -- tools installed via winget/scoop/choco are invisible |

Beyond the mechanical workarounds, the biggest ongoing cost is **fighting the model's bash-first bias on Windows**:

- **Claude constantly wants to write bash for Windows.** Even when a `.ps1` file exists right next to the `.sh` file, Claude will default to writing bash, running the `.sh` variant, or suggesting bash-native solutions. I have a standing order -- one of six non-negotiable rules -- dedicated solely to forcing platform-native dispatch. It still gets violated.
- **Claude runs `.sh` check scripts on Windows instead of the `.ps1` variants.** The checklist rule files now carry explicit "On Windows: `powershell.exe -File ...`" reminders in every blockquote header because the model would otherwise reach for `bash scripts/check-pre-commit.sh` -- which hits an OS guard and silently exits, skipping all PS1 validation.
- **Claude reaches for bash idioms that are wrong for Windows.** `sed`/`awk` for file editing, long inline pipelines instead of temp files, `grep` instead of `Select-String`. These work in Git Bash but produce the wrong muscle memory -- the resulting code doesn't translate to the `.ps1` variants that actually run on Windows.
- **Rules and docs get ignored under context pressure.** Even with 70+ lines of cross-platform rules, a standing order, and dispatch reminders in every checklist, Claude will still skip the PS1 path when working through a long task. The rules are in context but get deprioritized against feature logic.

The dispatch block pattern that every script needs:

```bash
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        powershell.exe -NoProfile -ExecutionPolicy Bypass \
            -File "$(cygpath -w "$ps1_path")" ;;
    *) bash "$sh_path" ;;
esac
```

### Documentation and rules overhead

| File | Lines | Purpose |
|------|-------|---------|
| `reference/claude-code-windows-shell.md` | 88 | Entire file exists for this limitation |
| `.claude/rules/cross-platform.md` | ~70 of 100 | OS guards, PS 5.1 compat, ASCII-only rule, encoding gotchas, quoting patterns |
| Standing order in shared config | 1 of 6 | "Platform-native dispatch" -- non-negotiable rule for AI sessions |
| Checklist blockquotes (x6 files) | 18 | "On Windows: powershell.exe..." in every pre-commit/pre-push/post-push rule |

I also track 5 upstream issues in a version-dependency registry that gets re-checked on every Claude Code upgrade.

### 13 bugs that shipped to production

These are just the bugs serious enough to make it into release notes. Countless more were caught mid-session -- wasted tokens, wasted time, and interrupted flow debugging issues that wouldn't exist if the model had a native PowerShell tool.

**Windows-specific bugs (no cross-platform test catches these):**

| Bug | Root cause |
|-----|-----------|
| PowerShell pipeline mangled non-ASCII to `?` (0x3F) | Windows console codepage issue affecting all PS versions on Windows, including pwsh 7. macOS unaffected (UTF-8 locale). |
| `.NET` clipboard API decoded UTF-8 as Windows-1252, producing mojibake | Windows-specific `.NET` behavior, invisible on macOS. |
| `git diff` CRLF warnings crashed PS1 check scripts | `$ErrorActionPreference=Stop` + git stderr. Required permanent `InvokeGit` wrapper. |
| `deploy_configs()` missing Windows dispatch -- hook deployment silently failed | New bash function, forgot to replicate MINGW dispatch block. |
| Executable bits dropped on `.sh` files created on Windows | Write tool on Windows doesn't set Unix executable bit. |

**PS 5.1 bugs (pwsh 7 on macOS gives false confidence -- Microsoft only ships pwsh 7 cross-platform via Homebrew tap, so macOS testing passes while Windows PS 5.1 fails silently):**

| Bug | Root cause |
|-----|-----------|
| `ConvertFrom-Json -AsHashtable` silently failed on PS 5.1, **clobbering all `settings.json` data** with empty `@{}` | PS 6+ parameter. Works on pwsh 7 (macOS), fails only on PS 5.1 (Windows). |
| `Join-Path` with 3+ arguments failed on PS 5.1 | PS 6+ feature (`-AdditionalChildPath`). Works on pwsh 7 (macOS), fails only on PS 5.1. |
| `Set-Content -Encoding UTF8` wrote BOM on PS 5.1, breaking JSON parsing | PS version difference: 5.1 writes BOM, 6+ writes NoBOM. pwsh 7 on macOS wouldn't surface this. |
| `-replace` with scriptblock (PS 6.1+ syntax) produced garbage paths on PS 5.1 | Works on pwsh 7, silently stringified on PS 5.1. |
| Em-dash in PS1 string literal broke PS 5.1 parsing (Windows-1252 vs UTF-8) | PS 5.1 reads BOM-free UTF-8 as Windows-1252. pwsh 7 reads UTF-8 correctly on all platforms. |
| 3 more PS 5.1 / path-conversion bugs | All PS 5.1-specific, all undetectable without native Windows PS 5.1 execution. |

The underlying pattern isn't just "code was written in bash" -- it's that the model doesn't naturally think about PowerShell at all. It will ignore explicit rules, skip over existing `.ps1` files sitting right next to the `.sh` it's editing, and default to bash patterns even when the user has documented the correct approach. Every one of these 13 bugs was preventable if the model had run `powershell.exe -File script.ps1` to functionally test its work -- something it *can* do from the Bash tool but rarely does unprompted.

### What workarounds cannot fully solve

1. **Functional testing requires constant prompting.** Claude *can* run `powershell.exe -File script.ps1` from the Bash tool for functional tests, and we do this for syntax validation. But the model doesn't naturally reach for this -- it treats PS1 scripts as "done" after writing them, without testing the Windows execution path. Every functional test has to be explicitly requested or enforced via rules.

2. **Hooks run in bash on Windows, permanently.** The hook execution context is hardcoded to bash. Any hook that needs Windows-specific work (registry, `%LOCALAPPDATA%`, .NET APIs) must shell out to PowerShell from inside a bash script.

### What would help

A first-class `PowerShell` tool on Windows (or at minimum honoring `CLAUDE_CODE_SHELL`) would eliminate:
- All 20 dispatch blocks and 22 `cygpath` calls
- The standing order, the 88-line reference doc, and ~70 lines of cross-platform rules
- The entire class of "authored in bash, broke in PS 5.1" bugs
- The `InvokeGit` wrapper and its 15 call sites
- The inability to functionally test PS1 scripts during development

Windows is a second-class platform right now. The workarounds work, but they're a substantial tax on every session, and the model's bash-first training bias means constant vigilance is needed to keep it from reaching for the wrong tool.

---

**Environment:** Windows 11 Pro for Workstations, Claude Code 2.1.62, PowerShell 5.1 (ships with Windows), Git Bash via Git for Windows.

**Related issues:** #25558, #5049, #16225, #20453 (closed, no fix)
