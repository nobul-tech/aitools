# build-package: implementation plan (version 1.0)

**Intent**: **Purpose**: Give the mission that builds the package path an
executable sequence: the pinned interfaces, batches B1-B14 of 2-3 files each
(goal, files, merge dependencies, behaviour with error handling, verification
commands, done criteria), the test matrix, the merge order against open PRs,
risks, the tool-lifecycle gate and the open commander questions. **Scope**:
Execution of the decisions BP-1..BP-20. NOT their rationale
(`plans/build-package/design.md`). NOT the per-defect remediation list for
existing code (`plans/build-package/remediation.md`, same batch IDs). NOT
verbatim old/new edits: each batch's executing delegate drafts them against the
code as it stands when the batch starts, because open PRs move that code.
**Audience**: the executing mission and its per-batch delegates, who check
every name they use against the "Interfaces" section; Jose, who approves the
gates (P-1..P-7, Phase 2).

Author: S3-BuildPkg-PlanWriter for S3-BuildPkg, version 1.0, 2026-10-26.

Sources: the decisions file
`.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-BuildPkg/S3-BuildPkg-decisions.md`
(binding contract: BP-n, batch IDs, PR-owned files, P-n), the wave-1 files in
that folder (short names: RevBuild, RevInstall, RevLib, RevSetup, RevTools,
PkgWin, PkgMac, PkgLinux, Lang, DocsInv), `S3-MdmPkg/S3-MdmPkg-report.md`
(MDM-PKG) and the FAN-PLAN plan
`S3-FanPlan/S3-FanPlan-drafts/plans/rules-fanout-claude.md` (FAN-PLAN).
Line numbers are aitools `main` 5976553 unless a PR is named; this is a plan
file, so line numbers are allowed (documentation-standards.md) but they drift:
re-locate by function name before editing.

## 1. How to execute this plan

- **Sub-agent pattern** (plan-execution.md): this plan touches 3+ code files
  and the shared library, so every code batch goes to a fresh delegate. The
  delegate prompt carries the seven delegation-duty elements (`/delegate`
  skill), the error-handling rules block from
  `reference/plan-execution-detail.md` "Sub-agent prompt template", and this
  plan's "Interfaces" section verbatim.
- **v1.0 is design-level.** Each batch gives exact file lists, interfaces,
  behaviour and pseudocode with error handling, and verification commands. The
  batch's delegate first drafts verbatim old/new edits against the then-current
  code (after the PRs in its "After" column merge), runs the error-handling
  audit checklist (`reference/plan-execution-detail.md` "Error-handling audit
  checklist") on every block, and only then applies them.
- **Ship per batch** (D-DEL4; handoff section I): own worktree from
  `origin/main`, branch `feature/build-package-<batch id lower case>` (for
  example `feature/build-package-b2`), commit and push after every batch, open
  a PR to `main`. Never push to main.
- **Orchestrate with a fresh delegate per batch**: orchestrator missions that
  hand each batch to a fresh delegate finish; single long sessions fade rules
  (handoff section I; plan-execution-detail.md "Why").
- **Contract drift guard**: before writing code, the delegate greps the repo
  for every interface name it uses (section 3) and stops with a "Contract
  change" note if one differs.
- **Protected files** (sources-of-truth.md) are never edited by a code batch:
  B13 applies approved drafts after the owning PR merges.
- Bash tool rules for delegates: simple commands only, scratch scripts for
  anything longer, Perl not sed, never run `aitools`, `aitools install`,
  `setup-user-*`, `deploy-harness` or `build-deploy.sh` against the real HOME
  (packet section 5).

## 2. Decisions (reference only; argued in design.md)

| ID | Decision (short) | Batches |
|---|---|---|
| BP-1 | Payload = public tree at a pinned ref + MANIFEST + BUILD-INFO; no personal data | B2 |
| BP-2 | Package path runs the dev-path scripts from the payload; build-deploy.sh untouched and never called | all |
| BP-3 | One bash script `scripts/build-package.sh`, one function per kind | B2, B8a, B9a, B10a |
| BP-4 | Native build host per kind; one CI workflow, three jobs | B11 |
| BP-5 | Launchers in `packaging/<os>/`, exempt from .sh/.ps1 pairing ("package launchers") | B8-B10, B13 |
| BP-6 | Entry point = existing installer + `--phase`, `--package-mode`; one order file | B3a, B3b |
| BP-7 | Run context per OS (macOS postinstall + LaunchAgent; Windows App A System + App B User; Linux postinst files only + `aitools-setup`) | B8-B10 |
| BP-8 | Prerequisites are separate MDM packages / Depends | B8-B10, B12 |
| BP-9 | One `.deb`, `Architecture: all`, 22.04 + 24.04 | B10a |
| BP-10 | Target-user / privileged-run API in the lib; only launchers switch user | B5a, B6 |
| BP-11 | Personalisation at run time; neutral fleet template; tiers proposed (P-3) | B6a, B6d |
| BP-12 | One version string; per-channel update mechanism; no self-update | B2, B3b, B8-B10 |
| BP-13 | Overwrite managed files with backups; runs per version; fix backup churn | B6b, B6c |
| BP-14 | winget CLI never in SYSTEM; user phase `--scope user --exact --source winget` | B7 |
| BP-15 | Detection rules per channel | B8-B10 |
| BP-16 | Logging locations per phase | B2, B5b, B8-B10 |
| BP-17 | Identifier `tech.nobul.aitools` | B8-B10 |
| BP-18 | Supported list in `reference/cross-platform-detail.md` | B0/B13 (DocsWriter) |
| BP-19 | Environment `cursor-cloud` (proposed, P-2) | B5b |
| BP-20 | Unsigned v1; signing later | B8a, B14 |

## 3. Interfaces (pinned)

Every consumer checks these names against the code before using them. A batch
that must change one records a "Contract change" note in its PR body and in
this file's "Contract changes" section.

### 3.1 `scripts/build-package.sh`

```
build-package.sh <command> [--ref <git-ref>] [--version <X.Y.Z>] [--out <dir>] [--intune-tool <path>] [--dry-run] [--help|-h]
```

Aligned with the B0 scaffold (`scripts/build-package.sh` as written by
ScaffoldWriter, read 2026-10-26); differences from the launch-prompt contract
are listed in section 11.

| Item | Value |
|---|---|
| Commands | `stage` (payload only), `pkg`, `intune`, `deb` (stage + that kind), `all` (stage + every kind this host can build; the others get OK `n/a (<host>)`); exactly one |
| `--ref <git-ref>` | default `HEAD`; resolved with `git rev-parse --verify --quiet "<ref>^{commit}"` (also in a dry run); a dirty working tree does not matter (the payload comes from the commit) |
| `--version <X.Y.Z>` | must match `^[0-9]+\.[0-9]+\.[0-9]+$` (no `v`); **required** for `pkg`, `intune`, `deb`, `all`; optional for `stage` (then BUILD-INFO says `version=none` and no VERSION file is written) |
| `--out <dir>` | default `${TMPDIR:-/tmp}/aitools-build-package/out`; an existing non-directory is refused. B2 adds: an existing non-empty dir without the marker file `.build-package-out` is refused (protects the `rm -rf` of `stage/`) |
| `--intune-tool <path>` | IntuneWinAppUtil.exe to use; default: `IntuneWinAppUtil.exe` or `IntuneWinAppUtil` on PATH; ignored (logged) off Windows |
| `--dry-run` | resolves ref, version, out and tool availability; logs `[DRY RUN]` plan lines; writes nothing (also `AITOOLS_DRY_RUN=1`) |
| `--help`, `-h` | the header comment as usage, exit 0, wins over other arguments |
| Unknown option or command | `log_error "Unknown option: <x>"` / `"Unknown command: <x>"` + brief usage, ERROR row `bad arguments`, exit 1 (never 0, never 2) |
| Exit | 0 = every requested kind built (warnings allowed); 1 = any ERROR |
| Logging | `logging_init "build-package"` → `$AITOOLS_LOG_DIR/deploy.log` |
| Summary rows | tool name `build-package` for every row; detail `<kind>: <result>` (30 chars max, `short`): `OK build-package pkg: n/a (linux)`, `ERROR build-package deb: cannot build (macos)`, and per built kind `OK build-package <kind>: <file name>` (B2/B8-B10 add these) |
| Functions | `stage_payload`, `build_pkg`, `build_intune`, `build_deb`, `detect_kind` (pinned for tests) |
| Host detection | `detect_kind`: native platform (`$AITOOLS_PLATFORM`) and then the tool: pkg needs `pkgbuild` + `productbuild` on macOS; deb needs `dpkg-deb` on Linux; intune needs Windows and the exe. Note for B2: cross-platform.md "Dead code from platform guards" prefers capability over identity; the platform test here encodes BP-4 (native host) and is kept, but the B2 delegate confirms it with the P-1 exemption text |
| Template token | `@VERSION@` in launcher templates (`control.in` today; `detect-user.ps1`, the stub Info.plist), replaced with Perl in the staged copy |

Outputs in `--out`:

| File | Kind |
|---|---|
| `stage/` (the staged tree, section 3.2) | all |
| `aitools-<v>.pkg` | pkg (productbuild product archive) |
| `aitools-system-<v>.intunewin`, `aitools-user-<v>.intunewin` | intune |
| `aitools_<v>_all.deb` | deb |
| `SHA256SUMS` | every built file, one line each (`shasum -a 256` / `sha256sum` by capability) |

### 3.2 Staged tree and marker files

```
<out>/stage/
  VERSION                 X.Y.Z (one line, no "v"; absent for a stage without --version)
  repo/MANIFEST           sorted relative paths of every file under repo/ except MANIFEST, BUILD-INFO, VERSION
  repo/BUILD-INFO         key=value lines: version=, commit=, ref=, built= (UTC, Z), kind=, builder=build-package.sh
  repo/VERSION            same as VERSION
  repo/<include list>     scripts/ shared/ reference/ registries/ .claude/rules/ .claude/skills/ .claude/hooks/ (if present)
```

- Excluded inside the include list: paths matching `\.bak\.` and `(^|/)\.DS_Store$`.
- `kind=` is `stage` in the staged tree; each backend rewrites it in its own
  copy (`pkg`, `intune`, `deb`).
- **Package-mode marker**: a `repoPath` whose `BUILD-INFO` exists and that has
  no `.git` is a package payload. `scripts/aitools` and deploy-harness use this
  test (B3b, B4).
- **Per-user marker**: `~/.aitools/pkg-version` (`%USERPROFILE%\.aitools\pkg-version`),
  one line `X.Y.Z`, written by the launcher (`aitools-pkg-run.sh`,
  `install-user.ps1`, `aitools-setup`) after the installer's user phase exits
  0 (warnings allowed); temp file + rename; a failed write is ERROR and exit 1
  (the scaffold headers assign it to the launchers). On a non-zero installer
  exit it is left unchanged, so the next run retries.
- **Run lock** (macOS runner, Linux `aitools-setup`): directory
  `~/.aitools/pkg-run.lock` created with `mkdir` (atomic); removed by an EXIT
  trap; a lock older than 2 hours is logged and removed.

### 3.3 Installer flags (B3a)

| bash (`aitools-install.sh`) | PowerShell (`aitools-install.ps1`) | Behaviour |
|---|---|---|
| `--phase system\|user\|all` | `-Phase system\|user\|all` (`ValidateSet`) | default `all` = today's behaviour. `system` = machine-scope steps only (v1: Windows long-paths check; macOS/Linux: one OK row `n/a (no system steps)`). `user` = every other step. An invalid value: `log_error`, exit 1 |
| `--package-mode` | `-PackageMode` | requires the package-mode marker at the installer's repo root, else ERROR, exit 1. Exports `AITOOLS_PACKAGE_MODE=1` and `AITOOLS_FORCE=1` to children; skips gh auth (OK `gh auth` `n/a (package)`), Google Drive detection stays; never clones, pulls, or runs build-deploy; repos dir defaults to `$HOME/repos` without a prompt (the per-user marker is the launcher's job, section 3.2) |
| unknown option | (pwsh binding error, already exit 1) | `log_error "unknown option: <x>"` + usage, exit 1 (fixes RevInstall R3; `--help` alone exits 0) |

