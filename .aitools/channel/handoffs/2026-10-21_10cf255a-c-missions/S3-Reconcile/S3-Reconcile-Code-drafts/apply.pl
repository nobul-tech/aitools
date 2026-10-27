#!/usr/bin/env perl
# apply.pl EDITS BASEDIR OUTDIR -- apply @@@FILE/@@@OLD/@@@NEW/@@@END blocks from
# EDITS to copies of BASEDIR/<file> in OUTDIR/<file>. Each OLD must occur exactly
# once in the current text (else the script dies naming the edit). A target with
# CRLF line ends gets the OLD/NEW text converted to CRLF first.
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Copy qw(copy);

my ($edits, $base, $out) = @ARGV;
die "usage: apply.pl EDITS BASEDIR OUTDIR\n" unless defined $out;
open(my $fh, '<:raw', $edits) or die "cannot read $edits: $!\n";
my @blocks;
my ($file, $mode, $old, $new, $title) = (undef, '', '', '', '');
while (my $l = <$fh>) {
    if ($l =~ /^\@\@\@FILE (\S+)\s*(.*)$/) { ($file, $title, $mode, $old, $new) = ($1, $2, '', '', ''); next; }
    if ($l =~ /^\@\@\@OLD\s*$/) { $mode = 'old'; next; }
    if ($l =~ /^\@\@\@NEW\s*$/) { $mode = 'new'; next; }
    if ($l =~ /^\@\@\@END\s*$/) { push @blocks, [$file, $title, $old, $new]; $mode = ''; next; }
    if ($mode eq 'old') { $old .= $l } elsif ($mode eq 'new') { $new .= $l }
}
close $fh;
my %done;
my $n = 0;
for my $b (@blocks) {
    my ($f, $t, $o, $nw) = @$b;
    my $dst = "$out/$f";
    if (!$done{$f}) {
        make_path(dirname($dst));
        copy("$base/$f", $dst) or die "cannot copy $base/$f: $!\n";
        $done{$f} = 1;
    }
    open(my $in, '<:raw', $dst) or die "cannot read $dst: $!\n";
    local $/; my $text = <$in>; close $in;
    if ($text =~ /\r\n/) { $o =~ s/\r?\n/\r\n/g; $nw =~ s/\r?\n/\r\n/g; }
    my $count = () = $text =~ /\Q$o\E/g;
    die "edit '$t' on $f: OLD found $count times (expected 1)\n" unless $count == 1;
    $text =~ s/\Q$o\E/$nw/;
    open(my $w, '>:raw', $dst) or die "cannot write $dst: $!\n";
    print $w $text; close $w;
    $n++;
    print "ok: $f -- $t\n";
}
print "$n edit(s) applied\n";
