---
name: aitool-eval
description: "Read-only reference card for tool evaluation methodology —
  hard blocks, yellow flags, health flags, discovery playbook, Homebrew
  verification, sandbox walkthrough. Available in ANY repo. Use before
  installing or recommending any tool."
---

## Intent

**Purpose**: Equip any agent in any repo with the full tool evaluation
methodology from the aitools harness — criteria, discovery playbook,
health flags, and the 8-step evaluation process. A self-contained
reference card that enables rigorous tool evaluation without access to
the aitools repo's source files. **Scope**: Evaluation methodology
only. NOT registry writes (use `/tool-registry` in the aitools repo).
NOT tool installation (user's decision after evaluation). NOT tool
lifecycle management (use `/tool-lifecycle` rule in the aitools repo).
NOT tool operational knowledge (use `/aitool-ops`). **Audience**: Any
agent in any repo considering a new tool, package, extension, or
dependency.

## When to use

Invoke `/aitool-eval` when ANY of these arise:

- Before recommending or installing any tool, extension, or package
- Evaluating a new dependency for a project
- Comparing install methods across platforms
- Checking whether a tool passes hard block / yellow flag criteria
- Verifying Homebrew formula provenance
- Assessing tool health (red/yellow/green flags)
- Re-evaluating an existing tool after upstream changes
- Evaluating a system tool upgrade vs the bundled version
- Evaluating a governed capability of an existing tool (e.g., Python's
  sqlite3 module) — apply the criteria to the capability's maintenance
  and platform support, not just the parent tool
- User says `/aitool-eval` or asks about tool evaluation

## What this does NOT do

- Does NOT write to tool-registry.json — use `/tool-registry` in the
  aitools repo for registry writes
- Does NOT install tools — evaluation produces a recommendation; the
  user decides whether to proceed
- Does NOT manage tool lifecycle (onboarding, setup scripts, aliases)
  — that is project-specific work in the aitools repo
- Does NOT file incidents — use `/incident` for harness deficiencies
- Does NOT evaluate patterns or approaches — this skill evaluates
  tools, packages, and dependencies. For evaluating whether to adopt
  a methodology or pattern, use project-specific governance

## Staleness warning

This skill was authored from the aitools repo's evaluation criteria,
discovery playbook, and tool-evaluation rule. If the source has been
updated since the last `aitools install`, this content may be stale.
Run `aitools` to refresh.

---

## Core Principle

**Reading any source is always OK; recommending or installing requires
evaluation.**

Browsing docs, reading code, or referencing a repo for learning is
fine regardless of quality. The moment you suggest a user install,
enable, or depend on something, it must pass evaluation.

## Evaluation Principles (ranked)

All install method decisions MUST follow these, in order. Higher-ranked
override lower when they conflict.

1. **Official endorsement** — is the method recommended by the tool's
   own documentation?
2. **Verified provenance and security** — can you trace the binary to
   the tool's maintainers?
3. **Latest stable version** — does the method deliver current stable?
4. **Cross-platform delivery** — does the tool ecosystem provide a
   cross-platform installer? Prefer it over per-platform fallbacks.
5. **Same upstream distribution** — same binary/package across
   platforms is a positive signal
6. **Automation and deployment** — can the install be scripted and
   repeated?
7. **Maintenance health** — active maintainers, recent releases,
   responsive to issues?
8. **Build time** — pre-built binaries preferred over compile-from-source

There is no global hierarchy (pip > winget > brew). Different tools
have different best methods. Each tool's best method depends on what
the tool's maintainers officially support.

---

## Hard Blocks (never recommend)

If ANY of these apply, do not recommend the tool:

- **Unverified publisher** — VS Code Marketplace extensions without
  the verified badge; packages from unknown orgs
- **Repo inactive 2+ years** — last commit >24 months ago with no
  maintenance signal
- **Known security advisories** — active CVEs, npm audit warnings,
  GitHub security alerts with no patch
- **Personal fork when official exists** — random user's fork when
  an official package is available
- **Typosquatting risk** — name suspiciously similar to a popular
  package (e.g., `colros` vs `colors`)
- **Excessive/unexplained permissions** — browser extension wanting
  all-site access, VS Code extension requesting credentials without
  justification

## Yellow Flags (disclose before recommending)

Present these to the user and let them decide:

- **Low adoption** — <1K weekly npm downloads, <10K VS Code installs,
  <500 GitHub stars
- **Sole maintainer** — single contributor with no org backing
- **No release in 12+ months** — still maintained but no recent
  activity
- **Excessive permissions** — requests broad access even if
  explainable
- **No license** — missing LICENSE file (legal risk for commercial
  use)
- **Archived repo** — explicitly archived by owner (may still work
  but will not get fixes)

### Disclosure format

When yellow flags exist, present them clearly:

```
I'd suggest [tool name] for this, but note:
- [flag 1]
- [flag 2]
Want to proceed, or should I look for alternatives?
```

## Green Signals

These increase confidence but do not override the checks above:

- Verified publisher (VS Code) or official org (GitHub/npm)
- High adoption (>10K weekly npm downloads, >100K VS Code installs)
- Multiple active maintainers
- Recent releases (within last 6 months)
- Good test coverage and CI pipeline
- Clear license (MIT, Apache 2.0, etc.)

---

## Health Flag Criteria

Health flags are per-platform. A tool can be green on Windows and red
on macOS.

### Red — action required

- Vendor deprecated the runtime or install method on this platform
- Security advisory with no patch available
- Install method broken or no longer available
- Using a version the tool project no longer supports
- Evaluation recommends migration not yet implemented
- Version unverified for >180 days

### Yellow — attention needed

- Version unverified (lastVerified is null or >90 days old)
- Evaluation status is stale (upstream changes not assessed)
- Sole upstream maintainer with no recent activity
- Package maintainer different from tool project and endorsement not
  verified
- Active workaround in place for this platform
- Build from source required (no pre-built binaries)

### Green — healthy

- Latest stable installed via endorsed or verified method
- Version verified within 90 days
- Provenance verified
- No open workarounds or upstream risks on this platform

---

## The 8-Step Evaluation Process

### Step 1: Load principles

Read the evaluation principles (above). Higher-ranked principles
override lower when they conflict. Requirements determine the
method, not assumptions about how the tool will be used.

### Step 2: Discovery

Read the tool's official documentation. Prefer the chrome-devtools
skill for JS-rendered content (official docs often use JavaScript
frameworks that WebFetch cannot render). WebFetch is fine for general
research and blog posts.

For each target platform (macOS, Windows, Linux), catalog every
install method mentioned in official docs:

| Method | macOS | Windows | Linux |
|--------|-------|---------|-------|
| (list all methods the official docs mention) | | | |

Include methods you do not plan to use — the catalog informs the
selection.

### Step 3: Provenance verification

For each candidate method, verify:
- **Source URL** — points to official upstream?
- **Checksums** — match upstream published checksums?
- **Maintainer identity** — who maintains the package?

For Homebrew packages, apply the Homebrew Verification Checklist
(below). For all methods: verify the binary can be traced to the
tool's maintainers.

### Step 4: Cross-platform analysis

Does the tool ecosystem provide a cross-platform installer (e.g.,
`pip`, `npm`, `cargo`)? If so, evaluate it before per-platform
fallbacks. Same upstream distribution across platforms is a positive
signal (evaluation principle #5).

Check availability on ALL target platforms:
- **macOS**: Homebrew, official installer, pip/npm/cargo
- **Windows**: winget, choco, official installer, pip/npm/cargo
- **Linux**: apt/dnf/pacman, official installer, pip/npm/cargo, snap

Note platform gaps. If a tool is single-platform, disclose upfront.

### Step 5: Criteria check

Classify each method against:

| Criterion | Weight | What to check |
|-----------|--------|---------------|
| **Official support** | Highest | Recommended by tool's docs? Maintained by tool's team? |
| **Elevation requirement** | High | Needs admin/sudo/UAC? Prefer user-level when officially supported |
| **Update model** | Medium | Package manager upgrade vs manual re-download? |
| **PATH integration** | Medium | Automatically on PATH, or manual setup? |
| **Existing toolchain** | Medium | Do you already have the package manager? |
| **Cross-platform** | Low | Same method on both platforms? Bonus, not required |

Check against hard blocks and yellow flags. Any hard block = reject.

### Step 6: Health flags

Apply the health flag criteria (above) to each platform. A tool can
be green on one platform and yellow or red on another. Document the
flag and its reason.

### Step 7: Recommend

Select the best method per platform with rationale. Reference the
evaluation principles by rank when explaining the choice. Present the
recommendation with:

- Chosen method per platform
- Rationale (which principles drove the choice)
- Yellow flags (if any, with disclosure)
- Health flags per platform
- Trial installation results (if performed)

### Step 8: Hand off

Present findings to the user. In the aitools repo, hand off to
`/tool-registry` for registry writes. In other repos, the user
decides the next step (install, defer, reject).

---

## Homebrew Verification Checklist

When evaluating any Homebrew-installed tool, verify the formula's
provenance:

| Check | Where to look | What matters |
|-------|---------------|-------------|
| **Maintainer** | Formula git blame on `Homebrew/homebrew-core` | Homebrew team vs official project team |
| **Source URL** | `url` field in formula | Must point to official upstream |
| **Checksum** | `sha256` in formula vs upstream checksums | Must match exactly |
| **Build process** | Formula body | Standard configure/make vs custom patches |
| **Tap** | homebrew-core vs third-party tap | homebrew-core has Homebrew CI; taps vary |
| **Analytics** | `https://formulae.brew.sh/formula/<name>` | Total installs, dependency vs explicit ratio |

### Third-party taps

Some tools use official taps maintained by the tool's project (e.g.,
`powershell/tap/powershell`, `datadog-labs/pack/pup`). Document
whether a formula is in homebrew-core or a third-party tap.

---

## Quick Checks by Tool Type

### VS Code Extensions

1. Check publisher verification badge on Marketplace
2. Check install count and rating
3. Check "Last Updated" date
4. Check repository link — official org or personal repo?
5. Review requested permissions/capabilities

### npm Packages

1. `npm view <pkg> repository.url` — verify official org
2. Check weekly downloads on npmjs.com
3. Check last publish date: `npm view <pkg> time.modified`
4. Check for known vulnerabilities: `npm audit` or Snyk
5. Review dependency count (fewer is better)

### PyPI Packages

1. Check project URL on pypi.org — verify official org
2. Check download stats (pypistats.org)
3. Check last release date
4. Review classifiers for development status
5. Check for known vulnerabilities (safety, pip-audit)

### GitHub Repos

1. Check org/owner — official org or personal account?
2. Check last commit date and recent activity
3. Check stars, forks, and open issue response time
4. Check for LICENSE file
5. Check for security policy (SECURITY.md)

### CLI Tools

1. Verify official installation source (not a wrapper or mirror)
2. Check package manager listing (Homebrew, winget, apt)
3. Verify GPG signatures or checksums where available
4. Check GitHub releases for recent activity

---

## Sandbox Walkthrough Protocol

For tools reaching trial installation, follow this sequence on the
target platform:

1. **Install** — using the chosen method from Step 5
2. **Configure** — any post-install config the tool requires
3. **Use** — run the tool's primary function with a realistic input
4. **Break** — test edge cases, bad input, missing dependencies
5. **Deinstall** — verify clean removal via the package manager

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

Empirical verification is mandatory. Do not ship install commands
that have not been tested on the target platform.

---

## Special Evaluation Contexts

### System tool upgrades

When evaluating whether to upgrade a system-bundled tool (e.g., macOS
system bash, system Python), apply additional considerations:

- **System dependency risk** — does the OS or other system tools
  depend on the bundled version?
- **Side-by-side installation** — can the upgraded version coexist
  with the system version? (e.g., `brew install bash` installs to
  `/usr/local/bin/bash`, leaving `/bin/bash` intact)
- **Shell default changes** — upgrading a shell requires updating
  `/etc/shells` and `chsh`; evaluate whether this is appropriate
- **Evaluation still applies** — a system tool upgrade is still a
  tool evaluation. Apply the full 8-step process to the upgrade
  method.

### Governed capabilities of existing tools

When evaluating a capability that is part of an existing managed tool
(e.g., Python's sqlite3 module, Node.js built-in test runner), the
evaluation scope is the capability, not the parent tool:

- **Maintenance** — is the capability actively maintained within the
  parent project?
- **Platform support** — does the capability work on all target
  platforms? (e.g., Python sqlite3 may link against different system
  SQLite versions)
- **Versioning** — is the capability's version tied to the parent
  tool's version, or independently versioned?
- **Alternatives** — are there standalone packages that provide the
  same capability with better maintenance or features?

### Tool Platform States

Each tool has an independent lifecycle state per platform:

| State | Meaning |
|-------|---------|
| `evaluating` | Under hands-on evaluation, no user verdict yet |
| `approved` | User approved on this platform, integration pending |
| `supported` | Fully integrated (setup script + installer entry) |
| `n/a` | Not available or not applicable on this platform |

---

## Anti-patterns

- **Choosing install methods without reading official documentation**
  — always start from the tool's own docs, not package manager search
- **Assuming any package manager is universally best** — winget is
  right for some tools, wrong for others. Each tool has its own best
  method.
- **Applying a fixed priority list across all tools** — there is no
  global hierarchy. Evaluate per-tool.
- **Hardcoding install commands from memory** — always verify against
  current official docs, even for well-known tools
- **Skipping trial installation** — methods must be tested empirically
  on the target platform
- **Evaluating only one platform** — check macOS, Windows, AND Linux.
  Platform gaps must be disclosed.
- **Assuming system-bundled = good enough** — system tools may be
  outdated, lack features, or have platform-specific limitations.
  Evaluate the upgrade path.
- **Confusing "code is correct" with "feature is operational"** — a
  tool that installs but has not been tested on the target platform
  is not verified

---

## Exemplar: Deep Cross-Platform Discovery (Perl)

This case study illustrates what thorough cross-platform evaluation
looks like in practice. The Perl tool lifecycle uncovered four layers
of problems that surface-level evaluation would miss.

### Discovery timeline

1. **Surface**: Git Bash on Windows bundles perl at `/usr/bin/perl`
   (v5.38.2). Appears to work. Initial evaluation: "perl available,
   no action needed."
2. **First failure**: Perl one-liners in setup scripts produce
   double-CR (`\r\r\n`) on Windows. Investigation reveals Git Bash's
   bundled perl uses `:unix:perlio` layers, but Strawberry Perl (the
   managed version installed via winget) defaults to `:unix:crlf`.
3. **PATH shadowing**: After installing Strawberry Perl via winget,
   Git Bash's `/usr/bin/perl` still wins in PATH. Managed tool is
   installed but invisible. Fix: `check-lib.ps1` prepends
   `C:\Strawberry\perl\bin` to PATH explicitly.
4. **PERLIO fix**: `export PERLIO=:perlio` disables CRLF translation
   for Strawberry Perl. Added to `build-deploy.sh` (build-time) and
   documented in tool-registry.json `platformGotchas.windows`.

### Lessons

- **Surface evaluation is not evaluation.** "command -v perl" returning
  true tells you nothing about which perl, what version, or what I/O
  behavior it has.
- **Platform-specific I/O layers matter.** The same perl version can
  behave differently depending on how it was compiled and which PerlIO
  layers are active.
- **PATH shadowing is a class of bug.** Any tool that exists in both
  Git Bash's bundled `/usr/bin/` and a managed location will have this
  problem. Evaluate PATH ordering for every Windows-managed tool.
- **The fix chain was 4 steps deep.** A single "install perl" step
  was not enough. Discovery -> install -> PATH fix -> I/O layer fix.

---

## Platform-Specific Gotcha Catalog

### macOS

- **System tools are ancient**: bash 3.2.57 (2007, GPLv2 -- Apple
  will never update), system Python deprecated (removed in recent
  macOS), system perl 5.30 (adequate but not current)
- **Homebrew PATH ordering**: `/opt/homebrew/bin` (ARM) or
  `/usr/local/bin` (Intel) must appear before `/usr/bin` for
  Homebrew-managed tools to take precedence. `#!/usr/bin/env bash`
  resolves via PATH, so ordering is critical.
- **SIP (System Integrity Protection)**: `/bin/bash`, `/usr/bin/perl`,
  and other system binaries cannot be replaced. Side-by-side
  installation via Homebrew is the only option.
- **Login shell vs script shell**: macOS default login shell is zsh.
  Upgrading bash via Homebrew does NOT change the login shell (nor
  should it -- aitools uses bash for scripts, not interactive use).
- **Xcode Command Line Tools**: Many build tools (clang, make, git)
  come from CLT, not Homebrew. Version and availability depend on
  whether CLT is installed.

### Windows

- **Git Bash PATH shadows managed tools**: Git for Windows includes
  `/usr/bin/` with perl, python, and other tools. These shadow
  winget/choco-installed versions. Must explicitly prepend managed
  tool paths. Affects: perl, potentially node, python.
- **PowerShell encoding**: Pipeline output uses OEM codepage (CP437).
  Non-ASCII characters get mangled. Fix: use temp files +
  `[IO.File]::ReadAllText(..., UTF8)` instead of piped output.
- **CRLF everywhere**: Git, editors, and Windows tools default to
  CRLF. Scripts must handle both. `set -euo pipefail` + CRLF input
  can cause subtle failures. Hook scripts must normalize.
- **winget vs choco vs scoop**: No single package manager is best for
  all tools. winget is Microsoft-official but limited catalog. choco
  has broader catalog. scoop is user-level only. Evaluate per tool.
- **Long path limit**: Windows 260-char path limit affects cargo, git,
  node. Must enable `LongPathsEnabled` registry key and
  `git config --global core.longpaths true`.

### Linux

- **Distro packages lag upstream**: apt/dnf packages are often months
  or years behind. Evaluate whether the distro version is sufficient
  or whether an upstream install method (pip, cargo, official repo)
  is needed.
- **Distro detection**: `apt` vs `dnf` vs `pacman` vs `apk`. Scripts
  need distro detection (`/etc/os-release` or `command -v apt`).
- **bash 5.x is usually present**: Unlike macOS, most Linux distros
  ship bash 5.x. Ubuntu 20.04+ has bash 5.0+.
- **No elevation by default**: Many CI runners and containers run as
  root, but developer machines require sudo. Install methods must
  handle both.

---

## Carry-Forward: Perl on macOS

**Status**: NOT FULLY EVALUATED.

macOS ships system perl at `/usr/bin/perl` (v5.30 on recent macOS).
Homebrew offers `brew install perl` (current 5.40+). The evaluation
has not been completed:

- Is system perl adequate for all aitools use cases?
- Does Homebrew perl introduce the same PATH shadowing issues as
  Windows?
- Are there PerlIO layer differences between system and Homebrew perl
  on macOS?
- Should aitools manage perl on macOS (as it does on Windows), or is
  system perl sufficient?

This is a carry-forward item for the next tool evaluation cycle.

---

## BuildPrereqs and KnownPaths

Tools that compile from source (`cargo install`, `pip install` with
C extensions, `go install` with cgo) need prerequisite validation
before attempting the build. The aitools harness provides a two-layer
framework:

- **Layer 1 (preventive)**: `check_build_prereqs` / `Check-BuildPrereqs`
  validates that required build tools (compiler, linker, headers) are
  present BEFORE starting the build. Missing prereqs = skip with
  actionable error.
- **Layer 2 (diagnostic)**: `diagnose_build_failure` /
  `Diagnose-BuildFailure` matches build error output against known
  signatures to surface specific remedies.

All `KnownPaths` entries (hardcoded install paths used for fallback
tool detection) MUST be empirically verified on the actual platform.
See `reference/script-standards-detail.md` for the verification
process and the `# Verified: YYYY-MM-DD (vX.Y.Z)` annotation format.

---

## Provenance

The evaluation methodology in this skill is derived from:

- **OWASP dependency checks** — security advisory verification,
  supply chain provenance
- **Industry standard adoption metrics** — npm weekly downloads, VS
  Code install counts, GitHub stars as adoption signals
- **Homebrew provenance model** — formula git blame, source URL
  verification, checksum matching
- **aitools harness** — the specific checklist, health flags, ranked
  evaluation principles, and discovery playbook developed through
  operational experience managing 15+ tools across macOS and Windows

Source files in the aitools repo:
- `reference/tool-evaluation-criteria.md` (criteria detail)
- `reference/tool-evaluation-playbook.md` (discovery process)
- `.claude/rules/tool-evaluation.md` (governance principles)
- `.claude/rules/tool-lifecycle.md` (lifecycle gates)
- `.claude/skills/tool-eval/SKILL.md` (project-level skill)

## Cross-references

- Tool operational knowledge: `/aitool-ops` skill (user-level)
- Full evaluation process (CRUD): `/tool-eval` skill (aitools repo)
- Tool registry: `/tool-registry` skill (aitools repo)
- Tool lifecycle: `.claude/rules/tool-lifecycle.md` (aitools repo)
