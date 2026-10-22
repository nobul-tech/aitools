# aitools-lib.sh -- shared helpers for all aitools bash scripts
# Sourced, not executed directly. No shebang, no set -euo pipefail (caller sets it).
#
# Provides: platform and environment detection (AITOOLS_PLATFORM, IS_MACOS,
# IS_WINDOWS, IS_LINUX, AITOOLS_ENVIRONMENT, is_claude_code_web,
# is_local_environment, write_environment_skip), display_path, read_config_key,
# logging_init, log/log_ok/log_error/log_warn/log_detail, invoke_ai,
# write_summary, show_summary, SORT_KEYS_JS, normalize_json.
#
# Usage:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
#   logging_init "script-name"
#
# Entry points (aitools, aitools-install) override log functions after sourcing
# for specialized logging (file-only, JSONL, etc.).

# ---------------------------------------------------------------------------
# Platform and environment detection (.claude/rules/cross-platform.md
# "Environment branches"; reference/cross-platform-detail.md "Platform and
# environment API"). Resolved once, when this library is sourced.
#   AITOOLS_PLATFORM     macos | linux | windows | unknown       (uname -s)
#   AITOOLS_ENVIRONMENT  claude-code-web | local
#     override: AITOOLS_ENVIRONMENT=claude-code-web|local already set
#     detect:   CLAUDE_CODE_REMOTE=true -> claude-code-web, else local
#     rule:     claude-code-web exists only on linux
# The code between the BEGIN/END markers is the canonical block that hooks embed
# verbatim (hooks cannot source this library). Change it here and in every hook
# that embeds it. A check-pre-commit step comparing the copies is planned (rollout
# batch R4); no hook embeds the block yet.
# ---------------------------------------------------------------------------
_AITOOLS_ENVIRONMENT_REQUESTED="${AITOOLS_ENVIRONMENT:-}"
# --- BEGIN aitools environment block ---
case "$(uname -s)" in
    Darwin*)              AITOOLS_PLATFORM="macos" ;;
    Linux*)               AITOOLS_PLATFORM="linux" ;;
    MINGW*|MSYS*|CYGWIN*) AITOOLS_PLATFORM="windows" ;;
    *)                    AITOOLS_PLATFORM="unknown" ;;
esac
case "${AITOOLS_ENVIRONMENT:-}" in
    claude-code-web|local) ;;
    *)
        if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
            AITOOLS_ENVIRONMENT="claude-code-web"
        else
            AITOOLS_ENVIRONMENT="local"
        fi ;;
esac
if [ "$AITOOLS_PLATFORM" != "linux" ]; then
    AITOOLS_ENVIRONMENT="local"
fi
# --- END aitools environment block ---
IS_MACOS=false
IS_WINDOWS=false
IS_LINUX=false
case "$AITOOLS_PLATFORM" in
    macos)   IS_MACOS=true ;;
    windows) IS_WINDOWS=true ;;
    linux)   IS_LINUX=true ;;
esac

# Predicates for environment branches (below the OS guard only).
is_claude_code_web()   { [ "$AITOOLS_ENVIRONMENT" = "claude-code-web" ]; }
is_local_environment() { [ "$AITOOLS_ENVIRONMENT" = "local" ]; }

# ---------------------------------------------------------------------------
# Log directory -- unified cross-platform location (reference/logging.md §1):
# ~/.aitools/logs on macOS, Linux, and Windows. Honors an explicit
# AITOOLS_LOG_DIR override (e.g. for tests).
# ---------------------------------------------------------------------------
AITOOLS_LOG_DIR="${AITOOLS_LOG_DIR:-$HOME/.aitools/logs}"

# ---------------------------------------------------------------------------
# Module-level counters (safe for sourcing without logging_init under set -u)
# ---------------------------------------------------------------------------
ERRORS=0
WARNINGS=0

# ---------------------------------------------------------------------------
# Display-friendly path (native Windows on MSYS, no-op elsewhere)
# ---------------------------------------------------------------------------
display_path() {
    if command -v cygpath &>/dev/null; then
        cygpath -w "$1"
    else
        printf '%s' "$1"
    fi
}

# ---------------------------------------------------------------------------
# Config reader (pure bash, handles UTF-8 BOM)
# ---------------------------------------------------------------------------
# Read a top-level string value from a JSON config file.
# Handles UTF-8 BOM (PowerShell 5.x writes one) and JSON-escaped backslashes.
read_config_key() {
    local file="$1" key="$2"
    [ -f "$file" ] || return 1
    local val
    val=$(tr -d '\357\273\277' < "$file" \
        | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -1 \
        | cut -d'"' -f4)
    [ -n "$val" ] || return 1
    # Unescape JSON backslashes: \\ -> \
    printf '%b' "$val"
}

# ---------------------------------------------------------------------------
# Logging init
# ---------------------------------------------------------------------------
# Sets SCRIPT_NAME, LOG_DIR, LOG_FILE; resets ERRORS, WARNINGS; creates log dir.
# Usage: logging_init "setup-foo"
# ---------------------------------------------------------------------------
# Log rotation (reference/logging.md §4): size-based, 5 MB x 5 backups.
# Fail-safe -- a broken rotate must never break the operation it records (§5).
# ---------------------------------------------------------------------------
_LOG_MAX_BYTES=5242880   # 5 MB
_LOG_BACKUP_COUNT=5
_rotate_log() {
    local f="$1"
    [ -f "$f" ] || return 0
    local size
    if [ "$(uname -s)" = "Darwin" ]; then
        size=$(stat -f %z "$f" 2>/dev/null || echo 0)
    else
        size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    fi
    [ "$size" -ge "$_LOG_MAX_BYTES" ] || return 0
    # Shift backups: <f>.4 -> <f>.5 ... <f>.1 -> <f>.2, then <f> -> <f>.1.
    # All mutations tolerate failure (fail-safe logging, logging.md §5).
    rm -f "$f.$_LOG_BACKUP_COUNT" 2>/dev/null || true
    local i=$_LOG_BACKUP_COUNT
    while [ "$i" -gt 1 ]; do
        local prev=$((i - 1))
        if [ -f "$f.$prev" ]; then
            mv -f "$f.$prev" "$f.$i" 2>/dev/null || true
        fi
        i=$prev
    done
    mv -f "$f" "$f.1" 2>/dev/null || true
}

logging_init() {
    SCRIPT_NAME="${1:?logging_init requires a script name}"
    LOG_DIR="$AITOOLS_LOG_DIR"
    LOG_FILE="$LOG_DIR/deploy.log"
    mkdir -p "$LOG_DIR"
    _rotate_log "$LOG_FILE"
    ERRORS=0
    WARNINGS=0
    _log_aitools_environment
}

# Record the resolved platform/environment (file-only detail line); warn when an
# AITOOLS_ENVIRONMENT override was invalid or not possible on this platform. The
# resolved value replaces an exported override, so child scripts do not warn again.
_log_aitools_environment() {
    log_detail "platform=$AITOOLS_PLATFORM environment=$AITOOLS_ENVIRONMENT (AITOOLS_ENVIRONMENT='$_AITOOLS_ENVIRONMENT_REQUESTED' CLAUDE_CODE_REMOTE='${CLAUDE_CODE_REMOTE:-}' type='${CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE:-}')"
    if [ -n "$_AITOOLS_ENVIRONMENT_REQUESTED" ] && [ "$_AITOOLS_ENVIRONMENT_REQUESTED" != "$AITOOLS_ENVIRONMENT" ]; then
        log_warn "AITOOLS_ENVIRONMENT='$_AITOOLS_ENVIRONMENT_REQUESTED' ignored (valid: local; claude-code-web on Linux only) -- environment is $AITOOLS_ENVIRONMENT"
    fi
}

# ---------------------------------------------------------------------------
# Standard logging (Pattern A: console + log file, with [level] tag)
# ---------------------------------------------------------------------------
log() {
    local level="${2:-info}"
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local line="[$ts] [$SCRIPT_NAME] [$level] $1"
    printf '%s\n' "$line" >> "$LOG_FILE"
    case "$level" in
        error) printf '\033[31m%s\033[0m\n' "$line" ;;
        warn)  printf '\033[33m%s\033[0m\n' "$line" ;;
        *)     printf '%s\n' "$line" ;;
    esac
}
log_ok()    { log "$1" "ok"; }
log_error() { log "$1" "error"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "$1" "warn"; WARNINGS=$((WARNINGS + 1)); }
log_detail() {
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '[%s] [%s] [detail] %s\n' "$ts" "$SCRIPT_NAME" "$1" >> "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# Agentic AI invocation -- generalized wrapper for claude/agent CLI
# ---------------------------------------------------------------------------
# Purpose: Standardized AI CLI invocation with speed/permission tiers,
#   validation callbacks, automatic retry, and telemetry logging.
# Inputs: SPEED (fast/balanced/quality), PERMISSIONS (none/readonly/full/
#   dangerous), VALIDATE_FN (function name, receives output as $1),
#   MAX_RETRIES (retry count on validation failure). Prompt from stdin.
# Expected output: Raw AI-generated text on stdout.
# Validation: Caller-provided VALIDATE_FN must return 0 (pass) or 1 (fail)
#   and set AI_REJECT_REASON on failure.
# Known limitations: Agent CLI has no --model flag; speed is hint-only via
#   prompt prefix. Retry prepends rejection reason but may not fix structural
#   issues (e.g., model always wrapping in code fences).

# File-only AI telemetry logging (avoids stdout capture interference when
# invoke_ai output is captured via $()). Does not increment ERRORS/WARNINGS --
# callers decide whether to count invoke_ai failures.
_ai_log() {
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '[%s] [%s] [%s] %s\n' "$ts" "$SCRIPT_NAME" "${2:-info}" "$1" >> "${LOG_FILE:-/dev/null}"
}

AI_REJECT_REASON=""

invoke_ai() {
    local speed="${1:-balanced}"
    local permissions="${2:-none}"
    local validate_fn="${3:-}"
    local max_retries="${4:-0}"

    AI_REJECT_REASON=""

    # Read prompt from stdin
    local prompt
    prompt=$(cat)

    # Detect backend
    # command -v exempt: existence check with explicit fallback chain
    local cli_cmd=""
    if command -v claude >/dev/null 2>&1; then
        cli_cmd="claude"
    elif $IS_WINDOWS; then
        # Windows Git Bash: agent may be on PowerShell PATH only
        local agent_path
        agent_path=$(pwsh -NoProfile -Command \
            'Get-Command agent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source' \
            2>/dev/null) || true  # pwsh may not be installed; fallback is no agent CLI
        if [ -n "$agent_path" ]; then cli_cmd="agent"; fi
    elif command -v agent >/dev/null 2>&1; then
        cli_cmd="agent"
    fi

    if [ -z "$cli_cmd" ]; then
        AI_REJECT_REASON="No AI CLI available (claude or agent)"
        _ai_log "AI invocation: no CLI available (claude or agent)" "error"
        return 1
    fi

    # Build CLI flags
    local -a flags=()

    if [ "$cli_cmd" = "claude" ]; then
        flags+=("-p" "--no-session-persistence")
        # Speed mapping (claude CLI: explicit model + effort)
        case "$speed" in
            fast)     flags+=("--model" "haiku" "--effort" "low") ;;
            balanced) flags+=("--model" "sonnet") ;;
            quality)  flags+=("--model" "opus" "--effort" "high") ;;
        esac
        # Permission mapping
        case "$permissions" in
            none)      flags+=("--allowedTools" "") ;;
            readonly)  flags+=("--allowedTools" "Read Glob Grep") ;;
            full)      ;; # default -- no restriction
            dangerous) flags+=("--dangerously-skip-permissions") ;;
        esac
        # System prompt hints for speed tiers
        case "$speed" in
            fast)    flags+=("--append-system-prompt" "Be concise and direct.") ;;
            quality) flags+=("--append-system-prompt" "Take your time. Be thorough.") ;;
        esac
    else
        # Agent CLI -- no --model flag; speed via prompt prefix only
        flags+=("-p" "--trust")
        # Permission mapping
        case "$permissions" in
            none)      flags+=("--mode" "ask") ;;
            readonly)  flags+=("--mode" "plan") ;;
            full)      ;; # default
            dangerous) flags+=("--force") ;;
        esac
    fi

    # Speed prefix for agent CLI (no model flag available)
    local speed_prefix=""
    if [ "$cli_cmd" = "agent" ]; then
        case "$speed" in
            fast)    speed_prefix="Be concise and direct. Prioritize speed.\n\n" ;;
            quality) speed_prefix="Take your time. Be thorough and precise.\n\n" ;;
        esac
    fi

    # Retry loop
    local attempt=0
    local current_prompt="$prompt"

    while [ "$attempt" -le "$max_retries" ]; do
        attempt=$((attempt + 1))

        _ai_log "AI invocation: speed=$speed backend=$cli_cmd attempt=$attempt"

        local full_prompt
        full_prompt=$(printf '%b%s' "$speed_prefix" "$current_prompt")

        local output
        # Suppress set -e abort; CLI may exit non-zero on model errors
        output=$(printf '%s' "$full_prompt" | "$cli_cmd" "${flags[@]}" 2>&1) || true

        if [ -z "$output" ]; then
            AI_REJECT_REASON="Empty output from $cli_cmd"
            _ai_log "AI invocation: speed=$speed backend=$cli_cmd attempt=$attempt result=empty" "warn"
            if [ "$attempt" -le "$max_retries" ]; then
                current_prompt=$(printf 'Your previous output was empty. Try again.\n\n%s' "$prompt")
                continue
            fi
            return 1
        fi

        # Validate if function provided
        if [ -n "$validate_fn" ]; then
            if ! "$validate_fn" "$output"; then
                [ -z "$AI_REJECT_REASON" ] && AI_REJECT_REASON="Validation failed"
                _ai_log "AI invocation: speed=$speed backend=$cli_cmd attempt=$attempt result=rejected reason=$AI_REJECT_REASON" "warn"
                while IFS= read -r _rej_line; do
                    log_detail "ai-rejected: $_rej_line"
                done <<< "$output"
                if [ "$attempt" -le "$max_retries" ]; then
                    current_prompt=$(printf 'Your previous output was rejected: %s. Try again.\n\n%s' \
                        "$AI_REJECT_REASON" "$prompt")
                    continue
                fi
                _ai_log "AI invocation: speed=$speed backend=$cli_cmd exhausted after $attempt attempts" "warn"
                return 1
            fi
        fi

        # Success
        _ai_log "AI invocation: speed=$speed backend=$cli_cmd attempt=$attempt result=accepted"
        printf '%s' "$output"
        return 0
    done

    return 1
}

