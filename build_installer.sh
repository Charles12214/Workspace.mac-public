#!/usr/bin/env zsh
set -e

echo "🚀 Starting Workspace.mac Public Installer Build..."
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# 1. Compile the latest release app
echo "🔨 Step 1: Building Workspace.mac.app..."
./build_app.sh

APP_BUNDLE="Workspace.mac.app"
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ Error: $APP_BUNDLE was not found."
    exit 1
fi

VERSION="1.0.0"
DMG_NAME="Workspace.mac-${VERSION}.dmg"
PKG_NAME="Workspace.mac-${VERSION}.pkg"
VOL_NAME="Workspace.mac"

# 2. Generate DMG Background Asset
echo "🎨 Step 2: Generating Installer Visuals..."
swift generate_dmg_assets.swift

# 3. Create .pkg Installer
echo "📦 Step 3: Generating macOS .pkg Installer Package (${PKG_NAME})..."
rm -f "${PKG_NAME}"
pkgbuild \
    --component "${APP_BUNDLE}" \
    --install-location "/Applications" \
    --identifier "com.charlie.workspace.mac" \
    --version "${VERSION}" \
    "${PKG_NAME}"

echo "✅ Created ${PKG_NAME} successfully!"

# 4. Create .dmg Disk Image
echo "💿 Step 4: Creating macOS Disk Image (${DMG_NAME})..."

STAGING_DIR="build_dmg_staging"
rm -rf "${STAGING_DIR}" "temp.dmg" "${DMG_NAME}"
mkdir -p "${STAGING_DIR}"

# Copy App to staging
echo "   -> Copying ${APP_BUNDLE}..."
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

# Add /Applications symlink
echo "   -> Creating Applications shortcut..."
ln -s /Applications "${STAGING_DIR}/Applications"

# Add Background Asset
mkdir -p "${STAGING_DIR}/.background"
cp dmg_background.png "${STAGING_DIR}/.background/background.png"

# Copy Volume Icon if present
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns"
fi

# Calculate size needed
APP_SIZE_MB=$(du -sm "${APP_BUNDLE}" | awk '{print $1}')
DMG_SIZE_MB=$((APP_SIZE_MB + 50))

echo "   -> Creating temporary read-write disk image (${DMG_SIZE_MB}MB)..."
hdiutil create \
    -srcfolder "${STAGING_DIR}" \
    -volname "${VOL_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE_MB}m" \
    temp.dmg

echo "   -> Mounting temporary disk image for Finder visual styling..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen temp.dmg | grep "/Volumes/${VOL_NAME}" | awk '{print $3}')

if [ -z "${MOUNT_DIR}" ]; then
    MOUNT_DIR="/Volumes/${VOL_NAME}"
fi

# Apply custom Volume Icon attribute if SetFile is available
if command -v SetFile &>/dev/null && [ -f "${MOUNT_DIR}/.VolumeIcon.icns" ]; then
    SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true
fi

# Use AppleScript to position icons and set background
echo "   -> Setting Finder layout, icon sizes, and background..."
osascript <<EOF 2>/dev/null || true
tell application "Finder"
    tell disk "${VOL_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set thebounds to {100, 100, 760, 520}
        set bounds of container window to thebounds
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 110
        set text size of theViewOptions to 12
        
        try
            set background picture of theViewOptions to file ".background:background.png"
        end try
        
        -- Position app on left, Applications on right
        set position of item "${APP_BUNDLE}" of container window to {170, 210}
        set position of item "Applications" of container window to {490, 210}
        
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Sync & detach
echo "   -> Finalizing disk image..."
sync
sleep 1
hdiutil detach "${MOUNT_DIR}" -force 2>/dev/null || true

# Compress into final UDZO DMG
echo "   -> Compressing into final public release DMG..."
hdiutil convert temp.dmg \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_NAME}"

# Clean up temporary files
rm -rf "${STAGING_DIR}" temp.dmg

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "🎉 PUBLIC INSTALLERS CREATED SUCCESSFULLY!"
echo "═══════════════════════════════════════════════════════════════"
echo "1. 💿 macOS Disk Image (Recommended for Public Users):"
echo "   $(pwd)/${DMG_NAME}"
echo "   (Size: $(du -sh "${DMG_NAME}" | awk '{print $1}'))"
echo ""
echo "2. 📦 macOS Flat Package Installer:"
echo "   $(pwd)/${PKG_NAME}"
echo "   (Size: $(du -sh "${PKG_NAME}" | awk '{print $1}'))"
echo "═══════════════════════════════════════════════════════════════"
