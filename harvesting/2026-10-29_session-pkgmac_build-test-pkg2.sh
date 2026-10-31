#!/bin/bash
# build-test-pkg2.sh -- throwaway: test which fix removes AppleDouble ._ files
# from a pkgbuild payload. NOTHING IS INSTALLED.
set -euo pipefail
S=/Users/new-jose/repos/aitools/.scratch/session-pkgmac/testpkg
echo "== A: COPYFILE_DISABLE=1 only =="
COPYFILE_DISABLE=1 /usr/bin/pkgbuild --root "$S/root" --identifier tech.nobul.aitools-test \
  --version 0.0.1 --install-location / --scripts "$S/scripts" "$S/out/a.pkg"
/usr/sbin/pkgutil --payload-files "$S/out/a.pkg"
echo "== B: xattr -cr on root, then pkgbuild =="
/usr/bin/xattr -cr "$S/root"
/usr/bin/xattr -cr "$S/scripts"
echo "xattrs after clear:"
/usr/bin/xattr -l "$S/root/Library/Application Support/aitools-test/VERSION" || echo "xattr exit=$?"
/usr/bin/pkgbuild --root "$S/root" --identifier tech.nobul.aitools-test \
  --version 0.0.1 --install-location / --scripts "$S/scripts" "$S/out/b.pkg"
/usr/sbin/pkgutil --payload-files "$S/out/b.pkg"
/usr/sbin/pkgutil --expand "$S/out/b.pkg" "$S/expanded-b"
find "$S/expanded-b" | sort
echo "== analyze (component plist) =="
/usr/bin/pkgbuild --analyze --root "$S/root" "$S/out/components.plist"
cat "$S/out/components.plist"
echo "== --version flag support =="
/usr/bin/pkgbuild --version 2>&1 | head -3 || echo "no --version"
echo done
