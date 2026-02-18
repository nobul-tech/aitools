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

### 3-Value Status Model per Platform

Each tool gets an independent approval status on each platform:

- `approved` -- Tool is fully tested and working on this platform
- `pending` -- Tool has been evaluated but not yet approved on this platform
- `n/a` -- Tool is not available or not applicable on this platform

### Retrofit Existing Tools

All current tool entries in `reference/tool-install-sources.md` will be updated with explicit platform status. Format: `macOS: approved | Windows: approved` (or other status combinations). Eliminates ambiguity about what "no status" means.

### Redefine "Under Evaluation" Category

- Tools not approved on **any** platform stay in "Under Evaluation"
- First platform approval promotes the tool to the main section (with `pending` status on other platforms)
- Prevents tools from living indefinitely in an undefined state

### No Stub Scripts Required

The installer (`aitools-install.sh/.ps1`) already skips missing scripts with `log_warn`. No new script patterns needed -- only documentation changes.

## Files to Modify

5 documentation/rules files:

| File | Change |
|------|--------|
| `reference/tool-install-sources.md` | Add platform status columns to each tool entry |
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

## Open Questions

- Should the platform status display inline in tool-install-sources.md entries, or in a separate summary table?
- Should `aitools install` surface platform-specific warnings (e.g., "tool X is pending on this platform")?
