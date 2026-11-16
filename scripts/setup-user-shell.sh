#!/usr/bin/env bash
# setup-user-shell.sh -- Owns the aitools lines in the login profile and the shell rc files (macOS/Linux)
# Safe to re-run -- idempotent: a profile whose block is current is not rewritten.
# Platform: macOS/Linux (OS guard). Twin: setup-user-shell.ps1 (Windows).
# Tool context: /tool-registry skill; design: reference/ait-shellintegration.md.
#
# 1. PATH block. The harness must resolve managed tools (uv python shims,
#    cursor-agent, brew bash 5.x) deterministically. This script writes a marked block
#      # >>> aitools managed >>>  ...  # <<< aitools managed <<<
#    at the END of the bash LOGIN profile (~/.bash_profile). Placed last, the block
#    re-asserts PATH precedence: brew shellenv (homebrew) then prepend ~/.local/bin,
#    so the managed copies win over any earlier installer prepends (grok, antigravity)
#    without rewriting the user's own lines.
#    Resulting precedence (decision #6):
#      ~/.local/bin -> /opt/homebrew/bin -> grok/antigravity -> system
#
# 2. Shell integration. The interactive rc files get the aliases source line:
#      # aitools shell integration
#      source "<aitools clone>/shared/shell/aliases.sh"
#    in ~/.bashrc (created if absent) and ~/.zshrc (only if it exists): appended
#    when the marker line is missing, left alone when present; the legacy
#    "# ai-tooling shell integration" pair is removed. (aitools-install.sh Step 7
#    wrote these lines itself until incident #173; it now only runs this script.)
#    The rc format is kept as it was: it never had the duplication bugs of the
#    Windows profile, and a format change would need a migration with no test
#    platform at hand. The aliases file is absent from the MDM deploy/ copy: then
#    no rc file is touched (WARN row).
#
# Owns:      the PATH block lines and our marker lines in ~/.bash_profile; the two
#            integration lines in the rc files.
# Preserves: every other line, byte for byte.
# Overwrites: no (rewrites only our lines; each file is backed up first).
#
# Repair (incident #172 parity with the .ps1): duplicate PATH blocks collapse to
# one at the first block's position; a marker line with no partner is removed.
# Damage this script does not guess at -- the profile fails `bash -n` (the bash
# that runs this script; a syntax error in ~/.bash_profile prints an error on every
# login shell, so the check is meaningful; it reports only the first error, so
# "parses worse" means "passed before, fails after"), or stray lines of our block
# outside the markers (a line containing "_aitoolsLocalBin" or "Owned by aitools
# (scripts/setup-user-shell.", the same set as the .ps1) -- is left in place and
# reported as WARN + ACTION naming the newest clean "<profile>.bak.<UTC>" backup
# (at most one block, passes `bash -n`, no stray lines), or "repair by hand". A
# write that would make the profile fail `bash -n` is refused (ERROR).
#
# Testing: AITOOLS_PROFILE_DIR targets profiles in a scratch dir instead of
# $HOME (the login profile and the rc files); AITOOLS_ALIASES_PATH overrides the
# aliases.sh path (a missing file exercises the MDM path).
#
# See plans/tooling-resolution-and-artifact-registry.md (Workstream A).

set -euo pipefail

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-user-shell"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

SHELL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Targets (overridable for testing) ---
PROFILE_DIR="${AITOOLS_PROFILE_DIR:-$HOME}"
PROFILE="$PROFILE_DIR/.bash_profile"
ALIASES_PATH="${AITOOLS_ALIASES_PATH:-$SHELL_SCRIPT_DIR/../shared/shell/aliases.sh}"

TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
BLOCK_FILE="$TMP_DIR/block"
NEW_FILE="$TMP_DIR/new-profile"
PERL_FILE="$TMP_DIR/shell-blocks.pl"

# --- The managed block (identical across Macs; arch detected at runtime) ---
# Go's bin directory is added with no existence check: it does not exist until
# the first `go install`, a PATH entry for a missing directory is harmless, and
# the line names the directory setup-go.sh checks, ${GOPATH:-$HOME/go}/bin
# (nobul-tech/aitools#185).
cat > "$BLOCK_FILE" <<'BLOCK'
# >>> aitools managed >>>
# Owned by aitools (scripts/setup-user-shell.sh). Placed last so it re-asserts
# PATH precedence for harness-managed tools. Edit via the script, not by hand.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi
export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.cargo/bin" ] && export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:${GOPATH:-$HOME/go}/bin"
# <<< aitools managed <<<
BLOCK