# ---------------------------------------------------------------------------
# Summary writer (3-arg: category, tool, detail)
# ---------------------------------------------------------------------------
write_summary() {
    if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then
        local cat="$1"
        # Auto-promote OK to WARN when warnings have been logged
        if [ "$cat" = "OK" ] && [ "${WARNINGS:-0}" -gt 0 ]; then
            cat="WARN"
        fi
        printf '%s|%s|%s\n' "$cat" "$2" "$3" >> "$AITOOLS_SUMMARY_FILE"
    fi
}

# ---------------------------------------------------------------------------
# Environment skip: a step that does not apply in this environment reports one
# OK row "n/a (<environment>)" plus the reason in the log (cross-platform.md
# "Environment branches"). Not WARN (nothing is wrong) and not "skipped" (a
# governed term for the user's deployment choice).
# Usage: write_environment_skip "google chrome" "managed only in Claude Code web (D-CHR1)"
# ---------------------------------------------------------------------------
write_environment_skip() {
    local tool="$1" reason="$2"
    log "n/a in the $AITOOLS_ENVIRONMENT environment: $reason"
    write_summary OK "$tool" "n/a ($AITOOLS_ENVIRONMENT)"
}

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

# ---------------------------------------------------------------------------
# Backup a directory before modifying managed files. Keeps at most $max_backups copies.
# ---------------------------------------------------------------------------
backup_dir() {
    local dir="$1" max_backups=5
    [ -d "$dir" ] || return 0
    local file_count
    file_count=$(find "$dir" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
    if [ "$file_count" -eq 0 ]; then
        return 0
    fi
    local ts
    ts=$(date -u +%Y-%m-%dT%H%M%SZ)
    if ! cp -R "$dir" "${dir}.bak.${ts}"; then
        log_warn "Could not back up $(display_path "$dir") -- proceeding without backup"
        return 0
    fi
    local old_backups
    old_backups=$(find "$(dirname "$dir")" -maxdepth 1 -name "$(basename "$dir").bak.*" -type d \
        | sort -r | tail -n +$((max_backups + 1)))
    if [ -n "$old_backups" ]; then
        printf '%s\n' "$old_backups" | while IFS= read -r old_dir; do
            rm -rf "$old_dir"
            log "Pruned old backup: $(display_path "$old_dir")"
        done
    fi
    log "Backed up $(display_path "$dir") ($file_count managed files)"
}

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
        elif ! : > "$snapdir/e$i"; then
            MANAGED_WRITE_ERROR="could not record restore state for $(display_path "$p") -- nothing written"
            rm -rf "$snapdir"
            return 1
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

# ---------------------------------------------------------------------------
# Merge file description lookup
# ---------------------------------------------------------------------------
# Purpose: Returns a human-readable description of a managed file for AI merge
#   prompts, providing context about the file's role in the config system.
# Inputs: $1 = file path
# Expected output: Single-line description string on stdout.
_get_merge_file_description() {
    case "$(basename "$1")" in
        CLAUDE.md) printf 'User-scope CLAUDE.md -- personal preferences and instructions for Claude Code' ;;
        *.md)      printf 'Configuration rule: %s' "$(basename "$1")" ;;
        *.json)    printf 'JSON config: %s' "$(basename "$1")" ;;
        *)         printf 'Managed file: %s' "$(basename "$1")" ;;
    esac
}

