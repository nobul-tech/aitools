#!/usr/bin/env bash
# aitools-profile.sh -- the one resolver for "where is my dotprofile" and
# "which machine profile is this machine" (macOS/Linux; on Windows use
# aitools-profile.ps1, which implements the same commands, options and output).
#
# Intent: Resolve, deterministically and with a stated reason ("via"), the
# dotprofile repo path and this machine's profile in profile.json, and derive
# the config.json values that come from them. NOT a writer of config.json
# (setup-user-config.sh/.ps1 is the only writer). NOT a writer of profile.json
# except the `register` subcommand, which writes to a temp file the caller
# validates, backs up and moves. NOT the settings.json sync (sync_managed_json).
# Consumed by: the bash shared-lib wrappers resolve_user_repo_path /
# resolve_machine_profile, setup-user-config.sh, build-deploy.sh (on macOS/Linux;
# under Git Bash on Windows it uses the AITOOLS_USER_REPO_PATH the entry point
# exports), aitools `user init`, and the generated deploy/setup-user-claude.sh
# (embedded copy).
#
# Usage: aitools-profile.sh <command> [options]   (--help for details)
# Exit codes: 0 resolved / ok; 1 nothing found (expected states, e.g. before
#   `aitools user init`); 2 error (bad input, unreadable or invalid JSON,
#   ambiguous match). Callers must not pass 2 through as their own exit code:
#   exit 2 from a setup script means a user abort (D-TS13).
# Output: data on stdout only -- key<TAB>value lines (default) or one JSON
#   object (--json). Diagnostics go to deploy.log (detail lines) and stderr.
# JSON engine: the embedded perl program below (core perl only, no modules).
#   It keeps key order and writes the node JSON.stringify(v, null, 2) layout, so
#   bash, PowerShell (ConvertTo-Json) and node writers produce the same bytes for
#   strings, integers, booleans and null (what profile.json holds). Other number
#   literals are kept verbatim here and re-formatted by PowerShell and node; a
#   lone UTF-16 surrogate escape is written differently by each engine.
# Safe to re-run: every command except `register` is read-only; `register`
#   writes only the --out file.
# Platform: macOS/Linux. Reference: reference/user-repo.md "Resolution".
# Decisions: P-Q2 (raw machine ids), P-Q3 (native bash + PowerShell, no node),
#   P-Q5 (macOS hostname = `scutil --get LocalHostName` only).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/aitools-lib.sh"
# stdout carries data: console log lines go to stderr (deploy.log unchanged).
# Defined before logging_init, whose environment check may already log a warning.
log() {
    local level="${2:-info}"
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local line="[$ts] [$SCRIPT_NAME] [$level] $1"
    printf '%s\n' "$line" >> "$LOG_FILE"
    printf '%s\n' "$line" >&2
}
logging_init "aitools-profile"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use aitools-profile.ps1."
        exit 2 ;;
esac

usage() {
    cat <<'EOF'
aitools-profile.sh -- dotprofile and machine-profile resolver (macOS/Linux)

Commands:
  user-repo-path  Which dotprofile. Options: --config F, --github-user U,
                  --user-repo-path P, --repos-path P, --plain (path only)
  machine-id      Print this machine's stable id (macOS IOPlatformUUID,
                  Linux /etc/machine-id); stored raw in profile.json
  hostname        Print this machine's name (macOS: scutil --get LocalHostName;
                  Linux: uname -n, short form)
  resolve         Which profile this machine uses and why.
                  Options: --config F, --profile F, --alias A, --environment E
  derive-config   The config.json values derived from profile.json.
                  Options: --config F, --github-user U, --user-repo-path P,
                  --repos-path P, --alias A, --environment E
  snapshot        Compact JSON of version, identity, cursor, profiles from
                  --profile F (for embedding in generated deploy scripts)
  register        Write --profile F with this machine registered under --alias A
                  to --out TMP. Options: --name N, --company C, --shell S,
                  --environment E, --create (new profile.json; with
                  --github-user U, --email E)

Output: key<TAB>value lines; --json prints one JSON object instead.
Environment: AITOOLS_USER_REPO_PATH, AITOOLS_MACHINE_ALIAS, AITOOLS_PROFILE_FILE,
  AITOOLS_ENVIRONMENT (see reference/user-repo.md "Resolution").
Test options: --machine-id-value ID, --hostname-value NAME (replace detection).
Exit: 0 ok, 1 not found, 2 error.
EOF
}

