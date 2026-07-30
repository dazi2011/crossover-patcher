#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
APP=${1:-"${MINGCHAO_PATCHER_DIST_DIR:-${TMPDIR:-/tmp}/crossover-patcher-dist}/CrossOver Patcher.app"}
CONTENTS="$APP/Contents"
SHELL_BINARY="$CONTENTS/MacOS/CrossOverPatcher"
CORE_BINARY="$CONTENTS/Helpers/PatchCore"
PAYLOAD="$CONTENTS/Resources/PatchCoreResources"

[[ -d $APP && ! -L $APP ]] || { echo "Invalid app bundle: $APP" >&2; exit 1; }
[[ -x $SHELL_BINARY && ! -L $SHELL_BINARY ]] || { echo 'Missing shell executable.' >&2; exit 1; }
[[ -x $CORE_BINARY && ! -L $CORE_BINARY ]] || { echo 'Missing PatchCore executable.' >&2; exit 1; }
[[ -d $PAYLOAD && ! -L $PAYLOAD ]] || { echo 'Missing version profiles.' >&2; exit 1; }

/usr/bin/plutil -lint "$CONTENTS/Info.plist" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
"$CORE_BINARY" verify-payload >/dev/null

FILE_COUNT=$(/usr/bin/find "$PAYLOAD" -type f | /usr/bin/wc -l | /usr/bin/tr -d ' ')
[[ $FILE_COUNT == 6 ]] || { echo "Unexpected payload file count: $FILE_COUNT" >&2; exit 1; }

while IFS= read -r -d '' candidate; do
    if /usr/bin/strings "$candidate" 2>/dev/null | /usr/bin/grep -Eq '/Users/|/Volumes/'; then
        echo "Absolute build path leak: $candidate" >&2
        exit 1
    fi
done < <(/usr/bin/find "$APP" -type f -print0)

echo '[verify] Complete app bundle passed'
/usr/bin/file "$SHELL_BINARY" "$CORE_BINARY"
/usr/bin/shasum -a 256 "$SHELL_BINARY" "$CORE_BINARY"