# ---------------------------------------------------------------------------
# AI merge prompt builder (initial merge)
# ---------------------------------------------------------------------------
# Purpose: Builds a structured merge prompt following the Role/Context/Task/
#   Constraints/Format pattern for merging managed configuration files.
# Inputs: $1=file_path, $2=source_content, $3=local_content, $4=diff_output
# Expected output: Complete prompt string on stdout, suitable for invoke_ai.
# Validation: validate_ai_merge_output (5 checks: conversational, fences,
#   refusal, truncation, header preservation)
# Known limitations: Very large files may hit model context limits. Files with
#   no markdown headers rely on Check 4 (length) for rewrite detection.
_ai_prompt_merge() {
    local file_path="$1"
    local source_content="$2"
    local local_content="$3"
    local diff_output="$4"

    local file_desc
    file_desc=$(_get_merge_file_description "$file_path")

    printf '%s' "You are merging a managed configuration file during automated deployment.

## What you are merging
${file_desc}

## Where changes come from
SOURCE: The canonical template, synced across machines -- the updated version being deployed
LOCAL: The user's current file on this machine, with their customizations

## What is happening
Updated configuration is being deployed. Source has changed and needs to be
incorporated without losing local customizations.

## Differences (unified diff: local vs source)
${diff_output}

## Full local file (start from this)
<LOCAL>
${local_content}
</LOCAL>

## Rules
1. Start with LOCAL as your base -- preserve all user customizations
2. Apply ONLY the changes shown in the diff
3. If a change conflicts with a local customization (contradicts its intent), keep local
4. If a change adds new content not in LOCAL, add it in the appropriate location
5. If a change updates content the user hasn't customized, apply it
6. CRITICAL: Do NOT wrap your output in markdown code fences (\`\`\`). Output raw file content ONLY
7. No commentary, no explanation, no preamble -- just the merged file content"
}

# ---------------------------------------------------------------------------
# AI merge prompt builder (refinement)
# ---------------------------------------------------------------------------
# Purpose: Builds a refinement prompt for iterating on a previous merge result
#   based on user feedback.
# Inputs: $1=source_content, $2=local_content, $3=current_merge, $4=feedback
# Expected output: Complete prompt string on stdout, suitable for invoke_ai.
# Validation: Same as initial merge (validate_ai_merge_output).
_ai_prompt_merge_refine() {
    local source_content="$1"
    local local_content="$2"
    local current_merge="$3"
    local feedback="$4"

    printf '%s' "You are refining a merged configuration file based on user feedback.

## Context
A previous merge produced CURRENT_MERGE from SOURCE + LOCAL. The user wants changes.

## SOURCE (original template)
<SOURCE>
${source_content}
</SOURCE>

## LOCAL (original user file)
<LOCAL>
${local_content}
</LOCAL>

## CURRENT MERGE (previous result)
<CURRENT_MERGE>
${current_merge}
</CURRENT_MERGE>

## User Feedback
${feedback}

## Rules
- Apply the user's feedback to CURRENT_MERGE
- Keep all content from CURRENT_MERGE not affected by the feedback
- Output the revised merged file content ONLY -- no preamble, no explanation, no markdown fences"
}

# Merge validation wrapper for invoke_ai -- captures source/local context
# via module-level variables set by _invoke_ai_merge before calling invoke_ai.
_MERGE_VALIDATE_SOURCE=""
_MERGE_VALIDATE_LOCAL=""
_merge_validate() {
    # Return the validator's status: the assignment below would otherwise make
    # this function return 0 and accept every output (parity: _MergeValidateWrapper).
    local rc=0
    validate_ai_merge_output "$1" "$_MERGE_VALIDATE_SOURCE" "$_MERGE_VALIDATE_LOCAL" || rc=$?
    AI_REJECT_REASON="$MERGE_REJECT_REASON"
    return "$rc"
}

MERGE_REJECT_REASON=""

# ---------------------------------------------------------------------------
# Validate AI merge output before accepting it.
# Returns 0 if valid, 1 if invalid. Sets MERGE_REJECT_REASON on failure.
# ---------------------------------------------------------------------------
validate_ai_merge_output() {
    local output="$1"
    local source_content="$2"
    local local_content="$3"
    MERGE_REJECT_REASON=""

    # Check 1: conversational patterns (first non-empty line)
    local first_line
    first_line=$(printf '%s' "$output" | perl -ne 'if (/\S/) { print; exit }')
    if printf '%s' "$first_line" | perl -ne 'exit 0 if /^(I |Here|Sure|Certainly|Let me)/i; exit 1'; then
        MERGE_REJECT_REASON="AI responded conversationally instead of producing merged content"
        return 1
    fi

    # Check 2: markdown code fences
    if printf '%s\n' "$output" | perl -ne 'exit 0 if /^```/; END { exit 1 }'; then
        MERGE_REJECT_REASON="AI wrapped output in code fences -- need raw content"
        return 1
    fi

    # Check 3: conversational refusal patterns (not bare keywords -- content may
    # legitimately contain "permission", "access", etc.)
    if printf '%s' "$output" | perl -ne 'exit 0 if /(?:I don.t have permission|I cannot access|I.m not authorized|I need (?:your )?approval|permission denied|access denied|I.m unable to|I can.t (?:read|write|access|open|modify))/i; END { exit 1 }'; then
        MERGE_REJECT_REASON="AI indicated it couldn't perform the merge"
        return 1
    fi

    # Check 4: minimum length (output >= 50% of shorter input when shorter > 40 chars)
    local out_len src_len local_len min_input_len threshold
    out_len=$(printf '%s' "$output" | wc -c | tr -d ' ')
    src_len=$(printf '%s' "$source_content" | wc -c | tr -d ' ')
    local_len=$(printf '%s' "$local_content" | wc -c | tr -d ' ')
    if [ "$src_len" -le "$local_len" ]; then min_input_len=$src_len; else min_input_len=$local_len; fi
    threshold=$((min_input_len / 2))
    if [ "$min_input_len" -gt 40 ] && [ "$out_len" -lt "$threshold" ]; then
        MERGE_REJECT_REASON="Output too short ($out_len chars, expected ${threshold}+) -- likely truncated"
        return 1
    fi

    # Check 5: header preservation — deduplicated headers from source+local must
    # be >=60% preserved in output. Files with 0 headers pass (Check 4 handles truncation).
    local combined_headers
    combined_headers=$(printf '%s\n%s' "$source_content" "$local_content" \
        | grep -E '^#{1,6} ' | sort -u)
    local total preserved=0
    total=$(printf '%s\n' "$combined_headers" | grep -c '^' || true)  # count lines; may be 0
    if [ "$total" -gt 0 ]; then
        while IFS= read -r header; do
            [ -z "$header" ] && continue
            printf '%s' "$output" | grep -qF "$header" && preserved=$((preserved + 1))
        done <<< "$combined_headers"
        local threshold=$(( (total * 60 + 99) / 100 ))
        [ "$threshold" -lt 1 ] && threshold=1
        if [ "$preserved" -lt "$threshold" ]; then
            MERGE_REJECT_REASON="Rewrote too much ($preserved/$total section headers preserved, need 60%+)"
            return 1
        fi
    fi

    return 0
}

MERGED_CONTENT=""

# ---------------------------------------------------------------------------
# Spinner for AI operations (visual progress indicator)
# ---------------------------------------------------------------------------
_AI_SPINNER_PID=""

_start_spinner() {
    local msg="${1:-working...}"
    (
        local chars='/-\|'
        local i=0
        while true; do
            printf '\r  %s %s' "${chars:$((i % 4)):1}" "$msg" > /dev/tty
            i=$((i + 1))
            sleep 0.2
        done
    ) &
    _AI_SPINNER_PID=$!
}

_stop_spinner() {
    if [ -n "$_AI_SPINNER_PID" ] && kill -0 "$_AI_SPINNER_PID" 2>/dev/null; then
        kill "$_AI_SPINNER_PID" 2>/dev/null
        wait "$_AI_SPINNER_PID" 2>/dev/null || true  # reap; exit code irrelevant for spinner
    fi
    _AI_SPINNER_PID=""
    printf '\r  \033[K' > /dev/tty  # clear spinner line
}

# ---------------------------------------------------------------------------
# Interactive = stdin is a terminal AND the controlling terminal can be opened.
# Spec (managed-file-deployment.md, interactive-menus.md): non-terminal stdin ->
# no prompt, source wins. Prompts still read /dev/tty so data piped on stdin is
# never consumed as an answer. Parity: Test-InteractiveConsole in aitools-lib.ps1.
# ---------------------------------------------------------------------------
tty_interactive() {
    [ -t 0 ] || return 1
    # 2>/dev/null: the open fails when there is no controlling terminal; that
    # failure is the answer (return 1), not an error to report.
    (printf '' > /dev/tty) 2>/dev/null
}

# ---------------------------------------------------------------------------
# EOF-safe prompt read. Usage: read_tty_choice <var> <what-the-default-does>
# Bare `read -r x < /dev/tty` returns 1 at EOF (closed stdin under a pty), which
# aborts the caller under set -e with no log line. This logs and returns 0 with
# <var> empty, so each caller's `*)` default branch applies.
# ---------------------------------------------------------------------------
read_tty_choice() {
    local __var="$1" __default_desc="$2" __line=""
    if ! IFS= read -r __line < /dev/tty; then
        printf '\n' > /dev/tty
        log_warn "No input at prompt (EOF) -- defaulting to $__default_desc"
        __line=""
    fi
    printf -v "$__var" '%s' "$__line"
}

# ---------------------------------------------------------------------------
# Agentic merge via invoke_ai with refinement loop ([m]erge & adopt).
# Uses structured prompts from _ai_prompt_merge / _ai_prompt_merge_refine.
# Sets DIFF_REVIEW_RESULT to:
#   "merge"  -- [y]es: MERGED_CONTENT holds the accepted merge
#   "menu"   -- [n]o: the preview was rejected; prompt_diff_review shows its
#               menu again (nothing written)
#   "failed" -- the AI merge produced no valid output; MANAGED_MERGE_ERROR
#               holds the reason (deploy_managed_file logs it; nothing written)
# ---------------------------------------------------------------------------
MANAGED_MERGE_ERROR=""
_invoke_ai_merge() {
    local file_path="$1"
    local source_content="$2"
    local local_content="${3:-}"
    local diff_output="${4:-}"

    MANAGED_MERGE_ERROR=""

    # Read local from disk if not provided (backward compat)
    if [ -z "$local_content" ] && [ -f "$file_path" ]; then
        local_content=$(cat "$file_path")
    fi

    # Detect backend for transparency display
    local ai_backend="unknown"
    if command -v claude >/dev/null 2>&1; then
        ai_backend="claude"
    elif command -v agent >/dev/null 2>&1; then
        ai_backend="agent"
    fi
    local display_name
    display_name=$(basename "$file_path")
    printf '  >> AI merge: %s (balanced) -- merging %s...\n' "$ai_backend" "$display_name" > /dev/tty

    # Set validation context for _merge_validate wrapper
    _MERGE_VALIDATE_SOURCE="$source_content"
    _MERGE_VALIDATE_LOCAL="$local_content"

    local current_merge=""
    local iteration=0

    while true; do
        iteration=$((iteration + 1))
        local prompt_text

        if [ -z "$current_merge" ]; then
            prompt_text=$(_ai_prompt_merge "$file_path" "$source_content" "$local_content" "$diff_output")
        else
            local feedback
            printf '  refinement feedback: ' > /dev/tty
            read_tty_choice feedback "no feedback"
            prompt_text=$(_ai_prompt_merge_refine "$source_content" "$local_content" "$current_merge" "$feedback")
        fi

        local merged
        _start_spinner "merging $display_name (attempt $iteration)..."
        # invoke_ai returns 1 on failure with no stdout; || true suppresses set -e abort
        # (the empty result is checked just below)
        merged=$(printf '%s' "$prompt_text" | invoke_ai balanced none _merge_validate 1) || true
        _stop_spinner

        # Defense-in-depth: strip leading/trailing code fences if AI ignored instructions
        if [ -n "$merged" ]; then
            merged=$(printf '%s' "$merged" | perl -0777 -pe 's/\A```[^\n]*\n//; s/\n```\s*\z//')
        fi

        if [ -z "$merged" ]; then
            MANAGED_MERGE_ERROR="AI merge failed (iteration $iteration): ${AI_REJECT_REASON:-unknown error}"
            printf '  >> %s -- nothing written\n' "$MANAGED_MERGE_ERROR" > /dev/tty
            DIFF_REVIEW_RESULT="failed"
            return 0
        fi

        # Show merge preview
        printf '\n  --- merged result preview (first 30 lines) ---\n' > /dev/tty
        printf '%s\n' "$merged" | head -30 | while IFS= read -r line; do
            printf '  | %s\n' "$line" > /dev/tty
        done
        local total_lines
        total_lines=$(printf '%s\n' "$merged" | wc -l | tr -d ' ')
        if [ "$total_lines" -gt 30 ]; then
            printf '  | ... (%d more lines)\n' "$((total_lines - 30))" > /dev/tty
        fi
        printf '\n  [y]es accept / [r]efine / [n]o reject: ' > /dev/tty
        local accept
        read_tty_choice accept "reject the merge (back to the review menu)"
        case "$(printf '%s' "$accept" | tr '[:upper:]' '[:lower:]')" in
            y)
                MERGED_CONTENT="$merged"
                DIFF_REVIEW_RESULT="merge"
                printf '  >> merged: AI-merged content accepted (iteration %d)\n' "$iteration" > /dev/tty
                return 0
                ;;
            r)
                current_merge="$merged"
                printf '  >> refining merge (iteration %d)...\n' "$iteration" > /dev/tty
                continue
                ;;
            *)
                printf '  >> merge rejected -- back to the review menu\n' > /dev/tty
                DIFF_REVIEW_RESULT="menu"
                return 0
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Review choices -- what each one does. Applies to prompt_diff_review,
# deploy_managed_file and review_json_fields below (PS1 twins:
# Prompt-DiffReview, Deploy-ManagedFile, Review-JsonFields). Spec:
# reference/managed-file-deployment.md. Model and AI merge rules:
# .claude/rules/agentic-standards.md "Managed-file review choices and merge".
#
# Terms:
#   SOURCE       the content being deployed (repo or dotprofile); the source
#                of truth
#   LOCAL        the deployed file on disk
#   ADOPT TARGET the repo file SOURCE comes from (ADOPT_PATH). The caller
#                passes its path; this library writes it. "" = no adopt
#                target: adopt and merge are not offered.
# There is no ancestor and no deploy state: the only comparison is SOURCE
# against LOCAL (trailing newlines normalized).
#
# No menu is shown when:
#   LOCAL missing                       -> SOURCE written, "created"
#   LOCAL == SOURCE                     -> nothing written, "verified"
#   no terminal, EOF, or AITOOLS_FORCE  -> SOURCE written (backup), "updated"
#
# Text files (DEST not ending in .json), one review per file:
#   [o]verwrite      -> SOURCE written to LOCAL (backup kept); "updated"
#   [a]ccept & adopt -> LOCAL kept; LOCAL copied to the adopt target now;
#                       "accept & adopt"
#   [m]erge & adopt  -> AI merge (_invoke_ai_merge: invoke_ai balanced/none,
#                       validated, previewed; [y]es / [r]efine / [n]o). [y]:
#                       the merge is written to LOCAL and to the adopt target
#                       now; "accept & adopt". [n]: back to this menu. No valid
#                       merge output: nothing written; "failed".
#   [s]kip           -> nothing written; "skipped"; reviewed again next run
#   [x]abort         -> log_error, exit 2: ends this script
# After adopt or merge, SOURCE, LOCAL and the adopt target agree, so the next
# run verifies the file and asks nothing. A caller whose adopt target is not a
# plain copy of LOCAL (CLAUDE.md: machine footer stripped, profile tokens
# restored) passes an adopt filter; the adopt target gets the filtered content.
#
# JSON files (DEST ending in .json; review_json_fields): node compares SOURCE
# and LOCAL field by field (key path; a whole array is one field). Each
# differing field is one prompt_json_field_review: [o]verwrite (SOURCE value
# to LOCAL), [a]dopt (LOCAL value to the adopt target), [s]kip, [x]abort. No
# merge. A field only in LOCAL stays in LOCAL: with an adopt target and a
# terminal it gets [a]dopt / [s]kip / [x]abort (no overwrite); otherwise it is
# kept without a prompt. Key order is preserved in both files. One result per
# file, by precedence: failed > accept & adopt > skipped > updated > verified.
#
# Failure: every file a step writes (LOCAL, and the adopt target for adopt or
# merge) is snapshotted and backed up first (a failed backup of an existing
# file fails the step: nothing written) and validated after (non-empty; JSON
# parses and keeps SOURCE's top-level keys, except keys the review chose to
# leave absent). If a write, the merge or a validation fails, the files are
# restored, the reason is logged (log_error), the result is "failed" (the
# caller records it; deploy_tracker_summary writes an ERROR row) and the run
# continues with the next file. An adopt target listed in its repo's
# protected-files table (.claude/rules/sources-of-truth.md) gets a WARN that
# names it: working tree only; the review gate applies at commit. The library
# never commits or pushes: after adopt or merge it logs that the adopt
# target's repo has an uncommitted change to review and ship.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Show SOURCE against LOCAL and ask what to do ("Review choices" above).
#
# Args:
#   $1 = DEST, the deployed file on disk (LOCAL)
#   $2 = NEW_CONTENT, the SOURCE content
#   $3 = ADOPT_OFFERED: 1 offers [a]ccept & adopt and [m]erge & adopt; 0 hides them
#   $4 = CUR_CONTENT, LOCAL content (optional; read from DEST when empty)
#
# Sets DIFF_REVIEW_RESULT to "overwrite", "adopt", "merge", "skip" or
# "failed"; "merge" also sets MERGED_CONTENT; "failed" (the AI merge produced
# no valid output) sets MANAGED_MERGE_ERROR. Exits 2 on [x]abort
# (_managed_abort).
# Non-interactive, EOF at the prompt, --force / AITOOLS_FORCE: "overwrite".
# ---------------------------------------------------------------------------
DIFF_REVIEW_RESULT=""
_PDR_ADOPT_TARGET=""   # set by deploy_managed_file; shown in the review header only
prompt_diff_review() {
    local file_path="$1"
    local new_content="$2"
    local adopt_offered="${3:-0}"
    local cur_content="${4:-}"

    DIFF_REVIEW_RESULT="overwrite"
    MERGED_CONTENT=""

    # --force or AITOOLS_FORCE: auto-overwrite
    if [ "${AITOOLS_FORCE:-}" = "1" ] || [ "${FORCE:-}" = "true" ]; then
        log_warn "Diff in $(display_path "$file_path") -- overwriting (--force)"
        return 0
    fi

    # Non-interactive: auto-overwrite
    if ! tty_interactive; then
        log_warn "Diff in $(display_path "$file_path") -- overwriting (non-interactive)"
        return 0
    fi

    # Read current file if not provided
    if [ -z "$cur_content" ] && [ -f "$file_path" ]; then
        cur_content=$(cat "$file_path")
    fi

    # Context header
    printf '\n\033[33m[REVIEW]\033[0m %s differs from source.\n' \
        "$(display_path "$file_path")" > /dev/tty
    printf '  source = the repo version (would deploy)\n' > /dev/tty
    printf '  local  = current file on disk\n' > /dev/tty
    if [ "$adopt_offered" = "1" ] && [ -n "$_PDR_ADOPT_TARGET" ]; then
        printf '  repo   = %s (adopt target)\n' "$(display_path "$_PDR_ADOPT_TARGET")" > /dev/tty
    fi
    printf '\n' > /dev/tty

    # Show diff
    local diff_output
    # diff exits 1 on differences (expected), suppress set -e abort
    diff_output=$(diff -u <(printf '%s' "$new_content") <(printf '%s' "$cur_content") \
        --label "source (would deploy)" --label "local (on disk)" 2>&1) || true
    local diff_lines
    diff_lines=$(printf '%s\n' "$diff_output" | wc -l | tr -d ' ')
    if [ "$diff_lines" -le 40 ]; then
        printf '%s\n' "$diff_output" > /dev/tty
    else
        printf '%s\n' "$diff_output" | head -30 > /dev/tty
        printf '  ... (%d more lines -- full diff in deploy log)\n' \
            "$((diff_lines - 30))" > /dev/tty
    fi
    # Full diff as structured [detail] records at every size (raw appends broke the log format).
    local diff_line
    while IFS= read -r diff_line; do
        log_detail "diff $(basename "$file_path"): $diff_line"
    done <<< "$diff_output"

    # Menu (parity: Prompt-DiffReview in aitools-lib.ps1). A rejected merge
    # preview ("menu") shows the menu again.
    local choice
    while true; do
        printf '\n' > /dev/tty
        printf '  [o]verwrite      : source wins -> written to local (backup kept)\n' > /dev/tty
        if [ "$adopt_offered" = "1" ]; then
            printf '  [a]ccept & adopt : local wins -> copied to the repo now\n' > /dev/tty
            printf '  [m]erge & adopt  : AI merge of source + local -> local and the repo\n' > /dev/tty
        fi
        printf '  [s]kip           : nothing written; asked again next run\n' > /dev/tty
        printf '  [x]abort         : stop this script (exit 2)\n' > /dev/tty
        if [ "$adopt_offered" = "1" ]; then
            printf '  choice [o/a/m/s/x]: ' > /dev/tty
        else
            printf '  choice [o/s/x]: ' > /dev/tty
        fi

        read_tty_choice choice "overwrite"
        case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')" in
            a)  if [ "$adopt_offered" = "1" ]; then
                    printf '  >> accept & adopt: local kept, copied to the repo\n' > /dev/tty
                    DIFF_REVIEW_RESULT="adopt"
                else
                    printf '  >> overwritten: source deployed to local (backup kept)\n' > /dev/tty
                    DIFF_REVIEW_RESULT="overwrite"
                fi ;;
            m)  if [ "$adopt_offered" = "1" ]; then
                    _invoke_ai_merge "$file_path" "$new_content" "$cur_content" "$diff_output"
                else
                    printf '  >> overwritten: source deployed to local (backup kept)\n' > /dev/tty
                    DIFF_REVIEW_RESULT="overwrite"
                fi ;;
            s)  printf '  >> skipped: local file unchanged\n' > /dev/tty
                DIFF_REVIEW_RESULT="skip" ;;
            x)  _managed_abort ;;
            *)  printf '  >> overwritten: source deployed to local (backup kept)\n' > /dev/tty
                DIFF_REVIEW_RESULT="overwrite" ;;
        esac
        if [ "$DIFF_REVIEW_RESULT" != "menu" ]; then break; fi
    done
    return 0
}

