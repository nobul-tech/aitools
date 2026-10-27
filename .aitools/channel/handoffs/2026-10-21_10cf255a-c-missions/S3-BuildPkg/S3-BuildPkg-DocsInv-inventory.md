# S3-BuildPkg-DocsInv: supported-platform and deployment-path docs inventory

**Intent**: **Purpose**: List the repo docs whose text states which platforms or
environments aitools supports, or describes deployment paths, and that must change
because of the commander's 2026-10-26 decisions, with proposed old -> new text.
**Scope**: README.md, CLAUDE.md, shared/claude-shared.md, shared/cursor-rules/user-rules.md,
.claude/rules, .cursor/rules, reference, ROADMAP.md, plans (excluding other missions'
handoff folders and harvesting/), plus the dotprofile template. Proposals only.
NOT applied edits. NOT the files of open PRs (conflicts listed).
**Audience**: S3-BuildPkg (orchestrator) and the doc writer.

Author: S3-BuildPkg-DocsInv (level 2 under S3-BuildPkg), 2026-10-26, macOS. Read-only. No repo
file edited, nothing committed.

## Summary (5 lines)

1. 24 doc locations need changes: 15 are needed for this mission, 9 can wait. Most say "macOS and Windows" (or "both machines"), and the closed environment list `claude-code-web | local` shows up 5 times.
2. Most of the files to edit are owned by open PRs. cross-platform.md, deploy-paths.md and deploy-paths.mdc are in #99, claude-shared.md is in #105, and the decision tree, plan and glossary are in #101/#106. Each edit has to rebase after its PR merges.
3. Recommendation: put the supported list in one place, a new short section "Supported platforms and environments" in `.claude/rules/cross-platform.md`, with the per-item detail in `reference/cross-platform-detail.md`. Every other doc points to it and does not list the five again.
4. Below are drafts of the deploy-paths "package path" (third path) section, with its equivalence claim, and of the cross-platform `cursor-cloud` environment change (its signal is a `<signal>` placeholder).
5. There are 6 glossary proposals. The existing `environment` definition already names Cursor cloud, and `platform` names dnf, which the Ubuntu-only decision narrows. 4 INCIDENT markers.

## 1. Inventory table

Priority: **must** = needed for this mission (supported list, package path, environment value). **later** = wording follow-up.
"PR" = an open PR that changes the file (checked with `gh pr list -R nobul-tech/aitools --state open --json number,files`, 2026-10-26). P = protected (`.claude/rules/sources-of-truth.md`).

