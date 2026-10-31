#!/bin/bash
# Wait until wave-1 delegate files exist (or 90 min), printing each as it appears.
set -euo pipefail
d=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-BuildPkg
files="S3-BuildPkg-RevBuild-findings.md S3-BuildPkg-RevInstall-findings.md S3-BuildPkg-RevLib-findings.md S3-BuildPkg-RevSetup-findings.md S3-BuildPkg-RevTools-findings.md S3-BuildPkg-PkgWin-notes.md S3-BuildPkg-PkgMac-notes.md S3-BuildPkg-PkgLinux-notes.md S3-BuildPkg-Lang-evaluation.md S3-BuildPkg-DocsInv-inventory.md"
seen=""
end=$(( $(date +%s) + 5400 ))
while [ "$(date +%s)" -lt "$end" ]; do
  n=0
  for f in $files; do
    if [ -f "$d/$f" ]; then
      n=$((n+1))
      case " $seen " in *" $f "*) ;; *) echo "present: $f"; seen="$seen $f" ;; esac
    fi
  done
  if [ "$n" -eq 10 ]; then echo "all 10 present"; exit 0; fi
  sleep 30
done
echo "timeout: $n of 10"
