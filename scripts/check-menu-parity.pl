#!/usr/bin/env perl
# check-menu-parity.pl -- check-post-push step 29 "Deployment menu parity
# audit": the bash and PowerShell libraries offer the same menu choices
# (.claude/rules/interactive-menus.md "Cross-platform parity"). Safe to re-run:
# reads only.
#
# Usage:
#   perl scripts/check-menu-parity.pl BASH_LIB PS1_LIB
#   perl scripts/check-menu-parity.pl --help
#
# Two comparisons, full-line comments (# ...) skipped in both files:
#   menu lines  the [x] (one letter) on each printf line (bash) and each
#               [Console]::Write / WriteLine line (PowerShell), the last one
#               on the line; one sorted set per file (step 29 before v0.77.2)
#   prompts     each call of the menu-read helper: read_menu_choice (bash, its
#               6th argument PROMPT) and Read-MenuChoice (PowerShell, -Prompt).
#               The prompt's [x] letters and [a/b/c] lists make one sorted set
#               per call; the files match when their lists of sets match (the
#               order of the calls is not compared). A prompt with no letter
#               counts as "?", so it still has to exist on both sides.
# A prompt given as a variable ("$p", $p, ${p}) takes the last literal
# assigned to it on an earlier line of the same file (bash p="..." or
# local p='...'; PowerShell $p = "..."), without regard to control flow.
#
# Blind spots (a static check): letters built at run time ("[$(...)]",
# $($valid -join '/')) are not seen (the prompt counts as "?"); a variable
# assigned in another function or file, by concatenation, or not at all
# counts as "?"; a call split over lines without a trailing \ (bash) or `
# (PowerShell); PowerShell -Prompt abbreviated, written -Prompt:value,
# positional or splatted (the prompt counts as "?"), and calls inside <# #>
# block comments or here-strings (they count); a menu line's letters
# other than its last [x]; a helper called under another name (a wrapper).
#
# Output: detail lines ("  bash:LINE n,r,y", one per call), then one summary
# line: "menus a,m,o,s,x; prompts ?|a,m,o,s,x|n,r,y|o,s,x" on a match, or what
# differs. Exit: 0 match; 1 mismatch, or nothing found in either file; 2
# usage or read error.
# Platform: any perl 5 (macOS, Linux, Windows Git Bash or Strawberry perl).
# Called by: scripts/check-post-push.sh and .ps1, step 29.
# Tests: tests/check-post-push/test-menu-parity.sh.
use strict;
use warnings;

if (@ARGV && ($ARGV[0] eq "--help" || $ARGV[0] eq "-h")) {
    open(my $self, "<", $0) or do { print STDERR "check-menu-parity: cannot read $0: $!\n"; exit 2 };
    while (my $l = <$self>) {
        last if $. > 1 && $l !~ /^#/;
        next if $. == 1;
        $l =~ s/^# ?//;
        print $l;
    }
    close($self);
    exit 0;
}
if (@ARGV != 2) {
    print STDERR "check-menu-parity: usage: perl scripts/check-menu-parity.pl BASH_LIB PS1_LIB (--help)\n";
    exit 2;
}

# read_lines <file>: the file's lines, line endings removed (CRLF included)
sub read_lines {
    my ($f) = @_;
    open(my $fh, "<", $f) or do { print "cannot read $f: $!\n"; exit 2 };
    my @l = <$fh>;
    close($fh);
    s/\r?\n\z// for @l;
    return \@l;
}

# logical_lines <lines> <continuation char>: [first line number, text] per
# statement line: full-line comments dropped, a line ending in the
# continuation character joined with the next
sub logical_lines {
    my ($lines, $cont) = @_;
    my @out;
    my ($buf, $start);
    for my $i (0 .. $#$lines) {
        my $l = $lines->[$i];
        if (!defined $buf) {
            next if $l =~ /^\s*#/;
            ($buf, $start) = ("", $i + 1);
        }
        if (substr($l, -1) eq $cont) {
            $buf .= substr($l, 0, -1) . " ";
            next;
        }
        push @out, [$start, $buf . $l];
        undef $buf;
    }
    push @out, [$start, $buf] if defined $buf;
    return \@out;
}

