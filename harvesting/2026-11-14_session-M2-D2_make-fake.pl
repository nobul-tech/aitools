#!/usr/bin/env perl
# make-fake.pl (M2-D2 scratch) -- a fake-terminal copy of the integ lib and of
# the edited bash suite, for a machine without pywinpty:
#   lib-fake/aitools-lib.sh: read_tty_choice reads stdin (echoing the line like
#     a terminal), every "> /dev/tty" goes to stderr, tty_interactive is true
#     when stdin is a pipe (fake-pty-run) and false for /dev/null.
#   suite-fake/test-menu-choice.sh: LIB -> lib-fake, PTY -> D1's
#     fake-pty-run.py, pty forced on, POSIX counts (IS_WINDOWS off).
# Usage: perl make-fake.pl <worktree root>
use strict;
use warnings;

my $w = shift or die "usage: make-fake.pl <worktree root>\n";
my $s = "$w/.scratch/session-M2-D2";
my $integ = "$w/.scratch/session-M2-Reask/integ";
mkdir "$s/lib-fake";
mkdir "$s/suite-fake";
sub slurp { my ($f) = @_; open(my $fh, '<:raw', $f) or die "read $f: $!\n"; local $/; my $t = <$fh>; close $fh; return $t; }
sub spew  { my ($f, $t) = @_; open(my $fh, '>:raw', $f) or die "write $f: $!\n"; print $fh $t; close $fh; }

my $lib = slurp("$integ/scripts/aitools-lib.sh");
my $n = ($lib =~ s{if ! IFS= read -r __line < /dev/tty; then}{if IFS= read -r __line; then printf '%s\\n' "\$__line" >&2; else});
die "read_tty_choice read line not found\n" unless $n;
$n = ($lib =~ s{^(tty_interactive\(\) \{\n)    \[ -t 0 \] \|\| return 1\n}{$1    [ -p /dev/stdin ] || return 1\n}m);
die "tty_interactive body not found\n" unless $n;
$lib =~ s{> /dev/tty}{>&2}g;
spew("$s/lib-fake/aitools-lib.sh", $lib);

my $t = slurp("$w/tests/menus/test-menu-choice.sh");
$t =~ s{^LIB=.*$}{LIB="$s/lib-fake/aitools-lib.sh"}m or die "LIB line\n";
$t =~ s{^PTY=.*$}{PTY="$w/.scratch/session-M2-D1/fake-pty-run.py"}m or die "PTY line\n";
$t =~ s{^        IS_WINDOWS=true\n}{}m or die "IS_WINDOWS line\n";
$t =~ s{^        if \$HAVE_PTY && ! python3 -c 'import winpty'.*\n}{}m or die "winpty line\n";
spew("$s/suite-fake/test-menu-choice.sh", $t);
print "ok: lib-fake/aitools-lib.sh, suite-fake/test-menu-choice.sh\n";