Environment variables: `AITOOLS_PACKAGE_MODE=1` (set by the installer, read by
the lib and `scripts/aitools`), `AITOOLS_TARGET_USER` (override for the
target-user API), `AITOOLS_LOG_DIR` (existing; launchers set it for the
system phase), `AITOOLS_ENVIRONMENT` (existing; `cursor-cloud` after P-2).

### 3.4 Order file (B3a)

`scripts/aitools-order.txt`: one script base name per line, in run order; `#`
starts a comment; blank lines ignored; no phase column in v1 (every line is a
user-phase config script). Content (post-#106 sync order, BP-6; RevInstall
2.3):

```
# Config scripts run by aitools-install (Step 21) and aitools sync, in order.
deploy-harness
setup-user-claude
setup-user-mcp
setup-user-skills
setup-cursor-ide-mcp
setup-user-cursor
setup-user-settings
setup-user-hooks
```

Readers: `aitools-install.sh`, `aitools-install.ps1`, `scripts/aitools`,
`scripts/aitools.ps1`. A missing or empty order file is ERROR, exit 1 (no
built-in fallback list, so the two lists can never diverge again).
deploy-harness keeps #106's semantics: its exit 2 stops the run; any other
script's exit 2 is an ERROR row and the run continues (brief).

### 3.5 Library API (B5a, B5b)

| bash (`aitools-lib.sh`) | PowerShell (`aitools-lib.ps1`) | Result |
|---|---|---|
| `resolve_target_user` | `Resolve-TargetUser` | sets `AITLIB_TARGET_USER`, `AITLIB_TARGET_HOME`, `AITLIB_TARGET_UID`, `AITLIB_TARGET_VIA` (`env\|self\|console\|sudo\|root\|none`) / `$script:AitLibTargetUser`, `AitLibTargetHome`, `AitLibTargetSid`, `AitLibTargetVia`; returns 0 found, 1 none, 3 error |
| `is_privileged_run` | `Test-PrivilegedRun` | exit 0 / `$true` when uid 0 or SYSTEM (`S-1-5-18`) |
| `run_as_target_user CMD ARGS...` | `Invoke-AsTargetUser` (v1: refuses with ERROR; App B already runs as the user) | macOS `launchctl asuser <uid> sudo -u <user> -H`; Linux root→user `sudo -u <user> -H` when sudo exists, else `runuser -u <user> --`; returns CMD's exit |
| `require_user_context` | `Assert-UserContext` | log_error + ERROR row + return 1 when privileged and HOME is not the run user's (bash: `[ "$(id -u)" = 0 ] && [ ! -O "$HOME" ]`; PS1: identity is SYSTEM) |
| `is_cursor_cloud` | `Test-CursorCloud` | after P-2 |
| `is_package_mode` | `Test-PackageMode` | `AITOOLS_PACKAGE_MODE=1` |

Return codes never 2 (D-TS13: bare exit 2 = user abort).

### 3.6 Packaging files (`packaging/`)

| File | Installed as | Runs as | Interpreter |
|---|---|---|---|
| `packaging/macos/postinstall` | pkg `Scripts/postinstall` | root (installer) | `/bin/bash` 3.2 |
| `packaging/macos/aitools-pkg-run.sh` | `/Library/Application Support/aitools/bin/aitools-pkg-run.sh` | console user | `/bin/bash` 3.2 |
| `packaging/macos/tech.nobul.aitools.firstrun.plist` | `/Library/LaunchAgents/tech.nobul.aitools.firstrun.plist` (Label `tech.nobul.aitools.firstrun`, RunAtLoad true, ProgramArguments `/bin/bash`, the runner path) | each user at login | launchd |
| `packaging/windows/install-system.ps1` | App A content root; install command `"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File .\install-system.ps1` | SYSTEM | pwsh 7 |
| `packaging/windows/install-user.ps1` | App B content root; install command `"C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass -File .\install-user.ps1` | signed-in user | pwsh 7 |
| `packaging/windows/detect-user.ps1` | uploaded as App B's custom detection script (not in the package) | Intune detection host | Windows PowerShell 5.1 compatible |
| `packaging/linux/control.in` | `DEBIAN/control` after token replacement | n/a | n/a |
| `packaging/linux/postinst` | `DEBIAN/postinst` (mode 0755) | root (dpkg) | `/bin/sh` or bash with `set -e` |
| `packaging/linux/aitools-setup` | `/opt/aitools/bin/aitools-setup`; `/usr/bin/aitools-setup` symlink in the package data | user, or root in a container | bash |

Added by later batches (not scaffolded in B0; names pinned here):
`packaging/macos/aitools-uninstall.sh` (B8b), `packaging/windows/uninstall-system.ps1`
(B9a; Intune does not expand environment variables in the uninstall command,
PkgWin 2), `packaging/linux/prerm` (B10b),
`packaging/linux/cloud/claude-code-web-setup.sh` and
`packaging/linux/cloud/cursor-install.sh` (B10c).

`aitools-setup` flags: `--user <name>`, `--force` (sets `AITOOLS_FORCE=1`),
`--environment <value>` (sets `AITOOLS_ENVIRONMENT`), `--rerun` (ignore a
matching `pkg-version`), `--help`; unknown option exit 1.

### 3.7 Identifiers, paths and logs

