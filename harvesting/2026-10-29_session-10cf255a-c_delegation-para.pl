#!/usr/bin/env perl
# delegation-para.pl -- replace the "## Delegation Duty" paragraph in a CLAUDE.md template (scratch)
use strict;
use warnings;

my $file = shift or die "usage: delegation-para.pl FILE\n";
open my $in, '<', $file or die "read $file: $!\n";
local $/;
my $text = <$in>;
close $in;

my $new = <<'END';
## Delegation Duty

Applies on every platform and in every environment, to every delegate (Agent tool sub-agent of any type, workflow agent, parallel or background session, cloud agent). **Load the `/delegate` skill before every Agent tool call and every workflow**, at session start, and after a compaction. Every delegation prompt carries eight elements: identity; rules and CLAUDE.md files (an explicit instruction to read in full every user- and project-scope CLAUDE.md and rule, by absolute path); skills, with `/delegate` first and the instruction to load it before delegating further and to pass the same instructions down; operational learning; conflict priority (D-DEL6: the commander's own words, newest first, then the prompt, then skills); the `WRITE_BLOCKED` signal; access (explicit paths); and the name prefix -- **the delegate writes every `*.md` file with its name as a prefix**, e.g. `S2-report.md` (D-DEL1). Delegates write versions, not drafts (D-DEL5). Verify a delegate's output before relying on it. Rule: `~/.claude/rules/delegation.md`; everything else: the `/delegate` skill.
END

my $count = ($text =~ s/^## Delegation Duty\n\n.*?\n(?=\n## )/$new/ms);
die "Delegation Duty section not found in $file\n" unless $count == 1;
open my $out, '>', $file or die "write $file: $!\n";
print {$out} $text;
close $out or die "close $file: $!\n";
print "updated $file\n";
