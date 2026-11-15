#!/usr/bin/env perl
# mutate.pl (M2-D2 scratch) -- mutants with the pre-mission behaviour: an
# unrecognised answer (empty line included) takes the default at once.
#   mut-sh/aitools-lib.sh   from lib-fake (bash, fake terminal)
#   mut-sh/test-menu-choice.sh  suite-fake pointed at it
#   mut-ps/scripts/*        integ scripts/ with Read-MenuChoice mutated
#   mut-ps/tests/menus/test-menu-choice.ps1  the edited PS1 suite
# Usage: perl mutate.pl <worktree root>
use strict;
use warnings;
use File::Copy qw(copy);
use File::Path qw(make_path);

my $w = shift or die "usage: mutate.pl <worktree root>\n";
my $s = "$w/.scratch/session-M2-D2";
my $integ = "$w/.scratch/session-M2-Reask/integ";
sub slurp { my ($f) = @_; open(my $fh, '<:raw', $f) or die "read $f: $!\n"; local $/; my $t = <$fh>; close $fh; return $t; }
sub spew  { my ($f, $t) = @_; open(my $fh, '>:raw', $f) or die "write $f: $!\n"; print $fh $t; close $fh; }

make_path("$s/mut-sh", "$s/mut-ps/scripts", "$s/mut-ps/tests/menus");
my $lib = slurp("$s/lib-fake/aitools-lib.sh");
my $n = ($lib =~ s{(\n\s*)log_detail "menu answer \(\$__ctx\): \\"\$__raw\\" -> not one of \$__hint, asked again"}{$1printf -v "\$__mvar" '%s' "\$__default"; return 0});
die "bash mutation point not found\n" unless $n;
spew("$s/mut-sh/aitools-lib.sh", $lib);
my $t = slurp("$s/suite-fake/test-menu-choice.sh");
$t =~ s{^LIB=.*$}{LIB="$s/mut-sh/aitools-lib.sh"}m or die "LIB line\n";
spew("$s/mut-sh/test-menu-choice.sh", $t);

opendir(my $dh, "$integ/scripts") or die "opendir: $!\n";
for my $f (readdir $dh) { next unless -f "$integ/scripts/$f"; copy("$integ/scripts/$f", "$s/mut-ps/scripts/$f") or die "copy $f: $!\n"; }
closedir $dh;
my $ps = slurp("$s/mut-ps/scripts/aitools-lib.ps1");
$n = ($ps =~ s{(\r?\n\s*)LogDetail "menu answer \(\$\{Context\}\): `"\$raw`" -> not one of \$hint, asked again"}{$1return \$Default});
die "PS1 mutation point not found\n" unless $n;
spew("$s/mut-ps/scripts/aitools-lib.ps1", $ps);
copy("$w/tests/menus/test-menu-choice.ps1", "$s/mut-ps/tests/menus/test-menu-choice.ps1") or die "copy ps1 suite: $!\n";
print "ok: mutants written\n";
