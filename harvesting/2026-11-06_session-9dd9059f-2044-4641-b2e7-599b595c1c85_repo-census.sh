#!/usr/bin/env bash
# repo-census.sh - tracked file counts and sizes per top-level dir (read-only)
set -euo pipefail
cd /Users/new-jose/repos/aitools
echo "== tracked files per top-level entry =="
git ls-files | perl -ne 'chomp; ($t)=split m{/}; $c{$t}++; $s{$t}+= -s $_ if -f $_; END { printf "%-22s %6d files %9.1f KB\n", $_, $c{$_}, $s{$_}/1024 for sort { $c{$b} <=> $c{$a} } keys %c }'
echo
echo "== total tracked =="
git ls-files | wc -l
echo
echo "== harvesting tracked by extension =="
git ls-files harvesting | perl -ne 'chomp; ($e)= /\.([^.\/]+)$/ ? $1 : "none"; $c{$e}++; END { printf "%-8s %d\n", $_, $c{$_} for sort { $c{$b} <=> $c{$a} } keys %c }'
echo
echo "== untracked count in harvesting =="
git ls-files --others --exclude-standard harvesting | wc -l
echo
echo "== tracked .bak / .DS_Store / pycache =="
git ls-files | grep -E '\.bak\.|\.DS_Store|__pycache__' || echo "none"
echo
echo "== largest tracked files =="
git ls-files | while read -r f; do [ -f "$f" ] && printf '%s\t%s\n' "$(wc -c < "$f")" "$f"; done | sort -rn | head -15
echo
echo "== deploy/ tracked count =="
git ls-files deploy | wc -l
echo
echo "== rfcs, plans tracked =="
git ls-files rfcs plans | wc -l
