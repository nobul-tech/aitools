#!/usr/bin/env bash
# resolve-rn2.sh WORKTREE FROM_VERSION UNTIL_VERSION -- resolve a
# RELEASE_NOTES.md conflict: take our side (:2:), then insert their side's
# entries from "## FROM_VERSION" up to (not including) "## UNTIL_VERSION"
# right after our top entry, so versions stay descending.
set -euo pipefail
wt="$1"
from="$2"
until_v="$3"
tmp="$wt/.scratch/session-M5-Fixes"
git -C "$wt" cat-file -p :2:RELEASE_NOTES.md > "$tmp/rn-ours.tmp"
git -C "$wt" cat-file -p :3:RELEASE_NOTES.md > "$tmp/rn-theirs.tmp"
perl -e '
  my ($ours, $theirs, $from, $until) = @ARGV;
  local $/; open(my $a, "<", $ours) or die; my $o = <$a>; close $a;
  open(my $b, "<", $theirs) or die; my $t = <$b>; close $b;
  my ($block) = $t =~ /(^## \Q$from\E .*?)(?=^## \Q$until\E )/ms or die "no $from..$until block in theirs\n";
  my $n = 0; my $pos;
  while ($o =~ /^## v/mg) { $n++; if ($n == 2) { $pos = $-[0]; last } }
  die "ours has fewer than 2 entries\n" unless defined $pos;
  substr($o, $pos, 0) = $block;
  open(my $c, ">", $ours) or die; print $c $o; close $c;
' "$tmp/rn-ours.tmp" "$tmp/rn-theirs.tmp" "$from" "$until_v"
cp "$tmp/rn-ours.tmp" "$wt/RELEASE_NOTES.md"
grep -n '^## v0\.7[67]' "$wt/RELEASE_NOTES.md"
if grep -n '^<<<<<<<\|^>>>>>>>' "$wt/RELEASE_NOTES.md"; then echo "conflict markers left"; exit 1; fi
echo "resolved"