# ---------------------------------------------------------------------------
# Deploy one managed file. SOURCE is the source of truth ("Review choices"
# above prompt_diff_review). Parity: Deploy-ManagedFile in aitools-lib.ps1.
#
# Args:
#   $1 = SRC_CONTENT   content to deploy (SOURCE)
#   $2 = DEST          deployed path (LOCAL). A name ending in .json is
#                      reviewed field by field (review_json_fields).
#   $3 = TOOL_NAME     summary tool name (e.g. "claude rules")
#   $4 = ITEM_NAME     item name for log lines (e.g. "concurrent-agents.md")
#   $5 = ADOPT_PATH    absolute path of the repo file that is the source of
#                      truth; "" = adopt and merge are not offered
#   $6 = ADOPT_FILTER  optional, text files only: name of a function that
#                      reads LOCAL content on stdin and prints the content the
#                      adopt target gets (CLAUDE.md strips its machine footer
#                      and restores profile tokens). "" = plain copy.
#
# Sets MANAGED_FILE_RESULT to "created", "updated", "verified",
# "accept & adopt", "skipped" or "failed". On "failed" nothing is left
# half-written (snapshots restored) and the reason is logged with log_error;
# the caller records the outcome (deploy_tracker_record, or its own ERROR
# row). Exits 2 on [x]abort. Honors DRY_RUN (reports, writes nothing).
# ---------------------------------------------------------------------------
MANAGED_FILE_RESULT=""
deploy_managed_file() {
    local src_content="$1"
    local dest="$2"
    local tool_name="$3"
    local item_name="$4"
    local adopt_path="${5:-}"
    local adopt_filter="${6:-}"

    MANAGED_FILE_RESULT="verified"
    _managed_state_notice

    # Normalize trailing newlines for a stable comparison: command substitution
    # strips them, and every write adds exactly one back.
    src_content=$(printf '%s' "$src_content" | perl -0777 -pe 's/[\r\n]+$/\n/')

    # Dry run: report what would happen without writing
    if [ "${DRY_RUN:-}" = "true" ]; then
        if [ -f "$dest" ]; then
            local _dr_existing
            _dr_existing=$(cat "$dest")
            _dr_existing=$(printf '%s' "$_dr_existing" | perl -0777 -pe 's/[\r\n]+$/\n/')
            if [ "$_dr_existing" = "$src_content" ]; then
                log "[DRY RUN] Unchanged: $item_name"
            else
                log "[DRY RUN] Would update: $item_name -> $(display_path "$dest")"
            fi
        else
            log "[DRY RUN] Would create: $item_name -> $(display_path "$dest")"
        fi
        return 0
    fi

    # JSON: field-by-field review
    case "$dest" in
        *.json)
            local _src_tmp
            if ! _src_tmp=$(mktemp); then
                log_error "Failed: $item_name: could not create a temp file for the JSON review"
                MANAGED_FILE_RESULT="failed"
                return 0
            fi
            if ! printf '%s\n' "$src_content" > "$_src_tmp"; then
                rm -f "$_src_tmp"
                log_error "Failed: $item_name: could not write a temp file for the JSON review"
                MANAGED_FILE_RESULT="failed"
                return 0
            fi
            review_json_fields "$_src_tmp" "$dest" "$adopt_path"
            rm -f "$_src_tmp"
            return 0 ;;
    esac

    # New file: create
    if [ ! -f "$dest" ]; then
        if _managed_write "$dest" "$src_content" "" ""; then
            log_ok "Created: $item_name -> $(display_path "$dest")"
            MANAGED_FILE_RESULT="created"
        else
            log_error "Failed: $item_name: $MANAGED_WRITE_ERROR"
            MANAGED_FILE_RESULT="failed"
        fi
        return 0
    fi

    local existing
    if ! existing=$(cat "$dest"); then
        log_error "Failed: $item_name: cannot read $(display_path "$dest")"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi
    existing=$(printf '%s' "$existing" | perl -0777 -pe 's/[\r\n]+$/\n/')
    if [ "$existing" = "$src_content" ]; then
        MANAGED_FILE_RESULT="verified"
        return 0
    fi

    # LOCAL differs from SOURCE: review (non-interactive / EOF / --force -> overwrite)
    local adopt_offered=0
    if [ -n "$adopt_path" ]; then adopt_offered=1; fi
    _PDR_ADOPT_TARGET="$adopt_path"
    prompt_diff_review "$dest" "$src_content" "$adopt_offered" "$existing"
    _PDR_ADOPT_TARGET=""

    local p_local="$dest" local_out="$src_content" p_repo="" repo_content=""
    case "$DIFF_REVIEW_RESULT" in
        skip)
            log_warn "Skipped: $item_name (local differs from source; reviewed again next run)"
            MANAGED_FILE_RESULT="skipped"
            return 0 ;;
        failed)
            log_error "Failed: $item_name: ${MANAGED_MERGE_ERROR:-AI merge failed} -- nothing written"
            MANAGED_FILE_RESULT="failed"
            return 0 ;;
        adopt)
            p_local=""; local_out=""
            p_repo="$adopt_path"; repo_content="$existing" ;;
        merge)
            local_out=$(printf '%s' "$MERGED_CONTENT" | perl -0777 -pe 's/[\r\n]+$/\n/')
            p_repo="$adopt_path"; repo_content="$local_out" ;;
    esac

    # The adopt target gets LOCAL (or the merge), passed through the filter if any
    if [ -n "$p_repo" ] && [ -n "$adopt_filter" ]; then
        local filtered
        if ! filtered=$(printf '%s\n' "$repo_content" | "$adopt_filter") || [ -z "$filtered" ]; then
            log_error "Failed: $item_name: adopt filter $adopt_filter failed -- nothing written"
            MANAGED_FILE_RESULT="failed"
            return 0
        fi
        repo_content="$filtered"
    fi

    if ! _managed_write "$p_local" "$local_out" "$p_repo" "$repo_content"; then
        log_error "Failed: $item_name: $MANAGED_WRITE_ERROR (files restored)"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi

    if [ -n "$p_repo" ]; then
        log_ok "Accept & adopt: $item_name -> $(display_path "$p_repo")"
        _managed_adopt_notice "$p_repo"
        MANAGED_FILE_RESULT="accept & adopt"
    else
        log_ok "Updated: $item_name -> $(display_path "$dest")"
        MANAGED_FILE_RESULT="updated"
    fi
}

