# ---------------------------------------------------------------------------
# Managed-file helpers for deploy_managed_file, review_json_fields and the
# review prompts below. SOURCE is the source of truth; there is no deploy
# state (see the "Review choices" block above prompt_diff_review).
# ---------------------------------------------------------------------------

# [x]abort: log, then exit 2 (a bare exit 2 means user abort; commander
# decision 2026-10-21, D-TS13 reversed: no marker file). One helper for every
# review prompt. Parity: Invoke-ManagedAbort in aitools-lib.ps1.
_managed_abort() {
    log_error "Aborted by user"
    exit 2
}

# Deploy state (~/.aitools/deploy-state/) is no longer used. Files from older
# versions are left on disk; say so once per script run (detail level).
_MANAGED_STATE_NOTED=false
_managed_state_notice() {
    if [ "$_MANAGED_STATE_NOTED" = "true" ]; then return 0; fi
    _MANAGED_STATE_NOTED=true
    if [ -d "$HOME/.aitools/deploy-state" ]; then
        log_detail "deploy state is no longer used (SOURCE is the source of truth); $(display_path "$HOME/.aitools/deploy-state") left on disk"
    fi
}

# Adopting into a protected file is allowed: it writes only the working tree.
# WARN, naming the file, when the adopt target is listed in the protected-files
# table (.claude/rules/sources-of-truth.md) of the git repo that contains it.
# Table entries are backticked paths in the first column; * matches within one
# path segment.
_managed_protected_note() {
    local target="$1" dir top prefix rel table
    dir=$(dirname "$target")
    [ -d "$dir" ] || return 0
    # 2>/dev/null: git fails outside a repo; that means "not protected" (empty result checked).
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || top=""
    [ -n "$top" ] || return 0
    # 2>/dev/null: same as above; an empty prefix is valid (file at the repo root).
    prefix=$(git -C "$dir" rev-parse --show-prefix 2>/dev/null) || prefix=""
    table="$top/.claude/rules/sources-of-truth.md"
    [ -f "$table" ] || return 0
    rel="${prefix}$(basename "$target")"
    if perl -e '
        my ($table, $rel) = @ARGV;
        open my $fh, "<", $table or exit 1;
        while (my $line = <$fh>) {
            next unless $line =~ /^\|\s*`([^`]+)`/;
            my $pat = quotemeta($1);
            $pat =~ s/\\\*/[^\/]*/g;
            exit 0 if $rel =~ /^$pat$/;
        }
        exit 1;
    ' "$table" "$rel"; then
        log_warn "Adopted into protected file $(display_path "$target") -- working tree only; the review gate (.claude/rules/sources-of-truth.md) applies at commit"
    fi
}

# After adopt or merge: the library never commits or pushes. Say that the
# adopt target's repo has an uncommitted change to review, and WARN when the
# target is protected (_managed_protected_note).
_managed_adopt_notice() {
    local target="$1" top
    _managed_protected_note "$target"
    # 2>/dev/null: outside a git repo there is nothing to commit (empty result checked).
    top=$(git -C "$(dirname "$target")" rev-parse --show-toplevel 2>/dev/null) || top=""
    if [ -n "$top" ]; then
        log "Uncommitted change in $(display_path "$top"): $(basename "$target") -- review and commit it (cd $(display_path "$top") && git diff)"
    fi
}

# ---------------------------------------------------------------------------
# Write LOCAL and/or the adopt target as one step.
#   $1 = LOCAL path   ("" = LOCAL not written)    $2 = LOCAL content
#   $3 = adopt path   ("" = adopt target not written)  $4 = adopt content
# Content is written with exactly one trailing newline. Before anything is
# written, each existing file is snapshotted (for restore) and backed up
# (backup_file: rotated .bak.<ts>); a failed backup fails the step with
# nothing written. After writing, each file is validated: non-empty, and for
# a name ending in .json: valid JSON that has every top-level key listed in
# MANAGED_WRITE_REQUIRED_1 / _2 (JSON arrays for $1 / $3; unset = none; the
# caller sets them just before the call; they are cleared on return). On any
# failure every file this call touched is restored from its snapshot (a file
# that did not exist is removed), MANAGED_WRITE_ERROR is set, and 1 is
# returned. The caller logs MANAGED_WRITE_ERROR with log_error.
# ---------------------------------------------------------------------------
MANAGED_WRITE_ERROR=""
MANAGED_WRITE_REQUIRED_1=""
MANAGED_WRITE_REQUIRED_2=""
_managed_write() {
    local p1="$1" c1="$2" p2="$3" c2="$4"
    local req1="${MANAGED_WRITE_REQUIRED_1:-[]}" req2="${MANAGED_WRITE_REQUIRED_2:-[]}"
    MANAGED_WRITE_REQUIRED_1=""; MANAGED_WRITE_REQUIRED_2=""
    MANAGED_WRITE_ERROR=""
    local snapdir
    if ! snapdir=$(mktemp -d); then
        MANAGED_WRITE_ERROR="could not create a restore snapshot directory -- nothing written"
        return 1
    fi

    # Snapshot: s<N> holds the prior content; e<N> marks "did not exist".
    local i p c werr
    for i in 1 2; do
        if [ "$i" = "1" ]; then p="$p1"; else p="$p2"; fi
        [ -n "$p" ] || continue
        if [ -f "$p" ]; then
            if ! cp -p "$p" "$snapdir/s$i"; then
                MANAGED_WRITE_ERROR="could not snapshot $(display_path "$p") for restore -- nothing written"
                rm -rf "$snapdir"
                return 1
            fi
            backup_file "$p"
            if [ "$BACKUP_FILE_OK" != "true" ]; then
                MANAGED_WRITE_ERROR="backup of $(display_path "$p") failed -- nothing written"
                rm -rf "$snapdir"
                return 1
            fi
        else
            : > "$snapdir/e$i"
        fi
    done

    local rc=0 req
    for i in 1 2; do
        if [ "$i" = "1" ]; then p="$p1"; c="$c1"; req="$req1"; else p="$p2"; c="$c2"; req="$req2"; fi
        [ -n "$p" ] || continue
        if ! werr=$(mkdir -p "$(dirname "$p")" 2>&1); then
            MANAGED_WRITE_ERROR="cannot create the directory for $(display_path "$p"): $werr"
            rc=1; break
        fi
        if ! werr=$( { printf '%s\n' "$c" > "$p"; } 2>&1 ); then
            MANAGED_WRITE_ERROR="write failed for $(display_path "$p"): $werr"
            rc=1; break
        fi
        if [ ! -s "$p" ]; then
            MANAGED_WRITE_ERROR="validation failed: $(display_path "$p") is empty after the write"
            rc=1; break
        fi
        case "$p" in
            *.json)
                if ! werr=$(node -e "
const fs = require('fs');
let v;
try { v = JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); }
catch (e) { console.error('not valid JSON: ' + e.message); process.exit(1); }
const req = JSON.parse(process.argv[2]);
const isObj = v !== null && typeof v === 'object' && !Array.isArray(v);
const miss = isObj ? req.filter(k => !Object.prototype.hasOwnProperty.call(v, k)) : req;
if (miss.length) { console.error('missing required keys: ' + miss.join(', ')); process.exit(1); }
" "$p" "$req" 2>&1); then
                    MANAGED_WRITE_ERROR="validation failed: $(display_path "$p"): $werr"
                    rc=1; break
                fi ;;
        esac
    done

    if [ "$rc" -ne 0 ]; then
        for i in 1 2; do
            if [ "$i" = "1" ]; then p="$p1"; else p="$p2"; fi
            [ -n "$p" ] || continue
            if [ -f "$snapdir/s$i" ]; then
                # Restore only what changed (a write refused at open changed nothing).
                if ! cmp -s "$snapdir/s$i" "$p"; then
                    if cp -p "$snapdir/s$i" "$p"; then
                        log "Restored $(display_path "$p")"
                    else
                        log_error "Restore failed for $(display_path "$p") -- its backup is next to it (.bak.*)"
                    fi
                fi
            elif [ -f "$snapdir/e$i" ] && [ -e "$p" ]; then
                if rm -f "$p"; then
                    log "Removed partial $(display_path "$p")"
                else
                    log_error "Could not remove partial $(display_path "$p")"
                fi
            fi
        done
    fi
    rm -rf "$snapdir"
    return "$rc"
}
