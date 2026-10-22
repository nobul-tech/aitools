#!/usr/bin/env perl
# apply-edits.pl -- S3-SourceTruth batch tool: exact old->new text replacement.
#
# Usage: perl apply-edits.pl FILE EDITS_DIR PREFIX
#   Applies every pair EDITS_DIR/PREFIX-<NN>.old / PREFIX-<NN>.new in NN order.
#   Each .old text must occur in FILE exactly once (checked against the file
#   as each earlier edit left it). All edits are checked before any write:
#   on any miss or duplicate nothing is written and the exit code is 1.
use strict;
use warnings;

my ($file, $dir, $prefix) = @ARGV;
die "usage: apply-edits.pl FILE EDITS_DIR PREFIX\n" unless $file && $dir && $prefix;
sub slurp { my $p = shift; open my $h, '<:raw', $p or die "cannot read $p: $!\n"; local $/; my $c = <$h>; close $h; $c =~ s/\r\n/\n/g; return $c; }
# Line endings: a CRLF working-tree file (PS1, eol=crlf) is edited as LF and
# written back as CRLF, so the result has one line-ending style.
my $crlf = do { open my $h, '<:raw', $file or die "cannot read $file: $!\n"; my $l = <$h>; close $h; (defined $l && $l =~ /\r\n\z/) ? 1 : 0 };
my $text = slurp($file);
opendir my $dh, $dir or die "cannot open $dir: $!\n";
my @olds = sort grep { /^\Q$prefix\E-\d+\.old$/ } readdir $dh;
closedir $dh;
die "no edits for prefix $prefix in $dir\n" unless @olds;
for my $o (@olds) {
    (my $n = $o) =~ s/\.old$/.new/;
    my $old = slurp("$dir/$o");
    my $new = slurp("$dir/$n");
    my $count = () = $text =~ /\Q$old\E/g;
    die "$o: expected exactly 1 occurrence in $file, found $count -- nothing written\n" unless $count == 1;
    my $i = index($text, $old);
    substr($text, $i, length($old)) = $new;
    print "applied $o\n";
}
die "mixed line endings after edit -- nothing written\n" if $text =~ /\r/;
$text =~ s/\n/\r\n/g if $crlf;
open my $oh, '>:raw', $file or die "cannot write $file: $!\n";
print $oh $text;
close $oh or die "cannot close $file: $!\n";
print "wrote $file" . ($crlf ? " (CRLF)" : "") . "\n";
