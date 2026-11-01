#!/usr/bin/env bash
# test-os-guards.sh -- every product script's OS guard refuses the wrong platform.
#
# Purpose: prove the platform targeting of plans/ci-platform-targeting.md
# (commander, 2026-11-01: "the os guard should be tested to ensure it works,
# ie, the pwsh scripts meant for windows only should refuse to run").
#
# The script list comes from the files, not a hand list. Every tracked .ps1 and
# .sh under scripts/, shared/ and packaging/ is one of:
#   win     .ps1 with the Windows guard (-not $IsWindows ... "This script is for
#           Windows" ... exit 1; canonical form in .claude/rules/cross-platform.md)
#   posix   .sh with the POSIX guard (MINGW*|MSYS*|CYGWIN*) ... "This script is
#           for macOS/Linux" ... exit 1)
#   exempt  no guard, and listed in the "OS guard exemptions" table of
#           .claude/rules/cross-platform.md (hooks, libraries, entry points ...)
# A script with no guard that the table does not list FAILS (detection layer).
#
# On macOS and Linux: each win script, run with pwsh -NoProfile -NonInteractive
#   -File and no arguments under an isolated HOME, must exit 1, print the guard
#   message, and write nothing under HOME except ~/.aitools/logs.
# On Windows (Git Bash): each posix script, run with bash under an isolated
#   HOME, must do the same with the macOS/Linux message.
# The guards' pass side (the script runs on its own platform) is covered by the
# functional suites that run there.
#
# Usage: bash tests/os-guards/test-os-guards.sh [--help]
# Exit: 0 all checks pass, 1 any failure. Without pwsh on macOS/Linux the
#   refusal checks are reported FAIL under CI (CI=true) and SKIP elsewhere.
# Platform: macOS, Linux, Windows Git Bash; bash 3.2 compatible. Safe to re-run
#   (everything runs under a temp dir that is removed on exit).
set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if 2 .. /^set -euo/' "$0" | perl -ne 'print unless /^set -euo/' | perl -pe 's/^# ?//'
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
cleanup() { cd / && rm -rf "$WORK"; }
trap cleanup EXIT

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
    Darwin) PLATFORM=macos ;;
    *) PLATFORM=linux ;;
esac

PASS=0
FAIL=0
SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  skip %s\n' "$1"; }

