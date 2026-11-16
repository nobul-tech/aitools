#!/usr/bin/env perl
# Count runs of three backticks in a file (AAR rule 3.4.1).
use strict;
use warnings;
my $bt = chr(96) x 3;
my $n = 0;
while (my $line = <>) {
    my $copy = $line;
    $n++ while $copy =~ /\Q$bt\E/g;
}
print "triple-backtick runs: $n\n";