| Item | Value |
|---|---|
| macOS pkg identifier, stub bundle id | `tech.nobul.aitools` (BP-17) |
| LaunchAgent label | `tech.nobul.aitools.firstrun` |
| Stub app | `/Library/Application Support/aitools/aitools.app`, `CFBundleIdentifier tech.nobul.aitools`, `CFBundlePackageType APPL`, `CFBundleShortVersionString` = `CFBundleVersion` = X.Y.Z, `LSUIElement true`, executable `Contents/MacOS/aitools` = `#!/bin/sh` / `exit 0`; generated by `build_pkg` |
| Component plist keys | `BundleIsRelocatable false`, `BundleIsVersionChecked false` (rollbacks must install; PkgMac 1) |
| Windows registry | `HKLM\SOFTWARE\aitools`, value `Version` (REG_SZ X.Y.Z), written last by App A |
| Windows payload | `%ProgramFiles%\aitools\` (`repo\`, `VERSION`) |
| Linux package name | `aitools`; file `aitools_<v>_all.deb`; prefix `/opt/aitools/` |
| System-phase log dir | macOS `/Library/Logs/aitools`, Windows `C:\ProgramData\aitools\logs`, Linux `/var/log/aitools`; file `deploy.log` (lib naming; see contract change C-2) |
| User-phase log dir | `~/.aitools/logs` (unchanged) |
| logging_init names | `build-package`, `aitools-pkg-postinstall`, `aitools-pkg-run`, `aitools-install-system`, `aitools-install-user`, `aitools-setup` |

## 4. Batches

Batch table (from the decisions file; letter suffixes split a batch to keep
2-3 files):

| Batch | Files | After |
|---|---|---|
| B0 | this mission (docs, scaffold) | -- |
| B1 | none (approvals, evaluations) | -- |
| B2 | `scripts/build-package.sh`, `tests/build-package/test-stage.sh` | B0 |
| B3a | `scripts/aitools-install.sh`, `scripts/aitools-install.ps1`, `scripts/aitools-order.txt` | #106, #116 |
| B3b | `scripts/aitools`, `scripts/aitools.ps1` | B3a, #113, #115 |
| B4 | `scripts/deploy-harness.sh`, `scripts/deploy-harness.ps1`, `tests/deploy-harness/test-deploy-harness.sh` | #100, #110, #111 |
| B5a | `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1` (target-user API, package mode, adopt guard) | #103, #112, #113, #115, #116, FAN-PLAN Batch A |
| B5b | `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1` (logging fail-safe, HOME guard, `cursor-cloud`, `sync_managed_json` package rule) | B5a; P-2 for `cursor-cloud` |
| B6a | `scripts/setup-user-claude.sh`, `.ps1` | FAN-PLAN B-D, #103, #112, B5a |
| B6b | `scripts/setup-user-cursor.sh`, `.ps1` | #109, #110, B5a |
| B6c | `scripts/setup-user-shell.sh`, `.ps1` | B5a |
| B6d | `scripts/setup-user-hooks.sh`, `.ps1`, `scripts/setup-user-settings.sh` (+ `.ps1` as B6d2 if needed) | B5a; P-3 for tiers |
| B6e | `shared/hooks/session-archive.sh`, `shared/hooks/session-catchup.sh` | -- (hook rollout rules apply) |
| B6f | `scripts/setup-user-config.sh`, `.ps1` | #98, #114, B5a |
| B7a..B7n | one tool pair per batch (section 4 B7) | B5a |
| B8a | `scripts/build-package.sh` (`build_pkg`), `packaging/macos/postinstall`, `packaging/macos/tech.nobul.aitools.firstrun.plist` | B2, B3a, B5a |
| B8b | `packaging/macos/aitools-pkg-run.sh`, `packaging/macos/aitools-uninstall.sh` | B8a |
| B9a | `scripts/build-package.sh` (`build_intune`), `packaging/windows/install-system.ps1`, `packaging/windows/uninstall-system.ps1` | B1 Phase 2 approval, B2, B3a, B5a |
| B9b | `packaging/windows/install-user.ps1`, `packaging/windows/detect-user.ps1` | B9a |
| B10a | `scripts/build-package.sh` (`build_deb`), `packaging/linux/control.in`, `packaging/linux/postinst` | B2, B3a |
| B10b | `packaging/linux/aitools-setup`, `packaging/linux/prerm` | B10a, B5a |
| B10c | `packaging/linux/cloud/claude-code-web-setup.sh`, `packaging/linux/cloud/cursor-install.sh` | B10b; P-2 |
| B11a | `.github/workflows/package.yml` | B2, B8a, B9a, B10a; actions evaluation (B1) |
| B11b | `scripts/check-pre-push.sh`, `scripts/check-pre-push.ps1` (step 11) | B2; P-1 (cross-language row) |
| B12 | none (test runs; results file) | B8-B11 |
| B13 | PR-owned docs, one PR per owning PR | each owning PR |
| B14 | optional signing | B12 |

Contract change C-1 (recorded in section 11): B8a, B9a and B10b also depend
on B5a, because the launchers call the target-user and privileged-run API.

---

### B0 -- this mission

Docs (`design.md`, this file, `remediation.md`, `doc-edits-pending.md`) and the
scaffold: `scripts/build-package.sh` stub and the `packaging/` skeleton
(ScaffoldWriter). Done when the orchestrator commits them to main.

### B1 -- approvals and evaluations (no code)

- **Goal:** clear every gate a code batch waits on.
- **Items and owners:**
  1. P-1: commander approves the two `cross-platform.md` rows (bash-only build
     script; "package launchers" exemption category, which also covers
     `detect-user.ps1` running under Windows PowerShell 5.1). Applied in B13
     after #99.
  2. P-4: `/tool-eval` of IntuneWinAppUtil (read the official docs with
     chrome-devtools; write `reference/evaluations/intunewinapputil-windows-<date>.md`;
     health flags: Windows yellow per PkgWin 1), Under Evaluation registry entry
     via `/tool-registry` (protected), then the **Phase 2 gate** (section 8).
  3. P-2: `cursor-cloud` value and signals; verify on one Cursor cloud run
     (B12 row 6 can run early with a hand-written install command).
  4. P-3: fleet content tiers and the neutral fleet template.
  5. P-4: the "build-host tool" lifecycle class (tool-lifecycle.md draft).
  6. Evaluate `actions/upload-artifact` (check.yml uses only
     `actions/checkout@v4`, Lang 2) under the user CLAUDE.md "Tool & Source
     Evaluation" gate.
  7. P-5, P-6, P-7 answers.
- **Verification:** each answer recorded in the decisions file (section 4) and
  in this file's section 10.
- **Done:** P-1, P-2, P-4 (Phase 2) answered; the others may follow.

### B2 -- `build-package.sh stage` and its tests

- **Goal:** a staged payload on any host, with MANIFEST, BUILD-INFO and VERSION.
- **Files:** `scripts/build-package.sh` (replace the B0 stub's `stage` path),
  `tests/build-package/test-stage.sh` (new, mode 100755).
- **After:** B0.
- **Behaviour (pseudocode, bash 3.2):**

```bash
#!/usr/bin/env bash
# build-package.sh -- header: name, purpose, intent, "Safe to re-run",
# platform: macOS/Linux/Git Bash (build hosts only), /tool-registry skill ref.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ ! -f "$SCRIPT_DIR/aitools-lib.sh" ]; then
    printf '%s\n' "build-package: aitools-lib.sh not found next to the script" >&2
    exit 1
fi
source "$SCRIPT_DIR/aitools-lib.sh"
logging_init "build-package"
# No OS guard: build script exemption (cross-platform.md, pending P-1 row).

INCLUDE_PATHS="scripts shared reference registries .claude/rules .claude/skills .claude/hooks"
EXCLUDE_RE='(\.bak\.|(^|/)\.DS_Store$)'

