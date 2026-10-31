#!/usr/bin/env bash
# Probe origin/main (clone at bc4aad1) for checks CI does not run (scratch, read-only)
set -u
root=/Users/new-jose/repos/aitools/.scratch/session-ma-fci/main-clone
cd "$root"
echo "## /bin/bash 3.2 -n over every tracked .sh outside harvesting/ and .aitools/"
n=0
bad=0
for f in $(git ls-files '*.sh' | grep -vE '^(harvesting|\.aitools)/'); do
    n=$((n + 1))
    if ! /bin/bash -n "$f" 2>/tmp/fci-bn.txt; then
        bad=$((bad + 1))
        echo "FAIL $f"
        head -3 /tmp/fci-bn.txt
    fi
done
echo "checked $n, failed $bad"
echo "## pwsh parser over every tracked .ps1 outside harvesting/ (CI covers only scripts/ and deploy/)"
git ls-files '*.ps1' | grep -vE '^(harvesting|\.aitools)/' | grep -vE '^(scripts|deploy)/[^/]+\.ps1$' > /tmp/fci-ps1.txt
cat /tmp/fci-ps1.txt
pwsh -NoProfile -File /Users/new-jose/repos/aitools/.scratch/session-ma-fci/parse-list.ps1 /tmp/fci-ps1.txt
echo "## perl -c on .pl"
for f in $(git ls-files '*.pl' | grep -vE '^(harvesting|\.aitools)/'); do
    perl -c "$f" 2>&1 | tail -1
done
echo "## py_compile outside scripts/"
for f in $(git ls-files '*.py' | grep -vE '^(harvesting|\.aitools|scripts)/'); do
    if python3 -I -m py_compile "$f"; then echo "ok $f"; else echo "FAIL $f"; fi
done
echo "## non-100755 tracked .sh"
git ls-files -s '*.sh' | grep -v '^100755'
echo "## hook parity"
python3 -I scripts/check-hook-parity.py shared/hooks/hooks-manifest.json scripts/setup-user-hooks.sh scripts/setup-user-hooks.ps1 scripts/build-deploy.sh
echo "parity rc=$?"
echo "## standing-order-guard smoke (clean, violation)"
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | bash shared/hooks/standing-order-guard.sh
echo "clean rc=$?"
echo '{"tool_name":"Bash","tool_input":{"command":"git status && git log"}}' | bash shared/hooks/standing-order-guard.sh 2>/dev/null
echo "violation rc=$?"
