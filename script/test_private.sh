#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

echo '[test] Public shell and protocol'
"$ROOT_DIR/script/test.sh"

echo '[test] Prebuilt PatchCore and version profiles'
(
    cd "$ROOT_DIR/PrivateComponents"
    /usr/bin/shasum -a 256 -c MANIFEST.sha256
)
/usr/bin/codesign --verify --strict --verbose=2 "$ROOT_DIR/PrivateComponents/PatchCore"
PROFILE_STAGE=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/crossover-patcher-test-profiles.XXXXXX")
trap '/bin/rm -rf "$PROFILE_STAGE"' EXIT INT TERM HUP
for profile_id in \
    preview-20260717-27.0.0.40734-singlefile \
    crossover-26.3-26.3.0.39832-singlefile; do
    /usr/bin/ditto --noqtn \
        "$ROOT_DIR/PrivateResources/$profile_id" \
        "$PROFILE_STAGE/$profile_id"
done
CROSSOVER_PATCHER_PROFILE_ROOT="$PROFILE_STAGE" \
    "$ROOT_DIR/PrivateComponents/PatchCore" verify-payload >/dev/null

echo '[test] Complete app assembly'
"$ROOT_DIR/script/build_private_app.sh" release
