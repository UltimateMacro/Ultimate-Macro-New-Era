# Dependency provenance

Ultimate Macro uses a small number of third-party source and binary
dependencies. New or updated dependencies must use immutable sources and must
be reviewed before release.

## Reproducibly fetched source dependencies

`Main.ahk` directly includes OCR and JSON, but their generated copies are not
committed. Synchronize them before local validation or packaging:

```powershell
pwsh ./tools/sync_dependencies.ps1
```

The script downloads only immutable URLs and verifies both SHA-256 and Git blob
identity before installing a file.

| Dependency | Pinned source and version | Purpose | Integrity | License |
| --- | --- | --- | --- | --- |
| Descolada OCR | `Descolada/OCR@15154d1477eb21ade15dc82a62594053face757f`, OCR 2.0.0, `Lib/OCR.ahk` | Windows Media OCR wrapper used by map, reward, and result detection | Git blob `8b143a4df95e4a447389434c4f75017235339a44`; raw-download SHA-256 `ed348c0be111692c4ffeb9dcc8a9f524c575d48d7f81c8bcd96b882bb7375124` | MIT |
| thqby JSON | `thqby/ahk2_lib@4d1fe28493bcb665d7fcccce1289ed9a36df4ff0`, JSON 1.0.7, `JSON.ahk` | AHK v2 JSON parser used by Discord and GitHub API responses | Git blob `d384f62d611ffdbd16e4fcfb97fc32ec4e4e41d5`; raw-download SHA-256 `1d215d4acb9c6ac6205c1f586cc0868b72c0d557a77890e89b83a1960c9498e2` | MIT |

`lib/Roblox.ahk` is project-local GPL-3.0 source rather than a fetched third-
party dependency. It supplies the client/screen coordinate and window helpers
already required by the runtime.

## Existing native image-search files

| File | SHA-256 | Status |
| --- | --- | --- |
| `lib/ImageSearch/image_search.dll` | `346d25b9baf582b4cd5550fceaa57f4b1e18f10ae38007ba52ccd07bd790221e` | Existing unsigned upstream binary. Its source/build provenance still needs a separate binary review. |
| `lib/ImageSearch/msvcp140.dll` | `7c26614e1d733892c2deac7e245ce115504b1d80592dd0a01b08e3e5a55f89ca` | Existing Microsoft-signed runtime, version 14.51.36247.0. Prefer the official Visual C++ Redistributable in a future packaging review. |

`ImageSearch.ahk` also looks for `opencv_world500.dll`. Native OpenCV is an
optional acceleration backend, not a runtime requirement. When it is absent the
macro uses the reviewed GDI+ fallback, which now performs bounded multi-scale
template matching and preserves client-relative coordinates.

The reference `opencv_world500.dll` was audited but is not shipped in this QA
candidate because its exact build recipe/source provenance and notice bundle are
still unresolved. Audit details:

- size: 80,108,032 bytes;
- file/product version: 5.0.0;
- SHA-256: `7bc06231bf3cfd287e0b6853a78f78e00ceb58266f3cb49642f428ea6f4d1518`;
- Authenticode: unsigned;
- byte-for-byte source: the official New Era v1.3.3 `TDS_Macro.zip` asset;
- upstream OpenCV license: Apache-2.0;
- unresolved: exact compiler/build recipe and bundled notice provenance.

The reference `vcruntime140.dll` is Microsoft-signed version 14.51.36247.0
with SHA-256
`d1f4225df2cd877dbf130d5668a021dce3f94118455ff5ec952061c30afc9ce7`.
It is not committed here; install the supported Microsoft Visual C++ Redistributable instead of copying
that file into the QA candidate when the native backend is approved.

## Runtime image provenance

The PNGs restored by the pre-QA port are only the files current code directly
loads or searches for. Each is byte-identical to the official New Era v1.3.3
`TDS_Macro.zip` asset, whose SHA-256 is
`6d4cae2e3be38b4df70dc38be84c38cef89f1086d6db7f530d210762fc5cdde3`.
They ship as part of the project's GPL-3.0 release; no separate per-image
license notice was present, so the project license and attribution must remain
with redistributed copies.
Unused FULL-only images remain deferred; see `PLAN.md`.
