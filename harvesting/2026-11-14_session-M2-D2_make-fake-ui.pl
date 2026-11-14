#!/usr/bin/env perl
# make-fake-ui.pl (M2-D2 scratch) -- integ/tests/profile/test-user-init-fake.sh:
# the edited user-init suite with the pty replaced by D1's fake-pty-run.py
# (input on a pipe), pty cases forced on, and -- in the suite's throwaway
# aitools copy only -- Test-InteractiveConsole returning $true when
# FAKE_CONSOLE=1, which only the "pty" runs set. integ is a throwaway worktree.
# Usage: perl make-fake-ui.pl <worktree root>
use strict;
use warnings;

my $w = shift or die "usage: make-fake-ui.pl <worktree root>\n";
my $integ = "$w/.scratch/session-M2-Reask/integ";
sub slurp { my ($f) = @_; open(my $fh, '<:raw', $f) or die "read $f: $!\n"; local $/; my $t = <$fh>; close $fh; return $t; }
sub spew  { my ($f, $t) = @_; open(my $fh, '>:raw', $f) or die "write $f: $!\n"; print $fh $t; close $fh; }

my $t = slurp("$w/tests/profile/test-user-init.sh");
$t =~ s{^PTY=.*$}{PTY="$w/.scratch/session-M2-D1/fake-pty-run.py"}m or die "PTY line\n";
$t =~ s{^    if ! python3 -c 'import winpty'.*\n}{    :  # fake: pty forced on\n}m or die "winpty line\n";
my $over = q{printf '\nfunction Test-InteractiveConsole { if ($env:FAKE_CONSOLE -eq "1") { return $true }; return ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) }\n' >> "$SRC/scripts/aitools-lib.ps1"};
$t =~ s{^(cp -R "\$REPO/scripts" "\$REPO/shared" "\$SRC/"\n)}{$1$over\n}m or die "cp line\n";
my $n = ($t =~ s{"\$\{e\[\@\]\}" python3 "\$\(native_path "\$PTY"\)"}{"\${e[\@]}" FAKE_CONSOLE=1 python3 "\$(native_path "\$PTY")"});
die "ps1 pty line\n" unless $n;
spew("$integ/tests/profile/test-user-init-fake.sh", $t);
print "ok: integ/tests/profile/test-user-init-fake.sh\n";
