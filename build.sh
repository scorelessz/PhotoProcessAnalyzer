#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

NAME="PhotoProcessAnalyzer"
CONFIG="release"

echo "==> 编译通用二进制 (arm64 + x86_64)"
swift build -c "$CONFIG" --arch arm64 --arch x86_64

BIN=".build/$CONFIG/$NAME"
BUNDLE="$NAME.app"
RES=".build/$CONFIG/${NAME}_${NAME}.bundle/Contents/Resources"

echo "==> 组装 $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/$NAME"
cp "$RES"/* "$BUNDLE/Contents/Resources/"

cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleDisplayName</key><string>照片处理工具 · 逆向分析</string>
    <key>CFBundleExecutable</key><string>PhotoProcessAnalyzer</string>
    <key>CFBundleIdentifier</key><string>com.example.photoprocessanalyzer</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>PhotoProcessAnalyzer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key><true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

echo "==> 签名 (ad-hoc)"
codesign --force --deep -s - "$BUNDLE"

echo "==> 打包 dmg"
mkdir -p dist
rm -f "dist/$NAME.dmg"
hdiutil create -volname "照片处理工具 逆向分析" -srcfolder "$BUNDLE" -ov -format UDZO "dist/$NAME.dmg" >/dev/null

echo "完成：dist/$NAME.dmg"
