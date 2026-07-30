#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SWIFTPM_SCRATCH_PATH=${MINGCHAO_PATCHER_BUILD_DIR:-${TMPDIR:-/tmp}/mingchao-patcher-swiftpm}

/usr/bin/xcrun swift test \
    --package-path "$ROOT_DIR" \
    --scratch-path "$SWIFTPM_SCRATCH_PATH"
