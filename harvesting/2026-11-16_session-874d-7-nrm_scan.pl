#!/usr/bin/env perl
# scan.pl -- list lines of an RFC that contain RFC 2119 key words (any case)
# or vague/passive markers, for a normative-language review.
# Usage: perl scan.pl <file>
use strict;
use warnings;

my $file = shift or die "usage: scan.pl <file>\n";
open my $fh, '<', $file or die "cannot open $file: $!\n";
my $n = 0;
my $kw = qr/\b(must|shall|should|may|required|recommended|optional|cannot|can|never|always|only)\b/i;
my $vague = qr/\b(brief|short|large|small|well within|enough|appropriate|reasonable|some|several|as needed|if possible|etc|and so on|carefully|properly|relevant|significant|likely|usually|normally|generally|typically|still|already|for now|first)\b/i;
my $passive = qr/\b(is|are|was|were|be|been|being)\s+(\w+ed|written|kept|given|made|done|found|sent|taken|run|set|shown|known|chosen|held|read)\b/i;
while (my $line = <$fh>) {
    $n++;
    chomp $line;
    my @tags;
    while ($line =~ /$kw/g) { push @tags, ($1 eq uc $1 ? "KW:" : "kw:") . $1; }
    while ($line =~ /$vague/g) { push @tags, "vague:$1"; }
    while ($line =~ /$passive/g) { push @tags, "pass:$1 $2"; }
    next unless @tags;
    printf "%4d [%s] %s\n", $n, join(',', @tags), $line;
}
close $fh;
