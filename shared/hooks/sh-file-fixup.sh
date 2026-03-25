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
#   - Stderr feedback is shown to Claude

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
dir=$(dirname "$file_path")
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mode=$(git -C "$dir" ls-files -s "$file_path" 2>/dev/null | cut -c1-6)
    if [ "$mode" = "100644" ]; then
        git update-index --chmod=+x "$file_path" 2>/dev/null || true
        fixed="${fixed}git+x "
    fi
fi

# Report what was fixed (stderr → shown to Claude as feedback)
if [ -n "$fixed" ]; then
    echo "sh-file-fixup: $(basename "$file_path") — fixed: ${fixed% }" >&2
    emit_hook_event "hook_fire" "{\"file\":\"$(basename "$file_path")\",\"action\":\"${fixed% }\"}"
fi

exit 0
