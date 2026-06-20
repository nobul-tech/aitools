# Plan: Managed-Tool Resolution + Artifact Registry

**Intent**: **Purpose**: Capture the confirmed design for making every
managed tool deterministically resolved and governed by the harness —
durable PATH/shell-integration ownership, a 1:1 tool-ops resolution
model, and a generated artifact registry — so the design survives
session/context boundaries and drives implementation. **Scope**:
Confirmed decisions, workstream breakdown (A/B/C), sequencing, and the
open-thread backlog. NOT the framework-adoption execution for the
artifact registry (that goes through the `/frameworks` skill). NOT
per-tool registry data (`/tool-registry` skill). NOT per-tool ops data
(`/tool-ops` skill). **Audience**: Every session continuing this work,
on either machine.

Origin: design session 2026-06-17 (started from `aitools install` on
nobul-mac reporting `python3` resolving to Homebrew's interpreter, not
the uv shim). This file is the durable record of decisions reached in
that conversation.

---

## Status (2026-06-17)

**Shipped this session:**
- `~/.zprofile` — removed the dead Intel-brew line (`eval "$(/usr/local/bin/brew shellenv)"`) that errored on every shell init (no Intel Homebrew on Apple Silicon).
- `agent` symlink — removed stale `~/.grok/bin/agent` (→ old grok 0.2.3), repointed `~/.local/bin/agent` → `cursor-agent` (Cursor CLI). **Live only; not durable** until Workstream A owns PATH order (`~/.grok/bin` still precedes `~/.local/bin`).
- `scripts/setup-python.{sh,ps1}` — shadow detection now names the *actual* shadowing dir (parent of the resolved binary) instead of the hardcoded `/usr/bin`. `setup-python.sh` passed `bash -n`; `.ps1` not parse-checked (no pwsh on this Mac — see backlog).
- `registries/tool-registry.json` `python` entry — corrected `postInstallConfig` (the `/usr/bin` mis-diagnosis → the real Homebrew-bin shadow) and populated `knownPaths` with the uv shim paths.

**Not yet done:** Workstreams A, B, C below; ROADMAP index row; `framework-registry.json` pending entry for C.

---

## Problem

1. **python3 shadow.** Interactively, `python3` resolves to the uv shim (`~/.local/bin/python3`, 3.14.6) — correct. In the harness's *non-interactive* contexts (SessionStart/SessionEnd hooks, `aitools install`, Claude Code's Bash tool, cron/MDM) it resolves to Homebrew's `python@3.x` at `/opt/homebrew/bin/python3`. Cause: the `~/.local/bin` prepend lives only in `.zshrc` (interactive), and `brew shellenv` (`.zprofile`, login) plus re-evals push `/opt/homebrew/bin` ahead. **The harness owns zero PATH ordering today.**
2. **Mis-diagnosed remediation.** The install warning and the registry's `postInstallConfig` both blamed `/usr/bin`; the real shadow is `/opt/homebrew/bin`, and `~/.local/bin` is already ahead of `/usr/bin`. (Fixed in scripts + registry this session.)
3. **No "harness uses what it manages" model.** `tool-ops.json` governs only `claude-code` (deny rules + hooks). There is no place that says how the harness should *resolve and invoke* a managed tool, and nothing verifies it.
4. **`agent` resolved to grok**, not Cursor (stale user symlink). The harness's own `setup-user-cursor.sh` "Cursor CLI" check matched grok 0.2.3.

---

## Confirmed decisions