# ---------------------------------------------------------------------------
# JSON engine (perl). Commands, all paths given as separate key segments:
#   check FILE              0 valid object, 1 missing, 2 invalid (stderr)
#   get FILE SEG...         print the scalar; 1 absent or null, 3 not a scalar
#   type FILE SEG...        object|array|string|number|boolean; 1 absent/null
#   keys FILE SEG...        object keys, one per line; 1 absent, 3 not an object
#   items FILE SEG...       array scalar items, one per line; 1 absent, 3 not an array
#   json FILE SEG...        compact JSON of the value; 1 absent
#   edit IN OUT             apply stdin ops to IN ("-" = {}), write OUT pretty,
#                           re-read OUT to validate. Ops (tab-separated):
#                           set<TAB>string|number|bool|null|json<TAB>VALUE<TAB>SEG...
#                           del<TAB>SEG...
#   snapshot FILE           compact {version, identity, cursor, profiles}
#   tagged2json             key<TAB>value lines on stdin -> one compact object
#                           (warn/error lines collected into warnings/errors)
# For get/type/keys/items/json: 4 = FILE missing, 2 = FILE invalid.
# ---------------------------------------------------------------------------
# read -d '' returns 1 at the end of input by design; the -n check below is the result check
read -r -d '' _PJ <<'PERL' || true
use strict;
use warnings;
my $T;
sub perr { my $p = pos($T); die 'invalid JSON at byte ' . (defined $p ? $p : 0) . ': ' . $_[0] . "\n" }
sub ws { $T =~ /\G[ \t\r\n]*/gc; return }
sub u8 { my $ch = chr($_[0]); { no warnings; utf8::encode($ch); } return $ch }
sub pstr {
    my $s = '';
    while (1) {
        if ($T =~ /\G([^"\\\x00-\x1f]+)/gc) { $s .= $1; next }
        return $s if $T =~ /\G"/gc;
        if ($T =~ /\G\\(["\\\/bfnrt])/gc) {
            my %m = ('"' => '"', '\\' => '\\', '/' => '/', b => "\b", f => "\f", n => "\n", r => "\r", t => "\t");
            $s .= $m{$1}; next;
        }
        if ($T =~ /\G\\u([0-9a-fA-F]{4})/gc) {
            my $c = hex $1;
            if ($c >= 0xD800 && $c <= 0xDBFF && $T =~ /\G\\u([dD][c-fC-F][0-9a-fA-F]{2})/gc) {
                $c = 0x10000 + (($c - 0xD800) << 10) + (hex($1) - 0xDC00);
            }
            $s .= u8($c); next;
        }
        perr('invalid string');
    }
}
# Numbers keep their source lexeme byte for byte: re-formatting through perl's
# %.15g would silently change 16-17 digit values in a file this engine rewrites.
sub numnorm { return $_[0] }
sub pval {
    ws();
    if ($T =~ /\G\{/gc) {
        my @kv;
        ws();
        return ['O', \@kv] if $T =~ /\G\}/gc;
        while (1) {
            ws();
            $T =~ /\G"/gc or perr('expected a string key');
            my $k = pstr();
            ws();
            $T =~ /\G:/gc or perr('expected ":"');
            my $v = pval();
            my $done = 0;
            for my $p (@kv) { if ($p->[0] eq $k) { $p->[1] = $v; $done = 1; last } }
            push @kv, [$k, $v] unless $done;
            ws();
            next if $T =~ /\G,/gc;
            return ['O', \@kv] if $T =~ /\G\}/gc;
            perr('expected "," or "}"');
        }
    }
    if ($T =~ /\G\[/gc) {
        my @a;
        ws();
        return ['A', \@a] if $T =~ /\G\]/gc;
        while (1) {
            push @a, pval();
            ws();
            next if $T =~ /\G,/gc;
            return ['A', \@a] if $T =~ /\G\]/gc;
            perr('expected "," or "]"');
        }
    }
    return ['S', pstr()] if $T =~ /\G"/gc;
    return ['N', numnorm($1)] if $T =~ /\G(-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)/gc;
    return ['T'] if $T =~ /\Gtrue/gc;
    return ['F'] if $T =~ /\Gfalse/gc;
    return ['Z'] if $T =~ /\Gnull/gc;
    perr('unexpected character');
}
sub parse_text {
    my ($text, $what) = @_;
    $T = $text;
    $T =~ s/\A\xEF\xBB\xBF//;
    pos($T) = 0;
    my $v = eval { my $x = pval(); ws(); perr('trailing characters') if pos($T) < length($T); $x };
    if (!$v) { my $e = $@; chomp $e; return (undef, "$what is invalid JSON: $e") }
    return ($v, undef);
}
sub load {
    my ($f) = @_;
    my $fh;
    if (!open($fh, '<:raw', $f)) { return (undef, $!{ENOENT} ? 'missing' : "cannot read $f: $!") }
    local $/;
    my $text = <$fh>;
    close $fh;
    $text = '' unless defined $text;
    my ($v, $e) = parse_text($text, $f);
    return (undef, $e) unless $v;
    return (undef, "$f: top level is not an object") unless $v->[0] eq 'O';
    return ($v, undef);
}
sub estr {
    my $s = shift;
    $s =~ s/(["\\])/\\$1/g;
    $s =~ s/\x08/\\b/g; $s =~ s/\x0c/\\f/g; $s =~ s/\n/\\n/g; $s =~ s/\r/\\r/g; $s =~ s/\t/\\t/g;
    $s =~ s/([\x00-\x1f])/sprintf('\\u%04x', ord $1)/ge;
    return '"' . $s . '"';
}
sub enc {
    my ($v, $ind, $pretty) = @_;
    my $t = $v->[0];
    return estr($v->[1]) if $t eq 'S';
    return $v->[1] if $t eq 'N';
    return 'true' if $t eq 'T';
    return 'false' if $t eq 'F';
    return 'null' if $t eq 'Z';
    my $nl = $pretty ? "\n" : '';
    my $in1 = $pretty ? ('  ' x ($ind + 1)) : '';
    my $in0 = $pretty ? ('  ' x $ind) : '';
    my @p = @{$v->[1]};
    if ($t eq 'O') {
        return '{}' unless @p;
        my $sep = $pretty ? ': ' : ':';
        return '{' . $nl . join(',' . $nl, map { $in1 . estr($_->[0]) . $sep . enc($_->[1], $ind + 1, $pretty) } @p) . $nl . $in0 . '}';
    }
    return '[]' unless @p;
    return '[' . $nl . join(',' . $nl, map { $in1 . enc($_, $ind + 1, $pretty) } @p) . $nl . $in0 . ']';
}
sub nav {
    my ($v, @segs) = @_;
    for my $s (@segs) {
        return undef unless $v->[0] eq 'O';
        my $n;
        for my $p (@{$v->[1]}) { if ($p->[0] eq $s) { $n = $p->[1]; last } }
        return undef unless defined $n;
        $v = $n;
    }
    return $v;
}
sub setp {
    my ($root, $val, @segs) = @_;
    die "set: no key given\n" unless @segs;
    my $last = pop @segs;
    my $v = $root;
    for my $s (@segs) {
        my $n;
        for my $p (@{$v->[1]}) { if ($p->[0] eq $s) { $n = $p; last } }
        if (!$n) { $n = [$s, ['O', []]]; push @{$v->[1]}, $n }
        die "set: '$s' is not an object\n" unless $n->[1][0] eq 'O';
        $v = $n->[1];
    }
    for my $p (@{$v->[1]}) { if ($p->[0] eq $last) { $p->[1] = $val; return } }
    push @{$v->[1]}, [$last, $val];
}
sub delp {
    my ($root, @segs) = @_;
    my $last = pop @segs;
    my $v = nav($root, @segs);
    return unless $v && $v->[0] eq 'O';
    $v->[1] = [grep { $_->[0] ne $last } @{$v->[1]}];
}
sub typed {
    my ($type, $value) = @_;
    return ['S', $value] if $type eq 'string';
    if ($type eq 'number') { die "set: '$value' is not a number\n" unless $value =~ /^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$/; return ['N', numnorm($value)] }
    if ($type eq 'bool') { return ['T'] if $value eq 'true'; return ['F'] if $value eq 'false'; die "set: '$value' is not true or false\n" }
    return ['Z'] if $type eq 'null';
    if ($type eq 'json') { my ($v, $e) = parse_text($value, 'value'); die "set: $e\n" unless $v; return $v }
    die "set: unknown type '$type'\n";
}
sub tname { my %n = (O => 'object', A => 'array', S => 'string', N => 'number', T => 'boolean', F => 'boolean'); return $n{$_[0]->[0]} }
sub need { my ($f) = @_; my ($v, $e) = load($f); if (!$v) { exit 4 if $e eq 'missing'; print STDERR "$e\n"; exit 2 } return $v }

my $cmd = shift(@ARGV);
$cmd = '' unless defined $cmd;
if ($cmd eq 'check') {
    my ($v, $e) = load($ARGV[0]);
    exit 0 if $v;
    exit 1 if $e eq 'missing';
    print STDERR "$e\n";
    exit 2;
}
if ($cmd eq 'get' || $cmd eq 'type' || $cmd eq 'keys' || $cmd eq 'items' || $cmd eq 'json') {
    my $f = shift(@ARGV);
    my $x = nav(need($f), @ARGV);
    exit 1 if !defined $x || ($x->[0] eq 'Z' && $cmd ne 'json');
    if ($cmd eq 'json') { print enc($x, 0, 0); exit 0 }
    if ($cmd eq 'type') { print tname($x); exit 0 }
    if ($cmd eq 'get') {
        exit 3 if $x->[0] eq 'O' || $x->[0] eq 'A';
        print $x->[0] eq 'T' ? 'true' : $x->[0] eq 'F' ? 'false' : $x->[1];
        exit 0;
    }
    if ($cmd eq 'keys') { exit 3 unless $x->[0] eq 'O'; print map { $_->[0] . "\n" } @{$x->[1]}; exit 0 }
    exit 3 unless $x->[0] eq 'A';
    for my $i (@{$x->[1]}) {
        next if $i->[0] eq 'O' || $i->[0] eq 'A' || $i->[0] eq 'Z';
        print(($i->[0] eq 'T' ? 'true' : $i->[0] eq 'F' ? 'false' : $i->[1]) . "\n");
    }
    exit 0;
}
if ($cmd eq 'edit') {
    my ($in, $out) = @ARGV;
    my $root = $in eq '-' ? ['O', []] : need($in);
    my $ok = eval {
        while (my $line = <STDIN>) {
            chomp $line;
            next if $line eq '';
            my @f = split /\t/, $line, -1;
            my $op = shift @f;
            if ($op eq 'set') { my ($type, $value) = splice(@f, 0, 2); setp($root, typed($type, $value), @f) }
            elsif ($op eq 'del') { delp($root, @f) }
            else { die "edit: unknown op '$op'\n" }
        }
        1;
    };
    if (!$ok) { print STDERR $@; exit 2 }
    my $fh;
    if (!open($fh, '>:raw', $out)) { print STDERR "cannot write $out: $!\n"; exit 2 }
    print $fh enc($root, 0, 1) . "\n";
    if (!close($fh)) { print STDERR "cannot write $out: $!\n"; exit 2 }
    my ($v, $e) = load($out);
    if (!$v) { print STDERR "validation failed: $e\n"; exit 2 }
    exit 0;
}
if ($cmd eq 'snapshot') {
    my $p = need($ARGV[0]);
    my @kv;
    for my $k ('version', 'identity', 'cursor', 'profiles') {
        my $x = nav($p, $k);
        push @kv, [$k, defined $x ? $x : ['O', []]];
    }
    print enc(['O', \@kv], 0, 0) . "\n";
    exit 0;
}
if ($cmd eq 'tagged2json') {
    my (@kv, @w, @e);
    while (my $line = <STDIN>) {
        chomp $line;
        next if $line eq '';
        my ($k, $v) = split /\t/, $line, 2;
        $v = '' unless defined $v;
        if ($k eq 'warn') { push @w, ['S', $v] }
        elsif ($k eq 'error') { push @e, ['S', $v] }
        else { push @kv, [$k, ['S', $v]] }
    }
    push @kv, ['warnings', ['A', \@w]], ['errors', ['A', \@e]];
    print enc(['O', \@kv], 0, 0) . "\n";
    exit 0;
}
print STDERR "json engine: unknown command '$cmd'\n";
exit 2;
PERL
if [ -z "$_PJ" ]; then
    printf 'aitools-profile: internal error -- JSON engine program is empty\n' >&2
    exit 2
fi
if ! command -v perl >/dev/null 2>&1; then
    log_detail "perl not found -- aitools-profile cannot read JSON"
    printf 'aitools-profile: perl not found (the harness manages perl; run aitools install)\n' >&2
    exit 2
fi

pj() { perl -e "$_PJ" -- "$@"; }

# jread VAR FILE SEG... -- VAR = the scalar at the path ("" when absent, null or
# not a scalar); JREAD_FOUND=true|false. FILE must already be validated (jcheck);
# any other engine failure is an internal error and exits 2 with a message.
JREAD_FOUND=false
jread() {
    local __var="$1"; shift
    local __v="" __rc=0
    __v=$(pj get "$@") || __rc=$?
    case "$__rc" in
        0) JREAD_FOUND=true ;;
        1|3) JREAD_FOUND=false; __v="" ;;
        *) printf 'aitools-profile: internal error reading %s (engine exit %s)\n' "$1" "$__rc" >&2; exit 2 ;;
    esac
    printf -v "$__var" '%s' "$__v"
}

# jlist VAR KIND FILE SEG... -- VAR = keys (KIND=keys) or array items (KIND=items),
# newline-separated; "" when absent or of another type.
jlist() {
    local __var="$1" __kind="$2"; shift 2
    local __v="" __rc=0
    __v=$(pj "$__kind" "$@") || __rc=$?
    case "$__rc" in
        0) : ;;
        1|3) __v="" ;;
        *) printf 'aitools-profile: internal error listing %s (engine exit %s)\n' "$1" "$__rc" >&2; exit 2 ;;
    esac
    printf -v "$__var" '%s' "$__v"
}

