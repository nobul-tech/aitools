#!/usr/bin/env bash
# checks.sh -- syntax checks of the build-package scaffold (review, read-only)
set -uo pipefail
R=/Users/new-jose/repos/aitools
for f in scripts/build-package.sh packaging/macos/postinstall packaging/macos/aitools-pkg-run.sh packaging/linux/postinst packaging/linux/aitools-setup tests/build-package/test-cli.sh; do
    if /bin/bash -n "$R/$f"; then echo "bash -n OK: $f"; else echo "bash -n FAIL: $f"; fi
done
plutil -lint "$R/packaging/macos/tech.nobul.aitools.firstrun.plist"
for f in packaging/windows/install-system.ps1 packaging/windows/install-user.ps1 packaging/windows/detect-user.ps1; do
    pwsh -NoProfile -File "$R/.scratch/session-review/parse.ps1" "$R/$f"
done
echo "--- modes"
git -C "$R" ls-files -s packaging tests/build-package scripts/build-package.sh
echo "--- CRLF / BOM in ps1"
for f in packaging/windows/install-system.ps1 packaging/windows/install-user.ps1 packaging/windows/detect-user.ps1; do
    head -c 3 "$R/$f" | od -An -tx1
    if grep -q $'\r' "$R/$f"; then echo "CRLF: $f"; else echo "LF: $f"; fi
done
echo "--- perl regex interpolation of EXCLUDE_RE (plan B2)"
EXCLUDE_RE='(\.bak\.|(^|/)\.DS_Store$)'
printf '%s\n' "shared/hooks/a.sh.bak.2026" "x/.DS_Store" ".DS_Store" "shared/ok.sh" "a.DS_Storex" | perl -ne "print unless m{$EXCLUDE_RE}"
echo "--- export-ignore attributes"
git -C "$R" check-attr export-ignore -- scripts/aitools shared/claude-shared.md
if [ -f "$R/.gitattributes" ]; then grep -n "export" "$R/.gitattributes"; else echo "no .gitattributes"; fi
