#!/usr/bin/env perl
# gen-rows.pl OUT SUMMARY... -- S3-CursorVerify-Pwsh rows generator (contract v1.0 "Output").
# rows.txt: the summary rows (CAT|tool|detail) whose tool is "harness files",
# "cursor rules", "cursor skills", or whose category is ACTION, in emitted order
# (summary files in the order given), DETAIL rows included. .bak.<UTC> -> .bak.TS.
use strict;
use warnings;
my ($out, @files) = @ARGV;
die "usage: gen-rows.pl OUT SUMMARY...\n" unless defined $out && @files;
my %want = map { $_ => 1 } ('harness files', 'cursor rules', 'cursor skills');
open(my $o, '>:raw', $out) or die "write $out: $!\n";
my $n = 0;
for my $f (@files) {
    next unless -f $f;
    open(my $fh, '<:raw', $f) or die "read $f: $!\n";
    while (my $l = <$fh>) {
        $l =~ s/\r?\n\z//;
        my ($cat, $tool) = split /\|/, $l, 3;
        next unless defined $tool;
        next unless $cat eq 'ACTION' || $want{$tool};
        $l =~ s/\.bak\.\d{4}-\d\d-\d\dT\d{6}Z(?:-\d+)?/.bak.TS/g;
        print $o "$l\n";
        $n++;
    }
    close $fh;
}
close $o;
print "rows.txt $n rows\n";
