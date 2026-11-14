#!/usr/bin/env perl
# make-lib.pl -- scratch copies of scripts/aitools-lib.sh/.ps1 with the M2-Reask
# wrapper (wrapper.sh / wrapper.ps1) inserted after read_tty_choice /
# Read-ConsoleChoice; scratch copies of the two suites pointed at them.
# Usage: perl make-lib.pl <worktree root>
use strict;
use warnings;

my $root = shift or die "usage: make-lib.pl <worktree root>\n";
my $s = "$root/.scratch/session-M2-D1";
my $w = "$root/.scratch/session-M2-Reask";
mkdir "$s/lib";
mkdir "$s/suite";

sub slurp { my ($f) = @_; open(my $fh, '<:raw', $f) or die "read $f: $!\n"; local $/; my $t = <$fh>; close $fh; return $t; }
sub spew  { my ($f, $t) = @_; open(my $fh, '>:raw', $f) or die "write $f: $!\n"; print $fh $t; close $fh; }

# bash: after the closing brace of read_tty_choice()
my $sh = slurp("$root/scripts/aitools-lib.sh");
my $wsh = slurp("$w/wrapper.sh");
my $n = ($sh =~ s/(\nread_tty_choice\(\) \{\n.*?\n\}\n)/$1\n$wsh/s);
die "bash: read_tty_choice not found\n" unless $n;
spew("$s/lib/aitools-lib.sh", $sh);

# PS1 (CRLF or LF): after the closing brace of Read-ConsoleChoice
my $ps = slurp("$root/scripts/aitools-lib.ps1");
my $nl = ($ps =~ /\r\n/) ? "\r\n" : "\n";
my $wps = slurp("$w/wrapper.ps1");
$wps =~ s/\r?\n/$nl/g;
$n = ($ps =~ s/(\r?\nfunction Read-ConsoleChoice \{\r?\n.*?\r?\n\}\r?\n)/$1$nl$wps/s);
die "ps1: Read-ConsoleChoice not found\n" unless $n;
spew("$s/lib/aitools-lib.ps1", $ps);

# Suites: same code, lib path pointed at the scratch copy
my $tsh = slurp("$root/tests/menus/test-menu-choice.sh");
$n = ($tsh =~ s{^LIB=.*$}{LIB="$s/lib/aitools-lib.sh"}m);
die "suite sh: LIB line not found\n" unless $n;
$tsh =~ s{^PTY=.*$}{PTY="$root/tests/managed-files/pty-run.py"}m;
$tsh =~ s{^ROOT=.*$}{ROOT="$root"}m;
spew("$s/suite/test-menu-choice.sh", $tsh);

my $tps = slurp("$root/tests/menus/test-menu-choice.ps1");
(my $ws = $s) =~ s{^/([a-z])/}{uc($1) . ":/"}e;   # pwsh needs C:/..., not /c/...
$n = ($tps =~ s{^\$lib = .*$}{\$lib = "$ws/lib/aitools-lib.ps1"}m);
die "suite ps1: lib line not found\n" unless $n;
spew("$s/suite/test-menu-choice.ps1", $tps);
print "ok: lib/aitools-lib.sh, lib/aitools-lib.ps1, suite/test-menu-choice.sh, suite/test-menu-choice.ps1\n";
