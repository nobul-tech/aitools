#!/usr/bin/perl
# snap-text.pl <snapshot-file> -- print the quoted text strings of a chrome-devtools
# a11y snapshot between the "Open actions menu" marker and "ON THIS TOPIC"
# (Jamf Learning Hub layout). Falls back to the whole file if markers are absent.
use strict; use warnings;
my $f = shift or die "usage: snap-text.pl <file>\n";
open my $fh, '<', $f or die "cannot open $f: $!\n";
my @lines = <$fh>; close $fh;
my $on = 0; my $seen = 0;
for my $l (@lines) { $seen = 1 if $l =~ /Open actions menu/; }
$on = 1 unless $seen;
for my $l (@lines) {
    if ($l =~ /Open actions menu/) { $on = 1; next; }
    last if $l =~ /"ON THIS TOPIC"/;
    next unless $on;
    next if $l =~ /\b(link|button|image)\b/ && $l !~ /StaticText/ && $l =~ /url=/;
    while ($l =~ /"([^"]{2,})"/g) {
        my $s = $1;
        next if $s =~ /^(Copy link to clipboard|polite|additions text|vertical|horizontal)$/;
        print "$s\n";
    }
}
