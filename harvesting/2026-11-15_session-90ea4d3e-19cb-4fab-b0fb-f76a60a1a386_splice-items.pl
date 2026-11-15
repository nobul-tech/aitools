#!/usr/bin/env perl
# splice-items.pl -- replace everything from "## 8." to end of file in the
# checklist with the contents of a section file. Usage: splice-items.pl <checklist> <sections>
use strict;
use warnings;

my ($target, $section) = @ARGV;
die "usage: splice-items.pl <checklist> <sections>\n" unless $target && $section;

open my $tf, '<:encoding(UTF-8)', $target or die "cannot read $target: $!\n";
my $text = do { local $/; <$tf> };
close $tf;

open my $sf, '<:encoding(UTF-8)', $section or die "cannot read $section: $!\n";
my $new = do { local $/; <$sf> };
close $sf;

my $pos = index($text, "\n## 8. ");
die "item 8 heading not found in $target\n" if $pos < 0;

my $out = substr($text, 0, $pos + 1) . $new;
open my $of, '>:encoding(UTF-8)', $target or die "cannot write $target: $!\n";
print {$of} $out;
close $of;
print "spliced items 8-9 into $target\n";
