# Claude Code CLI: install method evaluation (macOS trial; Windows and Linux from docs)

DRAFT by S3-RegCC (mission REGISTRY-CC, Session Commander 10cf255a-c), 2026-10-21.
Proposed path: `reference/evaluations/claude-code-macos-2026-10-21.md`. Referenced by
the proposed `evaluation.provenance` of the Claude Code registry entry
(`/tool-registry` skill). Not written to `reference/` until the commander approves.

No earlier Claude Code evaluation exists: `reference/evaluations/` held only
`google-chrome-linux-2026-10-05.md` on origin/main db4b3c5.

## Sources consulted (retrieved 2026-10-21, chrome-devtools unless noted)

| Source | What it gave |
|---|---|
| https://code.claude.com/docs/en/setup | System requirements, install methods per platform, update model, channels, Linux package repos, npm, binary integrity, uninstall paths |
| https://code.claude.com/docs/en/changelog | 2.1.307 is the newest entry (October 21, 2026); 2.1.15 npm deprecation notice; 2.1.84 PowerShell tool preview; 2.1.120 Git for Windows no longer required; 2.1.77 SendMessage replaces the Agent `resume` parameter; 2.1.217/2.1.219 nesting depth |
| https://code.claude.com/docs/en/authentication | Credential storage per platform, env overrides, login expiry |
| https://formulae.brew.sh/api/cask/claude-code.json and `claude-code@latest.json` | Cask versions 2.1.304 / 2.1.306, tap homebrew/cask, url downloads.claude.ai, sha256 |
| https://downloads.claude.ai/claude-code-releases/{2.1.302,2.1.304,2.1.306,2.1.307}/manifest.json | Per-platform SHA-256 checksums, buildDate |
| `gh api` Homebrew/homebrew-cask `Casks/c/claude-code.rb` and its commits | Cask body; commits by BrewTestBot |
| `gh api` microsoft/winget-pkgs `manifests/a/Anthropic/ClaudeCode/2.1.302/` and its commits | Portable installer from downloads.claude.ai, sha256, Publisher Anthropic PBC, License Proprietary, committed by spectobot (Dumplings) |
| `gh api` repos/anthropics/claude-code, `LICENSE.md`, `security-advisories` | Organization repo; LICENSE.md "All rights reserved", Commercial Terms of Service (proprietary, no SPDX id); advisories and patched versions (4 of 35 are for Claude Desktop, not the CLI) |

## Method catalog (official docs)

| Method | macOS | Windows | Linux | Auto-updates | Notes |
|---|---|---|---|---|---|
| Native installer (Recommended) | install.sh | install.ps1 / install.cmd | install.sh | Yes (background) | Anthropic-hosted; channel or version selectable |
| Homebrew cask | claude-code (stable), claude-code@latest | -- | (cask supports Linux arches) | No (opt-in env) | homebrew/cask, Homebrew-maintained |
| WinGet | -- | Anthropic.ClaudeCode | -- | No (opt-in env) | Community-submitted manifest |
| apt / dnf / apk | -- | -- | Signed Anthropic repos, stable/latest | No | Needs sudo (apt/dnf) |
| npm | Yes | Yes | Yes | No | Node 22+; same native binary; harness: deprecated |

## Classification and decision

Preferred method stays **native** on all three platforms: officially recommended
(principle 1), Anthropic-hosted with signed manifest and platform code signatures
(principle 2), auto-updates to latest (principle 3), one upstream distribution on every
platform (principles 4-5), no elevation, already automated in `aitools-install` Step 9
(principle 6). Package-manager methods lag the latest release (2026-10-21: Homebrew
stable 2.1.304, @latest 2.1.306, WinGet 2.1.302, native 2.1.307), which matters given the
advisory rate. apt/dnf/apk are recorded as non-preferred Linux alternatives.

## Provenance verification (macOS)

- Installed: native; `~/.local/bin/claude` -> `~/.local/share/claude/versions/2.1.307`.
- `shasum -a 256` of the installed binary:
  `5b113a7752119470f1da419cb0e608af3361cae25b614216b13022093958fb2a`, equal to
  `platforms.darwin-arm64.checksum` in the 2.1.307 manifest.
- `codesign --verify --verbose`: valid on disk, satisfies its Designated Requirement;
  `spctl -a -vv -t install`: accepted, Notarized Developer ID, origin
  "Developer ID Application: Anthropic PBC (Q6L2SF6YDW)".
- Manifest GPG signature: NOT verified (gpg is not installed on this Mac).
- Homebrew cask 2.1.304 arm sha256 equals the 2.1.304 manifest darwin-arm64 checksum.
- WinGet 2.1.302 x64/arm64 InstallerSha256 equal the 2.1.302 manifest win32 checksums.

## Trial: Claude Code on macOS

```
Date: 2026-10-21
Method: native (installed earlier; kept current by auto-update and aitools-install Step 9)
Official source: https://code.claude.com/docs/en/setup
Result: success
Installed path: ~/.local/bin/claude -> ~/.local/share/claude/versions/2.1.307
Version: 2.1.307 (Claude Code)
Elevation needed: no
PATH integration: ~/.local/bin on PATH
Notes: claude doctor: "Running: native (2.1.307)", "Auto-update channel: latest",
"Last update attempt: success -> 2.1.307 (2026-10-21)", "No installation issues found".
```

Windows and Linux: not trialled (no machine in this session).

## Health assessment (per /tool-eval flag criteria)

- macOS yellow: active workaround (D-DEL1, tool-ops item #26, reproduced on macOS
  2.1.307 by S3-RegCC-Check); evaluation stale until this file is approved;
  operational reference stale (tool-ops-claude-code.md "Current version" 2.1.81).
- Windows yellow: version never recorded in the registry (null). The only Windows date
  on record is item #1's workaround verification (2.1.74, 2026-03-13, 222 days ago); read
  as a version verification it would make the flag red, which then needs a migration
  plan (tool-evaluation.md). Item #1 predates upstream shell changes; provenance not
  verified.
- Linux yellow: version and provenance never verified.

## Open items

1. Windows and Linux trials (version, knownPaths, provenance).
2. Re-verify tool-ops-claude-code.md items #1-#25 at 2.1.307 (#1 and #25 look obsolete).
3. Install gpg (or verify on a machine with gpg) to check the manifest signature.
4. Decide whether npm stays "deprecated" (docs no longer use the word).
