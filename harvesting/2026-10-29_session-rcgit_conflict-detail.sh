#!/usr/bin/env bash
# conflict-detail.sh A B FILE... -- show conflicted hunks of merging branch A and B
# (merge-tree --write-tree, then print the conflict regions of each FILE from the tree).
set -uo pipefail
R=/Users/new-jose/repos/aitools
a="$1"; b="$2"; shift 2
tree=$(git -C "$R" merge-tree --write-tree "origin/$a" "origin/$b" | head -1)
echo "tree=$tree"
for f in "$@"; do
  echo "===== $f"
  git -C "$R" show "$tree:$f" | perl -ne 'if(/^<<<<<<< /){$in=1;$s=$.} if($in){print "$.: $_"} if(/^>>>>>>> /){$in=0;print "-----\n"}'
done
