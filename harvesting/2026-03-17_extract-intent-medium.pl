#!/usr/bin/env perl
# Extract user messages about intents with a higher size limit (5000 chars)
# to catch medium-length conversational messages that the 2000 limit missed.
use strict;
use warnings;
use JSON::PP;

my $file = $ARGV[0] or die "Usage: $0 <jsonl-file>\n";
my $mode = $ARGV[1] // "intent";

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

        if (ref($content) eq "ARRAY") {
            $content = join(" ", map {
                ref($_) eq "HASH" ? ($_->{text} // "") : $_
            } @$content);
        }

        # Medium messages only (2000-5000 chars) - the short ones already found
        my $len = length($content);
        return if $len <= 2000 || $len > 5000;

        return unless $content =~ $match_re;

        print "---[len=$len]---\n$content\n";
    };
}

close $fh;
