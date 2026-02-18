# Per-Platform Tool Approval

- **Status**: In Progress (roadmap)
- **Priority**: High
- **Created**: 2026-02-18
- **Origin**: Session `6584ed94` — Typst evaluation surfaced the need for platform-specific approval

## Problem

The current tool evaluation system doesn't distinguish between platforms. This creates two problems:

1. Tools with strong support on macOS but weak/missing support on Windows get marked "approved" globally, causing confusion during Windows installation
2. No clear pathway for platform-specific beta testing before broader approval

## Design

### 4-State Lifecycle per Platform

Each tool gets an independent lifecycle state on each platform:

```
evaluating → approved → supported    (or n/a)
```

| State | Meaning | Lifecycle phase |
|-------|---------|----------------|
| `evaluating` | Under hands-on evaluation, no user verdict yet | Phase 1-2 |
| `approved` | User approved on this platform, integration pending | Phase 2 passed |
| `supported` | Fully integrated -- setup script + installer entry | Phases 3-5 complete |
| `n/a` | Not available or not applicable on this platform | -- |

**Why 3 active states, not 2**: A tool can be approved on macOS (user said yes after testing) before setup scripts exist. Without the intermediate state, it either stays in "Under Evaluation" (wrong -- gate passed) or claims `supported` (wrong -- no scripts yet).

Canonical definition: `reference/tool-evaluation-criteria.md` ("Tool Platform States" section).

### Retrofit Existing Tools

All current tool entries in `reference/tool-install-sources.md` will be updated with explicit platform status. Format: `macOS: supported | Windows: supported` (or other state combinations). Eliminates ambiguity about what "no status" means.

### Redefine "Under Evaluation" Category

- Tools `evaluating` on **all** platforms stay in "Under Evaluation"
- First platform reaching `approved` promotes the tool to the main section (with `evaluating` or `n/a` on other platforms)
- Prevents tools from living indefinitely in an undefined state

### No Stub Scripts Required

The installer (`aitools-install.sh/.ps1`) already skips missing scripts with `log_warn`. No new script patterns needed -- only documentation changes.

## Files to Modify

5 documentation/rules files:

| File | Change |
|------|--------|
| `reference/tool-install-sources.md` | Add platform status lines to each tool entry |
| `reference/tool-evaluation-criteria.md` | Update Phase 2 to clarify per-platform approval gates |
| `.claude/rules/tool-lifecycle.md` | Clarify that Phase 2 gates are per-platform |
| `.claude/rules/sources-of-truth.md` | Already done (roadmap system creation) |
| `CLAUDE.md` | Already done (roadmap system creation) |

## Implementation Notes

- Zero Windows risk -- implementation involves only documentation changes
- No script modifications required
- Individual platform approvals can proceed independently after this plan is implemented
- Each platform's Phase 2 gate is evaluated separately
- Scripts and installer remain unchanged until a platform-specific tool approval requires a new setup script

## Resolved Questions

- **Display format**: Platform status displays inline in each tool's entry in `tool-install-sources.md` (e.g., `macOS: supported | Windows: supported`), not in a separate summary table. Inline keeps the status next to the install commands it describes.
- **Installer warnings**: `aitools install` surfacing platform-specific warnings (e.g., "tool X is evaluating on this platform") is future scope. The current `log_warn` for missing scripts already covers the common case.