# --- Block surgery in Perl (USO: perl for non-trivial string manipulation) ---
# Line-based, same rules as the .ps1: a block runs from a start marker line to the
# first end marker line after it; a line's key is the line trimmed.
#   splice IN BLOCK OUT  first block replaced by BLOCK, later blocks and stray
#                        marker lines dropped, BLOCK appended when there is none;
#                        prints DETAIL: lines, BLOCKS= ORPHANS= UNCHANGED= STRAY=
#   check FILE           prints STRAY= PS= PE= IS= IE= (marker line counts)
#   oneblock FILE        exit 0 when exactly one start and one end line, start first
cat > "$PERL_FILE" <<'PERL'
use strict; use warnings;
my ($mode, @arg) = @ARGV;
my $PS = "# >>> aitools managed >>>";
my $PE = "# <<< aitools managed <<<";
my $IS = "# >>> aitools shell integration >>>";
my $IE = "# <<< aitools shell integration <<<";
my @TOKENS = ("_aitoolsLocalBin", "Owned by aitools (scripts/setup-user-shell.");
sub slurp { my $f = shift; return "" unless -f $f; open my $h, "<:raw", $f or die "read $f: $!\n"; local $/; my $c = <$h>; close $h; return defined $c ? $c : ""; }
sub lines { my $t = shift; return () unless length $t; return split /(?<=\n)/, $t; }
sub key { my $l = shift; $l =~ s/^\s+//; $l =~ s/\s+\z//; return $l; }
sub count { my ($t, $m) = @_; my $n = 0; for (lines($t)) { $n++ if key($_) eq $m; } return $n; }
sub stray {
    my $t = shift; my $n = 0; my $close;
    for my $l (lines($t)) {
        my $k = key($l);
        if (defined $close) { undef $close if $k eq $close; next; }
        if ($k eq $PS) { $close = $PE; next; }
        if ($k eq $IS) { $close = $IE; next; }
        my $s = ($k eq $PE || $k eq $IE) ? 1 : 0;
        for my $tok (@TOKENS) { $s = 1 if index($l, $tok) >= 0; }
        $n++ if $s;
    }
    return $n;
}
if ($mode eq "splice") {
    my ($in, $bf, $out) = @arg;
    my $block = slurp($bf);
    my @l = lines(slurp($in));
    my @o; my ($blocks, $orph, $old) = (0, 0, undef);
    my $i = 0;
    while ($i < @l) {
        my $k = key($l[$i]);
        if ($k eq $PS) {
            my $j = $i + 1;
            $j++ while ($j < @l && key($l[$j]) ne $PE);
            if ($j < @l) {
                $blocks++;
                if ($blocks == 1) { $old = join("", @l[$i .. $j]); push @o, $block; }
                else { printf "DETAIL: removed duplicate block (profile lines %d-%d)\n", $i + 1, $j + 1; }
                $i = $j + 1; next;
            }
            $orph++; printf "DETAIL: removed stray marker line %d: %s\n", $i + 1, $k; $i++; next;
        }
        if ($k eq $PE) { $orph++; printf "DETAIL: removed stray marker line %d: %s\n", $i + 1, $k; $i++; next; }
        push @o, $l[$i]; $i++;
    }
    if ($blocks == 0) { $o[-1] .= "\n" if (@o && $o[-1] !~ /\n\z/); push @o, $block; }
    my $new = join("", @o);
    open my $h, ">:raw", $out or die "write $out: $!\n"; print $h $new; close $h or die "close $out: $!\n";
    my $unch = ($blocks == 1 && $orph == 0 && defined $old && $old eq $block) ? 1 : 0;
    print "BLOCKS=$blocks\nORPHANS=$orph\nUNCHANGED=$unch\nSTRAY=", stray($new), "\n";
} elsif ($mode eq "check") {
    my $t = slurp($arg[0]);
    print "STRAY=", stray($t), "\nPS=", count($t, $PS), "\nPE=", count($t, $PE), "\nIS=", count($t, $IS), "\nIE=", count($t, $IE), "\n";
} elsif ($mode eq "oneblock") {
    my @s; my @e; my $n = 0;
    for (lines(slurp($arg[0]))) { my $k = key($_); push @s, $n if $k eq $PS; push @e, $n if $k eq $PE; $n++; }
    exit((@s == 1 && @e == 1 && $s[0] < $e[0]) ? 0 : 1);
} else { die "unknown mode $mode\n"; }
PERL

# bash_n FILE: 0 when FILE passes `bash -n`; its first error goes to the log.
# The output and exit code of the last failing check stay in BASH_N_OUT and
# BASH_N_RC (the reason of the parse-check error below).
BASH_N_OUT=""
BASH_N_RC=0
bash_n() {
    local out rc=0
    out=$("${BASH:-bash}" -n "$1" 2>&1) || rc=$?
    if [ "$rc" -eq 0 ]; then BASH_N_OUT=""; BASH_N_RC=0; return 0; fi
    BASH_N_OUT="$out"
    BASH_N_RC=$rc
    log_detail "bash -n $(display_path "$1"): $out"
    return 1
}

# value_of KEY TEXT: the value of a KEY=VALUE line in TEXT ("" when absent).
value_of() { printf '%s\n' "$2" | perl -ne 'print $1 if /^\Q'"$1"'\E=(.*)$/'; }

# --- Backups that exist before this run (the one this run takes is of the
# --- current, possibly damaged file and is never a restore candidate) ---
BACKUPS_BEFORE=""
for f in "$PROFILE".bak.*; do
    [ -f "$f" ] || continue
    BACKUPS_BEFORE="$BACKUPS_BEFORE$f
"
done

# find_clean_backup: newest backup (names sort by timestamp) with at most one
# block of each kind, passing bash -n, no stray lines; prints its path or "".
find_clean_backup() {
    local b chk
    while IFS= read -r b; do
        [ -n "$b" ] || continue
        if ! chk=$(perl "$PERL_FILE" check "$b"); then log_detail "backup unreadable: $b"; continue; fi
        [ "$(value_of PS "$chk")" -le 1 ] || continue
        [ "$(value_of PS "$chk")" = "$(value_of PE "$chk")" ] || continue
        [ "$(value_of IS "$chk")" -le 1 ] || continue
        [ "$(value_of IS "$chk")" = "$(value_of IE "$chk")" ] || continue
        [ "$(value_of STRAY "$chk")" = 0 ] || continue
        bash_n "$b" || continue
        printf '%s' "$b"
        return 0
    done <<EOF
$(printf '%s' "$BACKUPS_BEFORE" | sort -r)
EOF
    return 0
}

# report_damage FILE: one warning with its ACTION (write_action) when FILE fails
# bash -n or has stray lines.
report_damage() {
    local file="$1" parse_fail=0 stray chk clean rc=0
    # stdout is the KEY=VALUE protocol, so perl's stderr goes to a file
    chk=$(perl "$PERL_FILE" check "$file" 2>"$TMP_DIR/check.err") || rc=$?
    if [ "$rc" -ne 0 ]; then
        write_error "shell" "cannot read $(display_path "$file") for the damage check" "$(error_reason "$(<"$TMP_DIR/check.err")" "$rc")"
        return 0
    fi
    stray=$(value_of STRAY "$chk")
    bash_n "$file" || parse_fail=1
    if [ "$parse_fail" -eq 0 ] && [ "$stray" = 0 ]; then return 0; fi
    # write_action logs only its TEXT: the counts go to a detail line
    log_detail "$(display_path "$PROFILE"): bash -n fails: $parse_fail, $stray stray aitools line(s) outside the block -- left in place, not guessed at"
    clean=$(find_clean_backup)
    if [ -n "$clean" ]; then
        write_action "shell" "profile damage left in place -- restore $(display_path "$PROFILE") from $(display_path "$clean")" \
            "Restore $(display_path "$PROFILE") from $(display_path "$clean")"
    else
        write_action "shell" "profile damage left in place -- repair $(display_path "$PROFILE") by hand (no clean backup)" \
            "Repair $(display_path "$PROFILE") by hand (no clean backup)"
    fi
}

# ============================================================
# 1. PATH block in the login profile
# ============================================================
SPLICE_OUT=""
splice_rc=0
# stdout is the KEY=VALUE protocol, so perl's stderr goes to a file
SPLICE_OUT=$(perl "$PERL_FILE" splice "$PROFILE" "$BLOCK_FILE" "$NEW_FILE" 2>"$TMP_DIR/splice.err") || splice_rc=$?
if [ "$splice_rc" -ne 0 ]; then
    write_error "shell" "cannot compute the managed block for $(display_path "$PROFILE")" "$(error_reason "$(<"$TMP_DIR/splice.err")" "$splice_rc")"
    exit 1
fi
while IFS= read -r line; do
    case "$line" in
        DETAIL:*) log_detail "${line#DETAIL: }" ;;
    esac
