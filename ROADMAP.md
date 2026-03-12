# Roadmap

Active and planned work items for the aitools project.
Detailed plans live in `plans/`. See `RELEASE_NOTES.md` for completed work.

## In Progress

| Item | Plan | Priority | Summary |
|------|------|----------|---------|

## Planned

| Item | Plan | Priority | Summary |
|------|------|----------|---------|
| Subagent context hook & CLAUDE.md trim | -- | High | SubagentStart hook injects user + project CLAUDE.md into Explore/Plan/general-purpose agents. Trim shared/claude-shared.md (~146 → ~106 lines). Hook script drafted, trimmed template proposed — ready to implement. |
| Chrome DevTools research subagent | -- | Medium | Custom subagent type for web doc reading tasks. Uses `chrome-devtools` skill. Subagent context hook (above) handles CLAUDE.md injection; this item adds the custom agent type + skill integration. |
| Tool lifecycle gaps | -- | Medium | Security/credential docs, cleanup for all tools, troubleshooting guides, ~~version management~~, CVE response, deprecation path |
| Log location discoverability | -- | Medium | Document log paths (`deploy.log`, `clip2md.log`, `checks.log`, `checks.jsonl`) in CLAUDE.md, README, and rules. Add `aitools logs` command to open/tail/clear logs. Assess log rotation and management. |
| Datadog log integration | plans/datadog-log-integration.md | High | Ship structured logs to Datadog via HTTP API (startup program credits). Add Datadog MCP server + Pup CLI as managed tools. `log_ship` helper in aitools-lib. CI Visibility for pipeline tracing. Post-credits migration path to Axiom. |
| Conditional template blocks | [#5](https://github.com/nobul-jose/aitools/issues/5) | Medium | Platform-gated sections in CLAUDE.md templates (e.g., `{{#if WINDOWS}}...{{/if}}`). Enables Windows-only or macOS-only coaching/rules without auto-memory. |
| clip2: unified clipboard command | [#3](https://github.com/nobul-jose/aitools/issues/3) | Medium | Refactor `clip2md` into `clip2` with format subcommands (`md`, `pdf`). Requires PDF tool evaluation. |
| Session search & view | [#4](https://github.com/nobul-jose/aitools/issues/4) | Low | `aitools sessions search <query>` and `sessions view <file>` for working with archived transcripts |
| aitools user sync | -- | Near-term | Merge `shared/claude-shared.md` managed sections (Managed CLI Tools table, etc.) into dotprofile CLAUDE.md automatically. Prevents silent drift when shared template is updated but dotprofile is not. `--dry-run` flag; structured log of added/updated/flagged rows. |
| aitools install version capture | -- | Near-term | Capture installed versions per platform → `~/.aitools/versions.json`; compare against `reference/tool-versions.json`; flag drift at end of install; new `aitools versions` command; telemetry consent on first run; version blocking via `blocked[]` |
| aitools.nobul.tech + Modal compute | -- | Near-term | Vercel + Next.js docs/dashboard (friends/family → open source); GitHub OAuth → dotprofile repo → one-liner install; log/version ingest API (anonymized telemetry); drift → PR automation via Claude API; Modal as compute backend for Claude API calls and batch processing |
| aitools inside Modal containers | -- | Future | `aitools install` / setup scripts provision Modal environments; configure managed tools (pandoc, typst, etc.) in Modal images |
| setup-typst raw npm output | [#14](https://github.com/nobul-jose/aitools/issues/14) | Low | Raw `up to date in 209ms` npm output leaks before structured log lines |
| setup-cursor-ide-mcp raw agent output | [#15](https://github.com/nobul-jose/aitools/issues/15) | Low | `agent mcp disable` output not captured into structured logging |
| setup-rust blank log line | [#16](https://github.com/nobul-jose/aitools/issues/16) | Low | Empty rustup output lines produce `[info] ` with blank message |
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
| Eliminate deploy template duplication | v0.25.1 | Sentinel-based extraction in `build-deploy.sh` -- single source of truth for all 4 script pairs, ~507 lines removed |
| Summary format + error handling standards | v0.32.0 | 3-field summary, canonical tool names, external command standards, detail reference rewrite |
| Error handling audit | v0.22 | Error handling rules, full script audit, 5 violations + 4 logic bugs fixed |
| Rust as managed tool | v0.22 | Full lifecycle: setup scripts, installer, deploy, aliases |
| Check script logging | v0.22 | File logging (`checks.log`/`checks.jsonl`), OS guards, `StepPass` detail support |
| Per-platform tool approval | v0.22 | Platform status fields present in all tool entries |
| User repo & session archive | v0.22 | Phases A+B, bugs #1/#2, v2 profiles, template interpolation, multi-machine init |
| Interactive clobber protection | v0.21 | `--dry-run`/`--force` flags, clobber detection, corrupt file handling, PS1 node-free conversion |
