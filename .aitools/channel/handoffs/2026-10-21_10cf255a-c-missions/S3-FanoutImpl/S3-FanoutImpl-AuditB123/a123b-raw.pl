#!/usr/bin/env perl
# a123b-raw.pl OUTDIR: console lines in <case>/<lang>.out that are not structured
# log lines ([ts] [script] [level] msg) -- raw stderr that bypassed the logger.
# Summary panel lines are not printed by the drivers, so any hit is raw output.
use strict; use warnings;
my $out = shift or die "usage\n";
opendir my $d, $out or die; my @cases = sort grep { -d "$out/$_" && !/^\./ } readdir $d;
for my $c (@cases) {
    for my $l (qw(sh ps)) {
        my $f = "$out/$c/$l.out";
        open my $fh, "<", $f or next;
        while (my $x = <$fh>) {
            $x =~ s/\e\[[0-9;?]*[A-Za-z]//g; $x =~ s/\r//g; chomp $x;
            next if $x =~ /\A\s*\z/;
            next if $x =~ /\A\[\d{4}-\d\d-\d\dT[\d:]+Z\] \[[^\]]+\] \[(info|ok|warn|error)\] /;
            next if $c =~ /\Apty/;   # pty logs hold the menu and diff
            print "$c/$l: $x\n";
        }
    }
}
