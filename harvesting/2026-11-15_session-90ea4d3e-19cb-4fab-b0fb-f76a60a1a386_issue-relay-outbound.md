## Decide: keep or remove the relay-outbound feature

The relay-outbound rule (`.claude/rules/relay-outbound.md`) and its Cursor twin were deleted, but the feature it governed still runs:

- `scripts/relay-outbound-prompt.sh` and `scripts/relay-outbound-prompt.ps1` (the `[RELAY]` prompt after `aitools` / `hh -n` when `relay.md` is uncommitted or the branch is ahead of `origin/main`)
- call sites: `scripts/aitools`, `scripts/aitools.ps1`, `scripts/hh.sh`, `scripts/hh.ps1`
- documentation: `README.md`, the exemption rows in `.claude/rules/cross-platform.md` and `.cursor/rules/cross-platform.mdc`, `reference/tool-support-decision-tree.md`

With the rule gone, the scripts have no governing rule and only README documents them.

## Options

1. **Remove the feature**: delete both scripts, their call sites and every documentation reference, in one change.
2. **Keep the feature**: keep the scripts and call sites, with README as their documentation (and, if wanted, a short replacement rule or reference section).

## Context

Found by the cleanup of the deleted artifacts' references (session 90ea4d3e, 2026-11-13). The cleanup removed documentation references to the deleted rule and held the scripts and call sites for this decision.