# ---------------------------------------------------------------------------
# Review a JSON managed file field by field ("Review choices" above).
# Parity: Review-JsonFields in aitools-lib.ps1 (same embedded node script).
#
# Args:
#   $1 = SRC_FILE    file holding the SOURCE JSON
#   $2 = DEST        deployed JSON file (LOCAL)
#   $3 = ADOPT_PATH  repo JSON file that is the source of truth; "" = no adopt
#
# Sets MANAGED_FILE_RESULT, one per file by precedence failed > accept & adopt
# > skipped > updated > verified: "created" (LOCAL was missing), "failed"
# (files restored, log_error), "accept & adopt" (a field was adopted into
# ADOPT_PATH; overwrites chosen in the same run are written too), "skipped"
# (a field was left differing), "updated" (fields overwritten from SOURCE),
# "verified" (nothing written). Requires node. Exits 2 on [x]abort.
# ---------------------------------------------------------------------------
review_json_fields() {
    local src_file="$1" dest="$2" adopt_path="${3:-}"
    local item
    item=$(basename "$dest")
    MANAGED_FILE_RESULT="verified"

    if ! command -v node >/dev/null 2>&1; then
        log_error "Failed: $item: node is required for the JSON field review"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi

    local work
    if ! work=$(mktemp -d); then
        log_error "Failed: $item: could not create a work directory for the JSON review"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi
    cat > "$work/review.js" <<'REVIEW_JSON_NODE_EOF'
// review_json_fields / Review-JsonFields: SOURCE against LOCAL, field by field.
// The same text is embedded in aitools-lib.sh and aitools-lib.ps1: keep them identical.
//   plan  SRC LOCAL OUT_PLAN
//     OUT_PLAN: one line per differing field: idx<TAB>kind<TAB>key<TAB>local<TAB>source
//     kind: differ | source-only | local-only. A whole array is one field.
//   apply SRC LOCAL ADOPT CHOICES OUT_LOCAL OUT_ADOPT OUT_RESULT OUT_REQ_LOCAL OUT_REQ_ADOPT
//     ADOPT: the adopt target, or "-" for none.
//     CHOICES: idx<TAB>overwrite|adopt|skip|keep per field (missing = skip).
//     OUT_LOCAL / OUT_ADOPT: new file content, or empty when that file is unchanged.
//     OUT_RESULT: "over=N adopt=N skip=N kept=N".
//     OUT_REQ_LOCAL / OUT_REQ_ADOPT: JSON array of SOURCE's top-level keys the
//     written file must keep (keys the review chose to leave absent excluded).
//   keys  SRC OUT_KEYS
//     OUT_KEYS: JSON array of SOURCE's top-level keys ([] when not an object).
// Key order is preserved: existing keys keep their position, new keys are appended.
// Exit 3 with the reason on stderr when a file cannot be read or parsed.
const fs = require('fs');
const mode = process.argv[2];
function readJson(p, label) {
    let text;
    try { text = fs.readFileSync(p, 'utf8'); }
    catch (e) {
        if (e.code === 'ENOENT') return undefined;
        throw new Error(label + ': cannot read ' + p + ': ' + e.message);
    }
    if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
    try { return JSON.parse(text); }
    catch (e) { throw new Error(label + ': ' + p + ' is not valid JSON: ' + e.message); }
}
function isObj(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }
function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
function canon(v) {
    if (Array.isArray(v)) return '[' + v.map(canon).join(',') + ']';
    if (isObj(v)) return '{' + Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + canon(v[k])).join(',') + '}';
    return JSON.stringify(v);
}
function fields(src, loc) {
    const out = [];
    if (!isObj(src) || !isObj(loc)) {
        if (canon(src) !== canon(loc)) out.push({ path: [], kind: 'differ', s: src, l: loc });
        return out;
    }
    (function walk(s, l, path) {
        const keys = Object.keys(s).concat(Object.keys(l).filter(k => !has(s, k)));
        for (const k of keys) {
            const p = path.concat([k]);
            const inS = has(s, k), inL = has(l, k);
            if (inS && inL) {
                if (isObj(s[k]) && isObj(l[k])) walk(s[k], l[k], p);
                else if (canon(s[k]) !== canon(l[k])) out.push({ path: p, kind: 'differ', s: s[k], l: l[k] });
            } else if (inS) {
                out.push({ path: p, kind: 'source-only', s: s[k] });
            } else {
                out.push({ path: p, kind: 'local-only', l: l[k] });
            }
        }
    })(src, loc, []);
    return out;
}
function disp(v) {
    if (v === undefined) return '(absent)';
    let t = JSON.stringify(v);
    if (t.length > 200) t = t.slice(0, 197) + '...';
    return t;
}
function clean(t) { return String(t).replace(/[\t\r\n]/g, ' '); }
function clone(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)); }
function setPath(obj, path, val) {
    let o = obj;
    for (let i = 0; i < path.length - 1; i++) {
        if (!isObj(o[path[i]])) o[path[i]] = {};
        o = o[path[i]];
    }
    o[path[path.length - 1]] = val;
}
function delPath(obj, path) {
    let o = obj;
    for (let i = 0; i < path.length - 1; i++) {
        if (!isObj(o[path[i]])) return;
        o = o[path[i]];
    }
    delete o[path[path.length - 1]];
}
function keptKeys(src, obj) {
    if (!isObj(src) || !isObj(obj)) return [];
    return Object.keys(src).filter(k => has(obj, k));
}
try {
    const src = readJson(process.argv[3], 'source');
    if (src === undefined) throw new Error('source: ' + process.argv[3] + ' not found');
    if (mode === 'keys') {
        fs.writeFileSync(process.argv[4], JSON.stringify(isObj(src) ? Object.keys(src) : []) + '\n');
        process.exit(0);
    }
    const loc = readJson(process.argv[4], 'local');
    if (loc === undefined) throw new Error('local: ' + process.argv[4] + ' not found');
    const list = fields(src, loc);
    if (mode === 'plan') {
        const lines = list.map((f, i) => [i, f.kind, f.path.length ? clean(f.path.join('.')) : '(document)',
            clean(disp(f.l)), clean(disp(f.s))].join('\t'));
        fs.writeFileSync(process.argv[5], lines.length ? lines.join('\n') + '\n' : '');
    } else if (mode === 'apply') {
        const adoptPath = (process.argv[5] && process.argv[5] !== '-') ? process.argv[5] : '';
        const choices = {};
        for (const line of fs.readFileSync(process.argv[6], 'utf8').split(/\r?\n/)) {
            const m = /^(\d+)\t(\w+)$/.exec(line);
            if (m) choices[m[1]] = m[2];
        }
        let newLocal = clone(loc);
        let adoptObj;
        if (adoptPath) {
            adoptObj = readJson(adoptPath, 'adopt target');
            if (adoptObj === undefined) adoptObj = clone(src);
        }
        let over = 0, adopt = 0, skip = 0, kept = 0;
        list.forEach((f, i) => {
            const c = choices[String(i)] || 'skip';
            if (c === 'adopt' && adoptPath) {
                adopt++;
                if (f.path.length === 0) adoptObj = clone(f.l);
                else if (f.kind === 'source-only') delPath(adoptObj, f.path);
                else setPath(adoptObj, f.path, clone(f.l));
            } else if (c === 'overwrite' && f.kind !== 'local-only') {
                over++;
                if (f.path.length === 0) newLocal = clone(f.s);
                else setPath(newLocal, f.path, clone(f.s));
            } else if (f.kind === 'local-only' && c !== 'skip') {
                kept++;
            } else {
                skip++;
            }
        });
        fs.writeFileSync(process.argv[7], over ? JSON.stringify(newLocal, null, 2) + '\n' : '');
        fs.writeFileSync(process.argv[8], adopt ? JSON.stringify(adoptObj, null, 2) + '\n' : '');
        fs.writeFileSync(process.argv[9], 'over=' + over + ' adopt=' + adopt + ' skip=' + skip + ' kept=' + kept + '\n');
        fs.writeFileSync(process.argv[10], JSON.stringify(keptKeys(src, newLocal)) + '\n');
        fs.writeFileSync(process.argv[11], JSON.stringify(adoptPath ? keptKeys(src, adoptObj) : []) + '\n');
    } else {
        throw new Error('unknown mode: ' + mode);
    }
} catch (e) {
    process.stderr.write(String((e && e.message) || e) + '\n');
    process.exit(3);
}
REVIEW_JSON_NODE_EOF

    local rc=0
    if [ ! -f "$dest" ]; then
        local src_json
        node "$work/review.js" keys "$src_file" "$work/keys.json" 2> "$work/err" || rc=$?
        if [ "$rc" -ne 0 ] || ! src_json=$(cat "$src_file"); then
            log_error "Failed: $item: cannot read the source JSON (node exit $rc): $(cat "$work/err")"
            rm -rf "$work"
            MANAGED_FILE_RESULT="failed"
            return 0
        fi
        MANAGED_WRITE_REQUIRED_1=$(cat "$work/keys.json")
        rm -rf "$work"
        if _managed_write "$dest" "$src_json" "" ""; then
            log_ok "Created: $item -> $(display_path "$dest")"
            MANAGED_FILE_RESULT="created"
        else
            log_error "Failed: $item: $MANAGED_WRITE_ERROR"
            MANAGED_FILE_RESULT="failed"
        fi
        return 0
    fi

    node "$work/review.js" plan "$src_file" "$dest" "$work/plan.tsv" 2> "$work/err" || rc=$?
    if [ "$rc" -ne 0 ]; then
        log_error "Failed: $item: field comparison failed (node exit $rc): $(cat "$work/err")"
        rm -rf "$work"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi
    if [ ! -s "$work/plan.tsv" ]; then
        rm -rf "$work"
        MANAGED_FILE_RESULT="verified"
        return 0
    fi

    # One review per differing field. fd 3 carries the plan so stdin stays the
    # terminal (tty_interactive tests stdin).
    local adopt_ok=0 can_prompt=0
    if [ -n "$adopt_path" ]; then adopt_ok=1; fi
    if [ "${AITOOLS_FORCE:-}" != "1" ] && [ "${FORCE:-}" != "true" ] && tty_interactive; then can_prompt=1; fi
    : > "$work/choices.tsv"
    local idx kind key ldisp sdisp choice
    while IFS=$'\t' read -r idx kind key ldisp sdisp <&3; do
        [ -n "$idx" ] || continue
        if [ "$kind" = "local-only" ]; then
            # A field only in LOCAL: [a]dopt / [s]kip / [x]abort, no overwrite.
            # Without an adopt target or a terminal it is kept, no prompt.
            if [ "$adopt_ok" = "1" ] && [ "$can_prompt" = "1" ]; then
                prompt_json_field_review "$key" "$ldisp" "(not in source)" "source" "1" "local" "0"
                choice="$JSON_FIELD_REVIEW_RESULT"
            else
                log_detail "$item: $key only in local -- kept"
                choice="keep"
            fi
        else
            prompt_json_field_review "$key" "$ldisp" "$sdisp" "source" "$adopt_ok" "local"
            choice="$JSON_FIELD_REVIEW_RESULT"
        fi
        printf '%s\t%s\n' "$idx" "$choice" >> "$work/choices.tsv"
    done 3< "$work/plan.tsv"

    rc=0
    node "$work/review.js" apply "$src_file" "$dest" "${adopt_path:--}" "$work/choices.tsv" \
        "$work/local.out" "$work/adopt.out" "$work/result.txt" \
        "$work/req-local.json" "$work/req-adopt.json" 2> "$work/err" || rc=$?
    if [ "$rc" -ne 0 ]; then
        log_error "Failed: $item: applying the field choices failed (node exit $rc): $(cat "$work/err")"
        rm -rf "$work"
        MANAGED_FILE_RESULT="failed"
        return 0
    fi
    local counts n_over n_adopt n_skip
    counts=$(cat "$work/result.txt")
    n_over=$(printf '%s' "$counts" | perl -ne 'print $1 if /over=(\d+)/')
    n_adopt=$(printf '%s' "$counts" | perl -ne 'print $1 if /adopt=(\d+)/')
    n_skip=$(printf '%s' "$counts" | perl -ne 'print $1 if /skip=(\d+)/')
    log_detail "$item: field review $counts"

    local p_local="" c_local="" p_adopt="" c_adopt="" r_local r_adopt
    r_local=$(cat "$work/req-local.json")
    r_adopt=$(cat "$work/req-adopt.json")
    if [ -s "$work/local.out" ]; then p_local="$dest"; c_local=$(cat "$work/local.out"); fi
    if [ -s "$work/adopt.out" ]; then p_adopt="$adopt_path"; c_adopt=$(cat "$work/adopt.out"); fi
    rm -rf "$work"

    if [ -n "$p_local" ] || [ -n "$p_adopt" ]; then
        MANAGED_WRITE_REQUIRED_1="$r_local"
        MANAGED_WRITE_REQUIRED_2="$r_adopt"
        if ! _managed_write "$p_local" "$c_local" "$p_adopt" "$c_adopt"; then
            log_error "Failed: $item: $MANAGED_WRITE_ERROR (files restored)"
            MANAGED_FILE_RESULT="failed"
            return 0
        fi
    fi
    if [ "${n_over:-0}" -gt 0 ]; then
        log_ok "Updated: $item -> $(display_path "$dest") ($n_over field(s) from source)"
    fi
    if [ "${n_adopt:-0}" -gt 0 ]; then
        log_ok "Accept & adopt: $item -> $(display_path "$adopt_path") ($n_adopt field(s))"
        _managed_adopt_notice "$adopt_path"
    fi
    if [ "${n_skip:-0}" -gt 0 ]; then
        log_warn "Skipped: $item ($n_skip field(s) differ from source; reviewed again next run)"
    fi
    if [ "${n_adopt:-0}" -gt 0 ]; then
        MANAGED_FILE_RESULT="accept & adopt"
    elif [ "${n_skip:-0}" -gt 0 ]; then
        MANAGED_FILE_RESULT="skipped"
    elif [ "${n_over:-0}" -gt 0 ]; then
        MANAGED_FILE_RESULT="updated"
    else
        MANAGED_FILE_RESULT="verified"
    fi
}

# ---------------------------------------------------------------------------
# Write an adopted file back to its source-of-truth target(s).
#
# Companion to deploy_managed_file: when the diff review returns
# "accept & adopt", the local (deployed) file won and must propagate back to
# every canonical source it was deployed from -- e.g. the user's dotprofile AND
# the shared/ template. Centralizes the backup+rotate+copy+log that callers
# used to hand-roll, so all adopt paths behave identically.
#
# For each target: rotate a timestamped backup of the existing target (via
# backup_file -- keeps 20, prunes oldest), ensure its parent dir, then copy the
# adopted content over it. Empty target args are skipped, so callers may pass an
# optional path (e.g. "${VAR:+...}") without branching.
#
# Args:
#   $1     = adopted source file to copy FROM (the deployed file on disk)
#   $2..$N = one or more target paths to write back to (empty entries skipped)
#
# Sets ADOPT_TARGETS_WRITTEN to the count written. Returns 0 if >=1 target was
# written, 1 otherwise (source missing or no non-empty targets).
# ---------------------------------------------------------------------------
ADOPT_TARGETS_WRITTEN=0
adopt_managed_file() {
    local src="$1"; shift
    ADOPT_TARGETS_WRITTEN=0

    if [ ! -f "$src" ]; then
        log_error "adopt_managed_file: adopted source not found: $(display_path "$src")"
        return 1
    fi

    local target
    for target in "$@"; do
        [ -n "$target" ] || continue
        backup_file "$target"                 # rotation; no-op if target absent
        mkdir -p "$(dirname "$target")"
        if cp "$src" "$target"; then
            log_ok "Adopted -> $(display_path "$target")"
            ADOPT_TARGETS_WRITTEN=$((ADOPT_TARGETS_WRITTEN + 1))
        else
            log_error "adopt_managed_file: failed to write $(display_path "$target")"
        fi
    done

    [ "$ADOPT_TARGETS_WRITTEN" -gt 0 ] && return 0 || return 1
}

