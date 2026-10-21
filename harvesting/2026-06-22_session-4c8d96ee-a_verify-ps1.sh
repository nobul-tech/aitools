#!/usr/bin/env bash
set -uo pipefail
cd /Users/new-jose/repos/aitools

echo "=== pwsh parse: aitools-lib.ps1 ==="
pwsh -NoProfile -Command '$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile("scripts/aitools-lib.ps1",[ref]$null,[ref]$e); if($e){$e; exit 1} else {"OK ps1 parse"}'

echo ""
echo "=== embedded node-script parity (bash heredoc vs ps1 here-string) ==="
perl -ne 'print if /<<.SYNC_NODE_EOF.\s*$/../^SYNC_NODE_EOF\s*$/' scripts/aitools-lib.sh \
  | perl -ne 'next if /<<.SYNC_NODE_EOF.\s*$/; next if /^SYNC_NODE_EOF\s*$/; print' > /tmp/node_sh.js
perl -ne 'print if /^    \$nodeScript = \@.$/../^.\@\s*$/' scripts/aitools-lib.ps1 \
  | perl -ne 'next if /\$nodeScript = \@.$/; next if /^.\@\s*$/; print' > /tmp/node_ps.js
echo "bash JS lines: $(wc -l < /tmp/node_sh.js)   ps1 JS lines: $(wc -l < /tmp/node_ps.js)"
if diff -q /tmp/node_sh.js /tmp/node_ps.js >/dev/null; then echo "OK node scripts identical"; else echo "FAIL node scripts differ:"; diff /tmp/node_sh.js /tmp/node_ps.js | head -20; fi