# jtype VAR FILE SEG... -- VAR = object|array|string|number|boolean, or "" when absent/null
jtype() {
    local __var="$1"; shift
    local __v="" __rc=0
    __v=$(pj type "$@") || __rc=$?
    case "$__rc" in
        0) : ;;
        1) __v="" ;;
        *) printf 'aitools-profile: internal error typing %s (engine exit %s)\n' "$1" "$__rc" >&2; exit 2 ;;
    esac
    printf -v "$__var" '%s' "$__v"
}

# jsub VAR FILE SEG... -- VAR = compact JSON of the value at the path, "" when absent
jsub() {
    local __var="$1"; shift
    local __v="" __rc=0
    __v=$(pj json "$@") || __rc=$?
    case "$__rc" in
        0) : ;;
        1) __v="" ;;
        *) printf 'aitools-profile: internal error reading %s (engine exit %s)\n' "$1" "$__rc" >&2; exit 2 ;;
    esac
    printf -v "$__var" '%s' "$__v"
}

# jcheck FILE -- sets JCHECK_STATE=valid|missing|invalid and JCHECK_MSG
jcheck() {
    local rc=0
    JCHECK_MSG=$(pj check "$1" 2>&1) || rc=$?
    case "$rc" in
        0) JCHECK_STATE=valid ;;
        1) JCHECK_STATE=missing ;;
        *) JCHECK_STATE=invalid
           if [ -z "$JCHECK_MSG" ]; then JCHECK_MSG="$1 could not be read (engine exit $rc)"; fi ;;
    esac
}

