# Version-bound runtime profiles

This directory contains the exact three-delta production profiles for:

- CrossOver Preview `20260717 / 27.0.0.40734`
- CrossOver `26.3 / 26.3.0.39832`

PatchCore validates every file by SHA-256 and rejects missing or additional
profile files before assembly or use. The data is version-bound and is not
covered by the MIT license for the app shell. The checked-in profiles and
prebuilt PatchCore are sufficient to assemble the complete app from a clean
clone.
