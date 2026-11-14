#!/usr/bin/env bash
# test-setup-pywinpty.sh -- setup-pywinpty.sh (dev and MDM copy) and the pywinpty
# part of the MDM build (build-deploy.sh: copy + embedded pin).
#
# Cases:
#   dev-*     scripts/setup-pywinpty.sh, plain, --dry-run, AITOOLS_DRY_RUN=1: exit 0,
#             the one summary row "OK|pywinpty|n/a (<platform>)", nothing written
#             under HOME (macOS and Linux; on Windows the .sh refuses by its OS
#             guard, which tests/os-guards covers: SKIP)
#   build-*   bash scripts/build-deploy.sh into a fixture dotprofile: exit 0;
#             deploy/setup-pywinpty.ps1 carries the pin as the here-string
#             $AitoolsEmbeddedPywinptyPin (the pywinpty== line, every
#             --hash=sha256: line, "'@" at column 0, text equal to
#             scripts/requirements-pywinpty.txt), the library inlined, and parses
#             under pwsh; deploy/setup-pywinpty.sh passes bash -n (every platform)
#   mdm-*     the generated deploy/setup-pywinpty.sh, plain and --dry-run: the same
#             row as dev (macOS and Linux; Windows: SKIP, as dev)
#   pin-*     a broken pin (missing, empty, no pywinpty== line, a "'@" line, no
#             "# wheel-tags:" line, no --hash=sha256: entry): build exit 1 with the
#             matching "Cannot embed the pywinpty pin" error, the fixture
#             dotprofile's deploy/ unchanged. Each case runs the whole build from a
#             temp copy of the tracked files whose scripts/requirements-pywinpty.txt
#             is replaced (build-deploy.sh takes its scripts from its own
#             directory; the real pin is never touched). A run stops at the pin
#             step (3-4 s each on Windows, 2026-11-14), so every case runs the
#             real build rather than the perl block alone.
#
# Safe to re-run: every case runs under its own temp HOME, log dir, summary file
# and fixture dotprofile (a git repo, passed by AITOOLS_USER_REPO_PATH in the
# C:/... form on Windows), all removed on exit; the real HOME and the real
# dotprofile are never read or written. A stub pwsh on PATH (a bash script, as in
# tests/build-deploy) stands in for the build's PS1 validator; the generated
# setup-pywinpty.ps1 is parsed by the real pwsh (SKIP without one, FAIL under
# CI=true). Needs node, perl and git. AITOOLS_TEST_BASH picks the bash that runs
# build-deploy.sh and the .sh scripts (default: bash).
#
# Platform targeting (plans/ci-platform-targeting.md): runs on macOS, Linux and
# Windows (Git Bash); setup-pywinpty.sh is POSIX-guarded, so its runs are SKIP on
# Windows; build-deploy.sh is a bash builder for every platform. The Windows
# install itself is tests/pywinpty/test-setup-pywinpty.ps1. bash 3.2 compatible.
# Exit 1 on any failure.
#
# Usage: bash tests/pywinpty/test-setup-pywinpty.sh [--bash-only] [--help]
#   --bash-only  accepted for compatibility (the suite runs only bash)

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 44' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/platform-lib.sh
. "$ROOT/tests/lib/platform-lib.sh"
TB="${AITOOLS_TEST_BASH:-bash}"
TMP_ROOT="$(mktemp -d)"
cleanup() { cd / && rm -rf "$TMP_ROOT"; }
trap cleanup EXIT
PIN="$ROOT/scripts/requirements-pywinpty.txt"
SUITE_START=$(date +%s)

PASS=0
FAIL=0
SKIP=0
C=""

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "$C" ] && [ -f "$C/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/\r//g; s/^/      | /' "$C/out" | tail -n 25
        fi
    fi
}
skip() {  # name, reason
    printf 'SKIP %s -- %s\n' "$1" "$2"; SKIP=$((SKIP + 1))
}

for tool in node perl git; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'FAIL %s not found -- cannot run build-deploy.sh\n' "$tool"
        exit 1
    fi
done
if [ ! -f "$PIN" ]; then
    printf 'FAIL %s missing\n' "$PIN"
    exit 1
fi
# The real pwsh, found before any stub is put on PATH (parses the generated .ps1).
REAL_PWSH="$(command -v pwsh 2>/dev/null || true)"

# --- setup-pywinpty.sh runs (dev and MDM copy) ---------------------------------

