#!/usr/bin/env bash
# workflow-delegation-guard.sh — Claude Code PreToolUse hook (matcher: Workflow)
# Reminds the caller to load the /delegate skill on EVERY Workflow call, and
# checks EACH agent() prompt of the workflow script for the eight delegation
# duty elements of /delegate v2.0 (one score per agent() call site).
#
# Intent: Detect workflow agent() prompts that omit delegation-duty elements
# and remind the delegating agent of the duty on every Workflow launch
# (detection layer for the user rule delegation.md, D-DEL7, and the
# /delegate skill). It mirrors delegation-duty-guard.sh (the Agent tool),
# adapted to scripts: Claude Code fires ONE PreToolUse(Workflow) event per
# Workflow call, carrying the whole script, and no event per agent() call,
# so the script is parsed here. NOT the duty itself (rule + skill). NOT a
# prompt rewriter. NOT the Agent-tool check (delegation-duty-guard.sh).
# Consumed by: Claude Code PreToolUse(Workflow), registered via
# hooks-manifest.json; rollout governed by .claude/rules/hook-rollout.md.
# Contract: .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Hook2/S3-Hook2-spec.md (v1.0)
#
# OBSERVE mode (MODE_WF_DUTY="observe"): always allows (exit 0). On every
# Workflow call it emits the reminder line, a per-agent() summary, the worst
# prompts and per-element guidance, two ways:
#   - stdout: {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#     "additionalContext":"..."}} -- the channel Claude reads on exit 0
#     (Claude never sees stderr from a hook that exits 0). At most 4,000
#     characters of context.
#   - stderr: the same text, for the user's transcript view and tests.
# MODE_WF_DUTY="enforce" blocks (exit 2, stderr only) when any checked
# prompt (or, in fallback, the whole script) misses an element; promote only
# per .claude/rules/hook-rollout.md (zero false positives).
#
# What is checked:
#   - Script text: tool_input.script (JSON-unescaped); else the file named by
#     tool_input.scriptPath (relative paths resolve against the payload's
#     "cwd"; a readable regular file of at most 512 KB, read as is); else
#     nothing is checked, but the reminder still prints.
#   - A Perl lexer (\G /gc regexes: comments, '...' and "..." strings,
#     template literals with nested ${...}, regex literals by the
#     previous-token heuristic) finds every agent( call site (a whole
#     identifier, not after "." and not "function agent"; never inside a
#     comment or string). Its first argument is resolved when it is string
#     literals, template literals, constants (const/let/var NAME = <strings,
#     templates, identifiers, + and parentheses>, resolved lazily, cycle
#     checked, depth <= 10), "+" and parentheses. Inside a template, ${NAME}
#     of a resolvable constant is replaced by its text; any other ${e} stays
#     as the literal text "${e}". Anything else is "unresolved".
#   - Label: a string/template "label:" in the second (object) argument,
#     else agent@L<line>; sanitised to [A-Za-z0-9 :#._/-], max 60 chars.
#   - Each resolved prompt is scored on its first 256 KB by the eight-element
#     block shared verbatim with delegation-duty-guard.sh (between the
#     "delegation elements block" markers; a test fails when they differ).
#   - Fallback to ONE whole-script score (as delegation-duty-guard did) when
#     the lexer fails (unterminated string, template or comment; nesting too
#     deep), when no agent( call is found, or on the 2 s time guard.
#   - Any other tool: silent, exit 0. Without perl: the reminder only.
#
# LIMITS (by design):
#   - Static call sites, not runtime calls: an agent( inside a loop or map()
#     counts once, whatever the number of agents it starts.
#   - Runtime values (${l.k}, ${BRIEF}) are left as text: they can neither add
#     nor hide an element unless their literal text names it.
#   - Prompts built by functions (agent(makePrompt(x))), member access
#     (agent(r.prompt)) or ternaries are "unresolved" and not scored.
#   - A constant name defined twice keeps its first string definition.
#   - Only the first 512 KB of the script text is parsed.
#
# Eight delegation duty elements (/delegate v2.0; detail and patterns in
# delegation-duty-guard.sh): identity, rules, skills, OL, conflict,
# WRITE_BLOCKED, access, md-prefix.
#
# Hook contract:
#   - PreToolUse hook, matcher: Workflow
#   - Receives JSON on stdin (tool_name, tool_input, cwd, ...)
#   - Exit 0 = allow (OBSERVE mode); exit 2 = block (ENFORCE mode only)
#   - stdout -> hookSpecificOutput JSON (exit 0 only); stderr -> text
#   - Must be fast (< 100 ms for a 500 KB script, macOS)
#   - Must never crash or hang (perl time guard: alarm, 2 s)
#   - Standalone: loads no shared library (deployed hooks cannot)
#
# KPI definitions (logged to harness DB via session events.jsonl, src "wdg";
# "delegation" events):
#   - one event per agent() call site: score, total (8), missing (csv),
#     mode, tool "Workflow", checked (1 scored, 0 unresolved), scope "agent",
#     agent (the label)
#   - fallback: one event, scope "script", checked 1
#   - nothing to check (no script, no perl, checker failure): one event,
#     scope "script", checked 0
#
# Framework: reference/framework-hook-rollout.md (observe-then-enforce)
# Platform: macOS + Linux + Windows Git Bash (bash 3.2 compatible)

