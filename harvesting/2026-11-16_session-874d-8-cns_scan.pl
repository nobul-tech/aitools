#!/usr/bin/env perl
# scan.pl - list candidate register and consistency defects in an RFC, by line
use strict;
use warnings;

my $file = shift or die "usage: scan.pl <file>\n";
open my $fh, '<', $file or die "cannot open $file: $!\n";
my @checks = (
    [ 'contraction',   qr/\b\w+(?:n't|'s|'re|'ll|'ve|'d)\b/ ],
    [ 'first-person',  qr/\b(?:we|our|us|I|my|me)\b/ ],
    [ 'informal',      qr/\b(?:just|simply|really|very|a lot|kind of|for now|still|already|gets?|got|stuff|things?|nothing is done|whatever)\b/i ],
    [ 'lower-2119',    qr/(?<![A-Z"])\b(?:must|should|may|shall|required|optional|recommended)\b(?![A-Z])/ ],
    [ 'abbrev',        qr/\b(?:RFI|DB|WAL|DDL|WP|CLI|SHA|URL|UTC|PR|OL|SITREP|SPOTREP|TC|FM|ADP|AR|JSON|SQL|ASM|AMB|BCP|hex|ids?)\b/ ],
    [ 'placeholder',   qr/<[a-zA-Z][^>]*>/ ],
    [ 'synonym',       qr/\b(?:hand-back|handback|hand back|report|briefing|delegator|subagent|sub-agent|scratch dir\b|session commander|top-level session|session agent)\b/i ],
);
my $n = 0;
while (my $line = <$fh>) {
    $n++;
    chomp $line;
    (my $plain = $line) =~ s/"[^"]*"//g;    # drop quoted text
    for my $c (@checks) {
        my ($name, $re) = @$c;
        my @hits;
        while ($plain =~ /($re)/g) { push @hits, $1; }
        next unless @hits;
        my %seen;
        my @u = grep { !$seen{$_}++ } @hits;
        printf "%4d %-13s %s\n", $n, $name, join(', ', @u);
    }
}
close $fh;
