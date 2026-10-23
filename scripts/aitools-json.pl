#!/usr/bin/env perl
# aitools-json.pl -- order-preserving JSON reader/writer for the bash scripts
#
# Intent (DRAFT, awaiting commander approval): Give bash scripts one JSON engine
# that needs only core perl (no modules, no node), keeps key order, and writes
# the node JSON.stringify(v, null, 2) layout, so bash, PowerShell
# (ConvertTo-Json, aitools-json.ps1) and node writers of the same shared file
# produce the same bytes. NOT a policy layer: it reads, edits and validates
# what its caller asks; it decides nothing about profiles or config. NOT for
# PowerShell (aitools-json.ps1 is the PowerShell side). Consumed by:
# aitools-profile.sh, setup-user-config.sh.
#
# Usage: perl aitools-json.pl <command> FILE [KEY...]   (paths as separate keys)
# Platform: macOS/Linux bash callers (any perl 5.10+). Safe to re-run: only
#   `edit` writes, and only its OUT file.
#
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
#                           rename<TAB>NEW<TAB>SEG...  (last SEG = the key to
#                             rename; it keeps its position and value). Errors
#                             (exit 2, nothing written): "rename: no key given",
#                             "rename: new key is empty",
#                             "rename: '<seg>' not found" (a path segment or the
#                             key is absent), "rename: '<seg>' is not an object",
#                             "rename: '<NEW>' already exists" (another key equals
#                             NEW ignoring case (Unicode, keys read as UTF-8), as
#                             PowerShell property names do). NEW equal to the key is a no-op; a case-only
#                             rename (ABC -> abc) is allowed. Segments match exactly.
#   snapshot FILE           compact {version, identity, cursor, profiles}
#   tagged2json             key<TAB>value lines on stdin -> one compact object
#                           (warn/error lines collected into warnings/errors)
# For get/type/keys/items/json: 4 = FILE missing, 2 = FILE invalid.

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
# renp ROOT NEW SEG... -- rename the key named by the last SEG to NEW in place
sub renp {
    my ($root, $new, @segs) = @_;
    die "rename: no key given\n" unless defined $new && @segs;
    die "rename: new key is empty\n" if $new eq '';
    my $old = pop @segs;
    my $v = $root;
    for my $s (@segs) {
        my $n;
        for my $p (@{$v->[1]}) { if ($p->[0] eq $s) { $n = $p->[1]; last } }
        die "rename: '$s' not found\n" unless defined $n;
        die "rename: '$s' is not an object\n" unless $n->[0] eq 'O';
        $v = $n;
    }
    my $hit;
    for my $p (@{$v->[1]}) { if ($p->[0] eq $old) { $hit = $p; last } }
    die "rename: '$old' not found\n" unless $hit;
    return if $new eq $old;
    my $fold = sub { my $s = $_[0]; utf8::decode($s); return lc $s };  # keys are UTF-8 bytes
    my $want = $fold->($new);
    for my $p (@{$v->[1]}) {
        next if $p == $hit;
        die "rename: '$new' already exists\n" if $fold->($p->[0]) eq $want;
    }
    $hit->[0] = $new;
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
            elsif ($op eq 'rename') { my $new = shift @f; renp($root, $new, @f) }
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
