#!/usr/bin/env bash
# How big is a working-tree copy of the tracked files, and how long does copy + git init take?
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/pywinpty
cd "$WT"
echo "tracked files: $(git ls-files | wc -l)"
git ls-files -z | xargs -0 du -cb 2>/dev/null | tail -n 1
echo "top dirs by count:"
git ls-files | perl -ne 'm{^([^/]+)/} and $c{$1}++; END { printf "%6d %s\n", $c{$_}, $_ for sort { $c{$b} <=> $c{$a} } keys %c }' | head -n 12
T=$(mktemp -d)
start=$(date +%s)
git ls-files -z | tar --null -T - -cf - | tar -xf - -C "$T"
mid=$(date +%s)
git -C "$T" init -q
git -C "$T" add -A 2>/dev/null
end=$(date +%s)
echo "copy: $((mid - start)) s, git init+add: $((end - mid)) s, files in index: $(git -C "$T" ls-files | wc -l)"
grep -n 'git ' "$WT/scripts/build-deploy.sh" | head -n 30
rm -rf "$T"
