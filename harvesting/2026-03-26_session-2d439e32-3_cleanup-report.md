# Machine Cleanup Report

**Date**: 2026-03-25T00:00:00Z
**Machine**: Darwin arm64 (Joses-MBP)

## Task 1: Kill zombie dashboard on port 8411

- **Status**: DONE
- **Finding**: PID 4685 (Python) was listening on port 8411. Regular `kill` did not terminate it; `kill -9 4685` succeeded.
- **Verification**: `lsof -i :8411` returns exit code 1 (no process found).

## Task 2: Clean up orphaned test DB files

- **Status**: DONE
- **Finding**: Both files existed and were removed:
  - `.aitools/sessions/test-12345.db-shm` (32768 bytes, dated Mar 24)
  - `.aitools/sessions/test-12345.db-wal` (0 bytes, dated Mar 24)
- **Verification**: `ls` confirms both files no longer exist.

## Task 3: Fix harness DB index -- remove stale entries

- **Status**: DONE
- **Finding**: Two stale entries confirmed and removed:
  - `c0dc2ddc-f` (status: active) -- stale duplicate
  - `test-1234567890` (status: completed) -- test artifact
- **Verification**: SELECT query returns no matching rows.

## Task 4: Run hooks setup to remove stale Stop hooks

- **Status**: BLOCKED
- **Finding**: `bash scripts/setup-user-hooks.sh` was denied by the Bash permission gate (interactive setup script requires approval). This must be run manually:
  ```
  bash /Users/pepe/repos/aitools/scripts/setup-user-hooks.sh
  ```

## Task 5: Create provenance tables in harness.db

- **Status**: ALREADY DONE (no action needed)
- **Finding**: All three tables already exist in harness.db with data:
  - `knowledge_items`: 5 rows
  - `provenance_edges`: 2 rows
  - `nogood_sets`: 1 row
- Schema matches `reference/harness-db-schema.sql`. No creation required.

## Summary

| Task | Result |
|------|--------|
| Kill zombie (port 8411) | DONE (kill -9) |
| Remove orphaned DB files | DONE |
| Clean stale session_index | DONE |
| Deploy hook fix | BLOCKED (run manually) |
| Create provenance tables | ALREADY EXISTED |