# ---------------------------------------------------------------------------
# Deploy tracker: centralizes outcome counting and summary writing for
# loops that deploy multiple managed files (rules, skills, hooks).
# ---------------------------------------------------------------------------

# Reset all deploy tracker counters. Call before a deploy loop.
_DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
_DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0
DEPLOY_TRACKER_TEXT=""

deploy_tracker_init() {
    _DT_ADDED=0; _DT_UPDATED=0; _DT_VERIFIED=0
    _DT_ACCEPTED=0; _DT_SKIPPED=0; _DT_PRESERVED=0; _DT_FAILED=0
    DEPLOY_TRACKER_TEXT=""
}

# Record a single file outcome. Increments counter and writes DETAIL summary.
# Args: $1=outcome $2=tool_name $3=item_name
deploy_tracker_record() {
    local outcome="$1" tool_name="$2" item_name="$3"
    case "$outcome" in
        added|created) _DT_ADDED=$((_DT_ADDED + 1))
                   write_summary DETAIL "$tool_name" "added: $item_name" ;;
        updated)   _DT_UPDATED=$((_DT_UPDATED + 1))
                   write_summary DETAIL "$tool_name" "updated: $item_name" ;;
        "accept & adopt") _DT_ACCEPTED=$((_DT_ACCEPTED + 1))
                       write_summary DETAIL "$tool_name" "accept & adopt: $item_name" ;;
        skipped)   _DT_SKIPPED=$((_DT_SKIPPED + 1))
                   write_summary DETAIL "$tool_name" "skipped: $item_name" ;;
        failed)    _DT_FAILED=$((_DT_FAILED + 1))
                   write_summary DETAIL "$tool_name" "failed: $item_name" ;;
        verified)  _DT_VERIFIED=$((_DT_VERIFIED + 1)) ;;
        preserved) _DT_PRESERVED=$((_DT_PRESERVED + 1)) ;;
    esac
}

# Write aggregate summary for a deploy loop. Uses non-zero counts.
# ERROR when any file failed, WARN when any was skipped, else OK.
# Sets DEPLOY_TRACKER_TEXT for use in log lines.
# Args: $1=tool_name
deploy_tracker_summary() {
    local tool_name="$1"
    local parts=""
    if [ "$_DT_ADDED" -gt 0 ];    then parts="$_DT_ADDED added"; fi
    if [ "$_DT_UPDATED" -gt 0 ];  then parts="${parts:+$parts, }$_DT_UPDATED updated"; fi
    if [ "$_DT_ACCEPTED" -gt 0 ]; then parts="${parts:+$parts, }$_DT_ACCEPTED accepted"; fi
    if [ "$_DT_VERIFIED" -gt 0 ]; then parts="${parts:+$parts, }$_DT_VERIFIED verified"; fi
    if [ "$_DT_FAILED" -gt 0 ];   then parts="${parts:+$parts, }$_DT_FAILED failed"; fi
    if [ -z "$parts" ]; then parts="verified"; fi
    DEPLOY_TRACKER_TEXT="$parts"

    if [ "$_DT_FAILED" -gt 0 ]; then
        write_summary ERROR "$tool_name" "$_DT_FAILED failed"
    elif [ "$_DT_SKIPPED" -gt 0 ]; then
        write_summary WARN "$tool_name" "$_DT_SKIPPED skipped (user review)"
    else
        write_summary OK "$tool_name" "$parts"
    fi
}

# ---------------------------------------------------------------------------
# Granular per-leaf review prompt for JSON settings sync (sync_managed_json)
# and the JSON field review (review_json_fields).
# One prompt per divergent setting/rule. overwrite/adopt/skip are per-leaf;
# abort (x) is global and exits the run (code 2).
#
# Args:
#   $1 = leaf display name (e.g. "theme" or "permissions.deny MCP(vercel)")
#   $2 = current value display (the local file's side)
#   $3 = proposed value display (the source side)
#   $4 = source label (e.g. "profile.json")
#   $5 = adopt-allowed flag ("1" to offer adopt, else hidden)
#   $6 = local label (default "settings.json")
#   $7 = overwrite-allowed flag (default "1"; "0" for a field only in the
#        local file: no [o]verwrite, and the default answer is skip)
#
# Sets JSON_FIELD_REVIEW_RESULT to "overwrite", "adopt", or "skip".
# --force / AITOOLS_FORCE / non-interactive -> "overwrite" (source wins), or
# "skip" when overwrite is not allowed.
# ---------------------------------------------------------------------------
JSON_FIELD_REVIEW_RESULT=""
prompt_json_field_review() {
    local leaf="$1" current="$2" proposed="$3" source_label="${4:-profile.json}" adopt_allowed="${5:-1}"
    local local_label="${6:-settings.json}" overwrite_allowed="${7:-1}"
    local default_choice="overwrite" default_desc="overwriting from $source_label"
    if [ "$overwrite_allowed" != "1" ]; then
        default_choice="skip"; default_desc="skipping (only in $local_label)"
    fi

    JSON_FIELD_REVIEW_RESULT="$default_choice"

    # --force / AITOOLS_FORCE: source wins
    if [ "${AITOOLS_FORCE:-}" = "1" ] || [ "${FORCE:-}" = "true" ]; then
        log "Divergence in $leaf -- $default_desc (--force)"
        return 0
    fi
    # Non-interactive: source wins
    if ! tty_interactive; then
        log "Divergence in $leaf -- $default_desc (non-interactive)"
        return 0
    fi

    printf '\n\033[33m[REVIEW]\033[0m %s differs from %s.\n' "$leaf" "$source_label" > /dev/tty
    printf '  %s : %s\n' "$local_label" "$current" > /dev/tty
    printf '  %s : %s\n' "$source_label" "$proposed" > /dev/tty
    printf '\n' > /dev/tty
    if [ "$overwrite_allowed" = "1" ]; then
        printf '  [o]verwrite : %s value -> %s\n' "$source_label" "$local_label" > /dev/tty
    fi
    if [ "$adopt_allowed" = "1" ]; then
        printf '  [a]dopt     : keep %s value -> write to %s\n' "$local_label" "$source_label" > /dev/tty
    fi
    printf '  [s]kip      : leave this setting unchanged\n' > /dev/tty
    printf '  [x]abort    : stop the run\n' > /dev/tty
    if [ "$overwrite_allowed" != "1" ]; then
        printf '  choice [a/s/x]: ' > /dev/tty
    elif [ "$adopt_allowed" = "1" ]; then
        printf '  choice [o/a/s/x]: ' > /dev/tty
    else
        printf '  choice [o/s/x]: ' > /dev/tty
    fi

    local choice
    read_tty_choice choice "$default_desc"
    case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')" in
        a)  if [ "$adopt_allowed" = "1" ]; then
                printf '  >> adopted: %s value kept -> %s\n' "$local_label" "$source_label" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="adopt"
            elif [ "$overwrite_allowed" = "1" ]; then
                printf '  >> overwritten from %s\n' "$source_label" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="overwrite"
            else
                printf '  >> skipped: %s unchanged\n' "$leaf" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="skip"
            fi ;;
        s)  printf '  >> skipped: %s unchanged\n' "$leaf" > /dev/tty
            JSON_FIELD_REVIEW_RESULT="skip" ;;
        x)  _managed_abort ;;
        *)  if [ "$overwrite_allowed" = "1" ]; then
                printf '  >> overwritten from %s\n' "$source_label" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="overwrite"
            else
                printf '  >> skipped: %s unchanged\n' "$leaf" > /dev/tty
                JSON_FIELD_REVIEW_RESULT="skip"
            fi ;;
    esac
    return 0
}

