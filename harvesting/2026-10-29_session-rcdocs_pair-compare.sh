#!/usr/bin/env bash
# pair-compare.sh - compare .claude/rules/X.md with .cursor/rules/X.mdc on origin/main (read-only)
set -euo pipefail
REPO=/Users/new-jose/repos/aitools
D=/Users/new-jose/repos/aitools/.scratch/session-rcdocs/pairs
mkdir -p "$D"
OUT=/Users/new-jose/repos/aitools/.scratch/session-rcdocs/pair-compare.txt
: > "$OUT"
for f in agentic-standards config-file-safety cross-platform deploy-paths documentation-standards git-safety hook-rollout interactive-menus managed-file-deployment plan-execution relay-outbound script-standards smoke-test-pattern sources-of-truth tool-lifecycle web-sources; do
  git -C "$REPO" show "origin/main:.claude/rules/$f.md" > "$D/$f.md"
  git -C "$REPO" show "origin/main:.cursor/rules/$f.mdc" > "$D/$f.mdc"
  mdl=$(wc -l < "$D/$f.md")
  mdcl=$(wc -l < "$D/$f.mdc")
  rows_md=$(perl -ne '$n++ if /^\| \x60/; END { print $n+0 }' "$D/$f.md")
  rows_mdc=$(perl -ne '$n++ if /^\| \x60/; END { print $n+0 }' "$D/$f.mdc")
  printf '%-26s md=%4s mdc=%4s  code-rows md=%3s mdc=%3s\n' "$f" "$mdl" "$mdcl" "$rows_md" "$rows_mdc" >> "$OUT"
done
printf '\n==== git-safety body diff (frontmatter differs)\n' >> "$OUT"
diff "$D/git-safety.md" "$D/git-safety.mdc" >> "$OUT" || true
printf '\n==== web-sources diff\n' >> "$OUT"
diff "$D/web-sources.md" "$D/web-sources.mdc" >> "$OUT" || true
printf '\n==== sources-of-truth rows only in md\n' >> "$OUT"
perl -ne 'print if /^\| \x60/' "$D/sources-of-truth.md" | perl -ne '/^\| (\x60[^\x60]+\x60)/ and print "$1\n"' | sort > "$D/sot-md.txt"
perl -ne 'print if /^\| \x60/' "$D/sources-of-truth.mdc" | perl -ne '/^\| (\x60[^\x60]+\x60)/ and print "$1\n"' | sort > "$D/sot-mdc.txt"
comm -23 "$D/sot-md.txt" "$D/sot-mdc.txt" >> "$OUT"
cat "$OUT"
