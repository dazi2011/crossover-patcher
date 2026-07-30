#!/usr/bin/env bash

set -euo pipefail

CONFIGURATION=${1:-debug}
case "$CONFIGURATION" in
    debug) SWIFT_CONFIGURATION=debug ;;
    release) SWIFT_CONFIGURATION=release ;;
    *) echo "usage: $0 [debug|release]" >&2; exit 2 ;;
esac

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
APP_NAME='CrossOver Patcher'
EXECUTABLE_NAME='CrossOverPatcher'
SWIFT_PRODUCT_NAME='MingchaoPatcher'
DIST_DIR=${MINGCHAO_PATCHER_DIST_DIR:-${TMPDIR:-/tmp}/mingchao-patcher-dist}
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
/bin/mkdir -p "$DIST_DIR"
STAGE_DIR=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/mingchao-patcher-assemble.XXXXXX")
STAGE_APP="$STAGE_DIR/$APP_NAME.app"
STAGE_CONTENTS="$STAGE_APP/Contents"
PATCH_CORE_BINARY=${PATCH_CORE_BINARY:-}
PATCH_CORE_RESOURCES=${PATCH_CORE_RESOURCES:-}
PATCH_CORE_SHA256=${PATCH_CORE_SHA256:-}
REQUIRE_PATCH_CORE=${REQUIRE_PATCH_CORE:-0}
SWIFTPM_SCRATCH_PATH=${MINGCHAO_PATCHER_BUILD_DIR:-${TMPDIR:-/tmp}/mingchao-patcher-swiftpm}
PREFIX_MAP="$ROOT_DIR=/public-source"

cleanup()
{
    /bin/rm -rf "$STAGE_DIR"
}
trap cleanup EXIT INT TERM HUP

/bin/mkdir -p "$STAGE_CONTENTS/MacOS" "$STAGE_CONTENTS/Resources"

echo "[build] Compiling public shell ($SWIFT_CONFIGURATION)"
/usr/bin/xcrun swift build \
    --package-path "$ROOT_DIR" \
    --scratch-path "$SWIFTPM_SCRATCH_PATH" \
    -c "$SWIFT_CONFIGURATION" \
    -Xswiftc -file-prefix-map \
    -Xswiftc "$PREFIX_MAP"
BIN_DIR=$(/usr/bin/xcrun swift build \
    --package-path "$ROOT_DIR" \
    --scratch-path "$SWIFTPM_SCRATCH_PATH" \
    -c "$SWIFT_CONFIGURATION" \
    -Xswiftc -file-prefix-map \
    -Xswiftc "$PREFIX_MAP" \
    --show-bin-path)
/usr/bin/install -m 0755 "$BIN_DIR/$SWIFT_PRODUCT_NAME" "$STAGE_CONTENTS/MacOS/$EXECUTABLE_NAME"
/usr/bin/strip -S -x "$STAGE_CONTENTS/MacOS/$EXECUTABLE_NAME"
/usr/bin/install -m 0644 "$ROOT_DIR/Resources/Info.plist" "$STAGE_CONTENTS/Info.plist"
/usr/bin/ditto --noqtn "$ROOT_DIR/Resources/Licenses" "$STAGE_CONTENTS/Resources/Licenses"
/usr/bin/install -m 0644 "$ROOT_DIR/Resources/THIRD_PARTY_NOTICES.txt" \
    "$STAGE_CONTENTS/Resources/THIRD_PARTY_NOTICES.txt"
/usr/bin/install -m 0644 "$ROOT_DIR/Resources/PatchCore-NOTICE.txt" \
    "$STAGE_CONTENTS/Resources/PatchCore-NOTICE.txt"

if [[ -n $PATCH_CORE_BINARY ]]; then
    if [[ ! -f $PATCH_CORE_BINARY || ! -x $PATCH_CORE_BINARY ]]; then
        echo "PATCH_CORE_BINARY is not an executable file: $PATCH_CORE_BINARY" >&2
        exit 1
    fi
    if [[ -z $PATCH_CORE_SHA256 ]]; then
        echo 'PATCH_CORE_SHA256 is required when packaging PatchCore.' >&2
        exit 1
    fi
    ACTUAL_CORE_SHA256=$(/usr/bin/shasum -a 256 "$PATCH_CORE_BINARY" | /usr/bin/awk '{print $1}')
    if [[ $ACTUAL_CORE_SHA256 != "$PATCH_CORE_SHA256" ]]; then
        echo 'PATCH_CORE_BINARY hash mismatch.' >&2
        exit 1
    fi
    /bin/mkdir -p "$STAGE_CONTENTS/Helpers"
    /usr/bin/install -m 0755 "$PATCH_CORE_BINARY" "$STAGE_CONTENTS/Helpers/PatchCore"
    /usr/bin/codesign --force --sign - --timestamp=none "$STAGE_CONTENTS/Helpers/PatchCore"
    if [[ -z $PATCH_CORE_RESOURCES || ! -d $PATCH_CORE_RESOURCES ]]; then
        echo 'PATCH_CORE_RESOURCES must point to the separately prepared private resources.' >&2
        exit 1
    fi
    /usr/bin/env CROSSOVER_PATCHER_PROFILE_ROOT="$PATCH_CORE_RESOURCES" \
        "$PATCH_CORE_BINARY" verify-payload >/dev/null
    PRIVATE_TARGET="$STAGE_CONTENTS/Resources/PatchCoreResources"
    /usr/bin/ditto --noqtn "$PATCH_CORE_RESOURCES" "$PRIVATE_TARGET"
    "$STAGE_CONTENTS/Helpers/PatchCore" verify-payload >/dev/null
elif [[ $REQUIRE_PATCH_CORE == 1 ]]; then
    echo 'Official release assembly requires PATCH_CORE_BINARY.' >&2
    exit 1
else
    echo '[build] Public-shell build: PatchCore intentionally absent'
fi

echo '[build] Applying ad-hoc signature'
# The bundle is generated entirely in staging. Clear source-control/Finder/File
# Provider metadata copied from the workspace before sealing its resources.
/usr/bin/xattr -cr "$STAGE_APP"
/usr/bin/codesign --force --sign - --timestamp=none "$STAGE_APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$STAGE_APP"
/usr/bin/plutil -lint "$STAGE_CONTENTS/Info.plist" >/dev/null

while IFS= read -r -d '' candidate; do
    if /usr/bin/strings "$candidate" 2>/dev/null | /usr/bin/grep -Eq '/Users/|/Volumes/'; then
        echo "release path leak detected in $candidate" >&2
        exit 1
    fi
done < <(/usr/bin/find "$STAGE_APP" -type f -print0)

if [[ -e $APP_BUNDLE ]]; then
    ARCHIVE_DIR="$DIST_DIR/previous"
    /bin/mkdir -p "$ARCHIVE_DIR"
    TIMESTAMP=$(/bin/date '+%Y%m%d-%H%M%S')
    /bin/mv "$APP_BUNDLE" "$ARCHIVE_DIR/$APP_NAME-$TIMESTAMP.app"
fi
/bin/mv "$STAGE_APP" "$APP_BUNDLE"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "[build] App: $APP_BUNDLE"
/usr/bin/file "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
/usr/bin/shasum -a 256 "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
