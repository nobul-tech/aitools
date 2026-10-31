#!/usr/bin/env bash
# syntax-probe.sh -- probe the X3 "wide syntax loop" claim on origin/main.
# Extracts origin/main into a temp tree, then runs bash -n, /bin/bash -n,
# py_compile and perl -c over git ls-files selections. Read-only on the repo.
set -euo pipefail
repo=/Users/new-jose/repos/aitools
out=/Users/new-jose/repos/aitools/.scratch/session-s3mafrev
tree="$out/tree"
rm -rf "$tree"
mkdir -p "$tree"
git -C "$repo" archive origin/main | tar -x -C "$tree"
cd "$tree"
fail=0
total=0
while IFS= read -r f; do
    total=$((total + 1))
    if ! bash -n "$f" 2>"$out/err.txt"; then
        echo "BASH5 FAIL: $f"; cat "$out/err.txt"; fail=$((fail + 1))
    fi
    if ! /bin/bash -n "$f" 2>"$out/err.txt"; then
        echo "BASH32 FAIL: $f"; cat "$out/err.txt"; fail=$((fail + 1))
    fi
done < <(git -C "$repo" ls-tree -r --name-only origin/main | grep -E "\.sh\$" | grep -vE "^(harvesting|\.aitools)/")
echo "sh files: $total failures: $fail"
pyf=0
while IFS= read -r f; do
    if ! python3 -m py_compile "$f" 2>"$out/err.txt"; then echo "PY FAIL: $f"; cat "$out/err.txt"; pyf=$((pyf + 1)); fi
done < <(git -C "$repo" ls-tree -r --name-only origin/main | grep -E "\.py\$" | grep -vE "^(harvesting|\.aitools)/")
echo "py failures: $pyf"
plf=0
while IFS= read -r f; do
    if ! perl -c "$f" >"$out/err.txt" 2>&1; then echo "PL FAIL: $f"; cat "$out/err.txt"; plf=$((plf + 1)); fi
done < <(git -C "$repo" ls-tree -r --name-only origin/main | grep -E "\.pl\$" | grep -vE "^(harvesting|\.aitools)/")
echo "pl failures: $plf"
echo "bash used: $(command -v bash) $(bash --version | head -1)"