# letters <prompt>: the sorted set of choice letters in a prompt, "?" if none
sub letters {
    my ($p) = @_;
    return "?" unless defined $p;
    my %s;
    while ($p =~ /\[(\w)\]|\[(\w(?:\/\w)+)\]/g) {
        if (defined $1) { $s{$1} = 1 } else { $s{$_} = 1 for split m{/}, $2 }
    }
    return %s ? join(",", sort keys %s) : "?";
}

# ---- bash ----------------------------------------------------------------

# sh_dq <s> <i>: a double-quoted string from after its opening quote;
# returns (text, index after the closing quote). $(...) is kept raw.
sub sh_dq {
    my ($s, $i) = @_;
    my ($txt, $n) = ("", length $s);
    while ($i < $n) {
        my $c = substr($s, $i, 1);
        return ($txt, $i + 1) if $c eq '"';
        if ($c eq "\\") {
            my $x = substr($s, $i + 1, 1);
            $txt .= ($x =~ /[\$`"\\]/) ? $x : "\\$x";
            $i += 2;
            next;
        }
        if ($c eq '$' && substr($s, $i + 1, 1) eq '(') {
            my $j = sh_subst_end($s, $i + 2);
            $txt .= substr($s, $i, $j - $i);
            $i = $j;
            next;
        }
        $txt .= $c;
        $i++;
    }
    return ($txt, $n);
}

# sh_subst_end <s> <i>: from after "$(", the index after its matching ")"
sub sh_subst_end {
    my ($s, $i) = @_;
    my ($d, $n) = (1, length $s);
    while ($i < $n) {
        my $c = substr($s, $i, 1);
        if ($c eq "'") { my $j = index($s, "'", $i + 1); $i = $j < 0 ? $n : $j + 1; next }
        if ($c eq '"') { my (undef, $j) = sh_dq($s, $i + 1); $i = $j; next }
        if ($c eq "\\") { $i += 2; next }
        if ($c eq '(') { $d++ }
        elsif ($c eq ')') { $d--; return $i + 1 if $d == 0 }
        $i++;
    }
    return $n;
}

# sh_tokens <s>: shell words with quotes removed; ; & | are tokens of their
# own; an unquoted # at the start of a word ends the line
sub sh_tokens {
    my ($s) = @_;
    my @t;
    my $cur;
    my ($i, $n) = (0, length $s);
    while ($i < $n) {
        my $c = substr($s, $i, 1);
        if ($c =~ /\s/) { push @t, $cur if defined $cur; undef $cur; $i++; next }
        last if !defined $cur && $c eq '#';
        if ($c =~ /[;&|]/) { push @t, $cur if defined $cur; undef $cur; push @t, $c; $i++; next }
        $cur = "" unless defined $cur;
        if ($c eq "'") {
            my $j = index($s, "'", $i + 1);
            $j = $n if $j < 0;
            $cur .= substr($s, $i + 1, $j - $i - 1);
            $i = $j + 1;
            next;
        }
        if ($c eq '"') { my ($txt, $j) = sh_dq($s, $i + 1); $cur .= $txt; $i = $j; next }
        if ($c eq "\\") { $cur .= substr($s, $i + 1, 1); $i += 2; next }
        if ($c eq '$' && substr($s, $i + 1, 1) eq '(') {
            my $j = sh_subst_end($s, $i + 2);
            $cur .= substr($s, $i, $j - $i);
            $i = $j;
            next;
        }
        $cur .= $c;
        $i++;
    }
    push @t, $cur if defined $cur;
    return @t;
}

# sh_prompts <file>: [line, prompt or undef] per read_menu_choice call
sub sh_prompts {
    my ($f) = @_;
    my $ll = logical_lines(read_lines($f), "\\");
    my %cmd_start = map { $_ => 1 } (";", "&", "|", "then", "do", "else", "{", "(", "!", "elif", "if", "while", "until");
    my @calls;
    my @prior;    # tokens of earlier logical lines, for variable lookup
    for my $l (@$ll) {
        my @t = sh_tokens($l->[1]);
        for my $k (0 .. $#t) {
            next unless $t[$k] eq "read_menu_choice";
            next unless $k == 0 || $cmd_start{$t[$k - 1]};
            my @args;
            for my $a (@t[$k + 1 .. $#t]) {
                last if $a =~ /^[;&|]$/;
                push @args, $a;
            }
            my $p = $args[5];
            if (defined $p && $p =~ /^\$\{?(\w+)\}?$/) {
                my $name = $1;
                undef $p;
                for my $tok (@prior) { $p = $1 if $tok =~ /^\Q$name\E=(.*)\z/s }
            }
            push @calls, [$l->[0], $p];
        }
        push @prior, @t;
    }
    return \@calls;
}

# ---- PowerShell ----------------------------------------------------------

# ps_paren_end <s> <i> <open> <close>: from after an opening bracket, the
# index after its match; strings inside are skipped
sub ps_paren_end {
    my ($s, $i, $o, $c) = @_;
    my ($d, $n) = (1, length $s);
    while ($i < $n) {
        my $ch = substr($s, $i, 1);
        if ($ch eq '"') { my (undef, $j) = ps_dq($s, $i + 1); $i = $j; next }
        if ($ch eq "'") { my (undef, $j) = ps_sq($s, $i + 1); $i = $j; next }
        if ($ch eq '`') { $i += 2; next }
        if ($ch eq $o) { $d++ }
        elsif ($ch eq $c) { $d--; return $i + 1 if $d == 0 }
        $i++;
    }
    return $n;
}

# ps_dq <s> <i>: an expandable string from after its opening quote; returns
# (text, index after the closing quote). $(...) is kept raw; `x and "" are
# escapes.
sub ps_dq {
    my ($s, $i) = @_;
    my ($txt, $n) = ("", length $s);
    while ($i < $n) {
        my $c = substr($s, $i, 1);
        if ($c eq '"') {
            if (substr($s, $i + 1, 1) eq '"') { $txt .= '"'; $i += 2; next }
            return ($txt, $i + 1);
        }
        if ($c eq '`') { $txt .= substr($s, $i + 1, 1); $i += 2; next }
        if ($c eq '$' && substr($s, $i + 1, 1) eq '(') {
            my $j = ps_paren_end($s, $i + 2, "(", ")");
            $txt .= substr($s, $i, $j - $i);
            $i = $j;
            next;
        }
        $txt .= $c;
        $i++;
    }
    return ($txt, $n);
}

# ps_sq <s> <i>: a verbatim string from after its opening quote ('' escapes)
sub ps_sq {
    my ($s, $i) = @_;
    my ($txt, $n) = ("", length $s);
    while ($i < $n) {
        my $c = substr($s, $i, 1);
        if ($c eq "'") {
            if (substr($s, $i + 1, 1) eq "'") { $txt .= "'"; $i += 2; next }
            return ($txt, $i + 1);
        }
        $txt .= $c;
        $i++;
    }
    return ($txt, $n);
}

# ps_args <s> <i>: the arguments of a command from index i: [kind, text]
# with kind str (a string literal), var ($name) or other; stops at the end of
# the statement (; | } ) or a comment
sub ps_args {
    my ($s, $i) = @_;
    my @a;
    my $n = length $s;
    while ($i < $n) {
        my $c = substr($s, $i, 1);
        if ($c =~ /\s/) { $i++; next }
        last if $c =~ /[;|})#]/;
        if ($c eq '"') { my ($t, $j) = ps_dq($s, $i + 1); push @a, ["str", $t]; $i = $j; next }
        if ($c eq "'") { my ($t, $j) = ps_sq($s, $i + 1); push @a, ["str", $t]; $i = $j; next }
        if ($c eq '(' || substr($s, $i, 2) eq '@(') {
            my $st = $i;
            $i += $c eq '(' ? 1 : 2;
            $i = ps_paren_end($s, $i, "(", ")");
            push @a, ["other", substr($s, $st, $i - $st)];
            next;
        }
        if ($c eq '{' || substr($s, $i, 2) eq '@{') {
            my $st = $i;
            $i += $c eq '{' ? 1 : 2;
            $i = ps_paren_end($s, $i, "{", "}");
            push @a, ["other", substr($s, $st, $i - $st)];
            next;
        }
        my $st = $i;
        $i++ while $i < $n && substr($s, $i, 1) !~ /[\s;|})]/;
        my $w = substr($s, $st, $i - $st);
        push @a, [($w =~ /^\$\{?\w+\}?$/ ? "var" : "other"), $w];
    }
    return @a;
}

