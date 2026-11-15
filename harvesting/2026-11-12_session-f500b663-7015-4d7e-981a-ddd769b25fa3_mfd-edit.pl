#!/usr/bin/env perl
# mfd-edit.pl FILE... -- rewrite the four three-source lines of
# managed-file-deployment.md / .mdc (identical in both) for shared-only rules
# and skills. Dies when any old line is not found exactly once.
use strict;
use warnings;

my @pairs = (
    [
        q{| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, profile.json (preferences, identity, machine profiles); user rules and user skills too, but through `~/.aitools` (row below), where `shared/` and `.claude/` win a name conflict |},
        q{| Dotprofile repo (`aitools-<username>`) | Primary (wins if present) | CLAUDE.md template, profile.json (preferences, identity, machine profiles). Its `claude/rules/` and `claude/skills/` are not harness sources (commander, 2026-11-06) |},
    ],
    [
        q{| aitools repo + dotprofile -> `~/.aitools/` (`deploy-harness`) | First source wins on a name conflict: `shared/`, then `.claude/`, then the dotprofile `claude/rules/` / `claude/skills/` |},
        q{| aitools repo -> `~/.aitools/` (`deploy-harness`) | Rules and skills from `shared/` only (commander, 2026-11-06); hooks from `shared/hooks/`, then `.claude/hooks/` (first source wins on a name conflict) |},
    ],
    [
        q{- **Rules**: deploy-harness collects `shared/rules/`, `.claude/rules/` and `<userRepoPath>/claude/rules/` into `~/.aitools/rules/` (first source wins) and writes `~/.aitools/rules/.aitools-rules-manifest` (each rule's source, or `retired`).},
        q{- **Rules**: deploy-harness copies `shared/rules/` only into `~/.aitools/rules/` (aitools `.claude/rules/` is project scope, loaded only in aitools sessions; the dotprofile `claude/rules/` is not a harness source; commander, 2026-11-06) and writes `~/.aitools/rules/.aitools-rules-manifest` (each rule's source, or `retired`; a rule a previous run took from `.claude/rules/` or the dotprofile is retired).},
    ],
    [
        q{- **Skills**: user-level skills in `shared/skills/` (aitools-authored; `chrome-devtools` and `a11y-debugging` vendored from upstream), project skills in `.claude/skills/` and personal skills in the dotprofile `claude/skills/`. deploy-harness collects the three into `~/.aitools/skills/<name>/` (first source wins) and writes `~/.aitools/skills/.aitools-skills-manifest` (each skill's source, or `retired`).},
        q{- **Skills**: user-level skills in `shared/skills/` (aitools-authored; `chrome-devtools` and `a11y-debugging` vendored from upstream) are the only harness skills; project skills in `.claude/skills/` load only in aitools sessions, and the dotprofile `claude/skills/` is not a harness source (commander, 2026-11-06). deploy-harness copies `shared/skills/` into `~/.aitools/skills/<name>/` and writes `~/.aitools/skills/.aitools-skills-manifest` (each skill's source, or `retired`; a skill a previous run took from `.claude/skills/` or the dotprofile is retired).},
    ],
);

for my $file (@ARGV) {
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
}
