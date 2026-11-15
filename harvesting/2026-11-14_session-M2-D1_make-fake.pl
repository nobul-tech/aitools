#!/usr/bin/env perl
# make-fake.pl -- scratch-only: lib-fake/aitools-lib.sh (the wrapper-inserted
# scratch lib with read_tty_choice reading stdin and echoing the line like a
# terminal, and every "> /dev/tty" sent to stderr) and suite-fake/ (the bash
# suite pointed at lib-fake and fake-pty-run.py, pty forced on, POSIX counts).
# Usage: perl make-fake.pl <worktree root> [lib file to start from]
use strict;
use warnings;

my $root = shift or die "usage: make-fake.pl <worktree root> [lib]\n";
my $s = "$root/.scratch/session-M2-D1";
my $from = shift // "$s/lib/aitools-lib.sh";
mkdir "$s/lib-fake";
mkdir "$s/suite-fake";
sub slurp { my ($f) = @_; open(my $fh, '<:raw', $f) or die "read $f: $!\n"; local $/; my $t = <$fh>; close $fh; return $t; }
sub spew  { my ($f, $t) = @_; open(my $fh, '>:raw', $f) or die "write $f: $!\n"; print $fh $t; close $fh; }

my $lib = slurp($from);
my $n = ($lib =~ s{if ! IFS= read -r __line < /dev/tty; then}{if IFS= read -r __line; then printf '%s\\n' "\$__line" >&2; else});
die "read_tty_choice read line not found\n" unless $n;
$lib =~ s{> /dev/tty}{>&2}g;
spew("$s/lib-fake/aitools-lib.sh", $lib);

my $t = slurp("$s/suite/test-menu-choice.sh");
$t =~ s{^LIB=.*$}{LIB="$s/lib-fake/aitools-lib.sh"}m or die "LIB line\n";
$t =~ s{^PTY=.*$}{PTY="$s/fake-pty-run.py"}m or die "PTY line\n";
$t =~ s{^        IS_WINDOWS=true\n}{}m or die "IS_WINDOWS line\n";
$t =~ s{^        if \$HAVE_PTY && ! python3 -c 'import winpty'.*\n}{}m or die "winpty line\n";
spew("$s/suite-fake/test-menu-choice.sh", $t);
print "ok: lib-fake/aitools-lib.sh, suite-fake/test-menu-choice.sh (from $from)\n";
