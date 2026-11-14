#!/usr/bin/env perl
# insert-wrapper.pl LIB WRAPPER ANCHOR_RE -- insert WRAPPER's text (plus a blank
# line) after the first line matching ANCHOR_RE that closes a function ("}"),
# i.e. after the "}" that follows the anchor. Writes LIB in place, keeping its
# line endings (CRLF if the file has them).
use strict; use warnings;
my ($lib, $wrapper, $anchor) = @ARGV;
open my $fh, '<:raw', $lib or die "read $lib: $!"; local $/; my $t = <$fh>; close $fh;
open my $wh, '<:raw', $wrapper or die "read $wrapper: $!"; my $w = <$wh>; close $wh;
my $nl = ($t =~ /\r\n/) ? "\r\n" : "\n";
$w =~ s/\r\n/\n/g; $w =~ s/\n/$nl/g;
my $re = qr/$anchor/m;
$t =~ /$re/g or die "anchor not found";
my $pos = pos($t);
$t =~ /\G.*?^\}[^\n]*\n/msg or die "closing brace not found";
my $end = pos($t);
substr($t, $end, 0) = $nl . $w;
open my $oh, '>:raw', $lib or die "write $lib: $!"; print $oh $t; close $oh;
print "inserted after byte $end\n";
