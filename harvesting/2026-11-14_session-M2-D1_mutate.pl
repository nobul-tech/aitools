#!/usr/bin/env perl
# mutate.pl -- negative control: lib-mut/ copies of the scratch libs where an
# empty answer returns the default (the pre-mission behaviour), and a PS1 suite
# copy pointed at lib-mut. Usage: perl mutate.pl <worktree root>
use strict;
use warnings;

my $root = shift or die "usage: mutate.pl <worktree root>\n";
my $s = "$root/.scratch/session-M2-D1";
mkdir "$s/lib-mut";
mkdir "$s/suite-mut";
sub slurp { my ($f) = @_; open(my $fh, '<:raw', $f) or die "read $f: $!\n"; local $/; my $t = <$fh>; close $fh; return $t; }
sub spew  { my ($f, $t) = @_; open(my $fh, '>:raw', $f) or die "write $f: $!\n"; print $fh $t; close $fh; }

my $sh = slurp("$s/lib/aitools-lib.sh");
$sh =~ s{(__ans=\$\(printf '%s' "\$__ans" \| tr '\[:upper:\]' '\[:lower:\]'\)\n)}{$1        if [ -z "\$__ans" ]; then printf -v "\$__mvar" '%s' "\$__default"; return 0; fi\n} or die "bash mutation point\n";
spew("$s/lib-mut/aitools-lib.sh", $sh);

my $ps = slurp("$s/lib/aitools-lib.ps1");
$ps =~ s{(\$ans = \$raw\.Trim\(\)\.ToLowerInvariant\(\)\r?\n)}{$1        if (\$ans -eq "") { return \$Default }\r\n} or die "ps1 mutation point\n";
spew("$s/lib-mut/aitools-lib.ps1", $ps);

my $t = slurp("$s/suite/test-menu-choice.ps1");
$t =~ s{lib/aitools-lib\.ps1}{lib-mut/aitools-lib.ps1} or die "suite lib path\n";
spew("$s/suite-mut/test-menu-choice.ps1", $t);
print "ok: lib-mut/aitools-lib.sh, lib-mut/aitools-lib.ps1, suite-mut/test-menu-choice.ps1\n";
