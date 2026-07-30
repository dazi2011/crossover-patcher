# Prebuilt proprietary component

`PatchCore` is the prebuilt proprietary release executable used to assemble the
complete Patcher app. Its source code and private unit tests are intentionally
not included in this repository. The SwiftUI app shell remains open source under
the root MIT license.

`MANIFEST.sha256` pins the exact executable committed to this history. The build
refuses to continue if its bytes or executable signature no longer validate.

The limited binary redistribution permission is defined in `LICENSE.txt`.