# ---------------------------------------------------------------------------
# Output: key<TAB>value lines, warnings and errors last
# ---------------------------------------------------------------------------
OUT_LINES=""
WARN_LINES=""
ERR_LINES=""
one_line() { local v="${1-}"; v="${v//[$'\t\r\n']/ }"; printf '%s' "$v"; }
put() { OUT_LINES="${OUT_LINES}${1}"$'\t'"$(one_line "${2-}")"$'\n'; }
add_warn() { WARN_LINES="${WARN_LINES}$(one_line "$1")"$'\n'; }
add_err() { ERR_LINES="${ERR_LINES}$(one_line "$1")"$'\n'; }
finish() {
    local code="$1" all="$OUT_LINES" line
    while IFS= read -r line; do
        if [ -n "$line" ]; then all="${all}warn"$'\t'"${line}"$'\n'; log_detail "$CMD warning: $line"; fi
    done <<< "$WARN_LINES"
    while IFS= read -r line; do
        if [ -n "$line" ]; then all="${all}error"$'\t'"${line}"$'\n'; log_detail "$CMD error: $line"; fi
    done <<< "$ERR_LINES"
    log_detail "$CMD exit=$code"
    if $OPT_JSON; then
        printf '%s' "$all" | pj tagged2json
    else
        printf '%s' "$all"
    fi
    exit "$code"
}

usage_error() {
    log_detail "usage error: $1"
    printf 'aitools-profile: %s (see --help)\n' "$1" >&2
    exit 2
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
CMD="${1:-}"
if [ $# -gt 0 ]; then shift; fi
case "$CMD" in --help|-h) usage; exit 0 ;; esac
OPT_CONFIG=""; OPT_PROFILE=""; OPT_ALIAS=""; OPT_ENVIRONMENT=""; OPT_GITHUB_USER=""
OPT_USER_REPO_PATH=""; OPT_REPOS_PATH=""; OPT_NAME=""; OPT_COMPANY=""; OPT_SHELL=""
OPT_EMAIL=""; OPT_OUT=""; OPT_MACHINE_ID_VALUE=""; OPT_HOSTNAME_VALUE=""
OPT_CREATE=false; OPT_JSON=false; OPT_PLAIN=false
need_value() { if [ "$1" -lt 2 ]; then usage_error "$2 needs a value"; fi; }
while [ $# -gt 0 ]; do
    case "$1" in
        --config)          need_value $# "$1"; OPT_CONFIG="$2"; shift 2 ;;
        --profile)         need_value $# "$1"; OPT_PROFILE="$2"; shift 2 ;;
        --alias)           need_value $# "$1"; OPT_ALIAS="$2"; shift 2 ;;
        --environment)     need_value $# "$1"; OPT_ENVIRONMENT="$2"; shift 2 ;;
        --github-user)     need_value $# "$1"; OPT_GITHUB_USER="$2"; shift 2 ;;
        --user-repo-path)  need_value $# "$1"; OPT_USER_REPO_PATH="$2"; shift 2 ;;
        --repos-path)      need_value $# "$1"; OPT_REPOS_PATH="$2"; shift 2 ;;
        --name)            need_value $# "$1"; OPT_NAME="$2"; shift 2 ;;
        --company)         need_value $# "$1"; OPT_COMPANY="$2"; shift 2 ;;
        --shell)           need_value $# "$1"; OPT_SHELL="$2"; shift 2 ;;
        --email)           need_value $# "$1"; OPT_EMAIL="$2"; shift 2 ;;
        --out)             need_value $# "$1"; OPT_OUT="$2"; shift 2 ;;
        --machine-id-value) need_value $# "$1"; OPT_MACHINE_ID_VALUE="$2"; shift 2 ;;
        --hostname-value)  need_value $# "$1"; OPT_HOSTNAME_VALUE="$2"; shift 2 ;;
        --path-form)       need_value $# "$1"; shift 2 ;;  # PowerShell parity; paths are already native here
        --create)          OPT_CREATE=true; shift ;;
        --json)            OPT_JSON=true; shift ;;
        --plain)           OPT_PLAIN=true; shift ;;
        --help|-h)         usage; exit 0 ;;
        *)                 usage_error "unknown option: $1" ;;
    esac
done

# ---------------------------------------------------------------------------
# This machine: environment, stable id, hostname
# ---------------------------------------------------------------------------
# Environment: the shared lib resolved AITOOLS_ENVIRONMENT; --environment re-applies
# the same rule (claude-code-web exists only on linux).
THIS_ENV="$AITOOLS_ENVIRONMENT"
if [ -n "$OPT_ENVIRONMENT" ]; then
    case "$OPT_ENVIRONMENT" in
        claude-code-web|local) THIS_ENV="$OPT_ENVIRONMENT" ;;
        *) usage_error "--environment must be local or claude-code-web" ;;
    esac
    if [ "$AITOOLS_PLATFORM" != "linux" ]; then THIS_ENV="local"; fi
fi

# Stable machine id, stored raw in profile.json (P-Q2).
#   macOS: IOPlatformUUID (ioreg) -- hardware-bound, survives OS reinstall.
#   Linux: /etc/machine-id, then /var/lib/dbus/machine-id (duplicated on cloned images).
THIS_ID=""; THIS_ID_SOURCE=""; THIS_ID_ERROR=""
detect_machine_id() {
    if [ -n "$OPT_MACHINE_ID_VALUE" ]; then
        THIS_ID="$OPT_MACHINE_ID_VALUE"; THIS_ID_SOURCE="argument"; return 0
    fi
    if [ -x /usr/sbin/ioreg ]; then
        local out rc=0
        out=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then THIS_ID_ERROR="ioreg failed (exit $rc)"; return 0; fi
        THIS_ID=$(printf '%s\n' "$out" | perl -ne 'print $1 if /"IOPlatformUUID"\s*=\s*"([^"]+)"/')
        THIS_ID_SOURCE="IOPlatformUUID"
        if [ -z "$THIS_ID" ]; then THIS_ID_ERROR="IOPlatformUUID not found in ioreg output"; fi
        return 0
    fi
    local f
    for f in /etc/machine-id /var/lib/dbus/machine-id; do
        if [ -r "$f" ]; then
            THIS_ID=$(tr -d '[:space:]' < "$f")
            if [ -n "$THIS_ID" ]; then THIS_ID_SOURCE="$f"; return 0; fi
        fi
    done
    THIS_ID_ERROR="no machine id source (ioreg, /etc/machine-id, /var/lib/dbus/machine-id)"
}

