#!/bin/bash
# build-test-pkg4.sh -- throwaway: stub .app for Intune detection inside the payload.
# NOTHING IS INSTALLED.
set -euo pipefail
S=/Users/new-jose/repos/aitools/.scratch/session-pkgmac/testpkg4
rm -rf "$S"
APP="$S/root/Library/Application Support/aitools-test/aitools-test.app"
mkdir -p "$APP/Contents/MacOS" "$S/scripts" "$S/out"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>tech.nobul.aitools-test</string>
  <key>CFBundleName</key><string>aitools-test</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.0.2</string>
  <key>CFBundleVersion</key><string>0.0.2</string>
  <key>CFBundleExecutable</key><string>aitools-test</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
printf '#!/bin/sh\nexit 0\n' > "$APP/Contents/MacOS/aitools-test"
chmod 755 "$APP/Contents/MacOS/aitools-test"
printf '#!/bin/bash\necho postinstall\nexit 0\n' > "$S/scripts/postinstall"
chmod 755 "$S/scripts/postinstall"
plutil -lint "$APP/Contents/Info.plist"
echo "== analyze =="
/usr/bin/pkgbuild --analyze --root "$S/root" "$S/out/components.plist"
cat "$S/out/components.plist"
echo "== build =="
/usr/bin/pkgbuild --root "$S/root" --component-plist "$S/out/components.plist" \
  --identifier tech.nobul.aitools-test --version 0.0.2 --install-location / \
  --scripts "$S/scripts" "$S/out/component.pkg"
/usr/bin/productbuild --package "$S/out/component.pkg" "$S/out/aitools-test-0.0.2.pkg"
/usr/sbin/pkgutil --expand "$S/out/aitools-test-0.0.2.pkg" "$S/expanded"
echo "== PackageInfo =="
cat "$S/expanded/component.pkg/PackageInfo"
echo "== Distribution =="
cat "$S/expanded/Distribution"
echo done
