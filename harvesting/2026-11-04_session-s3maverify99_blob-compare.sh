#!/usr/bin/env bash
# Compare PR #99 file blobs: PR head vs merge commit vs origin/main.
set -euo pipefail
repo=/Users/new-jose/repos/aitools
head=df10361be63e93f34ca4246bdb59e32f0716098a
merge=3c4f8fefe2bb8cdcc0dc20334d7a4a82232740e4
base=8a9dcb54558811235da5bb972613d374e3a124f7
p1=b40a32003f6eacf4b881129b485f80e7c81748f5
files=$(git -C "$repo" diff --name-only "$base" "$head")
for f in $files; do
  h=$(git -C "$repo" rev-parse "$head:$f")
  m=$(git -C "$repo" rev-parse "$merge:$f")
  o=$(git -C "$repo" rev-parse "origin/main:$f")
  maintouch=$(git -C "$repo" diff --name-only "$base" "$p1" -- "$f")
  later=$(git -C "$repo" log --format=%h "$merge..origin/main" -- "$f" | tr '\n' ' ')
  st1=SAME; [ "$h" = "$m" ] || st1=DIFF
  st2=SAME; [ "$h" = "$o" ] || st2=DIFF
  printf '%s head=merge:%s head=origin/main:%s main-touched-before-merge:%s later-commits:[%s]\n' "$f" "$st1" "$st2" "${maintouch:+yes}" "$later"
done
echo "--- merge commit files vs first parent (should equal PR file set) ---"
git -C "$repo" diff --name-only "$p1" "$merge" > /tmp/s3mav99-merge.txt
git -C "$repo" diff --name-only "$base" "$head" > /tmp/s3mav99-pr.txt
if cmp -s /tmp/s3mav99-merge.txt /tmp/s3mav99-pr.txt; then echo "FILE SETS EQUAL"; else echo "FILE SETS DIFFER"; diff /tmp/s3mav99-merge.txt /tmp/s3mav99-pr.txt || true; fi
echo "--- range-diff patch identity ---"
a=$(git -C "$repo" diff "$base" "$head" | git -C "$repo" patch-id --stable | cut -d' ' -f1)
b=$(git -C "$repo" diff "$p1" "$merge" | git -C "$repo" patch-id --stable | cut -d' ' -f1)
echo "pr-patch-id=$a merge-patch-id=$b"
