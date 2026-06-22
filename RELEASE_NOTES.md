# aitools Release Notes

## Versioning

`major.minor.patch` -- not semver (no API contract), but follows the same spirit:

- **Major** (v0 → v1): structural changes to CLI commands, architecture, or project layout
- **Minor** (v0.14): new features, new managed tools, batches of improvements
- **Patch** (v0.14.1): isolated bug fixes with no new functionality

Multiple changes on the same day roll into one release. Bug fixes ship alongside features in the same minor if they land together.

---

## v0.73.0 -- settings.json ↔ profile.json sync; deny-rule deprecation (2026-06-22)

Fixes the reported "`aitools install` overwrites `~/.claude/settings.json`". Two root causes: `setup-user-mcp` force-added obsolete `permissions.deny` rules on every run regardless of `profile.json`/`settings.json`, and both deployers re-serialized via `sortKeys` (alphabetizing while Claude Code writes insertion order), so any managed-field change rewrote the whole file. `profile.json` (`claude.settings`) is now the source of truth for `settings.json` (except the manifest-owned `hooks`), reconciled by a generic, granular sync engine.

### New features

| # | Change |
|---|--------|
| 1 | **Settings sync engine** -- `sync_managed_json` / `prompt_json_field_review` in `aitools-lib.{sh,ps1}` (identical embedded node logic). Per managed leaf (arbitrary keys; `permissions` per-rule across allow/ask/deny): live-only → auto-adopt into `profile.json` (no prompt); equal → no-op; differ/live-missing → granular per-leaf menu `[o]verwrite / [a]dopt / [s]kip / [x]abort` (abort global). No-op runs do zero writes/backups. |
| 2 | **`setup-user-settings.{sh,ps1}`** -- new script pair orchestrating the sync; resolves `profile.json` via `config.json` `userRepoPath` (works in dev and MDM). Migrates legacy flat `claude.{autoMemory,alwaysThinking,effortLevel}` into `claude.settings`. Wired into `aitools-install` Step 21 + entry-point dispatch (both platforms). |

### Improvements

| # | Change |
|---|--------|
| 3 | **Deny-rule deprecation** -- `setup-user-mcp.{sh,ps1}` no longer write `settings.json` (MCP registration only). Obsolete rules `MCP(vercel)` / `MCP(webflow)` / `Agent(claude-code-guide)` are purged by the sync engine before adopt; `tool-ops.json` drops `cc-deny-guide-subagent` (the working `block-claude-code-guide.sh` hook is kept -- CC honors the hook where it does not honor deny for built-in subagents). vercel/webflow MCP are now enabled by default. |
| 4 | **`setup-user-hooks.{sh,ps1}` slimmed to hooks-only** -- preference handling moved to the sync engine; `sortKeys` write churn dropped (key order preserved; sort retained only for the order-independent unchanged comparison). |

### Bug fixes

| # | Severity | Change |
|---|----------|--------|
| 5 | Medium | **`build-deploy.sh` heredoc bug** (pre-existing, shipped in v0.72.0): hook source files lacking a trailing newline glued the embedding delimiter onto the last content line, producing an unterminated heredoc and an unparseable `deploy/setup-user-hooks.sh`. Fixed defensively on both platforms (newline guarded before the delimiter / here-string terminator). |
| 6 | Low | `sync_managed_json` `decision_count` used `grep -c \. \|\| echo 0`, which doubled to `"0\n0"` on an empty decisions file (`[: integer expected`). Changed to `\|\| true` with an empty-guard. |

### Documentation

| # | Change |
|---|--------|
| 7 | 11 protected docs/registries truthed up: `claude-shared.md` + dotprofile `CLAUDE.md` (MCP no longer disabled by default; prefs synced by `setup-user-settings`), `managed-file-deployment.md` + `.mdc`, `interactive-menus.md` (JSON field-level review now implemented + per-leaf semantics), `config-file-safety.md`, `deploy-paths.md` (duplication table: mcp/hooks now pure-extract), `reference/user-repo.md` (`claude.settings` schema + sync model), `aitool-ops` + `tool-ops` skills and tests. |

### Files created

| File | Purpose |
|------|---------|
| `scripts/setup-user-settings.sh` / `.ps1` | Orchestrate settings.json ↔ profile.json sync |

**Verified on:** macOS + PowerShell (pwsh installed). 15 bash + 9 pwsh + 6 apply-branch + 17 end-to-end assertions, all green; `build-deploy.sh` and every generated deploy script parse on both platforms; first-run adopt (legacy migration + settings capture) and no-op idempotence (zero backups) verified live against the real profile.

---

## v0.72.0 -- Unified logging to ~/.aitools/logs with rotation (issue #7) (2026-06-20)

