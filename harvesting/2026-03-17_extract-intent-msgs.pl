#!/usr/bin/env perl
# Extract user messages about intents, approvals, and quality feedback
# from JSONL session transcripts.
use strict;
use warnings;
use JSON::PP;

my $file = $ARGV[0] or die "Usage: $0 <jsonl-file>\n";
my $mode = $ARGV[1] // "intent"; # "intent" or "approval"

open my $fh, '<', $file or die "Cannot open $file: $!\n";

my $intent_re = qr/intent/i;
my $approval_re = qr/beautiful|perfect|looks good|lookd|thats good|that.s good|weak sauce|wtf|not right|actually|weight|recent|heuristic|exemplar/i;

my $match_re = ($mode eq "approval") ? $approval_re : $intent_re;

while (my $line = <$fh>) {
    eval {
        my $obj = decode_json($line);
        my $type = $obj->{type} // "";
        return unless $type =~ /^(human|queue-operation|user)$/;

        my $content = $obj->{message}{content} // "";

        # Handle array content (multipart messages)
        if (ref($content) eq "ARRAY") {
            $content = join(" ", map {
                ref($_) eq "HASH" ? ($_->{text} // "") : $_
            } @$content);
        }

        # Skip very long messages (plan pastes, file contents >2000 chars)
        return if length($content) > 2000;

        # Must match the pattern
        return unless $content =~ $match_re;

        print "---\n$content\n";
    };
}

close $fh;
