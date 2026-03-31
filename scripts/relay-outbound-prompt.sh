#!/usr/bin/env bash
# relay-outbound-prompt.sh — [RELAY] prompt when relay.md is dirty or main is ahead of origin
#
# Sourced by scripts/aitools and hh.sh:
#   source "$repo/scripts/relay-outbound-prompt.sh"
#   relay_outbound_prompt "$repo"
#
# Or run directly:
#   bash scripts/relay-outbound-prompt.sh /path/to/aitools
#
# Env:
#   AITOOLS_SKIP_RELAY_PROMPT=1  — skip (automation / CI)
#   CI                           — non-interactive: one-line hint only
#   RELAY_PROMPT_FORCE=1         — prompt even when CI is set (TTY only)

relay_outbound_prompt() {
    local repo="${1:?relay_outbound_prompt: repo path required}"
    local relay_rel=".aitools/channel/relay.md"
    local relay_path="$repo/$relay_rel"

    [ -d "$repo/.git" ] || return 0
    [ -f "$relay_path" ] || return 0

    if [ "${AITOOLS_SKIP_RELAY_PROMPT:-}" = "1" ]; then
        return 0
    fi

    local dirty=0
    if [ -n "$(git -C "$repo" status --porcelain -- "$relay_rel" 2>/dev/null)" ]; then
        dirty=1
    fi

    local ahead=0 behind=0 branch_name
    branch_name=$(git -C "$repo" branch --show-current 2>/dev/null || echo main)
    if git -C "$repo" rev-parse --verify origin/main >/dev/null 2>&1; then
        ahead=$(git -C "$repo" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
        behind=$(git -C "$repo" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
    fi
    ahead=${ahead:-0}
    behind=${behind:-0}

    [ "$dirty" -eq 1 ] || [ "${ahead:-0}" -gt 0 ] || return 0

    local tty_ok=false
    if (printf '' > /dev/tty) 2>/dev/null; then
        tty_ok=true
    fi

    if [ -n "${CI:-}" ] && [ -z "${RELAY_PROMPT_FORCE:-}" ]; then
        printf '\033[33m[RELAY]\033[0m %s — uncommitted relay and/or unpushed commits (see git status)\n' "$relay_rel" >&2
        return 0
    fi

    if ! $tty_ok; then
        printf '\033[33m[RELAY]\033[0m %s — uncommitted relay and/or unpushed commits — run: git -C %s status -sb\n' \
            "$relay_rel" "$repo" >&2
        return 0
    fi

    printf '\n\033[33m[RELAY]\033[0m Outbound relay / git — other machines need your commits.\n' > /dev/tty
    if [ "$dirty" -eq 1 ]; then
        printf '  %s: local changes (not committed)\n' "$relay_rel" > /dev/tty
    fi
    if [ "${ahead:-0}" -gt 0 ]; then
        printf '  %s: %s commit(s) ahead of origin/main (not pushed)\n' "$branch_name" "$ahead" > /dev/tty
    fi
    if [ "${behind:-0}" -gt 0 ]; then
        printf '  %s: also %s behind origin/main — pull before push if others committed\n' "$branch_name" "$behind" > /dev/tty
    fi
    printf '\n  Suggested commands:\n' > /dev/tty
    printf '    git add %s\n' "$relay_rel" > /dev/tty
    printf '    git commit -m "channel: update relay — …"\n' > /dev/tty
    printf '    git push\n' > /dev/tty
    printf '\n  [c]ontinue  [q]uit (exit 2)  [s]how git status\n' > /dev/tty
    printf '  choice [c/q/s] (default c): ' > /dev/tty
    local choice
    read -r choice < /dev/tty
    case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')" in
        q|q*)
            return 2
            ;;
        s|s*)
            git -C "$repo" status -sb > /dev/tty
            printf '\n' > /dev/tty
            ;;
        *)
            return 0
            ;;
    esac
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    relay_outbound_prompt "${1:?usage: $0 /path/to/aitools}"
    exit $?
fi
