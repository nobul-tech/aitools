#!/usr/bin/env perl
# rm-shape.pl REMEDIATION PLAN -- table-shape check: every RM row has 10 cells and a
# Batch cell whose batch IDs all exist in the plan's section 4; prints the
# by-primary-batch counts. Exit 1 on any problem.
use strict;
use warnings;

my ($rem, $plan) = @ARGV;
die "usage: rm-shape.pl REMEDIATION PLAN\n" unless $rem && $plan;

open my $p, '<', $plan or die "read $plan: $!\n";
my ($in4, %exists) = (0);
while (<$p>) {
    $in4 = 1 if /^## 4\. Batches/;
    $in4 = 0 if /^## 5\./;
    next unless $in4;
    $exists{$1} = 1 if /^\| (B\d+[a-z]?\d?) \|/;
}
close $p;
die "no batch IDs found in plan section 4\n" unless %exists;

open my $r, '<', $rem or die "read $rem: $!\n";
my ($bad, $rows, %primary, %ids) = (0, 0);
while (<$r>) {
    next unless /^\| RM-(\d+) \|/;
    my $id = $1;
    $rows++;
    my @c = split /(?<!\\)\|/, $_, -1;
    if (@c != 12) { print "BAD RM-$id: ", scalar(@c) - 2, " cells (want 10)\n"; $bad++; next; }
    if ($ids{$id}++) { print "BAD RM-$id: duplicate row\n"; $bad++; }
    my $batch = $c[7];
    $batch =~ s/^\s+|\s+$//g;
    my ($prim) = $batch =~ /^(--MDM|--dev|--PR|B\d+[a-z]?\d?)/;
    unless ($prim) { print "BAD RM-$id: no primary batch in '$batch'\n"; $bad++; next; }
    push @{ $primary{$prim} }, $id;
    for my $b ($batch =~ /\b(B\d+[a-z]?\d?)\b/g) {
        next if $b eq 'B0';   # B0 is done (plan section 4 lists it)
        unless ($exists{$b}) { print "BAD RM-$id: batch $b not in plan section 4\n"; $bad++; }
    }
}
close $r;

my @gap = grep { !$ids{$_} } 1 .. 118;
if (@gap) { print "BAD missing RM ids: @gap\n"; $bad++; }
print "rows: $rows; plan section 4 batch IDs: ", join(' ', sort keys %exists), "\n";
for my $k (sort keys %primary) {
    printf "%-6s %3d  %s\n", $k, scalar @{ $primary{$k} }, join(', ', @{ $primary{$k} });
}
print $bad ? "FAIL: $bad problem(s)\n" : "PASS: every RM row has a batch that exists in plan section 4\n";
exit($bad ? 1 : 0);
