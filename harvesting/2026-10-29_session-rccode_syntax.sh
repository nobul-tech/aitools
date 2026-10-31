#!/usr/bin/env bash
# bash -n and pwsh parser on every drafted file
set -euo pipefail
S=/Users/new-jose/repos/aitools/.scratch/session-rccode
rc=0
for f in out/pr106/aitools out/pr106/aitools-install.sh out/main/aitools-lib.sh out2/main/aitools out2/main/setup-user-config.sh out3/main/check-pre-push.sh; do
  if bash -n "$S/$f"; then echo "bash -n ok: $f"; else echo "bash -n FAIL: $f"; rc=1; fi
done
pwsh -NoProfile -File "$S/parse.ps1" "$S/out/pr106/aitools.ps1" "$S/out/pr106/aitools-install.ps1" "$S/out/main/aitools-lib.ps1" "$S/out2/main/aitools.ps1" "$S/out2/main/setup-user-config.ps1" "$S/out3/main/check-pre-push.ps1" || rc=1
echo "-- pushFiles defined in check-pre-push.ps1:"
grep -n 'pushFiles =' "$S/base/main/check-pre-push.ps1" || echo "  NOT FOUND"
echo "-- CRLF preserved in ps1 outputs (count of LF-only lines should be 0):"
for f in out/pr106/aitools.ps1 out/pr106/aitools-install.ps1 out/main/aitools-lib.ps1 out2/main/aitools.ps1 out2/main/setup-user-config.ps1 out3/main/check-pre-push.ps1; do
  n=$(perl -ne '$c++ if /(?<!\r)\n\z/; END { print $c+0 }' "$S/$f")
  b=$(perl -ne '$c++ if /(?<!\r)\n\z/; END { print $c+0 }' "$S/base/${f#out*/}")
  echo "$f: LF-only lines $n (base $b)"
done
exit $rc