Completes the logging migration ([#7](https://github.com/nobul-tech/aitools/issues/7)): all aitools logging moves to a single cross-platform directory `~/.aitools/logs/` with size-based rotation, dissolving the prior 3-way native split (macOS `~/Library/Logs`, Linux `~/.local/state`, Windows `%LOCALAPPDATA%`) and the latent bash↔PS1 Windows divergence it caused.

### New features

| # | Change |
|---|--------|
| 1 | **Log rotation** -- size-based, 5 MB × 5 backups, net-new in `logging_init` (bash) / `Initialize-Logging` (PS1) via a fail-safe `_rotate_log`/`Rotate-Log` helper (`stat`+`uname` dispatch / `.Length`+`Move-Item`). Also wired into `check_log_init`/`CheckLogInit` (`checks.log`/`.jsonl`). The Python loggers (`ait-harvest.py`, `harness-db.py`) already rotated. |

### Improvements

| # | Change |
|---|--------|
| 2 | **Unified log location** -- `aitools-lib.{sh,ps1}`, the `aitools`/`aitools.ps1` bootstrap loggers, `check-lib.ps1`, and the clip2md aliases now resolve to `~/.aitools/logs` (forward slashes in bash, `Join-Path` in PS1), honoring an `AITOOLS_LOG_DIR` override for tests. Propagated to all 38 deploy scripts. |
| 3 | **Doc consolidation** -- `reference/logging.md` is the single source of truth; fixed the stale 3-way table + bridge prose in `script-standards-detail.md`, the old truncate paths in `pre-update.md`, added a pointer in `script-standards.md`, and documented the harvest/archive system (catch-up, subagent transcripts, `ait-harvest.py` helper, `logs/`) across `user-repo.md`, `tool-ops-claude-code.md`, `artifact-harvesting.md`, `aitools-workspace.md`. |

### Bug fixes

| # | Severity | Change |
|---|----------|--------|
| 4 | Low | Stale "deletes ephemeral files" claim in `artifact-harvesting.md` corrected (auto-deletion was removed in v0.64.1). |

**Verified on:** macOS + PowerShell (pwsh installed this session) -- bash and PS1 both resolve to `~/.aitools/logs/deploy.log`; rotation tested live on both (6 MB log → `.1`; second → `.1`+`.2`; small file → no rotate); `AITOOLS_LOG_DIR` override works; `deploy.log`/`checks.log` now land in `~/.aitools/logs` with no new writes to the old dirs; acceptance scan shows zero leftover log-path literals (only legit NASM/Git/Python install paths remain); all `.ps1` parse-clean; `check-post-push -Extensive` **0 FAIL**; all 38 deploy scripts carry the new path.

---

## v0.71.0 -- Hook registration generated from the manifest + Explore agent block (2026-06-20)

Closes the recurring hook-registration drift class (7 incidents across v0.60-v0.70, one silent for ~3 months) by making `shared/hooks/hooks-manifest.json` the **generator** of hook deployment + registration, not merely an audit source. Adding a hook is now one manifest entry -- no parallel hand-maintained lists in `setup-user-hooks.{sh,ps1}` + `build-deploy.sh`. Full RCA via `/investigate` (report harvested this session).

### New features

| # | Change |
|---|--------|
| 1 | **Manifest-as-generator** (issue [#7](https://github.com/nobul-tech/aitools/issues/7) / plan §5) -- `setup-user-hooks.{sh,ps1}` and `build-deploy.sh` (§15-16) now GENERATE hook deployment + `settings.json` registration by looping over `hooks-manifest.json`. The dev path reads the manifest at runtime; the self-contained MDM deploy path embeds the registration list (`REGS_JSON` / `$regs`) at build time, so the node merge block is identical dev and deploy. Replaces ~10 hardcoded touchpoints per hook (resolve / dest / cmd / positional `argv` / `mergeHookEntry` / validation) across two languages. |
| 2 | **`block-explore-agent.sh`** (PreToolUse on Agent) -- blocks the built-in Explore subagent by operator policy, redirecting research/search delegation to `general-purpose`. Mirrors `block-claude-code-guide.sh`; blocklist-driven (extend `BLOCKED_TYPES`). |

### Bug fixes

| # | Severity | Change |
|---|----------|--------|
| 3 | High | **MDM hook preferences emitted invalid JS** -- the deploy (MDM) `setup-user-hooks` node merge block produced `const effortLevel = high;` (unquoted -> ReferenceError) whenever `effortLevel` was set: the embedded `"high"` double-quotes collapsed inside the bash-double-quoted `node -e "..."`. Pre-existing; never caught because the generated deploy script was never run. Fixed (single-quoted JS literal). It broke the `settings.json` merge on any MDM machine with `effortLevel` set. |

### Improvements

| # | Change |
|---|--------|
| 4 | **`check-hook-parity.py`** (post-push step 32) rewritten -- the old audit extracted hardcoded `mergeHookEntry` calls (now gone). It now verifies the new invariant: both scripts are manifest-driven and no hardcoded per-hook registration list has resurfaced. |
| 5 | **PowerShell installed** (`brew install powershell/tap/powershell`) -- closes the standing pwsh-absent gap (registry-listed, no install step). `.ps1` syntax validation now runs in `build-deploy` + `check-post-push` step 6 (both PASS); previously-deferred `.ps1` parse-checks are green. |

### Files created

| File | Purpose |
|------|---------|
| `shared/hooks/block-explore-agent.sh` | PreToolUse[Agent] hook blocking the Explore subagent |

**Verified on:** macOS -- all `.sh` `bash -n` clean; setup-user-hooks dev path strip-and-regenerate proven (18 hooks register from the manifest alone, idempotent); generated deploy `.sh` dry-run + live verified self-contained; all `.ps1` parse-clean via pwsh; PowerShell `MergeHookEntry` + `$regs` loop proven (18 register once, idempotent, block-explore matcher=Agent); `check-post-push -Extensive` **0 FAIL** (27 PASS / 3 SKIP / 4 WARN). The full `.ps1` run is OS-guarded to Windows; the first Windows `aitools install` should confirm end-to-end.

---

## v0.70.0 -- Harness-owned shell integration + deterministic tool resolution (2026-06-20)

Workstream A of the managed-tool resolution design (`plans/tooling-resolution-and-artifact-registry.md`): the harness now owns PATH precedence in the login profile and resolves managed Python deterministically, so the uv python shim / cursor-agent / brew bash win in the harness's contexts instead of being shadowed.

### New features

| # | Change |
|---|--------|
| 1 | **Login-profile PATH ownership** — `scripts/setup-user-shell.{sh,ps1}` (new): idempotently owns a marked block (`# >>> aitools managed >>>` … `# <<< aitools managed <<<`) in the login profile (`~/.bash_profile`; PowerShell `$PROFILE`). Placed last, it re-asserts precedence (`brew shellenv` → prepend `~/.local/bin`), yielding the canonical order `~/.local/bin → /opt/homebrew/bin → grok/antigravity → system` without rewriting the user's own lines. Wired into `aitools-install` Step 7 and embedded in `build-deploy`. |
| 2 | **Deterministic Python resolver** — `harness_python` (`aitools-lib.sh`) / `Get-HarnessPython` (`aitools-lib.ps1`): prefer the uv shim (`~/.local/bin/python3`) over a bare PATH lookup, for non-interactive contexts (cron/launchd) where login PATH order does not apply. `aitools-dashboard` `find_python`/`Find-Python` delegate to it. |
| 3 | **Cursor `agent` shim management** — `setup-user-cursor.{sh,ps1}`: harness owns the `agent → cursor-agent` symlink (POSIX) and warns when `agent` resolves to grok instead of Cursor (PATH-order regression). |

### Improvements

| # | Change |
|---|--------|
| 4 | Live `~/.bash_profile` on nobul-mac: managed block applied (decision-#6 order verified — uv python 3.14.6, brew bash 5.3.15, cursor-agent all resolving correctly); stray zsh-only lines (`autoload`/`compinit` from the grok installer) that errored on every bash login removed. |

### Files created

| File | Purpose |
|------|---------|
| `scripts/setup-user-shell.sh` / `.ps1` | Idempotent owner of the login-profile managed PATH block |
| `reference/ait-shellintegration.md` | How aitools owns shell integration + PATH precedence; marker convention; canonical order; resolver |

### Deferred (Workstream A remainder)

| Item | Reason |
|------|--------|
| Install-step reorder (decision #9) | High blast radius, untestable locally (`.ps1`), no current functional value — tracked follow-up |
| Hook python-resolution inlining | 10 standalone deployed hooks cannot source the lib; each needs an inline shim + test |

**Verified on:** macOS — all edited `.sh` `bash -n` clean; `setup-user-shell.sh` tested against profile copies (idempotent, single marker pair) then applied live and re-verified in a fresh login shell; `harness_python` smoke-tested → uv shim, Python 3.14.6. PowerShell files are mechanical parity mirrors, marked `UNTESTED on Windows` (no pwsh on this Mac).

---

## v0.69.1 -- Python resolution correctness + managed-tool/artifact-registry design capture (2026-06-20)

### Bug fixes

| # | Severity | Change |
|---|----------|--------|
| 1 | Medium | **Python shadow mis-diagnosis** — `setup-python.{sh,ps1}` and the `tool-registry.json` `python` entry told users to put `~/.local/bin` before `/usr/bin`, but the uv shim is shadowed by the Homebrew bin (`/opt/homebrew/bin/python3`), and `~/.local/bin` already precedes `/usr/bin`. Detection now names the *actual* shadowing dir (parent of the resolved binary); the registry `postInstallConfig` is corrected and `knownPaths` populated with the uv shim paths. Interactively `python3` already resolves to the uv shim; the shadow bites the harness's non-interactive contexts — durable fix tracked in the plan below. |

### Documentation

| # | Change |
|---|--------|
| 2 | **`plans/tooling-resolution-and-artifact-registry.md`** — confirmed design for harness-owned PATH/shell-integration, a tool-ops model 1:1 with tool-registry (baseline resolution + verification, optional rich sections, `enforcement` flag only on blocking rules), consumer-declared tool dependencies, and a generated artifact registry. Captures 10 decisions + Workstreams A/B/C + sequencing + open-thread backlog. |
| 3 | **ROADMAP** — "In Progress" row for the above. |
| 4 | **Framework registry** — `pending` adoption entry: Artifact registry (ITIL CMDB + SBOM). |

### Files created

| File | Purpose |
|------|---------|
| `plans/tooling-resolution-and-artifact-registry.md` | Design of record for managed-tool resolution + artifact registry |

**Verified on:** macOS — `setup-python.sh` `bash -n` clean; `tool-registry.json` and `framework-registry.json` parse clean. `setup-python.ps1` is a mechanical parity edit, not parse-checked (no pwsh on this Mac; see plan backlog). The durable resolution fix (Workstreams A–C) is not yet implemented.

---

## v0.69.0 -- Remote bootstrap one-liner + uv-unified Python + per-user deploy + registry consolidation (2026-06-15)

### New features

| # | Change |
|---|--------|
| 1 | **Remote bootstrap one-liner** (fa07e52, 7cc8cb5) — `scripts/bootstrap.{sh,ps1}`: `curl\|bash` (macOS/Linux) / `irm\|iex` (Windows) installs prerequisites (package manager + git), clones nobul-tech/aitools, runs the installer, then (interactive) pulls the dotprofile and rebuilds from it. README documents both one-liners. |
| 2 | **uv as the unified Python manager** (2e702a9 macOS, 3c4bba4 Windows) — `setup-python.{sh,ps1}` run `uv python install <ver> --default` so `python`/`python3` resolve to the uv-managed interpreter (`~/.local/bin` shims); per-repo override via uv `.python-version` / `uv venv`. Replaces brew-python (macOS) and pymanager (Windows). Installer reordered: uv (Step 14) before Python (Step 15). |
| 3 | **Per-user MDM deploy** (2c0fd32) — `build-deploy.sh` builds the personalized self-contained `deploy/` into the user's dotprofile repo (`aitools-<ghuser>/deploy/`), not the shared `aitools/deploy/`. Skips gracefully when no dotprofile is configured. |
| 4 | **Registries consolidated under `registries/`** — the JSON registries (tool-registry, tool-ops, tool-versions, framework-registry, glossary, incidents) are now canonical in `registries/`; the duplicate `reference/*.json` copies were removed. Skills (`/tool-registry`, `/tool-ops`), `sources-of-truth.md`, framework docs, and `check-post-push` repointed to `registries/`; `check-pre-commit` step 16 audit extended to also guard `registries/`. `glossary.json` reconciled (newer `reference/` content promoted into `registries/`). |

### Bug fixes

| # | Severity | Change |
|---|----------|--------|
| 1 | High | **bash 3.2 install crash** (fa07e52) — empty `sync_args` array under `set -u` aborted Step 22 on a fresh Mac. Guarded with `${arr[@]+...}`. |
| 2 | High | **`set -e` abort pre-user-init** (fa07e52) — `VAR=$(read_config_key … userRepoPath)` returned nonzero when the key was absent, killing aitools-install (402/408), build-deploy (1011), setup-user-skills, setup-user-hooks. Guarded `\|\| true` → graceful shared-only fallback. |
| 3 | Medium | **Homebrew not on PATH non-interactively** (2c0fd32) — `aitools` + `aitools-install` eval `brew shellenv` on macOS when brew is absent from PATH; fixes "node required for JSON manipulation" under hooks/MDM/`!`-shells. |
| 4 | Medium | **Modal spurious "Python 3.10+ required"** (2e702a9) — setup-modal skips the system-python gate when uv is present (uv provisions its own Python); enforces 3.10+ only on the pip fallback. |
| 5 | Low | **Cursor CLI drift** (fa07e52) — `agent mcp disable` removed upstream; setup-cursor-ide-mcp uses `agent mcp remove`, non-fatal. |
| 6 | Low | **bootstrap flow ordering** (7cc8cb5) — deployed shared-only configs before pulling the dotprofile; reordered so `user init` pulls it, then `aitools` rebuilds from it. |

### Owner migration (nobul-jose → nobul-tech)

| # | Change |
|---|--------|
| 7 | Repo moved to the **nobul-tech** org. Updated clone URLs (`aitools`, `aitools.ps1`, README), registry `meta.primary` (`tool-registry.json`, `tool-versions.json`), `ROADMAP.md` issue links, `incidents.json` issue link, and `LICENSE` copyright. Per-user dotprofile repos correctly stay under the user account (e.g. `nobul-jose/aitools-nobul-jose`); the `userTemplate` URL is intentionally left username-based. |

### Files created / removed

| File | |
|------|--|
| `scripts/bootstrap.sh` / `.ps1` | created — remote bootstrap |
| `reference/{tool-registry,tool-ops,tool-versions,framework-registry,glossary,incidents}.json` | removed — duplicates of `registries/*.json` (consolidated to the canonical `registries/`) |

### Documentation

| # | Change |
|---|--------|
| 8 | `registries/tool-registry.json` + `reference/tool-registry.md` + `registries/tool-versions.json` Python entries updated brew/pymanager → uv. |
| 9 | README ("How it works" / "What's here" / "Develop") + `.claude/rules/deploy-paths.md` reconciled to the per-user dotprofile-deploy model. |

**Verified on:** macOS (`python3`→uv 3.14.6, `bash`→5.3, Modal installs clean, full bootstrap + `aitools user init` + dotprofile `deploy/` build confirmed). **Windows: NOT yet validated** — the `setup-python.ps1` uv mirror and uv-Python registry entries were authored on macOS (no pwsh to parse-check); run `aitools install` on Windows to validate.

**Known debt (follow-ups):** (a) pre-commit deploy-drift steps 3+10 and post-push #7 now no-op against the frozen shared `aitools/deploy/` (build-deploy targets the dotprofile) — updating those check steps to audit the dotprofile `deploy/` is deferred; (b) Windows uv-Python path untested.

---

## v0.68.0 -- Resilient session/scratch harvesting + Windows harvest RCA (2026-06-14)

### Bug fixes

| # | Severity | Change |
|---|----------|--------|
| 1 | High | **Windows harvest no-op fixed** (bda38a2) — `setup-user-hooks.ps1` deployed `scratch-init.sh` + `harvest-session.sh` as files but never registered them in `settings.json` (no `MergeHookEntry`/validation), so harvesting + scratch dirs were no-ops on Windows since 2026-03-15. Added the two missing registrations + validation counts. |
| 2 | Medium | **check-post-push step 32 false-failure** (44e1daf) — the hook-registration parity audit compared sort-order-sensitive strings extracted via perl-in-PowerShell (mangled `$1`/`\n`). Moved the comparison to stdlib `scripts/check-hook-parity.py` (set-based, order-independent). |
| 3 | Low | **check-post-push step 30 stale caller list** — audited `setup-user-mcp` for `deploy_managed_file` return-value coverage, but skills deployment moved to `setup-user-skills`; `setup-user-mcp` is no longer a caller. Caller list corrected. |
| 4 | Low | **Unguarded `-ErrorAction SilentlyContinue`** — `setup-user-hooks.ps1` stale-backup `Get-ChildItem` now null-checks its result; `aitools-install.ps1` env cleanup uses a `Test-Path` guard. |
| 5 | Low | **read-session.py UnicodeEncodeError** on non-ASCII under a Windows cp1252 console — added a UTF-8 stdout/stderr reconfigure. |

### New features

| # | Change |
|---|--------|
| 6 | **SessionStart catch-up harvesting** — new `session-catchup.sh` hook + stdlib `scripts/ait-harvest.py` recover CC transcripts (incl. subagents) and scratch artifacts that an abrupt / offline / slept SessionEnd missed. Concurrency-safe across same-machine sessions: heartbeat single-flight lock, mtime-primary liveness, skip-own-session via stdin sid, dotprofile-state guards. |
| 7 | **Single-source hook registration** — `shared/hooks/hooks-manifest.json` + `check-post-push` step 32 parity audit close the bash↔PS1 registration drift that caused bug #1. |
| 8 | **Unified archive logic** — `session-archive.sh` / `harvest-session.sh` refactored to thin shims; `aitools sessions archive` (bash + ps1) delegate to `ait-harvest.py`, ending the triplication. |

### Documentation

| # | Change |
|---|--------|
| 9 | **`reference/logging.md`** — logging-standard decision doc (unified `~/.aitools/logs/`, per-component files, 5 MB × 5 rotation, native path separators). Phase 5 migration (`aitools-lib`) tracked in [#7](https://github.com/nobul-tech/aitools/issues/7). |
| 10 | **`plans/harvest-archive-resilience.md`** + ROADMAP "In Progress" entry. |

### Files created

| File | Purpose |
|------|---------|
| `scripts/ait-harvest.py` | Stdlib session/scratch carry-forward helper |
| `scripts/check-hook-parity.py` | Hook-registration parity audit (step 32) |
| `shared/hooks/session-catchup.sh` | SessionStart catch-up hook |
| `shared/hooks/hooks-manifest.json` | Single source of truth for hook registration |
| `reference/logging.md` | Logging standard |
| `plans/harvest-archive-resilience.md` | Implementation plan |

**Verified on:** Windows (14/14 `ait-harvest` unit tests, hook smoke tests, `build-deploy` clean, `check-post-push -Extensive` 0 FAIL, full `aitools install` clean — 19 hooks verified). macOS verification pending for the deferred Phase 5 logging migration (#7).

---

## v0.67.1 -- Hook pipeline fix, command channel, harness-db CLI (2026-03-25)

### Bug fixes

| # | Change |
|---|--------|
| 1 | **Hook deployment pipeline fix** (924b380) — removed stale Stop hook references (surfacing-duty, estimate-refresh, intent-sentinel) from `setup-user-hooks.sh/.ps1` that were deleted in v0.67.0 telemetry rebuild but still referenced in the deployment pipeline. Added cleanup logic to remove orphaned hook files from `~/.claude/hooks/`. |
| 2 | **harness-db.py context consumption** (ef572f0) — fixed three bugs: stderr output consumed context tokens (redirected to log), unbounded query output (added `--limit`), filter bug in session listing. |

### Enhancements

| # | Change |
|---|--------|
| 3 | **harness-db.py lean CLI subcommands** (d395d50) — `log-event`, `add-ol`, `add-finding` subcommands for zero-friction session data entry from hooks and scripts. |
| 4 | **Provenance schema + rewind-aware /aitool-continue** (0e01902) — provenance tracking tables in harness-db schema. `/aitool-continue` updated with rewind awareness and session continuity context. |
| 5 | **command-channel-stop.sh** — new Stop hook implementing the command channel uplink. Polls session SQLite DB for pending commander directives and injects them into agent context via stderr. Supports flash/priority/normal directive priorities. |

### Housekeeping

| # | Change |
|---|--------|
| 6 | **49 session artifacts harvested** — delegation prompts, investigation reports, operational learning, scripts, and research from session c0dc2ddc. Harvest manifest updated. |
| 7 | **Running estimate + state carry-forward** — updated channel state and provenance export from current session. |
| 8 | **deploy/ rebuilt** — `setup-user-skills.sh/.ps1` regenerated with updated skill content. |

(tested: macOS)

---

## v0.67.0 -- Telemetry rebuild, /aitool-continue, mission control (2026-03-25)

### Architecture

| # | Change |
|---|--------|
| 1 | **Telemetry rebuild** — deleted 3 Stop hooks (surfacing-duty, estimate-refresh, intent-sentinel) whose /tmp state tracking was unreliable. Enforcement hooks (standing-order-guard, delegation-duty-guard, block-claude-code-guide, glossary-skill-guard, sh-file-fixup) now emit JSONL events (~0.1ms) instead of Python subprocesses (~150ms). SessionEnd processes and ships to Datadog. |
| 2 | **Harness DB extended** — `harness-db.py` gains event processing, new schema fields, JSONL aggregation. `harness-db-schema.sql` updated. |

### New skills

| # | Change |
|---|--------|
| 3 | **/aitool-continue** — user-level continuous self-learning skill. Loads operational learning, commander profile, delegation principles, project context, and recent session state so every session starts smarter than the last. |

### Bug fixes

| # | Change |
|---|--------|
| 4 | **CI fix: CLAUDE_EFFORT_LEVEL unbound variable** — CI runners failed for 6 consecutive runs because `CLAUDE_EFFORT_LEVEL` was referenced without `set -u` guard in hook scripts. Added `${CLAUDE_EFFORT_LEVEL:-}` default. deploy/ rebuilt. |
| 5 | **Harness-db hooks registered in settings.json** — `harness-db-sessionstart.sh` and `harness-db-sessionend.sh` were deployed to `~/.claude/hooks/` but never registered via `mergeHookEntry` in `setup-user-hooks.sh/.ps1`. Hooks were invisible to Claude Code. Both scripts now resolve, deploy, validate, and register alongside the existing 13 hooks. |

### Housekeeping

| # | Change |
|---|--------|
| 6 | **360 harvested artifacts committed** — backlog of session artifacts from 2026-03-22 through 2026-03-24 (AARs, dashboards, research, scripts, running estimates). Harvest manifest updated with 4 new entries. |
| 7 | **Harness state carry-forward** — channel state files (alpha, bravo, charlie) and mission-command handoff plan from session 5HyCwPtSDH. |

(tested: macOS)

---

## v0.66.0 -- Intent sentinel, delegation guard, managed bash, CI pipeline (2026-03-24)

### New hooks

| # | Change |
|---|--------|
| 1 | **intent-sentinel-stop.sh** — Stop hook with 8 telemetry functions. Consolidated status line every 5 turns: context usage, turns since human, subagent count, RE freshness, delegation compliance, session duration, tool usage profile. Resurfaces commander intent after 3 agent-only turns. Detects research→execution phase transitions. The commander's window into harness internals. |
| 2 | **delegation-duty-guard.sh** — PreToolUse on Agent. Checks every subagent launch for 6 delegation duty elements (identity, rules, skills, OL, WRITE_BLOCKED, access workaround). Injects corrective reminder when elements missing. OBSERVE mode. |

### Platform + CI

| # | Change |
|---|--------|
| 3 | **Managed bash** — `setup-bash.sh/.ps1` installs bash 5.x via Homebrew on macOS (system bash is 3.2 from 2007). Linux/Windows verified. Added to tool-registry, install pipeline, build-deploy. |
| 4 | **CI pipeline** — `.github/workflows/check.yml` with 3 runners: macOS-14 (brew install bash), ubuntu-latest, windows-2022. Validates bash/PS1/Python syntax, build-deploy drift, line endings, script pairing. |
| 5 | **D1+D2 fixed** — check-post-push.sh: process substitution+heredoc (D1) rewritten with temp file approach, 10 BSD paste call sites (D2) fixed with explicit stdin arg. |

### Hook improvements

| # | Change |
|---|--------|
| 6 | **standing-order-guard.sh** — 3 checks promoted to enforce (OR, semicolon, backticks). MODE_REST eliminated — each check has its own variable. Intent header + KPI definitions added. 15/15 smoke tests. |
| 7 | **Hook stderr fix** — removed `2>/dev/null` from harness-db.py calls in 5 hooks. Safety warnings now surface via stderr. Fixes USO violation (no silent failures). |

### Skills + evaluation

| # | Change |
|---|--------|
| 8 | **`/aitool-eval` reference-card** — second reference-card skill. Full evaluation methodology embedded: criteria, discovery playbook, health flags, Homebrew checklist, sandbox walkthrough. Platform gotcha catalogs, Perl exemplar, system tool upgrade + governed capability evaluation contexts. |
| 9 | **/aitool-eval depth** — Perl story as deep cross-platform exemplar, platform-specific gotcha catalogs (macOS/Windows/Linux), BuildPrereqs reference, Perl-on-macOS carry-forward. |

### Research (in scratch, to be harvested)

| # | Change |
|---|--------|
| 10 | **Self-evolving systems research** — 1,752 lines across 3 files. 23 concepts from 7 domains (autopoiesis, strange loops, MAPE-K, Constitutional AI, OODA, SECI spiral). 7 safety mechanisms identified. Ascending Spiral conceptual model. Managed deployment analysis for DB exports. |

(tested: macOS)

---

## v0.65.1 -- Compliance, reference-card skill, intent fixes (2026-03-24)

### New capabilities

| # | Change |
|---|--------|
| 1 | **`/aitool-ops` reference-card skill** — first user-level reference-card in the harness. Embedded tool-ops knowledge (deny rules, 14 hooks, CC version deps, governance modes, hook portability table, subagent restrictions, SendMessage gap) available in ANY repo. Establishes the three-tier skill taxonomy pattern (decision #49, M5 P-6). |
| 2 | **`.claude/rules/aitool-ops.md`** — governance rule with trigger directive, three-tier taxonomy table, reference-card pattern definition |

### Hook improvements

| # | Change |
|---|--------|
| 3 | **SQLite-integrated hooks** — 5 session lifecycle hooks rewritten with harness-db.py integration (OBSERVE mode, graceful degradation). Critical fixes carried forward (stat dispatch, no rm-rf, session_id dirs). |
| 4 | **glossary-skill-guard.sh** — 2 audit fixes: added missing `set -euo pipefail`, fixed `hookSpecificOutput` JSON going to stderr instead of stdout |
| 5 | **build-deploy.sh** — hook embedding expanded from 4 to 13 hooks |
| 6 | **check-pre-commit.sh** — step 18 (Python syntax validation), step 19 (schema file check) |

### Skill quality

| # | Change |
|---|--------|
| 7 | **5 skill intents fixed** — chrome-devtools, a11y-debugging, investigate, optimize-plan: upgraded from `## Purpose`/`Core Concepts` to structured `## Intent` (purpose/scope/audience) |
| 8 | **Skill artifact lifecycle RFC** — written to scratch, defines 5-phase lifecycle, 12 conventions, testing strategy |

### Compliance

| # | Change |
|---|--------|
| 9 | **Full 7-domain compliance audit** — cross-platform, structured logging, build-deploy, library usage, entry points, agentic standards, hook deployment. CLEAN: zero violations across 13 hooks, 34 setup scripts, 2 entry points, 2 Python scripts |

(tested: macOS)

---

## v0.65.0 -- SQLite foundation, mission control, dashboard fixes, hook improvements (2026-03-24)

### New capabilities

| # | Change |
|---|--------|
| 1 | **SQLite harness database foundation** — `scripts/harness-db.py` (1001-line Python CLI) with subcommands: init, session start/end, mission start/end, log, export, status. Canonical schema at `reference/harness-db-schema.sql` covering session DBs (per-session, WAL mode) and harness DB (cross-session). Option B architecture: SQLite runtime (gitignored) + JSON archive (tracked in git). |
| 2 | **Session lifecycle hooks** — `harness-db-sessionstart.sh` registers sessions in SQLite DB. `harness-db-sessionend.sh` exports DB to `running-estimate.json` for git carry-forward. |
| 3 | **`/mission-control` skill** — new user-level skill codifying 7 ad-hoc monitoring patterns into a structured 4-layer monitoring stack: infrastructure health, activity monitoring, work product inventory, deliverable validation. Pre-flight verification protocol, mission health thresholds, FRAGORD criteria. |
| 4 | **Multi-mission dashboard** — `generate-dashboard.py --multi-dir` scans directory for multiple running estimates, renders summary table with per-mission health. Both static and live (`--serve`) modes. |
| 5 | **Dashboard schema validation** — `generate-dashboard.py` warns on stderr when running estimate is missing expected fields. Silent zeros → visible warnings. Backward compatible. |
| 6 | **Dashboard `--health-check`** — `aitools-dashboard.sh --health-check` reports per-instance liveness + data quality with field counts. |
| 7 | **Multi-instance dashboard ports** — port-keyed PID registry (`~/.aitools/dashboard-pids/<port>.pid`) replacing single PID file. `--stop --port N` or `--stop --all`. `--status` shows all instances. |
| 8 | **Running estimate template** — `.aitools/templates/mission-running-estimate.json` with ALL dashboard-expected fields pre-populated. Missions copy to prevent silent-zero dashboards. |

### Hook improvements (issues #53, #54)

| # | Change |
|---|--------|
| 9 | **harvest-session.sh** — session ID in harvested filenames (`YYYY-MM-DD_session-XXXX_filename`), auto-creates `harvesting/` + manifest on first harvest, routes `handoff*` files to `.aitools/channel/handoffs/`, reports harvest results to stderr |
| 10 | **scratch-init.sh** — uses CC `session_id` for deterministic dir names (fixes `.current-session` race condition for concurrent sessions), discovers unconsumed handoffs at `.aitools/channel/handoffs/` on session start |
| 11 | **`.aitools/channel/handoffs/`** — new tracked directory for session handoff documents |

### Operational knowledge

| # | Change |
|---|--------|
| 12 | **tool-ops-claude-code.md #24** — subagent cross-repo file access restriction: Glob/Grep denied outside CWD repo, Read with explicit paths works. Documented workaround for delegation prompts. |
| 13 | **tool-ops-claude-code.md #25** — SendMessage for agent continuation unavailable: gated behind Agent Teams flag, old `resume` param removed in 2.1.77. Agent Continuation Gap section with 3 upstream issues linked. |
| 14 | **operational-learning.json OL-O12** — subagent file access restriction observation with evidence and workaround |
| 15 | **planning/SKILL.md** — subagent file access restriction section added alongside existing subagent context gap |

### Session state

| # | Change |
|---|--------|
| 16 | **running-estimate.json v9** — updated from v8.3 with full session RnTOD5XJFi state: 16 new decisions, 28 completedWork, 13 facts, 7 assumptions, 8 observations, 8 findings, 12 mission delegations. Audited by S2-Quebec (5-POV parallel audit, PASS with zero must-fix items). |
| 17 | **harness-state.json** — new artifact (exploration): the harness in document form. Initial skeleton with design principles, operative patterns, frameworks, decisions, gaps, assumptions. |

(tested: macOS)

---

## v0.64.1 -- Remove auto-deletion from session hooks (2026-03-22)

### Fixes

| # | Change |
|---|--------|
| 1 | **Remove rm -rf from scratch-init.sh** — SessionStart hook no longer auto-deletes stale session dirs (>24h). This was the proximate cause of the 30-file loss (session Z1IhGrcgGO). Now logs stale count for manual cleanup |
| 2 | **Remove rm -rf from harvest-session.sh** — SessionEnd hook no longer deletes the session scratch dir after harvesting. If harvest partially fails or classification misses files, they remain recoverable |
| 3 | **Remove fs.unlinkSync from harvest-session.sh** — Prune logic still marks artifacts as `pruned` in manifest but no longer deletes files from `harvesting/`. Files accumulate for manual cleanup |

(tested: macOS)

---

## v0.64.0 -- Platform stabilization, operational learning, process discipline (2026-03-22)

Session 77a33baf (Windows): Lagebeurteilung after switching from Mac revealed 3 cross-platform failure clusters. Fixed all. Built institutional learning infrastructure. Established design principle. 3-agent parallel investigation for Deploy-Configs root cause.

### New

| # | Change |
|---|--------|
| 1 | **Design principle: Process discipline as work product** — the observation-to-fact pipeline IS the primary deliverable. Added to CLAUDE.md Design Principles. Governs every session, every platform, every aitools developer |
| 2 | **Operational learning estimate** — `.aitools/channel/operational-learning.json`. Institutional learning accumulator (CALL OIL taxonomy). 11 observations, 8 insights, 7 patterns, 5 proposals with CALL lifecycle (pending-analysis → analyzed → implemented → verified). Active carry-forward gaps with `informsTransitions`/`resolvableBy`/`blocksExecution` |
| 3 | **Hook portability check** — `check-pre-commit.sh` step 17. Context-aware detection of 5 known-bad patterns in hooks (`stat -f`, stat fallback chains, `find -printf`, `grep -P`, `date -d`). Missing detection layer for platform engineering |
| 4 | **Hook portability rule** — `cross-platform.md` new section: known command divergences table, canonical `stat` dispatch pattern, "NEVER use fallback chain" guidance |

### Fixes

| # | Change |
|---|--------|
| 1 | **Stop hook crash on Windows** — `surfacing-duty-stop.sh` and `estimate-refresh-stop.sh` crashed with "File: unbound variable". Root cause: `stat -f %m` on GNU stat (Git Bash) means `--file-system`, partially succeeds with wrong multiline output, contaminates variable, `set -u` catches it. Fix: `uname -s` platform dispatch (same pattern as `session-archive.sh:68`). 4th hook crash instance (v0.29.2 $MODE, v0.31.0 find-printf, bc2429e hook type, this) |
| 2 | **Deploy-Configs file lock crash** — `aitools` no-args failed on Windows: all 6 deploy PS1 scripts crashed instantly with zero diagnostics. Root cause: `2>> $logFile` holds exclusive .NET FileStream lock; child scripts write to same file via `[IO.File]::AppendAllText()`; lock collision throws IOException on first log call; `*> $null` suppresses the exception. Fix: remove output redirection, matching `Invoke-ValidatedScript` pattern. Fixed both PS1 and bash entry points. 3-agent parallel investigation (S3-Alpha, S3-Beta in worktree, S2-Verify) |
| 3 | **Dotprofile pull blocked** — `aitools-nobul-jose` had uncommitted CLAUDE.md template change blocking pull. Resolved: stash, pull, pop, resolve conflict (de-interpolation bug: `jose@nobul.tech` hardcoded instead of `{{IDENTITY_GIT_EMAIL}}`). 2 untracked session files committed |

### Operational Learning

| Pattern | Description |
|---------|-------------|
| P1 | Write-on-A, discover-on-B (4th instance) |
| P2 | Correct pattern exists but new code uses old |
| P3 | Commit pipeline selectivity (SessionEnd outputs never committed) |
| P4 | Cross-machine state divergence |
| P6 | Demonstrate-then-skip at subsequent transitions |
| P7 | 6-stage carry-forward pipeline (produce → commit → push → pull → deploy → verify) |

(tested: Windows)

---

## v0.63.0 -- Dynamic mission control dashboard, .gitignore fix, 30 file recovery (2026-03-21)

Session 5HyCwPtSDH: 35 missions, ~47 agents, 18 AARs, 16 decisions. The session that taught the harness how to learn continuously.

### New

| # | Change |
|---|--------|
| 1 | **Dynamic mission control dashboard** — `aitools dashboard` CLI command with `--serve` (live HTTP server, auto-updates when running estimate changes), `--stop`, `--status`, `--snapshot`. Zero external dependencies (Python stdlib). CORS-safe (localhost, not file://). Dual-script (.sh + .ps1) |
| 2 | **SessionStart hook** — `dashboard-serve.sh` auto-launches dashboard server. Zero user action. Calls `aitools dashboard --background` |
| 3 | **Lagebeurteilung Stop hook** — `estimate-refresh-stop.sh` tracks turns, injects context rot reminders at 20%+ context, detects stale running estimates. Implements D-CONTEXT-ROT-HOOK |
| 4 | **30 file recovery** — session Z1IhGrcgGO's 30 lost investigation files recovered from CC transcript extraction (Write tool call content in JSONL). Method: `extract-writes.py` parsed 11.4 MB transcript + 52 subagent transcripts |

### Fixes

| # | Change |
|---|--------|
| 1 | **`.gitignore` fix** (D-GITIGNORE-FIX) — replaced blanket `.aitools/` with selective patterns. Unblocks: running estimate tracking, channel/handoffs/, briefings/. Unanimous finding across M1, M2, M4 |
| 2 | **Running estimate at tracked path** — `.aitools/channel/running-estimate.json` now carries forward between machines via git |

### Session decisions (16)

D-CONTEXT-ROT-HOOK, D-OPERATIONAL-LEARNING-DUTY, D-GITIGNORE-FIX, D-MULTI-AGENT-PATTERNS, D-PER-SESSION-ESTIMATES, D-AITOOL-PREFIX, D-S1-LAUNCH, D-DASHBOARD-GOVERNANCE, D-ASSUMPTION-INJECTION, D-MARK-OR-VERIFY, D-NACHBESPRECHUNG, D-CLI-NATIVE-DASHBOARD, D-SILENT-DESCOPING-PREVENTION, D-DYNAMIC-HARD-REQUIREMENT, D-INLINE-SYNTHESIS, D-DELEGATION-GATE

### Hard requirements for accepting session

HR-1: Per-mission dashboards (auto-start at delegation). HR-2: Concurrent session dashboards (per-session ports). HR-3: Channel infrastructure (decisions #22-24). HR-4: Full platform support (.ps1 server). HR-5: Running estimate auto-freshness.

---

## v0.62.6 -- Handoff v3 update, /handoff workflow executed (2026-03-19)

Handoff prompt updated to v3 using the /handoff skill's full 8-step workflow (state audit → update → verify → amend). Captures v0.62.3-5 work: 6 AAR proposals implemented, 13 governed terms, session activity dashboard, cross-boundary verification RCA, surfacing duty findings, CC UX observation. 5 verification amendments applied (section numbering, exclusion count, term count, commit range, grammar).

---

## v0.62.5 -- Session activity dashboard, full /handoff governance (2026-03-19)

### New

| # | Change |
|---|--------|
| 1 | **Session activity dashboard** — interactive HTML report (`harvesting/2026-03-19_session-subagent-report.html`) showing all 40 subagent launches: identity, delegation prompts, skills, context, outcomes, duration, tokens. Dark theme, filterable, searchable, collapsible |
| 2 | **Exit code 1 AAR** — full investigation chain: cross-boundary verification failure class, false claim propagation RCA, 6 proposals implemented |

### Improvements

| # | Change |
|---|--------|
| 3 | **13 governed terms** — accepting session, assumption, Auftrag, blast radius, blocker, cross-boundary, delegating agent, handoff, Lagebeurteilung, lifecycle transition, Mitdenken, Reibung, Schwerpunkt |
| 4 | **Incident-governance** — ambiguity routing (terminological→/glossary, structural→/incident), TODO(glossary) markers |
| 5 | **Scratch skill** — lifecycle deletion warning |
| 6 | **Workspace rule** — channel/handoffs/ row |
| 7 | **Lagebeurteilung** — general-purpose capability in /handoff (5 transition points, assumption flush) |
| 8 | **PCI language** — "delegating agent" replaces fixed "S3", delegation duty component 9 (lifecycle transition awareness) |
| 9 | **"Accepting session"** — replaces "next session" throughout, staleness notes added |

### Session totals (Z1IhGrcgGO)

40 subagents, 3.4M tokens, 2h 54m compute, 1043 tool calls, 4 worktrees, 8 commits, v0.62.2–v0.62.5.

---

## v0.62.4 -- /handoff governance, glossary terms, ambiguity routing (2026-03-19)

All 6 AAR proposals implemented. 13 governed terms filed. Ambiguity routing in surfacing duty. Lagebeurteilung as general-purpose capability. Scratch lifecycle warning. Workspace rule updated. See v0.62.5 for consolidated description.

---

## v0.62.3 -- /handoff skill, harness verification, cross-boundary RCA (2026-03-18)

### New

| # | Change |
|---|--------|
| 1 | **`/handoff` skill** — user-level skill (`shared/skills/handoff/`) capturing the full session handoff workflow: Schwerpunkt declaration, session state audit (S2), Lagebeurteilung, handoff writing (S3), 9-criteria verification, amendments, commit. Applies German doctrine concepts (Schwerpunkt, Lagebeurteilung, Reibung, Mitdenken) as thinking tools. Deployed to Claude Code and Cursor |
| 2 | **Handoff prompt v2** — `plans/mission-command-briefing/handoff-prompt-v2.md`. 12 sections, verified 3x, covers 10 approved decisions, 12 open threads, 5 hard exclusions, provenance research across 6 doctrinal traditions |

### Improvements

| # | Change |
|---|--------|
| 3 | **Harness CI/CD investigation** — bootstrap problem identified (check-post-push.sh broken on macOS 16 days undetected). CI Phase 1 feasibility confirmed (shellcheck + tool-ops mock tests, ~30 lines YAML). Tool-ops "no" for aitools self-tracking reconciled via three-layer verification architecture |
| 4 | **Cross-boundary verification RCA** — false claim ("scratch not auto-cleaned") propagated through 5 subagents unchallenged. 10 missed catch points identified. New verification failure class: artifacts that cross lifecycle boundaries (session end/start) tested only within one side of the boundary |
| 5 | **`/handoff` skill scratch deletion fix** — removed scratch fallback, mandated permanent tracked location, added lifecycle survival to verification criterion 2, fixed "Project without plans/" adaptation that endorsed scratch |

### Harvested

33 artifacts from prior sessions (investigations, barrier analyses, extraction scripts)

---

## v0.62.2 -- Governed-data-access enforcement, harness definition update (2026-03-17)

### Improvements

| # | Change |
|---|--------|
| 1 | **Governed-data bypass vectors removed** — 28 governed registry JSON paths removed from 10 files (rules, reference docs, cursor rules). Agents no longer learn registry file paths from rules loaded at session start. Pre-commit step 16 (capability bypass audit) now passes |
| 2 | **Harness definition updated** — CLAUDE.md mission, `reference/harness.md`, and glossary definition aligned to: "aitools and the tools, context, state, artifacts, frameworks, and provenance it manages" |
| 3 | **`reference/harness.md` rewritten** — all governed JSON paths removed, artifact roles scoped out to future `/artifact-roles` skill, crisp one-line definition added |
| 4 | **Incident #50 filed** — sources-of-truth.md protected files table exposes all governed registry JSON paths as bypass vectors. Step 16 "known failure" rationalization proven wrong during live session |

### Governed-data fixes

| File | Paths removed |
|------|--------------|
| `.claude/rules/frameworks.md` | 2 (`framework-registry.json`) |
| `.claude/rules/tool-lifecycle.md` | 1 (`tool-registry.json`) |
| `.claude/rules/documentation-standards.md` | 1 (`incidents.json`) |
| `.claude/rules/tool-ops.md` | 1 (`tool-ops.json`) |
| `reference/framework-adoption.md` | 6 (`framework-registry.json` ×5, `incidents.json` ×1) |
| `reference/framework-governed-vocabulary.md` | 4 (`glossary.json` ×3, `framework-registry.json` ×1) |
| `reference/framework-three-layer-governance.md` | 1 (`framework-registry.json`) |
| `reference/managed-file-deployment.md` | 1 (`incidents.json`) |
| `reference/script-standards-detail.md` | 1 (`glossary.json`) |
| `.cursor/rules/managed-file-deployment.mdc` | 2 (`incidents.json` ×2) |

### Remaining (tracked)

9 governed registry paths remain in rules: `sources-of-truth.md` (6) and `incident-governance.md` (3). Both require design work — see Incident #50.

---

## v0.62.1 -- Brief integrity, #54 integration, readingOrder fix (2026-03-16)

### Improvements

| # | Change |
|---|--------|
| 1 | **Decision #54 integration** — 13 reciprocal `related` links fixed, component (15) added to #51 (systemic finding escalation from Plan Writer to improvement cycle) |
| 2 | **readingOrder fix** — 6 decisions (#49-#54) were missing from `meta.readingOrder`. Agents reading via /brief would have missed them. Now 53 active decisions across 12 phases, zero gaps |
| 3 | **Handoff prompt updated** — improvement cycle woven into plan-writing protocol (write-review escalation, Plan Writer template, cross-cutting table, sequencing). ReadingOrder aligned with brief |
| 4 | **Incident #49 filed** — subagent transcript search missed queue-operation messages, produced false fabrication claim |

---

## v0.62.0 -- Workspace governance, planning brief v6, harness improvement cycle (2026-03-16)

### New

| # | Change |
|---|--------|
| 1 | **aitools-workspace rule** — new `.claude/rules/aitools-workspace.md` governs the `.aitools/` namespace: project-scoped harness capabilities (channel, scratch, harvesting) with cross-machine carry-forward principle. Session-ephemeral data gitignored; carry-forward state (running estimates) tracked in git |
| 2 | **tool-registry.json** — unified JSON registry merging tool-registry.md + tool-versions.json. Governed by `/tool-registry` skill |
| 3 | **Mission command briefing** — 54-decision planning brief (`plans/mission-command-briefing/`) covering Mission Command, Platform Engineering, Mission Analysis, and Operational Learning frameworks |
| 4 | **Decision #53: Governed document drift prevention** — `governedBy` schema field + rule-write impact hook + plan-gate drift check. Structural enforcement against stale brief decisions |
| 5 | **Decision #54: Harness improvement cycle** — finding-to-verified-fix workflow through structured investigation, parallel barrier analysis, worktree-isolated editing, and independent re-audit |

### Improvements

| # | Change |
|---|--------|
| 6 | **Rules refined** — frameworks.md (deduplicated registry table), sources-of-truth.md (tool-registry.md→json), tool-lifecycle.md (install method discovery, trigger directive) |
| 7 | **Skills updated** — intent-writing (pre-write audit, multi-pass ambiguity removal, quality criteria, style calibration), intent-audit (quality/ambiguity checks, exemplar comparison), tool-registry (schema v1.0 alignment), incident (known limitations noted) |
| 8 | **harvest-session.sh** — JSON, YAML, and unknown file extensions now harvested instead of silently deleted |
| 9 | **5 brief decisions amended** — #3, #22, #26, #34, #50 aligned with workspace rule carry-forward principle (14→1 inconsistencies) |
| 10 | **Cross-machine carry-forward intent** — added to dotprofile CLAUDE.md and live ~/.claude/CLAUDE.md |

### Incidents

| # | Change |
|---|--------|
| 11 | **Incident #48** — agent asserts behavioral constraints without checking source artifacts (3rd occurrence of pattern) |
| 12 | **Incident #49** — subagent transcript search missed queue-operation messages, produced false fabrication claim |

### Harvesting

| # | Change |
|---|--------|
| 13 | **30+ session artifacts** harvested from sessions 84280c8b, eaacf9da, b8a9ed4e, and current session |
| 14 | **Handoff prompt** for continuation sessions |

---

## v0.61.2 -- AAR, test suite, governed data fix (2026-03-15)

### Improvements

| # | Change |
|---|--------|
| 1 | **After Action Review** — 731-line AAR of the tool-ops planning session harvested as a keep artifact. Covers session arc, 10 key decisions, 7 plan revisions, military doctrine parallels (Mission Command, OPORD, Backbrief), and lessons for future plans |
| 2 | **Tool-ops test suite** — 42 tests across 5 suites (schema integrity, drift detection, live contract tests, governed access enforcement, cross-reference validation). Harvested as a keep artifact for reuse |

### Bug fixes

| # | Change |
|---|--------|
| 3 | **Governed data bypass in tool-ops-claude-code.md intent** — intent statement referenced `tool-ops.json` and `incidents.json` directly instead of through governing skills. Found by tool-ops test suite (Suite 4). Fixed to reference `/tool-ops` and `/incident` skills |

---

## v0.61 -- Tool-ops framework, incidents rename, CC ops consolidation (2026-03-15)

### Breaking changes

| # | Change |
|---|--------|
| 1 | **Gap → Incident rename** — `known-gaps.json` renamed to `incidents.json`, `gap-governance.md` to `incident-governance.md`, `/gap` skill to `/incident`. Schema: removed `type` field (gap/ambiguity distinction), added `rootCause`, `correctiveAction`, `preventionLayer` nullable fields. All 72 files updated across rules, skills, hooks, reference docs, scripts, plans, cursor rules, glossary, and deploy |
| 2 | **CC ops files consolidated** — `claude-code-maintenance.md`, `claude-code-practices.md`, `claude-code-windows-shell.md` merged into `reference/tool-ops-claude-code.md`. All cross-references updated (14 files) |

### New frameworks

| # | Change |
|---|--------|
| 3 | **Tool operations framework** — per-tool operational metadata for deeply-integrated managed tools. Governs deny rules, hooks, context injection, KPIs, governance modes (audit→active), and verification specs. Grounded in SRE operational readiness, hook-rollout observe-to-enforce, and lean pull systems. New rule (`.claude/rules/tool-ops.md`), reference (`reference/framework-tool-ops.md`), registry (`reference/tool-ops.json`), skill (`/tool-ops`). Claude Code is the first implementation |

### New skills

| # | Change |
|---|--------|
| 4 | **`/incident`** (project) — replaces `/gap`. Files harness deficiencies with structured fields, severity classification, and root cause tracking. Updated schema with rootCause/correctiveAction/preventionLayer |
| 5 | **`/tool-ops`** (project) — governed access to tool-ops.json. Read operational metadata, update governance modes, manage per-tool entries |

### New hooks

| # | Change |
|---|--------|
| 6 | **`block-claude-code-guide.sh`** (PreToolUse on Agent) — blocks built-in Claude Code Guide subagent (Haiku model returns inaccurate schema), injects corrective harness context for other Agent calls. Resolves deny rule bypass (incident #26) |
| 7 | **`tool-ops-session-audit.sh`** (SessionEnd) — reads tool-ops.json, runs mock-json-pipe contract tests, checks deny rule drift, detects stale version deps, emits KPIs to `~/.claude/hooks/logs/tool-ops-audit.jsonl`. Advisory only (always exit 0) |

### Improvements

| # | Change |
|---|--------|
| 8 | **20 incidents migrated from effectiveness.md** — I1-I20 from the Claude Code effectiveness tracker now in `incidents.json` as entries #28-47 with structured fields. Original text preserved in effectiveness.md |
| 9 | **2 new incidents filed** — #26 (deny rule bypass via permissions.deny) and #27 (glossary hook registered but never deployed) |
| 10 | **Glossary updated** — "gap" and "ambiguity" deprecated, "incident" added. 8+ term sources updated |
| 11 | **Surfacing duty hook updated** — `surfacing-duty-stop.sh` now uses incident terminology, detects both gap and incident language for backward compatibility |
| 12 | **Intent blocks added** — `incident-governance.md`, `incident/SKILL.md`, `tool-ops-claude-code.md` now have formal intent statements |
| 13 | **Framework registry** — tool-ops entry added, gap governance entry renamed to incident governance |

---

## v0.60 -- Skills extraction, dotprofile adopt flow, dynamic skill discovery (2026-03-15)

### Breaking changes

| # | Change |
|---|--------|
| 1 | **Skills deployment extracted from setup-user-mcp** — skills are now deployed by `setup-user-skills.sh/.ps1` (new script pair). `setup-user-mcp` only handles MCP servers and deny rules. Entry points updated to call the new script |

### New features

| # | Change |
|---|--------|
| 2 | **Dynamic skill discovery** — `setup-user-skills` scans `shared/skills/*/` at runtime instead of hardcoding skill names. Adding a new skill to `shared/skills/` is all that's needed — no script changes required |
| 3 | **Dotprofile priority for skills and hooks** — dotprofile repo (`claude/skills/`, `claude/hooks/`) overrides shared versions, matching the existing CLAUDE.md priority pattern |
| 4 | **Reverse discovery** — `setup-user-skills` and `setup-user-hooks` scan deployed directories for user-created content not in any source and offer to adopt it to the dotprofile repo |
| 5 | **All 8 user-level skills now deploy** — was 2 (chrome-devtools, a11y-debugging). Now also deploys: intent-audit, intent-writing, investigate, optimize-plan, planning, scratch |
| 6 | **Dynamic skill embedding in build** — `build-deploy.sh` discovers and embeds all skills from `shared/skills/` at build time. Deploy scripts are fully self-contained with all skills |

### New hooks

| # | Change |
|---|--------|
| 7 | **`sh-file-fixup.sh`** (PostToolUse on Write\|Edit) — auto-fixes .sh files after creation/modification: CRLF→LF, chmod +x, git update-index --chmod=+x. Eliminates the recurring manual fixup cycle that interrupted every commit involving .sh files |
| 8 | **`surfacing-duty-stop.sh`** (Stop, prompt type) — periodic surfacing duty reminder every 30m in long sessions, plus gap-acknowledgment detection that prompts filing when agent says "pre-existing gap" without invoking /gap. Implements the Stop hook spec from gap-governance.md |

### Bug fixes

| # | Change |
|---|--------|
| 9 | **Accept & adopt target fixed** — skills and hooks adopt now writes to dotprofile repo (`<userRepoPath>/claude/skills/`, `claude/hooks/`), not to `shared/` in the aitools repo. Fixes gap #15 |
| 10 | **PS1 hooks parity** — `setup-user-hooks.ps1` now deploys scratch-init.sh and harvest-session.sh, matching the bash version |
| 11 | **First-deploy gap fixed** — `aitools` entry point now compares deploy list against repo source after pull+build. If the list changed, self-updates and re-execs so new deploy scripts run on the first deploy, not the second. Zero overhead when lists match (~1ms perl comparison) |
| 12 | **Raw echo in resolve_hook()** — changed to `printf '%s\n'` to satisfy check-script step 6 (no raw echo in setup scripts) |
| 13 | **Stop hook false positive** — suppresses gap-acknowledgment detection for 30m after known-gaps.json is modified, preventing false triggers when agent discusses a gap after filing it |

### Improvements

| # | Change |
|---|--------|
| 14 | **MergeHookEntry supports hook types** — bash and PS1 merge functions now accept a `hookType` parameter (default: `command`). Enables `prompt`-type hooks like the Stop hook |
| 15 | **User repo spec updated** — `reference/user-repo.md` now documents `claude/skills/` and `claude/hooks/` directories in the dotprofile structure |
| 16 | **CLAUDE.md deploy list updated** — includes `setup-user-skills` in the config scripts list |
| 17 | **Gap #25 filed** — deploy/setup-user-hooks embeds 2 of 6 hook scripts; settings.json references 4 missing paths on MDM machines |

---

## v0.59 -- Governance overhaul, artifact harvesting, tool evaluation framework (2026-03-15)

### New frameworks

| # | Change |
|---|--------|
| 1 | **Tool evaluation framework** — new rule (`.claude/rules/tool-evaluation.md`), `/tool-eval` skill, `/tool-registry` skill. Ranked evaluation principles, health flags (green/yellow/red), evaluation provenance in `reference/evaluations/` |
| 2 | **Artifact harvesting framework** — adopted from Disciplined Agile reuse engineering. New rule, `/harvest` skill, `harvesting/` directory, SessionEnd hook (`harvest-session.sh`) for classifying and preserving session work product |
| 3 | **Governed data access** — new rule (`.claude/rules/governed-data-access.md`), `/governed-data` skill. Codifies the principle that governed JSON files are accessed only through their governing skill |

### New skills

| # | Change |
|---|--------|
| 4 | **`/tool-registry`** (project) — governed access to tool registry data |
| 5 | **`/tool-eval`** (project) — evaluation process, health flag criteria, Homebrew verification checklist |
| 6 | **`/governed-data`** (project) — content placement standard, adding governed registries, compliance auditing |
| 7 | **`/harvest`** (project) — artifact harvesting lifecycle, manifest management, promotion workflow |
| 8 | **`/scratch`** (user-level) — ephemeral session scratch files, mktemp session directories, commit message pattern |

### New hooks

| # | Change |
|---|--------|
| 9 | **`scratch-init.sh`** (SessionStart) — creates unique session scratch directory, cleans stale dirs |
| 10 | **`harvest-session.sh`** (SessionEnd) — classifies scratch contents, harvests artifacts, audits harvesting/ |

### Improvements

| # | Change |
|---|--------|
| 11 | **Structured logging for aitools entry points** — `scripts/aitools` and `scripts/aitools.ps1` now use `[timestamp] [aitools] [level]` format for all step output. Added missing `blog_warn` to `build-deploy.sh` |
| 12 | **Pre-commit step 16 expanded** — now checks CLAUDE.md in addition to rules, adds `tool-registry.json` to governed files list |
| 13 | **Tool lifecycle rule rewritten** — 206→90 lines, added intent, stripped procedures that moved to skills |
| 14 | **Frameworks rule lean rewrite** — updated intent, added registries table rows for Glossary and Tool evaluation |
| 15 | **CLAUDE.md governed data cleanup** — removed 5 direct JSON references, removed stale Three-layer registries design principle |
| 16 | **Cross-reference sweep** — 14 files updated to reference `/tool-registry` skill instead of `tool-registry.md` |
| 17 | **Chrome DevTools skill** — added `.md` URL pattern for efficient Claude Code docs reading |
| 18 | **USO/UCI updates** — scratch directives now reference `/scratch` skill and session directories |
| 19 | **Framework registry** — Tool lifecycle entry updated (new concepts, artifacts), Governed data access entry updated (new skill), Artifact harvesting entry added. `lastUpdated` backfilled on all entries |
| 20 | **Framework reference files** — `framework-tool-lifecycle.md` and `framework-governed-data-access.md` rewritten to follow content placement standard (concepts only, no requirements duplication) |

---

## v0.58 -- Verified terminology, capability bypass detection (2026-03-14)

### Bug fixes

| # | Change |
|---|--------|
| 1 | **"unchanged" → "verified"** in 6 remaining setup scripts (setup-user-cursor, setup-user-mcp, setup-cursor-ide-mcp) — aligns with glossary-governed term |
| 2 | **Remove redundant inline summary block** from setup-user-cursor (.sh/.ps1) — was duplicating the end-of-run panel |
| 3 | **Fix 4 capability bypasses** in rules: `@reference/` to governed JSON replaced with skill references (frameworks.md, glossary.md, documentation-standards.md) |

### New features

| # | Change |
|---|--------|
| 4 | **Pre-commit step 15**: Deprecated summary terms — catches `"unchanged"` in `write_summary` calls |
| 5 | **Pre-commit step 16**: Capability bypass audit — catches `@reference/` to governed JSON in rules (Dennis & Van Horn 1966 capability model) |
| 6 | **Governed summary outcomes spec**: New section in `script-standards-detail.md` codifying governed vs deprecated summary detail values |

**Verified on:** macOS

---

## v0.57 -- Frameworks skill, governed data access, bug fixes #49/#50/#51 (2026-03-14)

### New features

| # | Change |
|---|--------|
| 1 | **`/frameworks` skill** (project-level): Read framework registry, add new adopted frameworks. Trigger directive in frameworks rule. |
| 2 | **Governed data access framework**: `reference/framework-governed-data-access.md` — pattern for registry access via skills instead of direct file reads. Three artifacts: skill, trigger directive, detection hook. |
| 3 | **Glossary detection hook**: `shared/hooks/glossary-skill-guard.sh` — fires on Read/Grep of glossary files, reminds agent to use /glossary skill. First governed data access hook. |

### Bug fixes

| # | Change |
|---|--------|
| 4 | **#49**: User repo template now includes `.gitignore` (`.scratch/`, `*.bak.*`, `.DS_Store`) |
| 5 | **#50**: User repo pull captures stderr via `2>&1` and logs via `log_detail` on failure (was `2>/dev/null`) |
| 6 | **#51**: Hook deployment migrated from bare `cp` to `deploy_managed_file` with interactive review, deploy tracking, and accept & adopt support |

### Improvements

| # | Change |
|---|--------|
| 7 | **Deployment outcome renames**: `unchanged`→`verified`, `adopted`/`merge-adopted`→`accept & adopt` across aitools-lib, setup-user-claude, setup-user-mcp, deploy tracker (8 files) |
| 8 | **Framework registry**: New governed-data-access framework entry |
| 9 | **Gap #24 filed**: No governed data access pattern for registry files |
| 10 | **Glossary**: 12 new governed terms (DTCC, discovery context, discipline, framework, etc.) |
| 11 | **Investigate skill**: Three-layer RCA check added |
| 12 | **Harness, adoption, three-layer governance docs**: Rule-skill governance, DTCC three-artifact requirement, three-layer completeness |

### Files created

| File | Purpose |
|------|---------|
| `.claude/skills/frameworks/SKILL.md` | Frameworks skill |
| `reference/framework-governed-data-access.md` | Governed data access framework doc |
| `shared/hooks/glossary-skill-guard.sh` | Glossary skill detection hook |

**Verified on:** macOS

---

## v0.56 -- Install audit findings, Auth0 platform plan (2026-03-14)

### Improvements

| # | Change |
|---|--------|
| 1 | **Gap #23 filed**: Credential storage undocumented; keychain prompts block `aitools install` (85s delay, 6-8 prompts on macOS for gh/pup). Linked to Auth0 roadmap item. |
| 2 | **3 GH issues filed**: User repo pull fails on untracked file conflicts (#49), user repo pull suppresses stderr (#50), hooks silently overwritten via bare cp (#51). Gap #1 linked to #51. |
| 3 | **Nobul Auth0 platform plan**: `plans/nobul-auth0-platform.md` — 5-phase plan for centralized credential management via Auth0 tenant (auth.nobul.tech). Phase 1: `aitools auth` CLI + GitHub device flow. Phases 2-5: multi-provider, token lifecycle, web apps (vcard/credits), RBAC. |
| 4 | **ROADMAP.md**: Auth0 platform added as high-priority planned item |

### Files created

| File | Purpose |
|------|---------|
| `plans/nobul-auth0-platform.md` | Auth0 platform implementation plan (5 phases) |

**Verified on:** macOS

---

## v0.55 -- Framework adoption infrastructure (2026-03-14)

### New features

| # | Change |
|---|--------|
| 1 | **Framework adoption lifecycle**: `reference/framework-adoption.md` — 9-step discovery-to-continuation cycle for adopting established discipline concepts into the harness |
| 2 | **Framework registry**: `reference/framework-registry.json` — structured source of truth for all adopted frameworks (8 frameworks: gap governance, source of truth, three-layer governance, tool lifecycle, managed file deployment, incident investigation, intent documentation, hook rollout) |
| 3 | **Harness architecture**: `reference/harness.md` — defines the 5 harness components (rules, references, skills, hooks, plans) and their relationships |
| 4 | **Governed vocabulary**: `reference/framework-governed-vocabulary.md` + `reference/glossary.json` + `/glossary` skill — base artifacts, scope modifiers, and composition convention for consistent terminology |
| 5 | **`/intent-writing` skill** (user-level): Draft intent statements with purpose/scope/audience structure |
| 6 | **`/intent-audit` skill** (user-level): Verify existing intent statements against file content |
| 7 | **`/glossary` skill** (project-level): Read governed vocabulary definitions, add new terms |

### Improvements

| # | Change |
|---|--------|
| 8 | **Gap governance enriched schema**: discovery context, discipline, frameworks, reference file fields added to known-gaps.json entries |
| 9 | **Frameworks rule** (`.claude/rules/frameworks.md`): Intent, registry of registries (frameworks, gaps, tools), three-layer pattern reference |
| 10 | **Glossary rule** (`.claude/rules/glossary.md`): Governed terms always in context, definitions via skill/JSON |
| 11 | **CLAUDE.md**: Three-layer registries design principle, document intent principle updates |
| 12 | **Gap #20 filed**: No process discipline rule governs plan adherence or deviations. Reference file: `reference/gap-020-process-discipline.md` |
| 13 | **Gap #21 filed**: Tool registry markdown needs migration to three-layer pattern |
| 14 | **Gap #22 filed**: Gap registry has no read/context skill |
| 15 | **8 framework reference files**: Per-framework documentation with discipline source, key concepts, and implementing artifacts |

### Files created

| File | Purpose |
|------|---------|
| `reference/framework-adoption.md` | Discovery-to-continuation lifecycle |
| `reference/framework-registry.json` | Framework registry (structured data) |
| `reference/harness.md` | Harness architecture (5 components) |
| `reference/framework-governed-vocabulary.md` | Vocabulary composition convention |
| `reference/glossary.json` | Governed vocabulary definitions |
| `reference/framework-gap-governance.md` [now: `framework-incident-governance.md`] | Gap governance framework doc |
| `reference/framework-source-of-truth.md` | Source of truth framework doc |
| `reference/framework-three-layer-governance.md` | Three-layer governance framework doc |
| `reference/framework-tool-lifecycle.md` | Tool lifecycle framework doc |
| `reference/framework-managed-file-deployment.md` | Managed file deployment framework doc |
| `reference/framework-incident-investigation.md` | Incident investigation framework doc |
| `reference/framework-intent-documentation.md` | Intent documentation framework doc |
| `reference/framework-hook-rollout.md` | Hook rollout framework doc |
| `reference/gap-020-process-discipline.md` [now: `incident-020-process-discipline.md`] | Gap #20 reference file |
| `.claude/skills/glossary/SKILL.md` | Glossary skill |
| `shared/skills/intent-writing/SKILL.md` | Intent writing skill |
| `shared/skills/intent-audit/SKILL.md` | Intent audit skill |

**Verified on:** macOS

---

## v0.54.1 -- Skill architecture, hook redesign, 12 gap filings (2026-03-13)

### New features

| # | Change |
|---|--------|
| 1 | **`/gap` skill** (project-level): File gaps/ambiguities to known-gaps.json with classification decision tree, severity assignment, protected file review gate. Model-invocable. |
| 2 | **`/audit` skill** (project-level): Deep governance review — cross-references, gap health, stale entries, TODO(gap) markers, skill coverage, plan consistency. User-invocable only. |
| 3 | **`/planning` skill** (user-level): Session flow, context budgets per model, batch sizing, subagent coordination, user-as-co-architect, decision evaluation criteria (state/context/leverage/risk/precedent/ambiguity). |
| 4 | **`/optimize-plan` skill** (user-level): Living plan review — stale sections, dependency graph, leverage map, scope assessment, context-window-aware depth. |
| 5 | **`/investigate` skill** (user-level): Full incident lifecycle with RCA (5 Whys, Swiss cheese model, timeline), barrier analysis for evaluating corrective actions, escalation framework. |

### Improvements

| # | Change |
|---|--------|
| 6 | **Plan file major revision**: 40 skills (32 user + 8 project), skill placement framework, SubagentStart pre-built cache, 20 foundational decisions, 7 hook specifications, exclusion criteria, telemetry architecture (SQLite + Datadog), barrier analysis methodology, dependency map design |
| 7 | **CLAUDE.md**: "End users are developers" principle (single/multi-platform), skill locations (user-level + project-level), project structure tree |
| 8 | **documentation-standards.md**: Skill placement section with user/project criteria, split threshold, no-override rule |
| 9 | **gap-governance.md**: Streamlined hook specs to reference plan, decisions-tracking pattern |
| 10 | **known-gaps.json**: 12 new gaps (IDs 6-17) |
| 11 | **UCI coaching**: "Suggest answers with questions" — 6-point evaluation criteria |
| 12 | **Session working convention**: 60-70% context budget, structured flow, resume-from markers |

### Files created

| File | Purpose |
|------|---------|
| `.claude/skills/gap/SKILL.md` [now: `incident/SKILL.md`] | Gap filing skill with tests |
| `.claude/skills/audit/SKILL.md` | Governance audit skill with tests |
| `shared/skills/planning/SKILL.md` | Session and plan strategy skill with tests |
| `shared/skills/optimize-plan/SKILL.md` | Living plan review skill with tests |
| `shared/skills/investigate/SKILL.md` | Incident lifecycle + RCA skill with tests |

**Verified on:** Windows

---

## v0.54 -- Governance and compliance framework (2026-03-13)

### New features

| # | Change |
|---|--------|
| 1 | **Design Principles** in CLAUDE.md: Three-layer governance (prevention/detection/audit), ambiguity-as-defect, full context over token budgeting, specs vs state, separate tool harnesses, skills as enablement |
| 2 | **`.claude/rules/gap-governance.md`** (NEW): Decision tree (gap vs ambiguity vs roadmap vs issue), severity scale, lifecycle (open/planned/closed), surfacing duty, staleness rule (90 days), `/gap` and `/audit` skill interface specs, SubagentStart and PreToolUse hook specs |
| 3 | **`reference/known-gaps.json`** (NEW): Migrated 5 existing gaps from markdown to structured JSON with severity, type, created/updated dates. Replaces `known-gaps.md`. |
| 4 | **`plans/governance-and-compliance-framework.md`** (NEW): Full implementation plan — 30 skills (15 managed tools + 3 dependencies + 3 build tools + 9 process/workflow), hook specifications, permission strategy, edge cases, verification steps |

### Improvements

| # | Change |
|---|--------|
| 5 | **Cursor rule parity killed**: Removed `cursor-rule-parity.md` rule. Claude Code and Cursor are separate tool harnesses managed independently — no parity requirement. |
| 6 | **`documentation-standards.md`**: Replaced cursor parity bullet with gap-governance cross-reference; updated `known-gaps.md` → `known-gaps.json` |
| 7 | **`sources-of-truth.md`**: Updated protected files table — `known-gaps.md` → `known-gaps.json` with governance rule reference |
| 8 | **`ROADMAP.md`**: Added governance & compliance framework entry linking to plan |

### Files created

| File | Purpose |
|------|---------|
| `.claude/rules/gap-governance.md` [now: `incident-governance.md`] | Gap/ambiguity governance rule — decision tree, lifecycle, skill/hook specs |
| `reference/known-gaps.json` [now: `incidents.json`] | Structured gap tracking (replaces known-gaps.md) |
| `plans/governance-and-compliance-framework.md` | Implementation plan for 30 skills, hooks, permissions |

### Files removed

| File | Reason |
|------|--------|
| `.claude/rules/cursor-rule-parity.md` | Replaced by "Separate tool harnesses" design principle |
| `reference/known-gaps.md` | Replaced by `reference/known-gaps.json` [now: `incidents.json`] |

**Verified on:** Windows

---

## v0.53 -- Close documentation gaps for managed file deployment (2026-03-13)

### Added

| # | Change |
|---|--------|
| 1 | **Mission statement** in CLAUDE.md: Cross-platform tool lifecycle management, configuration, and AI context orchestration |
| 2 | **`.claude/rules/managed-file-deployment.md`** (NEW): Deployment type definitions (markdown, JSON config, shell script), content sources, shared requirements, platform-specific config values |
| 3 | **`reference/known-gaps.md`** (NEW): Consolidated tracking of 5 known out-of-spec items — hook deployment, JSON backup parity, JSON interactive review, MCP disable scope, backup proliferation |
| 4 | **Layered reference architecture** in `documentation-standards.md`: Rules = concise directives, references = implementation detail, `@` link convention, function attribution without line numbers |
| 5 | **10 reference sections** appended to `reference/managed-file-deployment.md`: deployment types, content sources, platform-specific config values, shell script detail, JSON config review detail, diff mechanisms, AI-assisted merge detail, backup policy, env var deployment, auth file policy |
| 6 | **Cursor CLI config behavior** in `tool-registry.md`: managed fields table, MCP disable scope known issue, platform-specific MCP commands |
| 7 | **Perl PERLIO deployment** in `tool-registry.md`: build-time scope, PATH priority, Git Bash bundled perl behavior |
| 8 | **MCP server disable scope** in `tool-lifecycle.md`: per-project vs per-user asymmetry between Cursor CLI and Claude Code |
| 9 | **Deployment pattern updates** in `tool-lifecycle.md`: new onboarding checklist bullet for deployment types table |
| 10 | **JSON field-level review** in `interactive-menus.md`: review display, menu options, adopt rules for JSON config deployments |

### Changed

| # | Change |
|---|--------|
| 11 | **Backup section** in `config-file-safety.md`: now mandates per deployment type (internal for text, caller for JSON), cross-refs deployment rule |
| 12 | **`@` consistency**: ~44 cross-reference paths standardized across 8 rules files to use `@` prefix convention |
| 13 | **Cursor parity**: new `managed-file-deployment.mdc`, extended `tool-lifecycle.mdc` (+4 sections), `config-file-safety.mdc` (backup), `documentation-standards.mdc` (+3 sections) |
| 14 | **Sources-of-truth**: added `managed-file-deployment.md` and `known-gaps.md` to protected files table |
| 15 | **Cursor CLI Windows version**: updated from `pending` to `2026.03.11-6dfa30c` in tool-registry.md |
| 16 | **Datadog Pup Windows version**: updated to `0.31.0` in tool-versions.json |

### Files created

| File | Purpose |
|------|---------|
| `.claude/rules/managed-file-deployment.md` | Deployment type definitions, content sources, platform config rules |
| `.cursor/rules/managed-file-deployment.mdc` | Cursor parity for above |
| `reference/known-gaps.md` [now: `incidents.json`] | Known out-of-spec code tracking |

**Verified on:** Windows

---

## v0.52.8 -- Fix deploy/ drift, Strawberry Perl PERLIO, cross-platform.md slim-down (2026-03-13)

### Fixed

| # | Change |
|---|--------|
| 1 | **Step 7 deploy/ drift (FAIL → PASS)**: `check-lib.ps1` prepends Strawberry Perl to PATH; when Step 7 spawned `build-deploy.sh` from that context, Strawberry Perl's `:crlf` text mode doubled CR in `extract_between --crlf` output (`\r\r\n`). Fix: `export PERLIO=:perlio` near top of `build-deploy.sh` — disables CRLF layer, matching Git perl. Removed redundant `binmode ARGVOUT` from final CRLF conversion. |

### Changed

| # | Change |
|---|--------|
| 2 | **`cross-platform.md` slim-down** (214 → 112 lines): Moved gotcha details, code examples, and explanatory prose to new `reference/cross-platform-detail.md`. Consolidated 6 separate gotcha sections into single "Windows platform gotchas" bullet list with `@reference` pointer. All inbound section heading references preserved. |
| 3 | **Cursor rule parity**: Updated `.cursor/rules/cross-platform.mdc` with Strawberry Perl text mode gotcha. |
| 4 | **Tool registry/versions**: Added Platform Gotchas subsection to Perl entry in `tool-registry.md`. Added PERLIO note to `tool-versions.json`. |

(tested: Windows)

---

## v0.52.7 -- OS guard standardization, init-logging, dead code cleanup (2026-03-13)

### Added

| # | Change |
|---|--------|
| 1 | **`init-logging.sh/.ps1`**: New sourced libraries that auto-detect the caller and initialize structured logging. Sourced before the OS guard so guards can use `log_error`/`LogError` for Datadog-parseable error messages. |
| 2 | **PSO: Fail, don't mask**: New standing order -- never mask broken states with fallbacks. Surface failures via structured logging; remediate root cause. |
| 3 | **OS guard patterns** in `cross-platform.md`: Canonical copyable guard patterns, exemptions table, dead code rule. |
| 4 | **OS guard logging convention** in `script-standards-detail.md`: Rationale for structured logging in guards (Datadog observability). |
| 5 | **Git Bash PATH shadowing** documentation in `cross-platform.md`: Documents how Git's bundled tools shadow managed installs when Git Bash spawns pwsh. |
| 6 | **Check script block order** in `script-standards.md`: Documented the init-logging double-init pattern for check scripts. |
| 7 | **Windows tool versions**: Populated `tool-versions.json` for 13 tools previously null on Windows. |

### Fixed

| # | Change |
|---|--------|
| 8 | **4 PS1 check scripts used `$IsMacOS` guard**: Missed Linux. Changed to `-not $IsWindows` (catches macOS AND Linux). |
| 9 | **10 check scripts used raw output in guards**: `Write-Host`/`echo` replaced with `LogError`/`log_error` via init-logging. |
| 10 | **Git Bash PATH shadowing in `check-lib.ps1`**: Removed blanket Git `usr/bin` PATH prepend. Now explicitly prepends managed Strawberry Perl directory, ensuring it takes priority over Git's bundled perl (5.38.2 vs 5.42.0). |
| 11 | **`Initialize-Logging` wrong Linux path**: macOS path (`~/Library/Logs/aitools`) was used for Linux. Added 3-way platform split: Windows (`$LOCALAPPDATA`), macOS (`~/Library/Logs`), Linux (XDG_STATE_HOME). |
| 12 | **Step 21 hardcoded `macos` platform key**: Now uses `platform.system()` for dynamic detection. Works on Windows and Linux. |

### Removed

| # | Change |
|---|--------|
| 13 | **Dead `$IS_WINDOWS` branches** in `check-pre-commit.sh` (step 2) and `check-post-push.sh` (step 6): OS guard exits on Windows, so `elif $IS_WINDOWS` branches with `cygpath` were unreachable. Also removed `if $IS_MACOS` wrapper -- replaced with `require_pwsh` (works on macOS AND Linux). |
| 14 | **Dead `$IsMacOS`/`$IsLinux` branches** in `check-post-push.ps1`: Platform key and python command simplified from 3-way conditional to constants (OS guard ensures Windows-only). |

### Changed

| # | Change |
|---|--------|
| 15 | **Bridge pattern docs**: Updated `script-standards-detail.md` -- double-init is safe and deterministic, not fragile. |
| 16 | **CC version**: Updated `claude-code-maintenance.md` from 2.1.70 to 2.1.74. |
| 17 | **Cursor rule parity**: Updated `cross-platform.mdc` and `script-standards.mdc` with guard patterns, check script block order, PATH shadowing. |

(tested: Windows)

---

## v0.52.6 -- Post-integration fixes (2026-03-12)

### Fixed

| # | Change |
|---|--------|
| 1 | **deploy/setup-perl.sh missing +x bit (#46)**: `build-deploy.sh` sets filesystem `chmod +x` but didn't update git index. Fixed with `git update-index --chmod=+x`. |
| 2 | **Perl missing from version command dictionaries (#46)**: Added `perl --version` to `$toolCmds`/`TOOL_CMDS` in check-post-push scripts. Onboarding checklist amended to prevent recurrence. |
| 3 | **`skipped` return value unhandled (#47)**: setup-user-mcp skills loop and setup-user-claude rules loop now explicitly handle `skipped`/`unchanged` per return value contract. |
| 4 | **Step 31 over-broad extraction (#48)**: Rewrote perl regexes with flip-flop operator to scope extraction to target functions (`Deploy-ManagedFile`, `Record-DeployOutcome`) instead of entire lib files. |

### Changed

| # | Change |
|---|--------|
| 5 | **interactive-menus.md**: Clarified return value contract as per-call-site (not per-file). Documented step 30 file-level limitation. |
| 6 | **tool-lifecycle.md**: Added check-post-push version command dictionaries to onboarding checklist. |

(tested: Windows)

---

## v0.52.5 -- Refresh-Path fix, managed Perl lifecycle (2026-03-12)

### Fixed

| # | Change |
|---|--------|
| 1 | **Refresh-Path drops runtime PATH entries (#45)**: Changed from destructive replace to additive merge -- preserves entries inherited from parent process and added by `Ensure-ToolOnPath`. All 33 callers benefit. |
| 2 | **check-lib.ps1 Git tools PATH**: Explicitly add Git's `usr/bin` to PATH at init as safety net for bundled tools. |

### Added

| # | Change |
|---|--------|
| 3 | **Perl as managed tool**: Full lifecycle -- setup-perl.ps1/.sh, installer integration, build pipeline, tool-registry entry. Replaces fragile dependency on Git for Windows bundled perl. |
| 4 | **Bundled dependencies** section in `.claude/rules/tool-lifecycle.md`: defines graduation path for tools that ship inside other tools. |
| 5 | **Refresh-Path documentation** in `.claude/rules/cross-platform.md`. |

### Platform testing

- Windows: tested
- macOS: not tested (PS1-only changes; bash unaffected)

---

## v0.52.4 -- Merge UX fixes + deployment flow documentation (2026-03-12)

### Fixed

| # | Change |
|---|--------|
| 1 | **Merge preview encoding (#42, PS1)**: `Try-AutoMerge` now uses in-place `git merge-file` + `[IO.File]::ReadAllText` instead of pipeline capture through OEM codepage -- fixes Unicode mojibake (em-dash, arrows) on Windows. |
| 2 | **Trailing blank lines (#43)**: Normalize trailing whitespace in `Deploy-ManagedFile` / `deploy_managed_file` before content comparison -- prevents false diffs on every deploy-adopt-deploy cycle. |
| 3 | **Auto-merge menu (#44)**: Replace separate `[y]es` + `[a]dopt` with single `[a]ccept` that deploys merge AND updates profile. New return value `merge-adopt` / `merge-adopted` handled by all callers. |

### Added

| # | Change |
|---|--------|
| 4 | **Deployment flow documentation**: New rule `.claude/rules/interactive-menus.md`, new reference `reference/managed-file-deployment.md` (full state machine spec), new cursor rule `.cursor/rules/interactive-menus.mdc`. Cross-references added to `script-standards.md`, `config-file-safety.md`, `sources-of-truth.md`, `cursor-practices.md`, `post-push-checklist.md`. |
| 5 | **Check steps 29-31** (post-push): menu parity audit, return value coverage audit, deployment state machine sync. |

### Platform testing

- Windows: tested
- macOS: not tested (bash syntax validated, PS1 encoding fix is Windows-only)

## v0.52.3 -- Auto-merge engine swap, NASM detection, pup messaging, log locking (2026-03-12)

### Fixed

| # | Change |
|---|--------|
| 1 | **Merge engine (#38, CRITICAL)**: Replace `diff3` with `git merge-file -p` -- `Find-Diff3` computed wrong path on Windows (2 levels up instead of 3), so 3-way merge never worked. Rename to implementation-agnostic names (`try_auto_merge`/`Try-AutoMerge`). |
| 2 | **NASM detection (#39)**: Check known install paths before declaring "not found" -- winget user-scope install at `%LOCALAPPDATA%\bin\NASM\` not on session PATH. |
| 3 | **Pup messaging (#40)**: Compare version before/after `cargo install` -- show "already up to date" instead of "upgraded" when unchanged. |
| 4 | **Log file locking (#41)**: Replace `Add-Content` with `[IO.File]::AppendAllText()` in PS1 logging -- prevents exclusive lock contention between concurrent `aitools` instances. |

### Platform testing

- Windows: tested
- macOS: not tested (tested: Windows)

---

## v0.52.2 -- Fix pre-pull checkout data loss, resume merge fixes (2026-03-12)

### Fixed

| # | Change |
|---|--------|
| 1 | **Pre-pull checkout (#37)**: Remove `scripts/` from `git checkout HEAD --` in entry points -- was silently destroying uncommitted source files. Root cause: `build-deploy.sh` chmod on `scripts/*.sh` created mode noise, checkout cleared noise + real work. |
| 2 | **Build chmod**: Remove `scripts/` from `chmod +x` in `build-deploy.sh` -- eliminates the mode noise source. |
| 3 | **Error severity (#34)**: `log_warn` -> `log_error` for AI merge failure (user-requested operation). |
| 4 | **Start telemetry (#36)**: Add invocation start log line before CLI call in `invoke_ai`/`Invoke-AI` retry loop. |
| 5 | **Shadow bootstrap (#32)**: Seed deploy shadow from existing content when empty -- enables auto-merge for pre-existing files. |
| 6 | **Prompt fences (#33)**: ALL-CAPS anti-fence rule + defense-in-depth stripping of code fences from AI output. |
| 7 | **Spinner + transparency (#35)**: Show backend/tier/filename before AI merge; animated spinner during invocation. |

### Added

| # | Change |
|---|--------|
| 8 | **git-safety rule**: `.claude/rules/git-safety.md` + Cursor parity -- codifies deploy/ ephemeral, scripts/ never-reset. |
| 9 | **User-facing AI standards**: New section in agentic-standards rule (transparency, progress, failure severity). |
| 10 | **CLAUDE.md**: deploy/ lifecycle added to Key Decisions. |

### Platform testing

- Windows: tested
- macOS: not tested (tested: Windows)

Closes #32, #33, #34, #35, #36, #37

---

## v0.52.1 -- Fix post-push check false positives (steps 26, 27) (2026-03-12)

### Fixed

| # | Change |
|---|--------|
| 1 | **Step 26 PS1**: Replace `-replace` chain with Perl extraction -- fixes false-positive WARN from ordering bug (`.sh$` stripped before parenthetical suffix). |
| 2 | **Step 26 both**: Add `setup-user-X` → `-X` abbreviation matching (was only stripping `setup-`). |
| 3 | **Step 27 both**: Delegate to `Check-BuildPrereqs`/`check_build_prereqs` framework instead of bare `Get-Command`/`command -v` -- gets KnownPaths fallback, architecture filtering, correct install instructions from single source of truth. |
| 4 | **pre-update command**: Add build prerequisite failure mode to known failures table; recommend `aitools install` when prereqs missing. |

---

## v0.52.0 -- Agentic framework, merge overhaul, clip2md refactor (2026-03-12)

### Added

| # | Change |
|---|--------|
| 1 | **`invoke_ai` / `Invoke-AI`**: Generalized AI invocation in aitools-lib. Multiple backends (claude/agent CLI), speed tiers (fast/balanced/quality), permission tiers (none/readonly/full/dangerous), validation callbacks, automatic retry, telemetry logging. |
| 2 | **Agentic standards rule**: `.claude/rules/agentic-standards.md` -- prompt design pattern (Role/Context/Task/Constraints/Format), evaluation lifecycle, speed/permission governance. |
| 3 | **Agentic framework reference**: `reference/agentic-framework.md` -- detailed spec. |
| 4 | **Merge prompt overhaul**: Context-rich prompt with file descriptions, deploy semantics, unified diff. AI applies diff to local instead of rewriting. |
| 5 | **RFC-0002**: aitools / nobul-ops coordination principles. |

### Changed

| # | Change |
|---|--------|
| 6 | **Check 5 validation**: Header preservation (60% threshold) replaces verbatim line matching. |
| 7 | **Merge speed**: sonnet (balanced) instead of default opus. |
| 8 | **Merge errors**: User-friendly messages ("rewrote too much" vs "structural overlap"). |
| 9 | **clip2md**: Opportunistic `invoke_ai fast` (haiku/auto). `--no-session-persistence` added. |

### Notes

- Agent CLI (Cursor): `--model auto` default for all speed tiers (account limitation). Speed via prompt hints only.

### Platform testing

- Windows: tested
- macOS: not tested (tested: Windows)

---

## v0.51.0 -- Install method discovery process, fix AI merge validation (2026-03-12)

Closes #25, #26, #27.

### Fixed

| # | Change |
|---|--------|
| 1 | **AI merge validation false positive** (#25): Check 3 matched bare keywords ("permission") in CLAUDE.md content. Replaced with sentence-level conversational-refusal patterns. |
| 2 | **Rejected AI merge output wall of text** (#27): Multi-KB content dumped to console as single line. Now uses `LogDetail`/`log_detail` (file-only) per line. |

### Changed

| # | Change |
|---|--------|
| 3 | **CMake prereq: uv tool instead of winget** (#26): Changed from `winget install Kitware.CMake` (needs admin) to `uv tool install cmake` (user-level, installs to `~/.local/bin`). Decision based on cmake.org/download which lists pip as an official method (winget not mentioned). PyPI package maintained by Kitware. `uv tool` preferred over `uv pip` because it installs to a PATH-included directory. |
| 4 | **CMake auto-install in setup-datadog**: When CMake missing, attempts `uv tool install cmake` before falling back to ACTION item. |

### Added

| # | Change |
|---|--------|
| 5 | **Install method discovery process**: New rule section in `tool-lifecycle.md` + detailed playbook (`reference/tool-evaluation-playbook.md`). Requires reading official tool documentation, evaluating install methods against criteria, trial installation, and documenting rationale. Applies to managed tools AND build prerequisites. |
| 6 | **`log_detail` / `LogDetail`**: File-only structured logging for diagnostic content. |
| 7 | **AI merge progress message**: "merging via AI (this may take 30-60s)..." |
| 8 | **`Test-IsAdmin` helper**: Admin detection for future elevation framework. |

### Platform testing

- Windows: tested (CMake trial install, AI merge regression test)
- macOS: not tested (tested: Windows)

---

## v0.50.2 -- Fix AI merge prompt corruption (2026-03-11)

Closes #24.

### Fixed

| # | Change |
|---|--------|
| 1 | **AI merge prompt corruption** (#24): `_invoke_ai_merge` / `Invoke-AiMerge` referenced temp file paths in prompts instead of inlining content. Claude CLI with `--allowedTools ""` couldn't read the files, responded conversationally, and the response was written to disk as "merged" content. Prompt now inlines all content using XML delimiters (`<SOURCE>`, `<LOCAL>`). |

### Added

| # | Change |
|---|--------|
| 2 | **AI merge output validation**: `validate_ai_merge_output` (bash) / `Test-AiMergeOutput` (PS1) rejects conversational text, code fences, permission language, truncated output, and content with no structural overlap. |
| 3 | **AI merge refinement loop**: after merge preview, user can `[r]efine` with feedback for iterative improvement, or `[y]es` accept / `[n]o` reject. |
| 4 | **Merge write-back**: accepted merges sync to dotprofile repo with auto commit/push. |
| 5 | **Agentic prompt patterns doc**: `reference/agentic-prompt-patterns.md` documents safe `claude -p` usage in aitools scripts. |

### Platform testing

- macOS: tested
- Windows: not tested (tested: macOS)

## v0.50.1 -- Fix NASM detection, deploy UX overhaul (2026-03-11)

Closes #22, #23.

### Fixed

| # | Change |
|---|--------|
| 1 | **NASM KnownPaths corrected** (#22): winget NASM.NASM installs to `%LOCALAPPDATA%\bin\NASM\`, not `C:\Program Files\NASM\`. Primary path updated; Program Files kept as secondary. |
| 2 | **CMake paths marked UNVERIFIED**: documented as assumed, pending empirical verification. |
| 10 | **check-prereq-detection step 6 crash**: `CheckLogInit`/`check_log_init` didn't initialize aitools-lib logging vars (`logFile`/`LOG_FILE`, etc.), so lib functions called from check steps (e.g., `Check-BuildPrereqs` → `Ensure-ToolOnPath` → `Log`) threw null-path errors under strict mode. Fixed with a bridge pattern in both check-lib files. |

### Changed

| # | Change |
|---|--------|
| 3 | **Deploy state tracking**: new manifest + shadow system eliminates unnecessary prompts. Auto-deploys when user hasn't edited the local file (handles profile.json interpolation changes silently). |
| 4 | **Deploy diff review UX** (#23): lowercase options, directional labels (`source wins -> local`, `local wins -> profile`), context header, clear outcome messages. |
| 5 | **Non-agentic merge** via `diff3`: automatic 3-way merge using deploy shadow as common ancestor. Clean merges shown for confirmation; conflicts fall through to AI merge. |
| 6 | **AI merge** via `claude -p`: agentic fallback with preview and confirmation. Falls back gracefully if claude CLI unavailable. |

### Added

| # | Change |
|---|--------|
| 7 | **KnownPaths empirical verification rule**: new rule requiring all KnownPaths to be verified on actual machines. Applies to tools AND build dependencies. |
| 8 | **check-prereq-detection steps 10-12** (PS1) / **9-10** (bash): empirical path verification, tool-registry cross-reference, verification status audit. |
| 9 | **check-post-push**: deploy state integrity step (manifest/shadow consistency). |
| 11 | **Logging architecture documented**: new section in `script-standards-detail.md` describing setup vs check vs build logging systems and the bridge pattern. Rules updated in `.claude/rules/` and `.cursor/rules/`. |

### Verified

- Windows: all changes tested (tested: Windows)
- macOS: bash changes not tested (tested: Windows)

---

## v0.50.0 -- Fix build prerequisite detection false negatives (2026-03-11)

Closes #20.

### Added

| # | Change |
|---|--------|
| 1 | **`Ensure-ToolOnPath` / `ensure_tool_on_path`**: New reusable lib functions with 3-step detection: PATH check, registry/cache refresh (`Refresh-Path` / `hash -r`), known filesystem paths fallback with session PATH update. |
| 2 | **`KnownPaths` + `ToolName` fields** on `$script:BuildPrereqs` entries (PS1): enables `Check-BuildPrereqs` to fall back to filesystem detection when `Get-Command` fails. |
| 3 | **`check-prereq-detection.ps1` / `.sh`**: New check script pair verifying KnownPaths coverage, function availability, and consumer script integration. |

### Fixed

| # | Change |
|---|--------|
| 4 | **NASM false negative in setup-datadog** (#20): `Check-BuildPrereqs` now falls back to known install paths when `Get-Command` / `command -v` fails (tool installed but not on PATH in current session). |
| 5 | **setup-rust.ps1 "restart terminal" eliminated**: After NASM install, uses `Ensure-ToolOnPath` to find NASM at known locations and add to session PATH instead of giving up with a restart warning. |
| 6 | **setup-datadog belt-and-suspenders**: Both `.ps1` and `.sh` now call `Refresh-Path` / `hash -r` before `Check-BuildPrereqs` to pick up tools installed by earlier steps in the same session. |

### Verified

- Windows: all changes tested (syntax, check-prereq-detection 9/9 PASS, check-pre-commit 0 FAIL)
- macOS: not tested -- `ensure_tool_on_path` (bash) and `check-prereq-detection.sh` need verification (tested: Windows)

---

## v0.49.0 -- Centralize diff review deploy flow into lib functions (2026-03-11)

### Added

| # | Change |
|---|--------|
| 1 | **`deploy_managed_file` / `Deploy-ManagedFile`**: New lib function centralizing the full compare→backup→prompt→write flow for managed file deployment. Callers handle adopt action (varies by file type). Available in all deploy scripts via build-time inlining. |
| 2 | **Deploy tracker functions**: `deploy_tracker_init/record/summary` (bash) and `Initialize-DeployTracker/Record-DeployOutcome/Write-DeployTrackerSummary` (PS1) centralize outcome counting and aggregate summary writing for deploy loops. |
| 3 | **ARIA Live Regions audit step**: Added section 8 to `a11y-debugging/SKILL.md` covering `aria-live`, `role="alert"`, `role="status"` verification. |

### Changed

| # | Change |
|---|--------|
| 4 | **setup-user-claude refactored**: CLAUDE.md deploy and rules deploy loop now use `deploy_managed_file` and deploy tracker instead of inline diff/backup/write logic. Reduces code duplication and ensures consistent summary reporting. |
| 5 | **setup-user-mcp skills refactored**: `deploy_skill` / `Deploy-Skill` now delegates to `deploy_managed_file`. Deploy loops use tracker for granular outcome summaries (e.g., "1 added, 1 unchanged" instead of just "deployed"). |
| 6 | **build-deploy.sh skills refactored**: `deploy_embedded_skill` / `Deploy-EmbeddedSkill` in generated deploy scripts use `deploy_managed_file` and deploy tracker. |
| 7 | **Sentinel regex relaxed**: `build-deploy.sh` `extract_between` patterns for post-write validation now use `\s*` instead of fixed 4-space indent, accommodating refactored code structure. |

### Fixed

| # | Change |
|---|--------|
| 8 | **Adopt missing from summary**: Rules and skills adopt now emits `write_summary DETAIL` lines and includes adopted count in aggregate summary (was silently omitted). |
| 9 | **Case inconsistency fully fixed**: Diff review prompt hint now `[A/O/S/X]` (all uppercase). v0.48.1 partially fixed to `[A/O/s/x]` — this completes the fix. |
| 10 | **created/added mismatch**: Deploy tracker now accepts both `"created"` and `"added"` as outcomes, preventing silent count misses for newly created files. |
| 11 | **Tracker text ordering**: `deploy_tracker_summary` now called before the log line that uses `DEPLOY_TRACKER_TEXT`, fixing empty tracker text in rules summary output. |

**Verified on:** macOS (syntax validation, build 30/30, pre-commit 0 FAIL, dry-run smoke tests). Windows: not tested (PS1 syntax validated).

---

## v0.48.1 -- Fix adopt clobber, case inconsistency, add accordion skill (2026-03-11)

### Fixed

| # | Change |
|---|--------|
| 1 | **Sequential adopt clobber bug**: When a skill was adopted from `~/.claude/skills/` to `shared/`, the subsequent deploy to `~/.cursor/skills/` saw a reversed diff and a second adopt would overwrite `shared/` with the old content. Fix: after adopt, sync the adopted content to all other deploy targets so the next loop sees no diff. |
| 2 | **Prompt case inconsistency**: Diff review prompt showed `[A]dopt` but hint showed `[a/O/s/x]`. Now consistent: `[A/O/s/x]`. |

### Added

| # | Change |
|---|--------|
| 3 | **Accordion skill content**: Restored "Expanding accordions, tabs, and FAQs" section to `chrome-devtools/SKILL.md` (lost during a previous deploy overwrite). Documents the pattern for extracting content from JS-rendered collapsible elements. |

**Verified on:** macOS (syntax validation, build, functional test of adopt flow). Windows: not tested (PS1 syntax validated).

---

## v0.48.0 -- Build prerequisite validation framework (2026-03-10)

### Added

| # | Change |
|---|--------|
| 1 | **Two-layer build prerequisite framework**: Layer 1 (preventive) checks known prerequisites before source builds via `Check-BuildPrereqs`/`check_build_prereqs` in aitools-lib. Layer 2 (reactive) diagnoses build failures via `Diagnose-BuildFailure`/`diagnose_build_failure` by scanning output for known error signatures. Both use centralized data tables — adding a new prerequisite = one table entry. |
| 2 | **NASM auto-install in setup-rust.ps1**: Detects missing NASM (required by `aws-lc-sys` crypto crates) and installs via `winget install NASM.NASM`. Fixes `aitools install` failing at Step 18 (pup) with `NASM command not found! Build cannot continue.` after 2 min of wasted compilation. |
| 3 | **setup-datadog.ps1 prereq gate**: Calls `Check-BuildPrereqs "cargo"` before any cargo build. Missing prerequisites (MSVC, NASM, CMake) produce `ERROR` + `ACTION` summary lines and skip the build entirely. Both cargo failure blocks (upgrade + fresh install) now call `Diagnose-BuildFailure` for targeted remediation. |
| 4 | **setup-datadog.sh cargo fallback diagnosis**: Cargo install fallback path now checks prerequisites before build and diagnoses failures with known signatures. |
| 5 | **Pre-commit check step 14**: "Build prereq framework" audit verifies all setup scripts using `cargo install` reference the framework functions. |
| 6 | **Post-push check step 27**: "Build prerequisites installed" verifies NASM and CMake are present on the current machine when cargo is installed. |
| 7 | **Script standards update**: New "Build prerequisite validation" section in `.claude/rules/script-standards.md` and `.cursor/rules/script-standards.mdc`. Canonical patterns and "Adding a new build prerequisite" process in `reference/script-standards-detail.md`. |

**Verified on:** Windows (syntax validation, pre-commit step 14 pass, NASM install + setup-rust smoke test). macOS: not tested.

**Closes:** #19

---

## v0.47.1 -- Fix /dev/tty non-interactive detection on macOS (2026-03-09)

### Fixed

| # | Change |
|---|--------|
| 1 | **Non-interactive detection**: `[ -c /dev/tty ]` passes on macOS even without a controlling terminal (device exists but is "not configured", causing `set -e` abort). Replaced with actual write test: `(printf '' > /dev/tty) 2>/dev/null`. |

**Verified on:** macOS (non-interactive auto-overwrite, --force, dry-run all pass). Windows: not tested.

---

## v0.47.0 -- Diff review + adopt for managed file deployment (2026-03-09)

### Added

| # | Change |
|---|--------|
| 1 | **Diff review before overwrite**: When `aitools` deploys a managed text file (`~/.claude/CLAUDE.md`, rules, skills) and the deployed file differs from source, shows a unified diff and prompts: **Adopt** (merge local edits back to source), **Overwrite** (backup + deploy), **Skip** (keep local), or **Abort**. Non-interactive and `--force` mode auto-overwrite (preserves current behavior). |
| 2 | **Adopt to profile**: CLAUDE.md adopt strips the Machine-Specific footer and reverse-tokenizes `{{PLACEHOLDER}}` values back into the dotprofile template. Rules adopt copies the deployed file verbatim to the user repo. |
| 3 | **Adopt to shared/**: Skills adopt copies the deployed SKILL.md back to `shared/skills/` in the aitools repo, so local session edits survive future deploys. |
| 4 | **`--force` flag**: `aitools --force` / `aitools install --force` skips all diff-review prompts and overwrites unconditionally. Passed through as `AITOOLS_FORCE=1` to child scripts. |
| 5 | **`prompt_diff_review` / `Prompt-DiffReview` library functions**: New helpers in `aitools-lib.sh/.ps1` for interactive diff review with `/dev/tty` (bash) and `[Console]` (PS1) I/O to bypass deploy_configs redirection. |
| 6 | **Deploy script diff review**: Self-contained deploy scripts (MDM) now include `deploy_embedded_skill()` / `Deploy-EmbeddedSkill` helper functions with the same diff-review pattern. Uses temp files for bash 3.2 compatibility. |
| 7 | **DD_SITE env var**: Shell aliases now export `DD_SITE=us5.datadoghq.com` for Datadog CLI region selection. |

**Verified on:** macOS (syntax validation, build 30/30, dry-run smoke tests pass). Windows: not tested.

---

## v0.46.0 -- Add post-install auth check pattern, pup auth status (2026-03-06)

### Added

| # | Change |
|---|--------|
| 1 | **Post-install auth check standard**: New script-standards section requiring setup scripts to check auth status on every run (not just fresh install). Three patterns documented: command exit code, command output content, and config file presence. |
| 2 | **Pup auth documentation**: `reference/tool-registry.md` now has full Authentication section for Datadog CLI — commands, token storage locations, auth priority, agent mode. |
| 3 | **Tool onboarding checklist**: Auth check step added to both `.claude/rules/tool-lifecycle.md` and `.cursor/rules/tool-lifecycle.mdc` — tools requiring auth must implement the check and document auth commands. |

### Fixed

| # | Change |
|---|--------|
| 1 | **Pup auth check on every run**: `setup-datadog.sh/.ps1` now checks `pup auth status` output on every run, not just fresh installs. Shows WARN + ACTION in summary panel when not authenticated. |
| 2 | **Pup auth status exit code**: `pup auth status` always exits 0 regardless of auth state — scripts check output content (`Not authenticated` / `"authenticated": false`) instead of exit code. |

**Verified on:** Windows (syntax validation, build 30/30, smoke test confirms auth warning fires). macOS: not tested.

---

## v0.45.2 -- Fix write_summary OK ignoring WARNINGS counter (2026-03-06)

### Fixed

| # | Change |
|---|--------|
| 1 | **write_summary OK ignores warnings**: When a setup script called `log_warn` (incrementing `$WARNINGS`) but ended with `write_summary OK`, the summary panel showed `[ok]` (green) instead of `[!]` (yellow). Triggered on `aitools install` first run — Datadog old-tap migration logged `[warn]` but summary showed `[ok] datadog cli`. |
| 2 | **Library-level auto-promotion**: `write_summary` / `Write-Summary` in `aitools-lib.sh/.ps1` now auto-promotes `OK` → `WARN` when `$WARNINGS > 0`. Fixes all 106 call sites across 33 files — no call-site changes needed. |
| 3 | **Compliance guard**: New step 13 in `check-script-compliance.sh/.ps1` verifies the auto-promotion logic exists in both libs, preventing regression. |

**Verified on:** macOS (compliance check 13/13 PASS, deploy rebuild clean). Windows: not tested.

---

## v0.45.1 -- Fix git pull failure from build artifacts (line endings, file modes) (2026-03-06)

### Fixed

| # | Change |
|---|--------|
| 1 | **git pull blocked by stale build artifacts**: `aitools install` step [1/3] failed with "local changes would be overwritten by merge" when `deploy/*.ps1` had LF (should be CRLF per `.gitattributes`) or `scripts/*.sh` lost executable bit (Write tool creates 100644, `git update-index --chmod=+x` only fixes index). |
| 2 | **build-deploy.sh post-build fixup**: New step after PS1 validation — `chmod +x` all `.sh` files in `deploy/` and `scripts/`, CRLF conversion for all `deploy/*.ps1`. Prevents drift at source. |
| 3 | **Pre-pull checkout expanded**: `git checkout HEAD -- deploy/ scripts/` (was `deploy/` only) in both `aitools` and `aitools.ps1`. Defense-in-depth for any remaining drift. |

**Verified on:** macOS (build-deploy pass, previously dirty files now clean). Windows: not tested.

---

## v0.45.0 -- Fix Datadog CLI install, add long paths + install verification gate (2026-03-06)

### Fixed

| # | Change |
|---|--------|
| 1 | **Datadog CLI install broken**: Pup was rewritten from Go to Rust (circa v0.24+). `go install github.com/DataDog/pup@latest` no longer works. macOS: fixed Homebrew tap `datadog/pack` -> `datadog-labs/pack`, added old-tap migration. Windows: replaced `go install` with `cargo install --git`. |
| 2 | **Install error output silently dropped**: `setup-datadog.ps1` captured `$goOutput` but never logged it on failure. Now logs cargo output on error. |

### Added

| # | Change |
|---|--------|
| 1 | **Windows long path support** (Step 0 in `aitools-install.ps1`): Checks `LongPathsEnabled` registry key, emits ACTION if disabled. Sets `git config --global core.longpaths true` automatically. Required for cargo builds with deep dependency trees. |
| 2 | **Install command verification gate**: New rule in `tool-lifecycle.md/.mdc` requiring Chrome DevTools MCP verification of upstream install methods before writing/modifying any setup script. Applies to new onboarding, script modifications, and RCA. |

### Changed

| # | Change |
|---|--------|
| 1 | **tool-registry.md**: Datadog CLI install table updated -- Homebrew `datadog-labs/pack/pup` (macOS), `cargo install --git` (Windows). Added Rust rewrite note, verification date. |
| 2 | **tool-versions.json**: Updated datadog-pup notes to reflect Rust-based CLI and correct tap. |
| 3 | **Onboarding checklist**: New "Prerequisite" step requires upstream install verification via chrome-devtools before writing setup scripts. |

**Verified on:** Windows (smoke test: Pup 0.26.0 installed via cargo, long path check works). macOS: not tested (Homebrew tap change, old-tap migration).

---

## v0.44.0 -- Add Datadog CLI (pup) as managed tool (2026-03-06)

### Added

| # | Change |
|---|--------|
| 1 | **Datadog CLI (pup) managed tool**: New `setup-datadog.sh` (Homebrew tap `datadog/pack`) and `setup-datadog.ps1` (`go install`) setup scripts. Emits ACTION summary for `pup auth login` on fresh install. |
| 2 | **Version check completeness**: Added `python`, `uv`, `go`, `datadog-pup` to `check-post-push` TOOL_CMDS -- eliminates "SKIP: no version command defined" for these tools. |

### Changed

| # | Change |
|---|--------|
| 1 | **Installer step 18**: Datadog CLI runs after Go (step 17), deploy configurations renumbered to step 19. |
| 2 | **Build-deploy**: Generates `deploy/setup-datadog.sh/.ps1` (steps 25-26), user-mcp renumbered to 27-28. |
| 3 | **Tool name table**: Added `go`, `datadog cli`, `cursor cli` to `script-standards-detail.md`. |
| 4 | **Tool versions**: Updated `go` (1.26.1) and `datadog-pup` (0.26.0) macOS verified versions. |

### New files

| File | Purpose |
|------|---------|
| `scripts/setup-datadog.sh` | macOS Pup setup via Homebrew tap |
| `scripts/setup-datadog.ps1` | Windows Pup setup via go install |
| `deploy/setup-datadog.sh` | Self-contained deploy variant |
| `deploy/setup-datadog.ps1` | Self-contained deploy variant |

**Verified on:** macOS (smoke test: Pup 0.26.0 installed, build-deploy pass). Windows: not tested.

---

## v0.43.0 -- Add Go as managed tool, fix invocation table drift (2026-03-06)

### Added

| # | Change |
|---|--------|
| 1 | **Go managed tool**: New `setup-go.sh` (Homebrew) and `setup-go.ps1` (winget) setup scripts. Detects install provenance (homebrew, winget, pkg-installer, chocolatey, goenv, scoop, manual), cleans up non-preferred installs, ensures GOPATH/bin on PATH. |
| 2 | **Library functions**: `detect_go_provenance` / `Get-GoProvenance` (install method detection), `ensure_gopath_bin_on_path` / `Ensure-GopathBinOnPath` (PATH management) added to `aitools-lib.sh/.ps1`. |
| 3 | **Drift prevention checks**: `check-post-push` Steps 25 (CLI tools table sync) and 26 (deploy scripts list sync) verify `shared/claude-shared.md` and `CLAUDE.md` stay in sync with `tool-registry.md` and `build-deploy.sh`. |
| 4 | **`.scratch/` convention**: Project-local scratch directory (gitignored) replaces `/tmp/` for smoke test logs, scratch files, and subagent work product. Avoids permission prompts in Claude Code. |

### Changed

| # | Change |
|---|--------|
| 1 | **`check-post-push` always runs all steps**: Removed `--extensive`/`-Extensive` flag -- all 26 steps run by default. |
| 2 | **Invocation table drift fixed**: Added Go and Datadog CLI (`pup`) to Managed CLI Tools table in `shared/claude-shared.md` and dotprofile `CLAUDE.md`. |
| 3 | **Deploy scripts list fixed**: Added `-modal` and `-go` to `CLAUDE.md` deploy scripts reference. |
| 4 | **Go added to tool registry**: Full `reference/tool-registry.md` section with install, update, non-preferred methods, lifecycle. Entry added to `tool-versions.json`. |
| 5 | **USO/UCI rules updated**: Scratch files, commit messages, and subagent work product now specify `.scratch/` instead of `/tmp/` or generic "temp file". |

### New files

| File | Purpose |
|------|---------|
| `scripts/setup-go.sh` | macOS Go setup via Homebrew |
| `scripts/setup-go.ps1` | Windows Go setup via winget |
| `deploy/setup-go.sh` | Self-contained deploy variant |
| `deploy/setup-go.ps1` | Self-contained deploy variant |

**Verified on:** macOS (smoke test: Go upgraded 1.26.0 -> 1.26.1, post-push steps 25-26 PASS). Windows: not tested.

---

## v0.42.1 -- Python cleanup and uv tool repair library functions (2026-03-06)

### Added

| # | Change |
|---|--------|
| 1 | **`Repair-UvToolEnv` (PS1) / `repair_uv_tool_env` (bash)**: New shared library function that detects broken uv tool environments ("missing a valid environment") and automatically repairs them by finding a working Python via `uv python find` (fallback: system python) and reinstalling with `--force --python`. |
| 2 | **`Remove-OrphanedPythonDirs` (PS1, Windows only)**: New shared library function that scans `%LOCALAPPDATA%\Programs\Python\` for directories where `python.exe` is gone (legacy uninstall), removes them, and cleans stale User PATH entries. |

### Changed

| # | Change |
|---|--------|
| 1 | **`setup-modal.ps1/.sh`**: Replaced inline broken-environment repair with `Repair-UvToolEnv` / `repair_uv_tool_env` call. |
| 2 | **`setup-python.ps1`**: Added `Remove-OrphanedPythonDirs` call after legacy Python detection to clean up stale directories and PATH entries. |

(tested: Windows)

---

## v0.42.0 -- Extract Refresh-Path and winget output filter into shared library (2026-03-06)

### Changed

| # | Change |
|---|--------|
| 1 | **`Refresh-Path` extracted to `aitools-lib.ps1`**: Removed 9 identical inline definitions across setup scripts. Function now provided by the shared library (auto-inlined into deploy scripts by build). |
| 2 | **`Log-WingetOutput` extracted to `aitools-lib.ps1`**: Replaced 9 identical 4-line winget output filter blocks across 6 scripts with a single shared function call. |

(tested: Windows)

---

## v0.41.1 -- Fix logging noise across setup scripts (2026-03-06)

### Fixed

| # | Change |
|---|--------|
| 1 | **Python summary reports WARN when legacy install present** (`setup-python.ps1`): Summary line now checks accumulated warnings before choosing OK vs WARN. Previously showed green `[ok]` even when legacy `Python.Python.3.x` was detected. |
| 2 | **Suppress npm/cargo cleanup stdout** (`setup-typst.ps1`, `setup-typst.sh`): `npm uninstall -g typst` and `cargo uninstall typst-cli` stdout now piped to null. Previously leaked unstructured "up to date in Xms" lines to console. |
| 3 | **Filter winget download progress bar** (all `setup-*.ps1` with winget): Added `KB/MB/GB` regex to winget output filter. Prevents mojibaked Unicode block characters from appearing in structured log lines during package downloads. |
| 4 | **Filter rustup empty lines** (`setup-rust.ps1`, `setup-rust.sh`): Empty lines from `rustup update` output now skipped instead of logged as blank `[info]` entries. |

(tested: Windows)

---

## v0.41.0 -- Migrate Windows Python to pymanager (2026-03-06)

### Changed

| # | Change |
|---|--------|
| 1 | **Windows Python install via pymanager** (`setup-python.ps1`): Replaced version-specific `winget install Python.Python.3.13` with Python Install Manager (pymanager, PEP 773). Uses version-agnostic `winget install Python.PythonInstallManager` + `py install 3.14` for runtime management. Detects legacy `Python.Python.3.x` installs and warns with uninstall instructions. |
| 2 | **pip invocation on Windows** (`setup-modal.ps1`, `shared/claude-shared.md`, dotprofile): Standalone `pip` deprecated per PEP 773. Added `python -m pip` fallback in Modal CLI installer. Updated managed CLI table: `pip` (Windows) -> `python -m pip` (Windows). |

### Docs

| # | Change |
|---|--------|
| 1 | `reference/tool-registry.md`: Rewrote Python section for pymanager -- new install/update commands, added winget `Python.Python.3.x` and old py.exe launcher to non-preferred methods, updated invocation to include `py` for runtime management. |
| 2 | `reference/tool-versions.json`: Updated python notes field to reflect pymanager. |
| 3 | `scripts/setup-python.sh`: Added comment noting Windows uses pymanager. |

(tested: Windows)

---

## v0.40.0 -- JSON normalization, false-positive fix, modal migration, build speed (2026-03-06)

### Added

| # | Change |
|---|--------|
| 1 | **JSON normalization library** (`aitools-lib.sh`, `aitools-lib.ps1`): `SORT_KEYS_JS`/`normalize_json` (bash) and `Normalize-JsonForComparison`/`ConvertTo-CanonicalObject` (PS1). Recursively sorts keys before serializing, ensuring identical objects produce identical JSON regardless of hashtable key ordering or JS property insertion order. |
| 2 | **setup-user-mcp three-outcomes** (`.sh` + `.ps1`): Deny rules merge now detects unchanged state and skips the write, matching the three-outcomes pattern (unchanged/updated/failed) required by config-file-safety rules. |

### Fixed

| # | Change |
|---|--------|
| 1 | **False-positive change detection** (`setup-user-cursor`, `setup-cursor-ide-mcp`, `setup-user-hooks`, `setup-user-mcp` -- all .sh + .ps1): All JSON comparison sites now use normalized (sorted-key) serialization. Eliminates false "updated" reports caused by non-deterministic hashtable key ordering (PS1) and insertion-order differences (JS). Cursor IDE MCP no longer emits spurious "Restart Cursor IDE" action on every run. |
| 2 | **Modal CLI pip-to-uv migration** (`setup-modal.sh`, `setup-modal.ps1`): When `uv tool upgrade modal` fails with "is not installed" (pip-installed modal), falls back to `uv tool install modal` instead of reporting an error. |
| 3 | **Build speed** (`build-deploy.sh`): Replaced while-read + echo + grep loops with single perl invocations for lib inlining. Reduces subprocess spawns from ~15,600 to 26 on Windows. |

### Docs

| # | Change |
|---|--------|
| 1 | `reference/script-standards-detail.md`: Added JSON normalization row to library contents table. Updated canonical JSON config pattern to use `sortKeys()`. |
| 2 | `reference/claude-code-maintenance.md`: Updated to CC 2.1.70, added release notes section. |

---

## v0.39.1 -- Fix multi-line MERGE_RESULT case dispatch (2026-03-05)

### Fixed

| # | Change |
|---|--------|
| 1 | **setup-cursor-ide-mcp.sh, setup-user-cursor.sh**: CHANGED: lines appended to node output made `$MERGE_RESULT` multi-line, causing `case "$MERGE_RESULT"` to fall through to the catch-all error branch. Now extracts `MERGE_STATUS=$(head -1)` before the `case`, matching the pattern already used in `setup-user-hooks.sh`. |

---

## v0.39.0 -- Config change-detail library helpers + script dedup (2026-03-05)

### Added

| # | Change |
|---|--------|
| 1 | **Library helpers** (`aitools-lib.sh`, `aitools-lib.ps1`): `backup_file`/`Backup-File`, `backup_dir`/`Backup-Dir`, `ConvertPSObjectToHashtable`, `emit_merge_details`/`Emit-MergeDetails` moved from inline duplicates to shared library. All 26 deploy scripts get them via build-time inlining. |
| 2 | **Key-level CHANGED: tracking** (`setup-cursor-ide-mcp`, `setup-user-cursor` .sh + .ps1): JSON config merges now snapshot managed keys before write, detect per-key changes, and emit `CHANGED:` lines that become DETAIL summary entries. Fixes the triggering issue where `--isolated` → `--autoConnect` was silently corrected with no detail logged. |

### Fixed

| # | Change |
|---|--------|
| 1 | **Removed 15 inline duplicates** across 7 setup scripts: `backup_file` (4× bash), `Backup-File` (4× PS1), `ConvertPSObjectToHashtable` (4× PS1), `backup_dir` (1× bash), `Backup-Dir` (1× PS1). All now use the library version. |
| 2 | **setup-user-hooks refactored** (.sh + .ps1): inline CHANGED: parsing replaced with `emit_merge_details`/`Emit-MergeDetails` library calls. |

### Docs

| # | Change |
|---|--------|
| 1 | `reference/script-standards-detail.md`: Contents table updated with 4 new library entries. |
| 2 | `.claude/rules/script-standards.md`, `.cursor/rules/script-standards.mdc`: Block order lib descriptions updated to list all provided helpers. |

### Untested (Windows)

PS1 scripts validated via `pwsh Parser::ParseFile` on macOS. Functional testing on Windows pending.

---

## v0.38.0 -- Plan execution rules, DETAIL summary, effortLevel, config reporting (2026-03-05)

### Added

| # | Change |
|---|--------|
| 1 | **Plan execution rule** (`.claude/rules/plan-execution.md`, `.cursor/rules/plan-execution.mdc`, `reference/plan-execution-detail.md`): New project rule requiring sub-agent execution pattern for plans modifying 3+ code files or any shared library. Includes error-handling audit checklist, sub-agent prompt template, and verification protocol. Addresses root cause I17 (rule fade during long sessions). |
| 2 | **DETAIL summary category** (`aitools-lib.sh`, `aitools-lib.ps1`): `write_summary DETAIL "tool" "message"` renders indented under its parent entry, inheriting the parent's color. Summary renderer rewritten as single-pass with pre-sorted output (OK+details, WARN+details, ERROR+details, ACTIONs). |
| 3 | **effortLevel preference** (`build-deploy.sh`, `setup-user-hooks` .sh + .ps1): New `claudePrefs.effortLevel` in `profile.json` (low/medium/high). Deployed to `~/.claude/settings.json` via preferences merge. Validated against allowed values; displayed in dry-run and success logs. |
| 4 | **Config update reporting** (`setup-user-hooks`, `setup-user-claude`, `setup-user-cursor`, `setup-user-mcp`, `setup-cursor-ide-mcp` .sh + .ps1): Three-outcome pattern (unchanged/updated/created) with DETAIL summary entries for individual changes. Hook deployment shows per-hook diffs in log. Preferences merge tracks old→new values and emits `CHANGED:` lines. |
| 5 | **New compliance checks** (`check-script-compliance` .sh + .ps1): Step 11 scans PS1 for `-ErrorAction SilentlyContinue` without result check. Step 12 validates `write_summary` categories against valid set. |
| 6 | **Post-push DETAIL verification** (`check-post-push` .sh + .ps1): Step 24 (extensive only) verifies DETAIL category in both lib files and usage in scripts. |

### Fixed

| # | Change |
|---|--------|
| 1 | **Compliance warnings cleared**: Raw `echo` in `setup-user-claude.sh` backup pruning → `printf`. Unsafe grep pipelines in `setup-user-mcp.sh` and `aitools-install.sh` → `|| true`. Bare `Remove-Item -ErrorAction SilentlyContinue` in `aitools-install.ps1` → `Test-Path` guard. |
| 2 | **Summary preserve/cleanup** (`aitools-lib.sh`, `aitools-lib.ps1`): `AITOOLS_PRESERVE_SUMMARY` support with proper error handling on copy. |

### Notes

- Plan v3 implemented using the sub-agent execution pattern it codifies (batches 0, 3, 4, 5a-e, 6a+6c).
- Batch 6b (check-log-compliance script pair) deferred as follow-up.
- Verified: `check-script-compliance.sh` 12 PASS, 0 WARN, 0 FAIL.
- Verified: `build-deploy.sh` succeeds (26 deploy scripts). All bash syntax checks pass.
- Not tested (Windows): PS1 changes syntactically validated via `pwsh -NoProfile` but not end-to-end tested.

---

## v0.37.1 -- Fix summary panel: missing ERROR entries in config scripts (2026-03-05)

### Fixed

| # | Change |
|---|--------|
| 1 | **Guard "claude rules" OK** (`setup-user-claude` .sh + .ps1): `write_summary OK "claude rules"` was unconditional after rules deployment. Now guarded with `$ERRORS -eq 0` check; writes `ERROR` on validation failure. |
| 2 | **Add ERROR for "claude.md" validation** (`setup-user-claude` .sh + .ps1, `build-deploy.sh`): Post-write validation failures incremented ERRORS but never wrote `write_summary ERROR "claude.md"` -- tool vanished from summary. Added `elif` branch. Also fixed deploy template in `build-deploy.sh` which was missing `write_summary` for "claude.md" entirely. |
| 3 | **Add ERROR for "cursor rules"** (`setup-user-cursor` .sh + .ps1): Corrupt/clobber error branches called `log_error` but no `write_summary ERROR` -- tool vanished. Added `write_summary ERROR "cursor rules"` in all error branches. |
| 4 | **Add ERROR for "cursor ide mcp"** (`setup-cursor-ide-mcp` .sh + .ps1): Corrupt/clobber error branches and disable failures called `log_error` but no `write_summary ERROR` -- tool vanished. Added `write_summary ERROR "cursor ide mcp"` in all error branches. |
| 5 | **Add ERROR for "claude mcp"** (`setup-user-mcp` .sh + .ps1): `add_mcp_server` failure and deny merge error branches called `log_error` but no `write_summary ERROR` -- tool vanished. Added `write_summary ERROR "claude mcp"` in all error branches. |
| 6 | **Add ERROR for "claude hooks"** (`setup-user-hooks` .sh + .ps1): Corrupt/clobber error branches called `log_error` but no `write_summary ERROR` -- tool vanished. Added `write_summary ERROR "claude hooks"` in all error branches. |
| 7 | **Skills snapshot pattern** (`setup-user-mcp` .sh + .ps1, `build-deploy.sh`): Skills `write_summary OK` used cumulative `$ERRORS` -- an MCP add failure would hide skills OK even though skills deployed fine. Now uses `ERRORS_BEFORE_*_SKILLS` snapshot to isolate skills errors from earlier MCP errors. Also writes `ERROR` on skills deploy failure. |

### Notes

- All 7 bugs followed the same pattern: error paths called `log_error` (which increments ERRORS) but never called `write_summary ERROR`, so the tool vanished from the end-of-run summary panel on failure instead of showing red.
- Verified: `check-script-compliance.sh` shows no regressions (2 pre-existing WARNs, fixed in v0.38.0).
- Verified: `build-deploy.sh` builds successfully; all PS1 scripts pass pwsh syntax validation.
- Not tested (Windows): PS1 changes are syntactically validated via `pwsh -NoProfile` but not end-to-end tested.

---

## v0.37.0 -- Fix summary panel: dedup + correct severity reporting (2026-03-04)

### Fixed

| # | Change |
|---|--------|
| 1 | **Summary panel dedup** (`scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`): `show_summary()`/`Show-Summary` now deduplicates by tool name before rendering -- highest severity wins (ERROR > WARN > OK). Previously, a tool could show both green OK and red ERROR when a script wrote both. ACTION entries (empty tool name) are never deduplicated. Bash uses perl for dedup; PS1 uses hashtable. |
| 2 | **Error-then-unconditional-OK in 7 tool installers** (`setup-gh-cli`, `setup-rust`, `setup-uv`, `setup-pandoc`, `setup-typst`, `setup-vercelcli`, `setup-python` .sh + .ps1): Upgrade-failure paths called `write_summary ERROR` then fell through to `write_summary OK`. Wrapped final OK in `else` branch of error check (bash) or guarded with `$errors -eq 0` (PS1). |
| 3 | **Warn-then-unconditional-OK in user config scripts** (`setup-user-claude`, `setup-user-hooks`, `setup-user-mcp` .sh + .ps1): `write_summary OK` ran unconditionally after warn/error paths. Guarded with error/warning counter checks. |
| 4 | **Deploy template sync** (`scripts/build-deploy.sh`): Skills deployment `write_summary OK` in hardcoded template blocks (not extracted from source) synced with the same `$ERRORS`/`$errors` guard applied to source scripts. |

### Notes

- Renderer dedup is a safety net -- source scripts now emit correct severity, but the renderer protects against future regressions.
- Verified: `check-script-compliance.sh` shows no regressions (2 pre-existing WARNs, fixed in v0.38.0).
- Tested (macOS): dedup verified with mock summary file containing duplicate entries at all severity levels.
- Not tested (Windows): PS1 changes are syntactically validated via `pwsh -NoProfile` but not end-to-end tested.

---

## v0.36.2 -- Fix Modal install + smart ACTION detection (2026-03-04)

### Fixed

| # | Change |
|---|--------|
| 1 | **Modal CLI install broken on Homebrew Python** (`scripts/setup-modal.sh/.ps1`): `uv pip install --system` blocked by PEP 668 ("externally managed environment") after switching from pyenv to Homebrew Python 3.14. Switched to `uv tool install modal` which manages its own venv. Falls back to `pip install --user modal` when uv is unavailable. |
| 2 | **Unconditional "modal setup" ACTION** (`scripts/setup-modal.sh/.ps1`): Nagged every run even when already authenticated. Now checks for `~/.modal.toml` before suggesting auth. |
| 3 | **Unconditional "vercel login" ACTION** (`scripts/setup-vercelcli.sh/.ps1`): Nagged every run even when already authenticated. Now checks via `vercel whoami` before suggesting auth. |
| 4 | **Unconditional "Restart Cursor" ACTION** (`scripts/setup-cursor-ide-mcp.sh/.ps1`): Nagged every run even when config was unchanged. Now detects unchanged content and skips the restart suggestion. |
| 5 | **tool-registry.md**: Updated Modal CLI install method from `pip install modal` to `uv tool install modal`. |

### Notes

- Terminal title flickers with "pwsh" during `aitools install` on macOS -- this is `build-deploy.sh` validating 13 PS1 files individually via `pwsh`. Expected behavior, not a bug (could batch later).

---

## v0.36.1 -- Fix Python detection + write_summary set -e bug (2026-03-04)

### Fixed

| # | Change |
|---|--------|
| 1 | **setup-python.sh false positive warning** (`scripts/setup-python.sh`): Replaced `command -v python3` detection with direct Homebrew binary checks at `/opt/homebrew/bin/python3` and `/usr/local/bin/python3`. Prevents pyenv shims (or other PATH-shadowing tools) from triggering "installed via non-preferred method" warnings and unnecessary reinstall attempts. |
| 2 | **write_summary set -e abort** (`scripts/aitools-lib.sh`): `[ -n "" ] && printf ...` returns exit code 1 when `AITOOLS_SUMMARY_FILE` is unset; under `set -euo pipefail` this silently aborts the calling script. Changed to `if/then`. Affected all deploy scripts run standalone (outside `aitools install`). |

---

## v0.36.0 -- Logging standards overhaul + compliance check (2026-03-04)

### Added

| # | Change |
|---|--------|
| 1 | **Log line format standard**: Every log line now follows `[timestamp] [script] [level] message` with valid levels: `info`, `ok`, `warn`, `error`. Console output uses ANSI colors (red for errors, yellow for warnings). Log file output is plain text only. |
| 2 | **Warning counter** (`scripts/aitools-lib.sh/.ps1`): `log_warn`/`LogWarn` now increments `WARNINGS`/`$script:warnings`. Exit footers check both ERRORS and WARNINGS -- scripts with warnings report "COMPLETED with N warning(s)" instead of "COMPLETED successfully". |
| 3 | **Script compliance checker** (`scripts/check-script-compliance.sh/.ps1`): New 10-step automated audit -- log format, exit footers, write_summary coverage, counter tracking, raw echo/Write-Host, grep pipefail safety, OS guards, logging init, cross-platform pairing. Integrated as step 23 in `check-post-push` (extensive mode). |

### Fixed

| # | Change |
|---|--------|
| 1 | **setup-modal.sh grep pipefail crash** (`scripts/setup-modal.sh`): `grep -o '\[notice\]...' \| head -1` returns exit 1 when no match; `set -euo pipefail` kills the script before `write_summary` runs, causing Modal to disappear from the summary panel. Added `\|\| true`. Fixes [#12](https://github.com/nobul-jose/aitools/issues/12). |
| 2 | **setup-modal missing write_summary on Python check** (`scripts/setup-modal.sh/.ps1`): Early `exit 1` when Python < 3.10 had no `write_summary`, so Modal vanished from the summary panel on version failure. |
| 3 | **Exit footer reports success despite warnings** (`scripts/aitools-lib.sh/.ps1`, all setup scripts): No WARNINGS counter existed; `log_warn` didn't affect exit status. Fixes [#13](https://github.com/nobul-jose/aitools/issues/13). |
| 4 | **`grep -P` fails on macOS** (`scripts/check-post-push.sh`, `scripts/check-pre-commit.sh`): macOS BSD `grep` lacks `-P`. Replaced with `grep -rl $'\r'` (CRLF detection) and `perl -0777 -ne` (Perl regex matching). Added cross-platform grep portability rule to script standards. |

### Changed

| # | Change |
|---|--------|
| 1 | **All setup script exit footers** (28 files: 14 `.sh` + 14 `.ps1`): Updated to check both ERRORS and WARNINGS counters with level-tagged log messages. |
| 2 | **Entry point logging overrides** (`scripts/aitools`, `scripts/aitools.ps1`, `scripts/aitools-install.sh/.ps1`): Updated to `[level]` format and WARNINGS tracking. |
| 3 | **Build script logging** (`scripts/build-deploy.sh`): `blog`/`blog_ok`/`blog_error` now include `[level]` tag. |
| 4 | **Module-level counter initialization** (`scripts/aitools-lib.sh`): `ERRORS=0` and `WARNINGS=0` set at module level (safe for scripts that source without calling `logging_init`, e.g., via `check-lib.sh`). |
| 5 | **Rules and documentation** (`.claude/rules/script-standards.md`, `.cursor/rules/script-standards.mdc`, `reference/script-standards-detail.md`): Added log line format spec, warning counter requirement, console color spec, standalone build logging exception, cross-platform grep portability rule. |

**Verified**: macOS

---

## v0.35.0 -- Shared helper library + git pull resilience (2026-03-03)

### Added

| # | Change |
|---|--------|
| 1 | **Shared helper library** (`scripts/aitools-lib.sh`, `scripts/aitools-lib.ps1`): New single source of truth for common helpers -- platform detection, log directory, `display_path`, `read_config_key`/`ReadConfigKey`, `logging_init`/`Initialize-Logging`, `log`/`log_ok`/`log_error`/`log_warn` + PS1 equivalents, `write_summary`/`Write-Summary`, `show_summary`/`Show-Summary`. Previously copy-pasted across 14+ setup scripts (~50 lines each in .sh, ~40 in .ps1). |
| 2 | **PS1 summary panel parity** (`scripts/aitools.ps1`): Added `Show-Summary` call and summary file init. PS1 entry point was missing end-of-run summary panel entirely -- now matches bash behavior. |

### Fixed

| # | Change |
|---|--------|
| 1 | **git pull line-ending failure** (`scripts/aitools`, `scripts/aitools.ps1`): `git checkout -- deploy/` resets from index (which may have line-ending diffs staged), not HEAD. Changed to `git checkout HEAD -- deploy/` on both quiet-pull and gitpull-strict paths. Fixes [#11](https://github.com/nobul-jose/aitools/issues/11). |
| 2 | **git pull failure visibility** (`scripts/aitools`, `scripts/aitools.ps1`): Pull failures now emit `write_summary WARN "source" "stale local checkout (git pull failed)"` so they appear in the end-of-run summary panel instead of being silently logged. |

### Changed

| # | Change |
|---|--------|
| 1 | **All setup scripts consolidated** (26 files: 13 `.sh` + 13 `.ps1`): Replaced ~15 lines of inline logging boilerplate with 2-line lib source + `logging_init`/`Initialize-Logging`. |
| 2 | **Entry points source lib** (`scripts/aitools`, `scripts/aitools.ps1`, `scripts/aitools-install.sh/.ps1`): Source shared lib then override logging for specialized behavior (file-only, JSONL). Bootstrap helpers (`read_config_key`, `display_path`) remain inline in `scripts/aitools` (needed before repo path is known). |
| 3 | **Check-lib sources base lib** (`scripts/check-lib.sh`, `scripts/check-lib.ps1`): Removed duplicated `read_config_key`/`ReadConfigKey`, platform detection, and log directory computation -- now inherited from `aitools-lib`. |
| 4 | **Build pipeline inlines lib** (`scripts/build-deploy.sh`): Added `inline_lib_bash()`/`inline_lib_ps1()` filters. Deploy scripts remain self-contained -- lib content is inlined at build time. |
| 5 | **Documentation updates** (`CLAUDE.md`, `.claude/rules/script-standards.md`, `.cursor/rules/script-standards.mdc`, `reference/script-standards-detail.md`): Updated project structure tree, block order, logging helpers reference, and added shared library section with contents table, usage examples, and override documentation. |

**Verified**: macOS

---

## v0.34.3 -- Move Cloud MCP status into setup-user-mcp (2026-03-03)

### Fixed

| # | Change |
|---|--------|
| 1 | **Cloud MCP display location** (`setup-user-mcp.sh/.ps1`): Moved cloud MCP status display from `aitools-install` orchestrator into `setup-user-mcp` itself, so it appears with proper `[setup-user-mcp]` tag right before `COMPLETED successfully`. Previously displayed after the summary panel in the orchestrator with manual tag formatting. |

### Changed

| # | Change |
|---|--------|
| 1 | **Post-push step 22b** (`check-post-push.sh/.ps1`, `post-push-checklist.md`): Now checks `setup-user-mcp` source scripts for `show_cloud_mcp_status`/`Show-CloudMcpStatus` in exit section instead of checking `aitools-install` for `show_cloud_mcp`/`Show-CloudMcp`. |

**Verified**: Windows

---

## v0.34.2 -- Fix winget logging noise + Cloud MCP in install + post-push audit (2026-03-03)

### Fixed

| # | Change |
|---|--------|
| 1 | **Winget progress noise** (`setup-uv.ps1`, `setup-python.ps1`, `setup-typst.ps1`, `setup-gh-cli.ps1`, `setup-pandoc.ps1`, `setup-rust.ps1`): Filter winget progress bar characters (`-`, `\`, `|`, `/`) and blank lines from structured log output. 9 locations across 6 scripts. |
| 2 | **Cloud MCP in install path** (`aitools-install.sh/.ps1`): Cloud MCP server status now displays inside the installer output with `[setup-user-mcp]` tag, right before `COMPLETED successfully` -- matching the structured logging style of the no-args/gitpull deploy sequence. Previously missing from install entirely; v0.34.2 initial fix placed it after `All up to date` without tagging. |

### Added

| # | Change |
|---|--------|
| 1 | **Post-push step 22: Logging hygiene audit** (`check-post-push.sh/.ps1`): Extensive-tier check with two sub-steps -- 22a verifies all setup-*.ps1 filter winget progress chars, 22b verifies both installer scripts call show_cloud_mcp before COMPLETED. |

**Verified**: Windows

---

## v0.34.1 -- Move Cloud MCP status into deploy sequence (2026-03-03)

### Changed

| # | Change |
|---|--------|
| 1 | **Cloud MCP status display** (`scripts/aitools`, `scripts/aitools.ps1`): Moved from end-of-run (after summary panel) into `deploy_configs()`/`Deploy-Configs()`, displayed immediately after `setup-user-mcp` runs. Uses structured logging with `[timestamp] [setup-user-mcp]` prefix to match surrounding deploy output. Standalone `aitools mcp` display unchanged. |

**Verified**: Windows

---

## v0.34.0 -- Onboard Python, pip, and uv as managed tools (2026-03-03)

### Added

| # | Change |
|---|--------|
| 1 | **Python setup scripts** (`setup-python.sh/.ps1`): New managed tool. macOS: `brew install python`. Windows: `winget install Python.Python.3.13` with automatic Microsoft Store (MSIX) Python removal via `Get-AppxPackage`. Winget ID stored in `$pythonWingetId` variable for easy version bumps. pip verified as bundled. |
| 2 | **uv setup scripts** (`setup-uv.sh/.ps1`): New managed tool. macOS: `brew install uv`. Windows: `winget install --id=astral-sh.uv`. Fast Python package installer (50-100x faster than pip). |
| 3 | **uv-first package install pattern**: Documented in `reference/script-standards-detail.md` with bash and PowerShell examples. All Python package installs now check uv > pip3 > pip. |

### Changed

| # | Change |
|---|--------|
| 1 | **Modal CLI uv-first** (`setup-modal.sh/.ps1`): Package installs now use uv when available, falling back to pip. `pip check` only runs when pip is the backend. Header comments updated to reflect uv-first. |
| 2 | **Installer ordering** (`aitools-install.sh/.ps1`): Python (Step 14) and uv (Step 15) added before Modal (renumbered Step 16). Deploy configs renumbered to Step 17. |
| 3 | **Build pipeline** (`build-deploy.sh`): Copy-as-is blocks added for `setup-python` and `setup-uv` (blocks 17-20). Modal renumbered to 21-22, MCP to 23-24. |
| 4 | **Tool registry** (`reference/tool-registry.md`): Python and uv entries added with install commands, lifecycle, and non-preferred method cleanup targets. Modal dependencies updated to include uv. |
| 5 | **Managed CLI Tools table**: Python, pip, and uv added to `shared/claude-shared.md`, user dotprofile `CLAUDE.md`, and project `CLAUDE.md` MDM deploy line. |

### Fixed

| # | Change |
|---|--------|
| 1 | **Python MSIX alias stub** (`setup-python.ps1`): After removing Microsoft Store Python, `Get-Command python` still found the stale WindowsApps alias stub. Script now tests `python --version` to distinguish real Python from stale aliases, and falls through to fresh install when needed. |
| 2 | **uv `--system` flag** (`setup-modal.sh/.ps1`): `uv pip install` requires `--system` to install into the system Python (not a virtualenv). Added `INSTALL_FLAGS`/`$installFlags` variable to the uv-first pattern. Updated `reference/script-standards-detail.md` examples. |
| 3 | **Modal PATH refresh** (`setup-modal.sh/.ps1`): Added `Refresh-Path`/`hash -r` at script start to pick up Python and uv installed by prior steps in the same installer run. |
| 4 | **Python/uv idempotent PATH refresh** (`setup-python.ps1`, `setup-uv.ps1`): Added `Refresh-Path` before install/update check so child pwsh processes find tools installed by prior runs. Without this, `Get-Command` found stale WindowsApps stubs instead of the real Python. |
| 5 | **winget "already installed" false failure** (`setup-python.ps1`, `setup-uv.ps1`): `winget install` exits with -1978335189 when the package is already installed with no upgrade available. Scripts now detect "already installed" + "No available upgrade" output and treat it as success instead of error. |

**Verified**: Windows (tested: setup-python, setup-uv, setup-modal end-to-end, plus idempotent re-runs). macOS: pending.

---

## v0.33.0 -- Installer improvements: pip health, MCP idempotency, cursor IDE rename, hooks skip (2026-03-03)

### Changed

| # | Change |
|---|--------|
| 1 | **Rename `setup-cursor-mcp` to `setup-cursor-ide-mcp`**: Disambiguates Cursor IDE MCP setup from Claude Code MCP setup. Updated across 17 files (scripts, docs, references). Summary tool name now `cursor ide mcp`. "Next steps" log replaced with `write_summary ACTION` for end-of-run panel visibility. |
| 2 | **Hooks idempotency** (`setup-user-hooks`): Hook files and `settings.json` now compared before writing. Skips copy/write when content is unchanged. Summary shows "deployed" or "unchanged" accordingly. |
| 3 | **Chrome-devtools MCP idempotency** (`setup-user-mcp.ps1`): Fixed Windows config match to include `cmd /c` prefix. Was: remove+re-add every run. Now: "already configured, skipping" on subsequent runs. |
| 4 | **Modal pip health** (`setup-modal`): Pip upgrade notice (`[notice] A new release of pip is available`) now surfaced as WARN in summary panel. Post-install `pip check` detects and warns about dependency conflicts (e.g., protobuf version mismatch). |

**Verified**: Windows

---

## v0.32.1 -- Fix typst + modal installer false failures (2026-03-03)

### Fixed

| # | Change |
|---|--------|
| 1 | **Typst winget "already up to date" handling** (`setup-typst.ps1`): winget returns non-zero exit code (`-1978335189` / `APPINSTALLER_CLI_UPDATE_NOT_APPLICABLE`) when no upgrade is available. Script now checks output for "No available upgrade" before checking exit code, matching the pattern already used by `setup-gh-cli.ps1`. Was: `[ERR] typst winget upgrade failed`. |
| 2 | **Modal CLI PATH resolution** (`setup-modal.ps1`): Windows Store Python's `pip install --user` places the `modal` binary in a Scripts directory not on PATH. Script now refreshes PATH from registry after pip install, and if `modal` still not found, discovers the Python user Scripts directory via `sysconfig` and adds it to both session and persistent user PATH. Was: `[ERR] modal cli installed but not on PATH`. |

**Verified**: Windows

---

## v0.32.0 -- 3-field summary format + external command standards (2026-03-03)

### Changed

| # | Change |
|---|--------|
| 1 | **3-field summary format**: All `write_summary` calls converted from 2-arg (`CAT\|msg`) to 3-arg (`CAT\|tool_name\|detail`). Renderer updated with left-aligned columns. Canonical tool name table in `reference/script-standards-detail.md`. |
| 2 | **Tool name standardization**: Inconsistent names (`vercel CLI`, `modal CLI`, `cursor config`, `hooks`, `MCP servers`) normalized to lowercase canonical names (`vercel cli`, `modal cli`, `cursor rules`, `claude hooks`, `claude mcp`). |
| 3 | **Missing summary entries added**: `claude rules` (setup-user-claude), `claude skills` + `cursor skills` (setup-user-mcp), `cursor mcp` (setup-cursor-ide-mcp) now appear in the end-of-run panel. |
| 4 | **External command error handling standards**: New section in script-standards rule and detail reference. Four standards: capture output, check exit codes, distinguish "up to date" from failure, PATH = error not warning. |
| 5 | **`reference/script-standards-detail.md` rewrite**: Full reference with severity categories, decision guide, summary coverage rule, ACTION item format, anti-pattern examples, and external command patterns. |
| 6 | **Build-deploy skills write_summary**: `build-deploy.sh` updated to emit `write_summary` calls in embedded skills sections, so deploy/ scripts include skills in the summary panel. |

**Verified**: Windows
**Closes**: [#8](https://github.com/nobul-jose/aitools/issues/8) (remaining steps), [#9](https://github.com/nobul-jose/aitools/issues/9) (build-deploy standardization landed in prior batch; summary format was last dependency)

---

## v0.31.0 -- End-of-run summary panel + Modal CLI setup scripts (2026-03-02)

### New

| # | Change |
|---|--------|
| 1 | **End-of-run summary panel**: Every aitools run (`install`, no-args, `gitpull`) now ends with a structured panel showing `[ok]` (green), `[!]` (yellow warnings), and `ACTION REQUIRED` (yellow) items. Motivating case: `modal setup` auth step was buried mid-install and invisible by run end. |
| 2 | **`show_summary`**: Three-pass display function (OK → WARN → ACTION) in `scripts/aitools` and `scripts/aitools-install.sh/.ps1`. Reads `AITOOLS_SUMMARY_FILE` temp file; silent no-op if unset (standalone script runs). |
| 3 | **`write_summary` in all 11 setup scripts**: Every tool and config setup script now calls `write_summary OK/WARN/ACTION` at the verify point. Tool scripts: gh-cli, pandoc, rust, typst, vercelcli, modal. Config scripts: user-claude, user-cursor, user-mcp, cursor-mcp, user-hooks. |
| 4 | **`setup-modal.sh/.ps1`**: Dedicated install/update scripts for Modal CLI (pip install, Python 3.10+ guard, `modal setup` ACTION item). MDM-deployable copies generated. Deploy count 20 → 22. |
| 5 | **Script standards rule**: End-of-run summary section added to `.claude/rules/script-standards.md`; code patterns in `reference/script-standards-detail.md`. `write_summary` is now a repo requirement for all setup scripts. |
| 6 | **Modal CLI promoted to supported**: `tool-registry.md` platform status updated from evaluating to supported on all three platforms. |

**Verified**: macOS

---

## v0.30.0 -- Onboard gh-cli as managed tool (2026-03-02)

### New

| # | Change |
|---|--------|
| 1 | **`setup-gh-cli.sh/.ps1`**: dedicated install/update scripts for GitHub CLI (macOS/Linux via Homebrew+apt, Windows via winget). Matches pandoc/rust/typst lifecycle pattern. |
| 2 | **`aitools-install` Step 1 refactored**: inline gh install body replaced with `validate_and_run`/`Invoke-ValidatedScript` delegation to `setup-gh-cli`. Auth step (Step 2) unchanged. |
| 3 | **`deploy/setup-gh-cli.sh/.ps1`**: MDM-deployable copies generated by `build-deploy.sh`. Deploy count 18 → 20. |
| 4 | **Tool registry**: full GitHub CLI entry with all 6 lifecycle fields. |
| 5 | **Managed CLI Tools table**: `gh` row added to `shared/claude-shared.md`, dotprofile `CLAUDE.md`, and deployed `~/.claude/CLAUDE.md`. |
| 6 | **Tool lifecycle rule**: onboarding checklist + dotprofile priority note added to `.claude/rules/tool-lifecycle.md` and `.cursor/rules/tool-lifecycle.mdc`. |
| 7 | **Roadmap**: `aitools user sync` feature item added — future structured merge of shared template sections into dotprofile, eliminating manual "update both files" requirement. |

**Verified**: macOS

---

## v0.29.4 -- Fix step 21 logging and audit findings (2026-03-02)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Medium | **Step 21: suppress OK noise**: per-tool OK lines were printed before the step header, inconsistent with all other steps. Now only WARN/SKIP detail lines print; step header shows count summary (`11 OK, 1 skipped`). |
| 2 | Medium | **PS1 step 21: wrong platform key**: script always read `macos.lastVerifiedVersion` and printed `"no Windows version in manifest"` — wrong on both counts. Now uses `$IsMacOS`/`$IsLinux`/`windows` to select the correct platform key. |
| 3 | Low | **Step 21: remove WARNS sentinel**: Python emitted a `WARNS\|count\|` sentinel line consumed by the bash loop. Replaced with a per-line bash counter; cleaner and removes implicit coupling. |

### Other fixes

| # | Fix |
|---|-----|
| 1 | Extensive tier comment "steps 6-20" corrected to "steps 6-21" in both scripts. |
| 2 | Step 10 protected files inventory was missing `reference/tool-versions.json` (added as protected in v0.29.0 but never added to the check). Both scripts updated. |

**Verified**: macOS

---

## v0.29.3 -- Post-push step 21: Tool version freshness (2026-03-02)

### Changes

| # | Change |
|---|--------|
| 1 | **Post-push step 21: Tool version freshness**: `check-post-push.sh/.ps1` now implements the step documented in v0.29.0. Checks all 9 versioned tools against `tool-versions.json` (substring match on `--version` output); checks 3 @latest MCP tools for `lastReviewed` staleness (>30d = WARN). `modal-cli` skipped when manifest version is null. |

**Verified**: macOS

---

## v0.29.2 -- Hook: Fix crash on unset $MODE variable (2026-03-02)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | High | **Hook crash on every Bash call**: `standing-order-guard.sh` referenced deleted `$MODE` variable (stale from MODE→per-check refactor). `set -euo pipefail` with `-u` caused the hook to crash before any check ran, producing "PreToolUse:Bash hook error" on every Bash tool call. Fix: unconditional `mkdir -p "$LOG_DIR"` replaces the dead conditional. |

**Verified**: macOS

---

## v0.29.1 -- Hook: Enforce && and $() (2026-03-02)

### Changes

| # | Change |
|---|--------|
| 1 | **PreToolUse hook: promote `&&` and `$()` to enforce**: `standing-order-guard.sh` now blocks `&&` and `$()` (exit 2). `\|\|`, `;`, and backticks remain in observe mode. Log analysis (35 entries) showed zero false positives for both promoted checks. |
| 2 | **Hook: `;` false-positive exemption**: `;` inside `pwsh -Command` and `perl -e` arguments is now correctly identified as a language-internal separator and skipped, not flagged as a shell chain. Keeps `;` detection clean for eventual enforce promotion. |
| 3 | **Hook rollout rule: per-check modes**: `hook-rollout.md` updated to document `MODE_AND`/`MODE_SUBSHELL`/`MODE_REST` pattern and current enforcement state table. Replaces single `MODE` variable model. |
| 4 | **I11 RCA**: `cd /path && git status` in same session as I10 documentation. Root cause: mode-switch amnesia + `cd && cmd` muscle memory. Hook correctly detected it but observe mode allowed through. |

**Verified**: macOS

---

## v0.29.0 -- Tool Registry: Renames, Linux Platform, Version Tracking (2026-03-02)

### Changes

| # | Change |
|---|--------|
| 1 | **File renames**: `reference/tool-install-sources.md` → `reference/tool-registry.md`; `reference/claude-code-version-deps.md` → `reference/claude-code-maintenance.md`. All references updated across scripts, rules, plans, and docs. |
| 2 | **Linux as third platform**: All tool entries in `tool-registry.md` now carry 3-platform Platform Status (`macOS \| Windows \| Linux`). Linux status per tool reflects Modal container targets (Debian). |
| 3 | **6th lifecycle field**: `Last verified version` added to all tool entries in `tool-registry.md`. macOS populated from live version checks (2026-03-02); Windows/Linux start as `pending`. |
| 4 | **`reference/tool-versions.json`** (new): Machine-readable per-platform version manifest for all 13 managed tools. Three patterns: A (maintenanceFile), B (versioned per-platform), C (@latest/remote). `_meta` block includes RFC 6570 URI Template for user repo, related doc paths, schema version. |
| 5 | **Modal CLI** (evaluating): New tool section in `tool-registry.md`. Cross-platform pip install; requires Python 3.10+; planned compute backend for aitools.nobul.tech. |
| 6 | **Post-push checklist item #21**: Tool version freshness — compare `<tool> --version` against `tool-versions.json` per platform; review @latest tools for assumption drift. |
| 7 | **Roadmap**: Three new planned items — aitools install version capture, aitools.nobul.tech + Modal compute, aitools inside Modal containers. |
| 8 | **I8 RCA complete**: Plan revision shallow (keyword grep vs. full re-read) — two confirmed occurrences, root cause identified, remediation documented. I10 RCA updated to reflect I8 as upstream cause. |

**Verified**: macOS

---

## v0.28.1 -- Hook: Glob Pattern Guard for rm (2026-03-01)

### Improvements

| # | Change |
|---|--------|
| 1 | **PreToolUse hook: glob guard for rm**: `standing-order-guard.sh` now detects glob patterns (`*`, `?`) in `rm` commands (observe mode). Suggests writing a cleanup script instead. |
| 2 | **USO: Simple Bash commands only**: Added glob-in-rm restriction to both `shared/claude-shared.md` and user repo CLAUDE.md. |

**Verified**: macOS

---

## v0.28.0 -- MCP Auth Preservation + Cloud Server Detection (2026-03-01)

### Improvements

| # | Change |
|---|--------|
| 1 | **MCP auth preservation**: `setup-user-mcp` now checks existing server configs via `claude mcp list` before re-adding. Servers whose config already matches are skipped, preserving OAuth tokens for HTTP servers (vercel, webflow). Use `--force` / `-Force` to re-add unconditionally. |
| 2 | **Cloud MCP detection**: `aitools mcp` and `aitools install` now display cloud MCP servers configured via claude.ai (e.g., Gmail, Google Calendar). Silent no-op when no cloud servers or `claude` CLI is unavailable. |

**Verified**: macOS

---

## v0.27.6 -- Simple Bash Commands Hook Guard (2026-03-01)

### Improvements

| # | Change |
|---|--------|
| 1 | **PreToolUse hook: Simple Bash commands guard**: `standing-order-guard.sh` now detects `&&`, `||`, `;`, `$(...)`, and backticks in Bash tool calls (observe mode). Suggests `git -C` for cross-repo commands and `git commit -F` for commit messages. Known gap: `$(...)` after quoted segments invisible to json_field parser -- mitigated by the USO itself. |

**Verified**: macOS

---

## v0.27.5 -- Pre-Push Regex Regression Fix (2026-03-01)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Low | **v0.27.4 regression**: `build-deploy.sh` not matched by pre-push step 7. Regex `build-deploy\.` consumed the extension dot, leaving `sh` with no `.` for `.*\.(sh|ps1)$`. Restructured to `(setup-.*|build-deploy)\.(sh|ps1)$`. |

**Verified**: macOS

---

## v0.27.4 -- Pre-Push Deploy Source Detection Fix (2026-03-01)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Low | **Pre-push step 7 false positives**: regex `^(scripts/|shared/).*\.(sh|ps1)$` matched non-deploy scripts (`check-*.sh/.ps1`, `aitools`, `analyze-session.sh`) triggering false "deploy/ not updated" warnings. Narrowed to `scripts/(setup-|build-deploy\.)` only. |
| 2 | Low | **Pre-push step 7 false negatives**: regex filtered `shared/` by `.sh/.ps1` extension, missing `shared/*.md` files (`claude-shared.md`, `SKILL.md`) that `build-deploy.sh` embeds into deploy scripts. Removed extension filter for `shared/`. |

**Verified**: macOS

---

## v0.27.3 -- Config Merge Audit Parity Fix (2026-03-01)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Low | **Post-push step 19 false positive**: `check-post-push.sh` scanned only 5 header lines for "sole owner" exemption, missing the comment on line 12 of `setup-user-claude.sh`. PS1 equivalent already used 15 lines. Widened bash to `head -15` to match. |

**Verified**: macOS

---

## v0.27.2 -- Dotprofile Docs & @ Reference Tracking (2026-03-01)

### Improvements

| # | Change |
|---|--------|
| 1 | **Dotprofile structure in CLAUDE.md**: Project CLAUDE.md now documents dotprofile repo layout (directory tree, template priority, rules deployment, session archiving) alongside the main repo structure. |
| 2 | **@ reference behavior documented**: `@file` references resolve in `CLAUDE.md` (pulled into context) but NOT in `.claude/rules/*.md` (remain as plain text). Added to dotprofile CLAUDE.md template under Knowledge Management. |
| 3 | **Version-deps tracking**: Added item #18 to `reference/claude-code-version-deps.md` tracking `@` reference resolution behavior across CC versions. |

**Verified**: macOS

---

## v0.27.1 -- Rules Deployment & Deploy Logging (2026-03-01)

### New features

| # | Change |
|---|--------|
| 1 | **User-level rules deployment**: `setup-user-claude` now deploys `~/.claude/rules/*.md` from user repo with additive semantics (add new, update changed, preserve unmanaged). Includes backup, diff logging, and post-write validation. |
| 2 | **Directory deployment pattern**: `config-file-safety.md` gains backup-before-overwrite for directories, diff logging on overwrite, and additive deploy conventions. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 3 | Low | Hook `json_field()` parser simplified from 4-process pipeline to pure bash regex (`BASH_REMATCH`), fixing fragile grep/sed chain. |
| 4 | Low | Standing-order-guard hook: missing colon after `--` in sed/awk violation messages now matches all other "USO: Dedicated tools --:" messages. |

### Improvements

| # | Change |
|---|--------|
| 5 | **Deploy logging: CLAUDE.md diff on change**: Actual mode now compares old vs new content -- logs "Content unchanged (no differences)", "Content updated" with unified diff to deploy.log, or "Content: new file". Closes #7. |
| 6 | **Deploy logging: rules unchanged clarity**: Rules unchanged message now includes "(no differences)" suffix. |
| 7 | **check-lib.sh: `get_mtime` helper**: Extracted duplicate macOS/Linux stat patterns from check-post-push.sh into shared library. |
| 8 | **CLAUDE.md streamlined**: Project tree restructured, Key Decisions simplified, Deploy using MDM section added. Shared template streamlined. |
| 9 | **Tool lifecycle additions**: Install cleanup, cross-platform vetting, and MCP server isolation rules added. |
| 10 | **Equal platform visibility**: Cross-platform rule now enforces showing both macOS and Windows in docs. |

**Verified on:** macOS (Darwin arm64)

---

## v0.27 -- CLAUDE.md Restructure & RFC 0001 (2026-03-01)

### New features

| # | Change |
|---|--------|
| 1 | **USO/PSO/UCI/PCI naming**: Standing orders split into USO (user) and PSO (project). Coaching items split into UCI (user) and PCI (project). Numbers removed for stability across reordering. |
| 2 | **RFC 0001 adopted**: Workspace tool-requests convention (`docs/aitools-requests.md`). GitHub-centric consumption via `gh` CLI. |
| 3 | **Tool governance signposts**: User-level CLAUDE.md now references aitools GitHub URLs for tool evaluation framework and install sources. Cross-project agents directed to RFC 0001 or `gh issue create`. |
| 4 | **Effectiveness log in user repo**: Coaching evaluation log moved from `reference/claude-code-effectiveness.md` to user repo `claude/effectiveness.md`. |

### Improvements

| # | Change |
|---|--------|
| 5 | **Context reduction**: Dropped all 6 `@reference/` imports from project CLAUDE.md (~870 lines). Replaced with signpost references that Claude reads on demand. |
| 6 | **Git identity dedup**: Removed from project CLAUDE.md, `.claude/rules/git-identity.md`, and `.cursor/rules/general.mdc` -- user-level covers all projects. |
| 7 | **Hooks coaching broadened**: From "explore hooks for auto-lint" to full hook pattern inventory (subagent context injection, auto-format, auto-test, notifications). |
| 8 | **Subagent context gap softened**: Changed from hard rule ("never delegate") to advisory ("prefer research; consider including rules"). |
| 9 | **Standing order references updated**: All `SO #N` references in hooks, scripts, and rules updated to `USO: Name` format. |

### Files created

| File | Purpose |
|------|---------|
| `rfcs/README.md` | RFC index |
| `rfcs/RFC-0001-workspace-tool-requests.md` | Workspace tool-requests convention |

**Verified on:** macOS (Darwin arm64)

---

## v0.26.1 -- Hook Observe Mode & Bug Fixes (2026-03-01)

### New features

| # | Change |
|---|--------|
| 1 | **Hook observe/enforce mode**: `standing-order-guard.sh` now supports `MODE="observe"` (log-only, default) and `MODE="enforce"` (blocking). New `violation()` helper dispatches based on mode. Logs to `~/.claude/hooks/logs/`. |
| 2 | **Pipeline exemption**: `cat`, `head`, `tail` as first token are allowed when the command contains a pipe (`|`), since the Read tool can't pipe output. |
| 3 | **Hook rollout rule**: New `.claude/rules/hook-rollout.md` + `.cursor/rules/hook-rollout.mdc` codifying the observe-then-enforce practice. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | High | **Post-push step 5 crash on macOS**: `find -printf '%T@'` is GNU-only; replaced with `find -print0` + `stat` loop for cross-platform file mtime lookup. |

### Improvements

| # | Change |
|---|--------|
| 5 | **Hook hot-path efficiency**: Moved `mkdir -p` from `violation()` to script init; replaced `sed`-based newline counting and `head\|awk` token extraction with pure bash. Cuts ~4 external process spawns per invocation. |

**Verified on:** macOS

---

## v0.26 -- Typst PDF Engine (2026-02-28)

### New features

| # | Change |
|---|--------|
| 1 | **Typst** added as managed tool: `setup-typst.sh` + `.ps1` (Homebrew on macOS, winget on Windows), cleanup of cargo/npm non-preferred installs, `aitools install` step 13, deploy scripts |

### Files created

| File | Purpose |
|------|---------|
| `scripts/setup-typst.sh` | macOS: Homebrew install/upgrade + cleanup |
| `scripts/setup-typst.ps1` | Windows: winget install/upgrade + cleanup |

**Verified on:** Windows

---

## v0.25 -- Standing Order Enforcement & Incident Tracking (2026-02-28)

### New features

| # | Change |
|---|--------|
| 1 | **PreToolUse hook** (`standing-order-guard.sh`): Real-time blocking of SO #1 (file ops in Bash) and SO #4 (long inline commands). Runs on every Bash tool call. |
| 2 | **Transcript analyzer** (`scripts/analyze-session.sh`): Post-hoc detection of SO #1, SO #4, and batch size violations in session JSONL files. |
| 3 | **Incident tracker**: Structured tracking of standing order violations with status stages (Observed → RCA → Remediated/Mitigated/Accepted → Verified) in `reference/claude-code-effectiveness.md`. 5 backfilled incidents (I1-I5). |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | High | **Duplicate hook bug**: `ConvertPSObjectToHashtable` didn't recurse into arrays — `ConvertFrom-Json` returns `Object[]` of `PSCustomObject`, causing find() to never match existing entries. Root cause of 13 duplicate SessionEnd hooks accumulating on re-runs. |
| 5 | Medium | **PowerShell array unwrapping**: Functions returning `@(single_item)` lose array wrapping. Fixed with comma operator `,@(...)`. |
| 6 | Medium | **Array normalization**: Existing corrupt data (from prior buggy writes) read as single object not array. Added normalization pass to force `[{}]` structure. |

### Improvements

| # | Change |
|---|--------|
| 7 | `setup-user-hooks.sh/.ps1`: `mergeHookEntry`/`MergeHookEntry` helpers with dedup, replacing brittle find/update. Manages both SessionEnd and PreToolUse hooks. |
| 8 | `check-post-push` step #5: Now verifies session archive health — directory exists, has .jsonl files, most recent within 7 days. |
| 9 | `build-deploy.sh`: `ps1_hashtable_helper` updated with array recursion fix. Deploy templates include standing-order-guard embed + mergeHookEntry with dedup. |
| 10 | Pre-commit step 13: Deploy template logic sync warning when `scripts/setup-user-*` changes without `build-deploy.sh`. |

### Files created

| File | Purpose |
|------|---------|
| `shared/hooks/standing-order-guard.sh` | PreToolUse hook source (deployed to `~/.claude/hooks/`) |
| `scripts/analyze-session.sh` | Standalone transcript analysis tool |

**Verified on:** Windows

---

## v0.25.2 -- Rule Hardening (2026-02-28)

### Improvements

| # | Change |
|---|--------|
| 1 | **Remove "gold standard" concept**: Existing scripts are reference examples, not authoritative. All references across 6 files (CLAUDE.md, script-standards, config-file-safety, tool-evaluation-criteria, + Cursor mirrors) replaced with "reference examples" language and explicit warning: "Do not assume existing scripts are violation-free." |
| 2 | **Broaden rule scope to plans and pseudocode**: script-standards.md and error-handling.md now state "all plans you propose and all reusable code you write" -- a plan that drafts code with violations is itself a violation. Incident I7 documented. |
| 3 | **PATH refresh rule**: tool-lifecycle.md now requires asking the user to relaunch Claude Code after package manager installs instead of invoking tools via hardcoded package manager paths. |

**Verified on:** Windows

---

## v0.25.1 -- Eliminate Deploy Template Duplication (2026-02-28)

### Improvements

| # | Change |
|---|--------|
| 1 | **`extract_between()` helper**: Perl-based sentinel extraction in `build-deploy.sh`. Extracts code between `# --- BEGIN/END ...` markers, with `--crlf` flag for PS1 output. Uses `m!...!` delimiter for JS sentinel compatibility. |
| 2 | **setup-user-cursor**: Replaced ~355 hardcoded template lines with 3 extraction zones + 1 preference replacement per platform. Sentinel markers in `.sh` and `.ps1`. |
| 3 | **setup-user-hooks**: Replaced ~375 hardcoded template lines with 4 extraction zones + 2 replacement zones per platform. Normalized `guardCmd` in `.sh` to match deploy pattern. Sentinel markers in `.sh` and `.ps1`. |
| 4 | **setup-user-claude**: Replaced hardcoded validation with extraction (2 zones per platform). Improved validation order (validate before declaring success). |
| 5 | **setup-user-mcp**: Migrated from sed to `extract_between()` for consistency. |
| 6 | **Incident I6 remediated**: Deploy template drift eliminated -- `build-deploy.sh` now reads setup logic from `scripts/` sources instead of maintaining parallel hardcoded copies. ~507 lines removed from `build-deploy.sh` (1588 → 1081). |

### Documentation

| # | Change |
|---|--------|
| 7 | Updated I6 status to Remediated in `reference/claude-code-effectiveness.md`. |
| 8 | Moved "Eliminate deploy template duplication" from ROADMAP Planned to Completed. |

**Verified on:** Windows

---

## v0.24 -- Repo Rename: ai-tooling to aitools (2026-02-28)

### New features

| # | Change |
|---|--------|
| 1 | **Repo renamed from `ai-tooling` to `aitools`**: Aligns repo name with CLI brand, eliminates the hyphen that caused a real bug in session path sanitization (v0.16 #8), and simplifies all paths. |
| 2 | **Config key renamed `aiToolingRepoPath` to `repoPath`**: Both CLI entry points (`aitools` bash + PS1) read `repoPath` first with fallback to `aiToolingRepoPath` for migration. Installer writes the new key. |
| 3 | **Shell marker updated to `# aitools shell integration`**: Installer detects and removes old `# ai-tooling shell integration` marker block before adding the new one. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 6 | High | Config migration gap: rename left stale `aiToolingRepoPath` in config.json; added auto-migration to both CLI entry points |
| 7 | Medium | Install resilience: all commands now clone fresh if repo path doesn't exist on disk (was gitpull-only) |
| 8 | Low | `sessions move` documented as archive-only (doesn't affect Claude Code session resolution) |

### Improvements

| # | Change |
|---|--------|
| 9 | Structured logging in CLI entry points (`scripts/aitools` + `.ps1`): `log`/`log_error`/`log_warn` helpers, error/warning messages logged to `deploy.log` |
| 10 | Fixed 6 pre-existing empty `catch{}` violations in node-e one-liners (standing order #7) |

### Documentation

| # | Change |
|---|--------|
| 4 | Updated ~30 files: README, CLAUDE.md, ROADMAP, shared/claude-shared.md, reference docs, rules, plans, check scripts, setup scripts, and RELEASE_NOTES GitHub issue URLs. |
| 5 | Cross-platform paths table in CLAUDE.md now uses tilde notation (`~/repos/aitools`, `~\repos\aitools`) instead of hardcoded `C:\repos\`. |

**Verified on:** Windows

---

## v0.23.1 -- PS1 First-Class Documentation (2026-02-28)

### Documentation

| # | Change |
|---|--------|
| 1 | **PS1 shown as full equal in all docs**: README.md, CLAUDE.md, scripts/README.md -- split mixed/bash-only blocks into labeled macOS/Linux + Windows (PowerShell) pairs. PS1 is never summarized, footnoted, or commented out. |

**Verified on:** Windows (extensive post-push checklist: 20 PASS, 1 SKIP).

---

## v0.23 -- PowerShell 7 Baseline (2026-02-28)

### New features

| # | Change |
|---|--------|
| 1 | **pwsh as managed tool on Windows**: Added to `tool-install-sources.md` (Windows: `supported`). Install via `winget install --id Microsoft.PowerShell --source winget`. |
| 2 | **PS 7 version guard in deploy scripts**: Generated deploy `.ps1` files (`setup-user-claude`, `setup-user-cursor`, `setup-user-hooks`) now error on PS 5.1 with install instructions. |
| 3 | **Bootstrap exception in `aitools-install.sh`**: On Windows, tries `pwsh` first; falls back to `powershell.exe` only to install pwsh via winget on fresh machines. |

### Improvements

| # | Change |
|---|--------|
| 4 | **All bash→PS dispatch migrated to `pwsh`**: `scripts/aitools`, `scripts/aitools-install.sh`, `scripts/check-pre-commit.sh`, `scripts/check-post-push.sh`, `scripts/build-deploy.sh` -- every `powershell.exe` dispatch call now uses `pwsh`. |
| 5 | **pwsh availability check**: `deploy_configs()` in `scripts/aitools` now validates pwsh is installed before dispatching, with a clear error message and install command. |

### Documentation

| # | Change |
|---|--------|
| 6 | **Rules updated for PS 7 baseline**: `.claude/rules/cross-platform.md` + `.cursor/rules/cross-platform.mdc` -- dispatch pattern uses `pwsh`, new "PS 7 baseline" section documents retained PS 5.1 workarounds as harmless, ASCII-only relaxed to preference, pipeline encoding downgraded to advisory. |
| 7 | **Checklist rules updated**: All 6 checklist rule files (pre-commit, pre-push, post-push in both `.claude/` and `.cursor/`) -- Windows invocation commands use `pwsh`. |
| 8 | **Shared content + project docs**: `shared/claude-shared.md`, `CLAUDE.md`, `reference/claude-code-windows-shell.md`, `.claude/commands/pre-update.md`, `scripts/README.md` -- all `powershell.exe` references updated to `pwsh`. |

**Verified on:** Windows (pwsh 7.5.4, all scripts syntax-validated via build-deploy.sh). macOS: not tested.

---

## v0.22 -- Error Handling Audit & Rust Support (2026-02-27)

### New features

| # | Change |
|---|--------|
| 1 | **Rust (cargo) as managed tool**: Full lifecycle -- setup scripts (`setup-rust.sh/.ps1`), installer integration, deploy scripts, shell aliases. Installs via `rustup` with non-preferred source cleanup. |
| 2 | **Error handling rules**: New `.claude/rules/error-handling.md` with project-level requirements. Full audit of all scripts for silent failures -- 5 violations fixed, 4 logic bugs caught, 1 missing error path added. |
| 3 | **File logging for check scripts**: All check scripts (`check-pre-commit`, `check-pre-push`, `check-post-push`) now write structured logs to `checks.log` and JSONL to `checks.jsonl` alongside existing `deploy.log`. Shared logging via `check-lib.sh/.ps1`. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | MEDIUM | **winget upgrade match string**: `setup-pandoc.ps1` used wrong match string for `winget upgrade`, causing silent no-op on Windows. |
| 5 | MEDIUM | **5 error suppression violations**: Scripts using `-ErrorAction SilentlyContinue`, `2>/dev/null`, or `|| true` without result checks. Each now has an immediate null/empty guard. |
| 6 | MEDIUM | **4 logic bugs from audit**: False passes in check scripts from unguarded `Get-ChildItem`/`Get-Content`, `StepPass` missing `$Detail` parameter, and step counts feeding into summaries without error handling. |
| 7 | LOW | **Missing error path**: One code path had no error handling for template read failure. Added content validation before write. |

### Improvements

| # | Change |
|---|--------|
| 8 | **OS guards for check scripts**: `.sh` check scripts now reject Windows (Git Bash) with a clear message directing to the `.ps1` variant. |
| 9 | **`StepPass` detail support**: `StepPass` in `check-lib.ps1` now accepts and displays a `$Detail` parameter, matching `StepFail`/`StepWarn`/`StepSkip`. |

### Documentation

| # | Change |
|---|--------|
| 10 | **gh-issue-7490 comment reference**: Added `reference/gh-issue-7490-comment.md` documenting the upstream GitHub comment for Windows shell tracking. |

**Verified on:** Windows (PS 5.1, all scripts syntax-validated). macOS: not tested.

---

## v0.21 -- Interactive Clobber Protection (2026-02-27)

### New features

| # | Change |
|---|--------|
| 1 | **`--dry-run` for all setup scripts**: Every setup script (.sh/.ps1) and the `aitools` CLI now support `--dry-run`/`-DryRun`. Preview mode shows what would change without writing files. Env passthrough via `AITOOLS_DRY_RUN=1`. |
| 2 | **Clobber detection**: Config-writing scripts detect when a merge would lose non-managed fields. Warns in dry-run, refuses in normal mode (requires `--force` to proceed). |
| 3 | **Corrupt file handling**: Config-writing scripts now refuse to proceed on corrupt/unparseable JSON (instead of silently starting fresh). Use `--force` to override. |
| 4 | **`--dry-run` for `aitools install`**: Both `aitools-install.sh` and `.ps1` support `--dry-run` flag, passing through to all child scripts. |

### Improvements

| # | Change |
|---|--------|
| 5 | **PS1 scripts node-free**: `setup-user-cursor.ps1`, `setup-user-hooks.ps1`, and `setup-user-claude.ps1` no longer require Node.js. Converted from `node -e` to native PowerShell using `ConvertPSObjectToHashtable`. |
| 6 | **Deploy scripts updated**: `build-deploy.sh` regenerates deploy scripts with native PS merge and flag support. Deploy `setup-user-cursor.ps1` and `setup-user-hooks.ps1` are now node-free. |
| 7 | **New build emitters**: `ps1_hashtable_helper()`, `bash_flag_helpers()`, `ps1_param_block()`, `ps1_flag_helpers()` in `build-deploy.sh` for consistent flag/helper generation. |
| 8 | **Standing orders consolidated**: Grouped 6 standing order bullets under `### Standing Orders` heading with single enforcement note in `shared/claude-shared.md`. |
| 9 | **Platform dispatch in checklists**: Pre-commit, pre-push, and post-push rule blockquotes now show both macOS and Windows commands with "never run `.sh` on Windows" reminder. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 10 | HIGH | **Git stderr crash in PS1 check scripts**: `$ErrorActionPreference = "Stop"` caused CRLF warnings from `git diff` to terminate the script. Added `InvokeGit` wrapper to `check-lib.ps1` that temporarily lowers the preference around git calls. |
| 11 | LOW | **Reference link audit false positive**: Step 13 regex captured trailing backticks from markdown-formatted `@reference/` mentions (e.g., `` `@reference/` ``). Stripped trailing punctuation from matches. |

### Documentation

| # | Change |
|---|--------|
| 12 | **CC version registry**: Updated to 2.1.62. All CRITICAL upstream issues (Windows shell) still open. |

**Verified on:** Windows (PS 5.1 native, all scripts syntax-validated, extensive post-push 19 PASS / 0 FAIL). macOS: not tested.

---

## v0.20 -- PS 5.1 Compatibility Fixes and Config Safety (2026-02-27)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | CRITICAL | **`ConvertFrom-Json -AsHashtable` (PS 6+ only)**: Replaced with `ConvertPSObjectToHashtable` helper in `setup-user-mcp.ps1` and `setup-cursor-ide-mcp.ps1`. On PS 5.1, the parameter error was caught as "invalid JSON", starting with empty `@{}` and silently clobbering all existing `settings.json`/`mcp.json` data. |
| 2 | CRITICAL | **`Join-Path` 3+ arguments (PS 6+ only)**: Chained to 2-arg calls in `setup-user-mcp.ps1` (4 instances) and `build-deploy.sh` heredoc (2 instances). Caused `A positional parameter cannot be found that accepts argument 'skills'` on PS 5.1. |
| 3 | HIGH | **`setup-user-hooks` missing from install flow**: Added to `aitools-install.ps1` and `.sh` deploy lists. Previously only deployed via `aitools` default command, not `aitools install`. |
| 4 | HIGH | **Empty `catch {}` in `setup-user-claude.sh`**: Replaced with ENOENT check to surface parse errors from malformed `config.json`. |

### Improvements

| # | Change |
|---|--------|
| 5 | **Config backup coverage**: Added 20-rotating backup (`Backup-File`/`backup_file`) to `setup-user-mcp` (settings.json) and `setup-user-cursor` (cli-config.json). Previously only `setup-user-claude` and `setup-cursor-ide-mcp` had backups. |
| 6 | **User repo auto-pull**: `aitools` default command and `aitools gitpull` now pull the user repo (quiet, non-blocking) before deploying configs. Prevents stale profile data when switching machines. |
| 7 | **Improved catch block messages**: All PS1 config merge catch blocks now report the actual exception instead of generic "invalid JSON" message. |

**Verified on:** Windows (PS 5.1 native, all setup scripts executed, merge preservation confirmed). macOS: not tested.

---

## v0.19 -- Checklist Verification Scripts (2026-02-26)

### New features

| # | Change |
|---|--------|
| 1 | **Automated checklist scripts**: `check-pre-commit.sh/.ps1` (12 steps, `--fix` mode), `check-pre-push.sh/.ps1` (10 steps, read-only), `check-post-push.sh/.ps1` (5 always + 15 extensive steps, `--extensive` flag). Shared library `check-lib.sh/.ps1` provides colored output, counters, and summary. Replaces ad-hoc bash commands with single-command checklists. |
| 2 | **pwsh as managed tool**: Added to `tool-install-sources.md` (macOS: supported, Windows: n/a). PS1 validation in check scripts and `build-deploy.sh` now uses pwsh on macOS. Rule files updated to treat pwsh as required. |
| 3 | **macOS PS1 validation in build pipeline**: `build-deploy.sh` now validates all generated `.ps1` files via `pwsh` on macOS (previously skipped). |

### Improvements

| # | Change |
|---|--------|
| 4 | **Invocation lifecycle field**: Added 5th required field to tool entries in `tool-install-sources.md`. Documents direct CLI command and anti-patterns per tool. |
| 5 | **Dual deployment path rules**: New `.claude/rules/deploy-paths.md` and `.cursor/rules/deploy-paths.mdc` codify the dev/repo vs MDM path equivalence requirement. |
| 6 | **3 coaching standing orders**: Checklist scripts (not ad-hoc commands), scratch files for complex bash, Perl for string manipulation. |
| 7 | **Script reference notes in rules**: Pre-commit, pre-push, and post-push rule files now reference the check scripts at the top. |

### Files created

| File | Purpose |
|------|---------|
| `scripts/check-lib.sh` | Shared library: colors, counters, step formatters, config reader |
| `scripts/check-lib.ps1` | PS1 equivalent |
| `scripts/check-pre-commit.sh` | 12 pre-commit steps with `--fix` mode |
| `scripts/check-pre-commit.ps1` | PS1 equivalent |
| `scripts/check-pre-push.sh` | 10 pre-push steps, read-only |
| `scripts/check-pre-push.ps1` | PS1 equivalent |
| `scripts/check-post-push.sh` | 5 always + 15 extensive steps |
| `scripts/check-post-push.ps1` | PS1 equivalent |
| `.claude/rules/deploy-paths.md` | Dual deployment path rules |
| `.cursor/rules/deploy-paths.mdc` | Cursor equivalent |

**Verified on:** macOS (bash -n, pwsh ParseFile, all check scripts executed). Windows: PS1 validated via pwsh on macOS (not tested natively).

---

## v0.18 -- Release Notes Gate for Version Tagging (2026-02-26)

### New features

| # | Change |
|---|--------|
| 1 | **Release notes enforcement in gitpull**: `aitools gitpull` now checks RELEASE_NOTES.md for a matching `## vX.Y` heading before creating a version tag. If no entry exists, tagging is skipped with a yellow warning and instructions. Prevents tags without release notes (as happened with v0.17.0). Both bash and PowerShell entry points enforce the gate. |

### Improvements

| # | Change |
|---|--------|
| 2 | **Pre-update command warns about missing release notes**: `/pre-update` now flags when remote commits would trigger a tag but RELEASE_NOTES.md has no matching entry. Options table notes the requirement. |
| 3 | **Pre-commit and post-push rules updated**: Step 9 (release notes) strengthened to reference the automated enforcement. Post-push version tag section notes that gitpull now handles this automatically. Mirrored in `.cursor/rules/`. |

**Verified on:** macOS (bash -n, deploy syntax OK). Windows: PS1 not validated locally (tested: macOS).

---

## v0.17.1 -- Deploy Hooks to ~/.claude/hooks/ (2026-02-26)

### New features

| # | Change |
|---|--------|
| 1 | **deploy/ variant for setup-user-hooks**: `build-deploy.sh` now generates `deploy/setup-user-hooks.sh` and `.ps1` with embedded hook script and claude preferences. MDM-only machines (no repo) now get session archive hooks and preferences. Build produces 14 scripts (was 12). |
| 2 | **Hook deployed to ~/.claude/hooks/**: Setup scripts copy `shared/hooks/session-archive.sh` to `~/.claude/hooks/session-archive.sh` and point the `settings.json` hook command to the deployed copy. Follows the same deployed-copy pattern as skills and CLAUDE.md. |

### Documentation

| # | Change |
|---|--------|
| 3 | **user-repo.md updated**: Archiving Mechanism section now documents the deployed-copy pattern for hooks. |

### Files created

| File | Purpose |
|------|---------|
| `deploy/setup-user-hooks.sh` | Self-contained hook + preferences deploy (macOS/Linux) |
| `deploy/setup-user-hooks.ps1` | Self-contained hook + preferences deploy (Windows) |

**Verified on:** macOS (bash -n, both variants run, identical settings.json output). Windows: PS1 syntax not validated (pwsh not available), functional test deferred (tested: macOS).

---

## v0.17.0 -- CC Version Tracking Registry (2026-02-24)

### New features

| # | Change |
|---|--------|
| 1 | **Claude Code version dependency registry**: `reference/claude-code-version-deps.md` tracks version-dependent workarounds with severity tiers (CRITICAL/HIGH/MEDIUM/LOW), baseline versions, and upstream issue links. Post-push checklist #20 triggers review on CC upgrades. |

### Documentation

| # | Change |
|---|--------|
| 2 | **user-repo.md expanded**: Added Config Schema section (v2), session archive hook contract, template resolution docs. |

**Verified on:** macOS. Documentation only -- no scripts modified.

---

## v0.16.2 -- Config.json Version Bump to v2 (2026-02-22)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Low | **config.json stuck at v1**: `aitools-install.sh/.ps1` wrote `"version": 1` even after `userRepoPath` and `machineAlias` fields were added in v0.15. Bumped to `"version": 2` to match actual schema. |

### Documentation

| # | Change |
|---|--------|
| 2 | **Config schema documented**: `reference/user-repo.md` now has a full Config Schema section (v1 and v2) with field descriptions and migration notes. Follows the same pattern as the Profile Schema section. |

**Verified on:** macOS (bash -n, pwsh parse). Windows: PS1 syntax validated via pwsh, functional test deferred (tested: macOS).

---

## v0.16.1 -- User-Scope CLAUDE.md Migration (2026-02-22)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Medium | **Placeholder bug**: `scripts/setup-user-claude.sh/.ps1` read `shared/claude-shared.md` raw without interpolating `{{PLACEHOLDER}}` tokens. `~/.claude/CLAUDE.md` contained literal `{{PROFILE_NAME}}` etc. Fixed by adding profile.json interpolation (same pattern as `build-deploy.sh`). |

### New features

| # | Change |
|---|--------|
| 2 | **User repo CLAUDE.md template**: Personal preferences now live in `<userRepoPath>/claude/CLAUDE.md` (dotfile repo), synced across machines via git. Setup scripts read from user repo first, fall back to `shared/claude-shared.md`. |
| 3 | **Scaffold in `user init`**: `aitools user init` copies `shared/claude-shared.md` to `<userRepoPath>/claude/CLAUDE.md` if missing, keeping placeholders for per-machine interpolation at deploy time. |

### Files created

| File | Purpose |
|------|---------|
| `<userRepoPath>/claude/CLAUDE.md` | Personal CLAUDE.md template with `{{PLACEHOLDER}}` tokens |

**Verified on:** macOS (bash -n, pwsh parse, setup-user-claude.sh live run with resolved placeholders). Windows: PS1 syntax validated via pwsh, functional test deferred (tested: macOS).

---

## v0.16 -- Profile Validation & v1 Migration (2026-02-22)

### New features

| # | Change |
|---|--------|
| 1 | **Profile validation**: `scripts/profile-check.js` -- standalone Node.js script that reads `config.json`, locates `profile.json`, validates v2 fields (identity, profiles, machine match), and outputs structured JSON. Detects v1 profiles needing migration, missing fields, corrupt JSON, and alias mismatches. |
| 2 | **Profile check in sync/install flows**: `aitools` (no-args sync) and `aitools install` now run profile validation after deploy. Healthy v2 profiles produce no output. Issues show yellow warnings. v1 profiles prompt for interactive migration. Non-interactive terminals fall back to warn-only. |
| 3 | **v1-to-v2 interactive migration**: When a v1 profile is detected, the user is prompted for a machine alias (the only field not in v1). Migration preserves non-v1 sections (e.g., `cursor` preferences), handles multiple v1 machines, commits and pushes the user repo. Available in `aitools` sync, `aitools install`, and `aitools user init`. |
| 4 | **v1 detection in `user init`**: Paths 1 (repo exists) and 2 (GitHub clone) now detect v1 profiles and auto-trigger migration before proceeding with the existing v2 machine-addition flow. |

### Improvements

| # | Change |
|---|--------|
| 5 | **Standing order for dedicated tools**: Added to `shared/claude-shared.md` -- Use Read/Edit/Write/Grep/Glob for all file operations, never Bash equivalents. Elevated from coaching to standing order. |

### Files created

| File | Purpose |
|------|---------|
| `scripts/profile-check.js` | Standalone profile validation script (read-only, JSON output) |

**Verified on:** macOS (bash -n, pwsh parse, profile-check.js with live v2 profile, aitools sync smoke test). Windows: PS1 syntax validated via pwsh, functional test deferred (tested: macOS).

---

## v0.15.2 -- Post-Write Config Validation (2026-02-21)

### New features

| # | Change |
|---|--------|
| 1 | **Post-write validation for all config writers**: Every script that writes a config file now validates output immediately after writing. JSON configs are checked for valid parse, required keys, and double-slash paths. CLAUDE.md is checked for non-empty content and required sections. Catches malformed output at write time instead of by manual inspection. |
| 2 | **`validate_json_config` (bash) / `ValidateJsonConfig` (PS1)**: Reusable validation functions added to `aitools-install.sh/.ps1`. Uses `python3` (primary) or `node` (fallback) for JSON parsing, plus `grep` for required keys and a Python walker for double-slash path detection. |

### Improvements

| # | Change |
|---|--------|
| 3 | **Config write safety rule updated**: `.claude/rules/config-file-safety.md` and `.cursor/rules/config-file-safety.mdc` now document post-write validation as a requirement alongside read-then-merge, with gold standard references. |

### Files modified (17 write sites across 14 scripts)

| Script | Config validated | Method |
|--------|----------------|--------|
| `scripts/aitools-install.sh` | `config.json` | `validate_json_config` function |
| `scripts/aitools-install.ps1` | `config.json` | `ValidateJsonConfig` function |
| `scripts/setup-user-mcp.sh` | `settings.json` | Inline Node.js |
| `scripts/setup-user-mcp.ps1` | `settings.json` | Inline PS1 try/catch |
| `scripts/setup-user-hooks.sh` | `settings.json` | Inline Node.js |
| `scripts/setup-user-hooks.ps1` | `settings.json` | Inline Node.js |
| `scripts/setup-cursor-ide-mcp.sh` | `mcp.json` | Inline Node.js |
| `scripts/setup-cursor-ide-mcp.ps1` | `mcp.json` | Inline PS1 try/catch |
| `scripts/setup-user-cursor.sh` | `cli-config.json` | Inline Node.js |
| `scripts/setup-user-cursor.ps1` | `cli-config.json` | Inline Node.js |
| `scripts/setup-user-claude.sh` | `CLAUDE.md` | Inline bash checks |
| `scripts/setup-user-claude.ps1` | `CLAUDE.md` | Inline PS1 checks |
| `scripts/aitools` | `config.json`, `settings.local.json` | Inline Node.js |
| `scripts/aitools.ps1` | `config.json`, `settings.local.json` | Inline Node.js |
| `scripts/build-deploy.sh` | Generated deploy scripts | Embedded validation in templates |

**Verified on:** macOS (bash -n on all scripts, deploy/ rebuilt and verified)

---

## v0.15.1 -- Config Write Safety (2026-02-21)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | Medium | `setup-cursor-ide-mcp.sh/.ps1` now merges managed servers into `~/.cursor/mcp.json` instead of overwriting. User-added MCP servers are preserved across re-runs. |
| 2 | Low | Empty `catch {}` blocks in inline Node.js across all setup scripts and CLI now warn on corrupt JSON instead of silently starting with empty config. ENOENT (file missing) still starts fresh silently. |
| 5 | Medium | `aitools user init` (Path 1: repo already exists) now auto-detects `machineAlias` from `profile.json` by hostname match instead of leaving it empty. Hostname comparison uses short name (strips DNS suffix) to handle `Joses-MBP` vs `Joses-MBP.lax`. Same fix applied to `build-deploy.sh` profile lookup fallback. |

### New features

| # | Change |
|---|--------|
| 3 | **Config write safety rule** (`.claude/rules/config-file-safety.md`): codifies read-then-merge as the default for JSON config writes, documents managed vs preserved fields pattern, and flags empty `catch {}` as an anti-pattern. |
| 4 | **Pre-commit step 8** (config merge safety): verifies setup scripts use read-then-merge before committing. **Post-push step 19** (config merge audit): flags blind overwrites in extensive audits. |

**Verified on:** macOS

---

## v0.15 -- Standalone Chrome DevTools Skills (2026-02-21)

### New features

| # | Change |
|---|--------|
| 1 | **Standalone Chrome DevTools skills**: Vendored `chrome-devtools` and `a11y-debugging` SKILL.md files from upstream repo into `shared/skills/`. Deployed to `~/.claude/skills/` by `setup-user-mcp`. Replaces the Claude Code plugin (which bundled MCP config without `--isolated`). |
| 2 | **Self-contained skill deployment**: `build-deploy.sh` embeds skill content inline in deploy scripts via heredocs. Deploy scripts need no sibling files. |

### Improvements

| # | Change |
|---|--------|
| 3 | **Build script CRLF handling**: `build-deploy.sh` now strips CR before sed pattern matching on PS1 source files, fixing broken template extraction on macOS. |

### Documentation

| # | Change |
|---|--------|
| 4 | Updated `reference/tool-install-sources.md`: replaced plugin install section with standalone skills, added source URLs. |
| 5 | Updated `reference/cursor-practices.md`: skills section now reflects deployed Chrome DevTools skills. |
| 6 | Updated `shared/mcp/README.md`: plugin section replaced with skills section. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 7 | Medium | **Installer clobbers `userRepoPath`/`machineAlias`**: `aitools install` step 5 overwrote `config.json` with only 4 managed keys, dropping `userRepoPath` and `machineAlias` set by `aitools user init`. This caused downstream deploys (e.g., `setup-user-cursor`) to lose profile-driven preferences like `vimMode`. Both `.sh` and `.ps1` installers now preserve these keys. |

### Files created

| File | Purpose |
|------|---------|
| `shared/skills/chrome-devtools/SKILL.md` | Vendored browser automation & debugging skill |
| `shared/skills/a11y-debugging/SKILL.md` | Vendored accessibility auditing skill |

**Verified on:** macOS (bash -n, build-deploy.sh, setup-user-mcp.sh run, skills deployed to ~/.claude/skills/). Windows: deferred (tested: macOS).

---

## v0.14 -- Version Scheme Reset, Git Checklist Improvements (2026-02-21)

### Improvements

| # | Change |
|---|--------|
| 1 | **Version scheme reset**: Replaced date-based tags (`v2026-02-17.3.0`) with clean incremental versions (`v0.14.0`, `v0.15.0`). Continuity from v3.13 -- next `gitpull` creates v0.15.0. |
| 2 | **Pre-commit: PS1 validation on macOS**: When `pwsh` is installed, PS1 scripts are now validated on macOS too, not just Windows. |
| 3 | **Pre-commit: conditional platform note**: Platform note (`tested: macOS`) now only required when `.sh` or `.ps1` files are in the commit. Pure docs/markdown commits can omit it. |
| 4 | **Pre-commit: release notes gate**: New step 8 requires a `RELEASE_NOTES.md` entry when committing features, bug fixes, or behavioral changes. |
| 5 | **Pre-commit: deploy drift check**: New step 9 verifies no unstaged deploy/ changes remain after build freshness step. |
| 7 | **Pre-push: credential scan**: Moved credential/secret scan from post-push Extensive #14 to pre-push #3. Catches secrets before they leave the machine. |
| 8 | **Pre-push: WIP commit check**: New step #4 rejects `WIP`, `fixup!`, `squash!`, and `TODO` prefix commits before push. |
| 9 | **Pre-push: commit count check**: New step #8 pauses for review when pushing >5 commits. |
| 10 | **Pre-push: simplified cross-references**: Steps 5 (release notes) and 7 (deploy/) now reference pre-commit steps instead of re-describing the check. |
| 11 | **Post-push: read-only MCP check**: Always tier #3 changed from running setup scripts to grep-based verification. Full setup scripts moved to Extensive tier #14. |
| 12 | **Post-push: version consistency**: Always tier #4 now also verifies `aitools --version` matches the latest git tag. |
| 13 | **Post-push: pwsh validation on macOS**: Extensive #5 now notes that PS1 files can be validated on macOS when `pwsh` is installed. |
| 14 | **Session archive warnings**: `aitools` (no-args sync) now warns when the session archive hook is installed but `userRepoPath` is not configured. Previously only checked if the hook was installed. Same warning in `aitools.ps1`. |
| 15 | **Install hint for session archive**: `aitools install` now prints a hint about `aitools user init` when `userRepoPath` is missing. Same hint in `aitools-install.ps1`. |
| 16 | **Post-push Always #5**: New "Session archive readiness" check promoted to Always tier. Detects inactive session archive without running the full Extensive audit. |

### Documentation

| # | Change |
|---|--------|
| 6 | Updated version examples in `RELEASE_NOTES.md`, `.claude/rules/documentation-standards.md`, and `.cursor/rules/documentation-standards.mdc` to reflect new `v0.x` scheme. |

**Verified on:** macOS (bash -n on both scripts, build-deploy.sh rebuilt). Windows: deferred.

---

## v3.13 -- Plugin Docs, Overrides Framework, Web Source Rule (2026-02-21)

### New features

| # | Change |
|---|--------|
| 1 | **Overrides framework**: New section in `reference/tool-install-sources.md` documenting intentional deviations from upstream defaults (e.g., `--isolated` flag for Chrome DevTools MCP). Prevents audit false positives. |
| 2 | **Chrome DevTools MCP plugin docs**: Documented `/plugin install chrome-devtools-mcp` as optional install method that adds structured skills (`chrome-devtools`, `a11y-debugging`). Updated lifecycle Post-Install Config field. |
| 3 | **Web source reading rule**: New `.claude/rules/web-sources.md` and `.cursor/rules/web-sources.mdc` codifying preference for Chrome DevTools MCP skill over WebFetch when reading official docs for source-of-truth files. |
| 4 | **Profile v2 overrides schema**: Extended `reference/user-repo.md` with `overrides` key for machine-readable tracking of intentional config deviations. Informational only -- CLI integration deferred. |

### Improvements

| # | Change |
|---|--------|
| 5 | **User-level MCP skill preference**: Added Chrome DevTools MCP skill preference bullet to `shared/claude-shared.md`, propagated to deploy scripts. |
| 6 | **MCP README plugin note**: Added plugin install note to `shared/mcp/README.md` with `--isolated` precedence explanation. |

### Files created

| File | Purpose |
|------|---------|
| `.claude/rules/web-sources.md` | Web source reading rule (Claude Code) |
| `.cursor/rules/web-sources.mdc` | Web source reading rule (Cursor) |

**Verified on:** macOS (bash -n on all deploy scripts, build-deploy.sh rebuilt). Windows: deferred.

---

## v3.12.1 -- clip2md Plain Text Support (2026-02-20)

### New features

| # | Change |
|---|--------|
| 1 | **clip2md plain text fallback**: When no HTML is on the clipboard, `clip2md` now falls back to plain text. Plain text skips pandoc entirely -- saved as-is. Useful for terminal output, code snippets, and plain notes. Status messages show source type: `(HTML, ~XXX words)` or `(text, ~XXX words)`. |

### Improvements

| # | Change |
|---|--------|
| 2 | **Pandoc check moved inside HTML branch**: `clip2md` no longer requires pandoc when saving plain text. Pandoc is only checked when HTML content is detected. |

**Verified on:** Windows (bash -n + ParseFile validated). macOS: deferred.

---

## v3.12 -- Bug Fixes, v2 Profiles, Template Interpolation (2026-02-20)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | **git pull failure misdiagnosis** ([#1](https://github.com/nobul-jose/aitools/issues/1)): Any non-zero `git pull` exit was reported as "Could not reach remote". Real cause (e.g., dirty `deploy/` files) was hidden. Fix: reset generated `deploy/` before pull; distinguish network errors from other failures in both scripts. |
| 2 | BUG | **user init existing repo failure** ([#2](https://github.com/nobul-jose/aitools/issues/2)): `gh repo create` failed silently when repo already existed on GitHub. Local repo had no remote, no push. Fix: rewritten `user init` with 3-path flow (local exists / GitHub exists / fresh). |

### New features

| # | Change |
|---|--------|
| 3 | **v2 profile creation in user init**: Fresh repos now create v2 `profile.json` with `version`, `identity`, and per-machine `profiles` sections. Includes machine alias prompt. |
| 4 | **Multi-machine user init**: When GitHub repo exists but no local clone, `user init` clones it, prompts for machine alias, adds a new profile entry, commits, and pushes. |
| 5 | **Phase B template interpolation**: `shared/claude-shared.md` uses `{{PLACEHOLDER}}` tokens for identity fields. `build-deploy.sh` reads `profile.json` via config and interpolates at build time. Fallback to hardcoded defaults if profile unavailable. |

### Improvements

| # | Change |
|---|--------|
| 6 | **Windows tool discovery rule**: Added to `shared/claude-shared.md` -- documents that `which`/`command -v` in Git Bash misses Windows PATH tools; use `powershell.exe Get-Command` instead. |
| 7 | **GitHub issue tracking convention**: Added to `shared/claude-shared.md` -- when bugs are referenced, check the repo's GitHub issues for full context. |
| 8 | **machineAlias in config**: `user init` now writes `machineAlias` to `~/.aitools/config.json` alongside `userRepoPath`. Used by build-deploy.sh to select the correct profile. |

**Verified on:** Windows (bash -n + ParseFile validated on all scripts, deploy/ rebuilt and verified). macOS: scripts updated but not validated on this machine.

---

## v3.11 -- Cleanup & Deprecations (2026-02-19)

### Deprecated

| # | Change |
|---|--------|
| 1 | **Cursor User Rules clipboard workflow removed**: `setup-user-cursor` scripts no longer copy `user-rules.md` to clipboard or open the file. Cursor project rules (`.cursor/rules/*.mdc`) auto-load and cover the same ground. The source file `shared/cursor-rules/user-rules.md` is retained as reference. |

### Removed

| # | Change |
|---|--------|
| 2 | **`docs/` folder removed**: Vendor-specific PDFs and markdown conversions (4.7 MB, mostly StorNext/Quantum). Copies exist elsewhere. |
| 3 | **`conversionutils/` folder removed**: Legacy PDF-to-markdown utilities superseded by Marker. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | BUG | `setup-user-cursor.sh/.ps1` now have exit footers that check the error counter and exit with code 1 on failure. Previously, scripts exited 0 regardless of errors. |

### Documentation

| # | Change |
|---|--------|
| 5 | `reference/cursor-practices.md`: User Rules section updated to note deprecated workflow. |
| 6 | `CLAUDE.md`: Removed `docs/` and `conversionutils/` from project structure, removed legacy PDF conversion usage examples, simplified Marker key decision. |
| 7 | `README.md`: Removed `docs/` and `conversionutils/` directory rows, removed PDF conversion section. |
| 8 | `reference/session-showcase.md`: Removed `docs/` from repo structure, updated Cursor setup description. |

**Verified on:** macOS (bash -n validated on all .sh scripts, deploy/ rebuilt). Windows: PS1 scripts updated but not validated on this machine.

---

## v3.10 -- Audit & Governance Rules (2026-02-19)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `setup-vercelcli.sh/.ps1` and `setup-pandoc.sh/.ps1` now track errors via `ERRORS`/`$errors` counter and exit with code 1 on failure. Previously, `log_error()` only logged -- scripts silently exited 0 even when errors occurred. |

### New rules

| # | Change |
|---|--------|
| 2 | **Script standards** (`.claude/rules/script-standards.md` + `.cursor/rules/script-standards.mdc`): Codifies block order, error tracking requirement, logging helpers, exit footer, and gold standard references for all setup scripts. |
| 3 | **Documentation standards** (`.claude/rules/documentation-standards.md` + `.cursor/rules/documentation-standards.mdc`): Codifies RELEASE_NOTES format, version numbering, ROADMAP format, reference doc threshold, and when to create plans. |

### Improvements

| # | Change |
|---|--------|
| 4 | **Pre-commit checklist enhanced** (items 6-7): Added executable bit check (`git ls-files -s '*.sh' | grep -v '^100755'`) and install command consistency check (verify against `tool-install-sources.md`). |
| 5 | **Tool lifecycle rule enhanced**: Added lifecycle field completeness check (all 4 fields required) and Under Evaluation guard (evaluating-only tools must not have setup scripts, installer entries, aliases, or build pipeline entries). |

### Documentation

| # | Change |
|---|--------|
| 6 | `reference/cursor-practices.md`: Rule Correspondence table updated with 2 new rule pairs. |
| 7 | `CLAUDE.md`: Gold standard reference updated from setup-vercelcli to setup-user-mcp. Documentation standards key decision added. |

### Files created

| File | Purpose |
|------|---------|
| `.claude/rules/script-standards.md` | Script standards rule (Claude Code) |
| `.cursor/rules/script-standards.mdc` | Script standards rule (Cursor, condensed) |
| `.claude/rules/documentation-standards.md` | Documentation standards rule (Claude Code) |
| `.cursor/rules/documentation-standards.mdc` | Documentation standards rule (Cursor, condensed) |

**Verified on:** macOS (bash -n validated on all .sh scripts, deploy/ rebuilt). Windows: PS1 scripts updated but not validated on this machine.

---

## v3.9 -- MCP Concurrency, Cursor Rule Parity, Tool Lifecycle Fields (2026-02-19)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | Chrome DevTools MCP now uses `--isolated` flag across all setup scripts (Claude Code and Cursor, macOS and Windows). Creates throwaway temp Chrome profiles per process, preventing Chrome profile lock conflicts when Claude Code and Cursor run concurrently. |

### Improvements

| # | Change |
|---|--------|
| 2 | **Tool lifecycle entries standardized**: All managed tools in `reference/tool-install-sources.md` now include 4 mandatory fields: Platform Status, Concurrency, Post-Install Config, Dependencies. Phase 1 recording requirements updated in `reference/tool-evaluation-criteria.md`. |
| 3 | **Cursor project rules parity**: Created 4 new `.cursor/rules/*.mdc` files mirroring Claude Code rules: `sources-of-truth.mdc`, `tool-lifecycle.mdc`, `cross-platform.mdc`, `concurrent-agents.mdc`. Updated `general.mdc` (moved cross-platform to dedicated file). |
| 4 | **Concurrent agent coordination**: New rule (`.claude/rules/concurrent-agents.md` + `.cursor/rules/concurrent-agents.mdc`) for multi-agent codebase editing awareness. |
| 5 | **Protected files expanded**: `.cursor/rules/*.mdc` added to source-of-truth protected files table. Agent column added for future ownership restrictions. |
| 11 | **Pre-commit/pre-push/post-push checklists**: New rules for all three git lifecycle stages (`.claude/rules/` + `.cursor/rules/` mirrors). Pre-commit: identity, syntax, build freshness, line endings, platform note. Pre-push: scratch files, release notes, roadmap, deploy freshness, branch hygiene. Post-push: two tiers (Always + Extensive) with 17 audit items and flag disposition protocol. |

### Documentation

| # | Change |
|---|--------|
| 6 | `shared/mcp/README.md`: New "Concurrency" and "Post-Setup Authentication" sections. Prominently notes Vercel/Webflow OAuth requirement. |
| 7 | `reference/cursor-practices.md`: New "Rule Correspondence" table mapping Claude Code to Cursor rules, with "Changing rules" workflow. |
| 8 | `reference/tool-install-sources.md`: Chrome DevTools MCP install commands updated to include `--isolated`. All tool entries expanded with lifecycle fields. |
| 9 | `CLAUDE.md`: Two new key decisions (`--isolated` for stdio MCP, 4 lifecycle fields). Project structure expanded to show `.cursor/rules/` files. |
| 10 | Deleted `plans/cursor-vs-claude-code-rules-blueprint.md` (absorbed into `reference/cursor-practices.md`). |

### Files created

| File | Purpose |
|------|---------|
| `.claude/rules/concurrent-agents.md` | Concurrent agent coordination rule (Claude Code) |
| `.cursor/rules/sources-of-truth.mdc` | Protected files review gate (Cursor) |
| `.cursor/rules/tool-lifecycle.mdc` | Tool lifecycle gate (Cursor) |
| `.cursor/rules/cross-platform.mdc` | Cross-platform rules (Cursor, condensed) |
| `.cursor/rules/concurrent-agents.mdc` | Concurrent agent coordination rule (Cursor) |
| `.claude/rules/pre-commit.md` | Pre-commit checklist (Claude Code) |
| `.claude/rules/pre-push.md` | Pre-push checklist (Claude Code) |
| `.claude/rules/post-push.md` | Post-push audit checklist (Claude Code) |
| `.cursor/rules/pre-commit.mdc` | Pre-commit checklist (Cursor) |
| `.cursor/rules/pre-push.mdc` | Pre-push checklist (Cursor) |
| `.cursor/rules/post-push.mdc` | Post-push audit checklist (Cursor) |

**Verified on:** macOS (build validated, all setup scripts syntax-checked). Windows: PS1 MCP setup scripts updated but not validated on this machine.

---

## v3.8 -- Session Auto-Archive & User Repo (2026-02-19)

### New features

| # | Change |
|---|--------|
| 1 | **Session auto-archive**: Claude Code `SessionEnd` hook copies session transcripts to a private user repo (`aitools-<username>`) after each session ends. Files are organized by project under `sessions/<project>/<date>_<prefix>.jsonl`. Hook runs silently, never blocks Claude Code, and performs no git operations. |
| 2 | **`aitools user init`**: Interactive setup for the user repo -- detects GitHub username, creates repo with `profile.json` and `sessions/` structure, optionally creates a private GitHub repo, writes `userRepoPath` to config, and deploys the session archive hook. |
| 3 | **`aitools sessions list [project]`**: Lists archived sessions with file sizes, optionally filtered by project name. |
| 4 | **`aitools sessions archive <id>`**: Manually archives a specific session by ID (full UUID or prefix). Reads CWD from the JSONL transcript to derive the correct project name. |
| 5 | **`aitools sessions move <file> <project>`**: Refiles an archived session under a different project. Handles the case where CWD didn't match the actual project being worked on. |
| 6 | **Hook auto-deploy**: `setup-user-hooks.sh/.ps1` added to the deploy pipeline. Running `aitools` (no args) now installs/updates the hook in `~/.claude/settings.json` and shows a hint if the user repo isn't set up yet. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 7 | BUG | `aitools user init` (bash) now dispatches to `.ps1` on Windows for hook deployment. Previously called `setup-user-hooks.sh` which has an OS guard that rejects Windows. |
| 8 | BUG | `sessions archive` project derivation: Claude Code stores sessions in directories named by replacing `/` with `-` in the CWD path, which is lossy for project names containing hyphens (e.g., `ai-tooling` became `tooling`). Fixed by reading the actual `cwd` from the JSONL transcript via node instead of parsing the ambiguous directory name. |

### Documentation

| # | Change |
|---|--------|
| 9 | New `reference/user-repo.md`: documents the user repo pattern, naming convention, session naming, project derivation, and CLI commands. |
| 10 | `plans/user-repo-and-session-hooks.md`: status updated to "Phase A implemented", open questions resolved (hook schema, jq dependency, project derivation). |
| 11 | `shared/claude-shared.md`: strengthened "Smaller batches" coaching bullet (rules ignored when batch size causes focus to narrow); added "Subagent context gap" coaching bullet (subagents don't inherit project rules). |
| 12 | `reference/claude-code-practices.md`: new "Session Storage Internals" section documenting `~/.claude/projects/` storage scheme, lossy path sanitization, and JSONL transcript structure. |
| 13 | `reference/claude-code-effectiveness.md`: progress log entry for v3.8 implementation lessons. |

### Bug fixes (follow-up)

| # | Severity | Fix |
|---|----------|-----|
| 14 | BUG | Restored executable bits on `setup-user-hooks.sh` and `session-archive.sh` — the Write tool dropped them during initial creation. |

### Files created

| File | Purpose |
|------|---------|
| `shared/hooks/session-archive.sh` | SessionEnd hook script (bash-only, runs on both platforms) |
| `scripts/setup-user-hooks.sh` | Deploys hook config to `~/.claude/settings.json` (macOS/Linux) |
| `scripts/setup-user-hooks.ps1` | Same for Windows |
| `reference/user-repo.md` | User repo pattern documentation |

**Verified on:** macOS (hook, setup, all CLI commands tested end-to-end). Windows untested (PS1 scripts not validated on this machine).

---

## v3.7 -- Tool Lifecycle Terminology & Verified-on Convention (2026-02-18)

### Improvements

| # | Change |
|---|--------|
| 1 | **4-state tool lifecycle per platform**: Replaced the 3-value model (`approved`/`pending`/`n/a`) with a 4-state lifecycle (`evaluating` → `approved` → `supported`, plus `n/a`). The new intermediate `approved` state distinguishes "user said yes" from "fully scripted with setup scripts." Canonical definition in `reference/tool-evaluation-criteria.md`. |
| 2 | **"Tested on" → "Verified on" convention**: Renamed `**Tested on:**` to `**Verified on:**` across all release notes (9 instances). Eliminates overloading: "verified" means release changes were checked on this platform; "approved"/"supported" describe tool lifecycle status. Convention section renamed accordingly. |

### Tool status (under new terminology)

| Tool | macOS | Windows |
|------|-------|---------|
| Claude Code CLI | supported | supported |
| Vercel CLI | supported | supported |
| Cursor Agent CLI | supported | supported |
| Node.js | supported | supported |
| Pandoc | supported | supported |
| MCP servers (chrome-devtools, vercel, webflow) | supported | supported |
| Typst | evaluating | evaluating |

### Documentation

| # | Change |
|---|--------|
| 3 | `reference/tool-evaluation-criteria.md`: new "Tool Platform States" section defining the 4 states and their mapping to lifecycle phases. |
| 4 | `CLAUDE.md`: new key decision for tool platform states and verified-on convention. |
| 5 | `.claude/rules/cross-platform.md`: `tested-platform` → `verified-platform` reference. |
| 6 | `plans/per-platform-tool-approval.md`: updated from 3-value to 4-state model, resolved open questions (inline status, installer warnings are future scope). |
| 7 | `RELEASE_NOTES.md` v3.6 item #2: updated to reference 4-state model. |

**Verified on:** macOS. Windows not affected (documentation-only changes).

---

## v3.6 -- Roadmap System & Typst Evaluation (2026-02-18)

### New features

| # | Change |
|---|--------|
| 1 | **Roadmap tracking system**: `ROADMAP.md` at project root tracks active/planned work items with links to detailed plans in `plans/`. Completed items move to `RELEASE_NOTES.md`. |
| 2 | **Per-platform tool approval plan filed**: First roadmap item — detailed plan for separating tool approval pipelines per platform (macOS/Windows). Introduces a 4-state lifecycle model (`evaluating`/`approved`/`supported`/`n/a`) per platform. Plan only, no implementation yet. |

### Tool evaluation

| # | Change |
|---|--------|
| 3 | **Typst** added to "Under Evaluation" in `reference/tool-install-sources.md`. PDF engine for pandoc (`--pdf-engine=typst`) — single ~30-50 MB binary vs multi-GB LaTeX distributions. Pending hands-on testing before approval. |

### Documentation

| # | Change |
|---|--------|
| 4 | `CLAUDE.md`: added `plans/` to project structure, added roadmap tracking key decision. |
| 5 | `.claude/rules/sources-of-truth.md`: `ROADMAP.md` and `plans/*.md` added to protected files table. |
| 6 | Deploy scripts (`setup-user-claude.sh/.ps1`) rebuilt with coaching notes from `shared/claude-shared.md`. |

**Verified on:** macOS. Windows not affected (documentation-only changes; deploy scripts are generated output).

---

## v3.5.1 -- clip2md macOS fixes (2026-02-18)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (bash) crashed with `tr: Illegal byte sequence` on macOS, preventing auto-naming. Root cause: `perl -pe` without `-CSD` flag can't match multi-byte Unicode characters. `\x{00A0}` (NBSP) only replaced the `\xa0` byte, leaving an orphaned `\xc2` that corrupted the output. `\x{202F}` (narrow NBSP) was not matched at all. Fixed by adding `-CSD` (UTF-8 I/O mode) to the perl invocation. |
| 2 | BUG | `clip2md` and `cc` overwrite/init prompts failed in zsh with `read:NNN: -p: no coprocess`. Root cause: `read -rp "prompt"` is bash-only; in zsh `-p` means coprocess. Fixed by splitting into `printf "prompt"` + `read -r answer`, which works in both shells. |

### Documentation

| # | Change |
|---|--------|
| 3 | Added coaching notes to `shared/claude-shared.md`: ask the user for help when the environment is broken instead of brute-forcing workarounds; always `cd` back before deleting temp dirs. |

**Verified on:** macOS (bash -n validated, clip2md auto-name and explicit-name tested end-to-end). Windows not affected (PS1 uses native .NET Unicode and `Read-Host`).

---

## v3.5 -- clip2md AI-Powered Naming & Logging (2026-02-18)

### New features

| # | Change |
|---|--------|
| 1 | **clip2md auto-naming**: Running `clip2md` with no arguments uses the Claude Code CLI (`claude -p`) to generate a descriptive filename and one-line summary. Content-type-aware prompt: emails get `YYMMDD-participant-topic`, articles get `source-topic`, docs get `product-section`. Max 50 chars but compact by default. Writes to hidden temp file, renames on success. Collision avoidance via `-2`, `-3` suffixes. |
| 2 | **clip2md explicit-name improvements**: `clip2md notes` auto-appends `.md`, prompts before overwriting, shows AI summary when claude is available. |
| 3 | **clip2md logging**: All operations log to `clip2md.log` (Windows: `%LOCALAPPDATA%\aitools\`, macOS: `~/Library/Logs/aitools/`). Events: saves, errors, temp file lifecycle, overwrite decisions. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | BUG | `clip2md` (bash) `.md` extension strip was case-sensitive -- `clip2md notes.MD` produced `notes.MD.md`. Fixed with glob character class `%.[mM][dD]`. |

### Implementation details

| # | Detail |
|---|--------|
| 5 | AI helper `_clip2md_ai` sanitizes Claude's response: filename lowercased, non-alnum replaced with hyphens, truncated to 50 chars at word boundary, Windows reserved names prefixed with `clip-`. Summary truncated to 80 chars at word boundary. |
| 6 | PS1 temp file uses `Get-Random` for uniqueness; bash uses `$$-$RANDOM`. Hidden via dot prefix (`.clip2md-<random>.tmp`). Cleanup via `try/finally` (PS1) or explicit error-path removal (bash). |
| 7 | PS1 pipes markdown to `claude -p` directly (accepts potential pipeline encoding mangling since Claude only needs topic understanding, not exact content). File content is written from the pre-pipe `$md` variable. |

**Verified on:** Windows (PS1 validated, auto-name and explicit-name tested end-to-end). macOS tested in v3.5.1.

---

## v3.4.4 -- clip2md clipboard encoding fix (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (PS1) produced mojibake for em-dashes, curly quotes, and NBSP. Root cause: `[System.Windows.Forms.Clipboard]::GetData("HTML Format")` decodes UTF-8 clipboard bytes as Windows-1252, producing double-encoded characters. Fixed by re-encoding the string back to bytes via Windows-1252, then decoding as UTF-8. |
| 2 | BUG | `clip2md` (PS1) now also strips narrow no-break space (U+202F) alongside regular NBSP (U+00A0). Gmail uses narrow NBSP around time values. |

### Documentation

| # | Change |
|---|--------|
| 3 | Added .NET clipboard encoding gotcha to `.claude/rules/cross-platform.md`. |

**Verified on:** Windows (PS1 validated). macOS not affected (bash clipboard path uses osascript).

---

## v3.4 -- Graceful Tool Addition & Cross-Platform Safety (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `setup-pandoc.ps1` contained an em-dash (U+2014) in a string literal. PS 5.1 reads BOM-free UTF-8 as Windows-1252, where the em-dash's bytes include `0x94` (right double quotation mark), prematurely terminating the string and causing cascading parse errors. Replaced with `--`. |

### Improvements

| # | Change |
|---|--------|
| 2 | **Pre-validation for setup scripts**: `aitools-install.ps1` now validates PS1 scripts with `[Parser]::ParseFile` before executing. Scripts with parse errors are skipped with a warning instead of failing with cascading errors. `aitools-install.sh` does the same with `bash -n`. |
| 3 | **Pre-validation for deploy configs**: `deploy_configs()` (bash) and `Deploy-Configs` (PS1) in the `aitools` CLI now validate each script before executing, using the same ParseFile/`bash -n` pattern. |
| 4 | **Build-time PS1 validation** (Windows only): `build-deploy.sh` validates all generated `.ps1` deploy scripts with `ParseFile` after building. Catches encoding and syntax errors at build time. |

### Documentation

| # | Change |
|---|--------|
| 5 | Added ASCII-only rule for PS1 executable code to `.claude/rules/cross-platform.md`. |
| 6 | Added pre-validation convention to `.claude/rules/cross-platform.md`. |
| 7 | Added verified-platform convention to release notes (see below). |

### Verified-platform convention

Each release section ends with a verified-platform note:
```
**Verified on:** Windows. macOS untested for items 2, 3, 4.
```

**Verified on:** Windows. macOS untested for items 2, 3, 4.

---

## v3.4.1 -- clip2md NBSP fix (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (both `.sh` and `.ps1`) now converts non-breaking spaces (U+00A0) to regular spaces. Gmail uses `&nbsp;` extensively; pandoc passes these through as raw NBSP bytes, which render as `??` in terminal output and pollute saved markdown files. |

**Verified on:** Windows (PS1 validated). macOS untested for item 1.

---

## v3.4.2 -- clip2md pipeline encoding fix (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (PS1) piped pandoc output through PowerShell, which uses the console codepage (not UTF-8). Non-ASCII characters (NBSP, curly quotes, em-dashes) were mangled to `?` (0x3F) before the `-replace` fix could match them. Rewrote to use temp files for pandoc I/O, bypassing the pipeline entirely. Also strips `&nbsp;` entities from HTML before pandoc. |
| 2 | BUG | `clip2md` (bash) now also strips `&nbsp;` entities at the HTML stage before pandoc, as defense in depth. |

### Documentation

| # | Change |
|---|--------|
| 3 | Added PowerShell pipeline encoding gotcha to `.claude/rules/cross-platform.md`. |

**Verified on:** Windows (PS1 validated). macOS untested for item 2.

---

## v3.4.3 -- clip2md path resolution and empty output guard (2026-02-17)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `clip2md` (PS1) wrote output files relative to the .NET working directory (`[Environment]::CurrentDirectory`) instead of PowerShell's `$PWD`. Files ended up in `$HOME` instead of the current directory. Fixed by resolving paths with `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath()` before calling `[IO.File]::WriteAllText()`. |
| 2 | BUG | `clip2md` (PS1) now shows an error if pandoc produces empty output, instead of silently writing an empty file. |

### Documentation

| # | Change |
|---|--------|
| 3 | Added .NET vs PowerShell working directory gotcha to `.claude/rules/cross-platform.md`. |

**Verified on:** Windows (PS1 validated). macOS not affected (bash CWD tracks correctly).

---

## v3.3 — Pandoc Integration, Tool Lifecycle, PS 5.1 Fix (2026-02-17)

### New features

| # | Change |
|---|--------|
| 1 | **Pandoc integration**: new `setup-pandoc.sh`/`.ps1` setup scripts, `clip2md` alias for clipboard-to-markdown conversion via pandoc. |
| 2 | **Tool lifecycle rules**: added source-of-truth review gate (`.claude/rules/sources-of-truth.md`) and tool lifecycle gate (`.claude/rules/tool-lifecycle.md`) to enforce phased tool adoption. |
| 3 | **Self-update resilience**: `aitools` and `aitools.ps1` now validate syntax (`bash -n` / `[Parser]::ParseFile`) before overwriting the installed copy. If the repo version has parse errors on the current platform, the self-update is skipped with a warning — the working installed copy stays in place. |

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 4 | BUG | `aitools.ps1` path conversion used a `-replace` scriptblock (PowerShell 7+ feature). On Windows PowerShell 5.1, the scriptblock was stringified instead of executed, producing a garbage path that caused `build-deploy.sh` to fail. Replaced with `-match`/`$Matches` which works on all PS versions. |
| 5 | BUG | `clip2md` output now strips Gmail inline styles and empty pandoc attribute blocks (`{...}`) for cleaner markdown. |

### Documentation

| # | Change |
|---|--------|
| 6 | Added release versioning convention to `RELEASE_NOTES.md` and `CLAUDE.md` Key Decisions. |
| 7 | Added PowerShell 5.1 compatibility rule to `.claude/rules/cross-platform.md` — documents minimum PS version target and common PS 7+ gotchas. |

---

## v3.2 — Deploy Script Fixes + Error Tracking (2026-02-16)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | Generated bash deploy scripts now define logging helpers before the OS guard, so `log_error` is available when the guard fires. |
| 2 | BUG | Generated bash deploy scripts log to `~/Library/Logs/aitools/deploy.log` (matching source scripts and `aitools` CLI), not `~/Library/Logs/ai-tooling-deploy.log`. |
| 3 | BUG | `setup-cursor-ide-mcp.ps1` and `setup-user-cursor.ps1` now write BOM-free UTF-8 via `[System.IO.File]::WriteAllText` instead of `Set-Content -Encoding UTF8`. Fixes JSON parsing issues on PowerShell 5.1. |

### Improvements

| # | Severity | Change |
|---|----------|--------|
| 4 | WARNING | `setup-user-mcp` and `setup-cursor-ide-mcp` (both `.sh` and `.ps1`) now track errors and exit with code 1 on failure, matching the pattern used by other setup scripts. |
| 5 | STALE | Fixed drifted line-number reference in `reference/claude-code-windows-shell.md`. |

---

## v3.1 — Cross-Platform Bug Fixes (2026-02-16)

### Bug fixes

| # | Severity | Fix |
|---|----------|-----|
| 1 | BUG | `setup-user-cursor` no longer opens GUI editor or overwrites clipboard during automated deploy (`aitools`/`aitools gitpull`). Interactive behavior preserved when run directly. |
| 2 | BUG | PS1 `Deploy-Configs` no longer double-counts errors or reports false failures from stale `$LASTEXITCODE`. Reset between iterations; `continue` after catch prevents double-increment. |
| 3 | BUG | PS1 `setup-user-mcp.ps1` now unsets `CLAUDECODE` env var before `claude mcp add`, matching the bash version. Fixes failure when run inside a Claude Code session. |
| 4 | BUG | PS1 `aitools.ps1` now converts `$repoPath` to Unix-style path before passing to `bash.exe` for `build-deploy.sh`. Prevents fragile mixed-path parsing in Git Bash. |
| 5 | BUG | `--addmcp`, `--version`, `--help` now work on PowerShell 5.1. PS 5.1 doesn't support `--` prefix; these flags are now detected as positional args and remapped. |
| 6 | WARNING | PS1 self-update now stamps both `aitools.ps1` and bash `aitools`, matching the bash self-update behavior. Prevents stale version stamps. |
| 7 | WARNING | Fixed double-logging in `deploy_configs()`. Child scripts already log to the deploy log via tee/Add-Content; parent now redirects stdout to /dev/null instead of the same file. |
| 8 | WARNING | PS1 scripts now write BOM-free UTF-8 via `[System.IO.File]::WriteAllText` instead of `Set-Content -Encoding UTF8` (which writes BOM on PowerShell 5.1). Affects `setup-user-claude.ps1` and `setup-user-mcp.ps1`. |

### How the interactive gate works

Setup scripts that touch the clipboard or open GUI editors now check whether they're being called interactively:

- **Bash** (`setup-user-cursor.sh`): `[ -t 1 ]` — true when stdout is a terminal, false when redirected by `deploy_configs()`
- **PowerShell** (`setup-user-cursor.ps1`): `$env:AITOOLS_DEPLOY` — set by `deploy_configs()` / `Deploy-Configs` before calling child scripts, cleared after

When non-interactive, clipboard copy and `open`/`Start-Process` are skipped. Running the script directly still triggers both.

---

## v3 — Config Sync, Version Tagging, Config Backups (2026-02-16)

### New command structure

| Command | What it does |
|---------|-------------|
| `aitools` (no args) | Quiet pull + rebuild + deploy all configs. Warns and continues if offline. |
| `aitools gitpull` | Pull + rebuild + deploy + date-formatted changelog + version tag. Clones repo if missing. |
| `aitools install` | Pull + rebuild + install all tools + deploy configs (unchanged). |

**Machine-switching workflow:**
- Arrive at machine → `aitools` (quick sync) or `aitools gitpull` (verbose changelog)
- Full setup → `aitools install`

### Version tagging

`aitools gitpull` creates and pushes a version tag: `v<date>.<session>.0` (e.g., `v2026-02-16.1.0`).
Commits after a tag are shown by `--version` as `2026-02-16.1.3` (3 commits since tag).
Falls back to `YYYY-MM-DD (hash)` when no tags exist.

### Config file backups

Setup scripts now back up files before overwriting. Keeps at most 20 timestamped copies per file.

| File | Backed up by |
|------|-------------|
| `~/.claude/CLAUDE.md` | `setup-user-claude` |
| `~/.cursor/mcp.json` | `setup-cursor-ide-mcp` |

Backup format: `<file>.bak.<ISO-UTC-timestamp>` (e.g., `CLAUDE.md.bak.2026-02-17T023527Z`)

### Cross-platform fix

The bash `aitools` entry point now correctly dispatches to `.ps1` scripts via `powershell.exe` on Windows for all code paths (no-args, gitpull, install). Previously, only the `install` path had this forwarding — the new `deploy_configs()` function was missing it.

Added dispatch rule documentation to user-level CLAUDE.md, project CLAUDE.md, and `.claude/rules/cross-platform.md` to prevent recurrence.

---

## v2 — CLI Subcommands, MCP Restructuring, Full Tool Chain (2026-02-14)

### CLI Subcommands

`aitools` now separates sync from install:

- `aitools` — Pull latest + rebuild deploy scripts + self-update. Does not install.
- `aitools install` — Install/update ALL dev tools and deploy configurations.
- `aitools --addmcp <name...>` — Add MCP servers to the current project.

### Full Tool Chain via `aitools install`

`aitools install` is now the single command that installs and updates everything:

| Tool | Install method |
|------|---------------|
| GitHub CLI (gh) | brew (macOS) / winget (Windows) |
| Node.js | brew (macOS) / winget (Windows) |
| Claude Code CLI | Native installer (auto-updates) / winget (Windows) |
| Vercel CLI | npm install -g vercel |
| Cursor CLI | Official installer |
| ripgrep | brew (macOS) / winget (Windows) |
| Chrome DevTools MCP | Configured at user level |

### MCP Architecture Change

User-level MCP now includes **only chrome-devtools**. Vercel and Webflow are now
added per-project to reduce context bloat (flagged by `claude doctor`).

- **Before**: chrome-devtools, vercel, webflow all at user level
- **After**: chrome-devtools at user level; vercel/webflow at project level via `--addmcp`

Legacy user-level vercel/webflow entries are cleaned up on next `aitools install`.

### New: `aitools --addmcp`

Add MCP servers to the current project for all AI tools (Claude Code + Cursor):

    cd ~/repos/my-project
    aitools --addmcp vercel
    aitools --addmcp vercel webflow

Creates/updates `.mcp.json` (Claude Code) and `.cursor/mcp.json` (Cursor).
Merges with existing config — safe to re-run.

Supported servers: `vercel`, `webflow`

### Logging Improvements

All MCP setup scripts now include structured logging:
- macOS: ~/Library/Logs/aitools/deploy.log
- Windows: %LOCALAPPDATA%\aitools\deploy.log

All paths in log output use native OS format.

### Documentation

- New `reference/tool-install-sources.md` — official docs and verified install commands for all managed tools
- Updated `shared/mcp/README.md` — two-tier MCP architecture docs
- Updated `CLAUDE.md` — new CLI usage examples
