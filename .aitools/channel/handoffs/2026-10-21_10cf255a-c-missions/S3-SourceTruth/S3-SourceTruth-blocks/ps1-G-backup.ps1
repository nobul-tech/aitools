# ---------------------------------------------------------------------------
# Backup a file before overwriting. Keeps at most $MaxBackups copies.
# A failed copy is non-fatal here (warn, return) and sets
# $script:BackupFileOk = $false; callers that must not write without a backup
# check it (Write-ManagedFiles).
# ---------------------------------------------------------------------------
$script:BackupFileOk = $true
function Backup-File {
    param([string]$FilePath, [int]$MaxBackups = 20)
    $script:BackupFileOk = $true
    if (-not (Test-Path $FilePath)) { return }
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
    $backupPath = "${FilePath}.bak.${ts}"
    # A failed backup is non-fatal (config-file-safety.md "Backup before overwrite"):
    # warn and let the caller proceed.
    try {
        Copy-Item -Path $FilePath -Destination $backupPath -ErrorAction Stop
    } catch {
        $script:BackupFileOk = $false
        LogWarn "Could not back up $FilePath -- proceeding without backup: $_"
        return
    }
    # Prune oldest beyond limit
    $backups = @(Get-ChildItem -Path "${FilePath}.bak.*" | Sort-Object LastWriteTime -Descending)
    if ($backups.Count -gt $MaxBackups) {
        foreach ($old in ($backups | Select-Object -Skip $MaxBackups)) {
            try { Remove-Item $old.FullName -Force -ErrorAction Stop }
            catch { LogWarn "Could not prune old backup $($old.FullName)" }
        }
    }
    Log "Backed up $FilePath"
}
