#!/usr/bin/env perl
# rebatch.pl FILE -- rewrite the Batch column of every RM row in remediation.md
# from the map below (F6: every RM gets a lettered batch from plan section 4).
use strict;
use warnings;

my %map = (
  1 => '--MDM (B2 gate)', 2 => 'B4', 3 => 'B3a', 4 => 'B3a (B3b)', 5 => '--PR', 6 => 'B3a',
  7 => 'B4', 8 => '--MDM', 9 => '--MDM', 10 => 'B2 (--MDM)', 11 => '--MDM', 12 => '--MDM',
  13 => '--MDM', 14 => '--PR', 15 => '--MDM', 16 => '--MDM', 17 => '--MDM', 18 => '--dev',
  19 => 'B10a (B12)',
  20 => 'B3a', 21 => 'B3b', 22 => 'B3b', 23 => 'B3b', 24 => 'B3a', 25 => 'B3a', 26 => 'B5b (B3a)',
  27 => 'B3a', 28 => 'B3b', 29 => 'B3b', 30 => 'B3b', 31 => '--dev', 32 => '--dev', 33 => '--dev',
  34 => '--dev', 35 => 'B7h', 36 => 'B9a', 37 => '--PR', 38 => '--PR',
  39 => 'B5a (callers B4, B6a-B6h, B7a-B7m; launchers B8a, B9a, B10b)', 40 => 'B5a (B7d, B7k)', 41 => 'B5c (B7a-B7m, B6b)',
  42 => 'B5b (B1 P-2)', 43 => '--dev', 44 => 'B5d', 45 => 'B5b', 46 => 'B5b', 47 => 'B5b (B5d)',
  48 => 'B5b', 49 => 'B5a', 50 => 'B5b', 51 => '--dev', 52 => '--dev', 53 => '--dev',
  54 => 'B6a', 55 => 'B6c', 56 => 'B6e', 57 => 'B6d (B6a, B6g, B6h; B1 P-3)', 58 => '--PR',
  59 => 'B5a (adopt guard)', 60 => 'B6d2 (B1 P-3, P-6)', 61 => 'B6d', 62 => 'B6b', 63 => 'B6g',
  64 => 'B6g', 65 => 'B6g', 66 => 'B6c (B6b)', 67 => 'B6b', 68 => 'B6c', 69 => 'B6b', 70 => 'B6f',
  71 => 'B6d', 72 => 'B2', 73 => 'B6h', 74 => 'B6d', 75 => 'B6b (B5c)', 76 => '--PR', 77 => '--PR',
  78 => '--PR', 79 => '--PR', 80 => 'B6d',
  81 => 'B7a (B7b-B7h)', 82 => 'B1', 83 => 'B7a (B7b, B7d)', 84 => 'B7c (B7b, B7d, B7e, B7h, B7i)',
  85 => 'B7j', 86 => 'B7k', 87 => 'B7l', 88 => 'B7l', 89 => 'B7a', 90 => 'B7g (B7g2)',
  91 => 'B9a (B1)', 92 => 'B7a',
  93 => 'B0 (done, 5494d93)', 94 => 'B13 (body done in 5494d93; Intent draft to write)',
  95 => 'B13 (#105)', 96 => 'B0 (done, 5494d93)', 97 => 'B13 (P-1)',
  98 => 'B0 (done, 32bf20c; Equivalence rev 1) (B13: .mdc step 3 "steps 3+10")',
  99 => 'B0 (done, 5494d93)', 100 => 'B0 (done, 5494d93)',
  101 => 'B0 (criteria done, 5494d93) (B13: playbook row, draft to write)', 102 => 'B13 (#101/#106)',
  103 => 'B0 (done, 5494d93)', 104 => 'B0 (harness.md, aitools-workspace.md done, 5494d93) (B13: tool-lifecycle.mdc, draft to write)',
  105 => 'B13 (entry 14; #101/#106)', 106 => 'B13 (entry 8; #101)', 107 => 'B13 (draft to write; /tool-ops)',
  108 => 'B13 (entry 12; #101)', 109 => 'B13 (entry 9; #101)',
  110 => 'B1 (B5a code)', 111 => 'B1', 112 => 'B8a', 113 => 'B10c (P-1 exit policy)', 114 => 'B1',
  115 => 'B8a (B9a, B10b; P-1 exit policy)', 116 => 'B8a (B2 hygiene)',
  117 => 'B3a (B3b)', 118 => 'B3b',
);

my $file = shift or die "usage: rebatch.pl FILE\n";
open my $in, '<', $file or die "read $file: $!\n";
my @lines = <$in>;
close $in;

my (%seen, $changed);
for my $line (@lines) {
    next unless $line =~ /^\| RM-(\d+) \|/;
    my $id = $1;
    my @cells = split /(?<!\\)\|/, $line, -1;   # '' , ID, ..., Ver, "\n"
    die "RM-$id: expected 12 fields, got " . scalar(@cells) . "\n" unless @cells == 12;
    die "RM-$id: no batch in map\n" unless exists $map{$id};
    $cells[7] = " $map{$id} ";
    $line = join '|', @cells;
    $seen{$id} = 1;
    $changed++;
}
my @missing = grep { !$seen{$_} } sort { $a <=> $b } keys %map;
die "map ids without a row: @missing\n" if @missing;

open my $out, '>', $file or die "write $file: $!\n";
print {$out} @lines;
close $out or die "close $file: $!\n";
print "rewrote $changed RM rows\n";
