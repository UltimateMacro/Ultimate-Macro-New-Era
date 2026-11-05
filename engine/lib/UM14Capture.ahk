; Ultimate Macro 1.4 engine mode — screenshot scope.
; Part of a modified version of "Ultimate Macro" by Darksen, licensed GNU GPLv3.
;
; 1.3.3a sent full-desktop screenshots to Discord. Engine mode captures only the Roblox
; client area (windows covering it can still appear). Without a Roblox window, a blank
; image is sent instead of the desktop.

UM14_RobloxBitmap() {
    hwnd := GetRobloxHWND()
    if (hwnd) {
        try {
            WinGetClientPos(&x, &y, &w, &h, "ahk_id " hwnd)
            if (w > 0 && h > 0)
                return Gdip_BitmapFromScreen(x "|" y "|" w "|" h)
        }
    }
    pBitmap := Gdip_CreateBitmap(320, 180)
    G := Gdip_GraphicsFromImage(pBitmap)
    Gdip_GraphicsClear(G, 0xFF111015)
    Gdip_DeleteGraphics(G)
    return pBitmap
}
