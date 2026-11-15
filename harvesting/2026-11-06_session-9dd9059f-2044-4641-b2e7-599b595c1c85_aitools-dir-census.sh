#!/usr/bin/env bash
# aitools-dir-census.sh - breakdown of tracked files under .aitools/ and a few other dirs (read-only)
set -euo pipefail
cd /Users/new-jose/repos/aitools
for d in .aitools tests plans rfcs shared/skills .claude; do
  echo "== $d =="
  git ls-files "$d" | perl -ne 'chomp; @p=split m{/}; $n = @p > 3 ? 3 : @p - 1; $n = 1 if $n < 1; $k=join("/",@p[0..$n-1]); $c{$k}++; END { printf "%5d %s\n", $c{$_}, $_ for sort { $c{$b} <=> $c{$a} } keys %c }' | head -15
  echo
done
echo "== incidents open/closed =="
python3 -c 'import json; d=json.load(open("registries/incidents.json")); print("open:", len(d.get("incidents",[])), "closed:", len(d.get("closed",[])))'
