# Roadmap

Active and planned work items for the aitools project.
Detailed plans live in `plans/`. See `RELEASE_NOTES.md` for completed work.

## In Progress

| Item | Plan | Priority | Summary |
|------|------|----------|---------|
| Linux install hardening + first-class Linux | plans/linux-install-hardening.md | High | PR A shipped (safe re-runs #11–#13, #15–#18; v0.73.2/v0.73.3). Open, PR B: Linux paths for Homebrew-only scripts (#14) and an installer run in Linux CI (#19). Ubuntu 24.04/22.04 only; dnf deferred (not a supported platform, 2026-10-26). Epic #10 |
| build-package (parallel package distribution) | plans/build-package/implementation-plan.md | High | Installable packages for a fleet: Windows Intune Win32 app (`.intunewin`), unsigned macOS PKG (Intune, Jamf), Linux `.deb` for Ubuntu 24.04/22.04 (VMs, containers, Claude Code web, Cursor cloud). Runs the dev-path scripts from a pinned aitools payload; dev and MDM paths unchanged. Unsigned first; signing later and optional. |
| Managed-tool resolution + artifact registry | plans/tooling-resolution-and-artifact-registry.md | High | Harness owns PATH/shell-integration so the uv `python3` and `cursor-agent` resolve deterministically; tool-ops becomes 1:1 with tool-registry (baseline resolution + verification); generated artifact registry (CMDB + SBOM). Python/uv detection + registry fixes shipped; Step 0 (metadata convention) -> A (shell/PATH/agent) -> B (tool-ops) -> C (artifact registry) pending. |
| Tool support + machine profile (M2/M3) | plans/tool-support-and-machine-profile.md | High | Gate decided 2026-10-21 (95 items). Shipped: SOURCE-TRUTH review model, M3 resolver (`aitools-profile.sh/.ps1`), deploy-harness (`~/.aitools`), Cursor rules fan-out, `/tool-adopt`. Open: M2 decision-tree machinery (registry schema 1.1, `tool_*` helpers, `scripts/gen-tool-specs.py`; the reference `reference/tool-support-decision-tree.md` is written). M2 takes over Workstream A's resolver and verification scope. |
| Skills and rules fan-out | plans/skills-and-rules-fanout.md | High | Fan `~/.aitools/{rules,skills}` out to Claude Code and Cursor (FO-0..FO-7); open PRs #117-#126. |
| Claude Code rules fan-out | plans/rules-fanout-claude.md | High | `setup-user-claude` fans out every non-retired `~/.aitools/rules/*.md` into `~/.claude/rules/` (R-3); PR #121. |
| Deployment-area reconciliation | plans/fan-plan-reconciliation.md | High | v1.2 (executable): resolve the pending items between code, docs and commander decisions in the deployment area (setup-user-claude fan-out vs docs, parity, abort, pre-push step 7, incident ledger). |
| Managed content cascade | plans/managed-content-cascade.md | Medium | Per-section merge strategies and cascade levels between shared templates, dotprofile repos and deployed files. Design complete, implementation pending. |
| Logging and end-of-run summary conformance | plans/linux-install-hardening.md | High | Epic [#21](https://github.com/nobul-tech/aitools/issues/21): install/config output logged (#22, #23), set -e pipelines (#24), diagnostics through the framework (#25), ERROR rows on every failure path (#26), success by exit code not grep (#27), entry-point log override (#28). Most call sites fixed in PRs #37-#45 (v0.74.0); the issues stay open until their audit closes. |
| Harvest/archive/logging resilience | plans/harvest-archive-resilience.md | High | SessionStart catch-up + stdlib `ait-harvest.py` (concurrency-safe heartbeat lock, mtime-primary liveness) recover CC sessions that abrupt-exit/offline missed. Windows harvest RCA fixed (PS1 hook-registration parity). `hooks-manifest.json` + `check-post-push` step 32 parity audit close the bash↔PS1 drift root cause. Phases 1–5 shipped (Phase 5 logging migration closed with [#7](https://github.com/nobul-tech/aitools/issues/7), 2026-06-21); move to Completed with its release version. |

## Planned

| Item | Plan | Priority | Summary |
|------|------|----------|---------|
| Governance & compliance framework | plans/governance-and-compliance-framework.md | High | Three-layer governance (prevention/detection/audit), incident governance (`/incident` skill), PreToolUse validation hooks, SQLite telemetry + Datadog KPIs. Today 22 skills (20 user in `shared/skills/`, 2 project in `.claude/skills/`). Not built yet: SubagentStart pre-built cache, KPI shipping. |
| Subagent context hook & CLAUDE.md trim | -- | High | SubagentStart hook injects user + project CLAUDE.md into Explore/Plan/general-purpose agents (not built). Trim shared/claude-shared.md (142 lines today). |
| Chrome DevTools research subagent | -- | Medium | Custom subagent type for web doc reading tasks. Uses `chrome-devtools` skill. Subagent context hook (above) handles CLAUDE.md injection; this item adds the custom agent type + skill integration. |
| Tool lifecycle gaps | -- | Medium | Security/credential docs, cleanup for all tools, troubleshooting guides, ~~version management~~, CVE response, deprecation path |
| `aitools logs` command | -- | Medium | Logs live in `~/.aitools/logs/` (`reference/logging.md`, 5 MB × 5 rotation). Add `aitools logs` to open/tail/clear them. |
| Datadog log integration | plans/datadog-log-integration.md | High | Ship structured logs to Datadog via HTTP API (startup program credits). Add Datadog MCP server + Pup CLI as managed tools. `log_ship` helper in aitools-lib. CI Visibility for pipeline tracing. Post-credits migration path to Axiom. |
| Conditional template blocks | -- | Medium | Platform-gated sections in CLAUDE.md templates (e.g., `{{#if WINDOWS}}...{{/if}}`). Enables Windows-only or macOS-only coaching/rules without auto-memory. |
| clip2: unified clipboard command | -- | Medium | Refactor `clip2md` into `clip2` with format subcommands (`md`, `pdf`). Requires PDF tool evaluation. |
| Session search & view | -- | Low | `aitools sessions search <query>` and `sessions view <file>` for working with archived transcripts |
| aitools user sync | -- | Near-term | Merge `shared/claude-shared.md` managed sections (Managed CLI Tools table, etc.) into dotprofile CLAUDE.md automatically. Prevents silent drift when shared template is updated but dotprofile is not. `--dry-run` flag; structured log of added/updated/flagged rows. |
| aitools install version capture | -- | Near-term | Capture installed versions per platform → `~/.aitools/versions.json`; compare against the tool registry's per-platform `versions` (`/tool-registry` skill); flag drift at end of install; new `aitools versions` command; telemetry consent on first run; version blocking via `blocked[]` |
| Cross-user governance telemetry | -- | Future | Aggregate governance KPIs (hook fire rates, skill coverage, gap closure velocity) across users via aitools.nobul.tech ingest API. Requires telemetry consent. Schema in governance plan supports per-user metrics. |
| aitools.nobul.tech + Modal compute | -- | Near-term | Vercel + Next.js docs/dashboard (friends/family → open source); GitHub OAuth → dotprofile repo → one-liner install; log/version ingest API (anonymized telemetry); drift → PR automation via Claude API; Modal as compute backend for Claude API calls and batch processing |
| aitools inside Modal containers | -- | Future | `aitools install` / setup scripts provision Modal environments; configure managed tools (pandoc, typst, etc.) in Modal images |
| Nobul Auth0 platform | plans/nobul-auth0-platform.md | High | Auth0 tenant (auth.nobul.tech) for centralized credential management. Phase 1: `aitools auth` CLI + GitHub token via device flow. Phase 2: Vercel + Datadog. Phase 3: token lifecycle. Phase 4: vcard/credits web apps. Phase 5: multi-machine + RBAC. Resolves gap #23. |
| Elevation-aware installs | -- | Medium | `Install-WingetPackage` lib function with user scope -> machine scope -> `Start-Process -Verb RunAs` cascade. For tools that genuinely need admin (MSVC Build Tools). |

### aitools user sync — managed CLAUDE.md merging (near-term)

Currently `setup-user-claude.sh` uses a priority-override model: if the user's dotprofile
`<userRepoPath>/claude/CLAUDE.md` exists, it wins over `shared/claude-shared.md`. This means
any update to the shared template (e.g., adding a new managed tool row) must be manually replicated
to every dotprofile — a silent divergence risk.

**Planned:** `aitools user sync` performs a structured merge:
- Shared-template sections (Managed CLI Tools table, etc.) are reconciled into the dotprofile
- User-customized sections (Coaching, Standing Orders, etc.) are preserved untouched
- Stale or removed shared entries are flagged with log warnings (not silently deleted)
- Output: structured log of added / updated / flagged rows
- `--dry-run` flag shows diff without writing

This removes the manual "update both files" requirement and eliminates dotprofile drift.

## Completed

*Completed items move to RELEASE_NOTES.md.*

| Item | Version | Summary |
|------|---------|---------|
| Agentic framework + merge overhaul | v0.52.0 | `invoke_ai`/`Invoke-AI`, structured prompts, speed/permission tiers, header preservation, clip2md refactor |
| Eliminate deploy template duplication | v0.25.1 | Sentinel-based extraction in `build-deploy.sh` (~507 lines removed); `setup-user-hooks` still embeds hook scripts at build time (deploy-paths.md "duplication risk") |
| Summary format + error handling standards | v0.32.0 | 3-field summary, canonical tool names, external command standards, detail reference rewrite |
| Error handling audit | v0.22 | Error handling rules, full script audit, 5 violations + 4 logic bugs fixed |
| Rust as managed tool | v0.22 | Full lifecycle: setup scripts, installer, deploy, aliases |
| Check script logging | v0.22 | File logging (`checks.log`/`checks.jsonl`), OS guards, `StepPass` detail support |
| Per-platform tool approval | v0.22 | Platform status fields present in all tool entries |
| User repo & session archive | v0.22 | Phases A+B, bugs #1/#2, v2 profiles, template interpolation, multi-machine init |
| Interactive clobber protection | v0.21 | `--dry-run`/`--force` flags, clobber detection, corrupt file handling, PS1 node-free conversion |
