# install-user.ps1 -- aitools Intune Win32 app B "aitools (user)" installer (package launcher)
#
# Intent (batch B9b, plans/build-package/implementation-plan.md): run the user
# phase of the existing installer from the read-only payload that app A laid
# down. Steps when implemented:
#   1. refuse when running as SYSTEM or elevated with another user's profile
#      (BP-10); never require admin (a user-targeted app fails if it does)
#   2. exit 0 at once when %USERPROFILE%\.aitools\pkg-version equals
#      %ProgramFiles%\aitools\VERSION (runs once per version, BP-13)
#   3. log to ~/.aitools/logs (standard location, BP-16)
#   4. AITOOLS_FORCE=1 (non-interactive: overwrite with backups), then run
#      %ProgramFiles%\aitools\repo\scripts\aitools-install.ps1 -Phase user
#      -PackageMode (BP-6); every winget call uses
#      --scope user --exact --source winget where the package supports it (BP-14)
#   5. on success write %USERPROFILE%\.aitools\pkg-version = VERSION (read by
#      detect-user.ps1, BP-15)
# Run context: the signed-in user (Intune install behaviour User), started as
#   "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -ExecutionPolicy Bypass
#   -File install-user.ps1. App B depends on app A (and so on pwsh 7). No
#   terminal: never prompt. pwsh 7 only: B9b adds #Requires -Version 7.
# Platform: Windows 11 only. Package launcher: exempt from the .sh/.ps1
#   pairing (category "package launchers", BP-5, pending P-1).
# Follows: BP-2, BP-5, BP-6, BP-7, BP-10, BP-11, BP-13, BP-14, BP-15, BP-16.
# Safe to re-run: yes once implemented (version marker; managed files backed up).
#
# VERSION 1.0 SCAFFOLDING: refuses to run (exit 1).

$ErrorActionPreference = "Stop"

$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
[Console]::Error.WriteLine("[$ts] [aitools-install-user] [error] not implemented in v1.0 scaffolding (batch B9, plans/build-package/implementation-plan.md)")
exit 1