# run_sh <case> <script> [args...]: HOME, log dir and summary file in the case dir;
# extra environment comes from RUN_ENV (one VAR=value or empty).
RUN_ENV=""
run_sh() {
    C="$TMP_ROOT/$1"
    local script="$2"
    shift 2
    mkdir -p "$C/home" "$C/logs"
    : > "$C/summary"
    # shellcheck disable=SC2086
    env -u AITOOLS_DRY_RUN -u AITOOLS_PYWINPTY_PIN -u AITOOLS_PYWINPTY_PYTHON \
        HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" $RUN_ENV \
        "$TB" "$script" "$@" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
}

# na_checks <case label> <dry: yes|no>
na_checks() {
    local want="OK|pywinpty|n/a ($TEST_PLATFORM)"
    check "$1: exit 0" "[ \"\$(cat '$C/rc')\" = 0 ]"
    check "$1: one summary row '$want'" "[ \"\$(perl -pe 's/\\r//' '$C/summary')\" = '$want' ]"
    check "$1: log says n/a on $TEST_PLATFORM, nothing changed" "grep -q 'n/a on $TEST_PLATFORM: pywinpty is Windows-only' '$C/logs/deploy.log'"
    check "$1: nothing written under HOME" "[ -z \"\$(find '$C/home' -type f | head -n 1)\" ]"
    if [ "$2" = yes ]; then
        check "$1: dry-run logged" "grep -q 'DRY RUN' '$C/logs/deploy.log'"
    fi
}

if [ "$TEST_PLATFORM" = windows ]; then
    skip "dev: scripts/setup-pywinpty.sh (plain, --dry-run, AITOOLS_DRY_RUN=1)" "POSIX-guarded: refuses Windows (exit 1), covered by tests/os-guards; the Windows install is test-setup-pywinpty.ps1"
else
    run_sh dev-plain "$ROOT/scripts/setup-pywinpty.sh"
    na_checks "dev plain" no
    run_sh dev-dryrun "$ROOT/scripts/setup-pywinpty.sh" --dry-run
    na_checks "dev --dry-run" yes
    RUN_ENV="AITOOLS_DRY_RUN=1"
    run_sh dev-envdry "$ROOT/scripts/setup-pywinpty.sh"
    RUN_ENV=""
    na_checks "dev AITOOLS_DRY_RUN=1" yes
fi

# --- MDM build ------------------------------------------------------------------

# setup_dot <case>: case dir with a temp HOME, a stub pwsh, and a fixture
# dotprofile (git repo) whose committed deploy/ holds one marker file; a pristine
# copy of that deploy/ is kept for the unchanged checks.
setup_dot() {
    C="$TMP_ROOT/$1"
    D="$C/dot"
    mkdir -p "$C/home/.aitools" "$C/bin" "$D/deploy"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$C/bin/pwsh"
    chmod +x "$C/bin/pwsh"
    git -C "$D" init -q
    git -C "$D" config user.email test@example.invalid
    git -C "$D" config user.name test
    git -C "$D" config core.autocrlf false
    printf '.scratch/\n*.bak.*\n.DS_Store\n' > "$D/.gitignore"
    printf '# fixture\n' > "$D/README.md"
    printf 'previous build\n' > "$D/deploy/setup-pywinpty.ps1"
    cp -Rp "$D/deploy" "$C/pristine"
    git -C "$D" add -A
    git -C "$D" commit -q -m fixture
}

# run_build <build-deploy.sh path>
run_build() {
    local t0
    t0=$(date +%s)
    env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
        HOME="$C/home" USERPROFILE="$(native_path "$C/home")" AITOOLS_LOG_DIR="$C/home/.aitools/logs" \
        AITOOLS_USER_REPO_PATH="$(native_path "$D")" PATH="$C/bin:$PATH" \
        "$TB" "$1" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
    echo $(( $(date +%s) - t0 )) > "$C/secs"
}

