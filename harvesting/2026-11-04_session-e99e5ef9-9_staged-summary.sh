#!/usr/bin/env bash
# Summarize staged changes by top-level area and status; list non-harvesting paths.
set -euo pipefail
cd /Users/new-jose/repos/aitools
git diff --cached --name-status --find-renames > "$(dirname "$0")/staged-name-status.txt"
perl -ane '
  my $st = substr($F[0], 0, 1); my $p = $F[-1];
  my ($top) = $p =~ m{^((?:\.[^/]+/)?[^/]+)};
  $top = ".aitools/channel/handoffs" if $p =~ m{^\.aitools/channel/handoffs/};
  $c{"$top $st"}++;
  END { printf "%5d  %s\n", $c{$_}, $_ for sort keys %c }
' "$(dirname "$0")/staged-name-status.txt"
echo "--- outside harvesting/ and channel/handoffs/ ---"
grep -vE '\s(harvesting|\.aitools/channel/handoffs)/' "$(dirname "$0")/staged-name-status.txt" || true
