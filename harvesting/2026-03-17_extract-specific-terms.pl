#!/usr/bin/env perl
# Search for very specific meta-discussion terms
use strict;
use warnings;
use JSON::PP;

my $file = $ARGV[0] or die "Usage: $0 <jsonl-file>\n";

open my $fh, '<', $file or die "Cannot open $file: $!\n";

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
        return unless $content =~ /exemplar|heuristic|weighting|recen(cy|t)|signal|corpus|training|sample|calibrat/i;

        $content =~ s/\x1b\[[0-9;]*m//g;
        print "---\n$content\n";
    };
}

close $fh;
