#!/usr/bin/env perl
# old-on-branches.pl EDITS REF... -- for each @@@FILE/@@@OLD block in EDITS,
# count occurrences of OLD in `git show REF:<file>` for each REF. Prints only
# refs where the count is not 1 (an anchor that would need re-anchoring).
use strict;
use warnings;
my ($edits, @refs) = @ARGV;
my $repo = '/Users/new-jose/repos/aitools';
open(my $fh, '<:raw', $edits) or die "cannot read $edits: $!\n";
my (@blocks, $file, $title, $old);
my $mode = '';
while (my $l = <$fh>) {
    if ($l =~ /^\@\@\@FILE (\S+)\s*(.*)$/) { ($file, $title, $mode, $old) = ($1, $2, '', ''); next; }
    if ($l =~ /^\@\@\@OLD\s*$/) { $mode = 'old'; next; }
    if ($l =~ /^\@\@\@NEW\s*$/) { $mode = 'new'; next; }
    if ($l =~ /^\@\@\@END\s*$/) { push @blocks, [$file, $title, $old]; $mode = ''; next; }
    $old .= $l if $mode eq 'old';
}
my $bad = 0;
for my $ref (@refs) {
    for my $b (@blocks) {
        my ($f, $t, $o) = @$b;
        my $text = `git -C $repo show '$ref:$f' 2>/dev/null`;
        if ($? != 0) { print "$ref: $f missing ($t)\n"; $bad++; next; }
        if ($text =~ /\r\n/) { $o =~ s/\r?\n/\r\n/g; }
        my $n = () = $text =~ /\Q$o\E/g;
        if ($n != 1) { print "$ref: '$t' OLD found $n times\n"; $bad++; }
    }
}
print "checked ", scalar(@blocks), " block(s) x ", scalar(@refs), " ref(s); $bad anchor problem(s)\n";
