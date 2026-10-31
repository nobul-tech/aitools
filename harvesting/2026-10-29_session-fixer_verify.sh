#!/usr/bin/env bash
# verify.sh -- syntax checks for the S3-BuildPkg-Fixer edits (scratch, one-off)
set -uo pipefail
R=/Users/new-jose/repos/aitools
fail=0
for sh in bash /bin/bash; do
    for f in scripts/build-package.sh tests/build-package/test-cli.sh packaging/macos/postinstall \
             packaging/macos/aitools-pkg-run.sh packaging/linux/postinst packaging/linux/aitools-setup; do
        if "$sh" -n "$R/$f"; then echo "PASS $sh -n $f"; else echo "FAIL $sh -n $f"; fail=1; fi
    done
done
for f in packaging/windows/install-system.ps1 packaging/windows/install-user.ps1 packaging/windows/detect-user.ps1; do
    if pwsh -NoProfile -File "$R/.scratch/session-fixer/ps1-parse.ps1" "$R/$f"; then
        echo "PASS pwsh parse $f"
    else
        echo "FAIL pwsh parse $f"; fail=1
    fi
done
exit $fail