set -euo pipefail

MODE_WF_DUTY="observe"
DUTY_TOTAL=8
SCRIPT_MAX_BYTES=524288
CHECK_MAX_CHARS=262144
CONTEXT_MAX_CHARS=4000

REMINDER="[workflow-guard] Load /delegate before every Workflow call; every agent() prompt is a delegation prompt and needs all eight elements."

# --- Telemetry: JSONL event emission ---
# git may be absent or the cwd may not be a repo: both yield no session
# dir, and telemetry is skipped (the hook itself still runs).
_SESSION_DIR=""
_cs_file="$(git rev-parse --show-toplevel 2>/dev/null || echo "")/.scratch/.current-session"
if [ -f "$_cs_file" ]; then
    _SESSION_DIR=$(cat "$_cs_file" 2>/dev/null || true)
fi
_TS=""

emit_hook_event() {
    local event_type="$1" detail_json="$2"
    [ -n "$_SESSION_DIR" ] || return 0
    [ -n "$_TS" ] || _TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    # Telemetry is best effort: an unwritable log must not fail the hook.
    printf '{"t":"%s","type":"%s","src":"wdg","d":%s}\n' \
        "$_TS" "$event_type" "$detail_json" \
        >> "$_SESSION_DIR/events.jsonl" 2>/dev/null || true
}

# --- Output: stderr text + stdout additionalContext JSON, then exit ---
# finish <exit code> <message, newline-separated lines>
finish() {
    local rc="$1" msg="$2" esc
    if [ "${#msg}" -gt "$CONTEXT_MAX_CHARS" ]; then
        msg="${msg:0:$((CONTEXT_MAX_CHARS - 16))} [truncated]"
    fi
    printf '%s\n' "$msg" >&2
    if [ "$rc" -eq 0 ]; then
        esc="${msg//\\/\\\\}"
        esc="${esc//\"/\\\"}"
        esc="${esc//$'\n'/\\n}"
        esc="${esc//$'\t'/ }"
        esc="${esc//$'\r'/ }"
        printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$esc"
    fi
    exit "$rc"
}

none_event() {
    emit_hook_event "delegation" "{\"score\":0,\"total\":$DUTY_TOTAL,\"missing\":\"\",\"mode\":\"$MODE_WF_DUTY\",\"tool\":\"Workflow\",\"checked\":0,\"scope\":\"script\"}"
}

# --- Only Workflow launches are checked ---
# With perl, perl reads stdin itself and checks tool_name (keeping a 500 KB
# payload out of bash variables saves ~20 ms). Without perl, bash does.
if ! command -v perl >/dev/null 2>&1; then
    input=$(cat)
    _tool_re='"tool_name"[[:space:]]*:[[:space:]]*"Workflow"'
    if ! [[ "$input" =~ $_tool_re ]]; then
        exit 0
    fi
    none_event
    finish 0 "$REMINDER"$'\n'"[workflow-guard] perl not found: duty elements not checked."
fi

