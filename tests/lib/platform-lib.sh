#!/usr/bin/env bash
# platform-lib.sh -- shared helpers for platform-targeted test suites (sourced, not run).
#
# Each script is tested only on the platforms its OS guard allows
# (plans/ci-platform-targeting.md; commander 2026-11-01: ".ps1 scripts only run
# on windows ... linux/mac should only run the scripts meant to run there").
# A suite that covers a .sh/.ps1 pair runs the .sh half on macOS/Linux and the
# .ps1 half on Windows (Git Bash driving native pwsh). Parity between the two
# halves is checked against committed golden results instead of a second run on
# the same machine: both platforms must produce the same golden file.
#
# Provides:
#   TEST_PLATFORM   linux | macos | windows
#   TEST_LANG       sh (macOS, Linux) | ps1 (Windows)
#   native_path P   P as a native Windows program reads it (C:/... via cygpath -m);
#                   unchanged off Windows
#   golden_match NAME FILE
#                   0 when FILE, normalized, equals GOLDEN_DIR/NAME.<platform> if
#                   that exists, else GOLDEN_DIR/NAME; prints a diff otherwise.
#                   AITOOLS_TEST_UPDATE_GOLDEN=1 on macOS/Linux writes the golden
#                   file from FILE instead (review the diff in the PR); on
#                   Windows the golden files are never written.
# Normalization: CR removed; GOLDEN_TMP (the suite's temp root), in its POSIX and
#   native forms, replaced by <TMP>; backslashes in <TMP>-relative paths turned
#   into slashes. Set GOLDEN_DIR (absolute) and GOLDEN_TMP before calling.
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible.

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) TEST_PLATFORM=windows ;;
    Darwin) TEST_PLATFORM=macos ;;
    *) TEST_PLATFORM=linux ;;
esac
if [ "$TEST_PLATFORM" = windows ]; then TEST_LANG=ps1; else TEST_LANG=sh; fi

native_path() {
    if [ "$TEST_PLATFORM" = windows ] && command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        printf '%s' "$1"
    fi
}

# _golden_normalize FILE: normalized content on stdout
_golden_normalize() {
    local tmp_posix="${GOLDEN_TMP:-}" tmp_native=""
    [ -n "$tmp_posix" ] && tmp_native="$(native_path "$tmp_posix")"
    GT_POSIX="$tmp_posix" GT_NATIVE="$tmp_native" perl -pe '
        s/\r//g;
        for my $t (grep { length } ($ENV{GT_NATIVE}, $ENV{GT_POSIX})) {
            (my $bs = $t) =~ s{/}{\\}g;
            s/\Q$t\E([^\s|"]*)/my $r = $1; $r =~ tr{\\}{\/}; "<TMP>$r"/ge;
            s/\Q$bs\E([^\s|"]*)/my $r = $1; $r =~ tr{\\}{\/}; "<TMP>$r"/ge;
        }
    ' "$1"
}

golden_match() {
    local name="$1" file="$2" golden
    if [ -z "${GOLDEN_DIR:-}" ]; then
        printf '      | golden_match: GOLDEN_DIR is not set\n'
        return 1
    fi
    golden="$GOLDEN_DIR/$name"
    [ -f "$golden.$TEST_PLATFORM" ] && golden="$golden.$TEST_PLATFORM"
    if [ "${AITOOLS_TEST_UPDATE_GOLDEN:-}" = "1" ]; then
        if [ "$TEST_PLATFORM" = windows ]; then
            printf '      | golden files are written from a macOS/Linux .sh run only\n'
            return 1
        fi
        mkdir -p "$GOLDEN_DIR"
        _golden_normalize "$file" > "$golden"
        printf '      | golden written: %s\n' "${golden#"$GOLDEN_DIR"/}"
        return 0
    fi
    if [ ! -f "$golden" ]; then
        printf '      | missing golden file %s (write it: AITOOLS_TEST_UPDATE_GOLDEN=1 on macOS/Linux)\n' "$golden"
        return 1
    fi
    if _golden_normalize "$file" | cmp -s - "$golden"; then
        return 0
    fi
    printf '      | differs from golden %s (- golden, + %s):\n' "${golden#"$GOLDEN_DIR"/}" "$TEST_LANG"
    _golden_normalize "$file" | diff "$golden" - | perl -pe 's/^/      | /' | perl -ne 'print if $. <= 30'
    return 1
}
