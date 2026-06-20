# Shell Integration & PATH Ownership

**Intent**: **Purpose**: Document how aitools owns shell integration and
PATH precedence so the harness resolves managed tools (uv python,
cursor-agent, brew bash) deterministically across login and
non-interactive contexts on every platform. **Scope**: The managed
marked-block convention, canonical PATH order, what aitools owns vs
preserves, the per-platform login-profile targets, and the
`harness_python`/`Get-HarnessPython` resolver for non-interactive
contexts. NOT the setup-script internals (`scripts/setup-user-shell.*`).
NOT the tool-ops resolution/verification model (`/tool-ops`). NOT tool
install methods (`/tool-registry` skill). **Audience**: Every agent or
operator reasoning about why a managed tool resolves the way it does.

---

## The problem this solves

A managed tool is only useful if the harness actually invokes the
*managed copy*. The failure mode is a **managed-tool shadow**: the
canonical binary is on disk and current, but another entry earlier on
`PATH` wins. The seeding case: `python3` resolving to Homebrew's
`/opt/homebrew/bin/python3` instead of the uv shim at
`~/.local/bin/python3` in the harness's non-interactive contexts
(SessionStart/SessionEnd hooks, `aitools install`, the Claude Code Bash
tool, cron/MDM), because the `~/.local/bin` prepend lived only in an
interactive `*.rc` while `brew shellenv` (login) pushed `/opt/homebrew/bin`
ahead.

The fix has two layers:

1. **Login-shell PATH ownership** — a marked block the harness owns in
   the login profile, placed last so it re-asserts precedence.
2. **A deterministic resolver** — a library function that returns the
   managed interpreter regardless of `PATH`, for contexts where no login
   profile is sourced at all.

## The managed block

aitools owns a single marked region in the **login** profile:

```
# >>> aitools managed >>>
# Owned by aitools (scripts/setup-user-shell.sh). Placed last so it re-asserts
# PATH precedence for harness-managed tools. Edit via the script, not by hand.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.cargo/bin" ] && export PATH="$PATH:$HOME/.cargo/bin"
[ -d "$HOME/go/bin" ] && export PATH="$PATH:$HOME/go/bin"
# <<< aitools managed <<<
```

### Marker convention

- Start: `# >>> aitools managed >>>`
- End: `# <<< aitools managed <<<`
- The block is rewritten **in place** between the markers on every run
  (idempotent). If absent, it is appended at end-of-file. Everything
  outside the markers is the user's and is never touched.
- The block is owned by `setup-user-shell.{sh,ps1}` — edit the script,
  not the profile.

### Why "placed last" matters

Re-asserting precedence at the end of the profile is what makes the fix
robust without rewriting the user's own lines. The block runs after any
earlier installer prepends (grok, antigravity); its `brew shellenv`
re-prepends Homebrew and the `~/.local/bin` line re-prepends the managed
bin dir — so the managed copies end up ahead of everything that ran
before, regardless of how messy the rest of the profile is.

## Canonical PATH order (macOS/Linux)

```
~/.local/bin  →  /opt/homebrew/bin  →  grok / antigravity / other installer bins  →  system
```

- `~/.local/bin` first — uv python shims and `cursor-agent` win.
- `/opt/homebrew/bin` second — brew bash 5.x wins over system bash 3.2,
  and ahead of unmanaged installer bins.
- Unmanaged installer bins (grok, antigravity) sit behind — reachable
  by name, never shadowing a managed tool.

## What aitools owns vs preserves

| | |
|---|---|
| **Owns** | The marked block in the login profile; PATH precedence within it; the `agent → cursor-agent` shim (POSIX) |
| **Preserves** | Everything outside the markers — user aliases, unmanaged installer lines, completions, prompt config |

The interactive `*.rc` (`~/.bashrc`) keeps only the `source aliases.sh`
line; PATH ownership lives in the login profile, not the rc.

## Per-platform login-profile targets

| Platform | Login profile (managed block) | Interactive rc (aliases) |
|----------|-------------------------------|--------------------------|
| macOS/Linux (bash) | `~/.bash_profile` | `~/.bashrc` |
| macOS/Linux (zsh fallback) | `~/.zprofile` | `~/.zshrc` |
| Windows (PowerShell) | `$PROFILE` | `$PROFILE` |

On Windows there is no brew; the managed block prepends `$HOME\.local\bin`
(the aitools/uv bin dir) for the session. The macOS/Linux login shell is
read by Terminal.app when its shell is set to brew bash.

## The deterministic resolver (non-interactive contexts)

The login-profile block fixes interactive and login-inheriting shells. It
does **not** help a raw `bash -c` from launchd/cron/MDM, which sources no
profile. For those, harness code resolves the managed interpreter
directly:

- Bash: `harness_python` in `@scripts/aitools-lib.sh`
- PowerShell: `Get-HarnessPython` in `@scripts/aitools-lib.ps1`

Both prefer the uv shim (`~/.local/bin/python3`), then fall back to a
`PATH` lookup. Harness code that needs Python and can source the library
(e.g. `@scripts/aitools-dashboard.sh` `find_python`) calls the resolver
rather than a bare `python3`.

**Hooks are the exception.** Hook scripts (`shared/hooks/*.sh`) are
standalone deployed files and **cannot source the library** (see
`@.claude/rules/cross-platform.md`). A hook that needs the managed
interpreter must inline the shim preference
(`PY="$HOME/.local/bin/python3"; [ -x "$PY" ] || PY=python3`) rather than
call `harness_python`.

## Origin

Design record: `plans/tooling-resolution-and-artifact-registry.md`
(Workstream A). Seeded by `aitools install` on nobul-mac reporting
`python3` resolving to Homebrew's interpreter in non-interactive contexts.

## Cross-references

- Setup script: `@scripts/setup-user-shell.sh` / `@scripts/setup-user-shell.ps1`
- Install wiring: `@scripts/aitools-install.sh` / `.ps1` (Step 7)
- Resolver: `harness_python` / `Get-HarnessPython` in `@scripts/aitools-lib.sh` / `.ps1`
- Cross-platform shell rules: `@.claude/rules/cross-platform.md`
- Tool-ops resolution/verification model: `/tool-ops` skill
- Tool install methods: `/tool-registry` skill
