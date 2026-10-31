#!/bin/bash
# build-test-pkg3.sh -- throwaway: does --filter remove generated ._ entries? NOTHING IS INSTALLED.
set -euo pipefail
S=/Users/new-jose/repos/aitools/.scratch/session-pkgmac/testpkg
/usr/bin/pkgbuild --root "$S/root" --identifier tech.nobul.aitools-test \
  --version 0.0.1 --install-location / --scripts "$S/scripts" \
  --filter '/\.svn($|/)' --filter '/CVS($|/)' --filter '/\.DS_Store$' --filter '/\._' \
  "$S/out/c.pkg"
/usr/sbin/pkgutil --payload-files "$S/out/c.pkg"
echo "== which xattrs on dirs =="
/usr/bin/xattr -l "$S/root/Library"
echo "== whoami / sandbox hint =="
id -un
echo "TMPDIR=$TMPDIR"
echo done