# Hostname: one source per platform (P-Q5). macOS: `scutil --get LocalHostName`
# (the Bonjour name; the kernel hostname is derived from DNS/DHCP and changes with
# the network, so it is never used). Linux: `uname -n`, short form.
THIS_HOST=""; THIS_HOST_ERROR=""
# short_host NAME -- text before the first dot, ends trimmed, ASCII lower-cased
# (the same rule as ConvertTo-ShortHost in aitools-profile.ps1)
short_host() { local h="${1%%.*}"; printf '%s' "$h" | perl -pe 's/^[ \t\r\n]+|[ \t\r\n]+$//g; tr/A-Z/a-z/'; }
detect_hostname() {
    local raw="" rc=0
    if [ -n "$OPT_HOSTNAME_VALUE" ]; then
        raw="$OPT_HOSTNAME_VALUE"
    elif [ -x /usr/sbin/scutil ]; then
        raw=$(/usr/sbin/scutil --get LocalHostName 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then THIS_HOST_ERROR="scutil --get LocalHostName failed: $raw"; raw=""; fi
    else
        raw=$(uname -n 2>&1) || rc=$?
        if [ "$rc" -ne 0 ]; then THIS_HOST_ERROR="uname -n failed (exit $rc): $raw"; raw=""; fi
    fi
    THIS_HOST=$(short_host "$raw")
}

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ---------------------------------------------------------------------------
# Config (read-only here)
# ---------------------------------------------------------------------------
CFG_FILE="${OPT_CONFIG:-$HOME/.aitools/config.json}"
CFG_OK=false
load_config() {
    jcheck "$CFG_FILE"
    case "$JCHECK_STATE" in
        valid) CFG_OK=true ;;
        missing) CFG_OK=false ;;
        *) CFG_OK=false; add_warn "$JCHECK_MSG -- resolving without it" ;;
    esac
}
# cfg VAR KEY -- top-level config.json string, "" when absent or config unusable
cfg() {
    printf -v "$1" '%s' ""
    if $CFG_OK; then jread "$1" "$CFG_FILE" "$2"; fi
}

