# ---------------------------------------------------------------------------
# Choice-menu read. Usage:
#   read_menu_choice VAR "VALID" DEFAULT "DEFAULT_DESC" "CONTEXT" "PROMPT"
# VALID: the accepted answers, lowercase, space-separated ("o a m s x",
# "y yes n no"). DEFAULT: the answer taken only at EOF (one of VALID).
# DEFAULT_DESC: what the default does (read_tty_choice's EOF warning).
# CONTEXT: a short label for the log ("review CLAUDE.md"). PROMPT: printed as
# data before every read ("  choice [o/s/x]: "); the caller prints the menu.
# Reads through read_tty_choice, trims surrounding whitespace and lowercases.
# An offered answer sets VAR. Anything else -- an empty line, a word, a letter
# not offered -- prints "  please type one of a/b/c" and asks again (commander,
# 2026-11-13: "no default or other characters should re-ask"). EOF sets VAR to
# DEFAULT. Every answer is logged at detail (deploy.log only).
# EOF detection: read_tty_choice returns "" both at EOF and for a typed empty
# line. READ_TTY_EOF=1 after the read marks EOF (contract for read_tty_choice,
# see the M2-Reask PR "Contract change"); until read_tty_choice sets it, an
# empty answer with WARNINGS raised during the read is EOF (its EOF branch
# calls log_warn). 50 unrecognised answers in a row are treated as EOF, so a
# closed input that is not detected cannot loop forever.
# Spec: .claude/rules/interactive-menus.md "Answers";
# reference/managed-file-deployment.md "Menus". Parity: Read-MenuChoice in
# aitools-lib.ps1.
# ---------------------------------------------------------------------------
READ_TTY_EOF=0
read_menu_choice() {
    local __mvar="$1" __valid="$2" __default="$3" __desc="$4" __ctx="$5" __prompt="$6"
    local __ans="" __raw="" __w0=0 __tries=0 __v="" __hint=""
    for __v in $__valid; do
        if [ -z "$__hint" ]; then __hint="$__v"; else __hint="$__hint/$__v"; fi
    done
    while true; do
        printf '%s' "$__prompt" > /dev/tty
        READ_TTY_EOF=0
        __w0="${WARNINGS:-0}"
        __raw=""
        read_tty_choice __raw "$__desc"
        if [ "${READ_TTY_EOF:-0}" = "1" ] || { [ -z "$__raw" ] && [ "${WARNINGS:-0}" -gt "$__w0" ]; }; then
            log_detail "menu answer ($__ctx): EOF -> $__default"
            printf -v "$__mvar" '%s' "$__default"
            return 0
        fi
        # Trim surrounding whitespace (a CR included), then lowercase
        __ans="${__raw#"${__raw%%[![:space:]]*}"}"
        __ans="${__ans%"${__ans##*[![:space:]]}"}"
        __ans=$(printf '%s' "$__ans" | tr '[:upper:]' '[:lower:]')
        for __v in $__valid; do
            if [ "$__ans" = "$__v" ]; then
                log_detail "menu answer ($__ctx): \"$__raw\" -> $__ans"
                printf -v "$__mvar" '%s' "$__ans"
                return 0
            fi
        done
        log_detail "menu answer ($__ctx): \"$__raw\" -> not one of $__hint, asked again"
        __tries=$((__tries + 1))
        if [ "$__tries" -ge 50 ]; then
            log_warn "No valid answer after 50 tries at $__ctx -- treating input as ended, defaulting to $__desc"
            printf -v "$__mvar" '%s' "$__default"
            return 0
        fi
        printf '  please type one of %s\n' "$__hint" > /dev/tty
    done
}
