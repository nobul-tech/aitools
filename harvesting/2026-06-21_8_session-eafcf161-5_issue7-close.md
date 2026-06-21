Closing — all remaining items complete in **v0.72.0**.

**Logging migration (the core):**
- `aitools-lib.{sh,ps1}`, the `aitools`/`aitools.ps1` bootstrap loggers, `check-lib.ps1`, and the clip2md aliases now resolve to the unified `~/.aitools/logs` (honoring an `AITOOLS_LOG_DIR` override for tests).
- **Rotation** (5 MB × 5, fail-safe) is net-new in `logging_init`/`Initialize-Logging` + the check inits.
- **Old log-path literal cleanup:** acceptance scan shows zero leftover logging literals (only legit NASM/Git/Python install paths remain).
- **Doc consolidation:** `reference/logging.md` is the single source; fixed the stale 3-way table in `script-standards-detail.md`, the old paths in `pre-update.md`, added a pointer in `script-standards.md`, and documented the harvest/archive system (catch-up, subagent transcripts, `ait-harvest.py`, `logs/`) across `user-repo.md`, `tool-ops-claude-code.md`, `artifact-harvesting.md`, `aitools-workspace.md`.

**Verified both platforms** (pwsh installed this session): path + rotation tested live, override works, all 38 deploy scripts carry the new path, `check-post-push` 0 FAIL.

The **hooks-manifest-as-generator** item shipped earlier in v0.71.0.
