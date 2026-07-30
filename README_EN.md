# CrossOver Patcher

[简体中文](README.md) · [English](README_EN.md)

CrossOver Patcher is an experimental compatibility tool intended to improve CrossOver support for Windows games that use anti-cheat systems.

Currently adapted game:

- Wuthering Waves

## Supported builds

The installer accepts only these official, unmodified CrossOver applications:

| CrossOver | Exact version | Validation status |
| --- | --- | --- |
| CrossOver Preview | `20260717 / 27.0.0.40734` | Install, rollback, login, and real gameplay validated |
| CrossOver | `26.3 / 26.3.0.39832` | Install, rollback, and isolated runtime loading validated; extended real-game testing is not complete |

Other versions, modified apps, mixed runtime files, and incomplete installations are rejected. There is no force-patch bypass.

## Download and verification

Download [CrossOver-Patcher-0.2.0-macOS.zip](CrossOver-Patcher-0.2.0-macOS.zip).

SHA-256:

```text
80811f090321fd9e882d17e484ccf4a0d22b24c4083b8d363ad55294b0df6185
```

Verify in Terminal:

```sh
shasum -a 256 CrossOver-Patcher-0.2.0-macOS.zip
```

Requirements:

- Apple Silicon Mac
- macOS 14 or later
- Your own legally obtained supported CrossOver installation

This project does not provide or redistribute CrossOver, a complete Wine runtime, Game Porting Toolkit, D3DMetal, the game, or anti-cheat software.

## GUI usage

1. Extract the ZIP.
2. Open `CrossOver Patcher.app`.
3. Drag an official CrossOver app into the window, or select it with the file picker.
4. Choose an output location. The installer creates a new CrossOver app copy and never overwrites the input app.
5. Use the newly generated CrossOver app. Existing bottles and game files are not modified.

The installer creates adjacent `.cxorig` backups for the three target runtime modules and applies a local ad-hoc signature to the output app. This signature provides local integrity only; it is not an official CodeWeavers or Apple signature.

## Terminal usage

The GUI and command line use the same closed-source core:

```sh
CORE="$PWD/CrossOver Patcher.app/Contents/Helpers/PatchCore"

"$CORE" list-profiles
"$CORE" inspect "/Applications/CrossOver.app"
"$CORE" patch "/Applications/CrossOver.app" "$HOME/Applications/CrossOver Patched.app"
"$CORE" rollback "$HOME/Applications/CrossOver Patched.app"
```

Preview users should replace the path with their official `CrossOver Preview.app`. Already patched apps are rejected.

## High-level approach

The installer:

- identifies an exact CrossOver, Wine, and graphics-runtime combination;
- verifies the official signature, version, critical hashes, and PE/Mach-O structure;
- applies narrowly scoped, version-bound binary transformations inside a transactional copy;
- validates the resulting modules, backups, and app signature before committing the output;
- supports rollback through authenticated backups.

It does not modify game files, anti-cheat files, or CrossOver bottles. Future versions require a separately analyzed, built, and validated profile; the installer does not guess unknown binaries.

## Why the patcher is closed source

PatchCore and version profiles are currently proprietary. Publishing the complete implementation could make the compatibility method fail sooner and encourage unverified or unsafe variants. This repository distributes only a verifiable binary and documentation.

The proprietary status does not remove rights granted by third-party licenses such as Wine's LGPL. For at least three years after each public release, corresponding machine-readable source and build materials for LGPL-covered modifications are available on request through this repository's Issues. This written offer does not include proprietary PatchCore source.

## If macOS blocks the app or reports it as damaged

The project currently has no Apple Developer ID. The app is ad-hoc signed and not notarized.

Use this order:

1. Control-click the app in Finder, choose **Open**, and confirm.
2. If it is still blocked, use the per-app **Open Anyway** option in **System Settings → Privacy & Security**.
3. Download again and verify that the ZIP SHA-256 matches the value above.
4. Only if the checksum is correct and no per-app option is available, clear quarantine for this app only:

   ```sh
   xattr -dr com.apple.quarantine "CrossOver Patcher.app"
   ```

Do not disable SIP, Gatekeeper, XProtect, or quarantine globally. Stop if macOS explicitly identifies malware or says the app will damage the computer.

## Account risk

This is an unofficial compatibility modification and carries a non-zero account-enforcement risk. Game or anti-cheat updates may lead to restrictions, suspension, or permanent termination. No one can honestly guarantee that the risk is minor or that an account is safe. Use at your own risk, especially with important accounts.

## Privacy

The patcher runs locally and does not upload game logs, account data, or device identifiers. The release contains no telemetry.

## Independent-project disclaimer

This project is not affiliated with, endorsed by, sponsored by, or supported by Kuro Games, Tencent, CodeWeavers, Apple, or any anti-cheat vendor. CrossOver, Wine, Wuthering Waves, D3DMetal, and all other names and trademarks belong to their respective owners.
