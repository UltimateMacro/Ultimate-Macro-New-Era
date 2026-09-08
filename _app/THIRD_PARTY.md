# Third-party components

## WebViewToo

Strategy Lab Editor downloads WebViewToo from the pinned commit:
`53fc321984d1ad9665038950f5ef4cedd1face35`

WebViewToo is Copyright (c) 2025 Ryan Dingman and distributed under the MIT License. The bootstrapper attempts to keep a copy of the upstream license at `vendor/WebViewToo/LICENSE.WebViewToo.txt`.

## Microsoft Edge WebView2 Runtime

WebView2 Runtime is a Microsoft component and is not redistributed in this ZIP. If missing, the bootstrapper uses Microsoft's official Evergreen WebView2 bootstrapper link and asks before installing it.

## AutoHotkey v2

AutoHotkey v2 is not redistributed in this ZIP. If missing, the bootstrapper offers to download the official v2 installer from `https://www.autohotkey.com/download/ahk-v2.exe`.

### Integrity verification

The bootstrapper does not accept WebViewToo payloads based on file size alone. Each of the
six runtime files is checked against the exact Git blob id recorded by pinned commit
`53fc321984d1ad9665038950f5ef4cedd1face35` before it can be used. A mismatched cached
file is deleted and re-fetched; a mismatched download is deleted and launch fails closed.

The pinned blob ids were verified against the public GitHub contents tree for that exact
commit. The native `WebView2Loader.dll` files are still third-party binaries and are never
executed by the development audit environment; final execution remains a Windows QA gate.
