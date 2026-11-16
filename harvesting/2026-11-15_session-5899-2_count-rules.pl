#!/usr/bin/env perl
# Count the rule-line characters in the bash and PowerShell renderers.
use strict;
use warnings;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';
my ($sh, $ps) = @ARGV;
for my $spec ([$sh, 4336], [$sh, 4365], [$ps, 4576], [$ps, 4600]) {
    my ($f, $n) = @$spec;
    open my $fh, '<:encoding(UTF-8)', $f or die "$f: $!";
    my $i = 0;
    while (my $l = <$fh>) {
        $i++;
        next unless $i == $n;
        chomp $l;
        my ($rule) = $l =~ /"([^"]*)"/;
        my $kind = $rule =~ /^\x{2500}+$/ ? 'U+2500' : ($rule =~ /^-+$/ ? 'ASCII -' : 'mixed');
        printf "%s:%d length=%d kind=%s\n", $f, $n, length($rule), $kind;
    }
    close $fh;
}
