# Update signing identity v2

The prior private signing key was lost. This build pins a new RSA-4096 public
key and uses the separate HTTPS channel:

`https://keys.ultmacro.xyz/keys/ahk-updates-v2/`

Public SPKI SHA-256:
`a79a3b30f06178c992ec7f87dcff44dde2e5481501637cc30fd2a0a7451d88b9`

The public PEM included here is for independent verification. The helper pins
the same identity in its executable; changing a PEM/settings file cannot alter
its trust. No private signing key or recovery secret is shipped.

Older builds do not trust this replacement key. Install this ZIP manually once
from the owner's verified release/download before using future signed updates.
Signatures are not bypassed, and the old AHK/EXE update feeds are not rewritten.

This ZIP uses the separately signed v2 feed. If a feed is temporarily unavailable
or its signed offer has expired, verification refuses the update instead of
falling back to unsigned files or a different key. Installation still asks
for approval and extracts to a separate version folder without restarting the
macro. V2 cache/install state uses `VerifiedUpdatesV2`, separate from the old
signing identity's cache.
