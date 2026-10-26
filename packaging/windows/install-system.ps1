# install-system.ps1 -- aitools Intune Win32 app A "aitools (system)" installer (package launcher)
#
# Intent (batch B9, plans/build-package/implementation-plan.md): lay down the
# machine state for every user of the device. Steps when implemented:
#   1. log (UTC ...Z) to C:\ProgramData\aitools\logs\system-install.log
#      (AITOOLS_LOG_DIR, BP-16)
#   2. copy the payload from the package folder to %ProgramFiles%\aitools\
#      (read-only payload: repo\, VERSION, install-user.ps1)
#   3. check machine-wide prerequisites (PowerShell 7.6 LTS MSI, Git, Node LTS:
#      separate Intune dependency apps, BP-8): ERROR in the log when missing
#   4. never call the winget CLI: it is not supported in SYSTEM (BP-14)
#   5. write HKLM\SOFTWARE\aitools Version = X.Y.Z (the detection rule, BP-15)
#   6. exit 0 success, 1 failed (a retry code for transient errors: B9 decides)
# Run context: SYSTEM (Intune Management Extension, install behaviour System),
#   no user profile, no terminal: never prompt. Runs BEFORE pwsh 7 may exist,
#   so it must parse and run under Windows PowerShell 5.1 (64-bit host via
#   %SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe) and pwsh 7.
# Platform: Windows 10/11 only. Package launcher: exempt from the .sh/.ps1
#   pairing (category "package launchers", BP-5, pending P-1).
# Follows: BP-5, BP-7, BP-8, BP-12, BP-14, BP-15, BP-16, BP-17.
# Safe to re-run: will be idempotent (re-install of the same version).
#
# VERSION 1.0 SCAFFOLDING: refuses to run (exit 1).

$ErrorActionPreference = "Stop"

$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
[Console]::Error.WriteLine("[$ts] [aitools-install-system] [error] not implemented in v1.0 scaffolding (batch B9, plans/build-package/implementation-plan.md)")
exit 1
