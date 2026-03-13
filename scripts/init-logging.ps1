# init-logging.ps1 — Initialize structured logging with auto-detected caller name.
# Dot-source after aitools-lib.ps1 or check-lib.ps1, before the OS guard.
# Enables LogError in guards for Datadog-parseable error messages.
# See .claude/rules/cross-platform.md "OS guard patterns".

$_ilCallerName = [IO.Path]::GetFileNameWithoutExtension($MyInvocation.ScriptName)
Initialize-Logging $_ilCallerName
