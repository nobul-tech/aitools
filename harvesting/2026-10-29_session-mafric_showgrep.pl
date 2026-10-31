#!/usr/bin/env perl
# Print the grep extracts of the failed runs.
use strict; use warnings;
my $d = '/Users/new-jose/repos/aitools/.scratch/session-mafric';
for my $id (qw(39891714493 39891264259 39890650263 39888735993 39873612279)) {
  print "===== $id =====\n";
  open my $f, '<', "$d/fail-$id.grep" or die $!;
  while (<$f>) { s/^\S+\t\S+\t\d{4}-\d\d-\d\dT[\d:.]+Z //; print substr($_,0,300); print "\n" unless /\n$/; }
  close $f;
}