# ---------------------------------------------------------------------------
# Generic settings.json <-> profile.json sync engine.
#
# profile.json (under a sub-path, e.g. "claude.settings") is the source of
# truth for the live JSON file (settings.json), EXCLUDING harness-managed keys
# (e.g. "hooks"). For every managed leaf (arbitrary keys; permissions handled
# per-rule across allow/ask/deny):
#   - in live, not in profile  -> auto-adopt into profile (no prompt)
#   - equal                    -> no-op
#   - differ / live-missing    -> granular per-leaf prompt (prompt_json_field_review)
# Deprecated permission rules are stripped from live before the scan so they
# are never adopted. Writes preserve key order (no sort). Both files are backed
# up before write and validated after.
#
# Args:
#   $1 = live JSON file (e.g. ~/.claude/settings.json)
#   $2 = profile JSON file (dotprofile profile.json)
#   $3 = profile sub-path holding the mirror, dot form (e.g. "claude.settings")
#   $4 = exclude keys, comma-separated (default "hooks")
#   $5 = deprecated permission rules, comma-separated (default "")
#
# Sets SYNC_MANAGED_JSON_RESULT to "unchanged", "updated", or "created".
# Requires node. Honors DRY_RUN (plan only, no writes). Exits 2 on user abort.
# ---------------------------------------------------------------------------
SYNC_MANAGED_JSON_RESULT=""
sync_managed_json() {
    local live_file="$1" profile_file="$2" subpath="$3"
    local exclude_keys="${4:-hooks}" deprecated_rules="${5:-}"

    SYNC_MANAGED_JSON_RESULT="unchanged"

    if ! command -v node >/dev/null 2>&1; then
        log_error "sync_managed_json: node required for JSON sync"
        return 1
    fi

    local nodescript plan_json decisions_tsv choices_tsv
    nodescript=$(mktemp) || { log_error "sync_managed_json: mktemp failed"; return 1; }
    plan_json=$(mktemp); decisions_tsv=$(mktemp); choices_tsv=$(mktemp)

    cat > "$nodescript" <<'SYNC_NODE_EOF'
const fs = require('fs');
const mode = process.argv[2];
const PERM_CATS = ['allow', 'ask', 'deny'];

function readJson(p) {
    try { return JSON.parse(fs.readFileSync(p, 'utf8')); }
    catch (e) { if (e.code === 'ENOENT') return null; throw e; }
}
function jeq(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
function getSub(obj, parts) { let o = obj; for (const k of parts) { if (o == null || typeof o !== 'object') return undefined; o = o[k]; } return o; }
function ensureSub(obj, parts) { let o = obj; for (const k of parts) { if (o[k] == null || typeof o[k] !== 'object') o[k] = {}; o = o[k]; } return o; }
function setPath(obj, parts, val) { let o = obj; for (let i = 0; i < parts.length - 1; i++) { if (o[parts[i]] == null || typeof o[parts[i]] !== 'object') o[parts[i]] = {}; o = o[parts[i]]; } o[parts[parts.length - 1]] = val; }
function delPath(obj, parts) { let o = obj; for (let i = 0; i < parts.length - 1; i++) { if (o[parts[i]] == null) return; o = o[parts[i]]; } delete o[parts[parts.length - 1]]; }
function disp(v) { return v === undefined ? '(not in settings.json)' : JSON.stringify(v); }

function buildPlan(live, profile, subParts, excludeKeys, deprecated) {
    live = live || {};
    const mirror = getSub(profile, subParts) || {};
    const deprecatedRemoved = [];
    if (live.permissions) {
        for (const cat of PERM_CATS) {
            if (Array.isArray(live.permissions[cat])) {
                for (const r of live.permissions[cat]) if (deprecated.includes(r)) deprecatedRemoved.push({ cat, rule: r });
                live.permissions[cat] = live.permissions[cat].filter(r => !deprecated.includes(r));
            }
        }
    }
    const decisions = {}; const autoAdopts = [];
    const keys = new Set([...Object.keys(live), ...Object.keys(mirror)]);
    for (const k of excludeKeys) keys.delete(k);
    for (const k of keys) {
        if (k === 'permissions') {
            const lp = live.permissions || {}; const mp = mirror.permissions || {};
            const lHas = Object.prototype.hasOwnProperty.call(lp, 'defaultMode');
            const mHas = Object.prototype.hasOwnProperty.call(mp, 'defaultMode');
            if (lHas && !mHas) autoAdopts.push({ kind: 'scalar', path: ['permissions', 'defaultMode'], value: lp.defaultMode });
            else if (mHas && !lHas) decisions['permissions.defaultMode'] = { type: 'permScalar', path: ['permissions', 'defaultMode'], kind: 'live-missing', currentDisplay: disp(undefined), proposedDisplay: disp(mp.defaultMode), profileValue: mp.defaultMode };
            else if (lHas && mHas && !jeq(lp.defaultMode, mp.defaultMode)) decisions['permissions.defaultMode'] = { type: 'permScalar', path: ['permissions', 'defaultMode'], kind: 'differ', currentDisplay: disp(lp.defaultMode), proposedDisplay: disp(mp.defaultMode), liveValue: lp.defaultMode, profileValue: mp.defaultMode };
            for (const cat of PERM_CATS) {
                const lr = Array.isArray(lp[cat]) ? lp[cat] : [];
                const mr = Array.isArray(mp[cat]) ? mp[cat] : [];
                for (const rule of new Set([...lr, ...mr])) {
                    const inL = lr.includes(rule), inM = mr.includes(rule);
                    if (inL && !inM) autoAdopts.push({ kind: 'permRule', cat, rule });
                    else if (inM && !inL) decisions['permissions.' + cat + ' ' + rule] = { type: 'permRule', cat, rule, kind: 'live-missing', currentDisplay: '(not in settings.json)', proposedDisplay: 'rule present in profile.json' };
                }
            }
        } else {
            const lHas = Object.prototype.hasOwnProperty.call(live, k);
            const mHas = Object.prototype.hasOwnProperty.call(mirror, k);
            if (lHas && !mHas) autoAdopts.push({ kind: 'scalar', path: [k], value: live[k] });
            else if (mHas && !lHas) decisions[k] = { type: 'scalar', path: [k], kind: 'live-missing', currentDisplay: disp(undefined), proposedDisplay: disp(mirror[k]), profileValue: mirror[k] };
            else if (lHas && mHas && !jeq(live[k], mirror[k])) decisions[k] = { type: 'scalar', path: [k], kind: 'differ', currentDisplay: disp(live[k]), proposedDisplay: disp(mirror[k]), liveValue: live[k], profileValue: mirror[k] };
        }
    }
    return { decisions, autoAdopts, deprecatedRemoved };
}

const subParts = process.argv[5] ? process.argv[5].split('.') : [];
const excludeKeys = process.argv[6] ? process.argv[6].split(',').filter(Boolean) : [];
const deprecated = process.argv[7] ? process.argv[7].split(',').filter(Boolean) : [];

if (mode === 'plan') {
    const livePath = process.argv[3], profilePath = process.argv[4], planOut = process.argv[8];
    const live = readJson(livePath) || {};
    const profile = readJson(profilePath) || {};
    const plan = buildPlan(live, profile, subParts, excludeKeys, deprecated);
    fs.writeFileSync(planOut, JSON.stringify(plan));
    // TSV for the bash prompt loop: id \t kind \t currentDisplay \t proposedDisplay \t adoptAllowed
    const lines = [];
    for (const [id, d] of Object.entries(plan.decisions)) {
        lines.push([id, d.kind, d.currentDisplay, d.proposedDisplay, '1'].join('\t'));
    }
    // Trailing newline required: the bash `while read` loop drops a final line
    // that lacks one, silently losing the last decision.
    process.stdout.write(lines.length ? lines.join('\n') + '\n' : '');
    // counts to stderr for logging
    process.stderr.write('adopts=' + plan.autoAdopts.length + ' deprecated=' + plan.deprecatedRemoved.length + ' decisions=' + Object.keys(plan.decisions).length + '\n');
} else if (mode === 'apply') {
    const livePath = process.argv[3], profilePath = process.argv[4];
    const planPath = process.argv[8], choicesPath = process.argv[9];
    const plan = readJson(planPath);
    const live = readJson(livePath) || {};
    const profile = readJson(profilePath) || {};
    const mirror = ensureSub(profile, subParts);
    const origLive = JSON.stringify(live), origProfile = JSON.stringify(profile);

    // deprecated removals (already stripped in plan's view; re-apply to actual live)
    for (const d of plan.deprecatedRemoved) {
        if (live.permissions && Array.isArray(live.permissions[d.cat])) {
            live.permissions[d.cat] = live.permissions[d.cat].filter(r => r !== d.rule);
        }
    }
    // auto-adopts -> mirror
    for (const a of plan.autoAdopts) {
        if (a.kind === 'scalar') setPath(mirror, a.path, a.value);
        else if (a.kind === 'permRule') {
            if (!mirror.permissions || typeof mirror.permissions !== 'object') mirror.permissions = {};
            const arr = Array.isArray(mirror.permissions[a.cat]) ? mirror.permissions[a.cat] : [];
            if (!arr.includes(a.rule)) arr.push(a.rule);
            mirror.permissions[a.cat] = arr;
        }
    }
    // decisions
    const choices = {};
    try {
        const raw = fs.readFileSync(choicesPath, 'utf8');
        for (const ln of raw.split('\n')) { if (!ln) continue; const i = ln.indexOf('\t'); if (i < 0) continue; choices[ln.slice(0, i)] = ln.slice(i + 1); }
    } catch (e) { if (e.code !== 'ENOENT') throw e; }
    for (const [id, action] of Object.entries(choices)) {
        const d = plan.decisions[id]; if (!d || action === 'skip') continue;
        if (d.type === 'scalar' || d.type === 'permScalar') {
            if (action === 'overwrite') setPath(live, d.path, d.profileValue);
            else if (action === 'adopt') { if (d.kind === 'live-missing') delPath(mirror, d.path); else setPath(mirror, d.path, d.liveValue); }
        } else if (d.type === 'permRule') {
            if (action === 'overwrite') {
                if (!live.permissions || typeof live.permissions !== 'object') live.permissions = {};
                const arr = Array.isArray(live.permissions[d.cat]) ? live.permissions[d.cat] : [];
                if (!arr.includes(d.rule)) arr.push(d.rule);
                live.permissions[d.cat] = arr;
            } else if (action === 'adopt') {
                if (mirror.permissions && Array.isArray(mirror.permissions[d.cat])) mirror.permissions[d.cat] = mirror.permissions[d.cat].filter(r => r !== d.rule);
            }
        }
    }
    // drop empty permission arrays in live for cleanliness
    if (live.permissions && typeof live.permissions === 'object') {
        for (const cat of PERM_CATS) if (Array.isArray(live.permissions[cat]) && live.permissions[cat].length === 0) delete live.permissions[cat];
    }
    const liveChanged = JSON.stringify(live) !== origLive;
    const profileChanged = JSON.stringify(profile) !== origProfile;
    if (liveChanged) fs.writeFileSync(livePath, JSON.stringify(live, null, 2) + '\n');
    if (profileChanged) fs.writeFileSync(profilePath, JSON.stringify(profile, null, 2) + '\n');
    process.stdout.write((liveChanged ? 'live-changed' : 'live-unchanged') + ' ' + (profileChanged ? 'profile-changed' : 'profile-unchanged'));
}
SYNC_NODE_EOF

    local live_existed="false"
    [ -f "$live_file" ] && live_existed="true"

    # --- Plan pass ---
    local plan_stderr
    plan_stderr=$(node "$nodescript" plan "$live_file" "$profile_file" "$subpath" "$exclude_keys" "$deprecated_rules" "$plan_json" 2>&1 1>"$decisions_tsv") || {
        log_error "sync_managed_json: plan pass failed: $plan_stderr"
        rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv"
        return 1
    }
    log "Settings sync plan: $plan_stderr"

    # grep -c prints "0" and exits 1 on no matches; `|| true` avoids set -e abort
    # without the double-"0" that `|| echo 0` would append (-> "integer expected").
    local decision_count
    decision_count=$(grep -c . "$decisions_tsv" 2>/dev/null || true)
    [ -n "$decision_count" ] || decision_count=0

    if [ "${DRY_RUN:-}" = "true" ]; then
        log "[DRY RUN] settings sync: $plan_stderr (would prompt for $decision_count divergent leaf/leaves)"
        rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv"
        SYNC_MANAGED_JSON_RESULT="unchanged"
        return 0
    fi

    # Nothing to adopt, purge, or decide -> no write, no backups (avoid churn).
    case "$plan_stderr" in
        "adopts=0 deprecated=0 decisions=0")
            log_ok "Settings unchanged: $(display_path "$live_file")"
            rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv"
            SYNC_MANAGED_JSON_RESULT="unchanged"
            return 0 ;;
    esac

    # --- Prompt loop (granular, per leaf) ---
    : > "$choices_tsv"
    if [ "$decision_count" -gt 0 ]; then
        local id kind cur prop adoptf
        if [ "$live_existed" = "false" ]; then
            # No live file yet (fresh HOME): nothing local to protect, so every leaf is
            # created from the profile without prompting (#31).
            log "No $(display_path "$live_file") yet -- creating from profile ($decision_count setting(s))"
            mkdir -p "$(dirname "$live_file")"
        fi
        # Read decisions on fd 3, not stdin: the prompt's interactivity test
        # (tty_interactive) checks stdin, which must stay the caller's terminal.
        while IFS=$'\t' read -r -u 3 id kind cur prop adoptf; do
            [ -n "$id" ] || continue
            if [ "$live_existed" = "false" ]; then
                JSON_FIELD_REVIEW_RESULT="overwrite"
            else
                prompt_json_field_review "$id" "$cur" "$prop" "profile.json" "$adoptf"
            fi
            printf '%s\t%s\n' "$id" "$JSON_FIELD_REVIEW_RESULT" >> "$choices_tsv"
        done 3< "$decisions_tsv"
    fi

    # --- Backup before apply ---
    backup_file "$live_file"
    [ -f "$profile_file" ] && backup_file "$profile_file"

    # --- Apply pass ---
    local apply_out
    apply_out=$(node "$nodescript" apply "$live_file" "$profile_file" "$subpath" "$exclude_keys" "$deprecated_rules" "$plan_json" "$choices_tsv") || {
        log_error "sync_managed_json: apply pass failed"
        rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv"
        return 1
    }

    # --- Post-write validation ---
    if [ -f "$live_file" ] && ! node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$live_file" 2>/dev/null; then
        log_error "sync_managed_json: $(display_path "$live_file") is not valid JSON after write"
        rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv"
        return 1
    fi

    case "$apply_out" in
        live-changed*)
            log_ok "Settings synced: $(display_path "$live_file")"
            SYNC_MANAGED_JSON_RESULT=$([ "$live_existed" = "true" ] && echo "updated" || echo "created") ;;
        *)
            log_ok "Settings unchanged: $(display_path "$live_file")"
            SYNC_MANAGED_JSON_RESULT="unchanged" ;;
    esac
    case "$apply_out" in
        *profile-changed) log_ok "Profile updated: $(display_path "$profile_file")" ;;
    esac

    rm -f "$nodescript" "$plan_json" "$decisions_tsv" "$choices_tsv"
    return 0
}

# ---------------------------------------------------------------------------
# Repair broken uv tool environment (cross-platform)
# ---------------------------------------------------------------------------
# When `uv tool upgrade <tool>` fails with "missing a valid environment",
# find a working Python via `uv python find` (fallback: system python/python3)
# and reinstall with --force --python <path>.
# Returns 0 if repaired, 1 if not applicable or failed.
repair_uv_tool_env() {
    local tool_name="$1"
    local upgrade_output="${2:-}"

    if ! printf '%s\n' "$upgrade_output" | grep -q 'missing a valid environment'; then
        return 1
    fi

    log_warn "$tool_name uv environment is broken (Python removed?) -- repairing..."

    # Find a working Python -- uv's own Pythons first, then system
    local working_python=""
    local uv_python
    # 2>/dev/null + || true: "no Python found" is an expected outcome here; the -n/-x
    # check below handles it and falls through to system Python.
    uv_python=$(uv python find 2>/dev/null) || true
    if [ -n "$uv_python" ] && [ -x "$uv_python" ]; then
        working_python="$uv_python"
    elif command -v python3 >/dev/null 2>&1; then
        working_python=$(command -v python3)
    elif command -v python >/dev/null 2>&1; then
        working_python=$(command -v python)
    fi

    if [ -z "$working_python" ]; then
        log_error "Cannot repair $tool_name -- no working Python found"
        return 1
    fi

    log "Repairing with: uv tool install --force --python $working_python $tool_name"
    local repair_output
    # Capture the exit code instead of aborting under set -e; it decides success below.
    local repair_rc=0
    repair_output=$(uv tool install --force --python "$working_python" "$tool_name" 2>&1) || repair_rc=$?
    local line
    while IFS= read -r line; do
        if [ -n "$line" ]; then log "$line"; fi
    done <<< "$repair_output"

    if [ "$repair_rc" -ne 0 ]; then
        log_error "$tool_name environment repair failed (uv exit $repair_rc)"
        return 1
    fi

    log_ok "Repaired $tool_name uv environment"
    return 0
}

