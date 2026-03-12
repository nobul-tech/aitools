# RFC-0002: aitools / nobul-ops Coordination

**Status**: Draft
**Date**: 2026-03-12

## Context

Both `aitools` and `nobul-ops` are CLIs managing tools, config, and automation
on the same machines. They share design patterns but have distinct scopes.

- **aitools**: Dev tools + AI config (Claude Code, Cursor, MCP servers, pandoc, etc.)
- **nobul-ops**: Ops tools + business workflows (GWS, Stripe, Mercury, identity audit)

## Scope boundaries

| Concern | Owner | Examples |
|---------|-------|---------|
| Dev tool lifecycle | aitools | Claude Code, Cursor, pandoc, typst, rust |
| AI config & prompts | aitools | CLAUDE.md, MCP servers, agentic framework |
| Ops tool lifecycle | nobul-ops | GWS CLI, Stripe CLI, Mercury integration |
| Business automation | nobul-ops | Identity audit, invoice sync, domain management |
| Shared patterns | both | Structured logging, cross-platform dispatch, RFC-driven design |

## Shared design patterns

Both CLIs use:
- Structured logging (`log`/`Log`, `log_error`/`LogError`)
- Tool lifecycle management (install, upgrade, verify, auth check)
- Cross-platform dispatch (bash + PowerShell, OS guards)
- `.claude/rules/` + `.cursor/rules/` parity
- RFC-driven design decisions

## Tool overlap protocol

When both CLIs manage tools on the same machine, idempotent detection applies:
- Each CLI checks if a tool is already installed before acting
- No cross-CLI dependency -- each is self-contained
- Per nobul-ops `reference/tool-overlap.md`

## Config independence

- aitools: `~/.aitools/config.json`, `~/.aitools/deploy-state/`
- nobul-ops: `~/.nobul-ops/config.json`
- No cross-reading between config stores

## Agentic framework coordination

- **aitools**: bash/PS1 `invoke_ai`/`Invoke-AI` -- pragmatic, embedded in deploy scripts
- **nobul-ops**: Rust implementation is the long-term target
- **Shared binary candidate**: `nobul-ai invoke --speed fast --permissions none`
- **Migration**: agentic framework stays in aitools until Rust impl matures

## CLI composition (future)

- `aitools ops` could delegate to `nobul-ops`
- `nobul-ops dev` could delegate to `aitools`
- No current implementation -- coordination by convention

## Decision

This RFC establishes coordination principles, not code changes. Both CLIs
continue to evolve independently with shared design patterns documented here.