# ps_prompts <file>: [line, prompt or undef] per Read-MenuChoice call
sub ps_prompts {
    my ($f) = @_;
    my $ll = logical_lines(read_lines($f), "`");
    my @calls;
    my %assigned;    # lower-case variable name -> last string literal
    for my $l (@$ll) {
        my $s = $l->[1];
        while ($s =~ /(?<![\w-])Read-MenuChoice(?![\w-])/gi) {
            my $at = pos($s);
            next if substr($s, 0, $at) =~ /\bfunction\s+Read-MenuChoice\z/i;
            my @a = ps_args($s, $at);
            my $p;
            for my $k (0 .. $#a) {
                next unless $a[$k][0] eq "other" && $a[$k][1] =~ /^-Prompt$/i;
                my $v = $a[$k + 1];
                last unless $v;
                if ($v->[0] eq "str") { $p = $v->[1] }
                elsif ($v->[0] eq "var") {
                    (my $name = $v->[1]) =~ s/^\$\{?(\w+)\}?$/$1/;
                    $p = $assigned{lc $name};
                }
                last;
            }
            push @calls, [$l->[0], $p];
        }
        if ($s =~ /^\s*\$(\w+)\s*=\s*(.*)$/) {
            my ($name, $rest) = ($1, $2);
            my @a = ps_args($rest, 0);
            if (@a == 1 && $a[0][0] eq "str") { $assigned{lc $name} = $a[0][1] }
            else { delete $assigned{lc $name} }
        }
    }
    return \@calls;
}

