#!/usr/bin/perl
# Check remediation.md RM rows: 10 cells each, IDs 1..116 contiguous (scratch).
use strict; use warnings;
my $f = '/Users/new-jose/repos/aitools/plans/build-package/remediation.md';
open my $fh, '<', $f or die "open: $!";
my (%seen, $bad);
while (my $l = <$fh>) {
    next unless $l =~ /^\| RM-(\d+) \|/;
    my $id = $1;
    (my $t = $l) =~ s/\\\|//g;           # drop escaped pipes
    my $cells = () = $t =~ /\|/g;
    $cells -= 1;
    if ($cells != 10) { print "RM-$id has $cells cells\n"; $bad++ }
    print "dup RM-$id\n" if $seen{$id}++;
}
my @missing = grep { !$seen{$_} } 1..116;
print "missing: @missing\n" if @missing;
printf "rows=%d bad=%d\n", scalar(keys %seen), $bad // 0;
