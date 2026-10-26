# detect-user.ps1 -- aitools Intune Win32 app B custom detection script (package launcher)
#
# Intent (batch B9, plans/build-package/implementation-plan.md): tell Intune
# whether the user phase of version X.Y.Z has completed. When implemented:
#   - read %USERPROFILE%\.aitools\pkg-version (written by install-user.ps1)
#   - equal to the expected version (stamped at build time): write the version
#     to STDOUT and exit 0 = detected
#   - otherwise: write nothing to STDOUT and exit 1 = not detected
#   Intune rule: "detected when the script both returns a 0 value exit code and
#   writes a string value to STDOUT"; any STDERR output = not installed
#   (PkgWin notes section 4). Save as UTF-8 with BOM at build time (Intune
#   recommendation). Uploaded in the Intune app, not inside the .intunewin.
# Run context: Intune Management Extension, 64-bit host. Whether it runs as the
#   signed-in user for a User-context app is undocumented: test on a device
#   before relying on it (BP-15, open item). Parses under Windows PowerShell 5.1
#   and pwsh 7.
# Platform: Windows 10/11 only. Package launcher: exempt from the .sh/.ps1
#   pairing (category "package launchers", BP-5, pending P-1).
# Follows: BP-5, BP-12, BP-15.
# Safe to re-run: yes (read-only).
#
# VERSION 1.0 SCAFFOLDING: always reports "not detected" (STDERR line, exit 1).

$ErrorActionPreference = "Stop"

$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
[Console]::Error.WriteLine("[$ts] [aitools-detect-user] [error] not implemented in v1.0 scaffolding (batch B9, plans/build-package/implementation-plan.md)")
exit 1
