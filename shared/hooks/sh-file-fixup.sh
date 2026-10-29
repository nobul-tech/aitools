#!/usr/bin/env bash
# sh-file-fixup.sh — Claude Code PostToolUse hook for Write and Edit
# Auto-fixes .sh files after creation/modification:
#   - CRLF → LF line endings (Write tool on macOS can produce CRLF)
#   - chmod +x on disk (Write tool creates 100644)
#   - git update-index --chmod=+x (if tracked with wrong mode)
#
# Eliminates the recurring manual fixup cycle that interrupts every commit
# involving .sh files. See reference/framework-incident-investigation.md.
#
# Hook contract:
#   - PostToolUse on Write|Edit (runs AFTER the tool completes)
#   - Receives JSON on stdin with tool_input.file_path. The value is
#     JSON-unescaped (\\ \" \/); a Windows path (C:\x\y.sh) is converted
#     with cygpath -u; a relative path resolves against the payload's cwd.
#   - Exit 0 always (PostToolUse must never block)
#   - A failed fix names the step, quotes git's first error line, and gives
#     a shell-quoted command to run (printf %q)
#   - When something was fixed (or a fix failed), the report goes out twice:
#       stdout: {"hookSpecificOutput":{"hookEventName":"PostToolUse",
#               "additionalContext":"..."}} -- the channel Claude reads
#               on exit 0; it arrives next to the tool result, so Claude
#               knows the file on disk changed after its Write/Edit.
#       stderr: the same text, for the transcript and tests.
#     Claude never sees stderr from a hook that exits 0 (Claude Code hooks
#     reference, "Exit code 0"; 935 transcript records of this hook up to
#     2026-10-28 carried the report on stderr only, so none reached Claude).
#   - Nothing to fix: no output.
# Platform: macOS + Linux + Windows Git Bash (bash 3.2 compatible)

set -euo pipefail

# --- Telemetry: JSONL event emission ---
_SESSION_DIR=""
_cs_file="$(git rev-parse --show-toplevel 2>/dev/null || echo "")/.scratch/.current-session"
if [ -f "$_cs_file" ]; then
    _SESSION_DIR=$(cat "$_cs_file" 2>/dev/null || true)
fi

emit_hook_event() {
    local event_type="$1" detail_json="$2"
    [ -n "$_SESSION_DIR" ] || return 0
    printf '{"t":"%s","type":"%s","src":"fixup","d":%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$event_type" "$detail_json" \
        >> "$_SESSION_DIR/events.jsonl" 2>/dev/null || true
}

# Read JSON from stdin
input=$(cat)

# --- Path helpers (pure bash, no jq dependency) ---
# json_string_field <json> <key>: the raw (still JSON-escaped) string value,
# escape-aware so an escaped quote does not end it.
json_string_field() {
    local pattern="\"$2\"[[:space:]]*:[[:space:]]*\"((\\\\.|[^\"\\\\])*)\""
    if [[ "$1" =~ $pattern ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}
# json_unescape_path <raw>: undo the JSON escapes a path can carry (\\ \" \/).
# Other escapes (\n, \t, \uXXXX) are left as they are: a path with them is
# then not found, and the hook stays silent, as before.
json_unescape_path() {
    # Replacements come from variables: bash 3.2 keeps a literal "\/" in a
    # replacement string (probed 2026-10-28, 3.2.57 vs 5.3.15).
    local s="$1" bs=$'\001' sl='/' dq='"' b='\'
    s="${s//\\\\/$bs}"
    s="${s//\\\"/$dq}"
    s="${s//\\\//$sl}"
    s="${s//$bs/$b}"
    printf '%s' "$s"
}
# native_to_posix <path>: a Windows path (C:\x\y.sh or C:/x/y.sh) as Git Bash
# sees it, so dirname and [ -f ] work (dirname 'C:\x\y.sh' is "."). Other
# paths are returned unchanged.
native_to_posix() {
    case "$1" in
        [A-Za-z]:[\\/]*)
            if command -v cygpath >/dev/null 2>&1; then
                cygpath -u "$1"
            else
                printf '%s' "${1//\\//}"
            fi
            ;;
        *) printf '%s' "$1" ;;
    esac
}

