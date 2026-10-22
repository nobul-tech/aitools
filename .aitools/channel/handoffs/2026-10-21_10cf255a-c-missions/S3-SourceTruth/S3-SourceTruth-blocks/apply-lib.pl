#!/usr/bin/env perl
# apply-lib.pl -- S3-SourceTruth batch tool: replace line ranges of a file with
# block files, verbatim, after checking each range's first and last line.
#
# Usage: perl apply-lib.pl FILE SPEC
#   SPEC: one line per range: START<TAB>END<TAB>FIRST_LINE_REGEX<TAB>LAST_LINE_REGEX<TAB>BLOCK_FILE
#   Lines are 1-based, inclusive, against the ORIGINAL file (origin/main db4b3c5).
#   Ranges are applied bottom-up so line numbers stay valid. A BLOCK_FILE ending
#   in .tmpl has its line "__REVIEW_JSON_NODE__" replaced by review-json.js
#   (same directory), so the node script is byte-identical in both libs.
# Fails (exit 1, nothing written) if any anchor does not match or ranges overlap.
use strict;
use warnings;
use File::Basename qw(dirname);

my ($file, $spec) = @ARGV;
die "usage: apply-lib.pl FILE SPEC\n" unless $file && $spec;
open my $fh, '<', $file or die "cannot read $file: $!\n";
my @lines = <$fh>;
close $fh;

open my $sh, '<', $spec or die "cannot read $spec: $!\n";
my @ranges;
while (my $l = <$sh>) {
    chomp $l;
    next if $l =~ /^\s*(#|$)/;
    my ($s, $e, $first, $last, $block) = split /\t/, $l;
    die "bad spec line: $l\n" unless defined $block;
    push @ranges, [$s, $e, $first, $last, $block];
}
close $sh;

@ranges = sort { $b->[0] <=> $a->[0] } @ranges;
for my $i (1 .. $#ranges) {
    die "ranges overlap: $ranges[$i][0]-$ranges[$i][1] and $ranges[$i-1][0]-$ranges[$i-1][1]\n"
        if $ranges[$i][1] >= $ranges[$i-1][0];
}
my $dir = dirname($spec);
for my $r (@ranges) {
    my ($s, $e, $first, $last, $block) = @$r;
    die "range $s-$e outside file\n" if $e > @lines || $s < 1 || $s > $e;
    die "anchor mismatch at line $s: expected /$first/, got: $lines[$s-1]" unless $lines[$s-1] =~ /$first/;
    die "anchor mismatch at line $e: expected /$last/, got: $lines[$e-1]" unless $lines[$e-1] =~ /$last/;
}
for my $r (@ranges) {
    my ($s, $e, $first, $last, $block) = @$r;
    my $path = "$dir/$block";
    open my $bh, '<', $path or die "cannot read $path: $!\n";
    my @new = <$bh>;
    close $bh;
    if ($block =~ /\.tmpl$/) {
        open my $jh, '<', "$dir/review-json.js" or die "cannot read review-json.js: $!\n";
        my @js = <$jh>;
        close $jh;
        my @out;
        my $done = 0;
        for my $nl (@new) {
            if ($nl =~ /^__REVIEW_JSON_NODE__\s*$/) { push @out, @js; $done++; } else { push @out, $nl; }
        }
        die "placeholder not found exactly once in $block\n" unless $done == 1;
        @new = @out;
    }
    $new[-1] .= "\n" unless $new[-1] =~ /\n\z/;
    splice @lines, $s - 1, $e - $s + 1, @new;
    print "replaced $s-$e with $block (" . scalar(@new) . " lines)\n";
}
open my $oh, '>', $file or die "cannot write $file: $!\n";
print $oh @lines;
close $oh or die "cannot close $file: $!\n";
print "wrote $file\n";
