# ---------------------------------------------------------------------------
# Backup a file before overwriting. Keeps at most $max_backups copies.
# A failed copy is non-fatal here (warn, return 0) and sets BACKUP_FILE_OK=false;
# callers that must not write without a backup check it (_managed_write).
# ---------------------------------------------------------------------------
BACKUP_FILE_OK=true
backup_file() {
    local file="$1" max_backups=20
    BACKUP_FILE_OK=true
    [ -f "$file" ] || return 0
    local ts
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    # A failed backup is non-fatal (config-file-safety.md "Backup before overwrite"):
    # warn and let the caller proceed.
    if ! cp "$file" "${file}.bak.${ts}"; then
        BACKUP_FILE_OK=false
        log_warn "Could not back up $(display_path "$file") -- proceeding without backup"
        return 0
    fi
    # Prune oldest beyond limit.
    # 2>/dev/null: ls errors only if no backup matches; the backup just written always does,
    # and an empty list is handled by the -n check below.
    local old_backups old
    old_backups=$(ls -1t "${file}.bak."* 2>/dev/null | tail -n +$((max_backups + 1))) || old_backups=""
    if [ -n "$old_backups" ]; then
        while IFS= read -r old; do
            if [ -n "$old" ] && ! rm -f "$old"; then
                log_warn "Could not prune old backup $(display_path "$old")"
            fi
        done <<< "$old_backups"
    fi
    log "Backed up $(display_path "$file")"
}
