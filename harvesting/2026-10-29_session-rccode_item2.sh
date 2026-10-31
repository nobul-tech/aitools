#!/usr/bin/env bash
# Item 2: which open PR branches change a deploy/ input (so step 7 would FAIL on them
# even after the dotprofile deploy/ is rebuilt from main)
set -euo pipefail
R=/Users/new-jose/repos/aitools
RE='^(scripts/(setup-[^/]*|build-deploy|aitools-lib|aitools-profile|deploy-harness)\.(sh|ps1)$|scripts/aitools-json\.(pl|ps1)$|scripts/(harness-db|read-session|read-session-full)\.py$|shared/|reference/|registries/|\.claude/(hooks|skills|rules)/)'
for n in $(gh pr list -R nobul-tech/aitools --state open --json number,headRefName --jq '.[] | "\(.number):\(.headRefName)"'); do
  num=${n%%:*}; b=${n#*:}
  hits=$(git -C "$R" diff --name-only origin/main..."origin/$b" | grep -E "$RE" | tr '\n' ' ' || true)
  if [ -n "$hits" ]; then echo "#$num $b -> $hits"; else echo "#$num $b -> (none)"; fi
done
