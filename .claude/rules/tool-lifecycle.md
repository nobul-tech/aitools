## Tool Lifecycle Gate (this repo)

When adding a new managed tool, follow the lifecycle in `reference/tool-evaluation-criteria.md`.

**Hard stop at Phase 2:** After installing the tool and providing a test command, you MUST wait for the user's explicit approval before writing any integration code (aliases, setup scripts, installer steps, build changes).

- Do not plan Phase 3+ implementation until Phase 2 is approved
- Do not batch Phase 2 approval with Phase 3+ work in a single plan
- If the user rejects: uninstall, remove the "Under Evaluation" entry, stop
- If the user approves: promote to full entry, then proceed to Phase 3+

This applies in plan mode too — a plan that includes Phases 3-5 must note the Phase 2 gate and flag that implementation is contingent on approval.

### Lifecycle field completeness

Every tool entry in `reference/tool-install-sources.md` (including Under Evaluation) must have all 4 fields:
- **Platform Status** (per platform: `evaluating`/`approved`/`supported`/`n/a`)
- **Concurrency** (can multiple instances run simultaneously?)
- **Post-Install Config** (steps required after install, or "None")
- **Dependencies** (other tools/runtimes required)

Verify all 4 fields are present before committing changes to tool entries.

### Under Evaluation guard

Tools with `evaluating` status on ALL platforms must NOT have:
- Setup scripts in `scripts/`
- Entries in `aitools-install.sh/.ps1`
- Aliases in `shared/shell/`
- Build pipeline entries in `build-deploy.sh`

If any of these exist for an `evaluating`-only tool, flag it as a lifecycle error.
