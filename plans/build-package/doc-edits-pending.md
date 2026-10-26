# build-package: pending doc edits for PR-owned files

Author: S3-BuildPkg-DocsWriter for S3-BuildPkg, version 1.0, 2026-10-26

**Intent**: **Purpose**: Hold the exact old -> new text for every doc edit the
2026-10-26 decisions need (supported platforms and environments, package path,
`cursor-cloud`) in files that an open PR owns, so the executing mission (batch
B13) can apply each one after its PR merges. **Scope**: One entry per file:
owning PR, apply condition, OLD, NEW. Plus glossary proposals and the
dotprofile template line. NOT the edits already applied in this mission (listed
at the end). NOT plans/build-package/design.md, implementation-plan.md or
remediation.md. **Audience**: The executing mission (B13) and the commander.

Rules for applying: OLD blocks were taken from `main` at 0ddd127 (2026-10-26)
and checked against each owning PR's diff (`gh pr diff <n>`). After the PR
merges, re-check that each OLD block occurs exactly once on the new `main`;
if not, re-draft against the merged text, do not force it. The authoritative
supported list is `reference/cross-platform-detail.md` "Supported platforms and
environments" (BP-18, applied in this mission); every edit below points to it
and does not restate the list, except short orientation lines that name the
five and cite it. Templates deployed outside the repo cite the deployed copy,
`~/.aitools/reference/cross-platform-detail.md` (deploy-harness copies
`reference/` to `~/.aitools/`: `.claude/rules/managed-file-deployment.md`
"Content sources").

Decision references (BP-n, P-n): `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-BuildPkg/S3-BuildPkg-decisions.md`.

## Index

| # | File | Owning PR | Apply after | Needs |
|---|---|---|---|---|
| 1 | `.claude/rules/cross-platform.md` (opening, pointer section, equal visibility) | #99 | #99 merges | -- |
| 2 | `.claude/rules/cross-platform.md` (Environment branches, `cursor-cloud`) | #99 | #99 merges AND P-2 approved AND the B5 lib change ships | P-2 |
| 3 | `.claude/rules/cross-platform.md` (two exemption rows + package launchers row) | #99 | #99 merges AND P-1 approved | P-1 |
| 4 | `.claude/rules/deploy-paths.md` (third path) | #99 | #99 merges | -- |
| 5 | `.cursor/rules/deploy-paths.mdc` (third path mirror) | #99 | #99 merges | -- |
| 6 | `shared/claude-shared.md` (Cross-Platform Awareness line) | #105 | #105 merges | -- |
| 7 | `reference/tool-support-decision-tree.md` (Terms rows) | #101, #106 | both merge | P-2 for the `cursor-cloud` part |
| 8 | `reference/logging.md` (system-phase log location, BP-16) | #101 | #101 merges | -- |
| 9 | Glossary (`/glossary` skill; registry owned by #101) | #101 | #101 merges | commander review of terms |
| 10 | Dotprofile template `claude/CLAUDE.md` | none (other repo) | any time | P-7 (Jose's choice) |

---

## 1. `.claude/rules/cross-platform.md`: opening, pointer, equal visibility

Owning PR: #99 (changes the "Repos live under" line only; this edit does not
touch it). Apply after #99 merges.

### 1a. Opening

OLD:

```markdown
This repo is explicitly cross-platform — it provides tooling for both machines.
```

NEW:

```markdown
This repo is explicitly cross-platform — it provides tooling for every supported
platform and environment (below).

### Supported platforms and environments

Decided 2026-10-26 (commander): macOS, Windows 11, Linux (Ubuntu 24.04 and
22.04); environments `local`, Claude Code web, Cursor cloud. Each is
first-class; anything else is unsupported. The authoritative list, API values
and per-item detail: `@reference/cross-platform-detail.md` "Supported platforms
and environments". Do not restate the list elsewhere; point to that section.
```

Note: cross-platform.md is already about 200 lines against the ~40-100 guideline
(DocsInv INCIDENT 1). This adds 8 lines. Moving "Hook portability" (about 35
lines) to `reference/cross-platform-detail.md` would offset it; that is a
separate change, not drafted here.

### 1b. Equal platform visibility

OLD:

```markdown
When showing usage examples in docs, always show both macOS/bash and
Windows/PowerShell. Never abbreviate one platform as "same but .ps1".
```

NEW:

```markdown
When showing usage examples in docs, always show both macOS/Linux (bash) and
Windows (PowerShell). Never abbreviate one platform as "same but .ps1".
```

---

## 2. `.claude/rules/cross-platform.md`: Environment branches (`cursor-cloud`)

Owning PR: #99. Apply only when ALL hold: #99 merged; P-2 approved (value
`cursor-cloud`, BP-19 signals); the library change of batch B5 has shipped
(`aitools-lib.sh/.ps1` resolve `cursor-cloud` and provide the detector). Until
then the rule must keep describing the code as it is. Function names
`is_cursor_cloud` / `Test-CursorCloud` are proposed (RevLib); use whatever B5
ships.

