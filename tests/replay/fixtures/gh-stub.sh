#!/usr/bin/env bash
# gh-stub.sh -- tests/replay fixture: copied as "gh" onto the PATH of the replay
# run. "gh auth status" exits 1 (not authenticated). "gh auth login" checks that
# its stdin and stdout are terminals (the installer runs it </dev/tty >/dev/tty
# inside a relay, whose stdout is a pipe), prints a prompt, reads one line and
# appends "stdin=<tty|not-tty> stdout=<tty|not-tty> answer=<line>" to
# $GH_STUB_LOG; it exits $GH_LOGIN_RC (default 0). Anything else exits 1.
# Not a product script: test stub only.

case "${1:-} ${2:-}" in
    "auth status")
        exit 1 ;;
    "auth login")
        i=not-tty; o=not-tty
        if [ -t 0 ]; then i=tty; fi
        if [ -t 1 ]; then o=tty; fi
        printf '? Paste your authentication token: '
        answer=""
        if ! IFS= read -r answer; then answer="<EOF>"; fi
        printf 'stdin=%s stdout=%s answer=%s\n' "$i" "$o" "$answer" >> "${GH_STUB_LOG:?GH_STUB_LOG is not set}"
        exit "${GH_LOGIN_RC:-0}" ;;
esac
exit 1
