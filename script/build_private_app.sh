#!/usr/bin/env bash

set -euo pipefail

CONFIGURATION=${1:-release}
case "$CONFIGURATION" in
    debug|release) ;;
    *) echo "usage: $0 [debug|release]" >&2; exit 2 ;;
esac

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROFILE_ROOT="$ROOT_DIR/PrivateResources"
PROFILE_IDS=(
    'preview-20260717-27.0.0.40734-singlefile'
    'crossover-26.3-26.3.0.39832-singlefile'
)
COMPONENTS_ROOT="$ROOT_DIR/PrivateComponents"
APP_DIST_DIR=${MINGCHAO_PATCHER_DIST_DIR:-${TMPDIR:-/tmp}/crossover-patcher-dist}
ARTIFACT_DIR=${MINGCHAO_PATCHER_ARTIFACT_DIR:-"$ROOT_DIR/dist"}
APP="$APP_DIST_DIR/CrossOver Patcher.app"
ARCHIVE="$ARTIFACT_DIR/CrossOver-Patcher-0.2.0-macOS.zip"
CHECKSUMS="$ARTIFACT_DIR/SHA256SUMS.txt"
CORE_BINARY="$COMPONENTS_ROOT/PatchCore"
PROFILE_STAGE=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/crossover-patcher-profiles.XXXXXX")
ARCHIVE_STAGE=

cleanup()
{
    [[ ! -d $PROFILE_STAGE ]] || /bin/rm -rf "$PROFILE_STAGE"
    [[ -z $ARCHIVE_STAGE || ! -d $ARCHIVE_STAGE ]] || /bin/rm -rf "$ARCHIVE_STAGE"
}
trap cleanup EXIT INT TERM HUP

[[ -x "$CORE_BINARY" && ! -L "$CORE_BINARY" ]] || {
        echo 'Missing prebuilt PatchCore binary. Clone the complete repository.' >&2
    exit 1
}
for profile_id in "${PROFILE_IDS[@]}"; do
    [[ -d "$PROFILE_ROOT/$profile_id" ]] || {
        echo "Missing version profile: $PROFILE_ROOT/$profile_id" >&2
        exit 1
    }
done

echo '[build] Verifying repository profile manifest'
(
    cd "$PROFILE_ROOT"
    /usr/bin/shasum -a 256 -c MANIFEST.sha256
)
for profile_id in "${PROFILE_IDS[@]}"; do
    /usr/bin/ditto --noqtn "$PROFILE_ROOT/$profile_id" "$PROFILE_STAGE/$profile_id"
done

echo '[build] Verifying prebuilt PatchCore binary'
(
    cd "$COMPONENTS_ROOT"
    /usr/bin/shasum -a 256 -c MANIFEST.sha256
)
/usr/bin/codesign --verify --strict --verbose=2 "$CORE_BINARY"
CORE_SHA256=$(/usr/bin/shasum -a 256 "$CORE_BINARY" | /usr/bin/awk '{print $1}')

echo '[build] Verifying profiles before assembly'
CROSSOVER_PATCHER_PROFILE_ROOT="$PROFILE_STAGE" "$CORE_BINARY" verify-payload >/dev/null

echo '[build] Assembling complete Patcher app'
MINGCHAO_PATCHER_DIST_DIR="$APP_DIST_DIR" \
PATCH_CORE_BINARY="$CORE_BINARY" \
PATCH_CORE_SHA256="$CORE_SHA256" \
PATCH_CORE_RESOURCES="$PROFILE_STAGE" \
REQUIRE_PATCH_CORE=1 \
    "$ROOT_DIR/script/build_app.sh" "$CONFIGURATION"

"$ROOT_DIR/script/verify_private_app.sh" "$APP"

if [[ ${MINGCHAO_PATCHER_SKIP_ARCHIVE:-0} != 1 ]]; then
    /bin/mkdir -p "$ARTIFACT_DIR"
    ARCHIVE_STAGE=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/crossover-patcher-archive.XXXXXX")
    STAGE_ARCHIVE="$ARCHIVE_STAGE/CrossOver-Patcher-0.2.0-macOS.zip"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGE_ARCHIVE"
    /usr/bin/unzip -t "$STAGE_ARCHIVE" >/dev/null

    if [[ -e $ARCHIVE ]]; then
        PREVIOUS="$ARTIFACT_DIR/previous"
        /bin/mkdir -p "$PREVIOUS"
        TIMESTAMP=$(/bin/date '+%Y%m%d-%H%M%S')
        /bin/mv "$ARCHIVE" "$PREVIOUS/CrossOver-Patcher-0.2.0-macOS-$TIMESTAMP.zip"
    fi
    /bin/mv "$STAGE_ARCHIVE" "$ARCHIVE"
    /usr/bin/shasum -a 256 "$ARCHIVE" > "$CHECKSUMS"
    echo "[build] Archive: $ARCHIVE"
    /bin/cat "$CHECKSUMS"
fi

echo "[build] App: $APP"
