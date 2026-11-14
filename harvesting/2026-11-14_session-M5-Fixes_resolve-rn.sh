#!/usr/bin/env bash
# resolve-rn.sh WORKTREE INSERT_VERSION -- resolve a RELEASE_NOTES.md merge
# conflict where both sides only added a new top entry: take our side (:2:),
# then insert their side's INSERT_VERSION entry (## vX.Y.Z ... up to the next
# "## v" heading) right after our top entry, so versions stay descending.
set -euo pipefail
wt="$1"
ver="$2"
tmp="$wt/.scratch/session-M5-Fixes"
git -C "$wt" cat-file -p :2:RELEASE_NOTES.md > "$tmp/rn-ours.tmp"
git -C "$wt" cat-file -p :3:RELEASE_NOTES.md > "$tmp/rn-theirs.tmp"
perl -e '
  my ($ours, $theirs, $ver) = @ARGV;
  local $/; open(my $a, "<", $ours) or die; my $o = <$a>; close $a;
  open(my $b, "<", $theirs) or die; my $t = <$b>; close $b;
  my ($entry) = $t =~ /(^## \Q$ver\E .*?)(?=^## v)/ms or die "no $ver entry in theirs\n";
  # insert before the second "## v" heading of ours (after our own top entry)
  my $n = 0; my $pos;
  while ($o =~ /^## v/mg) { $n++; if ($n == 2) { $pos = $-[0]; last } }
  die "ours has fewer than 2 entries\n" unless defined $pos;
  substr($o, $pos, 0) = $entry;
  open(my $c, ">", $ours) or die; print $c $o; close $c;
' "$tmp/rn-ours.tmp" "$tmp/rn-theirs.tmp" "$ver"
cp "$tmp/rn-ours.tmp" "$wt/RELEASE_NOTES.md"
grep -n '^## v0\.7[67]' "$wt/RELEASE_NOTES.md"
if grep -n '^<<<<<<<\|^>>>>>>>' "$wt/RELEASE_NOTES.md"; then echo "conflict markers left"; exit 1; fi
echo "resolved"
