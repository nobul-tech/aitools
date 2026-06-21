## Summary

Phase 5 of the harvest/archive/logging plan (`plans/imperative-gliding-newell.md` §14/§20) was intentionally deferred at a clean checkpoint. The highest-blast-radius logging change — migrating `aitools-lib.{sh,ps1}` to the unified `~/.aitools/logs/` location with rotation — was left for a focused session that can also verify on macOS. Everything else in Phases 1–4 shipped and is fully working; the new `ait-harvest.py` logs correctly via its own `RotatingFileHandler` regardless.

Filed so the remaining work is tracked rather than living only in a session scratch doc.

## Remaining work

- [ ] **`aitools-lib.sh` / `aitools-lib.ps1` logging migration** — `AITOOLS_LOG_DIR` → `~/.aitools/logs`, per-component `LOG_FILE` naming via `logging_init`/`Initialize-Logging` arg, size-based rotation (5 MB × 5) in bash + PS1. Touches every setup script and the inlined `deploy/` copies. **Verify on macOS** (the location override reverses a deliberate 3-way native-dir decision, RELEASE_NOTES L865).
- [ ] **Old log-path literal cleanup** (plan §20.3 M4) — `grep -rn` for `.local/state`, `Library/Logs`, `LOCALAPPDATA`, `deploy.log` across `scripts/`, `shared/`, `reference/`, checks; migrate each. Known sites: `aitools`, `aitools.ps1`, `aitools-lib.sh`, `aitools-lib.ps1`, `check-lib.ps1`, `check-prereq-detection.ps1`, `setup-bash.ps1`, `setup-rust.ps1`, `setup-python.ps1`.
- [ ] **Doc consolidation** — `reference/logging.md` is created; trim the four scattered logging docs (script-standards.md, script-standards-detail.md, cross-platform.md, hook-rollout.md) to directive + pointer (plan §14.2). Add catch-up + subagents + helper + `logs/` to `reference/user-repo.md`, `reference/tool-ops-claude-code.md`, `.claude/rules/artifact-harvesting.md`, `.claude/rules/aitools-workspace.md`.
- [x] **Hooks-manifest as the generator** (DONE v0.71.0) (plan §5 full vision) — `hooks-manifest.json` is currently the AUDIT source (`check-post-push` step 32, which already prevents bash↔PS1 drift). Make `setup-user-hooks.{sh,ps1}` + `build-deploy.sh` *generate* registrations from the manifest at build time (the deeper refactor that fully removes the parallel hand-maintained lists).
- [ ] After the above: re-run `build-deploy.sh`, `check-post-push` (step 32 must pass), verify on macOS, then RELEASE_NOTES entry + version tag.

## Context

Phases 1–4 (Windows RCA fix, `ait-harvest.py` helper with the concurrency redesign, harvest reconcile, single-source parity audit) are complete and committed; 14/14 unit tests pass. See `plans/imperative-gliding-newell.md` §20 and `.scratch/session-8f1728f5/PROTECTED-CHANGES-FOR-REVIEW.md`.