# ---------------------------------------------------------------------------
# Parse CHANGED: lines from a node merge result and emit DETAIL summary entries.
# Usage: emit_merge_details "$MERGE_RESULT" "tool_name"
# Only processes lines prefixed with "CHANGED: " -- ignores status and other output.
# ---------------------------------------------------------------------------
emit_merge_details() {
    local merge_result="$1" tool_name="$2"
    local changed_keys
    changed_keys=$(echo "$merge_result" | perl -ne 'print if s/^CHANGED: //')
    if [ -n "$changed_keys" ]; then
        while IFS= read -r key_change; do
            log "  $key_change"
            write_summary DETAIL "$tool_name" "$key_change"
        done <<< "$changed_keys"
    fi
}

# ---------------------------------------------------------------------------
# JSON normalization for comparison (sorted keys, deterministic output)
# ---------------------------------------------------------------------------
# JavaScript JSON.stringify preserves insertion order, which may differ
# between runs or between PS1/bash variants writing the same file. Sorting
# keys before comparison ensures identical content produces identical JSON.
#
# SORT_KEYS_JS: minified sortKeys function for embedding in node -e blocks.
#   Usage: node -e "$SORT_KEYS_JS; ..."
#
# normalize_json: pipe-based wrapper for standalone use.
#   Usage: NORMALIZED=$(echo "$json_string" | normalize_json)
SORT_KEYS_JS='function sortKeys(o){if(o===null||typeof o!=="object")return o;if(Array.isArray(o))return o.map(sortKeys);var s={};Object.keys(o).sort().forEach(function(k){s[k]=sortKeys(o[k])});return s}'

normalize_json() {
    node -e "
        var input = require('fs').readFileSync('/dev/stdin', 'utf8');
        $SORT_KEYS_JS
        try {
            console.log(JSON.stringify(sortKeys(JSON.parse(input)), null, 2));
        } catch(e) {
            process.stderr.write('normalize_json: ' + e.message + '\n');
            process.exit(1);
        }
    "
}

# ---------------------------------------------------------------------------
# Go install provenance detection (macOS)
# Returns: "homebrew", "pkg-installer", "goenv", "manual", "none", or "unknown"
# ---------------------------------------------------------------------------
detect_go_provenance() {
    local go_path
    go_path=$(command -v go 2>/dev/null) || { echo "none"; return; }
    case "$go_path" in
        /opt/homebrew/*/go|/usr/local/Cellar/*/go)
            echo "homebrew" ;;
        /usr/local/go/bin/go)
            # /usr/local/go is go.dev's official tarball location. Only macOS can tell a
            # .pkg install from a manual tarball (pkgutil). Without pkgutil (Linux) the
            # tarball is the upstream-preferred install -- never a cleanup target.
            if ! command -v pkgutil >/dev/null 2>&1; then
                echo "upstream"
            elif pkgutil --pkg-info=org.golang.go >/dev/null 2>&1; then
                echo "pkg-installer"
            else
                echo "manual"
            fi ;;
        */.goenv/*)
            echo "goenv" ;;
        *)
            echo "unknown" ;;
    esac
}

# ---------------------------------------------------------------------------
# Ensure GOPATH/bin is on PATH for current session
# Returns 0 if already on PATH, 1 if added (caller should warn re persistence)
# ---------------------------------------------------------------------------
ensure_gopath_bin_on_path() {
    local gopath_bin="${GOPATH:-$HOME/go}/bin"
    case ":$PATH:" in
        *":$gopath_bin:"*) return 0 ;;
    esac
    export PATH="$gopath_bin:$PATH"
    return 1
}

# ---------------------------------------------------------------------------
# Summary panel renderer
# ---------------------------------------------------------------------------
# Reads AITOOLS_SUMMARY_FILE, displays colored panel, cleans up.
# Silent no-op if file unset, missing, or empty.
show_summary() {
    local sfile="${AITOOLS_SUMMARY_FILE:-}"
    [ -n "$sfile" ] || return 0
    [ -f "$sfile" ] || return 0
    [ -s "$sfile" ] || { rm -f "$sfile"; return 0; }

    # Dedup by tool name: highest severity wins (ERROR > WARN > OK).
    # ACTIONs (empty tool name) are never deduped. DETAIL lines collected separately.
    # Output is pre-sorted: OK+details, WARN+details, ERROR+details, ACTIONs.
    local deduped
    deduped=$(perl -F'\|' -lane '
        BEGIN { %rank = (OK => 1, WARN => 2, ERROR => 3); }
        $cat = $F[0]; $tool = $F[1]; $det = join("|", @F[2..$#F]);
        if ($cat eq "DETAIL") {
            push @{$details{$tool}}, $det; next;
        }
        if ($cat eq "ACTION" || $tool eq "") {
            push @actions, $_; next;
        }
        $r = $rank{$cat} // 0;
        if (!exists $best{$tool}) {
            push @order, $tool;
            $best{$tool} = $cat; $detail{$tool} = $det;
        } elsif ($r > ($rank{$best{$tool}} // 0)) {
            $best{$tool} = $cat; $detail{$tool} = $det;
        }
        END {
            my (@ok, @warn, @err);
            for my $t (@order) {
                my @g = ("$best{$t}|$t|$detail{$t}",
                         map { "DETAIL|$t|$_" } @{$details{$t} // []});
                if    ($best{$t} eq "OK")    { push @ok,   @g }
                elsif ($best{$t} eq "WARN")  { push @warn, @g }
                elsif ($best{$t} eq "ERROR") { push @err,  @g }
            }
            print for @ok, @warn, @err, @actions;
        }
    ' "$sfile")

    # Single-pass display: Perl output is pre-sorted by severity.
    # DETAIL lines inherit the color of their preceding parent entry.
    echo ""
    echo "────────────────────────────────────────────────────────"
    local last_color="" first_action=true
    while IFS='|' read -r cat tool detail; do
        case "$cat" in
            OK)
                last_color='\033[32m'
                printf '\033[32m  [ok]  %-16s %s\033[0m\n' "$tool" "$detail"
                ;;
            WARN)
                last_color='\033[33m'
                printf '\033[33m  [!]   %-16s %s\033[0m\n' "$tool" "$detail"
                ;;
            ERROR)
                last_color='\033[31m'
                printf '\033[31m  [ERR] %-16s %s\033[0m\n' "$tool" "$detail"
                ;;
            DETAIL)
                printf '%b                          %s\033[0m\n' "$last_color" "$detail"
                ;;
            ACTION)
                if [ "$first_action" = true ]; then
                    echo ""
                    printf '\033[1;35m  ACTION REQUIRED -- run before tools are ready:\033[0m\n'
                    first_action=false
                fi
                printf '\033[1;35m  >>  %s\033[0m\n' "$detail"
                ;;
        esac
    done <<< "$deduped"
    echo "────────────────────────────────────────────────────────"

    # Preserve summary for log compliance checks
    if [ "${AITOOLS_PRESERVE_SUMMARY:-}" = "1" ]; then
        # cp may fail if log dir was cleaned up; non-blocking (summary already displayed)
        if ! cp "$sfile" "$LOG_DIR/last-summary.txt" 2>/dev/null; then
            printf 'warning: could not preserve summary file\n' >&2
        fi
    fi
    # Cleanup summary file (already displayed; rm -f ignores nonexistent files)
    rm -f "$sfile"
}

# ---------------------------------------------------------------------------
# Build prerequisite checking
# ---------------------------------------------------------------------------

# ensure_tool_on_path: Verify a tool is findable after installation.
# Tries: 1) command -v (current PATH), 2) hash -r (cache refresh),
# 3) known paths fallback (filesystem check + session PATH update).
# Usage: ensure_tool_on_path "nasm" "/usr/local/bin/nasm" "/opt/homebrew/bin/nasm"
# Returns 0 if tool is now on PATH, 1 otherwise.
ensure_tool_on_path() {
    local tool_name="$1"
    shift
    local known_paths=("$@")

    # Already on PATH?
    if command -v "$tool_name" >/dev/null 2>&1; then return 0; fi

    # Refresh command cache (picks up tools installed earlier in the same session)
    hash -r 2>/dev/null  # expected to succeed; some shells don't support it
    if command -v "$tool_name" >/dev/null 2>&1; then return 0; fi

    # Fallback: check known install locations on disk
    for kp in "${known_paths[@]}"; do
        if [ -x "$kp" ]; then
            local parent_dir
            parent_dir=$(dirname "$kp")
            export PATH="$parent_dir:$PATH"
            log "$tool_name found at $kp (added to session PATH)"
            return 0
        fi
    done
    return 1
}

# ---------------------------------------------------------------------------
# Resolve the harness-managed Python interpreter deterministically.
# Prefers the uv shim (~/.local/bin/python3) so the harness uses the managed
# interpreter even in non-interactive contexts (cron/launchd/hooks) where the
# login-profile PATH order does not apply. Prints the resolved command or path
# on stdout; returns 1 if no interpreter is found.
# ---------------------------------------------------------------------------
harness_python() {
    local uv_shim="$HOME/.local/bin/python3"
    if [ -x "$uv_shim" ]; then
        printf '%s' "$uv_shim"
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return 0
    fi
    if command -v python >/dev/null 2>&1; then
        command -v python
        return 0
    fi
    return 1
}

# Check known build prerequisites for an ecosystem.
# Usage: check_build_prereqs "cargo"
#   Outputs missing prereq info to stdout (one per line: NAME|INSTALL_INSTRUCTION).
#   Returns 0 if all present, 1 if any missing.
check_build_prereqs() {
    local ecosystem="$1"
    local missing=0

    # Refresh shell command cache (picks up tools installed earlier in the same session)
    hash -r 2>/dev/null  # expected to succeed; some shells don't support it

    case "$ecosystem" in
        cargo)
            # NASM -- required by aws-lc-sys on x86_64
            if [ "$(uname -m)" = "x86_64" ] && ! command -v nasm >/dev/null 2>&1; then
                # Fallback: check known install locations
                if ensure_tool_on_path "nasm" /usr/local/bin/nasm /opt/homebrew/bin/nasm /usr/bin/nasm; then
                    : # Found via fallback -- ensure_tool_on_path already added to PATH
                else
                    echo "NASM|brew install nasm (macOS) or apt-get install nasm (Linux)"
                    missing=1
                fi
            fi
            # cmake -- required by some crates
            # Official: cmake.org/download lists pip, ZIP, MSI (not winget)
            # macOS: brew install cmake (user-level, no sudo)
            # Windows: uv tool install cmake (user-level, see reference/tool-evaluation-playbook.md)
            if ! command -v cmake >/dev/null 2>&1; then
                if ensure_tool_on_path "cmake" /usr/local/bin/cmake /opt/homebrew/bin/cmake /usr/bin/cmake /Applications/CMake.app/Contents/bin/cmake; then
                    : # Found via fallback
                else
                    echo "CMake|brew install cmake (macOS) / uv tool install cmake (Windows) -- see cmake.org/download"
                    missing=1
                fi
            fi
            ;;
        pip)
            # Add pip-specific prereqs here as discovered
            ;;
        go)
            # Add go-specific prereqs here as discovered
            ;;
    esac

    return $missing
}

# ---------------------------------------------------------------------------
# Build failure diagnosis
# ---------------------------------------------------------------------------

# Scan build output for known failure signatures.
# Usage: diagnose_build_failure "$output"
#   Prints "NAME|REMEDY" if a known signature is found.
#   Returns 0 if found, 1 if no match.
diagnose_build_failure() {
    local output="$1"

    # Table of known failure patterns -> remediation
    # Add new entries here when new build failures are discovered.
    local -a patterns=(
        "NASM command not found|NASM|brew install nasm / apt-get install nasm"
        "linker.*not found|Linker|Install build-essential (Linux) or Xcode CLI tools (macOS)"
        "cmake.*not found|CMake|brew install cmake / uv tool install cmake (see cmake.org/download)"
        "pkg-config.*not found|pkg-config|brew install pkg-config / apt-get install pkg-config"
        "Python\.h.*not found|Python headers|Install python3-dev or python3-devel"
        "openssl.*not found|OpenSSL|brew install openssl / apt-get install libssl-dev"
    )

    for entry in "${patterns[@]}"; do
        local pattern="${entry%%|*}"
        local rest="${entry#*|}"
        if printf '%s\n' "$output" | grep -qiE "$pattern"; then
            echo "$rest"
            return 0
        fi
    done
    return 1
}
