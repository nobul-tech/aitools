#!/usr/bin/env perl
# mdm-test-keep.pl SRC DEST ROOT -- copy the MDM test, pin ROOT, and replace the
# cleanup trap with one that prints the fake-git call log (then removes TMP_ROOT)
use strict; use warnings;
my ($src, $dest, $root) = @ARGV;
open my $in, '<', $src or die "open $src: $!";
local $/; my $t = <$in>; close $in;
my $n1 = ($t =~ s{^ROOT=.*$}{ROOT="$root"}m);
my $n2 = ($t =~ s{^trap 'rm -rf "\$TMP_ROOT"' EXIT$}{trap 'echo "=== fakegit.calls ==="; cat "\$TMP_ROOT/fakegit.calls" 2>&1; ls "\$TMP_ROOT"; rm -rf "\$TMP_ROOT"' EXIT}m);
die "ROOT line not replaced\n" unless $n1 == 1;
die "trap line not replaced\n" unless $n2 == 1;
open my $out, '>', $dest or die "write $dest: $!";
print $out $t; close $out;
print "ok\n";