stage_payload() {   # globals: REF VERSION OUT; sets STAGE_DIR, COMMIT
    COMMIT=""
    if ! COMMIT="$(git -C "$REPO_ROOT" rev-parse --verify "${REF}^{commit}" 2>&1)"; then
        log_error "ref not found: $REF ($COMMIT)"
        write_summary ERROR "stage" "ref not found: $REF"
        return 1
    fi
    STAGE_DIR="$OUT/stage"
    # rm only inside OUT, which carries the marker (checked in main)
    rm -rf "$STAGE_DIR"
    if ! mkdir -p "$STAGE_DIR/repo"; then
        log_error "cannot create $STAGE_DIR/repo"; write_summary ERROR "stage" "mkdir failed"; return 1
    fi
    # keep only include paths that exist at the commit (git archive fails on a missing pathspec)
    present=""
    for p in $INCLUDE_PATHS; do
        if [ -n "$(git -C "$REPO_ROOT" ls-tree --name-only "$COMMIT" -- "$p")" ]; then
            present="$present $p"
        else
            log "include path absent at $COMMIT: $p"
        fi
    done
    # MANIFEST from the commit, minus excludes (perl, not grep -P)
    if ! git -C "$REPO_ROOT" ls-tree -r --name-only "$COMMIT" -- $present \
        | perl -ne "print unless m{$EXCLUDE_RE}" | LC_ALL=C sort > "$STAGE_DIR/repo/MANIFEST"; then
        log_error "MANIFEST generation failed"; write_summary ERROR "stage" "manifest failed"; return 1
    fi
    if ! git -C "$REPO_ROOT" archive --format=tar "$COMMIT" -- $present | tar -x -C "$STAGE_DIR/repo"; then
        log_error "git archive | tar failed"; write_summary ERROR "stage" "archive failed"; return 1
    fi
    # remove the excluded files the archive extracted (paths matching EXCLUDE_RE),
    # then list every regular file under repo/ except MANIFEST (find + perl to strip
    # the "./" prefix), sort with LC_ALL=C and compare with MANIFEST:
    # any difference -> log_error with the first differing path, ERROR row, return 1
    printf '%s\n' "$VERSION" > "$STAGE_DIR/VERSION"
    cp "$STAGE_DIR/VERSION" "$STAGE_DIR/repo/VERSION"   # check rc, ERROR on failure
    write BUILD-INFO (version, commit, ref, built=$(date -u +%Y-%m-%dT%H:%M:%SZ), kind=stage, builder=build-package.sh)
    required files check: repo/scripts/aitools-install.sh .ps1, aitools-lib.sh .ps1,
        deploy-harness.sh .ps1, shared/claude-shared.md, shared/hooks/hooks-manifest.json
        -> each missing: log_error + ERROR row, return 1
    forbidden check: no repo/deploy/, no file named profile.json -> ERROR
    write_summary OK "stage" "<N> files ($COMMIT short)"
}
```

  The pseudocode marks one place ("delegate: use perl") where the delegate
  writes the exact code; `sed` above is a placeholder, not the implementation
  (USO: Perl for string manipulation). Main flow: parse args (unknown → exit 1),
  validate version, resolve `--out` (marker rule, section 3.1), dry-run prints
  and exits 0, dispatch subcommand, exit footer (ERRORS → exit 1).
- **Error-handling audit focus:** every pipeline under `set -o pipefail`; `cp`,
  `mkdir`, `tar` checked; no `2>/dev/null` without comment + check; every
  `log_error` paired with `write_summary ERROR`.
- **Tests (`tests/build-package/test-stage.sh`, new, next to B0's
  `test-cli.sh`, which already covers argument errors, `--version` format,
  `--ref`, dry-run plans and the n/a rows):** stage at `HEAD` into a temp out;
  MANIFEST equals the extracted file list; no `.bak.` or `.DS_Store` path;
  BUILD-INFO has all six keys; VERSION matches `--version`; stage without
  `--version` writes `version=none` and no VERSION; a non-empty `--out`
  without marker refused; a second stage into the same out replaces `stage/`.
  B2 also updates the `test-cli.sh` cases that expect "stage: not implemented".
  Every case under an isolated `HOME` and `AITOOLS_LOG_DIR`.
- **Verification:**
  - `bash -n /Users/new-jose/repos/aitools/scripts/build-package.sh`
  - `/bin/bash /Users/new-jose/repos/aitools/tests/build-package/test-stage.sh` (bash 3.2 on macOS) and with Homebrew bash 5
  - `bash scripts/check-pre-commit.sh` from the worktree
- **Done:** tests pass on macOS (3.2 and 5); stage output reviewed by hand once
  (MANIFEST count vs `git ls-tree -r` count).

### B3a -- installer `--phase`, `--package-mode`, order file

- **Goal:** the existing installer is the package entry point (BP-6).
- **Files:** `scripts/aitools-install.sh`, `scripts/aitools-install.ps1`,
  `scripts/aitools-order.txt` (new).
- **After:** #106 (adds Step 8b deploy-harness and the abort handling), #116
  (replaces the private relay, adds `resolve_repos_dir`).
- **Behaviour:**
  - Flag parsing per section 3.3. bash: an unknown option ends in `log_error`
    + usage + exit 1 (today it prints help and exits 0 at L47-51, L76:
    RevInstall R3). PS1: add `[ValidateSet('system','user','all')][string]$Phase = 'all'`
    and `[switch]$PackageMode`.
  - Package-mode check (both languages): `$REPO/BUILD-INFO` exists and
    `$REPO/.git` does not, else `log_error "--package-mode needs a package payload"`,
    ERROR row, exit 1. Then `export AITOOLS_PACKAGE_MODE=1 AITOOLS_FORCE=1`.
  - Phase gating: wrap each existing step in a phase predicate
    (`phase_includes user`). `system` runs only the machine-scope steps (v1:
    Windows long-paths check, `aitools-install.ps1:224-257`); bash `system` on
    macOS/Linux writes `OK "system phase" "n/a (no system steps)"`.
  - Step 21 (config scripts) and #106's Step 8b read `scripts/aitools-order.txt`
    (section 3.4): deploy-harness runs once, first, with #106's abort rule;
    Step 5 keeps the bootstrap-key writer, and deploy-harness gets
    `--skip-config` if #111 has merged (RevInstall R2), else the double writer
    run stays (logged, not an error).
  - In package mode: Step 2 gh auth → `OK "gh auth" "n/a (package)"`; Step 3
    repos dir → `--repos-path` or config or `$HOME/repos`, no prompt; Step 6
    installs `~/.local/bin/aitools` pointing at the payload's `scripts/aitools`
    (no copy of the repo). The installer does not write `pkg-version`.
  - The 17/18 "skipping (MDM deploy)" branches become
    `OK "<tool>" "n/a (not in payload)"` rows (RevInstall R10) only if the
    delegate's diff stays within these files; otherwise leave them (remediation).
  - Reading the order file (bash): `while IFS= read -r line; do case "$line" in '#'*|'') continue;; esac; ...; done < "$ORDER_FILE"`,
    with a prior `[ -s "$ORDER_FILE" ]` check (missing/empty: ERROR, exit 1).
    PS1: `Get-Content -LiteralPath $orderFile -ErrorAction Stop` inside
    try/catch that logs and exits 1.
- **Verification:**
  - `bash -n scripts/aitools-install.sh`; pwsh parser on the `.ps1`
    (`.scratch/<session>/ps1-parse.ps1` pattern: `[System.Management.Automation.Language.Parser]::ParseFile`)
  - isolated-HOME dry runs: `env HOME=<iso> AITOOLS_LOG_DIR=<iso>/logs bash scripts/aitools-install.sh --dry-run --phase user < /dev/null`;
    `--phase bogus` → exit 1; `--bogus` → exit 1; `--package-mode` from a git
    checkout → exit 1; `--package-mode` from a B2 staged tree
    (`<out>/stage/repo/scripts/aitools-install.sh --dry-run --phase user --package-mode`)
    → exit 0 with `n/a (package)` rows
  - `tests/hookin/test-hookin.sh` (from #106) and `tests/profile/test-install.sh` still pass
- **Done:** both installers accept the flags with identical rows; the order
  file is the only config-script list in the two installers.

### B3b -- `aitools` sync reads the order file; package-mode sync

- **Files:** `scripts/aitools`, `scripts/aitools.ps1`.
- **After:** B3a; #113, #115, #116 (they touch both files).
- **Behaviour:** `deploy_configs` / `Deploy-Configs` read
  `scripts/aitools-order.txt` (same parser and error rule as B3a). When
  `repoPath` holds the package-mode marker: no `git checkout HEAD -- deploy/`,
  no pull, no clone, no build-deploy (`OK "aitools repo" "n/a (package X.Y.Z)"`),
  then run the config loop (RevInstall R8). Fix the PS1 version stamp anchor
  (`(?m)^`, RevInstall R12) if not already fixed by remediation.
- **Verification:** `bash -n`; pwsh parser; isolated-HOME run of
  `scripts/aitools --dry-run` from a git checkout (unchanged rows) and from a
  staged tree's `repo/scripts/aitools` (no git calls: assert with
  `GIT_TRACE=1` output containing no `pull`/`clone`).
- **Done:** a package machine's `aitools` run never touches git for the aitools repo.

### B4 -- deploy-harness from a payload (no git work tree)

- **Files:** `scripts/deploy-harness.sh`, `scripts/deploy-harness.ps1`,
  `tests/deploy-harness/test-deploy-harness.sh`.
- **After:** #100 (rules manifest), #110 (stacked on #100), #111 (MDM variant,
  `--skip-config`).
- **Behaviour:** in `add_source` / `Add-Source`: when the source is not in a
  git work tree and the repo root holds the package-mode marker, list files
  from `$REPO_DIR/MANIFEST` filtered to the source's prefix (instead of
  `git ls-files -z`); otherwise keep today's ERROR "not a git checkout"
  (RevBuild 5, remediation 2). Fix the PS1 stale-`$LASTEXITCODE` guard
  (RevBuild remediation 14) in the same place: check `Get-Command git` once and
  report "git not found" honestly. bin CLIs unchanged. Adopt target: `""` in
  package mode (the payload is read-only).
- **Verification:** `bash -n`; pwsh parser; new test cases: deploy-harness run
  from a B2 staged tree under an isolated HOME deploys every source (counts
  equal to a git-checkout run at the same commit), exit 0; a non-git tree
  without the marker still fails with the ERROR row. Existing
  `tests/deploy-harness/test-deploy-harness.sh` passes.
- **Done:** identical `~/.aitools/{reference,registries,hooks,rules,skills,bin}`
  from a checkout and from a payload of the same commit (diff -r of the two
  isolated HOMEs is empty apart from logs).

### B5a -- library: target user, package mode, adopt guard

- **Files:** `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`.
- **After:** #103, #112, #113, #115, #116 (all edit the lib), FAN-PLAN Batch A
  (lib tracker and fan-out helpers).
- **Behaviour:** section 3.5 API. `resolve_target_user` order: `AITOOLS_TARGET_USER`
  → self when not privileged → macOS `stat -f %Su /dev/console` (empty, `root`,
  `loginwindow`, `_mbsetupuser` = none, rc 1) → Linux `SUDO_USER` (not `root`)
  → root itself (Linux) → none. HOME from `dscl . -read /Users/<u>
  NFSHomeDirectory` (macOS) / `getent passwd <u>` (Linux); a lookup failure is
  rc 3 with `log_error`. `is_package_mode`: when true, `deploy_managed_file`
  treats any adopt target as `""` (no adopt or merge offered) and logs one
  detail line. `require_user_context` is not called from `logging_init`; the
  setup-user-\* scripts call it explicitly in B6, so `logging_init` keeps no
  side effect beyond logging. `Test-IsAdmin` (no caller, RevLib R12) is reused inside
  `Test-PrivilegedRun` or removed.
- **Verification:** `bash -n`; pwsh parser; `tests/profile/test-lib.sh` and
  `tests/managed-files/*` pass; new cases in `tests/profile/test-lib.sh` (or a
  new `tests/target-user/` if the delegate prefers; name it in the PR):
  `AITOOLS_TARGET_USER` override; non-root self; Linux root + `SUDO_USER`
  (container job, B12); package mode suppresses adopt in a PTY run
  (`tests/managed-files/pty-run.py` pattern).
- **Done:** API behaves identically in both languages where it applies; no
  return code 2.

### B5b -- library: logging fail-safe, HOME guard, `cursor-cloud`, settings sync

- **Files:** `scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`.
- **After:** B5a; P-2 for the `cursor-cloud` part (ship the rest without it if P-2 waits).
- **Behaviour:** log writes and `mkdir`/`New-Item` of the log dir never abort
  the caller (logging.md section 5; RevLib R9); an unset HOME gives a clear
  stderr message and exit 1 before line 72 runs (RevInstall R9); `cursor-cloud`
  in the environment block (resolution: explicit `AITOOLS_ENVIRONMENT` wins;
  `CLAUDE_CODE_REMOTE=true` → `claude-code-web`; else on Linux the socket
  `${CURSOR_AGENT_SOCKET:-/run/cursor/api.sock}` exists → `cursor-cloud`; else
  `local`; Linux only) plus `is_cursor_cloud` / `Test-CursorCloud`, and the
  hooks' copy of the environment block is updated per cross-platform.md
  "Hooks"; `sync_managed_json` / `Sync-ManagedJson` do not auto-adopt into
  `profile.json` in package mode (RevLib R8).
- **Verification:** `bash -n`; pwsh parser; `tests/logging/` suite; new cases:
  unwritable `AITOOLS_LOG_DIR` → script continues, one stderr line; environment
  matrix (`CLAUDE_CODE_REMOTE`, socket present via a temp
  `CURSOR_AGENT_SOCKET` path, override) on Linux CI and forced-`local` on
  macOS.
- **Done:** logging.md section 5 holds; `cursor-cloud` resolves only on Linux.

### B6 -- setup-user-\* fleet and root fixes

Each sub-batch: the delegate takes the defect list from `remediation.md` (same
batch ID) and RevSetup section 5, drafts verbatim edits against the current
files, and verifies with `bash -n`, the pwsh parser, and an isolated-HOME run
in a root `ubuntu:24.04` container (B12 harness) plus macOS. Every script calls
`require_user_context` / `Assert-UserContext` before its first write.

| Batch | Files | Fixes (source) | After |
|---|---|---|---|
| B6a | setup-user-claude.sh/.ps1 | `$SHELL` unbound under `set -u` (RevSetup R2, probe-confirmed); no-dotprofile neutral template / one WARN for unresolved tokens (BP-11) | FAN-PLAN B-D (owns the rules span), #103, #112, B5a |
| B6b | setup-user-cursor.sh/.ps1 | backup only on change (R16); manage `model` only when the profile sets it (R17); summary row when node missing (R11); dry-run mkdir (R19) | #109, #110, B5a |
| B6c | setup-user-shell.sh/.ps1 | compare before backup/write (R16); Linux `~/.profile` shadowing (R4); dry-run support (R18) | B5a |
| B6d | setup-user-hooks.sh/.ps1 (+ setup-user-settings.sh/.ps1 as B6d2) | `backup_file` before the settings.json write (R10); settings `n/a (no dotprofile)` in package mode (R9); tier filter after P-3 (R6) | B5a; P-3 |
| B6e | shared/hooks/session-archive.sh, session-catchup.sh | never run the cwd repo's `scripts/ait-harvest.py` (R5, critical for a fleet) | none; hook-rollout pre-deploy verification applies |
| B6f | setup-user-config.sh/.ps1 | package `repoPath` = payload `repo/`; `$HOME` vs `$env:USERPROFILE` (R20) | #98, #114, B5a |

Done for B6: a root container run and a macOS user run of the package user
phase show no ERROR row caused by these scripts; B6e must merge before any
fleet rollout (B12 exit gate).

### B7 -- tool scripts: privilege and scope

One batch per tool pair (2 files), each through `/tool-adopt` (and
`/tool-eval` where the method is new); M2 = the tool-adopt mission's batch
naming in the decisions file.

| Batch | Tool | Change (source RevTools 5) |
|---|---|---|
| B7a | gh-cli | `as_root`-style privilege helper instead of bare `sudo` (R4); apt update first (R13); winget `--scope user` (R2) |
| B7b | pandoc | same privilege helper (R4); move off the distro package (RevTools 3 gap 4) |
| B7c | uv | Linux method (R5) |
| B7d | go | Linux method (R5); `--exact` (R17); machine MSI → own Intune app decision |
| B7e | typst | Linux method (R5); `--exact` |
| B7f | rust | winget scope; MSVC Build Tools and NASM per System/User split (R14) |
| B7g | perl, bash (two pairs, two batches if needed) | Linux update or `system` kind (R15) |
| B7h | node (installer Step 8 is inline: lives in `aitools-install.*`, so after B3a) | Linux method; macOS keg-only fix (RevInstall R6) |
| B7i | pwsh on macOS/Linux | decide required or not (RevTools R9; suggested: optional) |
| B7j.. | datadog, modal, vercelcli, cursor-ide-mcp | registry/script alignment (R6, R7, R10, R11) |

- **After:** B5a (privilege helper lives in the lib: if the delegate needs a
  new `as_root` helper, it is added to the lib in its own lib batch, not inside
  a tool batch).
- **Verification per batch:** `bash -n`, pwsh parser, the tool script run under
  an isolated HOME on macOS and in the Ubuntu container; Windows run on the
  Windows VM when the change touches winget.

### B8a -- macOS backend: `build_pkg`, postinstall, LaunchAgent

- **Files:** `scripts/build-package.sh` (`build_pkg`),
  `packaging/macos/postinstall`, `packaging/macos/tech.nobul.aitools.firstrun.plist`.
- **After:** B2, B3a, B5a (C-1).
- **`build_pkg` behaviour:**
  1. Capability: `command -v pkgbuild` and `command -v productbuild`, else
     ERROR + ACTION "build the pkg on macOS", return 1.
  2. Root dir `R=$WORK/pkgroot`: copy the staged tree to
     `R/Library/Application Support/aitools/` (`ditto --norsrc --noextattr`
     when available: untested, PkgMac INCIDENT 1; else `cp -R`), set
     `BUILD-INFO` `kind=pkg` (perl in place), install
     `aitools-pkg-run.sh` into `bin/` (mode 755), the plist into
     `R/Library/LaunchAgents/` (mode 644), generate `aitools.app` (section 3.7)
     with `@VERSION@` replaced.
  3. Scripts dir `S`: `postinstall` (mode 755).
  4. Component plist: `pkgbuild --analyze --root "$R" "$WORK/component.plist"`,
     then set `BundleIsRelocatable` and `BundleIsVersionChecked` to false
     (`/usr/libexec/PlistBuddy` or `plutil -replace`; check rc).
  5. `pkgbuild --root "$R" --component-plist "$WORK/component.plist" --identifier tech.nobul.aitools --version "$VERSION" --install-location / --scripts "$S" --ownership recommended "$WORK/aitools-component.pkg"`
  6. `productbuild --package "$WORK/aitools-component.pkg" "$OUT/aitools-$VERSION.pkg"`
  7. Gates (each failure: ERROR row, return 1): `pkgutil --payload-files` has
     no line matching `/\._` (count must be 0); `pkgutil --expand` PackageInfo
     `identifier="tech.nobul.aitools"` and `version="$VERSION"`; stub
     `plutil -extract CFBundleShortVersionString raw` equals VERSION;
     `bash -n` on postinstall and runner; `pkgutil --check-signature` exits 1
     (unsigned expected; exit 0 is a WARN "unexpectedly signed").
- **postinstall behaviour (root, bash 3.2, short):**

```bash
#!/bin/bash
# postinstall -- package launcher (packaging/macos). Runs as root from installer.
# $3 is the target volume, never a user name (PkgMac INCIDENT 2).
set -euo pipefail
PREFIX="/Library/Application Support/aitools"
LIB="$PREFIX/repo/scripts/aitools-lib.sh"
if [ ! -f "$PREFIX/VERSION" ] || [ ! -f "$LIB" ]; then
    printf '%s\n' "aitools postinstall: payload incomplete under $PREFIX" >&2
    exit 1                     # broken payload: let the MDM retry
fi
export AITOOLS_LOG_DIR="/Library/Logs/aitools"
source "$LIB"
logging_init "aitools-pkg-postinstall"
VERSION=""
IFS= read -r VERSION < "$PREFIX/VERSION" || true   # || true: a file without a trailing newline returns 1; checked next line
[ -n "$VERSION" ] || { log_error "empty VERSION file"; write_summary ERROR "aitools pkg" "empty VERSION"; exit 1; }
rc=0
resolve_target_user || rc=$?   # || : capture the return code; checked by the case below
case "$rc" in
  0) log "starting user phase for $AITLIB_TARGET_USER ($VERSION)"
     # detached so the 600 s installer timeout cannot kill it (PkgMac 2)
     if ! run_as_target_user /bin/bash "$PREFIX/bin/aitools-pkg-run.sh" --detach; then
         log_warn "could not start the user phase; the LaunchAgent runs it at next login"
     fi ;;
  1) log "no console user: deferred to the LaunchAgent at next login" ;;
  *) log_error "console-user resolution failed (rc $rc)"; write_summary ERROR "aitools pkg" "user resolution failed" ;;
esac
printf '%s\n' "aitools $VERSION installed; user setup started or deferred (log: $AITOOLS_LOG_DIR/deploy.log)"
exit 0                         # deferred or started; only a broken payload exits non-zero
```

  `--detach` is the runner's own flag: it re-executes itself with `nohup`
  in the background, output to its log, and returns 0 at once (pinned in B8b).
  Whether the installer kills a detached child at its timeout: unknown (B12).
- **Verification:** `bash -n packaging/macos/postinstall`; `plutil -lint
  packaging/macos/tech.nobul.aitools.firstrun.plist`; `bash scripts/build-package.sh pkg --version 0.1.0`
  on macOS (isolated HOME) passes every gate except possibly the `._` gate on a
  local agent host (PkgMac INCIDENT 1: then the gate is expected to fail
  locally and must pass on the `macos-14` runner, B11a);
  `tests/build-package/test-stage.sh` gains pkg cases gated on
  `command -v pkgbuild`.
- **Done:** CI-built pkg passes all gates.

### B8b -- macOS runner and uninstall

- **Files:** `packaging/macos/aitools-pkg-run.sh`, `packaging/macos/aitools-uninstall.sh`.
- **After:** B8a.
- **Runner behaviour (console user, bash 3.2):** flags `--detach`, `--rerun`,
  `--help`; refuses to run as root (`is_privileged_run` → ERROR, exit 1);
  sources the payload lib with the standard `AITOOLS_LOG_DIR` (unset any
  inherited value); `logging_init "aitools-pkg-run"`; takes the run lock
  (section 3.2); compares `~/.aitools/pkg-version` with `$PREFIX/VERSION` and
  exits 0 when equal (unless `--rerun`); checks prerequisites (Command Line
  Tools via `xcode-select -p`, `brew` on PATH after `brew shellenv` from
  `/opt/homebrew/bin/brew`, `node`) and reports each missing one as ERROR +
  ACTION without stopping the run; runs
  `bash "$PREFIX/repo/scripts/aitools-install.sh" --phase user --package-mode < /dev/null`
  and, on exit 0, writes `~/.aitools/pkg-version` (section 3.2); exits with
  the installer's code (0/1).
- **Uninstall behaviour (root):** `launchctl bootout` the agent for each
  logged-in user (failure logged), remove the LaunchAgent plist and
  `$PREFIX`, `pkgutil --forget tech.nobul.aitools`; never touches home
  directories; logs to `/Library/Logs/aitools/deploy.log`. Run by an Intune
  shell script or Jamf policy (Intune has no Uninstall assignment for
  unmanaged PKG, PkgMac 3).
- **Verification:** `bash -n` both; runner under an isolated HOME on macOS
  against a staged tree with `PREFIX` overridden by `AITOOLS_PKG_PREFIX`
  (test-only variable, pinned here) → exit 0 and `pkg-version` written; second
  run exits 0 immediately; concurrent second invocation sees the lock.
- **Done:** B12 macOS rows pass.

### B9a -- Windows backend: `build_intune`, install-system, uninstall-system

- **Files:** `scripts/build-package.sh` (`build_intune`),
  `packaging/windows/install-system.ps1`, `packaging/windows/uninstall-system.ps1`.
- **After:** **B1 Phase 2 approval for IntuneWinAppUtil (hard stop)**, B2,
  B3a, B5a (C-1).
- **`build_intune` behaviour:** resolve the exe (`--intune-tool` or PATH,
  section 3.1), else ERROR + ACTION; App A content folder `$OUT/intune/system/`
  = `install-system.ps1`, `uninstall-system.ps1`, `payload/` (the staged tree,
  `kind=intune`); App B folder `$OUT/intune/user/` = `install-user.ps1`; run
  `"$EXE" -c "$(cygpath -w "$OUT/intune/system")" -s "$(cygpath -w "$OUT/intune/system/install-system.ps1")" -o "$(cygpath -w "$OUT/intune")" -q`
  (same for user), check rc and the output file, rename to
  `aitools-system-<v>.intunewin` / `aitools-user-<v>.intunewin`; copy
  `detect-user.ps1` with `@VERSION@` replaced to
  `$OUT/detect-user-<v>.ps1` (uploaded by the admin as App B's detection
  script); pwsh parser on all three `.ps1` (pwsh is on the Windows runner).
  `cygpath` availability is a capability check (Git Bash only).
- **install-system.ps1 behaviour (SYSTEM, pwsh 7):** `#Requires -Version 7`;
  log dir `C:\ProgramData\aitools\logs` (create; ACL default); source
  `payload\repo\scripts\aitools-lib.ps1` with `$env:AITOOLS_LOG_DIR` set;
  `Initialize-Logging "aitools-install-system"`; copy `payload\` to
  `%ProgramFiles%\aitools.new`, then swap (`aitools` → `aitools.old`,
  `aitools.new` → `aitools`, remove `.old`; each step in try/catch that logs
  and exits 1 after restoring); run
  `& "$env:ProgramFiles\aitools\repo\scripts\aitools-install.ps1" -Phase system -PackageMode`
  and record its exit; write `HKLM:\SOFTWARE\aitools` `Version` last, only when
  the copy succeeded; exit 0 / 1 (Intune maps return codes; 1618 stays the
  default Retry code). Never calls winget (BP-14).
- **uninstall-system.ps1:** remove `%ProgramFiles%\aitools` and the HKLM key;
  never touches user profiles.
- **Verification:** pwsh parser on both `.ps1`; on the Windows runner
  `bash scripts/build-package.sh intune --version 0.1.0` produces both files;
  B12 Windows rows.
- **Done:** both `.intunewin` files build on `windows-2022`.

### B9b -- Windows user app and detection

- **Files:** `packaging/windows/install-user.ps1`, `packaging/windows/detect-user.ps1`.
- **After:** B9a.
- **install-user.ps1 (user, pwsh 7):** refuse when `Test-PrivilegedRun` says
  SYSTEM (ERROR, exit 1); exit 0 at once when `pkg-version` equals
  `%ProgramFiles%\aitools\VERSION` (scaffold step 2); run
  `& "$env:ProgramFiles\aitools\repo\scripts\aitools-install.ps1" -Phase user -PackageMode`
  (resolve `ProgramFiles` with `[Environment]::GetFolderPath('ProgramFiles')`
  from the 64-bit pwsh, PkgWin 2 caveat); on exit 0 write `pkg-version`
  (section 3.2); exit with the installer's code. User-phase
  winget calls carry `--scope user --exact --source winget` (B7).
- **detect-user.ps1 (Windows PowerShell 5.1 compatible):** no lib; read
  `Join-Path $env:USERPROFILE '.aitools\pkg-version'` in try/catch; when the
  trimmed content equals `@VERSION@`, `Write-Output` it and exit 0;
  else exit 1 with nothing on STDERR (any STDERR = not installed, PkgWin 4).
  Because detection must stay silent on STDERR, its catch writes nothing and
  exits 1: this is a documented exemption from "no silent failures", listed in
  the script header and in `reference/script-standards-detail.md` exemptions
  (protected; drafted in B13).
- **Verification:** pwsh parser; `powershell.exe -NoProfile -File detect-user.ps1`
  on the Windows VM with and without the marker (exit 0 + stdout / exit 1 +
  no stderr).
- **Done:** B12 Windows rows pass, including the User-context detection test.

### B10a -- Linux backend: `build_deb`, control, postinst

- **Files:** `scripts/build-package.sh` (`build_deb`),
  `packaging/linux/control.in`, `packaging/linux/postinst`.
- **After:** B2, B3a.
- **`build_deb` behaviour:** capability `command -v dpkg-deb`, else ERROR +
  ACTION; root `R=$WORK/debroot`: staged tree → `R/opt/aitools/`
  (`kind=deb`), `aitools-setup` → `R/opt/aitools/bin/` (0755), symlink
  `R/usr/bin/aitools-setup -> /opt/aitools/bin/aitools-setup`;
  `R/DEBIAN/control` from `control.in` with `@VERSION@` replaced;
  `postinst`, `prerm` (B10b) → `R/DEBIAN/` (0755);
  `dpkg-deb --root-owner-group --build "$R" "$OUT/aitools_${VERSION}_all.deb"`;
  gates: `dpkg-deb --info` shows `Architecture: all` and the version;
  `dpkg-deb --contents` lists no `/usr/local` path (Debian Policy, PkgLinux 4).
- **control.in:**

```
Package: aitools
Version: @VERSION@
Architecture: all
Maintainer: nobul-tech <jose@nobul.tech>
Depends: bash, perl, python3, git, curl, ca-certificates
Recommends: jq, sudo
Section: admin
Priority: optional
Description: aitools harness (Claude Code / Cursor configuration and tools)
 Installs the aitools payload under /opt/aitools. Run aitools-setup as the
 target user (or as root in a container) to configure that user.
```

  (Maintainer value from PkgLinux 7; the commander may change it.)
- **postinst (root):** `set -e`; on `configure`: check `/opt/aitools/VERSION`
  and `/opt/aitools/repo/scripts/aitools-install.sh` exist (missing: message
  to stderr, exit 1); print one line "aitools <v> installed; run aitools-setup";
  no per-user writes, no network, no prompts, no `systemctl` (PkgLinux 4).
  Idempotent.
- **Verification:** `bash -n` postinst (or `sh -n`); on Ubuntu:
  `bash scripts/build-package.sh deb --version 0.1.0`; `dpkg-deb --info` /
  `--contents`; optional `lintian` (not required; not a managed tool).
- **Done:** `.deb` builds on `ubuntu-24.04` and installs on 22.04/24.04 (B12).

### B10b -- `aitools-setup` and prerm

- **Files:** `packaging/linux/aitools-setup`, `packaging/linux/prerm`.
- **After:** B10a, B5a (C-1).
- **aitools-setup behaviour:** flags per section 3.6; source
  `/opt/aitools/repo/scripts/aitools-lib.sh` (missing → stderr, exit 1);
  `resolve_target_user` (with `--user` → `AITOOLS_TARGET_USER`); when running
  as root and the target is not root → `run_as_target_user` re-runs
  `aitools-setup` as the target (flags forwarded) and exits with its code;
  when the target is root (Claude Code web) → `AITOOLS_LOG_DIR` stays
  `~/.aitools/logs` (root's home is the user's home there); lock; version
  comparison (skip unless `--rerun`); run
  `bash /opt/aitools/repo/scripts/aitools-install.sh --phase user --package-mode < /dev/null`;
  on exit 0 write `pkg-version` (section 3.2); exit with the installer's code.
- **prerm:** on `remove`/`purge`: nothing per-user; exit 0. (The symlink is
  package data, so dpkg removes it.)
- **Verification:** `bash -n` both; container runs (B12 rows 1-3) including
  `sudo aitools-setup` from the `ubuntu` user (target = `ubuntu` via
  `SUDO_USER`) and `aitools-setup --user ubuntu` from root.
- **Done:** B12 Linux rows pass twice in a row (second run: version skip).

### B10c -- cloud setup snippets

- **Files:** `packaging/linux/cloud/claude-code-web-setup.sh`,
  `packaging/linux/cloud/cursor-install.sh`.
- **After:** B10b; P-2 for the Cursor snippet.
- **Behaviour:** Claude Code web (root, must exit 0, under ~5 minutes,
  64 KB limit, PkgLinux 5): set `AITOOLS_ENVIRONMENT=claude-code-web`; download
  the pinned `.deb` (release asset URL; reachability unknown, R-9) or fall back
  to `git clone --depth 1 --branch v<v>` + `build-package.sh deb`; `apt-get
  update`; `apt-get install -y ./aitools_<v>_all.deb` (fallback `dpkg -i` +
  `apt-get install -f -y`); `aitools-setup --force`; every failure is logged to
  `/var/log/aitools/cloud-setup.log` and the script still exits 0 (the
  environment requires it), with each continue-on-failure preceded by a logged
  check (USO "no silent failures"; PkgLinux INCIDENT 3). Cursor: same with
  `sudo`, `AITOOLS_ENVIRONMENT=cursor-cloud`, idempotent per Build, and a
  non-zero exit allowed (Cursor does not document an exit-0 rule).
- **Verification:** `bash -n`; one real run per environment (B12 rows 5, 6).

### B11a -- CI workflow `package.yml`

- **Files:** `.github/workflows/package.yml` (new).
- **After:** B2, B8a, B9a, B10a; `actions/upload-artifact` evaluated (B1 item 6).
- **Behaviour:** triggers `workflow_dispatch` (input `version`) and later a
  release tag; jobs `pkg` (`macos-14`), `intune` (`windows-2022`, obtains
  IntuneWinAppUtil per the approved `/tool-eval` method with a pinned hash),
  `deb` (`ubuntu-24.04`); each runs `bash scripts/build-package.sh <kind>
  --ref "$GITHUB_SHA" --version "<input>" --out "$RUNNER_TEMP/out"` with
  `AITOOLS_LOG_DIR=$RUNNER_TEMP/logs` and an isolated `HOME`, then uploads the
  file plus `SHA256SUMS`; install-test jobs `deb-test` on `ubuntu-22.04` and
  `ubuntu-24.04` (install, `aitools-setup --force` twice, assert exit 0 and no
  `[error]` line in `~/.aitools/logs/deploy.log`), plus a root `ubuntu:24.04`
  container job. Also run `tests/build-package/test-stage.sh` on all
  three, and once with `/bin/bash` 3.2 on macOS.
- **Note:** artifacts of a public repo's workflow are visible to others
  (Lang 2); the payload is public content only (BP-1), so this is acceptable.
- **Verification:** YAML parse (`ruby -ryaml -e 'YAML.load_file(ARGV[0])'`,
  harvested `yaml-check.rb` pattern); one `workflow_dispatch` run on the PR
  branch.

### B11b -- check-pre-push step 11

- **Files:** `scripts/check-pre-push.sh`, `scripts/check-pre-push.ps1`.
- **After:** B2; P-1 (the `.ps1` calls `build-package.sh` through the Git Bash
  lookup: the cross-language exception row).
- **Behaviour:** step 11 "package staging": when `scripts/build-package.sh`,
  `packaging/**` or any include-list path changed, run
  `build-package.sh stage --out <temp>` under an isolated HOME and
  `AITOOLS_LOG_DIR`, `< /dev/null`; PASS on exit 0 and a MANIFEST that matches
  the tree; SKIP when nothing relevant changed; FAIL otherwise. Update the
  "1-10" skip label to "1-11" in both files (Lang 5). No native builds in
  pre-push.
- **Verification:** run both check scripts from the worktree; known
  pre-existing failures recorded (packet section 4).

### B12 -- test matrix runs

See section 5. Output: a results file in the mission folder,
`<mission name>-B12-results.md` (D-DEL1 prefix), one row per cell with
command, exit code, log excerpt and the unknown it settled.

### B13 -- pending doc drafts into PR-owned files

One small PR per owning PR, after it merges, applying the approved drafts
from `plans/build-package/doc-edits-pending.md` (DocsWriter): cross-platform.md
rows and the supported-list pointer (#99), deploy-paths.md/.mdc third path and
equivalence (#99), claude-shared.md (#105), decision tree, logging.md
system-phase sentence, glossary terms (#101/#106), interactive-menus.md if
package-mode behaviour needs a line (#106), the script-standards-detail.md
exemption for `detect-user.ps1` (#101). Each is protected: only commander-
approved text (sources-of-truth.md).

### B14 -- optional signing

Developer ID Installer signing + notarization for the pkg (build gate then
expects `pkgutil --check-signature` exit 0 and `spctl` acceptance);
Authenticode for the `.ps1` launchers; a signed apt repository. Needs
certificates and a decision; not planned in detail.

## 5. Test matrix (B12)

Every cell runs the package built by CI from one commit and version. Commands
are written as scratch scripts (`.scratch/session-<name>/`), never inline.

| # | Target | Setup | Commands (in a scratch script) | Pass criteria | Settles |
|---|---|---|---|---|---|
| 1 | Ubuntu 24.04 container, root | `docker run --rm -v "$OUT:/out" ubuntu:24.04` (on a host with docker; none on the build Mac, PkgLinux 3) | `apt-get update`; `apt-get install -y /out/aitools_<v>_all.deb`; `perl -MDigest::SHA -MMIME::Base64 -MFile::Path -e1`; `env -u SHELL aitools-setup --force`; run again | exit 0 twice; second run "already at <v>"; no `[error]` in `/root/.aitools/logs/deploy.log`; files under `/root/.aitools`, `/root/.claude` | perl modules; SHELL unset (B6a); root-for-root |
| 2 | Ubuntu 22.04 container, root | same with `ubuntu:22.04` | same | same | one-deb claim (BP-9) |
| 3 | Ubuntu 24.04 container, non-root `ubuntu` + NOPASSWD sudo | Dockerfile: `useradd -m ubuntu`, `/etc/sudoers.d/ubuntu` `ubuntu ALL=(ALL) NOPASSWD:ALL` | as `ubuntu`: `sudo apt-get install -y /out/...deb`; `aitools-setup --force`; also `sudo aitools-setup --force` (target via SUDO_USER) | files owned by `ubuntu` under `/home/ubuntu`; nothing written to `/root` | Cursor-cloud-like user; BP-10 target rule |
| 4 | Ubuntu 22.04 and 24.04 VMs | GitHub runners `ubuntu-22.04`, `ubuntu-24.04` (B11a `deb-test`) | install, `aitools-setup --force` twice | exit 0; no `[error]` | VM path; issue #19 acceptance |
| 5 | Claude Code web | environment setup script = `packaging/linux/cloud/claude-code-web-setup.sh` with the pinned version | start a session; in it: `cat /var/log/aitools/cloud-setup.log`, `dpkg-query -W -f='${Version}' aitools`, `ls /root/.claude` | session starts (setup exit 0); version matches; `AITOOLS_ENVIRONMENT` resolves `claude-code-web` | release-asset download from a non-attached repo (R-9); 5-minute budget |
| 6 | Cursor cloud | `.cursor/environment.json` `install` = `packaging/linux/cloud/cursor-install.sh` | in an agent: `id -un`, `test -S "${CURSOR_AGENT_SOCKET:-/run/cursor/api.sock}"`, `env`, `aitools-setup --force --rerun` | P-2 signal observed; default user recorded; exit 0 | Cursor signal and user (R-7) |
| 7 | macOS VM, Intune unmanaged PKG | disposable Apple Silicon macOS VM enrolled in a test Intune tenant (VM tool not evaluated; choose via `/tool-eval`) | upload pkg, Included apps `tech.nobul.aitools` X.Y.Z; assign Required; with a user logged in, and once at the login window then log in | Intune reports success; `~/.aitools/pkg-version` = X.Y.Z; `/Library/Logs/aitools/deploy.log` present; no `._*` files on disk (`find "/Library/Application Support/aitools" -name '._*'`) | Gatekeeper on agent install (R-1); `._*` (R-2); detection outside /Applications (R-3); login-window user (R-5) |
| 8 | macOS VM, Jamf Pro | test Jamf tenant; package + policy Once per computer; EA on VERSION | `sudo jamf policy -id <n>`; check policy log; EA value; force a postinstall failure once (corrupt VERSION) | policy Completed; EA = X.Y.Z; broken payload marks Failed (records the unknown either way) | non-zero postinstall effect (R-4); `$3` handling |
| 9 | macOS, update | rows 7/8 with X.Y.Z+1 | upload new version | reinstall within the documented window; runner reruns once | BP-12 |
| 10 | Windows 11 VM, Intune Win32 | test Intune tenant; dependency apps pwsh 7.6 MSI, Git, Node; App A, App B (depends on A) | assign App B Required to a test user; sign in | App A detection (HKLM) and App B detection (script) succeed; `%USERPROFILE%\.aitools\pkg-version` = X.Y.Z; no winget call logged under SYSTEM; IME `AppWorkload.log` captured | User-context detection identity (R-6); winget scope (R-8); 32-bit host + pwsh path |
| 11 | Windows, update | supersede/in-place swap with X.Y.Z+1 | | reinstall once; backups not rotated by no-op runs | BP-12, BP-13 |
| 12 | Dev-path regression | Jose's normal machine flow is NOT used; a fresh isolated HOME clone run of `aitools install --dry-run` on macOS and Windows | same rows as before B3a (diff of summary rows) | no change except the order-file source | BP-2 equivalence |

Exit gate before any fleet rollout: rows 1-4, 7, 10 pass; B6e merged; P-3
answered (or the commander accepts the full harness set for the fleet).

## 6. Merge order against open PRs

Open PRs read 2026-10-26 (`gh pr list -R nobul-tech/aitools --state open --json number,files`).

| PR | Touches (relevant files) | Blocks |
|---|---|---|
| #99 | cross-platform.md, deploy-paths.md/.mdc, reference/managed-file-deployment.md | B13 (rows, third path) |
| #100 | deploy-harness.sh/.ps1, tests/deploy-harness | B4 |
| #101 | logging.md, script-standards-detail.md, decision tree, glossary.json, user-repo.md | B13 |
| #103 | aitools-lib.*, setup-user-claude.*, check.yml | B5a, B6a |
| #105 | shared/claude-shared.md, aitools-profile.* | B13; B6a template work |
| #106 | aitools-install.*, scripts/aitools*, interactive-menus.md, decision tree | B3a, B3b, B13 |
| #110 | deploy-harness.*, setup-user-cursor.* (on #100) | B4, B6b |
| #111 | build-deploy.sh, deploy-harness.*, tests/deploy-harness* | B4 |
| #112 | aitools-lib.*, setup-user-claude.*, build-deploy.sh, check.yml (on #103) | B5a, B6a |
| #113 | aitools-lib.*, scripts/aitools*, setup-user-claude/config.*, check.yml | B3b, B5a |
| #115 | aitools-lib.*, scripts/aitools*, setup-user-claude/config.*, check.yml | B3b, B5a |
| #116 | aitools-install.*, aitools-lib.*, scripts/aitools*, setup-user-*, check.yml | B3a, B3b, B5a |
| #98, #114 | setup-user-config.* | B6f |
| #108 | aitools-profile.*, aitools-json.* | B5a only if the fleet resolver outcome (RevLib R7) is done there |
| #109 | setup-user-cursor.*, check-lib.*, setup-user-skills.ps1 | B6b, B11b (check-lib) |

Recommended sequence (consistent with FAN-PLAN section 5, "#103 -> #112 ->
(#113/#115/#116) -> Batch A -> #100 -> #106 -> Batch B+C+D"):

1. Now, independent of every PR: B1 (approvals), B2 (new files only), B10a
   and B8a's `build_*` functions may be drafted but merge after B3a.
2. #103 → #112 → #98, #114, #108 → #113 → #115 → #116.
3. FAN-PLAN Batch A (lib).
4. #100 → #110 → #111 → #106 → FAN-PLAN Batches B+C+D.
5. B3a → B3b → B4 → B5a → B5b.
6. B6a..B6f (B6e any time), B7 batches.
7. B8a → B8b; B9a (after Phase 2) → B9b; B10a → B10b → B10c.
8. B11a, B11b → B12 → B14.
9. B13 after each owning PR (#99, #101, #105, #106) merges, in any order.

If a PR is closed instead of merged, the dependent batch rebases on main and
re-reads the affected code; the plan's behaviour stays.

## 7. Risks

| # | Risk | Likelihood / impact | Mitigation | Settled by |
|---|---|---|---|---|
| R-1 | Gatekeeper blocks an unsigned pkg installed by the Intune agent or the jamf binary | unknown / high (macOS channel fails) | agents download without quarantine (inference, PkgMac 5); B14 signing as fallback | B12 rows 7, 8 |
| R-2 | AppleDouble `._*` entries from `com.apple.provenance` xattrs land as stray files | known on the agent Mac / medium | build on the CI runner; `ditto --norsrc --noextattr` (untested); hard gate `pkgutil --payload-files` count 0 | B8a gate, B12 row 7 |
| R-3 | Intune macOS does not detect a stub app outside `/Applications` | unknown / high (Intune reports failure forever) | fallback: install the stub at `/Applications/aitools.app` (visible to users; commander choice) | B12 row 7 |
| R-4 | A non-zero pkg postinstall does not fail the install in Intune ("Irrespective of the post-install script run status ... success" covers only Intune's own field) or Jamf | unknown / medium | postinstall exits non-zero only for a broken payload; per-user status via `pkg-version` EA / custom attribute | B12 row 8 |
| R-5 | Console user at the login window or during Setup Assistant reported unexpectedly | unknown / medium | treat empty/root/loginwindow/_mbsetupuser as none → LaunchAgent | B12 row 7 |
| R-6 | Intune detection script for a User-context app does not run as the user (not documented) | unknown / high (App B never detected → reinstall loop) | test on a device; fallback: App B writes an HKLM-readable marker under `C:\ProgramData\aitools\users\<sid>.version` (needs an ACL set by App A) | B12 row 10 |
| R-7 | Cursor cloud has no documented env signal; default user unknown (root vs `ubuntu`) | high / medium | explicit `AITOOLS_ENVIRONMENT=cursor-cloud` in the install command; socket as secondary (preview API); `aitools-setup` supports both users | B12 row 6, P-2 |
| R-8 | winget packages lack a user-scope installer (Go MSI, Strawberry Perl) | likely for some / medium | per-tool `/tool-eval` with `winget show`; machine tools become own Intune apps; user phase ERROR + ACTION, never a silent wrong-profile install | B7, B12 row 10 |
| R-9 | Claude Code web cannot download a GitHub release asset of a repo not attached to the session ("same 403" for archive URLs of non-attached repos) | unknown / high for that environment | fallback: clone + local `build-package.sh deb`; or the user's repo commits a pinned `.deb` | B12 row 5 |
| R-10 | pkg postinstall's detached child is killed at the 600 s installer timeout | unknown / medium | LaunchAgent also runs at next login (self-healing); alternative `launchctl kickstart` of the agent in the user's GUI domain | B12 row 7 |
| R-11 | PowerShell 7.6 LTS end of support (no MSI from 7.7) | certain later / medium | plan a ZIP-based dependency app before 7.6 ends (date unknown) | B1 follow-up |
| R-12 | IntuneWinAppUtil licence forbids redistribution, or Phase 2 is rejected | unknown / high for the Windows kind | CI downloads it at build time (no redistribution); if rejected, the Windows kind waits (B9 blocked) | B1 Phase 2 |
| R-13 | Fleet users receive Jose's harness hooks, skills, MCP servers and aitools project rules (FAN-PLAN D5 fans `.claude/rules` into user scope) | certain until P-3 / medium | P-3 tiers; B6d filter; neutral template | P-3, B6d |
| R-14 | The cwd-repo `ait-harvest.py` execution in two hooks runs untrusted code for fleet users | certain today / critical for fleet | B6e before rollout | B6e |
| R-15 | Lib batches conflict with five open PRs and FAN-PLAN Batch A | high / medium | B5a waits for all of them (section 6); delegates draft edits against current main | merge order |
| R-16 | Intel Macs without Homebrew fail the user phase | certain / low (P-5 declares unsupported) | runner logs ERROR + ACTION on Intel without brew | P-5 |
| R-17 | HOME / SHELL values under Jamf, Intune and `sudo -H` differ from assumptions | unknown / medium | `sudo -u -H` sets HOME; B6a removes the SHELL crash; B12 logs `env` once per channel | B12 rows 7, 8, 10 |

## 8. Lifecycle: IntuneWinAppUtil (tool-lifecycle.md)

- IntuneWinAppUtil.exe is a third-party (Microsoft) download, so it is an
  install decision under the user CLAUDE.md gate and tool-lifecycle.md (Lang 4).
- Steps, in order, **before B9a**:
  1. `/tool-eval` Phase 1 with chrome-devtools on the official pages
     (PkgWin 1 already gathered: v1.8.7, 2025-08-13, `microsoft` org, .NET
     Framework 4.7.2, proprietary licence, binary committed in the repo, no
     release in the last 12 months: yellow).
  2. Evaluation record `reference/evaluations/intunewinapputil-windows-<date>.md`
     (tool-evaluation.md "Gates").
  3. Under Evaluation registry entry via `/tool-registry` (Windows
     `evaluating`, macOS/Linux `n/a`): protected, commander review.
  4. **Phase 2 gate, hard stop**: install on a Windows build host, give the
     commander a test command (for example `IntuneWinAppUtil.exe -c <folder
     with one .ps1> -s <that .ps1> -o <out> -q`), wait for explicit approval.
     Not batched with Phase 3+ work. No code that calls IntuneWinAppUtil is
     written before approval (B9a waits).
  5. After approval: the CI acquisition step (pinned commit and our recorded
     SHA-256), per the "build-host tool" class (P-4): no setup script, no
     installer step, no build-deploy copy block, no Managed CLI Tools row.
- pkgbuild, productbuild, dpkg-deb: OS-provided, checked by capability, no
  install; registry entries only if P-4 says build-host tools get them.
- nfpm, fpm, bomutils: not adopted (PkgLinux 3, PkgMac 1, Lang 4).

## 9. Done for the package path (v1)

- `build-package.sh all` on the three CI runners produces the four package
  files with `SHA256SUMS`, all gates green.
- B12 rows 1-12 recorded; the exit gate in section 5 passed.
- Dev path rows unchanged (row 12); MDM path untouched (no diff in
  `build-deploy.sh` from this plan).
- B13 drafts applied after their PRs; `RELEASE_NOTES.md` entry
  (documentation-standards.md format) for the release that ships v1.

## 10. Open questions (P-1..P-7), with suggested answers

| ID | Question | Suggested answer | Blocks |
|---|---|---|---|
| P-1 | Approve the two cross-platform.md rows: `build-package.sh` as a bash-only build script (OS-guard exemption + cross-language row for check-pre-push.ps1 step 11), and a "package launchers" exemption category (`packaging/**`: OS-native, run by MDM/dpkg, no `.sh`/`.ps1` pairing; includes `detect-user.ps1` under Windows PowerShell 5.1)? | Approve. The launchers cannot be paired by nature (a pkg postinstall has no Windows twin) | B11b, B13; B9b (5.1 exemption) |
| P-2 | Environment value `cursor-cloud`: explicit `AITOOLS_ENVIRONMENT=cursor-cloud` from the install command, secondary signal = the metadata socket exists, Linux only? | Approve; verify on one Cursor cloud run (B12 row 6) before B5b's part ships | B5b part, B10c |
| P-3 | Fleet content tiers (`tier: fleet \| harness` on hooks, skills, MCP servers) and a neutral fleet template? | Approve; standing-order-guard and the failure-mode hooks stay `harness`; also decide whether aitools project rules (`.claude/rules`) reach fleet users through the fan-out (FAN-PLAN D5) | B6d, fleet rollout |
| P-4 | IntuneWinAppUtil as a build-host tool (registry entry, `/tool-eval`, Phase 2) and a new "build-host tool" lifecycle class? | Approve both | B9a, B11a |
| P-5 | Intel Macs unsupported on the package path in v1 (dev path unchanged)? | Approve | B8b prerequisite check |
| P-6 | Dotprofile for fleet users: interactive `aitools user init` once, or a run-time fetch? | Interactive once in v1 | B6a |
| P-7 | Jose's personal "I work on both Windows 11 and macOS" line in the dotprofile template? | Update to the five-item form (DocsInv 5) | B13 (dotprofile) |

Other items raised while planning (not in P-1..P-7), each with a suggestion:

- Should App A set `LongPathsEnabled` in HKLM (today only checked, with an
  ACTION, `aitools-install.ps1:224-239`)? Suggested: report only in v1;
  setting a machine policy needs a commander decision.
- Stub app location if R-3 fails: `/Applications/aitools.app`? Suggested:
  yes, only if B12 row 7 shows detection fails elsewhere.
- Maintainer field of the `.deb` (`nobul-tech <jose@nobul.tech>`, from
  PkgLinux 7)? Suggested: keep unless the commander wants a team address.

## 11. Contract changes

- **C-1 (dependency):** B8a, B9a and B10b also depend on B5a (the decisions
  file lists B8 after B2, B3 and B9 after B1, B2, B3; B10 after B2, B3). Reason:
  the launchers call `resolve_target_user` / `is_privileged_run` /
  `run_as_target_user` (BP-10 says only launchers switch user, and the API
  lives in the lib). Alternative: inline resolution in each launcher, rejected
  as a third copy of the same logic.
- **C-2 (log file name):** BP-7 names the macOS system log
  `/Library/Logs/aitools/install.log`, and the scaffold headers name
  `install.log` (`packaging/macos/postinstall`) and `system-install.log`
  (`packaging/windows/install-system.ps1`). Launchers source the payload
  library (script-standards.md: "Do not define inline copies" of logging
  helpers), and `logging_init` always writes `deploy.log` in `AITOOLS_LOG_DIR`,
  so the file is `<system log dir>/deploy.log`. The named files become
  possible only if the lib gains a log-file-name option (Lang 3 option (ii)).
  Decision for B8a/B9a: use `deploy.log` and update the launcher headers,
  unless the commander wants the lib option (suggested: `deploy.log` in v1).
- **C-3 (batch split):** B3, B5, B6, B7, B8, B9, B10, B11 are split with
  letter suffixes to stay at 2-3 files (decisions file section 2 allows it).
  B6e (hooks security) and B6f (setup-user-config) are new sub-batches carved
  out of B6's scope.
- **C-4 (added names, beyond the ScaffoldWriter contract):**
  `scripts/aitools-order.txt` (BP-6 "proposed name", now pinned),
  `packaging/macos/aitools-uninstall.sh`, `packaging/windows/uninstall-system.ps1`,
  `packaging/linux/prerm`, `packaging/linux/cloud/claude-code-web-setup.sh`,
  `packaging/linux/cloud/cursor-install.sh`, `tests/build-package/test-stage.sh`
  (B2; B0 shipped `tests/build-package/test-cli.sh`, which stays), runner
  flags `--detach` and `--rerun`, `aitools-setup --rerun`, test-only
  `AITOOLS_PKG_PREFIX`, the `--out` marker `.build-package-out`,
  `~/.aitools/pkg-run.lock`, env `AITOOLS_PACKAGE_MODE`.
- **C-5 (aligned to the scaffold files, read 2026-10-26):** the launch prompt's
  contract named no `--intune-tool`; the scaffold adds it and this plan uses
  it. `--version` is required for every command except `stage` (scaffold),
  not defaulted from a tag. The staged tree is `<out>/stage/` (scaffold), not
  `<out>/stage/aitools-<v>/`. The template token is `@VERSION@` (scaffold
  `control.in`). Summary rows use the tool name `build-package` with a
  `<kind>:` detail (scaffold). `pkg-version` is written by the launchers
  (scaffold headers), not by the installer (an earlier draft of this plan).
  The scaffold's dry-run plan line "hygiene: ... (COPYFILE_DISABLE=1)" relies
  on a setting PkgMac found ineffective (PkgMac 1, INCIDENT 1): B8a replaces it
  with the `._*` payload gate.
