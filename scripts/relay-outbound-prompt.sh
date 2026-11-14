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
    local rc=0
    _relay_outbound_choice < /dev/tty > /dev/tty || rc=$?
    case "$rc" in
        2)
            return 2
            ;;
        3)
            git -C "$repo" status -sb > /dev/tty
            printf '\n' > /dev/tty
            ;;
    esac
    return 0
}

# Read the [RELAY] choice from stdin; the prompt and hints go to stdout (the
# caller points both at /dev/tty). An empty or unrecognised answer asks again.
# Returns 0 continue, 2 quit, 3 show git status. End of input, or 50
# unrecognised answers in a row, continues (the prompt's EOF default) and says so.
# hh.sh does not load aitools-lib, so this mirrors the library's
# read_menu_choice locally: same hint text, no answer logging.
_relay_outbound_choice() {
    local choice="" rc=0 tries=0
    while :; do
        printf '  choice [c/q/s]: '
        rc=0
        IFS= read -r choice || rc=$?
        # Trim surrounding whitespace (a CR included), then lowercase
        choice="${choice#"${choice%%[![:space:]]*}"}"
        choice="${choice%"${choice##*[![:space:]]}"}"
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')
        case "$choice" in
            c|continue) return 0 ;;
            q|quit) return 2 ;;
            s|show) return 3 ;;
        esac
        if [ "$rc" -ne 0 ]; then
            printf '\n  (no input -- continuing)\n'
            return 0
        fi
        tries=$((tries + 1))
        if [ "$tries" -ge 50 ]; then
            printf '  (no input -- continuing)\n'
            return 0
        fi
        printf '  please type one of c/continue/q/quit/s/show\n'
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    relay_outbound_prompt "${1:?usage: $0 /path/to/aitools}"
    exit $?
fi
