#!/usr/bin/env bash
# S2-Layout-B scan: registry path references in aitools + dotprofile
set -euo pipefail
OUT=/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S2-Layout
PAT='(registries|reference)/(incidents|glossary|framework-registry|tool-ops|tool-registry|tool-versions)\.json'
BARE='(incidents|glossary|framework-registry|tool-ops|tool-registry|tool-versions)\.json'
cd /Users/new-jose/repos/aitools
{
for d in scripts shared .claude .cursor reference plans rfcs tests .github CLAUDE.md ROADMAP.md README.md registries .aitools/hooks; do
  [ -e "$d" ] || { echo "MISSING $d"; continue; }
  grep -rnIE "$PAT" "$d" --exclude-dir=worktrees --exclude-dir=mission-command-briefing | cut -c1-300 || true
done
} > "$OUT/s2b-aitools-prefixed.out"
{
for d in scripts shared .claude .cursor tests .github; do
  [ -e "$d" ] || continue
  grep -rnIE "$BARE" "$d" --exclude-dir=worktrees | grep -vE "$PAT" | cut -c1-300 || true
done
} > "$OUT/s2b-aitools-bare.out"
echo "top-level dirs:" > "$OUT/s2b-aitools-dirs.out"
ls -a >> "$OUT/s2b-aitools-dirs.out"
cd /Users/new-jose/repos/aitools-nobul-jose
ls -a > "$OUT/s2b-dot-dirs.out"
{
for d in claude profile.json deploy scripts .claude; do
  [ -e "$d" ] || { echo "MISSING $d"; continue; }
  grep -rnIE "$BARE" "$d" | cut -c1-300 || true
done
} > "$OUT/s2b-dot.out"
cd /Users/new-jose/repos/aitools/registries
wc -l -c ./*.json > "$OUT/s2b-sizes.out"
wc -l "$OUT"/s2b-*.out
