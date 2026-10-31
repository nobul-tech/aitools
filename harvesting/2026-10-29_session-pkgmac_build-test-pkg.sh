#!/bin/bash
# build-test-pkg.sh -- throwaway: build an unsigned component pkg and a
# distribution (product archive) pkg in scratch, then inspect them.
# NOTHING IS INSTALLED. Scratch only.
set -euo pipefail

S=/Users/new-jose/repos/aitools/.scratch/session-pkgmac/testpkg
rm -rf "$S"
mkdir -p "$S/root/Library/Application Support/aitools-test" "$S/scripts" "$S/out"

printf 'version=0.0.1\n' > "$S/root/Library/Application Support/aitools-test/VERSION"

cat > "$S/scripts/postinstall" <<'EOF'
#!/bin/bash
# test postinstall: print the args the Installer passes, and the console user.
echo "aitools-test postinstall: \$0=$0"
echo "aitools-test postinstall: \$1(pkg path)=$1"
echo "aitools-test postinstall: \$2(dest)=$2"
echo "aitools-test postinstall: \$3(target volume)=$3"
echo "aitools-test postinstall: \$4(root)=${4:-}"
echo "aitools-test postinstall: id=$(id -un) COMMAND_LINE_INSTALL=${COMMAND_LINE_INSTALL:-unset}"
console_user=$(/usr/bin/stat -f %Su /dev/console)
echo "aitools-test postinstall: console user=$console_user"
exit 0
EOF
chmod 755 "$S/scripts/postinstall"

echo "== pkgbuild (component) =="
/usr/bin/pkgbuild --root "$S/root" --identifier tech.nobul.aitools-test \
  --version 0.0.1 --install-location / --scripts "$S/scripts" \
  "$S/out/aitools-test-component.pkg"

echo "== productbuild (distribution / product archive) =="
/usr/bin/productbuild --package "$S/out/aitools-test-component.pkg" \
  "$S/out/aitools-test-0.0.1.pkg"

echo "== productbuild --synthesize (distribution XML) =="
/usr/bin/productbuild --synthesize --package "$S/out/aitools-test-component.pkg" \
  "$S/out/distribution.xml"
cat "$S/out/distribution.xml"

echo "== payload-free variant =="
/usr/bin/pkgbuild --nopayload --identifier tech.nobul.aitools-test-nopayload \
  --version 0.0.1 --scripts "$S/scripts" "$S/out/aitools-test-nopayload.pkg"

echo "== pkgutil --payload-files component =="
/usr/sbin/pkgutil --payload-files "$S/out/aitools-test-component.pkg"
echo "== pkgutil --payload-files product =="
/usr/sbin/pkgutil --payload-files "$S/out/aitools-test-0.0.1.pkg"
echo "== pkgutil --check-signature product =="
/usr/sbin/pkgutil --check-signature "$S/out/aitools-test-0.0.1.pkg" || echo "check-signature exit=$?"

echo "== pkgutil --expand product =="
/usr/sbin/pkgutil --expand "$S/out/aitools-test-0.0.1.pkg" "$S/expanded"
find "$S/expanded" | sort
echo "== expanded Distribution =="
cat "$S/expanded/Distribution"
echo "== expanded PackageInfo =="
cat "$S/expanded/aitools-test-component.pkg/PackageInfo"

echo "== installer -pkginfo / -query (read-only) =="
/usr/sbin/installer -pkginfo -pkg "$S/out/aitools-test-0.0.1.pkg" || echo "pkginfo exit=$?"

echo "== sizes =="
ls -l "$S/out"
echo "== tool locations =="
ls -l /usr/bin/pkgbuild /usr/bin/productbuild /usr/sbin/pkgutil /usr/sbin/installer
echo "done"