# --- The checker (Perl, core only) ---
# Output: line 1 status (skip | agents | fallback:<reason> | none:<reason>),
# line 2 gap (1 when a checked text misses an element), line 3 the union of
# missing elements (csv), then the message lines after the reminder.
# perl appends the telemetry events itself (WDG_EVENTS, when set): one bash
# loop per event cost ~40 ms on a 270-agent script.
# read -d '' returns 1 at the end of the here-document (expected); the
# result is checked right below.
WDG_PERL=""
IFS= read -r -d '' WDG_PERL <<'WDG_PERL_EOF' || true
use strict;
my ($MAXB, $CHARS, $MODE) = ($ENV{WDG_MAX}, $ENV{WDG_CHARS}, $ENV{WDG_MODE});
my @EV;
sub ev {
    my ($s, $m, $c, $scope, $label) = @_;
    my $j = "{\"score\":$s,\"total\":8,\"missing\":\"$m\",\"mode\":\"$MODE\",\"tool\":\"Workflow\",\"checked\":$c,\"scope\":\"$scope\"";
    $j .= ",\"agent\":\"$label\"" if defined $label;
    push @EV, "$j}";
}
sub out {
    my ($st, $gap, $union, @lines) = @_;
    my $f = $ENV{WDG_EVENTS};
    if (defined $f && $f ne "" && @EV) {
        my @g = gmtime;
        my $ts = sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $g[5] + 1900, $g[4] + 1, @g[3, 2, 1, 0]);
        # Telemetry is best effort: an unwritable log must not fail the hook.
        if (open(my $o, ">>", $f)) {
            print $o "{\"t\":\"$ts\",\"type\":\"delegation\",\"src\":\"wdg\",\"d\":$_}\n" for @EV;
            close($o);
        }
    }
    print "$st\n$gap\n$union\n";
    print "$_\n" for @lines;
    exit 0;
}
my $in = do { local $/; <STDIN> };
$in = "" unless defined $in;
# The manifest matcher is Workflow; a mis-registered or manually piped
# payload of another tool stays silent.
out("skip", 0, "") if $in !~ /"tool_name"\s*:\s*"Workflow"/;

