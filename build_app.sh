#!/usr/bin/env zsh
set -e
setopt +o nomatch 2>/dev/null || true

killall Workspace 2>/dev/null || true
killall Workspace.mac 2>/dev/null || true
rm -f .build/out/Products/Release/Workspace.dSYM 2>/dev/null || true
rm -rf .build/out/Products/Release/*.dSYM* 2>/dev/null || true
rm -rf .build/out/Products/*/*dSYM* 2>/dev/null || true
rm -rf .build/*/*dSYM* 2>/dev/null || true
find .build -name "*dSYM*" -exec rm -rf {} + 2>/dev/null || true
sleep 0.5

echo "🔨 Building Workspace for macOS (Release)..."
export SDKROOT=$(xcrun --show-sdk-path)
# Standalone CommandLineTools SDK 27.x omits libSwiftUIMacros.dylib; fall back to MacOSX26.sdk if needed.
if [[ "$SDKROOT" == *"/CommandLineTools/"* ]] && \
   [ ! -f "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib" ] && \
   [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk" ]; then
    export SDKROOT="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
fi
BUILD_DIR="/tmp/workspace-build"

swift build -c release --build-path "$BUILD_DIR"

BINARY_NAME="Workspace"
APP_NAME="Workspace.mac"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling ${APP_DIR} bundle..."
rm -rf "${APP_DIR}" "Workspace.app"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp "${BUILD_DIR}/release/${BINARY_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Copy image resources
mkdir -p "${RESOURCES_DIR}/Images"
if [ -d "Resources/Images" ]; then
    cp -r Resources/Images/* "${RESOURCES_DIR}/Images/"
fi

# Copy Extensions (OfflineSuite only)
mkdir -p "${RESOURCES_DIR}/Extensions/OfflineSuite"
if [ -d "Extensions/OfflineSuite" ]; then
    cp -r Extensions/OfflineSuite/* "${RESOURCES_DIR}/Extensions/OfflineSuite/"
fi

# Write Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Workspace.mac</string>
    <key>CFBundleDisplayName</key>
    <string>Workspace.mac</string>
    <key>CFBundleIdentifier</key>
    <string>com.workspacemac.app</string>
    <key>CFBundleVersion</key>
    <string>1.3.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.3.0</string>
    <key>CFBundleExecutable</key>
    <string>Workspace.mac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>NSCameraUsageDescription</key>
    <string>Workspace requires camera access for Google Meet conferences.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Workspace requires microphone access for Google Meet and voice notes.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Workspace uses your location locally to fetch weather conditions for the ambient widget. Coordinates are encrypted on-device.</string>
</dict>
</plist>
EOF

# Write PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Ad-hoc code signing for local macOS execution
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true

echo "✨ Successfully built ${APP_DIR}!"
echo "🚀 Run it with: open ${APP_DIR}"
