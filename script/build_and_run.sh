#!/usr/bin/env bash

set -euo pipefail

MODE=${1:-run}
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
APP_NAME='CrossOver Patcher'
PROCESS_NAME='CrossOverPatcher'
DIST_DIR=${MINGCHAO_PATCHER_DIST_DIR:-${TMPDIR:-/tmp}/mingchao-patcher-dist}
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$PROCESS_NAME"

/usr/bin/pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true
if [[ -x "$ROOT_DIR/PrivateComponents/PatchCore" && \
      -d "$ROOT_DIR/PrivateResources/preview-20260717-27.0.0.40734-singlefile" && \
      -d "$ROOT_DIR/PrivateResources/crossover-26.3-26.3.0.39832-singlefile" ]]; then
    MINGCHAO_PATCHER_SKIP_ARCHIVE=1 \
    MINGCHAO_PATCHER_DIST_DIR="$DIST_DIR" \
        "$ROOT_DIR/script/build_private_app.sh" debug
else
    "$ROOT_DIR/script/build_app.sh" debug
fi

open_app()
{
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        /usr/bin/lldb -- "$APP_BINARY"
        ;;
    --logs|logs|--telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
        ;;
    --verify|verify)
        open_app
        for _ in 1 2 3 4 5; do
            if /usr/bin/pgrep -x "$PROCESS_NAME" >/dev/null; then
                echo '[verify] CrossOver Patcher is running'
                exit 0
            fi
            /bin/sleep 1
        done
        echo '[verify] CrossOver Patcher did not stay running' >&2
        exit 1
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
