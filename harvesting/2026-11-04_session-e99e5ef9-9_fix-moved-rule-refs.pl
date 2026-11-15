#!/usr/bin/env perl
# fix-moved-rule-refs.pl -- rewrite repo-relative references to rules moved on
# 2026-10-31 (commander's working-tree moves) in the files check-path-refs flagged.
# Usage: perl fix-moved-rule-refs.pl <pre-commit log> <repo root>
# Only exact repo-relative paths are rewritten; a path preceded by / ~ or a word
# character (e.g. ~/.claude/rules/tool-ops.md, a user-level deployed copy) is left.
use strict;
use warnings;

my ($log, $root) = @ARGV;
die "usage: $0 <log> <repo root>\n" unless $log && $root;

my %map = (
    '.claude/rules/artifact-harvesting.md' => 'shared/rules/artifact-harvesting.md',
    '.claude/rules/tool-evaluation.md'     => 'shared/rules/tool-evaluation.md',
    '.claude/rules/tool-lifecycle.md'      => 'shared/rules/tool-lifecycle.md',
    '.claude/rules/tool-ops.md'            => 'shared/rules/tool-ops.md',
    '.claude/rules/web-sources.md'         => 'shared/rules/web-sources.md',
    'shared/rules/hook-lifecycle.md'       => '.claude/rules/hook-lifecycle.md',
);

open my $lf, '<', $log or die "cannot read $log: $!\n";
my %files;
while (my $l = <$lf>) {
    next unless $l =~ /^([^\s:]+):\d+: (\S+)\s*$/;
    my ($f, $p) = ($1, $2);
    $files{$f} = 1 if exists $map{$p};
}
close $lf;
die "no flagged files found in $log\n" unless %files;

my $alt = join '|', map { quotemeta } sort { length $b <=> length $a } keys %map;
my $total = 0;
for my $rel (sort keys %files) {
    my $path = "$root/$rel";
    open my $in, '<:raw', $path or die "cannot read $path: $!\n";
    local $/;
    my $text = <$in>;
    close $in;
    my $n = ($text =~ s{(?<![~/\w-])($alt)}{$map{$1}}g);
    $n ||= 0;
    if ($n > 0) {
        open my $out, '>:raw', $path or die "cannot write $path: $!\n";
        print {$out} $text;
        close $out or die "cannot close $path: $!\n";
    }
    printf "%3d  %s\n", $n, $rel;
    $total += $n;
}
print "total replacements: $total\n";
