# Security and provenance notes

This is transparent source plus the original recognition dependencies; it is
not packed, obfuscated, or configured to bypass antivirus. Don't disable
antivirus, add exclusions, or assume that a detection is a false positive.

The original broad script-name cleanup and taskkill tree termination have
been replaced by handles to this app's own child or verified parent.
The macro still intentionally automates input, reads Roblox state through
its legacy routines, loads native recognition libraries, and can relaunch
Roblox when starting/recovering a strategy. These behaviors must not be hidden.

image_search.dll and opencv_world500.dll are the unchanged native files from
the supplied 1.3.3.10 ZIP. They have no reported Authenticode signer.
Retaining them preserves recognition compatibility; it is not a malware
assessment or a promise that antivirus products will accept them.

The interpreter comes from the official AutoHotkey v2.0.31 ZIP:
https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.31

Upstream archive SHA-256:
`ca1a595aca4528755d8d4cd7fed23d497a37bd9a0b6892072612d68dee1bd00a`

The update helper's pinned SHA-256 is
`ac1fe1b5e2dfcffe1d740616778c49c2e651a066229e510973659359d8a1389e`.
Its embedded public RSA key checks the owner's signed update feed; no private
key is included. Invalid, expired, modified, substituted or path-unsafe
packages must be refused. A ZIP is extracted only after the user's approval,
into a new directory, without automatically executing its contents.

Optional first-party endpoints:

* UltBot: https://remote.ultmacro.xyz/v1/remote/
* Dashboard: https://ultmacro.xyz/api/dashboard/v1/
* Verified AHK updates: https://keys.ultmacro.xyz/keys/ahk-updates/
* New signing-identity channel: https://keys.ultmacro.xyz/keys/ahk-updates-v2/

This local build pins the new v2 identity because the prior private key was
lost. Old feeds/clients are not re-trusted automatically. A one-time manual
install is required; the v2 feed is not published yet. New cache state is
isolated from old-key rollback receipts. No private signing material is bundled.

Pairing does nothing until enabled locally. Codes are not persisted.
Dashboard pairing enables authenticated website commands and uploads activity,
result/reward observations and a bounded health snapshot (including up to eight
current process names/identities). A hidden local PowerShell worker samples
health only while paired; it receives no device credential. Temperature reads
use localhost LibreHardwareMonitor or monitor WMI, never an external sensor API.
Process-close requests require a fresh listed PID, name and creation time;
system processes and the macro/health worker are protected. Disconnect or a
revoked credential cancels pending commands and automatic cooldown resumption.
Remote screenshots require additional local consent and a foreground Roblox
window; no desktop fallback exists. Temporary capture output is DPAPI sealed
and removed after use or timeout.

The retained legacy game/webhook routines can also contact Roblox, configured
Discord webhooks and the legacy Roblox-memory offset service. Their behavior
is unchanged. Keep your webhook/private-server settings private. Shared legacy
settings retain their original storage format; DPAPI here protects the new
pairing credentials, not every historical setting.

Scan the exact release ZIP with your security product. Scan results are
specific to the checked hash, engine and definition version; they are not a
cross-product safety guarantee. Report a detection and its exact file/hash
for investigation instead of recommending exclusions.