OLD:

```markdown
- **Detect** only through the library API: `is_claude_code_web` /
  `Test-ClaudeCodeWeb`, `$AITOOLS_ENVIRONMENT` / `$AitoolsEnvironment`
  (`claude-code-web` or `local`), `$AITOOLS_PLATFORM` / `$AitoolsPlatform`.
  Never read `CLAUDE_CODE_REMOTE` directly. Override: `AITOOLS_ENVIRONMENT`.
  `claude-code-web` exists only on Linux. Detail:
  `@reference/cross-platform-detail.md` "Environment detection".
```

NEW:

```markdown
- **Detect** only through the library API: `is_claude_code_web` /
  `Test-ClaudeCodeWeb`, `is_cursor_cloud` / `Test-CursorCloud`,
  `$AITOOLS_ENVIRONMENT` / `$AitoolsEnvironment` (`claude-code-web`,
  `cursor-cloud` or `local`), `$AITOOLS_PLATFORM` / `$AitoolsPlatform`.
  Never read the hosts' signals (`CLAUDE_CODE_REMOTE`, `CURSOR_AGENT_SOCKET`,
  `/run/cursor/api.sock`) directly. Override: `AITOOLS_ENVIRONMENT`.
  `claude-code-web` and `cursor-cloud` exist only on Linux. Detail:
  `@reference/cross-platform-detail.md` "Environment detection".
```

OLD:

```markdown
- **Test** both values with `CLAUDE_CODE_REMOTE` / `AITOOLS_ENVIRONMENT` set
  per case, under an isolated `HOME`; never against the live user config.
```

NEW:

```markdown
- **Test** every value with the host signal (`CLAUDE_CODE_REMOTE`, a stub
  `CURSOR_AGENT_SOCKET` path) / `AITOOLS_ENVIRONMENT` set per case, under an
  isolated `HOME`; never against the live user config.
```

Same condition, two follow-ups in files no PR owns (apply in the B5 PR itself):

- `reference/cross-platform-detail.md` "Environment detection": replace the
  "Cursor cloud is a supported environment ... (item 4)." paragraph (added by
  this mission) with resolution items describing what B5 ships: item 2 adds
  "otherwise `${CURSOR_AGENT_SOCKET:-/run/cursor/api.sock}` exists gives
  `cursor-cloud`" (precedence when both signals are set: proposed
  `claude-code-web` wins, with a warning); item 3 becomes "`claude-code-web`
  and `cursor-cloud` exist only on Linux"; item 5's detail line adds
  `CURSOR_AGENT_SOCKET='...'`; the API table gets the detector row and the
  environment row's three values; the Signals paragraph gets the Cursor source
  URLs and read date (PkgLinux notes: https://cursor.com/docs/cloud-agent/metadata,
  read 2026-10-26; re-read with chrome-devtools per `web-sources.md`).
- `.cursor/rules/cross-platform.mdc` "Environment branches": OLD
  "(`claude-code-web` or `local`; `cursor-cloud` proposed, not yet a value)" ->
  NEW "(`claude-code-web`, `cursor-cloud` or `local`)"; OLD
  "(`is_claude_code_web` / `Test-ClaudeCodeWeb`, `AITOOLS_ENVIRONMENT`,
  `AITOOLS_PLATFORM`), never by reading `CLAUDE_CODE_REMOTE`" -> NEW
  "(`is_claude_code_web` / `Test-ClaudeCodeWeb`, `is_cursor_cloud` /
  `Test-CursorCloud`, `AITOOLS_ENVIRONMENT`, `AITOOLS_PLATFORM`), never by
  reading the hosts' signals"; "Test both values" -> "Test every value".

---

## 3. `.claude/rules/cross-platform.md`: exemption rows (P-1)

Owning PR: #99. Apply after #99 merges and the commander approves P-1. Rows
1 and 2 are the Lang evaluation drafts
(`S3-BuildPkg-Lang-evaluation.md` "Exception rows to draft"), verbatim except
the approval date placeholder. Row 3 (package launchers, BP-5) is new here.

### 3a. Approved exceptions table (add a row)

Needed when a `.ps1` calls `build-package.sh` (check-pre-push.ps1 step 11,
batch B11). OLD:

