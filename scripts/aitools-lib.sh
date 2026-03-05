# aitools-lib.sh -- shared helpers for all aitools bash scripts
# Sourced, not executed directly. No shebang, no set -euo pipefail (caller sets it).
#
# Provides: platform detection, display_path, read_config_key, logging_init,
# log/log_ok/log_error/log_warn, write_summary, show_summary.
#
# Usage:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
#   logging_init "script-name"
#
# Entry points (aitools, aitools-install) override log functions after sourcing
# for specialized logging (file-only, JSONL, etc.).

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
IS_MACOS=false
IS_WINDOWS=false
case "$(uname -s)" in
    Darwin*)              IS_MACOS=true ;;
    MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;;
esac

# ---------------------------------------------------------------------------
# Log directory (platform-aware)
# ---------------------------------------------------------------------------
AITOOLS_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aitools"
$IS_MACOS && AITOOLS_LOG_DIR="$HOME/Library/Logs/aitools"

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
logging_init() {
    SCRIPT_NAME="${1:?logging_init requires a script name}"
    LOG_DIR="$AITOOLS_LOG_DIR"
    LOG_FILE="$LOG_DIR/deploy.log"
    mkdir -p "$LOG_DIR"
    ERRORS=0
    WARNINGS=0
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

# ---------------------------------------------------------------------------
# Summary writer (3-arg: category, tool, detail)
# ---------------------------------------------------------------------------
write_summary() {
    if [ -n "${AITOOLS_SUMMARY_FILE:-}" ]; then
        printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$AITOOLS_SUMMARY_FILE"
    fi
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
