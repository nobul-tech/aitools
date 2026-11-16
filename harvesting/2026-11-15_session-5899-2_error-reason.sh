#!/bin/bash
# Feasibility probe: error_reason OUTPUT EXIT_CODE in bash 3.2-compatible syntax,
# no grep -P, no pipeline ending in grep -q / head (script-standards).
set -euo pipefail
shopt -s extglob
error_reason() {
    local out="$1" rc="${2:-1}" line esc=$'\033' last="" hit=""
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line//$'\r'/}"
        # extglob: ESC [ digits/semicolons letter (bash 3.2 has extglob)
        line="${line//${esc}\[*([0-9;])[A-Za-z]/}"
        case "$line" in
            *[![:space:]]*) last="$line" ;;
            *) continue ;;
        esac
        if [ -z "$hit" ]; then
            case "$line" in
                Error:*|*" Error:"*|error:*|*" error:"*|fatal:*|*" fatal:"*|"E: "*|*failed*) hit="$line" ;;
            esac
        fi
    done <<< "$out"
    if [ -n "$hit" ]; then printf '%s' "$hit"
    elif [ -n "$last" ]; then printf '%s' "$last"
    else printf 'no output (exit %s)' "$rc"; fi
}
printf 'bash %s\n' "$BASH_VERSION"
printf 'L13: %s\n' "$(error_reason $'==> Fetching\nError: No available formula with the name x\ntail' 1)"
printf 'L14: %s\n' "$(error_reason $'a\n\033[33mlast line\033[0m\r\n\n' 1)"
printf 'L15: %s\n' "$(error_reason '' 2)"
printf 'NOTE-substring: %s\n' "$(error_reason $'NOTE: using cache\nok' 1)"