| # | File (P?) | Section | Current text (verbatim, short) | Why it must change | Proposed new text | Open PR | Priority |
|---|---|---|---|---|---|---|---|
| 1 | README.md (no) | line 1 tagline | "shared configs, rules, and scripts for Claude Code, Cursor, and MCP across Windows 11 and macOS." | Leaves out Linux (Ubuntu), Claude Code web, Cursor cloud; fleet audience | "shared configs, rules, and scripts for Claude Code, Cursor, and MCP on macOS, Windows, Linux (Ubuntu), Claude Code web and Cursor cloud. Supported list: `.claude/rules/cross-platform.md` \"Supported platforms and environments\"." | none | must |
| 2 | README.md (no) | "How it works" | "`scripts/build-deploy.sh` reads from `shared/` ... → deploy to endpoints." | Describes only the MDM path; the package path is new | Append: "A third, parallel path, `build-package`, builds installable packages (Windows .intunewin, macOS unsigned PKG for Intune and Jamf, Linux package for Ubuntu 24.04/22.04). The dev and MDM paths keep working. Paths and their equivalence: `.claude/rules/deploy-paths.md`." | none | must |
| 3 | README.md (no) | "Deploy to a machine (no repo needed)" | "Run these from the `deploy/` directory -- self-contained, MDM-ready:" | Will need a sibling "Install from a package" subsection once build-package has output | Add the subsection when the first package exists (commands unknown until PkgWin/PkgMac/PkgLinux report) | none | later |
| 4 | CLAUDE.md (P) | "What aitools is" | "keep aligned the tools he leverages across every repo and both machines (Windows 11, macOS)" ... "on either machine" | Two machines and one user; the decision is a fleet on five platforms/environments | "keep aligned the tools its users leverage across every repo, machine and environment it supports (`.claude/rules/cross-platform.md` \"Supported platforms and environments\")" ... "on any supported machine or environment". The Intent block ("Jose's central hub ... all his repositories and machines") also implies one user. An intent change needs commander approval (/intent-writing); not drafted here | none | must (body); intent: commander |
| 5 | shared/claude-shared.md (P) | "Cross-Platform Awareness" | "- I work on both Windows 11 and macOS -- both are first-class, ensure a seamless experience on either" | This is the fleet template (user-level, every user), but the line is Jose-specific and two-platform | "- aitools supports macOS, Windows, Linux (Ubuntu), Claude Code web and Cursor cloud; each is first-class (list: `~/.aitools/rules/cross-platform.md`, \"Supported platforms and environments\")". The path holds only if deploy-harness copies `.claude/rules/` to `~/.aitools/rules/` (managed-file-deployment.md "Content sources" says it does) and the fan-out reaches the tool. Unknown until FAN-PLAN reports | #105 (adjacent lines 36-37) | must |
| 6 | shared/claude-shared.md (P) | same section | "- Use `~/` with forward slashes on macOS, `%USERPROFILE%\` ... on Windows" / "under `~/repos/` (macOS) / `%USERPROFILE%\repos\` (Windows)" | Linux missing | "(macOS, Linux)" next to each macOS form | #105 | later |
| 7 | shared/claude-shared.md (P) | "Managed CLI Tools" / "Per-Platform Tools" | "`python3` (macOS) / `python` (Windows)"; bullets for macOS and Windows only | Linux and the hosted environments missing | Add "(macOS, Linux)"; add a "- **Linux (Ubuntu), Claude Code web, Cursor cloud**: bash, Claude Code ..." bullet (contents unknown; PkgLinux) | #105 | later |
| 8 | shared/cursor-rules/user-rules.md (P) | "Cross-Platform Awareness" | "- I work on both Windows 11 and macOS -- both are first-class" | Same as #5 (Cursor template) | Same text as #5. Line 28 `C:\repos\` already has a pending draft from S3-H2-DraftsH (PR #99 folder) | none (draft in #99 folder) | must |
| 9 | .claude/rules/cross-platform.md (P) | opening | "This repo is explicitly cross-platform — it provides tooling for both machines." | Two machines | "This repo is explicitly cross-platform. It provides tooling for every supported platform and environment (below)." + the new section from section 2 | #99 (line 8) | must |
| 10 | .claude/rules/cross-platform.md (P) | "Equal platform visibility" | "always show both macOS/bash and Windows/PowerShell" | Linux is supported; bash examples cover it, but the text does not say so | "always show macOS/Linux (bash) and Windows (PowerShell)" | #99 | must |
| 11 | .claude/rules/cross-platform.md (P) | "Environment branches" | "(`claude-code-web` or `local`) ... `claude-code-web` exists only on Linux." / "**Test** both values" | Closed list; Cursor cloud is now supported | Draft in section 3b | #99 | must |
| 12 | .claude/rules/deploy-paths.md (P) | whole rule | "## Dual Deployment Paths" / "Two deployment methods must produce equivalent results:" | A third, parallel path | Draft in section 3a | #99 (adds "MDM run order"); #111 has a draft edit of this file in its folder | must |
| 13 | .cursor/rules/deploy-paths.mdc (P) | mirror | "## Dual Deployment Paths" / "Two deployment methods..." | Mirror of #12 (and already stale: "Four script pairs", "pre-commit steps 3+10") | Mirror the section 3a summary: "Three deployment paths ... 3. **Package path** (`build-package`): ... see `.claude/rules/deploy-paths.md`" | #99 | must |
| 14 | .cursor/rules/cross-platform.mdc (P) | opening + "Environment branches" | "This repo targets macOS and Windows equally." / "(`claude-code-web` or `local`)" | Two platforms; closed list | "This repo targets every supported platform and environment equally (`.claude/rules/cross-platform.md` \"Supported platforms and environments\")." / "(`claude-code-web`, `cursor-cloud` or `local`)" | none | must |
| 15 | .cursor/rules/cross-platform.mdc (P) | "PowerShell 7 baseline" | "PS 7 (`pwsh`) is the project baseline on both platforms." | Wording | "on every platform" | none | later |
| 16 | .cursor/rules/tool-lifecycle.mdc (P) | cross-platform note | "verify availability on both macOS and Windows. Disclose if a tool is single-platform" | Linux missing | "verify availability on macOS, Windows and Linux (Ubuntu), and in Claude Code web and Cursor cloud where the tool runs there" | none | later |
| 17 | .claude/rules/aitools-workspace.md (P) | "Cross-machine carry-forward principle" | "across multiple machines (macOS, Windows)" | Example list is two platforms | "across multiple machines or environments (for example macOS, Windows, Linux, a hosted cloud agent)" | none | later |
| 18 | reference/cross-platform-detail.md (intent-protected only) | "Environment detection" Resolution 2-3 and "API" | "`AITOOLS_ENVIRONMENT` already set to `claude-code-web` or `local`"; "`claude-code-web` exists only on Linux"; API row "`claude-code-web` or `local`"; "The value list is closed. A new environment (for example a hosted Cursor agent) is added by decision: a new value, its signal, and the scripts that branch on it." | That decision is now taken | Draft in section 3b (detail part) and the new support-matrix section (section 2) | none | must |
| 19 | reference/tool-evaluation-criteria.md (P) | "Cross-Platform Requirements (This Project)" | "The aitools project supports both macOS and Windows as first-class platforms." + "Check availability on both platforms — Homebrew/curl for macOS, winget/choco/npm for Windows" | Evaluations would skip Linux and the hosted environments | "The aitools project supports the platforms and environments listed in `.claude/rules/cross-platform.md` \"Supported platforms and environments\", each first-class. ... Check availability on each: Homebrew/curl (macOS), winget/npm (Windows), apt/official .deb or tarball (Ubuntu); note whether the tool runs in Claude Code web and Cursor cloud (root, no display, ephemeral)" | none | must |
| 20 | reference/tool-evaluation-playbook.md (P) | Step 3 criteria table | "**Cross-platform** \| Low \| Same method on both platforms?" | Wording | "Same method on every supported platform?" | none | later |
| 21 | reference/tool-support-decision-tree.md (no; intent-protected) | Terms table | "environment ... = `local` or `claude-code-web`"; "platform ... (`apt`, `dnf`, ...)" | Closed list; dnf is outside the Ubuntu-only scope | "= `local`, `claude-code-web` or `cursor-cloud`"; keep the `family` schema but note "supported family: `apt` (Ubuntu 24.04, 22.04); `dnf` is schema-only, not supported" | #101, #106 | must |
| 22 | ROADMAP.md (P) | In Progress, row 1 | "Linux install hardening + first-class Linux ... PR B: Linux paths, dnf, CI (#14, #19)" | dnf is no longer in scope (Ubuntu only); build-package needs a row | Row 1: "... PR B: Linux (Ubuntu) paths, CI (#14, #19); dnf deferred (not a supported platform)". New In Progress row: "\| build-package (parallel package distribution) \| plans/build-package/ \| High \| Windows .intunewin, macOS unsigned PKG (Intune, Jamf), Linux package (Ubuntu 24.04/22.04; containers and VMs). Dev and MDM paths unchanged. Fleet audience. \|" | none | must |
| 23 | reference/harness.md (P) | "Components" -> Environment | "(Claude Code locally on a platform, or a hosted service such as Claude Code web)"; Orchestration: "(dotprofile wins; shared is fallback and MDM source)" | Cursor cloud is not named; package path missing | "... a hosted service such as Claude Code web or Cursor cloud"; Orchestration bullet: "Build pipelines generating self-contained deploy scripts (MDM path) and installable packages (package path, `build-package`)" | none (drafts in #100/#110/#111 folders target harness.md) | later |
| 24 | plans/linux-install-hardening.md (P) | scope lines | "dnf arrives with Linux support"; "`plans/linux-support.md`" | dnf out of scope | Do not edit the historical plan. Note the scope change in the ROADMAP row (#22) | none | later |

Not changed (checked, OK as is): README "macOS/Linux:" code headings; `.claude/rules/managed-file-deployment.md` "Platform-specific config values" (it already has a Linux column; a `cursor-cloud` row is needed only if a config value differs there, unknown; owned by #101); `reference/tool-ops-google-chrome.md` D-CHR1 (a dated decision record); `reference/managed-file-deployment.md` "bash-only on both platforms" (wording only; owned by #99/#106); `plans/mission-command-briefing/*` (historical).

## 2. One authoritative location

Recommendation: a new section **"Supported platforms and environments"** in
`.claude/rules/cross-platform.md`, placed right after the opening paragraph. The rule is the
right home for three reasons: it is always in context, deploy-harness copies it to
`~/.aitools/rules/` (managed-file-deployment.md "Content sources"), and the list is a directive.
The per-item detail (environment value, signal, package kind, verification state) goes in a new
section of `reference/cross-platform-detail.md` with the same name. That is a different fact,
so nothing is duplicated.

Proposed rule section (about 10 lines):

```markdown
### Supported platforms and environments

Decided 2026-10-26 (commander). aitools supports, for now, only:

| Kind | Supported | API value |
|---|---|---|
| Platform | macOS, Windows, Linux (Ubuntu 24.04 and 22.04) | `macos`, `windows`, `linux` |
| Environment | local (on any platform above), Claude Code web, Cursor cloud | `local`, `claude-code-web`, `cursor-cloud` |

Each is first-class. Anything else (other Linux families, WSL as a target) is unsupported:
scripts may run there but are not designed or verified for it. Detail and per-item status:
`@reference/cross-platform-detail.md` "Supported platforms and environments".
```

How the other docs should point to it: name the section and do not list the five again. The
exception is short marketing or orientation text (README tagline, CLAUDE.md), which may name
them and must cite the section. Templates deployed outside the repo (`shared/claude-shared.md`,
`shared/cursor-rules/user-rules.md`, the dotprofile template) cite the deployed copy,
`~/.aitools/rules/cross-platform.md`. Rule size: cross-platform.md is already 200 lines against
the ~40-100 guideline (see INCIDENT 1). Adding about 12 lines makes that worse, so moving "Hook
portability" (~35 lines) to the reference would offset it.

## 3a. Draft: deploy-paths.md (third path)

Written against main 5976553. PR #99 adds a "MDM run order" section and a build-deploy note to
this file, so rebase onto #99 before applying (the draft does not touch #99's new text).
Protected: the commander must approve it.

OLD:

```markdown
## Dual Deployment Paths (this repo)

Two deployment methods must produce equivalent results:

1. **Dev/repo path** (`scripts/setup-*.sh/.ps1`): reads `shared/` and user repo at
   runtime. Used by `aitools` CLI.
2. **MDM path** (`<userRepoPath>/deploy/setup-*.sh/.ps1`): self-contained, personalized,
   generated by `build-deploy.sh` into the user's dotprofile repo. Used for endpoint
   deployment. The shared `aitools/deploy/` is frozen (no longer regenerated).
```

NEW:

```markdown
## Deployment Paths (this repo)

Three parallel deployment paths. The dev and MDM paths stay as they are; the
package path is added beside them (commander, 2026-10-26):

1. **Dev/repo path** (`scripts/setup-*.sh/.ps1`): reads `shared/` and user repo at
   runtime. Used by `aitools` CLI.
2. **MDM path** (`<userRepoPath>/deploy/setup-*.sh/.ps1`): self-contained, personalized,
   generated by `build-deploy.sh` into the user's dotprofile repo. Used for endpoint
   deployment. The shared `aitools/deploy/` is frozen (no longer regenerated).
3. **Package path** (`build-package`): installable packages for a fleet of users,
   built from the same `scripts/` and `shared/` sources: a Windows Intune Win32 app
   (`.intunewin`), a macOS unsigned PKG (Intune unmanaged PKG, Jamf), and a Linux
   package for Ubuntu 24.04 and 22.04 (containers, including Claude Code web, and VMs).
   Unsigned first; signing and notarization later and optional. Design:
   `@plans/build-package/`.

### Equivalence

For the same platform, environment and profile, all three paths must leave the same
end state: the same files under `~/.aitools`, `~/.claude` and `~/.cursor`, and the
same managed-tool states and summary rows. The package path is built from the same
`scripts/` and `shared/` sources. It must not add a third copy of setup logic: the
duplication below (incident I6) already exists between `scripts/` and
`build-deploy.sh`. Where a package installs without a dotprofile, only the
profile-sourced content differs, and the package reports that as an `ACTION` row. It
never silently uses another profile. <!-- open: per-user personalization in the
package path, console-user resolution, update and re-run behaviour (MDM-PKG Q4, Q5,
Q6) are decided in plans/build-package/ -->
```

Also in the same file: "### When changing `scripts/setup-*.sh/.ps1`" gets step 4: "If the
script is in a package, run `build-package` for the affected package kinds and verify the
payload contains the change (command: unknown until build-package exists)." The `paths:`
front matter does not need to change (`plans/**` and `scripts/**` already match).

Mirror: `.cursor/rules/deploy-paths.mdc` gets the same list (three items) and a one-line
equivalence pointer to the `.claude` rule.

## 3b. Draft: cross-platform "Environment branches" (`cursor-cloud`)

Signal: `<signal>`. It is unknown until PkgLinux reports; I did not look up Cursor's docs in
this mission. Whether Cursor cloud is Linux-only is also unknown. The draft assumes it is
Linux-only, so mark the assumption as a placeholder.

Rule, OLD:

```markdown
- **Detect** only through the library API: `is_claude_code_web` /
  `Test-ClaudeCodeWeb`, `$AITOOLS_ENVIRONMENT` / `$AitoolsEnvironment`
  (`claude-code-web` or `local`), `$AITOOLS_PLATFORM` / `$AitoolsPlatform`.
  Never read `CLAUDE_CODE_REMOTE` directly. Override: `AITOOLS_ENVIRONMENT`.
  `claude-code-web` exists only on Linux. Detail:
  `@reference/cross-platform-detail.md` "Environment detection".
```

Rule, NEW:

```markdown
- **Detect** only through the library API: `is_claude_code_web` /
  `Test-ClaudeCodeWeb`, `is_cursor_cloud` / `Test-CursorCloud`,
  `$AITOOLS_ENVIRONMENT` / `$AitoolsEnvironment` (`claude-code-web`,
  `cursor-cloud` or `local`), `$AITOOLS_PLATFORM` / `$AitoolsPlatform`.
  Never read the hosts' own signals (`CLAUDE_CODE_REMOTE`, `<signal>`) directly.
  Override: `AITOOLS_ENVIRONMENT`. The hosted environments exist only on Linux
  (`cursor-cloud`: <unverified>). Detail:
  `@reference/cross-platform-detail.md` "Environment detection".
```

Also: "- **Test** both values with `CLAUDE_CODE_REMOTE` / `AITOOLS_ENVIRONMENT` set per case"
becomes "- **Test** every value with the host signal (`CLAUDE_CODE_REMOTE`, `<signal>`) /
`AITOOLS_ENVIRONMENT` set per case". The new function names are a proposal, and their names go
to RevLib. The PS1 twin exists only for parity (behind the Windows guard it is always `local`).

Reference (`cross-platform-detail.md`), changes:
- Resolution 2: "set to `claude-code-web`, `cursor-cloud` or `local` ... otherwise
  `CLAUDE_CODE_REMOTE=true` gives `claude-code-web`; otherwise `<signal>` gives `cursor-cloud`;
  otherwise `local`." The precedence when both signals are set is unknown. Propose that
  `claude-code-web` wins and a warning is logged.
- Resolution 3: "`claude-code-web` and `cursor-cloud` exist only on Linux".
- Resolution 5 detail line: add `<signal>='...'`.
- API table: the environment row lists the three values, plus a new row for
  `is_cursor_cloud` / `Test-CursorCloud`.
- "The value list is closed." paragraph becomes: "The value list is closed: `local`,
  `claude-code-web`, `cursor-cloud` (the last added 2026-10-26, commander). A further
  environment is added by decision: a new value, its signal, and the scripts that branch on it."
- Signals paragraph: add the `<signal>` source URL and read date once PkgLinux confirms it
  (chrome-devtools, `web-sources.md`).

## 4. Glossary proposals (draft only; glossary.json and the rule are protected; glossary.json is owned by PR #101)

Existing definitions read (`registries/glossary.json` through /glossary). `platform`:
"macOS, Windows, Linux. Linux is further distinguished by package-manager family (apt, dnf)."
`environment`: already lists "Claude Code web, Cursor cloud agents, claude.ai". `deployment
scope` = user/project/managed level, which is a different axis from a deployment path.
`harness` and `managed tool` need no change.

| Term | Type | Draft definition | Source |
|---|---|---|---|
| deployment path | term | One of the parallel ways aitools reaches a machine or environment: the dev path (`aitools` running `scripts/`), the MDM path (`build-deploy.sh` -> dotprofile `deploy/`), or the package path (`build-package`). All three must leave the same end state for the same platform, environment and profile. Distinct from deployment scope (user/project/managed level). | `.claude/rules/deploy-paths.md` |
| package path | term | The deployment path that installs aitools from a built package: a Windows Intune Win32 app (.intunewin), a macOS unsigned PKG (Intune, Jamf) or a Linux package for Ubuntu, built by `build-package` from `scripts/` and `shared/`. Parallel to the dev and MDM paths. | `.claude/rules/deploy-paths.md`; `plans/build-package/` |
| aitools package | term | A package file that `build-package` produces (one per package kind). Named this way to tell it apart from a package-manager package (brew formula, winget id, apt package) in the tool registry. | `plans/build-package/` |
| fleet user | term | A person whose machine receives aitools through an endpoint-management tool (Intune, Jamf) or a package, rather than by running the installer themselves. Fleet users may not have a dotprofile repo or know aitools exists. The 2026-10-26 audience decision. | `plans/build-package/` |
| console user | term | The user logged in at the machine's console when a package or MDM agent runs as root or SYSTEM. It is the user whose `HOME` (`~/.aitools`, `~/.claude`, `~/.cursor`) the install targets. No script resolves it today (Session Commander's note, S3-BuildPkg brief "Inputs"). | `plans/build-package/` |
| supported environment / supported platform | none: amend `platform` and `environment` instead | `platform`: "...macOS, Windows, Linux (Ubuntu 24.04 and 22.04; other families are unsupported, 2026-10-26)...". `environment`: add "Supported: local, Claude Code web, Cursor cloud (`.claude/rules/cross-platform.md` \"Supported platforms and environments\")." | 2026-10-26 decision |

`build-package` itself: a tool name, not a governed term. It is referenced through "package
path".

Framework check (/frameworks registry, read only): "Managed file deployment" (configuration
management) governs "Deploying and reconciling harness content across machines". Its artifacts
do not include `.claude/rules/deploy-paths.md`, and no framework covers packaging or software
distribution (release engineering). See INCIDENT 2.

## 5. Files outside the aitools repo (not edited)

| File | Line / section | Current | Proposed |
|---|---|---|---|
| `/Users/new-jose/repos/aitools-nobul-jose/claude/CLAUDE.md` (dotprofile template; the source of the deployed `~/.claude/CLAUDE.md`, which takes priority over `shared/claude-shared.md`: deploy-paths.md "Template sync") | "Cross-Platform Awareness", line 47 | "- I work on both Windows 11 and macOS -- both are first-class, ensure a seamless experience on either" | This one is personal to Jose and may stay true about his machines. To match the decision: "- I work on Windows 11, macOS, Linux (Ubuntu), Claude Code web and Cursor cloud -- all are first-class (list: `~/.aitools/rules/cross-platform.md`)". Commander's choice |
| same | line 48 | "if I switch from Mac to Windows on the same project" | "if I switch machines or environments" (later) |
| same | lines 49-50, 110-111, 119-120 | macOS/Windows-only path, python/pip and Per-Platform Tools lines | Same as rows #6 and #7, kept in sync with `shared/claude-shared.md` (deploy-paths.md "Template sync") |
| `/Users/new-jose/.claude/CLAUDE.md` (deployed) | "Cross-Platform Awareness" | the same line | Do not edit it. It changes when `setup-user-claude` next deploys the dotprofile template (never run against the real HOME from a mission) |

Dotprofile writes are committed and pushed to its main directly (N-Q2, packet section 6). This
is still a protected-content change, so it needs commander approval first.

## INCIDENT markers (not filed)

- INCIDENT 1: `.claude/rules/cross-platform.md` is 200 lines (`wc -l`), against the "~40-100
  lines" in documentation-standards.md "Layered reference architecture". Spec deviation, medium.
- INCIDENT 2: `.claude/rules/deploy-paths.md` is not an artifact of any framework in the
  framework registry. "Managed file deployment" lists managed-file-deployment.md,
  interactive-menus.md and config-file-safety.md only. A third, package-based path has no
  governing discipline (release engineering / software distribution). Governance ambiguity, low.
- INCIDENT 3: `.cursor/rules/deploy-paths.mdc` has drifted from its `.claude` twin on main: it
  says "Four script pairs" (including setup-user-mcp "Settings.json merge"), while the `.claude`
  rule says three pairs and setup-user-mcp is "pure extract"; and it says "Verify via pre-commit
  steps 3+10", which the `.claude` rule says no longer apply. Spec deviation, medium (#99 may fix
  part of it; I did not check).
- INCIDENT 4: terminology. "Package" now has two meanings in the harness: a package-manager
  package (tool registry `install.<platform>[].package`) and an aitools package (`build-package`
  output). Route to /glossary (the "aitools package" proposal above).

## Open questions (with suggested answers)

1. Is the environment value `cursor-cloud`, or `cursor-background-agent`? Suggest
   `cursor-cloud`: it matches the commander's wording and the existing glossary text "Cursor
   cloud agents".
2. Does the Ubuntu-only scope retire the registry `family` / `dnf` schema? Suggest keeping the
   schema and marking dnf unsupported in docs only (row #21). Removing it is a /tool-eval and
   registry change with no current benefit.
3. Should Jose's personal "I work on..." line change (section 5)? Suggest yes, to the five-item
   form, because he runs Claude Code web sessions (plans/linux-install-hardening.md "Verified on:
   Linux (Ubuntu 24.04, Claude Code web)").
4. Should the CLAUDE.md Intent (one user, "his") change for the fleet audience? Suggest yes, as a
   separate /intent-writing draft for commander approval, because the fleet decision changes the
   audience.

WRITE_BLOCKED: none.