strip_slash() { local p="$1"; while [ "${#p}" -gt 1 ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done; printf '%s' "$p"; }

# ---------------------------------------------------------------------------
# Which dotprofile (reference/user-repo.md "Which dotprofile"), first match wins:
#   1 AITOOLS_USER_REPO_PATH  2 --user-repo-path  3 config.json userRepoPath
#   4 <reposPath>/aitools-<githubUser>  5 the only aitools-* dir with profile.json
#   6 none (shared-only mode; not an error)
# Sets RUR_PATH, RUR_VIA, RUR_EXPECTED. Returns 0 found, 1 none, 2 error.
# ---------------------------------------------------------------------------
RUR_PATH=""; RUR_VIA="none"; RUR_EXPECTED=""
resolve_user_repo() {
    RUR_PATH=""; RUR_VIA="none"; RUR_EXPECTED=""
    local p="" base="" user="" d n found="" count=0
    if [ -n "${AITOOLS_USER_REPO_PATH:-}" ]; then
        if [ -d "$AITOOLS_USER_REPO_PATH" ]; then
            RUR_PATH=$(strip_slash "$AITOOLS_USER_REPO_PATH"); RUR_VIA="env"; return 0
        fi
        add_err "AITOOLS_USER_REPO_PATH does not exist: $AITOOLS_USER_REPO_PATH"; return 2
    fi
    if [ -n "$OPT_USER_REPO_PATH" ]; then
        if [ -d "$OPT_USER_REPO_PATH" ]; then
            RUR_PATH=$(strip_slash "$OPT_USER_REPO_PATH"); RUR_VIA="argument"; return 0
        fi
        add_err "--user-repo-path does not exist: $OPT_USER_REPO_PATH"; return 2
    fi
    cfg p userRepoPath
    if [ -n "$p" ]; then
        if [ -d "$p" ]; then RUR_PATH=$(strip_slash "$p"); RUR_VIA="config"; return 0; fi
        add_warn "config.json userRepoPath does not exist: $p"
    fi
    base="$OPT_REPOS_PATH"
    if [ -z "$base" ]; then cfg base reposPath; fi
    if [ -z "$base" ]; then base="$HOME/repos"; fi
    base=$(strip_slash "$base")
    user="$OPT_GITHUB_USER"
    if [ -z "$user" ]; then cfg user githubUser; fi
    if [ -n "$user" ]; then
        p="$base/aitools-$user"
        if [ -d "$p" ]; then RUR_PATH="$p"; RUR_VIA="convention"; return 0; fi
        RUR_EXPECTED="$p"; return 1
    fi
    for d in "$base"/aitools-*; do
        [ -d "$d" ] || continue
        n="${d##*/}"
        [[ "$n" =~ ^aitools-[A-Za-z0-9-]+$ ]] || continue
        [ -f "$d/profile.json" ] || continue
        found="$d"; count=$((count + 1))
    done
    if [ "$count" -eq 1 ]; then
        add_warn "githubUser unknown -- used the only dotprofile under $base"
        RUR_PATH="$found"; RUR_VIA="scan"; return 0
    fi
    if [ "$count" -gt 1 ]; then
        add_warn "githubUser unknown and $count aitools-* repos with profile.json under $base"
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Which machine profile (reference/user-repo.md "Which machine profile"),
# first decisive step wins:
#   1 override alias (--alias, AITOOLS_MACHINE_ALIAS)          via=override
#   2 environment claude-code-web: that machine.environment    via=environment
#   3 machine.id equals this machine's id                      via=id
#   4 config.json machineAlias                                 via=alias
#   5 hostname (legacy; warns)                                 via=hostname
#   6 none: error; never another profile's values
# Sets RM_ALIAS, RM_VIA, RM_OVERRIDE_SOURCE, ALIASES and the RM_ profile values.
# Returns 0 resolved, 2 no match or error.
# ---------------------------------------------------------------------------
RM_ALIAS=""; RM_VIA="none"; RM_OVERRIDE_SOURCE=""; ALIASES=""
RM_NAME=""; RM_COMPANY=""; RM_GIT_NAME=""; RM_GIT_EMAIL=""; RM_GITHUB=""

alias_listed() {
    local a
    while IFS= read -r a; do
        if [ -n "$a" ] && [ "$a" = "$1" ]; then return 0; fi
    done <<< "$ALIASES"
    return 1
}
alias_csv() {
    local a out=""
    while IFS= read -r a; do
        if [ -n "$a" ]; then out="${out:+$out, }$a"; fi
    done <<< "$ALIASES"
    printf '%s' "$out"
}

# identity_values PF -- RM_ values from identity only (machine-independent)
identity_values() {
    local pf="$1" v
    jread v "$pf" identity name
    if $JREAD_FOUND; then RM_NAME="$v"; else jread RM_NAME "$pf" identity git name; fi
    jread RM_COMPANY "$pf" identity company
    jread RM_GIT_NAME "$pf" identity git name
    jread RM_GIT_EMAIL "$pf" identity git email
    jread RM_GITHUB "$pf" identity github
}

# profile_values PF ALIAS -- effective values: the profile's name/company win over identity
profile_values() {
    local pf="$1" a="$2" v
    identity_values "$pf"
    jread v "$pf" profiles "$a" name
    if $JREAD_FOUND; then RM_NAME="$v"; fi
    jread v "$pf" profiles "$a" company
    if $JREAD_FOUND; then RM_COMPANY="$v"; fi
}

machine_done() {
    local pf="$1" a="$2" via="$3" pid=""
    RM_ALIAS="$a"; RM_VIA="$via"
    profile_values "$pf" "$a"
    jread pid "$pf" profiles "$a" machine id
    if [ "$via" != "id" ] && [ "$via" != "environment" ] && [ -n "$THIS_ID" ] && [ -n "$pid" ] \
        && [ "$(lc "$pid")" != "$(lc "$THIS_ID")" ]; then
        add_warn "profile \"$a\" is registered to another machine (machine.id $pid, this machine $THIS_ID)"
    fi
    if [ "$via" != "id" ] && [ "$via" != "environment" ] && [ "$via" != "hostname" ] && [ -n "$THIS_ID" ] && [ -z "$pid" ]; then
        add_warn "profile \"$a\" has no machine.id -- run: aitools user init (registers this machine)"
    fi
    return 0
}

resolve_machine() {
    local pf="$1" config_alias="$2" v t a all matches="" mcount=0 ignored=false names h
    RM_ALIAS=""; RM_VIA="none"; RM_OVERRIDE_SOURCE=""; ALIASES=""
    jread v "$pf" version
    jtype t "$pf" profiles
    if [ "$v" != "2" ] || [ "$t" != "object" ]; then
        add_err "profile.json is not v2 or has no profiles"; return 2
    fi
    jlist all keys "$pf" profiles
    while IFS= read -r a; do
        [ -n "$a" ] || continue
        jtype t "$pf" profiles "$a"
        if [ "$t" = "object" ]; then ALIASES="${ALIASES}${a}"$'\n'; else ignored=true; fi
    done <<< "$all"
    if $ignored; then add_warn "profile.json has profile entries that are not objects -- ignored"; fi
    if [ -z "$ALIASES" ]; then add_err "profile.json has no machine profiles"; return 2; fi

    local override="$OPT_ALIAS"
    if [ -n "$override" ]; then RM_OVERRIDE_SOURCE="argument"
    elif [ -n "${AITOOLS_MACHINE_ALIAS:-}" ]; then override="$AITOOLS_MACHINE_ALIAS"; RM_OVERRIDE_SOURCE="env"; fi
    if [ -n "$override" ]; then
        if alias_listed "$override"; then machine_done "$pf" "$override" "override"; return 0; fi
        add_err "override alias \"$override\" not in profiles ($(alias_csv))"; return 2
    fi

    if [ "$THIS_ENV" = "claude-code-web" ]; then
        while IFS= read -r a; do
            [ -n "$a" ] || continue
            jread v "$pf" profiles "$a" machine environment
            if [ "$v" = "claude-code-web" ]; then matches="${matches}${a}"$'\n'; mcount=$((mcount + 1)); fi
        done <<< "$ALIASES"
        if [ "$mcount" -eq 1 ]; then machine_done "$pf" "${matches%$'\n'}" "environment"; return 0; fi
        if [ "$mcount" -gt 1 ]; then
            add_err "more than one claude-code-web profile: $(printf '%s' "$matches" | paste -sd ',' - | perl -pe 's/,/, /g')"; return 2
        fi
        add_warn "no profile has machine.environment \"claude-code-web\""
    elif [ -n "$THIS_ID" ]; then
        while IFS= read -r a; do
            [ -n "$a" ] || continue
            jread v "$pf" profiles "$a" machine id
            if [ -n "$v" ] && [ "$(lc "$v")" = "$(lc "$THIS_ID")" ]; then matches="${matches}${a}"$'\n'; mcount=$((mcount + 1)); fi
        done <<< "$ALIASES"
        if [ "$mcount" -eq 1 ]; then
            a="${matches%$'\n'}"
            if [ -n "$config_alias" ] && [ "$config_alias" != "$a" ]; then
                add_warn "config.json machineAlias \"$config_alias\" disagrees with machine.id match \"$a\" -- machine.id wins"
            fi
            machine_done "$pf" "$a" "id"; return 0
        fi
        if [ "$mcount" -gt 1 ]; then
            add_err "machine.id $THIS_ID is registered on more than one profile: $(printf '%s' "$matches" | paste -sd ',' - | perl -pe 's/,/, /g')"; return 2
        fi
    fi

    if [ -n "$config_alias" ]; then
        if alias_listed "$config_alias"; then machine_done "$pf" "$config_alias" "alias"; return 0; fi
        add_warn "config.json machineAlias \"$config_alias\" not in profiles ($(alias_csv))"
    fi

    matches=""; mcount=0
    if [ -n "$THIS_HOST" ]; then
        while IFS= read -r a; do
            [ -n "$a" ] || continue
            jread v "$pf" profiles "$a" machine hostname
            jlist names items "$pf" profiles "$a" machine hostnames
            names="${v}"$'\n'"${names}"
            while IFS= read -r h; do
                if [ -n "$h" ] && [ "$(short_host "$h")" = "$THIS_HOST" ]; then
                    matches="${matches}${a}"$'\n'; mcount=$((mcount + 1)); break
                fi
            done <<< "$names"
        done <<< "$ALIASES"
    fi
    if [ "$mcount" -eq 1 ]; then
        add_warn "matched by hostname only (legacy) -- run: aitools user init (registers machine.id)"
        machine_done "$pf" "${matches%$'\n'}" "hostname"; return 0
    fi
    if [ "$mcount" -gt 1 ]; then
        add_err "hostname matches more than one profile: $(printf '%s' "$matches" | paste -sd ',' - | perl -pe 's/,/, /g')"; return 2
    fi
    add_err "no profile matches this machine (machine.id ${THIS_ID:-unavailable}, hostname ${THIS_HOST:-unavailable}) -- run: aitools user init"
    return 2
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
cmd_user_repo_path() {
    load_config
    local rc=0
    resolve_user_repo || rc=$?
    if $OPT_PLAIN; then
        local line
        while IFS= read -r line; do if [ -n "$line" ]; then printf 'warning: %s\n' "$line" >&2; fi; done <<< "$WARN_LINES"
        while IFS= read -r line; do if [ -n "$line" ]; then printf '%s\n' "$line" >&2; fi; done <<< "$ERR_LINES"
        log_detail "user-repo-path path=$RUR_PATH via=$RUR_VIA exit=$rc"
        if [ "$rc" -eq 0 ]; then printf '%s\n' "$RUR_PATH"; fi
        exit "$rc"
    fi
    put path "$RUR_PATH"
    put via "$RUR_VIA"
    put expected "$RUR_EXPECTED"
    finish "$rc"
}

cmd_machine_id() {
    detect_machine_id
    if [ -n "$THIS_ID_ERROR" ] || [ -z "$THIS_ID" ]; then
        log_detail "machine-id error: ${THIS_ID_ERROR:-empty id}"
        printf 'aitools-profile: %s\n' "${THIS_ID_ERROR:-empty machine id}" >&2
        exit 2
    fi
    log_detail "machine-id source=$THIS_ID_SOURCE"
    printf '%s\n' "$THIS_ID"
    exit 0
}

cmd_hostname() {
    detect_hostname
    if [ -n "$THIS_HOST_ERROR" ] || [ -z "$THIS_HOST" ]; then
        log_detail "hostname error: ${THIS_HOST_ERROR:-empty hostname}"
        printf 'aitools-profile: %s\n' "${THIS_HOST_ERROR:-empty hostname}" >&2
        exit 2
    fi
    printf '%s\n' "$THIS_HOST"
    exit 0
}

# put_machine_lines -- the shared tail of resolve and derive-config
put_identity_lines() {
    put name "$RM_NAME"
    put company "$RM_COMPANY"
    put gitName "$RM_GIT_NAME"
    put gitEmail "$RM_GIT_EMAIL"
    put github "$RM_GITHUB"
}

cmd_resolve() {
    load_config
    detect_machine_id
    detect_hostname
    if [ -n "$THIS_ID_ERROR" ]; then add_warn "machine id unavailable: $THIS_ID_ERROR"; fi
    if [ -n "$THIS_HOST_ERROR" ]; then add_warn "hostname unavailable: $THIS_HOST_ERROR"; fi
    local pf="${OPT_PROFILE:-${AITOOLS_PROFILE_FILE:-}}" from_env=false repo_rc=0 rc=0 config_alias=""
    if [ -z "$OPT_PROFILE" ] && [ -n "${AITOOLS_PROFILE_FILE:-}" ]; then from_env=true; fi
    put_head() {
        put alias "$RM_ALIAS"; put via "$RM_VIA"; put environment "$THIS_ENV"
        put machineId "$THIS_ID"; put hostname "$THIS_HOST"; put profileFile "$1"
        put userRepoPath "$RUR_PATH"; put userRepoVia "$RUR_VIA"
    }
    if [ -n "$pf" ]; then
        if [ ! -f "$pf" ]; then
            if $from_env; then add_err "profile file set but missing: $pf (AITOOLS_PROFILE_FILE)"
            else add_err "profile file set but missing: $pf"; fi
            put_head "$pf"; put_identity_lines; finish 2
        fi
    else
        resolve_user_repo || repo_rc=$?
        if [ "$repo_rc" -eq 2 ]; then put_head ""; put_identity_lines; finish 2; fi
        if [ "$repo_rc" -eq 1 ]; then put_head ""; put_identity_lines; finish 1; fi
        pf="$RUR_PATH/profile.json"
    fi
    jcheck "$pf"
    case "$JCHECK_STATE" in
        missing) add_warn "profile.json not found: $pf"; put_head "$pf"; put_identity_lines; finish 1 ;;
        invalid) add_err "$JCHECK_MSG"; put_head "$pf"; put_identity_lines; finish 2 ;;
    esac
    cfg config_alias machineAlias
    resolve_machine "$pf" "$config_alias" || rc=$?
    # No machine match: report identity-level values only (never another profile's)
    if [ -z "$RM_ALIAS" ]; then identity_values "$pf"; fi
    put_head "$pf"
    put_identity_lines
    finish "$rc"
}

cmd_derive_config() {
    load_config
    detect_machine_id
    detect_hostname
    if [ -n "$THIS_ID_ERROR" ]; then add_warn "machine id unavailable: $THIS_ID_ERROR"; fi
    if [ -n "$THIS_HOST_ERROR" ]; then add_warn "hostname unavailable: $THIS_HOST_ERROR"; fi
    local repo_rc=0 rc=0 d_gh="" d_urp="" d_alias="" pf gh="" config_alias=""
    put_derived() {
        put derived.githubUser "$d_gh"; put derived.userRepoPath "$d_urp"; put derived.machineAlias "$d_alias"
        put userRepoVia "$RUR_VIA"; put via "$RM_VIA"; put company "$RM_COMPANY"
        put machineId "$THIS_ID"; put hostname "$THIS_HOST"; put aliases "$(alias_csv)"
    }
    resolve_user_repo || repo_rc=$?
    if [ "$repo_rc" -eq 2 ]; then put_derived; finish 2; fi
    if [ "$repo_rc" -eq 1 ]; then
        add_warn "no dotprofile found -- only bootstrap keys written (shared-only mode)"
        d_gh="$OPT_GITHUB_USER"
        put_derived; finish 1
    fi
    # A value from an environment override is used for this run but not persisted:
    # config.json records the machine's own answer, not a test's or a caller's.
    if [ "$RUR_VIA" != "env" ]; then d_urp="$RUR_PATH"
    else add_warn "dotprofile from AITOOLS_USER_REPO_PATH -- not saved to config.json"; fi
    pf="$RUR_PATH/profile.json"
    jcheck "$pf"
    case "$JCHECK_STATE" in
        missing) add_warn "profile.json not found in $RUR_PATH"; d_gh="$OPT_GITHUB_USER"; put_derived; finish 1 ;;
        invalid) add_err "$JCHECK_MSG"; put_derived; finish 2 ;;
    esac
    gh="$OPT_GITHUB_USER"
    if [ -z "$gh" ]; then jread gh "$pf" identity github; fi
    if [ -z "$gh" ]; then cfg gh githubUser; fi
    d_gh="$gh"
    cfg config_alias machineAlias
    resolve_machine "$pf" "$config_alias" || rc=$?
    if [ -n "$RM_ALIAS" ]; then
        if [ "$RM_VIA" = "override" ] && [ "$RM_OVERRIDE_SOURCE" = "env" ]; then
            add_warn "machine alias from AITOOLS_MACHINE_ALIAS -- not saved to config.json"
        else
            d_alias="$RM_ALIAS"
        fi
    else
        RM_COMPANY=""
    fi
    put_derived
    finish "$rc"
}