# native <path>: a path a native Windows program (pwsh) can open; unchanged elsewhere
native() {
    if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# --- Classify every product script (one perl pass) ---------------------------
CLASSES="$WORK/classes.tsv"
if ! git -C "$ROOT" ls-files -- 'scripts/*.ps1' 'scripts/*.sh' 'shared/*.ps1' 'shared/*.sh' \
        'packaging/*.ps1' 'packaging/*.sh' > "$WORK/files.txt"; then
    printf 'FAIL: git ls-files failed in %s\n' "$ROOT"
    exit 1
fi
if ! perl -e '
    use strict; use warnings;
    my ($root, $rules, $list) = @ARGV;
    # Exemption tokens: column 2 of the "### OS guard exemptions" table.
    open my $rf, "<", $rules or die "cannot read $rules: $!\n";
    my ($in, @tok) = (0);
    while (my $l = <$rf>) {
        if ($l =~ /^### OS guard exemptions/) { $in = 1; next }
        last if $in && $l =~ /^### /;
        next unless $in && $l =~ /^\|/;
        my @col = split /\|/, $l;
        next unless defined $col[2];
        for my $t ($col[2] =~ /`([^`]+)`/g) {
            if ($t =~ m{^(.*)\.sh/\.ps1$}) { push @tok, "$1.sh", "$1.ps1" } else { push @tok, $t }
        }
    }
    close $rf;
    die "no exemption tokens found in $rules\n" unless @tok;
    my $glob2re = sub { my $g = quotemeta shift; $g =~ s/\\\*/[^\/]*/g; $g =~ s/\\\?/./g; qr/^$g$/ };
    my @pat = map { [ $_, $glob2re->($_), (index($_, "/") >= 0) ] } @tok;
    open my $lf, "<", $list or die "cannot read $list: $!\n";
    while (my $f = <$lf>) {
        chomp $f;
        next if $f eq "";
        open my $fh, "<", "$root/$f" or die "cannot read $f: $!\n";
        local $/; my $t = <$fh>; close $fh;
        my $kind = "none";
        if ($f =~ /\.ps1$/) {
            $kind = "win" if $t =~ /-not \$IsWindows\)\s*\{[^}]{0,300}?This script is for Windows[^}]{0,200}?exit 1/s;
        } else {
            $kind = "posix" if $t =~ /MINGW\*\|MSYS\*\|CYGWIN\*\)[^;]{0,300}?This script is for macOS\/Linux[^;]{0,200}?exit 1/s;
        }
        if ($kind eq "none") {
            (my $base = $f) =~ s{.*/}{};
            my ($hit) = grep { $_->[2] ? $f =~ $_->[1] : $base =~ $_->[1] } @pat;
            print $hit ? "exempt\t$f\t$hit->[0]\n" : "unexempt\t$f\n";
        } else {
            print "$kind\t$f\n";
        }
    }
' "$ROOT" "$ROOT/.claude/rules/cross-platform.md" "$WORK/files.txt" > "$CLASSES"; then
    printf 'FAIL: classification failed (see the error above)\n'
    exit 1
fi

n_win=$(grep -c '^win	' "$CLASSES" || true)
n_posix=$(grep -c '^posix	' "$CLASSES" || true)
n_exempt=$(grep -c '^exempt	' "$CLASSES" || true)
printf '== %s: %s Windows-guarded .ps1, %s POSIX-guarded .sh, %s exempt\n' \
    "$PLATFORM" "$n_win" "$n_posix" "$n_exempt"

echo "== every unguarded script is in the cross-platform.md exemption table"
if grep -q '^unexempt	' "$CLASSES"; then
    while IFS="$(printf '\t')" read -r _ f; do
        bad "no OS guard and not in the exemption table: $f"
    done < <(grep '^unexempt	' "$CLASSES")
else
    ok "all $n_exempt unguarded scripts are listed exemptions"
fi
[ "$n_win" -gt 0 ] && ok "found Windows-guarded scripts ($n_win)" || bad "found no Windows-guarded .ps1 (classifier broken?)"
[ "$n_posix" -gt 0 ] && ok "found POSIX-guarded scripts ($n_posix)" || bad "found no POSIX-guarded .sh (classifier broken?)"

# refuse <kind> <path> <runner...>: run a script on the wrong platform under a
# fresh HOME; it must exit 1, print the guard message, and write only logs.
refuse() {
    local kind="$1" f="$2"
    shift 2
    local h="$WORK/home-$(printf '%s' "$f" | tr '/.' '__')"
    local cwd="$WORK/cwd"
    mkdir -p "$h" "$cwd"
    local want="This script is for Windows"
    [ "$kind" = posix ] && want="This script is for macOS/Linux"
    local rc=0
    (cd "$cwd" && env HOME="$h" USERPROFILE="$(native "$h")" "$@" < /dev/null \
        > "$WORK/out.txt" 2>&1) || rc=$?
    # Allowed writes: the script's own logs (it logs its refusal) and pwsh's
    # startup cache (~/.cache/powershell/StartupProfileData-*, written by pwsh
    # itself before any script code runs).
    local stray
    stray=$(cd "$h" && find . -type f ! -path './.aitools/logs/*' ! -path './.cache/powershell/*' | head -n 5)
    if [ "$rc" -eq 1 ] && grep -qF "$want" "$WORK/out.txt" && [ -z "$stray" ]; then
        ok "$f refuses $PLATFORM (exit 1, guard message, only logs written)"
    else
        bad "$f on $PLATFORM: exit $rc (want 1); message $(grep -qF "$want" "$WORK/out.txt" && echo present || echo MISSING); stray files: ${stray:-none}"
        perl -ne 'print "       | $_" if $. <= 8' "$WORK/out.txt"
    fi
}

if [ "$PLATFORM" = windows ]; then
    echo "== POSIX-guarded .sh scripts refuse Windows (Git Bash)"
    while IFS="$(printf '\t')" read -r _ f; do
        refuse posix "$f" bash "$ROOT/$f"
    done < <(grep '^posix	' "$CLASSES")
else
    echo "== Windows-guarded .ps1 scripts refuse $PLATFORM (pwsh)"
    if command -v pwsh >/dev/null 2>&1; then
        while IFS="$(printf '\t')" read -r _ f; do
            refuse win "$f" pwsh -NoProfile -NonInteractive -File "$(native "$ROOT/$f")"
        done < <(grep '^win	' "$CLASSES")
    elif [ "${CI:-}" = "true" ]; then
        bad "pwsh is not on PATH: the Windows guards cannot be tested on this runner"
    else
        skip "pwsh is not on PATH: Windows guard refusal checks not run"
    fi
fi

printf '\ntest-os-guards: %d passed, %d failed, %d skipped (%s, bash %s)\n' \
    "$PASS" "$FAIL" "$SKIP" "$PLATFORM" "$BASH_VERSION"
[ "$FAIL" -eq 0 ]
