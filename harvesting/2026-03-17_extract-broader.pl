#!/usr/bin/env perl
# Extract user messages matching broader patterns about intent quality,
# the intent-writing skill, approval patterns
use strict;
use warnings;
use JSON::PP;

my $file = $ARGV[0] or die "Usage: $0 <jsonl-file> <pattern-name>\n";
my $mode = $ARGV[1] // "quality";

open my $fh, '<', $file or die "Cannot open $file: $!\n";

# Patterns for different search modes
my %patterns = (
    quality => qr/purpose.*scope|scope.*audience|purpose.*audience|intent.*purpose|intent.*scope|intent.*audience|intent.*(pattern|format|template|structure)|three.*(component|part)|weak|strong|good.*intent|bad.*intent|fix.*intent|rewrite.*intent|revise.*intent|draft.*intent/i,
    skill_invoke => qr/intent-writing|intent-audit|\/intent/i,
    approval_broad => qr/approved|approve|lgtm|ship it|go ahead|proceed|do it|good to go|that works|nice|great|excellent|well done|nailed it|solid|clean|crisp/i,
    rejection_broad => qr/no[,.]|nope|wrong|redo|try again|not quite|close but|rethink|revisit|missing|forgot|skip|too (long|short|vague|verbose|generic)|doesn.t (capture|say|cover|address)/i,
);

my $match_re = $patterns{$mode} // die "Unknown mode: $mode\n";

while (my $line = <$fh>) {
    eval {
        my $obj = decode_json($line);
        my $type = $obj->{type} // "";
        return unless $type =~ /^(human|queue-operation|user)$/;

        my $content = $obj->{message}{content} // "";
        if (ref($content) eq "ARRAY") {
            $content = join(" ", map {
                ref($_) eq "HASH" ? ($_->{text} // "") : $_
            } @$content);
        }

        return if length($content) > 3000;
        return unless $content =~ $match_re;

        # Strip ANSI codes for readability
        $content =~ s/\x1b\[[0-9;]*m//g;

        print "---\n$content\n";
    };
}

close $fh;