cmd_snapshot() {
    if [ -z "$OPT_PROFILE" ]; then usage_error "snapshot needs --profile"; fi
    jcheck "$OPT_PROFILE"
    case "$JCHECK_STATE" in
        missing) printf 'aitools-profile: profile.json not found: %s\n' "$OPT_PROFILE" >&2; exit 1 ;;
        invalid) printf 'aitools-profile: %s\n' "$JCHECK_MSG" >&2; exit 2 ;;
    esac
    local out rc=0
    out=$(pj snapshot "$OPT_PROFILE") || rc=$?
    if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
        printf 'aitools-profile: snapshot failed (engine exit %s)\n' "$rc" >&2; exit 2
    fi
    log_detail "snapshot of $OPT_PROFILE"
    printf '%s\n' "$out"
    exit 0
}

# edit_op LINE... -- append tab-separated edit operations (values must be one line)
EDIT_OPS=""
edit_set() {
    local type="$1" value="$2"; shift 2
    local segs="" s
    for s in "$@"; do segs="${segs}"$'\t'"${s}"; done
    EDIT_OPS="${EDIT_OPS}set"$'\t'"${type}"$'\t'"$(one_line "$value")${segs}"$'\n'
}

cmd_register() {
    if [ -z "$OPT_PROFILE" ] || [ -z "$OPT_ALIAS" ] || [ -z "$OPT_OUT" ]; then
        usage_error "register needs --profile, --alias and --out"
    fi
    if ! [[ "$OPT_ALIAS" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; then usage_error "invalid alias: $OPT_ALIAS"; fi
    local o
    for o in "$OPT_NAME" "$OPT_COMPANY" "$OPT_SHELL" "$OPT_EMAIL" "$OPT_GITHUB_USER"; do
        case "$o" in *$'\t'*|*$'\n'*|*$'\r'*) usage_error "register values must be one line (no tab or newline)" ;; esac
    done
    local in="$OPT_PROFILE" state before="" after="" v a all t ver os arch rc=0 msg pid
    jcheck "$OPT_PROFILE"
    case "$JCHECK_STATE" in
        invalid) add_err "$JCHECK_MSG"; finish 2 ;;
        missing)
            if ! $OPT_CREATE; then add_err "profile.json not found (use --create): $OPT_PROFILE"; finish 1; fi
            in="-"
            edit_set number 2 version
            edit_set string "$OPT_GITHUB_USER" identity github
            edit_set string "$OPT_EMAIL" identity email
            if [ -n "$OPT_NAME" ]; then edit_set string "$OPT_NAME" identity name; fi
            if [ -n "$OPT_COMPANY" ]; then edit_set string "$OPT_COMPANY" identity company; fi
            edit_set string "$OPT_NAME" identity git name
            edit_set string "$OPT_EMAIL" identity git email
            edit_set json '{}' profiles ;;
    esac
    if [ "$in" != "-" ]; then
        jread ver "$in" version
        if [ "$ver" != "2" ]; then add_err "profile.json is not v2 -- migrate first"; finish 2; fi
        jtype t "$in" profiles
        if [ "$t" != "object" ]; then edit_set json '{}' profiles; fi
    fi
    detect_hostname
    if [ "$THIS_ENV" != "claude-code-web" ]; then
        detect_machine_id
        if [ -n "$THIS_ID_ERROR" ]; then add_warn "$THIS_ID_ERROR -- profile registered without machine.id"; fi
    fi
    if [ -n "$THIS_ID" ] && [ "$in" != "-" ]; then
        jlist all keys "$in" profiles
        while IFS= read -r a; do
            [ -n "$a" ] || continue
            [ "$a" != "$OPT_ALIAS" ] || continue
            jread pid "$in" profiles "$a" machine id
            if [ -n "$pid" ] && [ "$(lc "$pid")" = "$(lc "$THIS_ID")" ]; then
                add_err "machine.id $THIS_ID is already registered on profile \"$a\""; finish 2
            fi
        done <<< "$all"
    fi
    state="created"
    if [ "$in" != "-" ]; then
        jtype t "$in" profiles "$OPT_ALIAS"
        if [ -n "$t" ]; then
            if [ "$t" != "object" ]; then add_err "profiles.$OPT_ALIAS is not an object"; finish 2; fi
            state="updated"
            jsub before "$in" profiles "$OPT_ALIAS"
        fi
    fi
    # Per-profile name/company only when neither the profile nor identity has one
    if [ -n "$OPT_NAME" ]; then
        v=""; if [ "$in" != "-" ]; then jread v "$in" profiles "$OPT_ALIAS" name; fi
        local has_prof=$JREAD_FOUND has_ident=false
        if [ "$in" = "-" ]; then has_ident=true; else jread v "$in" identity name; has_ident=$JREAD_FOUND; fi
        if [ "$state" = "created" ]; then has_prof=false; fi
        if ! $has_prof && ! $has_ident; then edit_set string "$OPT_NAME" profiles "$OPT_ALIAS" name; fi
    fi
    if [ -n "$OPT_COMPANY" ]; then
        v=""; if [ "$in" != "-" ]; then jread v "$in" profiles "$OPT_ALIAS" company; fi
        local has_profc=$JREAD_FOUND has_identc=false
        if [ "$in" = "-" ]; then has_identc=true; else jread v "$in" identity company; has_identc=$JREAD_FOUND; fi
        if [ "$state" = "created" ]; then has_profc=false; fi
        if ! $has_profc && ! $has_identc; then edit_set string "$OPT_COMPANY" profiles "$OPT_ALIAS" company; fi
    fi
    if [ -n "$THIS_ID" ]; then edit_set string "$THIS_ID" profiles "$OPT_ALIAS" machine id; fi
    if [ "$THIS_ENV" = "claude-code-web" ]; then edit_set string "claude-code-web" profiles "$OPT_ALIAS" machine environment; fi
    v=""; if [ "$in" != "-" ]; then jread v "$in" profiles "$OPT_ALIAS" machine hostname; fi
    if [ -z "$v" ] && [ -n "$THIS_HOST" ]; then edit_set string "$THIS_HOST" profiles "$OPT_ALIAS" machine hostname; fi
    case "$(uname -s)" in
        Darwin*) os="darwin" ;;
        Linux*)  os="linux" ;;
        *)       os=$(lc "$(uname -s)") ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)  arch="x64" ;;
        arm64|aarch64) arch="arm64" ;;
        *)             arch=$(uname -m) ;;
    esac
    edit_set string "$os" profiles "$OPT_ALIAS" machine os
    edit_set string "$arch" profiles "$OPT_ALIAS" machine arch
    if [ -n "$OPT_SHELL" ]; then edit_set string "$OPT_SHELL" profiles "$OPT_ALIAS" machine shell; fi
    msg=$(printf '%s' "$EDIT_OPS" | pj edit "$in" "$OPT_OUT" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then add_err "register failed: $msg"; finish 2; fi
    jtype t "$OPT_OUT" profiles "$OPT_ALIAS"
    if [ "$t" != "object" ]; then add_err "validation failed: profile $OPT_ALIAS missing after write"; finish 2; fi
    jsub after "$OPT_OUT" profiles "$OPT_ALIAS"
    if [ "$state" = "updated" ] && [ "$before" = "$after" ]; then state="unchanged"; fi
    put result "$state"
    put alias "$OPT_ALIAS"
    put machineId "$THIS_ID"
    put hostname "$THIS_HOST"
    finish 0
}

case "$CMD" in
    user-repo-path) cmd_user_repo_path ;;
    machine-id)     cmd_machine_id ;;
    hostname)       cmd_hostname ;;
    resolve)        cmd_resolve ;;
    derive-config)  cmd_derive_config ;;
    snapshot)       cmd_snapshot ;;
    register)       cmd_register ;;
    "")             usage; exit 2 ;;
    *)              usage_error "unknown command: $CMD" ;;
esac
