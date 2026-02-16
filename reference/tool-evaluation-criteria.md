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

## Special Cases

- **Pre-approved tools**: Tools already listed in `reference/tool-install-sources.md` have been evaluated and are pre-approved. No re-evaluation needed unless a concern arises.
- **Time-sensitive situations**: When live checks aren't possible (no network, rate-limited), state that evaluation is incomplete and recommend the user verify before installing.
- **Internal/private tools**: Company-internal tools skip public adoption checks but still need permission and security review.

## Updating This Policy

When a new tool is evaluated and approved for regular use, add it to `reference/tool-install-sources.md` with its official source URL. This serves as the pre-approved list.
