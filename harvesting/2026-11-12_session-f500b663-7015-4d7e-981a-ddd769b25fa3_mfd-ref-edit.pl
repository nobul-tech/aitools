#!/usr/bin/env perl
# mfd-ref-edit.pl FILE -- reference/managed-file-deployment.md: rules and
# skills from shared/ only (R-8 / S-7). Dies unless each old text matches once.
use strict;
use warnings;

my @pairs = (
    [
        "skills from `~/.aitools/skills/` (the fan-outs; first source wins there:\n`shared/`, then `.claude/`, then the dotprofile). Without `~/.aitools/skills`",
        "skills from `~/.aitools/skills/` (the fan-outs; deploy-harness fills them\nfrom aitools `shared/` only, R-8 / S-7). Without `~/.aitools/skills`",
    ],
    [
        "`shared/` directory is the fallback. Rules and skills are the exception:\nthey go through `~/.aitools`, where the first source wins (`shared/`, then\n`.claude/`, then the dotprofile).",
        "`shared/` directory is the fallback. Rules and skills are the exception:\nthey go through `~/.aitools`, filled from aitools `shared/rules/` and\n`shared/skills/` only (commander, 2026-11-06; `\@reference/rules.md` R-8).",
    ],
    [
        "(deploy-harness fills it from `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/`, first source wins)",
        "(deploy-harness fills it from `shared/rules/` only)",
    ],
    [
        "(deploy-harness fills it from `shared/skills/`, `.claude/skills/` and `<userRepoPath>/claude/skills/`, first source wins)",
        "(deploy-harness fills it from `shared/skills/` only)",
    ],
    [
        "| `~/.aitools/skills/<name>/` (+ `.aitools-skills-manifest`) | `shared/skills/`, `.claude/skills/`, `<userRepoPath>/claude/skills/` |\n| `~/.aitools/rules/` (flat, `*.md`; + `.aitools-rules-manifest`) | `shared/rules/`, `.claude/rules/`, `<userRepoPath>/claude/rules/` |",
        "| `~/.aitools/skills/<name>/` (+ `.aitools-skills-manifest`) | `shared/skills/` only |\n| `~/.aitools/rules/` (flat, `*.md`; + `.aitools-rules-manifest`) | `shared/rules/` only |",
    ],
    [
        "source `shared` \\| `aitools` \\| `dotprofile` \\| `retired` |",
        "source `shared` \\| `retired` (an older manifest's `aitools` and `dotprofile` lines are retired) |",
    ],
);

my $file = shift or die "usage: mfd-ref-edit.pl FILE\n";
open my $in, '<:raw', $file or die "cannot read $file: $!\n";
my $text = do { local $/; <$in> };
close $in;
for my $p (@pairs) {
    my ($old, $new) = @$p;
    my $n = () = $text =~ /\Q$old\E/g;
    die "$file: expected 1 match, found $n for: " . substr($old, 0, 70) . "\n" unless $n == 1;
    $text =~ s/\Q$old\E/$new/;
}
open my $out, '>:raw', $file or die "cannot write $file: $!\n";
print $out $text;
close $out or die "cannot write $file: $!\n";
print "updated $file\n";
