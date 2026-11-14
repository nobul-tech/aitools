# ---------------------------------------------------------------------------
# PROTOTYPE (M3b-Finish-R, optional bash twin of fix 1) -- read_tty_choice for
# scripts/aitools-lib.sh. Not wired into any tracked file. The guard logic is the
# block exercised by msys-stty.sh (variant "guarded"); this function form was only
# syntax-checked (bash -n), not run on a macOS/Linux pty.
#
# EOF-safe prompt read. Usage: read_tty_choice <var> <what-the-default-does>
# A program run earlier in this terminal may have left it raw (icanon/echo/icrnl
# off, e.g. killed while in raw mode): Enter then sends \r, `read` does not
# return, nothing echoes, and the answer arrives as "o\r" (the caller's `*)`
# default branch). The terminal settings are saved, line input forced for this
# one read, and restored after. Without a queryable terminal it reads as before.
# ---------------------------------------------------------------------------
read_tty_choice() {
    local __var="$1" __default_desc="$2" __line="" __saved=""
    # 2>/dev/null: stty -g fails when /dev/tty has no termios (no controlling
    # terminal); the empty result is checked below and the read runs unguarded.
    __saved=$(stty -g < /dev/tty 2>/dev/null) || __saved=""
    if [ -n "$__saved" ]; then
        stty icanon echo icrnl < /dev/tty 2>/dev/null || log_detail "read_tty_choice: could not set line mode"
    fi
    if ! IFS= read -r __line < /dev/tty; then
        printf '\n' > /dev/tty
        log_warn "No input at prompt (EOF) -- defaulting to $__default_desc"
        __line=""
    fi
    if [ -n "$__saved" ]; then
        stty "$__saved" < /dev/tty 2>/dev/null || log_detail "read_tty_choice: could not restore terminal settings"
    fi
    printf -v "$__var" '%s' "$__line"
}