1. **tool-ops is 1:1 with tool-registry.** Every managed tool gets a tool-ops entry — *every managed tool is a governed tool*. Baseline entry = `resolution` + `verification`. Richer sections (`denyRules`, `hooks`, `contextInjection`, `kpis`) are optional, added only when a tool earns them.
2. **Drop the blanket `governanceModes` field.** Resolution/audit/verification are inherent to being managed (always-on, advisory by default). Keep a single `enforcement: "audit" | "active"` flag **only on rules that can block a session** (deny rules), so observe-to-enforce graduation survives where blocking actually happens (ref incident #34730).
3. **Dependencies declared at the consumer.** Each artifact declares the managed tools it uses in its *own* metadata (`usesManagedTools`). tool-ops does **not** store a `harnessConsumers` list — the "who consumes X" view is derived by scanning artifact metadata.
4. **Artifact registry = generated, never hand-authored.** Per-artifact metadata lives *in each file*; `registries/artifact-registry.json` is produced by a scan (treated like `deploy/` — regenerated, never edited). Scope = source artifacts only. Adopted as a **CMDB + SBOM** framework via `/frameworks`.
5. **Two registries, clean split.** tool-registry = supply chain (identity / install / version / health / supported-status). tool-ops = operations (resolution / verification / governance). Install-path facts live in tool-registry `knownPaths`; tool-ops `resolution` references them.
6. **PATH precedence (macOS):** `~/.local/bin` → `/opt/homebrew/bin` → `~/.grok/bin` / other installer bins. This makes the uv `python3` and `cursor-agent` win deterministically.
7. **aitools owns a marked block** (`# >>> aitools managed >>>` … `# <<< aitools managed <<<`) in the **login** profile (`.zprofile` / `.bash_profile`); `brew shellenv` runs *inside* that block, then `~/.local/bin` is prepended. The interactive `*.rc` keeps only the `source aliases.{sh,ps1}` line.
8. **`agent` = Cursor** (harness-managed symlink + corrected detection); **grok stays unmanaged** (invoked as `grok`).
9. **Install order (flat, no tiers):** brew (+ git + bash) → node → uv → python → claude → agent → everything else → deploy configs.
10. **Lifecycle gate:** marking a tool `supported` on a platform requires a tool-ops `resolution` entry and a **passing resolution verification** — "supported" means installed, current, *and resolving to the managed copy in the harness's non-interactive context.*

---

## Step 0 — Artifact metadata convention (smallest slice of C; unblocks #3)

Define a uniform per-artifact metadata header, extending the existing intent block. Fields:

| Field | Meaning |
|-------|---------|
| `intent` | purpose / scope / audience (already required on governed files) |
| `kind` | rule \| skill \| hook \| setup-script \| lib \| entry-point \| reference \| registry \| plan \| framework-doc \| check-script \| generator \| alias \| config |
| `framework` | which framework this artifact implements (null if none) |
| `governed` | protected? (true/false) — derives the sources-of-truth list |
| `usesManagedTools` | array of managed-tool slugs invoked at runtime |
| `deps` | other artifacts relied on (optional) |
| `lastReviewed` | YYYY-MM-DD |

Where metadata lives by file type: `.md` / `.sh` / `.ps1` → header comment block; `.json` → `meta` object; files that cannot carry a header → sidecar or a registry override map. This convention is the single source the artifact-registry generator (C) reads.

---

## Workstream A — Durable resolution + shell-integration / PATH ownership (ship first)

The live fix. Mostly independent; consumes the python tool-ops entry from B.

- **A1.** New `scripts/setup-user-shell.{sh,ps1}` — dedicated owner of the managed shell block (extracted from `aitools-install` Step 7, which currently only appends `source aliases.sh` and owns no PATH).
- **A2.** Managed block in the **login** profile: `brew shellenv` (guarded — `/opt/homebrew` Apple Silicon, `/usr/local` Intel) → prepend `~/.local/bin` → fold in `$GOPATH/bin` and `~/.cargo/bin` → ensure precedence over `~/.grok/bin` / antigravity. Idempotent: replace content between `# >>> aitools managed >>>` / `# <<< aitools managed <<<`.
- **A3.** Replace `aitools-install.{sh,ps1}` Step 7 to call `setup-user-shell`; keep the `source aliases.{sh,ps1}` line in the interactive `*.rc`.
- **A4.** Embed `setup-user-shell` in `build-deploy.sh` (closes the gap that the MDM/deploy path sets up no shell integration today).
- **A5.** Deterministic resolver in `aitools-lib.{sh,ps1}` (e.g. `harness_python` / `Resolve-ManagedTool`) returning the managed shim (or `uv run`); repoint harness python callers (dashboard `find_python`, hook shims, relay sync) off bare PATH lookup.
- **A6.** `setup-user-cursor.{sh,ps1}` — manage the `agent → cursor-agent` symlink and fix detection to verify the resolved `agent` is actually Cursor (not grok).
- **A7.** Reorder installer steps to decision #9.
- **A8.** New `reference/ait-shellintegration.md` (all platforms) — the managed block, marker convention, canonical PATH order, what aitools owns vs preserves. (Protected: new intent statement.)

Cross-platform: every `.sh` needs a `.ps1`; PS1 manages the block in the login `$PROFILE` analog with an explicit END marker (today's Windows block has none).

---

## Workstream B — tool-ops for every managed tool

- **B1.** Schema change in `tool-ops.json`: drop per-tool `governanceModes`; add baseline `resolution` (`canonicalCommands`, `manager?`, `managedPath` per platform, `pathPrecedence`, `invocationContract`) + `verifications`; `enforcement` flag only on blocking rules.
- **B2.** `python` reference entry (resolution + verification), e.g. verification `python3 -c 'import sys; print(sys.executable)'` must contain `/.local/share/uv/python/`.
- **B3.** Replicate to the harness-invoked set first (node + npx/npm, bash, perl, uv, claude-code [extend], agent/cursor), then resolution-baseline entries for the rest.
- **B4.** Amend (protected, present diffs): `framework-tool-ops.md` (lean-pull reframe — every tool gets an entry; lean-pull now governs *which optional sections*); `.claude/rules/tool-ops.md`; `.claude/rules/tool-lifecycle.md` (add the decision-#10 gate); `tool-ops` SKILL.md (new schema).
- **B5.** Wire `shared/hooks/tool-ops-session-audit.sh` to run resolution verifications and assert 1:1 coverage (every registry tool has an ops entry).

---

## Workstream C — Artifact registry (CMDB + SBOM framework adoption)

- **C1.** Adopt via `/frameworks` (pending → adopted). Discipline: ITIL **CMDB** (configuration items + relationships) + **SBOM**. Concepts: configuration items, dependency graph, single-source-via-generation. Reference doc: `reference/framework-artifact-registry.md`.
- **C2.** Three-layer: rule `.claude/rules/artifact-governance.md` + **generated** `registries/artifact-registry.json` + `/artifact` skill + generator (`scripts/generate-artifact-registry.*`) + a check step.
- **C3.** Generator scans source artifacts, reads the Step-0 metadata, emits the registry. **Scope — exclude**: `deploy/` (generated), `.scratch/` + channel session dirs (ephemeral), `harvesting/` (its own manifest), logs, `*.bak.*`, `.git`, `node_modules`.
- **C4.** Derive existing scattered indexes from it: the sources-of-truth protected set; `framework-registry` framework→artifacts; tool-ops consumers.
- **C5.** Backfill metadata staged (new/changed files must carry it; opportunistic backfill; coverage KPI). Check step flags: missing intent/metadata, orphans, broken deps, stale cross-references (e.g. the `framework-registry.json` → `reference/tool-ops.json` drift below).

---

## Sequencing

Step 0 (metadata convention) → **A** (ship now) + **B2** (python tool-ops entry, which A5 consumes) → **B** (rest) → **C** (framework adoption).

---

## Open threads / backlog

| # | Item | Lands in |
|---|------|----------|
| 1 | python non-interactive shadow (the core durable fix) | A |
| 2 | `agent` durability (PATH ownership) | A |
| 3 | `setup-user-cursor` detection matched grok 0.2.3, not Cursor | A6 |
| 4 | `setup-go` GOPATH/bin "session only" warning | A2 |
| 5 | **pwsh gap** — in registry as macOS-supported (7.5.4) and required by `build-deploy.sh` for PS1 validation, but **no install step** in the 22; macOS PS1 validation silently skips, and `.ps1` edits can't be parse-checked locally | new tool-lifecycle item |
| 6 | **`framework-registry.json` stale** — lists `reference/tool-ops.json`; should be `registries/tool-ops.json` (post-v0.69.0 consolidation). Exactly what C's check step catches | quick fix / C |
| 7 | **Profile match failure** — install showed `No profile matches this machine (hostname: Mac)` while `hostname` = `nobul-mac.local`; `aitools user init` did not report setting `machineAlias`, so it may persist. Uninvestigated | TBD |
| 8 | Issue [#7](https://github.com/nobul-tech/aitools/issues/7) — logging migration to `~/.aitools/logs` | separate workstream |
| 9 | Expected post-install auth ACTIONs (vercel/modal/datadog) — not bugs | user action |