# Extract file_path from tool_input; a relative path resolves against the
# payload's cwd (Claude Code sends absolute paths, but do not trust it).
file_path=$(native_to_posix "$(json_unescape_path "$(json_string_field "$input" "file_path")")")
case "$file_path" in
    ""|/*) ;;
    *)
        payload_cwd=$(native_to_posix "$(json_unescape_path "$(json_string_field "$input" "cwd")")")
        [ -z "$payload_cwd" ] || file_path="${payload_cwd%/}/$file_path"
        ;;
esac

# Only act on .sh files
[ -n "$file_path" ] || exit 0
[[ "$file_path" == *.sh ]] || exit 0
[ -f "$file_path" ] || exit 0

fixed=""

# Fix CRLF → LF
if perl -ne 'exit 1 if /\r/' "$file_path" 2>/dev/null; then
    : # no CRLF found
else
    perl -pi -e 's/\r$//' "$file_path"
    fixed="${fixed}CRLF->LF "
fi

# Fix executable bit on disk
if [ ! -x "$file_path" ]; then
    chmod +x "$file_path"
    fixed="${fixed}+x "
fi

# Fix git index executable bit (if inside a git work tree)
failed=""
fail_detail=""
dir=$(dirname "$file_path")
base=$(basename "$file_path")
# first_line <text>: the first line, for quoting git's error in the report
first_line() { printf '%s' "${1%%$'\n'*}"; }
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # -C "$dir" with the base name: the index of the repo that holds the
    # file (not the cwd's), and no path that git must re-resolve from $dir.
    # git's stderr is captured (2>&1), not discarded, so a failure says why.
    # Under pipefail a failing ls-files would abort the hook before it
    # reports anything (seen on Windows Git Bash, exit 128); `if !` keeps it.
    mode=""
    if ls_out=$(git -C "$dir" ls-files -s -- "$base" 2>&1); then
        case "$ls_out" in
            [0-7][0-7][0-7][0-7][0-7][0-7]\ *) mode="${ls_out:0:6}" ;;
        esac
    else
        failed="${failed}git-mode-check "
        fail_detail="${fail_detail}; git-mode-check: git ls-files failed in $(printf '%q' "$dir") ($(first_line "$ls_out")), so the index mode is unknown; check the repo with: git -C $(printf '%q' "$dir") status"
    fi
    if [ "$mode" = "100644" ]; then
        if ui_out=$(git -C "$dir" update-index --chmod=+x -- "$base" 2>&1); then
            fixed="${fixed}git+x "
        else
            failed="${failed}git+x "
            fail_detail="${fail_detail}; git+x: $(first_line "$ui_out"); run: git -C $(printf '%q' "$dir") update-index --chmod=+x -- $(printf '%q' "$base")"
        fi
    fi
fi

# --- Report: stdout additionalContext JSON (Claude) + stderr text ---
# json_escape <text>: escape for a JSON string value (bash 3.2: no ${x@Q}).
# \ " \n \r \t get their short escapes; every other control character below
# 0x20 (ESC, ...) becomes \u00XX, so a file name can never make the JSON
# invalid (Claude Code would then drop the whole report).
json_escape() {
    local s="$1" out="" c i n
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    if [[ "$s" != *[[:cntrl:]]* ]]; then
        printf '%s' "$s"
        return 0
    fi
    for ((i = 0; i < ${#s}; i++)); do
        c="${s:i:1}"
        case "$c" in
            [[:cntrl:]])
                printf -v n '%d' "'$c"
                if [ "$n" -ge 0 ] && [ "$n" -lt 32 ]; then
                    out="${out}$(printf '\\u%04x' "$n")"
                else
                    out="${out}${c}"
                fi
                ;;
            *) out="${out}${c}" ;;
        esac
    done
    printf '%s' "$out"
}

if [ -n "$fixed" ] || [ -n "$failed" ]; then
    name="$base"
    msg="sh-file-fixup: ${name}"
    [ -z "$fixed" ] || msg="${msg} — fixed: ${fixed% } (applied after the tool ran)"
    [ -z "$failed" ] || msg="${msg} — fix failed: ${failed% }${fail_detail}"
    printf '%s\n' "$msg" >&2
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_escape "$msg")"
    emit_hook_event "hook_fire" "{\"file\":\"$(json_escape "$name")\",\"action\":\"$(json_escape "${fixed% }")\",\"failed\":\"$(json_escape "${failed% }")\"}"
fi

exit 0
