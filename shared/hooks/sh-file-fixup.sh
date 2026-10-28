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
#   - Receives JSON on stdin with tool_input.file_path
#   - Exit 0 always (PostToolUse must never block)
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

# Extract file_path from tool_input (pure-bash, no jq dependency)
file_path=""
if [[ "$input" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    file_path="${BASH_REMATCH[1]}"
fi

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
dir=$(dirname "$file_path")
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Under pipefail a failing ls-files would abort the hook before it
    # reports anything (seen on Windows Git Bash, exit 128, for a path with
    # a space and an apostrophe); report the failed check instead.
    if ! mode=$(git -C "$dir" ls-files -s -- "$file_path" 2>/dev/null | cut -c1-6); then
        mode=""
        failed="${failed}git-mode-check "
    fi
    if [ "$mode" = "100644" ]; then
        # -C "$dir": the index of the repo that holds the file, not the cwd's.
        # A failure (index lock held, ...) is reported, not hidden.
        if git -C "$dir" update-index --chmod=+x "$file_path" >/dev/null 2>&1; then
            fixed="${fixed}git+x "
        else
            failed="${failed}git+x "
        fi
    fi
fi

# --- Report: stdout additionalContext JSON (Claude) + stderr text ---
# json_escape <text>: escape for a JSON string value (bash 3.2: no ${x@Q}).
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

if [ -n "$fixed" ] || [ -n "$failed" ]; then
    name=$(basename "$file_path")
    msg="sh-file-fixup: ${name}"
    [ -z "$fixed" ] || msg="${msg} — fixed: ${fixed% } (applied after the tool ran)"
    [ -z "$failed" ] || msg="${msg} — fix failed: ${failed% }; run: git -C ${dir} update-index --chmod=+x ${file_path}"
    printf '%s\n' "$msg" >&2
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_escape "$msg")"
    emit_hook_event "hook_fire" "{\"file\":\"$(json_escape "$name")\",\"action\":\"$(json_escape "${fixed% }")\",\"failed\":\"$(json_escape "${failed% }")\"}"
fi

exit 0
