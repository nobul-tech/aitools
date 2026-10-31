#!/usr/bin/env bash
# Show message + stat for direct-to-main commits that are not PR squashes.
set -euo pipefail
r=/Users/new-jose/repos/aitools
for c in 9923a3c 8e490d7 5976553 1af8851 568fb5b 8953371 5494d93 32bf20c bc4aad1 60e7fd7 b2b9b60 42ed67e 6686c16 d3efa87 c412377 81d4aae 3a5f260 c1358b9 638d3ee 480b901; do
  git -C "$r" show --stat --format='==== %h %cI%n%B' "$c"
done