```markdown
| `build-deploy.sh` | Platform-independent output, result committed | 2026-02-17 | `& $bashExe "$path/build-deploy.sh"` |
```

NEW:

```markdown
| `build-deploy.sh` | Platform-independent output, result committed | 2026-02-17 | `& $bashExe "$path/build-deploy.sh"` |
| `build-package.sh` | Build step run on build hosts (developer machines, CI), never on endpoints; one staging path for three package kinds; the kind tools are native executables that Git Bash can launch | <approval date> | `& $bashExe "$path/build-package.sh"` (bashExe = the Git Bash known-path lookup used by check-pre-push.ps1) |
```

Do not copy build-deploy's justification: build-package's output is per-OS,
uncommitted binary artifacts (Lang evaluation).

### 3b. OS guard exemptions table (change one row, add one row)

OLD:

```markdown
| Build scripts | `build-deploy.sh` | See cross-language exceptions |
```

NEW:

```markdown
| Build scripts | `build-deploy.sh`, `build-package.sh` | See cross-language exceptions |
| Package launchers | `packaging/<os>/*` (pkg postinstall and runner, Intune install/detect/uninstall scripts, deb maintainer scripts, `aitools-setup`) | Platform-native files that MDM agents or dpkg run; exempt from `.sh`/`.ps1` pairing. Thin: resolve the run context, lay down state, call `scripts/aitools-install.*` from the payload (BP-5) |
```

Also in the same rule, "Platform targeting principle" ("Every script must have
both variants unless listed in the exemptions table") needs no change: the new
row is in that table.

---

## 4. `.claude/rules/deploy-paths.md`: third path

Owning PR: #99 (adds "MDM run order" after the list, a build-deploy note in
"When changing `scripts/setup-*.sh/.ps1`" step 2, and rewrites the duplication
section). This edit touches only the heading and the list, which #99 leaves
as is. Apply after #99 merges. Based on DocsInv section 3a, adjusted to BP-1
(payload = public aitools tree at a pinned ref, not the dotprofile `deploy/`),
BP-2 (runs the dev-path scripts), BP-11 (no personal data in a package).

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

Three parallel deployment paths must produce equivalent results. The dev and
MDM paths stay as they are; the package path is added beside them
(commander, 2026-10-26):

1. **Dev/repo path** (`scripts/setup-*.sh/.ps1`): reads `shared/` and user repo at
   runtime. Used by `aitools` CLI.
2. **MDM path** (`<userRepoPath>/deploy/setup-*.sh/.ps1`): self-contained, personalized,
   generated by `build-deploy.sh` into the user's dotprofile repo. Used for endpoint
   deployment. The shared `aitools/deploy/` is frozen (no longer regenerated).
3. **Package path** (`scripts/build-package.sh`): installable packages for a fleet of
   users: a Windows Intune Win32 app (`.intunewin`), an unsigned macOS PKG (Intune,
   Jamf) and a Linux `.deb` for Ubuntu 24.04 and 22.04 (VMs and containers,
   including Claude Code web and Cursor cloud). The payload is the aitools tree at
   a pinned ref (`git archive`), never the dotprofile `deploy/`; the package runs
   the dev-path scripts from it (`scripts/aitools-install.*`), so it adds no third
   copy of setup logic. `build-package.sh` never calls `build-deploy.sh`. No
   personal data goes into a package. Design: `@plans/build-package/design.md`.

### Equivalence

For the same platform, environment and profile, all three paths leave the same
end state: the same files under `~/.aitools`, `~/.claude` and `~/.cursor`, and the
same managed-tool states and summary rows. The package path holds this by
construction (same scripts, same order). Where a package user has no dotprofile,
only the profile-sourced content differs (the neutral fleet template, BP-11),
and the run says so in its summary; it never silently uses another profile.
```

Also in the same file, "### When changing `scripts/setup-*.sh/.ps1`" gets a
last step (number it after #99's merged list):

```markdown
N. If the script runs on the package path (every script `scripts/aitools-install.*`
   runs), run `bash scripts/build-package.sh stage` and verify the staged payload
   contains the change
```

(`stage` is the BP-3 subcommand; confirm its final name against what B2 ships
before applying.) The `paths:` front matter needs no change (`scripts/**`,
`plans/**` already match).

---

## 5. `.cursor/rules/deploy-paths.mdc`: third path mirror

Owning PR: #99 (adds "MDM run order" after the list; does not touch the
heading or list). Apply after #99 merges.

OLD:

```markdown
## Dual Deployment Paths (this repo)

Two deployment methods must produce equivalent results:

1. **Dev/repo path** (`scripts/setup-*.sh/.ps1`): reads `shared/` and user repo at runtime. Used by `aitools` CLI.
2. **MDM path** (`deploy/setup-*.sh/.ps1`): self-contained with build-time embedded content. Generated by `build-deploy.sh`.
```

NEW:

```markdown
## Deployment Paths (this repo)

Three parallel deployment paths must produce equivalent results:

1. **Dev/repo path** (`scripts/setup-*.sh/.ps1`): reads `shared/` and user repo at runtime. Used by `aitools` CLI.
2. **MDM path** (`deploy/setup-*.sh/.ps1`): self-contained with build-time embedded content. Generated by `build-deploy.sh`.
3. **Package path** (`scripts/build-package.sh`): Windows `.intunewin`, unsigned macOS PKG (Intune, Jamf), Linux `.deb` (Ubuntu 24.04/22.04). Payload = the aitools tree at a pinned ref; runs the dev-path scripts from it (no third copy of setup logic). Equivalence and detail: `.claude/rules/deploy-paths.md`.
```

---

## 6. `shared/claude-shared.md`: Cross-Platform Awareness line

Owning PR: #105 (adds two lines after "Projects live in git repos"; does not
change this line). Apply after #105 merges. Keep the dotprofile template in
sync (entry 10; `deploy-paths.md` "Template sync"): this file is the fallback
template every fleet user without a dotprofile receives, so the personal "I
work on" form does not fit it.

OLD:

```markdown
- I work on both Windows 11 and macOS -- both are first-class, ensure a seamless experience on either
```

NEW:

```markdown
- aitools supports macOS, Windows, Linux (Ubuntu), Claude Code web and Cursor cloud -- each is first-class, ensure a seamless experience on every one (list: `~/.aitools/reference/cross-platform-detail.md`, "Supported platforms and environments")
```

Later (not needed for this mission, DocsInv rows 6-7): add "(macOS, Linux)"
next to the macOS path and `python3`/`pip3` forms, and a Per-Platform Tools
bullet for Linux and the hosted environments once PkgLinux/B7 settle the tool
list.

---

## 7. `reference/tool-support-decision-tree.md`: Terms rows

Owning PRs: #101 and #106 (neither touches these two rows). Apply after both
merge. The `cursor-cloud` part waits for P-2 and B5 (as entry 2); the
`dnf` part can go in at once.

OLD:

```markdown
| platform | Governed term (`/glossary`); API value `$AITOOLS_PLATFORM` / `$AitoolsPlatform` = `macos`, `linux`, `windows`. On Linux the package-manager family (`apt`, `dnf`, ...) also selects methods (section 6 `family`) |
| environment | Governed term (`/glossary`); here only its API value `$AITOOLS_ENVIRONMENT` / `$AitoolsEnvironment` = `local` or `claude-code-web` |
```

NEW:

```markdown
| platform | Governed term (`/glossary`); API value `$AITOOLS_PLATFORM` / `$AitoolsPlatform` = `macos`, `linux`, `windows`. On Linux the package-manager family (`apt`, `dnf`, ...) also selects methods (section 6 `family`). Supported family: `apt` (Ubuntu 24.04, 22.04); `dnf` stays in the schema but is not a supported platform (`@reference/cross-platform-detail.md` "Supported platforms and environments") |
| environment | Governed term (`/glossary`); here only its API value `$AITOOLS_ENVIRONMENT` / `$AitoolsEnvironment` = `local`, `claude-code-web` or `cursor-cloud` |
```

If B5 has not shipped when this is applied, keep the environment row as OLD.

---

## 8. `reference/logging.md`: system-phase log location (BP-16)

Owning PR: #101 (adds a `deploy.jsonl` row in section 3 and a new section 7;
does not touch section 1). Apply after #101 merges.

OLD:

```markdown
deploy-state, proposed telemetry — see `@.claude/rules/aitools-workspace.md`),
so `logs/` joins it naturally.
```

NEW:

```markdown
deploy-state, proposed telemetry — see `@.claude/rules/aitools-workspace.md`),
so `logs/` joins it naturally.

**One exception: the package path's system phase.** A package launcher running
as root or SYSTEM has no user `~/.aitools`, so it sets `AITOOLS_LOG_DIR` to the
OS's machine log directory: `/Library/Logs/aitools` (macOS), `C:\ProgramData\aitools\logs`
(Windows), `/var/log/aitools` (Linux). Its user phase, and every other run, logs
to `~/.aitools/logs/` as above (`@plans/build-package/design.md`).
```

---

## 9. Glossary proposals (`/glossary` skill)

The glossary registry is owned by #101 and is protected. Apply through the
`/glossary` skill after #101 merges, with commander review of each term. Current
`platform` and `environment` definitions are quoted from DocsInv section 4 (read
through `/glossary` on 2026-10-26); re-read them through the skill before
applying.

| Term | Type | Draft definition | Source |
|---|---|---|---|
| deployment path | new term | One of the parallel ways aitools reaches a machine or environment: the dev path (`aitools` running `scripts/`), the MDM path (`build-deploy.sh` -> dotprofile `deploy/`), or the package path (`build-package`). All three must leave the same end state for the same platform, environment and profile. Distinct from deployment scope (user/project/managed level). | `.claude/rules/deploy-paths.md` |
| package path | new term | The deployment path that installs aitools from a built package (a Windows Intune Win32 app, an unsigned macOS PKG for Intune or Jamf, or a Linux `.deb` for Ubuntu), built by `build-package` from the aitools tree at a pinned ref. It runs the dev-path scripts from that payload. Parallel to the dev and MDM paths. | `.claude/rules/deploy-paths.md`; `plans/build-package/` |
| aitools package | new term | A package file that `build-package` produces (one per package kind: `.intunewin`, `.pkg`, `.deb`). Named this way to tell it apart from a package-manager package (brew formula, winget id, apt package) in the tool registry. | `plans/build-package/` |
| fleet user | new term | A person whose machine receives aitools through an endpoint-management tool (Intune, Jamf) or a package, rather than by running the installer themselves. A fleet user may have no dotprofile repo. | `plans/build-package/` |
| console user | new term | The user logged in at the machine's console when a package or MDM agent runs as root or SYSTEM: the user whose `HOME` (`~/.aitools`, `~/.claude`, `~/.cursor`) the install targets. Resolved by the target-user API (BP-10). | `plans/build-package/` |
| platform | amend | Current: "macOS, Windows, Linux. Linux is further distinguished by package-manager family (apt, dnf)." Proposed: "macOS, Windows, Linux. Supported: macOS, Windows 11, Linux = Ubuntu 24.04 and 22.04 (apt); other Linux families such as dnf are unsupported (2026-10-26). Linux is further distinguished by package-manager family." | `reference/cross-platform-detail.md` "Supported platforms and environments" |
| environment | amend | Keep the current text (it already names Claude Code web and Cursor cloud agents); append: "Supported: local, Claude Code web, Cursor cloud (`reference/cross-platform-detail.md` \"Supported platforms and environments\")." | same |

`build-package` itself is a tool name, not a governed term. INCIDENT 4 (DocsInv):
"package" now has two meanings; the "aitools package" term resolves it.

---

## 10. Dotprofile template (`aitools-nobul-jose/claude/CLAUDE.md`)

No PR; other repo (`/Users/new-jose/repos/aitools-nobul-jose/claude/CLAUDE.md`).
Jose's choice (P-7). This template wins over `shared/claude-shared.md` on his
machines, and the line is personal, so it may stay true about his own machines.
Dotprofile writes go to its main directly (N-Q2) after approval.

OLD (verified 2026-10-26):

```markdown
- I work on both Windows 11 and macOS -- both are first-class, ensure a seamless experience on either
```

NEW (suggested, the five-item form):

```markdown
- I work on Windows 11, macOS, Linux (Ubuntu), Claude Code web and Cursor cloud -- all are first-class, ensure a seamless experience on every one (list: `~/.aitools/reference/cross-platform-detail.md`, "Supported platforms and environments")
```

Later: the next line "if I switch from Mac to Windows on the same project" ->
"if I switch machines or environments on the same project".

---

## Applied in this mission (no PR owned these files on 2026-10-26)

`reference/cross-platform-detail.md` (new authoritative section; `cursor-cloud`
proposed in "API" and the closed-list paragraph), `README.md`, `CLAUDE.md`,
`reference/harness.md`, `ROADMAP.md`, `.claude/rules/aitools-workspace.md`,
`reference/tool-evaluation-criteria.md`, `.cursor/rules/cross-platform.mdc`,
`shared/cursor-rules/user-rules.md` (line "I work on both"; the `C:\repos\`
line keeps its separate pending draft in the PR #99 mission folder).

Not done (DocsInv "later", no PR owner): `.cursor/rules/tool-lifecycle.mdc`
cross-platform note, `reference/tool-evaluation-playbook.md` step 3 criteria
row, README "Install from a package" subsection (when a package exists), the
CLAUDE.md intent ("Jose's ... his repositories and machines": fleet audience,
DocsInv open question 4; left unchanged).
