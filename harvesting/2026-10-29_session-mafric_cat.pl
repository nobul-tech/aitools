#!/usr/bin/env perl
# Concatenate issue dumps into one file, and summarise PRs and runs.
use strict; use warnings; use JSON::PP;
my $d = '/Users/new-jose/repos/aitools/.scratch/session-mafric';
open my $o, '>', "$d/all-issues.txt" or die $!;
for my $n (7,9,10,11,12,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,30,31,32,72) {
  open my $f, '<', "$d/issue-$n.txt" or die "$n: $!";
  print $o "\n=========== ISSUE $n ===========\n"; print $o $_ while <$f>; close $f;
}
close $o;
local $/;
open my $p, '<', "$d/prs.json" or die $!; my $prs = decode_json(<$p>); close $p;
open my $po, '>', "$d/prs-summary.txt" or die $!;
for my $r (sort { $a->{number} <=> $b->{number} } @$prs) {
  my $b = $r->{body} // ''; $b =~ s/\r//g;
  printf $po "#%d %s %s merged=%s head=%s draft=%s\n  %s\n", $r->{number}, $r->{state}, $r->{title}, ($r->{mergedAt}//'-'), $r->{headRefName}, ($r->{isDraft}?'y':'n'), substr($b,0,600) =~ s/\n/\n  /gr;
}
close $po;
open my $rr, '<', "$d/runs.json" or die $!; my $runs = decode_json(<$rr>); close $rr;
my %c;
open my $ro, '>', "$d/runs-summary.txt" or die $!;
for my $r (@$runs) {
  my $k = ($r->{name}//'?') . ' ' . ($r->{conclusion}//'none'); $c{$k}++;
  printf $ro "%s %s %s %s %s %s\n", $r->{databaseId}, $r->{createdAt}, $r->{name}, $r->{headBranch}, ($r->{conclusion}//'none'), $r->{displayTitle};
}
print $ro "\nCOUNTS\n"; print $ro "$_ $c{$_}\n" for sort keys %c;
close $ro;
print "ok\n";
