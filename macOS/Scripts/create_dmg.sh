#!/bin/zsh
set -euo pipefail

# Skip during Xcode SwiftUI Previews or indexing builds.
if [[ "${ENABLE_PREVIEWS:-NO}" == "YES" || "${ACTION:-build}" == "indexbuild" ]]; then
    exit 0
fi

APP_NAME="${PRODUCT_NAME:-ezXplorer}"
WRAPPER="${WRAPPER_NAME:-${APP_NAME}.app}"
SOURCE_APP="${BUILT_PRODUCTS_DIR}/${WRAPPER}"

if [[ ! -d "${SOURCE_APP}" ]]; then
    echo "warning: [DMG] App bundle not found at ${SOURCE_APP}; skipping DMG creation."
    exit 0
fi

DMG_NAME="${APP_NAME}.dmg"
BUILD_DMG_PATH="${BUILT_PRODUCTS_DIR}/${DMG_NAME}"
DIST_DIR="${PROJECT_DIR}/dist"
DIST_DMG_PATH="${DIST_DIR}/${DMG_NAME}"

STAGING_DIR="$(mktemp -d "/tmp/${APP_NAME}-dmg-staging.XXXXXX")"
TMP_DMG="/tmp/${APP_NAME}-$$.dmg"

cleanup() {
    rm -rf "${STAGING_DIR}" "${TMP_DMG}"
}
trap cleanup EXIT

# Copy the built app bundle into a clean staging directory.
cp -R "${SOURCE_APP}" "${STAGING_DIR}/${WRAPPER}"

# Sign the staged bundle so the DMG copy is valid and launchable on Apple Silicon
# (Xcode's own target CodeSign phase runs immediately after Run Script phases).
STAGED_APP="${STAGING_DIR}/${WRAPPER}"
SIGN_ID="${EXPANDED_CODE_SIGN_IDENTITY:-}"
if [[ -z "${SIGN_ID}" ]]; then
    SIGN_ID="-"
fi

# Strip extended attributes that can break codesign, then ad-hoc/identity sign nested binaries & bundle.
xattr -cr "${STAGED_APP}" 2>/dev/null || true
if [[ -d "${STAGED_APP}/Contents/MacOS" ]]; then
    for bin in "${STAGED_APP}/Contents/MacOS"/*.dylib; do
        if [[ -f "${bin}" ]]; then
            /usr/bin/codesign --force --sign "${SIGN_ID}" --timestamp=none "${bin}" >/dev/null 2>&1 || true
        fi
    done
fi

ENTITLEMENTS_PATH=""
if [[ -n "${CODE_SIGN_ENTITLEMENTS:-}" ]]; then
    if [[ -f "${PROJECT_DIR}/${CODE_SIGN_ENTITLEMENTS}" ]]; then
        ENTITLEMENTS_PATH="${PROJECT_DIR}/${CODE_SIGN_ENTITLEMENTS}"
    elif [[ -f "${CODE_SIGN_ENTITLEMENTS}" ]]; then
        ENTITLEMENTS_PATH="${CODE_SIGN_ENTITLEMENTS}"
    fi
fi

if [[ -n "${ENTITLEMENTS_PATH}" ]]; then
    /usr/bin/codesign --force --sign "${SIGN_ID}" --entitlements "${ENTITLEMENTS_PATH}" --timestamp=none "${STAGED_APP}" >/dev/null 2>&1 || \
    /usr/bin/codesign --force --sign - --entitlements "${ENTITLEMENTS_PATH}" --timestamp=none "${STAGED_APP}" >/dev/null 2>&1 || true
else
    /usr/bin/codesign --force --sign "${SIGN_ID}" --timestamp=none "${STAGED_APP}" >/dev/null 2>&1 || \
    /usr/bin/codesign --force --sign - --timestamp=none "${STAGED_APP}" >/dev/null 2>&1 || true
fi

# Add standard macOS drag-to-Applications symlink.
ln -s /Applications "${STAGING_DIR}/Applications"

# Build compressed UDZO disk image.
/usr/bin/hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -quiet \
    "${TMP_DMG}"

# Place the generated DMG alongside the built .app AND in <project>/dist/ for easy access.
mkdir -p "${DIST_DIR}"
cp -f "${TMP_DMG}" "${BUILD_DMG_PATH}"
cp -f "${TMP_DMG}" "${DIST_DMG_PATH}"

echo "note: Created DMG installer at ${BUILD_DMG_PATH}"
echo "note: Copied DMG installer to ${DIST_DMG_PATH}"