# --- Script text: tool_input.script, else the scriptPath file ---
my $tip = ($in =~ /"tool_input"\s*:\s*\{/g) ? pos($in) : 0;
sub jfield {
    my ($name) = @_;
    pos($in) = $tip;
    return undef unless $in =~ /"\Q$name\E"\s*:\s*"/g;
    my $s = pos($in);
    1 while $in =~ /\G(?:[^"\\]+|\\.)/gcs;
    return substr($in, $s, pos($in) - $s);
}
my %JE = (n => "\n", t => "\t", r => "\r", b => "\b", f => "\f");
sub junesc {
    my ($t) = @_;
    $t =~ s/\\(?:u([0-9a-fA-F]{4})|(.))/defined $1 ? chr(hex $1) : (exists $JE{$2} ? $JE{$2} : $2)/gse;
    return $t;
}
my ($src, $status) = (undef, "");
my $raw = jfield("script");
if (defined $raw) {
    $src = junesc($raw);
} else {
    my $p = jfield("scriptPath");
    if (defined $p) {
        $p = junesc($p);
        if ($p !~ m{^(?:/|~|[A-Za-z]:[\\/])}) {
            pos($in) = 0;
            if ($in =~ /"cwd"\s*:\s*"((?:[^"\\]|\\.)*)"/) { $p = junesc($1) . "/$p"; }
        }
        $p =~ s{^~(?=/)}{$ENV{HOME} // ""}e;
        if (-f $p && -r _ && -s _ <= $MAXB) {
            if (open(my $fh, "<", $p)) { local $/; $src = <$fh> // ""; close($fh); }
            else { $status = "none:scriptPath unreadable"; }
        } else {
            $status = "none:scriptPath missing, unreadable or over 512 KB";
        }
    } else {
        $status = "none:no script or scriptPath in the input";
    }
}
if (!defined $src) {
    $status ||= "none:no script text";
    ev(0, "", 0, "script");
    out($status, 0, "");
}
$src = substr($src, 0, $MAXB);

# --- Scoring: the eight elements, shared verbatim with delegation-duty-guard.sh ---
sub score_text {
    local $_ = substr($_[0], 0, $CHARS);
    my $score = 0;
    my (@missing, @present);
    my $check = sub {
        my ($name, $ok) = @_;
        if ($ok) { $score++; push @present, $name; } else { push @missing, $name; }
    };
        # --- BEGIN delegation elements block ---
        # 1. Identity (role name)
        $check->("identity", /you\s+are|your\s+identity|your\s+role/i || /(?<![A-Za-z0-9])S[1-9](?![A-Za-z0-9])/);

        # 2. Rules AND CLAUDE.md files (both must be mentioned)
        $check->("rules", /CLAUDE\.md/i && /\brules?\b/i);

        # 3. Skills, /delegate first
        $check->("skills", /\/delegate\b|delegate\s+skill|skills[\/\\]+delegate\b/i);

        # 4. Operational learning
        $check->("OL", /operational\s+learning|carry[\s-]+forward|OL-/i);

        # 5. Conflict priority (D-DEL6)
        $check->("conflict", /D-DEL6|CONFLICT:/ || /conflict\s+priority/i);

        # 6. WRITE_BLOCKED signal
        $check->("WRITE_BLOCKED", /WRITE_BLOCKED/);

        # 7. Access: explicit / absolute paths
        $check->("access", /explicit\s+(?:absolute\s+)?paths|absolute\s+paths?|Glob\/Grep|cross-repo|OL-O12|(?<![\w.])(?:\/Users\/|\/home\/|\/root\/|\/tmp\/|~\/)[\w.-]|\b[A-Za-z]:[\\\/][\w.-]/i);

        # 8. Markdown name prefix (D-DEL1)
        my $md = qr/(?:\.md\b|markdown)/i;
        my $pfx = qr/(?:name.{0,60}?prefix|prefix.{0,60}?name|(?:start|begin)s?\s+with\s+(?:your|the)\s+(?:agent\s+)?name)/is;
        # The phrase may also wrap the extension: "Name every .md file with the prefix S2-".
        # Only windows around the first 200 ".md"/"markdown" hits are searched,
        # which bounds the backtracking on adversarial text (review N2, PR #122).
        my $mdp = /D-DEL1/ ? 1 : 0;
        my ($hits, $all) = (0, $_);
        while (!$mdp && $hits < 200 && $all =~ /$md/g) {
            $hits++;
            my $s = $-[0] - 250; $s = 0 if $s < 0;
            my $w = substr($all, $s, 500 + $+[0] - $-[0]);
            $mdp = 1 if $w =~ /$pfx.{0,160}?$md/is || $w =~ /$md.{0,160}?$pfx/is
                || $w =~ /name.{0,80}?$md.{0,80}?prefix/is || $w =~ /prefix.{0,80}?$md.{0,80}?name/is;
        }
        $check->("md-prefix", $mdp);
        # --- END delegation elements block ---
    return ($score, join(",", @missing));
}

# --- Lexer: token = [type (id|str|tpl|num|re|p), value, start, end] ---
my %SE = (n => "\n", t => "\t", r => "\r", b => "\b", f => "\f", v => "\x0b", 0 => "\0");
sub jsdecode {
    my ($x) = @_;
    $x =~ s/\\(?:u\{([0-9a-fA-F]{1,6})\}|u([0-9a-fA-F]{4})|x([0-9a-fA-F]{2})|(\r?\n)|(.))/
        defined $1 ? (hex($1) > 0x10FFFF ? "?" : chr(hex $1)) : defined $2 ? chr(hex $2)
        : defined $3 ? chr(hex $3) : defined $4 ? "" : (exists $SE{$5} ? $SE{$5} : $5)/gsex;
    return $x;
}
my $KW_RE = qr/^(?:return|typeof|instanceof|in|of|new|delete|void|throw|case|do|else|yield|await)$/;
my %KW = map { $_ => 1 } qw(return typeof instanceof in of new delete void throw case do else yield await);
sub lex {
    my ($in_expr, $nest) = @_;
    die "nesting too deep\n" if $nest > 64;
    my (@t, $p);
    my ($brace, $re_ok) = (0, 1);
    while (1) {
        $src =~ /\G(?:\s+|\/\/[^\n]*)*/gc;
        $p = pos($src) // 0;
        if ($src =~ /\G([A-Za-z_\$][\w\$]*)/gc) {
            my $v = $1;
            push @t, ["id", $v, $p, pos($src)];
            $re_ok = $KW{$v} ? 1 : 0;
            next;
        }
        if ($p >= length($src)) {
            die "unterminated template expression\n" if $in_expr;
            last;
        }
        if ($src =~ /\G\/\*/gc) {
            $src =~ /\G.*?\*\//gcs or die "unterminated comment\n";
            next;
        }
        if ($src =~ /\G(['"])/gc) {
            my $q = $1;
            my $s = pos($src);
            if ($q eq "'") { 1 while $src =~ /\G(?:[^'\\\n]+|\\.)/gcs; }
            else           { 1 while $src =~ /\G(?:[^"\\\n]+|\\.)/gcs; }
            my $e = pos($src);
            $src =~ /\G\Q$q\E/gc or die "unterminated string\n";
            push @t, ["str", jsdecode(substr($src, $s, $e - $s)), $p, pos($src)];
            $re_ok = 0;
            next;
        }
        if ($src =~ /\G`/gc) {
            my $parts = lex_tpl($nest);
            push @t, ["tpl", $parts, $p, pos($src)];
            $re_ok = 0;
            next;
        }
        if ($re_ok && $src =~ /\G\/(?:[^\/\\\[\n]|\\.|\[(?:[^\]\\\n]|\\.)*\])+\/[A-Za-z]*/gc) {
            push @t, ["re", "", $p, pos($src)];
            $re_ok = 0;
            next;
        }
        if ($src =~ /\G(?:\d[\w.]*|\.\d[\w.]*)/gc) {
            push @t, ["num", "", $p, pos($src)];
            $re_ok = 0;
            next;
        }
        $src =~ /\G(=>|\.\.\.|\?\.|===|!==|==|!=|<=|>=|&&|\|\||\?\?|\+\+|--|\*\*|[-+*\/%&|^]=|.)/gcs;
        my $v = $1;
        if ($v eq "{") { $brace++; }
        elsif ($v eq "}") {
            return \@t if $in_expr && $brace == 0;
            $brace--;
        }
        push @t, ["p", $v, $p, pos($src)];
        $re_ok = ($v =~ /^(?:\)|\]|\+\+|--)$/) ? 0 : 1;
    }
    return \@t;
}
sub lex_tpl {
    my ($nest) = @_;
    my @parts;
    while (1) {
        my $s = pos($src);
        1 while $src =~ /\G(?:[^`\\\$]+|\\.|\$(?!\{))/gcs;
        push @parts, ["lit", jsdecode(substr($src, $s, pos($src) - $s))] if pos($src) > $s;
        return \@parts if $src =~ /\G`/gc;
        if ($src =~ /\G\$\{/gc) {
            my $es = pos($src);
            my $toks = lex(1, $nest + 1);
            push @parts, ["expr", substr($src, $es, pos($src) - 1 - $es), $toks];
            next;
        }
        die "unterminated template\n";
    }
}

# --- Constants and resolution ---
my (%const, %memo);
my $budget = 8 * 1048576;
sub is_p { my ($tk, $v) = @_; return $tk && $tk->[0] eq "p" && $tk->[1] eq $v; }
sub add_text {
    my ($out, $v) = @_;
    $budget -= length($v);
    die "resolution budget exceeded\n" if $budget < 0;
    $$out .= $v if length($$out) < $MAXB;
}
# parse_expr(tokens, index, resolve?, const depth, seen, paren depth)
#   -> ("ok", text, next index) | ("un", reason, index)
sub parse_expr {
    my ($A, $j, $res, $d, $seen, $pd) = @_;
    return ("un", "expression too deep", $j) if $pd > 64;
    my $out = "";
    while (1) {
        my $tk = $A->[$j];
        return ("un", "no prompt", $j) unless $tk;
        my $v = "";
        if ($tk->[0] eq "str") { $v = $tk->[1]; $j++; }
        elsif ($tk->[0] eq "tpl") { $v = tpl_text($tk, $d, $seen) if $res; $j++; }
        elsif ($tk->[0] eq "id") {
            my $nx = $A->[$j + 1];
            return ("un", "call", $j) if is_p($nx, "(");
            return ("un", "member access", $j) if $nx && $nx->[0] eq "p" && $nx->[1] =~ /^(?:\.|\?\.|\[)$/;
            return ("un", "tagged template", $j) if $nx && $nx->[0] eq "tpl";
            return ("un", "expression", $j) if $tk->[1] =~ $KW_RE || $tk->[1] =~ /^(?:function|async|true|false|null|undefined|this)$/;
            if ($res) {
                my ($st, $tx) = resolve($tk->[1], $d + 1, $seen);
                return ("un", $tx, $j) if $st ne "ok";
                $v = $tx;
            }
            $j++;
        }
        elsif (is_p($tk, "(")) {
            my ($st, $tx, $k) = parse_expr($A, $j + 1, $res, $d, $seen, $pd + 1);
            return ($st, $tx, $k) if $st ne "ok";
            return ("un", "expression", $k) unless is_p($A->[$k], ")");
            $v = $tx;
            $j = $k + 1;
        }
        elsif (is_p($tk, "{")) { return ("un", "object argument", $j); }
        elsif (is_p($tk, ")") && $out eq "") { return ("un", "no prompt", $j); }
        else { return ("un", "expression", $j); }
        add_text(\$out, $v) if $res;
        my $nx = $A->[$j];
        if (is_p($nx, "+")) { $j++; next; }
        return ("un", "ternary", $j) if is_p($nx, "?");
        return ("ok", $out, $j);
    }
}
sub resolve {
    my ($n, $d, $seen) = @_;
    return ("ok", $memo{$n}) if exists $memo{$n};
    my $c = $const{$n};
    return ("un", "identifier $n is not a string constant") unless $c;
    return ("un", "constant nesting over 10") if $d > 10;
    return ("un", "constant cycle at $n") if $seen->{$n};
    local $seen->{$n} = 1;
    my ($st, $tx) = parse_expr($c->[0], $c->[1], 1, $d, $seen, 0);
    $memo{$n} = $tx if $st eq "ok";
    return ($st, $tx);
}
sub tpl_text {
    my ($tk, $d, $seen) = @_;
    my $out = "";
    for my $part (@{ $tk->[1] }) {
        if ($part->[0] eq "lit") { add_text(\$out, $part->[1]); next; }
        my $v = "\${" . $part->[1] . "}";
        if ($part->[1] =~ /^\s*([A-Za-z_\$][\w\$]*)\s*$/ && $1 !~ $KW_RE) {
            my ($st, $tx) = resolve($1, $d + 1, $seen);
            $v = $tx if $st eq "ok";
        }
        add_text(\$out, $v);
    }
    return $out;
}
# Every token array: the top level and each ${...} of each template.
sub arrays {
    my ($A, $acc) = @_;
    push @$acc, $A;
    for my $tk (@$A) {
        next unless $tk->[0] eq "tpl";
        for my $part (@{ $tk->[1] }) { arrays($part->[2], $acc) if $part->[0] eq "expr"; }
    }
    return $acc;
}
sub stmt_end {
    my ($A, $k) = @_;
    my $nx = $A->[$k];
    return 1 unless $nx;
    return 1 if $nx->[0] eq "p" && $nx->[1] =~ /^[;,)\]}]$/;
    return 0 if $nx->[0] eq "p" || $nx->[0] eq "tpl";
    my $prev = $A->[$k - 1];
    return index(substr($src, $prev->[3], $nx->[2] - $prev->[3]), "\n") >= 0 ? 1 : 0;
}
my @nl;
sub line_of {
    my ($p) = @_;
    if (!@nl) { push @nl, 0; pos($src) = 0; while ($src =~ /\n/g) { push @nl, pos($src); } }
    my ($lo, $hi) = (0, $#nl);
    while ($lo < $hi) { my $m = int(($lo + $hi + 1) / 2); if ($nl[$m] <= $p) { $lo = $m; } else { $hi = $m - 1; } }
    return $lo + 1;
}
sub clean { my ($x, $n) = @_; $x =~ s/[^A-Za-z0-9 :#._\/-]//g; return substr($x, 0, $n); }
sub find_label {
    my ($A, $k) = @_;
    return undef unless is_p($A->[$k], ",") && is_p($A->[$k + 1], "{");
    my $dep = 0;
    for (my $i = $k + 2; $i < @$A && $i < $k + 2000; $i++) {
        my $tk = $A->[$i];
        if ($tk->[0] eq "p" && $tk->[1] =~ /^[(\[{]$/) { $dep++; next; }
        if ($tk->[0] eq "p" && $tk->[1] =~ /^[)\]}]$/) { last if $dep == 0; $dep--; next; }
        next if $dep;
        next unless ($tk->[0] eq "id" || $tk->[0] eq "str") && $tk->[1] eq "label" && is_p($A->[$i + 1], ":");
        my ($vt, $after) = ($A->[$i + 2], $A->[$i + 3]);
        return undef unless $vt && ($vt->[0] eq "str" || $vt->[0] eq "tpl");
        return undef unless is_p($after, ",") || is_p($after, "}");
        return $vt->[0] eq "str" ? $vt->[1] : tpl_text($vt, 0, {});
    }
    return undef;
}

# --- Extraction under the time guard ---
my @sites;
my $fail = "";
my $ok = eval {
    local $SIG{ALRM} = sub { die "time guard (2 s)\n" };
    alarm 2;
    pos($src) = 0;
    my $top = lex(0, 0);
    my $all = arrays($top, []);
    for my $A (@$all) {
        for (my $i = 0; $i + 3 < @$A; $i++) {
            next unless $A->[$i][0] eq "id" && $A->[$i][1] =~ /^(?:const|let|var)$/;
            next unless $A->[$i + 1][0] eq "id" && is_p($A->[$i + 2], "=");
            my ($st, undef, $k) = parse_expr($A, $i + 3, 0, 0, {}, 0);
            next unless $st eq "ok" && stmt_end($A, $k);
            $const{ $A->[$i + 1][1] } //= [$A, $i + 3];
        }
    }
    for my $A (@$all) {
        for (my $i = 0; $i < @$A; $i++) {
            my $tk = $A->[$i];
            next unless $tk->[0] eq "id" && $tk->[1] eq "agent" && is_p($A->[$i + 1], "(");
            my $pv = $i > 0 ? $A->[$i - 1] : undef;
            next if $pv && (is_p($pv, ".") || is_p($pv, "?.") || ($pv->[0] eq "id" && $pv->[1] eq "function"));
            my ($st, $tx, $k) = parse_expr($A, $i + 2, 1, 0, {}, 0);
            if ($st eq "ok" && !(is_p($A->[$k], ",") || is_p($A->[$k], ")"))) {
                ($st, $tx) = ("un", is_p($A->[$k], "?") ? "ternary" : "expression");
            }
            my $label = ($st eq "ok") ? find_label($A, $k) : undef;
            if (!defined $label && $st ne "ok") {
                # skip the first argument to reach the options object
                my ($dep, $m) = (0, $i + 2);
                for (; $m < @$A && $m < $i + 20000; $m++) {
                    my $x = $A->[$m];
                    if ($x->[0] eq "p" && $x->[1] =~ /^[(\[{]$/) { $dep++; next; }
                    if ($x->[0] eq "p" && $x->[1] =~ /^[)\]}]$/) { last if $dep == 0; $dep--; next; }
                    last if $dep == 0 && is_p($x, ",");
                }
                $label = find_label($A, $m);
            }
            $label = clean(defined $label ? $label : "", 60);
            $label = "agent\@L" . line_of($tk->[2]) if $label eq "";
            my %r = (label => $label, ok => ($st eq "ok" ? 1 : 0), reason => clean($tx, 80));
            if ($r{ok}) { @r{qw(score missing)} = score_text($tx); }
            push @sites, \%r;
        }
    }
    alarm 0;
    1;
};
alarm 0;
if (!$ok) { ($fail = $@ || "parser error") =~ s/\s+$//; @sites = (); }
elsif (!@sites) { $fail = "no agent() call found"; }

if ($fail ne "") {
    my ($s, $m) = score_text($src);
    (my $why = substr($fail, 0, 80)) =~ s/[^A-Za-z0-9 :#._\/()-]//g;
    ev($s, $m, 1, "script");
    out("fallback:$why", ($s < 8 ? 1 : 0), $m,
        "[workflow-guard] per-agent() extraction failed ($why); the script was checked as one text: $s/8, missing " . ($m eq "" ? "none" : $m) . ".");
}
my ($n, $full, $un) = (scalar(@sites), 0, 0);
my %miss;
for my $r (@sites) {
    if ($r->{ok}) {
        $full++ if $r->{score} >= 8;
        $miss{$_} = 1 for grep { $_ ne "" } split /,/, $r->{missing};
        ev($r->{score}, $r->{missing}, 1, "agent", $r->{label});
    } else {
        $un++;
        ev(0, "", 0, "agent", $r->{label});
    }
}
my @L = ("[workflow-guard] Workflow: $n agent() prompts, $full with all eight, $un unresolved.");
# Worst first: scored prompts with gaps (lowest score first), then unresolved.
my @worst = sort { $a->{score} <=> $b->{score} } grep { $_->{ok} && $_->{score} < 8 } @sites;
push @worst, grep { !$_->{ok} } @sites;
for my $r (@worst[0 .. ($#worst < 4 ? $#worst : 4)]) {
    push @L, $r->{ok} ? "  $r->{label} $r->{score}/8 missing $r->{missing}" : "  $r->{label} unresolved ($r->{reason})";
}
push @L, "  ... and " . (@worst - 5) . " more" if @worst > 5;
my @order = qw(identity rules skills OL conflict WRITE_BLOCKED access md-prefix);
out("agents", (%miss ? 1 : 0), join(",", grep { $miss{$_} } @order), @L);
WDG_PERL_EOF
if [ -z "$WDG_PERL" ]; then
    none_event
    finish 0 "$REMINDER"$'\n'"[workflow-guard] checker source missing: duty elements not checked."
fi

# perl's stderr is discarded (warnings on odd input are noise for Claude);
# its exit code and output are checked right below.
_events=""
[ -z "$_SESSION_DIR" ] || _events="$_SESSION_DIR/events.jsonl"
rc=0
result=$(WDG_MAX="$SCRIPT_MAX_BYTES" WDG_CHARS="$CHECK_MAX_CHARS" WDG_MODE="$MODE_WF_DUTY" \
    WDG_EVENTS="$_events" perl -e "$WDG_PERL" 2>/dev/null) || rc=$?

# Header: status, gap, union (one line each), then the message lines.
status="${result%%$'\n'*}"
rest="${result#*$'\n'}"
gap="${rest%%$'\n'*}"
rest="${rest#*$'\n'}"
union="${rest%%$'\n'*}"
lines=""
case "$rest" in *$'\n'*) lines="${rest#*$'\n'}" ;; esac

if [ "$rc" -ne 0 ] || [ -z "$status" ] || [ "$status" = "$result" ]; then
    none_event
    finish 0 "$REMINDER"$'\n'"[workflow-guard] the checker failed (perl exit $rc): duty elements not checked."
fi

case "$status" in
    skip)
        exit 0
        ;;
    none:*)
        finish 0 "$REMINDER"$'\n'"[workflow-guard] Workflow: ${status#none:}; duty elements not checked."
        ;;
esac

# --- Per-element guidance for the elements missing in any prompt ---
guidance=""
case ",$union," in
    *,identity,*)
        guidance="${guidance} Identity: give the delegate a name and role (e.g. 'You are S3-Alpha')." ;;
esac
case ",$union," in
    *,rules,*)
        guidance="${guidance} Rules and CLAUDE.md: tell the delegate to read in full every user- and project-scope CLAUDE.md and rule (~/.claude/CLAUDE.md, ~/.claude/rules/*.md, <repo>/CLAUDE.md, <repo>/.claude/rules/*.md), by absolute path." ;;
esac
case ",$union," in
    *,skills,*)
        guidance="${guidance} Skills: tell the delegate to load /delegate first, before any delegate of its own, and to pass that on; then name the task skills." ;;
esac
case ",$union," in
    *,OL,*)
        guidance="${guidance} OL: include the operational learning relevant to the task, with sources." ;;
esac
case ",$union," in
    *,conflict,*)
        guidance="${guidance} Conflict priority (D-DEL6): commander's words newest first, then the prompt, then skills; report CONFLICT: lines." ;;
esac
case ",$union," in
    *,WRITE_BLOCKED,*)
        guidance="${guidance} WRITE_BLOCKED: on a denied write or tool call, output 'WRITE_BLOCKED: <what> -- <denial text>' and do not route around it." ;;
esac
case ",$union," in
    *,access,*)
        guidance="${guidance} Access: give absolute paths to every file and directory, including the delegate's scratch dir." ;;
esac
case ",$union," in
    *,md-prefix,*)
        guidance="${guidance} Name prefix (D-DEL1): tell the delegate to start every .md file name with its name, e.g. 'S2-report.md'." ;;
esac

msg="$REMINDER"$'\n'"${lines%$'\n'}"
if [ -n "$guidance" ]; then
    msg="${msg}"$'\n'"[workflow-guard] Guidance:${guidance} See the /delegate skill."
fi

if [ "$MODE_WF_DUTY" = "enforce" ] && [ "$gap" = "1" ]; then
    finish 2 "$msg"
fi

# OBSERVE mode (or no gap): allow, with the reminder, summary and guidance
finish 0 "$msg"