done <<< "$SPLICE_OUT"
BLOCKS=$(value_of BLOCKS "$SPLICE_OUT")
UNCHANGED=$(value_of UNCHANGED "$SPLICE_OUT")

# --- Never write a profile that parses worse than the one it replaces ---
PARSE_BEFORE=0
if [ -f "$PROFILE" ] && ! bash_n "$PROFILE"; then PARSE_BEFORE=1; fi
PARSE_AFTER=0
bash_n "$NEW_FILE" || PARSE_AFTER=1
log "Profile $(display_path "$PROFILE"): bash -n fails before: $PARSE_BEFORE, after: $PARSE_AFTER"
if [ "$PARSE_AFTER" -gt "$PARSE_BEFORE" ]; then
    # The new profile was the last bash_n call: BASH_N_OUT holds its error
    # (the file is left unchanged; the exit and report_damage say so). The temp
    # file's path is dropped, so the reason reads "line N: ..." as on the .ps1.
    write_error "shell" "managed block splice failed parse check" "$(error_reason "${BASH_N_OUT//"$NEW_FILE: "/}" "$BASH_N_RC")"
    report_damage "$PROFILE"
    exit 1
fi

# --- Write only when something changed, then validate ---
if [ -f "$PROFILE" ] && cmp -s "$PROFILE" "$NEW_FILE"; then
    log "Profile unchanged: $(display_path "$PROFILE")"
else
    w_rc=0
    w_out=$(mkdir -p "$PROFILE_DIR" 2>&1) || w_rc=$?
    if [ "$w_rc" -ne 0 ]; then
        write_error "shell" "profile directory not created" "$(error_reason "$w_out" "$w_rc")"
        exit 1
    fi
    backup_file "$PROFILE"
    w_out=$(cp "$NEW_FILE" "$PROFILE" 2>&1) || w_rc=$?
    if [ "$w_rc" -ne 0 ]; then
        write_error "shell" "managed block write failed" "$(error_reason "$w_out" "$w_rc")"
        exit 1
    fi
    if ! cmp -s "$PROFILE" "$NEW_FILE"; then
        write_error "shell" "profile check after write failed" "the written file differs from the computed profile"
        exit 1
    elif ! perl "$PERL_FILE" oneblock "$PROFILE"; then
        write_error "shell" "managed block markers missing" "not exactly one managed block in $(display_path "$PROFILE")"
        exit 1
    fi
    log_ok "Wrote $(display_path "$PROFILE")"
fi

# The OK status records; each warning and error is its own record
# (reference/logging.md 8.3), so their order changes no colour.
if [ "$BLOCKS" -eq 0 ]; then
    log_ok "Added managed block to $(display_path "$PROFILE")"
    write_summary OK "shell" "managed block added"
elif [ "$BLOCKS" -gt 1 ]; then
    log_ok "Collapsed $BLOCKS managed blocks to 1 in $(display_path "$PROFILE")"
    write_summary OK "shell" "collapsed $BLOCKS blocks to 1"
elif [ "$UNCHANGED" = 1 ]; then
    log "Managed block unchanged in $(display_path "$PROFILE")"
    write_summary OK "shell" "managed block unchanged"
else
    log_ok "Refreshed managed block in $(display_path "$PROFILE")"
    write_summary OK "shell" "managed block refreshed"
fi

# ============================================================
# 2. Shell integration in the interactive rc files
# ============================================================
OLD_MARKER="# ai-tooling shell integration"
MARKER="# aitools shell integration"
ALIASES_FOUND=0
if [ -f "$ALIASES_PATH" ]; then
    ALIASES_FOUND=1
    ALIASES_ABS="$(cd "$(dirname "$ALIASES_PATH")" && pwd)/$(basename "$ALIASES_PATH")"
    INTEG_ADDED=0
    INTEG_MIGRATED=0
    INTEG_FAILED=0
    for rcfile in "$PROFILE_DIR/.bashrc" "$PROFILE_DIR/.zshrc"; do
        # .bashrc is created when absent; .zshrc only when it exists.
        if [ "$rcfile" != "$PROFILE_DIR/.bashrc" ] && [ ! -f "$rcfile" ]; then continue; fi
        # One backup per file and run, taken before its first change (a second
        # backup in the same second would overwrite the first under the same name).
        RC_BACKED_UP=0
        if [ -f "$rcfile" ] && grep -qF "$OLD_MARKER" "$rcfile"; then
            backup_file "$rcfile"
            RC_BACKED_UP=1
            rc_rc=0
            rc_out=$(perl -i -0777 -pe 's/\n?# ai-tooling shell integration\nsource "[^\n]*"\n?//g' "$rcfile" 2>&1) || rc_rc=$?
            if [ "$rc_rc" -eq 0 ]; then
                log "Removed old shell integration marker from $(display_path "$rcfile")"
                INTEG_MIGRATED=1
            else
                write_error "shell" "cannot remove the legacy integration lines from $(display_path "$rcfile")" "$(error_reason "$rc_out" "$rc_rc")"
                INTEG_FAILED=1
                continue
            fi
        fi
        if [ -f "$rcfile" ] && grep -qF "$MARKER" "$rcfile"; then
            log "Shell integration already in $(display_path "$rcfile")"
            continue
        fi
        if [ "$RC_BACKED_UP" -eq 0 ]; then backup_file "$rcfile"; fi
        rc_rc=0
        # The redirect's own error (a read-only file) goes to append.err
        { printf '\n%s\nsource "%s"\n' "$MARKER" "$ALIASES_ABS" >> "$rcfile"; } 2>"$TMP_DIR/append.err" || rc_rc=$?
        if [ "$rc_rc" -ne 0 ]; then
            # The shell's "<script>: line N: " prefix is dropped: "<file>: <error>"
            rc_out=$(error_reason "$(<"$TMP_DIR/append.err")" "$rc_rc")
            write_error "shell" "cannot add shell integration to $(display_path "$rcfile")" "${rc_out#*: line *: }"
            INTEG_FAILED=1
        elif ! grep -qF "$MARKER" "$rcfile"; then
            write_error "shell" "cannot add shell integration to $(display_path "$rcfile")" "marker line not found after the append"
            INTEG_FAILED=1
        else
            log_ok "Added shell integration to $(display_path "$rcfile")"
            INTEG_ADDED=1
        fi
    done
    # Each failed rc file is its own error above; the OK status only when none failed
    if [ "$INTEG_FAILED" -eq 0 ]; then
        if [ "$INTEG_MIGRATED" -eq 1 ]; then
            write_summary OK "shell" "legacy integration migrated"
        elif [ "$INTEG_ADDED" -eq 1 ]; then
            write_summary OK "shell" "integration added"
        else
            write_summary OK "shell" "integration unchanged"
        fi
    fi
fi

# ============================================================
# 3. Warnings
# ============================================================
if [ "$ALIASES_FOUND" -eq 0 ]; then
    write_warn "shell" "aliases.sh not found ($(display_path "$ALIASES_PATH")) -- shell integration skipped (MDM deploy)"
fi

report_damage "$PROFILE"

# --- Advisory: zsh-only constructs in a bash login profile error on every login ---
# (e.g. grok's installer copies `autoload -Uz compinit` -- a zsh builtin -- which
# bash cannot run.) Warn but do not auto-remove; line surgery on user content
# beyond the managed block is out of scope for this script.
if [ -f "$PROFILE" ] && grep -qE '(^|[[:space:]])(autoload|compinit)([[:space:]]|$)' "$PROFILE"; then
    write_action "shell" "zsh-only lines (autoload/compinit) in $(display_path "$PROFILE") error under bash -- remove them" \
        "Remove autoload/compinit from .bash_profile (zsh-only)"
fi

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    log "COMPLETED successfully" "ok"
    exit 0
fi
