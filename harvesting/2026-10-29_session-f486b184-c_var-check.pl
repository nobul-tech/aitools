#!/usr/bin/env perl
# var-check.pl FILE START_RE END_RE -- list $VARS used in the [START, END) span of
# FILE that are never assigned anywhere in FILE (VAR=, local/export VAR, for VAR in,
# read VAR). Upper-case names only (the build script's globals).
use strict; use warnings;
my ($file, $start, $end) = @ARGV;
open my $fh, '<', $file or die "open $file: $!";
my @lines = <$fh>;
my (%assigned, %used, $in);
for my $l (@lines) {
    $assigned{$1} = 1 while $l =~ /\b([A-Z_][A-Z0-9_]*)\+?=/g;
    $assigned{$1} = 1 while $l =~ /\b(?:local|export|declare|readonly)\s+(?:-\w+\s+)?([A-Z_][A-Z0-9_]*)/g;
    $assigned{$1} = 1 while $l =~ /\bfor\s+([A-Z_][A-Z0-9_]*)\s+in\b/g;
    $assigned{$1} = 1 while $l =~ /\bread\s+(?:-\w+\s+)*([A-Z_][A-Z0-9_]*)/g;
}
for my $l (@lines) {
    $in = 1 if !$in && $l =~ /$start/;
    last if $in && $l =~ /$end/;
    next unless $in;
    $used{$1} = 1 while $l =~ /\$\{?([A-Z_][A-Z0-9_]*)/g;
}
my @env_ok = qw(HOME PATH TMPDIR PWD);
my %ok = map { $_ => 1 } @env_ok;
my @missing = grep { !$assigned{$_} && !$ok{$_} } sort keys %used;
print "used in span: ", scalar(keys %used), "\n";
print @missing ? "NOT ASSIGNED: @missing\n" : "all assigned\n";
