## Error Handling (this repo)

Project-level error handling requirements for all reusable scripts in the ai-tooling repo.
Complements standing order #7 (user-level) and the error handling section in `script-standards.md`.

### Scope

Every `.sh` and `.ps1` in `scripts/`, `deploy/`, `shared/hooks/`, and `shared/shell/`.

### Requirements

1. **Logging framework required** -- All scripts must use the repo's logging helpers
   (`log`/`log_error`/`LogError` etc.). Raw `echo` or `Write-Host` without structured
   logging is not acceptable in reusable scripts.

2. **`-ErrorAction SilentlyContinue` guard** -- Every use requires a null/empty check
   within 3 lines that logs or fails. No exceptions beyond command-existence checks with
   explicit fallback.

3. **`2>/dev/null` and `|| true` guard** -- Every use requires a comment explaining why the
   error is suppressed AND a result check that handles the failure case.

4. **Check scripts** -- `Get-ChildItem` and `Get-Content` failures must produce `StepFail`
   or `StepWarn`, never a silent skip. A step that cannot read its input data is a failed
   step, not a passed step with 0 findings.

5. **`try/catch` blocks** -- Catch blocks must log the error or re-throw. Empty `catch {}`
   is never acceptable. If a catch block intentionally swallows an error, it must log what
   was swallowed and why.

### Cross-references

- Standing order #7 in `shared/claude-shared.md` (user-level, applies to all projects)
- Error handling section in `.claude/rules/script-standards.md` (repo-level conventions)
- Exemptions table in `.claude/rules/script-standards.md` (approved deviations)
