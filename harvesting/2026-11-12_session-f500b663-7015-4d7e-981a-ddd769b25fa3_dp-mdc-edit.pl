#!/usr/bin/env perl
# dp-mdc-edit.pl FILE -- the deploy-paths.mdc twin of the deploy-paths.md edits
use strict;
use warnings;

my @pairs = (
    [
        q{(the only way the dotprofile's `claude/rules` reaches an endpoint)},
        q{(rules and skills come from aitools `shared/` only; commander, 2026-11-06)},
    ],
    [
        q{replaces only section 2 (dotprofile lookup) with the embedded snapshot},
        q{replaces only section 2 (source setup) with the embedded snapshot},
    ],
    [
        q{(`reference/`, `registries/`, `shared/hooks`, `.claude/hooks`, `shared/skills`, `.claude/skills`, `<userRepoPath>/claude/skills`, `shared/rules`, `.claude/rules`, `<userRepoPath>/claude/rules`, the bin CLIs) → its `git ls-files` list and contents, embedded as base64 at build time},
        q{(`reference/`, `registries/`, `shared/hooks`, `.claude/hooks`, `shared/skills`, `shared/rules`, the bin CLIs) → its `git ls-files` list and contents, embedded as base64 at build time. Nothing from the dotprofile is in the harness snapshot},
    ],
);

my $file = shift or die "usage: dp-mdc-edit.pl FILE\n";
open my $in, '<:raw', $file or die "cannot read $file: $!\n";
my $text = do { local $/; <$in> };
close $in;
for my $p (@pairs) {
    my ($old, $new) = @$p;
    my $n = () = $text =~ /\Q$old\E/g;
    die "$file: expected 1 match, found $n for: " . substr($old, 0, 60) . "\n" unless $n == 1;
    $text =~ s/\Q$old\E/$new/;
}
open my $out, '>:raw', $file or die "cannot write $file: $!\n";
print $out $text;
close $out or die "cannot write $file: $!\n";
print "updated $file\n";
