#!/usr/bin/env bash
# bash-n-all.sh -- bash -n each file separately (bash -n a b only parses a); also ASCII + LF checks
set -uo pipefail
R=/Users/new-jose/repos/aitools
rc=0
for f in scripts/build-package.sh packaging/macos/postinstall packaging/macos/aitools-pkg-run.sh \
         packaging/linux/postinst packaging/linux/aitools-setup tests/build-package/test-cli.sh; do
    for b in bash /bin/bash; do
        if "$b" -n "$R/$f"; then printf 'PASS bash -n (%s) %s\n' "$b" "$f"; else printf 'FAIL bash -n (%s) %s\n' "$b" "$f"; rc=1; fi
    done
done
for f in scripts/build-package.sh packaging/macos/postinstall packaging/macos/aitools-pkg-run.sh \
         packaging/macos/tech.nobul.aitools.firstrun.plist packaging/windows/install-system.ps1 \
         packaging/windows/install-user.ps1 packaging/windows/detect-user.ps1 packaging/linux/control.in \
         packaging/linux/postinst packaging/linux/aitools-setup tests/build-package/test-cli.sh; do
    if perl -ne 'exit 1 if /[^\x00-\x7f]/ || /\r/; END {}' "$R/$f"; then
        printf 'PASS ascii+lf %s (%s lines)\n' "$f" "$(wc -l < "$R/$f" | tr -d ' ')"
    else
        printf 'FAIL ascii+lf %s\n' "$f"; rc=1
    fi
done
exit "$rc"