# ---- menu lines ----------------------------------------------------------

# menu_letters <file> <regex>: the sorted set of the last [x] per matching
# non-comment line
sub menu_letters {
    my ($f, $re) = @_;
    my %s;
    for my $l (@{ read_lines($f) }) {
        next if $l =~ /^\s*#/;
        $s{$1} = 1 if $l =~ $re;
    }
    return join(",", sort keys %s);
}

my ($sh_lib, $ps1_lib) = @ARGV;
my $sh_menu = menu_letters($sh_lib, qr/printf.*\[(\w)\]/);
my $ps1_menu = menu_letters($ps1_lib, qr/Console.*Write.*\[(\w)\]/i);
my $sh_calls = sh_prompts($sh_lib);
my $ps1_calls = ps_prompts($ps1_lib);

my (@sh_sets, @ps1_sets);
for my $c (@$sh_calls) { my $x = letters($c->[1]); push @sh_sets, $x; print "  bash:$c->[0] $x\n" }
for my $c (@$ps1_calls) { my $x = letters($c->[1]); push @ps1_sets, $x; print "  ps1:$c->[0] $x\n" }
my $sh_list = join("|", sort @sh_sets);
my $ps1_list = join("|", sort @ps1_sets);

if ($sh_menu eq "" && $ps1_menu eq "" && !@sh_sets && !@ps1_sets) {
    print "no menu lines and no menu-read calls found in either file -- extraction broken?\n";
    exit 1;
}

my @problems;
push @problems, "menu letters: bash $sh_menu vs PS1 $ps1_menu" if $sh_menu ne $ps1_menu;
if ($sh_list ne $ps1_list) {
    # multiset difference, both ways
    my %cnt;
    $cnt{$_}++ for @sh_sets;
    $cnt{$_}-- for @ps1_sets;
    my @only_sh = map { ($_) x $cnt{$_} } grep { $cnt{$_} > 0 } sort keys %cnt;
    my @only_ps1 = map { ($_) x -$cnt{$_} } grep { $cnt{$_} < 0 } sort keys %cnt;
    push @problems, "prompts only in bash: [" . join("] [", @only_sh) . "]" if @only_sh;
    push @problems, "prompts only in PS1: [" . join("] [", @only_ps1) . "]" if @only_ps1;
}
if (@problems) {
    print join("; ", @problems), "\n";
    exit 1;
}
print "menus $sh_menu; prompts $sh_list\n";
exit 0;
