# ---------------------------------------------------------------------------
# PROTOTYPE (M3b-Finish-R, fix 1) -- one shared console-input helper for
# scripts/aitools-lib.ps1. Not wired into any tracked file.
#
# Console input mode (Windows). The input mode belongs to the console, not the
# process: a child run in this console (Git Bash / MSYS, node CLIs) can leave it
# raw (ENABLE_LINE_INPUT / ENABLE_ECHO_INPUT off, e.g. 0x2E8 or 0x208). Then
# [Console]::ReadLine() returns only when the NEXT key arrives, nothing echoes,
# and that key leaks into the following prompt.
#
# One Add-Type type, AitConsoleInput, compiled lazily and only when stdin is a
# Windows console (Initialize-AitConsoleInput), serves:
#   - Read-ConsoleChoice: enter cooked mode for the one read, restore after
#   - Save-ConsoleInputMode / Restore-ConsoleInputMode (moved from
#     scripts/aitools.ps1, same contract and return values; aitools.ps1
#     dot-sources this lib, so its copies and its AitConsoleModeGuard type go)
# Off Windows and with redirected stdin nothing is compiled and nothing changes.
# ---------------------------------------------------------------------------
function Initialize-AitConsoleInput {
    # $true when stdin is a Windows console and the type is loaded.
    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) { return $false }
    if ([Console]::IsInputRedirected) { return $false }
    if ('AitConsoleInput' -as [type]) { return $true }
    try {
        Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AitConsoleInput {
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool FlushConsoleInputBuffer(IntPtr h);
    const uint ProcessedInput = 0x1, LineInput = 0x2, EchoInput = 0x4, VirtualTerminalInput = 0x200;
    // Input mode of STD_INPUT_HANDLE (-10), or -1 when stdin is not a console.
    public static long Get() { uint m; return GetConsoleMode(GetStdHandle(-10), out m) ? (long)m : -1; }
    // 0 on success, else the Win32 error code.
    public static int Set(long m) {
        if (m < 0 || m > 0xFFFFFFFFL) return 87;
        return SetConsoleMode(GetStdHandle(-10), (uint)m) ? 0 : Marshal.GetLastWin32Error();
    }
    // Cooked line input for one read: drop keys typed before the prompt, turn
    // PROCESSED | LINE | ECHO on and VIRTUAL_TERMINAL_INPUT off. Returns the
    // previous mode (restore it with Set), or -1 when stdin is not a console.
    public static long EnterCooked() {
        IntPtr h = GetStdHandle(-10); uint m;
        if (!GetConsoleMode(h, out m)) return -1;
        FlushConsoleInputBuffer(h);
        SetConsoleMode(h, (m | ProcessedInput | LineInput | EchoInput) & ~VirtualTerminalInput);
        return m;
    }
}
'@
    } catch {
        LogDetail "console input helper unavailable: $($_.Exception.Message)"
        return $false
    }
    return $true
}

# Read-ConsoleChoice: [Console]::ReadLine() returns $null at EOF, and the
# callers' .ToLower() then threw. This logs and returns "" so each caller's
# default branch applies. On a Windows console the read runs in cooked mode
# (see above) and the previous mode is put back afterwards.
function Read-ConsoleChoice {
    param([string]$DefaultDesc)
    $saved = [long]-1
    if (Initialize-AitConsoleInput) { $saved = [AitConsoleInput]::EnterCooked() }
    try {
        $line = [Console]::ReadLine()
    } finally {
        if ($saved -ge 0) { $null = [AitConsoleInput]::Set($saved) }
    }
    if ($null -eq $line) {
        [Console]::WriteLine("")
        LogWarn "No input at prompt (EOF) -- defaulting to $DefaultDesc"
        return ""
    }
    return $line
}

# Save-ConsoleInputMode -- read the mode before running a child in this console.
# Returns [pscustomobject]@{ Mode; Reason } (Mode -1 = not guarded).
function Save-ConsoleInputMode {
    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        return [pscustomobject]@{ Mode = [long]-1; Reason = "not Windows" }
    }
    if ([Console]::IsInputRedirected) {
        return [pscustomobject]@{ Mode = [long]-1; Reason = "not a console" }
    }
    if (-not (Initialize-AitConsoleInput)) {
        return [pscustomobject]@{ Mode = [long]-1; Reason = "unavailable" }
    }
    $mode = [AitConsoleInput]::Get()
    if ($mode -lt 0) { return [pscustomobject]@{ Mode = [long]-1; Reason = "not a console" } }
    return [pscustomobject]@{ Mode = [long]$mode; Reason = "console" }
}

# Restore-ConsoleInputMode SAVED LABEL -- put back the mode Save-ConsoleInputMode
# read. Returns "restored", "unchanged", "restore failed", or the reason nothing
# was saved.
function Restore-ConsoleInputMode {
    param($Saved, [string]$Label)
    if ($null -eq $Saved -or $Saved.Mode -lt 0) {
        $why = if ($null -eq $Saved) { "not saved" } else { $Saved.Reason }
        LogDetail "console input mode around ${Label}: not guarded ($why)"
        return $why
    }
    $now = [AitConsoleInput]::Get()
    if ($now -eq $Saved.Mode) {
        LogDetail ("console input mode 0x{0:X} unchanged after {1}" -f $now, $Label)
        return "unchanged"
    }
    $nowText = if ($now -lt 0) { "unreadable" } else { "0x{0:X}" -f $now }
    $rc = [AitConsoleInput]::Set($Saved.Mode)
    if ($rc -eq 0) {
        LogDetail ("console input mode {0} after {1}, restored 0x{2:X}" -f $nowText, $Label, $Saved.Mode)
        return "restored"
    }
    LogWarn ("Could not restore the console input mode after {0} ({1}, wanted 0x{2:X}, Win32 error {3}) -- review menus may not echo; open a new terminal if a menu does not react" -f $Label, $nowText, $Saved.Mode, $rc)
    return "restore failed"
}
