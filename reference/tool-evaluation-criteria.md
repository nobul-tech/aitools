# Tool & Source Evaluation Criteria

Framework for evaluating tools, extensions, packages, and repos before recommending or installing them.
Applies to all tool types: VS Code extensions, npm packages, PyPI packages, GitHub repos, CLI tools.

## Core Principle

**Reading any source is always OK; recommending or installing requires evaluation.**

Browsing docs, reading code, or referencing a repo for learning is fine regardless of its quality.
But the moment you suggest a user install, enable, or depend on something, it must pass evaluation.

## Hard Blocks (never recommend)

- **Unverified publisher** — VS Code Marketplace extensions without the blue verified badge
- **Repo inactive 2+ years** — last commit >24 months ago with no maintenance signal
- **Known security advisories** — active CVEs, npm audit warnings, or GitHub security alerts
- **Personal fork, not official org** — random user's fork when an official package exists
- **Typosquatting risk** — name suspiciously similar to a popular package (e.g., `colros` vs `colors`)
- **Excessive/unexplained permissions** — browser extension wanting all-site access, VS Code extension requesting credentials without justification

## Yellow Flags (disclose before recommending)

Present these to the user and let them decide:

- **Low adoption** — <1K weekly npm downloads, <10K VS Code installs, <500 GitHub stars
- **Sole maintainer** — single contributor with no org backing
- **No release in 12+ months** — still maintained but no recent activity
- **Excessive permissions** — requests broad access even if explainable
- **No license** — missing LICENSE file (legal risk for commercial use)
- **Archived repo** — explicitly archived by owner (may still work but won't get fixes)

### Disclosure Format

When yellow flags exist, present them clearly:

```
I'd suggest [tool name] for this, but note:
- ⚠️ [flag 1]
- ⚠️ [flag 2]
Want to proceed, or should I look for alternatives?
```

## Green Signals

These increase confidence (but don't skip the checks above):

- Verified publisher (VS Code) or official org (GitHub/npm)
- High adoption (>10K weekly npm downloads, >100K VS Code installs)
- Multiple active maintainers
- Recent releases (within last 6 months)
- Good test coverage and CI pipeline
- Clear license (MIT, Apache 2.0, etc.)

## Evaluation Steps by Tool Type

### VS Code Extensions

1. Check publisher verification badge on Marketplace
2. Check install count and rating
3. Check "Last Updated" date
4. Check repository link — is it an official org or personal repo?
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

## Tool Platform States

Each managed tool has an independent lifecycle state per platform (macOS, Windows):

| State | Meaning | Lifecycle phase |
|-------|---------|----------------|
| `evaluating` | Under hands-on evaluation, no user verdict yet | Phase 1-2 |
| `approved` | User approved on this platform, integration pending | Phase 2 passed |
| `supported` | Fully integrated -- setup script + installer entry | Phases 3-5 complete |
| `n/a` | Not available or not applicable on this platform | -- |

Progression: `evaluating` → `approved` → `supported` (or `n/a` at any point).

- A tool in `evaluating` on all platforms stays in "Under Evaluation" in `tool-install-sources.md`
- First platform reaching `approved` promotes the tool to the main section
- `approved` vs `supported` distinguishes "user said yes" from "fully scripted"
- Display format in `tool-install-sources.md`: inline per entry (e.g., `macOS: supported | Windows: supported`)

## Special Cases

- **Pre-approved tools**: Tools already listed in `reference/tool-install-sources.md` have been evaluated and are pre-approved. No re-evaluation needed unless a concern arises.
- **Time-sensitive situations**: When live checks aren't possible (no network, rate-limited), state that evaluation is incomplete and recommend the user verify before installing.
- **Internal/private tools**: Company-internal tools skip public adoption checks but still need permission and security review.

## Cross-Platform Requirements (This Project)

The ai-tooling project supports both macOS and Windows as first-class platforms. When evaluating a tool for use in this project:

- **Check availability on both platforms** — Homebrew/curl for macOS, winget/choco/npm for Windows
- **Note platform gaps** — If a tool is macOS-only or Windows-only, disclose this upfront
- **Prefer tools with native support on both** — over tools that require WSL or emulation layers
- **Document install commands for both platforms** when adding to tool-install-sources.md

## Evaluation-to-Support Lifecycle

When adding a new managed tool, follow these phases in order. Each phase has a gate — don't proceed until the gate is passed.

### Phase 1: Evaluate & Record Source of Truth
**Gate: Official install docs verified and recorded in "Under Evaluation."**

1. Fetch the tool's official installation page
2. Record in `reference/tool-install-sources.md` under **"Under Evaluation"**:
   - Official source URL, preferred install command per platform, version check command
   - Non-preferred install methods (cleanup targets for setup scripts)
3. All subsequent phases reference this entry — never hardcode install commands from memory

### Phase 2: Install, Test & Approve (collaborative)
**Gate: User explicitly approves the tool after hands-on testing.**

This phase is a collaboration between Claude and the user. Claude automates the mechanics; the user makes the go/no-go decision.

1. **Claude installs** the tool using the preferred method from Phase 1
2. **Claude provides a test command** — a concrete pipeline or invocation the user can run to evaluate whether the tool meets the need (e.g., `echo '<h1>Test</h1>' | pandoc -f html -t markdown`)
3. **User tests** — runs the command, evaluates output quality, tries their real use case
4. **User gives verdict** — Claude asks explicitly: approve or reject?
   - **If rejected**: Claude uninstalls the tool (using the preferred package manager's remove command), removes the "Under Evaluation" entry from tool-install-sources.md, and stops. No further phases.
   - **If approved**: Claude promotes the entry from "Under Evaluation" to a full entry in tool-install-sources.md, then proceeds to Phase 3.

**Do not skip this gate.** Even if the plan includes later phases, stop here and wait for the user's verdict before writing any integration code (aliases, setup scripts, installer steps).

### Phase 3: Shell Integration (if applicable)
Add aliases/functions to `shared/shell/aliases.sh` + `.ps1`. These must check for the tool's existence and fail with a helpful error pointing to `aitools install`.

### Phase 4: Setup Script
Create `scripts/setup-<tool>.sh` + `.ps1` following setup-vercelcli as the gold standard. Install commands come from the tool-install-sources.md entry (not memory). Include cleanup of non-preferred install methods.

### Phase 5: Installer & Build Integration
Add step to `aitools-install.sh/.ps1`. Add copy-as-is block to `build-deploy.sh`. Promote from "Under Evaluation" to full entry if not already done.

### Backtracking
Each phase is independently revertible. Later phases never modify earlier artifacts — the source-of-truth entry is written once and only updated if official docs change.

## Updating This Policy

When a new tool is evaluated and approved for regular use, add it to `reference/tool-install-sources.md` with its official source URL. This serves as the pre-approved list.