# pin_embed_report <generated ps1> <pin>: one line per finding, "ok <what>" or
# "bad <what>"; the checks below grep it.
pin_embed_report() {
    perl -e '
        my ($gen, $pin) = @ARGV;
        open my $g, "<", $gen or die "cannot read $gen: $!\n";
        my @g = map { s/\r?\n\z//r } <$g>;
        close $g;
        open my $p, "<", $pin or die "cannot read $pin: $!\n";
        my $pt = do { local $/; <$p> };
        close $p;
        $pt =~ s/\r//g;
        $pt .= "\n" unless $pt =~ /\n\z/;
        my @open = grep { $g[$_] eq q{$AitoolsEmbeddedPywinptyPin = @} . chr(39) } 0 .. $#g;
        print @open == 1 ? "ok open\n" : "bad open (" . scalar(@open) . " opening lines)\n";
        exit 0 unless @open == 1;
        my $i = $open[0] + 1;
        my @body;
        while ($i <= $#g && $g[$i] ne chr(39) . "@") { push @body, $g[$i]; $i++ }
        print $i <= $#g ? "ok close\n" : "bad close (no closing line at column 0)\n";
        my $body = join("\n", @body) . "\n";
        my ($ver_line) = $pt =~ /^(\s*pywinpty==.*)$/m;
        print((defined $ver_line && grep { $_ eq $ver_line } @body) ? "ok version\n" : "bad version\n");
        my @hash = $pt =~ /^(.*--hash=sha256:.*)$/mg;
        my @miss = grep { my $h = $_; !grep { $_ eq $h } @body } @hash;
        print @hash && !@miss ? "ok hashes " . scalar(@hash) . "\n" : "bad hashes (" . scalar(@miss) . " of " . scalar(@hash) . " missing)\n";
        print $body eq $pt ? "ok equal\n" : "bad equal\n";
        my ($lib) = grep { $g[$_] =~ /^function Initialize-Logging\b/ } 0 .. $#g;
        my ($use) = grep { $g[$_] =~ /^function Invoke-PywinptySetup\b/ } 0 .. $#g;
        print((defined $lib && defined $use && $lib < $open[0] && $open[0] < $use) ? "ok order\n" : "bad order\n");
        print((grep { /^\s*\.\s.*aitools-lib\.ps1/ } @g) ? "bad inlined\n" : "ok inlined\n");
    ' "$1" "$2" 2>&1
}

PIN_VER="$(perl -ne 'if (/^\s*pywinpty==([0-9][0-9A-Za-z.]*)/) { print $1; exit }' "$PIN")"
PIN_HASHES="$(perl -ne '$n++ while /--hash=sha256:/g; END { print $n + 0 }' "$PIN")"

setup_dot build
run_build "$ROOT/scripts/build-deploy.sh"
BUILD_SECS="$(cat "$C/secs")"
G="$D/deploy/setup-pywinpty.ps1"
check "build: exit 0 (${BUILD_SECS} s)" "[ \"\$(cat '$C/rc')\" = 0 ]"
check "build: logged 'Embedding the pywinpty pin (pywinpty $PIN_VER, $PIN_HASHES hash(es))'" "grep -qF 'Embedding the pywinpty pin (pywinpty $PIN_VER, $PIN_HASHES hash(es))' '$C/out'"
check "build: deploy/setup-pywinpty.ps1 generated (not the previous build)" "[ -f '$G' ] && ! grep -qx 'previous build' '$G'"
if [ -f "$G" ]; then
    pin_embed_report "$G" "$PIN" > "$C/embed.txt"
else
    printf 'bad no generated file\n' > "$C/embed.txt"
fi
check "build: one line \$AitoolsEmbeddedPywinptyPin = @' opens the pin" "grep -qx 'ok open' '$C/embed.txt'"
check "build: closing '@ line at column 0 (CRLF allowed)" "grep -qx 'ok close' '$C/embed.txt'"
check "build: the pywinpty== line of the pin is embedded" "grep -qx 'ok version' '$C/embed.txt'"
check "build: every --hash=sha256: line of the pin is embedded ($PIN_HASHES)" "grep -qx 'ok hashes $PIN_HASHES' '$C/embed.txt'"
check "build: embedded text equals scripts/requirements-pywinpty.txt (line endings normalized)" "grep -qx 'ok equal' '$C/embed.txt'"
check "build: pin sits after the inlined library, before the setup logic" "grep -qx 'ok order' '$C/embed.txt'"
check "build: library inlined (no dot-source of aitools-lib.ps1)" "grep -qx 'ok inlined' '$C/embed.txt'"
check "build: deploy/setup-pywinpty.sh generated, bash -n passes" "[ -f '$D/deploy/setup-pywinpty.sh' ] && '$TB' -n '$D/deploy/setup-pywinpty.sh'"
if [ -n "$REAL_PWSH" ]; then
    printf '%s\n' \
        'param([string]$Path)' \
        '$e = $null' \
        '$null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$e)' \
        'if ($e) { $e | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }; exit 1 }' \
        'exit 0' > "$TMP_ROOT/parse.ps1"
    check "build: deploy/setup-pywinpty.ps1 parses (pwsh)" "[ -f '$G' ] && '$REAL_PWSH' -NoProfile -NonInteractive -File '$(native_path "$TMP_ROOT/parse.ps1")' '$(native_path "$G")' > '$C/parse.out' 2>&1"
elif [ "${CI:-}" = "true" ]; then
    check "build: deploy/setup-pywinpty.ps1 parses (pwsh not on PATH under CI)" "false"
else
    skip "build: deploy/setup-pywinpty.ps1 parses" "pwsh is not on PATH"
fi

# MDM copy of the .sh, run where it is meant to run
if [ "$TEST_PLATFORM" = windows ]; then
    skip "mdm: deploy/setup-pywinpty.sh (plain, --dry-run)" "POSIX-guarded: refuses Windows (exit 1), covered by tests/os-guards"
elif [ -f "$D/deploy/setup-pywinpty.sh" ]; then
    MDM_SH="$TMP_ROOT/mdm-bin/setup-pywinpty.sh"
    mkdir -p "$TMP_ROOT/mdm-bin"
    cp "$D/deploy/setup-pywinpty.sh" "$MDM_SH"
    run_sh mdm-plain "$MDM_SH"
    na_checks "mdm plain" no
    run_sh mdm-dryrun "$MDM_SH" --dry-run
    na_checks "mdm --dry-run" yes
else
    check "mdm: deploy/setup-pywinpty.sh generated" "false"
fi

# --- Broken pins: the build fails, deploy/ unchanged ---------------------------

COPY="$TMP_ROOT/repo-copy"
mkdir -p "$COPY"
C="$TMP_ROOT/copy"
mkdir -p "$C"
if git -C "$ROOT" ls-files -z > "$TMP_ROOT/files.z" && perl -MFile::Copy=copy -MFile::Path=make_path -MFile::Basename=dirname -e '
    my ($src, $dst, $list) = @ARGV;
    open my $l, "<", $list or die "cannot read $list: $!\n";
    local $/ = "\0";
    my $n = 0;
    while (my $f = <$l>) {
        chomp $f;
        next unless length $f && -f "$src/$f";   # a tracked file deleted in the work tree is skipped
        make_path(dirname("$dst/$f"));
        copy("$src/$f", "$dst/$f") or die "copy $f: $!\n";
        $n++;
    }
    die "no files copied\n" unless $n;
' "$ROOT" "$COPY" "$TMP_ROOT/files.z" > "$C/out" 2>&1; then
    COPY_OK=yes
else
    COPY_OK=no
fi
check "pin: temp copy of the tracked files made" "[ '$COPY_OK' = yes ] && [ -f '$COPY/scripts/build-deploy.sh' ]"

# pin_case <case> <expected error text> <perl program that turns the real pin
# (stdin) into the broken one (stdout), or "MISSING">
pin_case() {
    local name="$1" want="$2" prog="$3"
    setup_dot "pin-$name"
    if [ "$prog" = MISSING ]; then
        rm -f "$COPY/scripts/requirements-pywinpty.txt"
    else
        perl -e "$prog" < "$PIN" > "$COPY/scripts/requirements-pywinpty.txt"
    fi
    run_build "$COPY/scripts/build-deploy.sh"
    check "pin $name: build exit 1 ($(cat "$C/secs") s)" "[ \"\$(cat '$C/rc')\" = 1 ]"
    check "pin $name: error 'Cannot embed the pywinpty pin: ... $want'" "grep -F 'Cannot embed the pywinpty pin: ' '$C/out' | grep -qF -- \"$want\""
    check "pin $name: fixture deploy/ unchanged" "diff -r '$C/pristine' '$D/deploy' > /dev/null"
}

if [ "$COPY_OK" = yes ]; then
    pin_case missing "requirements-pywinpty.txt: cannot read" MISSING
    pin_case empty "requirements-pywinpty.txt is empty" 'local $/; <STDIN>;'
    pin_case no-version "has no pywinpty== line" 'while (<STDIN>) { s/^(\s*)pywinpty==/${1}winpty==/; print }'
    pin_case terminator "has a line starting with '@ (it would end the here-string)" 'print while <STDIN>; print chr(39) . "@\n";'
    pin_case no-wheel-tags "has no # wheel-tags: line" 'while (<STDIN>) { print unless /^\s*#\s*wheel-tags:/ }'
    pin_case no-hashes "has no --hash=sha256: entries" 'while (<STDIN>) { next if /--hash=sha256:/; s/\s*\\\s*$/\n/ if /pywinpty==/; print }'
else
    skip "pin: broken-pin builds" "the temp copy of the tracked files failed (see the FAIL above)"
fi

printf '\n%d passed, %d failed, %d skipped (%s, bash %s, %d s)\n' \
    "$PASS" "$FAIL" "$SKIP" "$TEST_PLATFORM" "$("$TB" -c 'echo $BASH_VERSION')" "$(( $(date +%s) - SUITE_START ))"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
