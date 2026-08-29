#Requires AutoHotkey v2.0

/***********************************************************
 * Roblox window helpers for Ultimate Macro: New Era.
 *
 * GetRobloxClientPos / GetRobloxHWND / ActivateRoblox are based on
 * the SP/Natro-style helpers already used by the project family.
 * `getRobloxPos` intentionally returns CLIENT-relative x/y (0,0),
 * matching CoordMode("Mouse", "Client") and CoordMode("Pixel", "Client").
 ***********************************************************/

GetRobloxClientPos(hwnd?) {
    global windowX, windowY, windowWidth, windowHeight

    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()

    if !hwnd
        return windowX := windowY := windowWidth := windowHeight := 0

    try {
        WinGetClientPos(&windowX, &windowY, &windowWidth, &windowHeight, "ahk_id " hwnd)
        return 1
    } catch TargetError {
        windowX := windowY := windowWidth := windowHeight := 0
        return 0
    }
}

; Returns coordinates in Roblox CLIENT space. The client origin is always 0,0.
getRobloxPos(&x := "", &y := "", &width := "", &height := "", hwnd := "") {
    if !hwnd
        hwnd := GetRobloxHWND()

    if !hwnd {
        x := y := width := height := 0
        return 0
    }

    rect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rect, "Int") {
        x := y := width := height := 0
        return 0
    }

    x := 0
    y := 0
    width := NumGet(rect, 8, "Int")
    height := NumGet(rect, 12, "Int")
    return (width > 0 && height > 0)
}

; Returns the Roblox client rectangle in SCREEN coordinates.
GetRobloxScreenClientRect(&x := "", &y := "", &width := "", &height := "", hwnd := "") {
    if !hwnd
        hwnd := GetRobloxHWND()

    if !hwnd {
        x := y := width := height := 0
        return 0
    }

    try {
        WinGetClientPos(&x, &y, &width, &height, "ahk_id " hwnd)
        return (width > 0 && height > 0)
    } catch TargetError {
        x := y := width := height := 0
        return 0
    }
}

; Returns hWnd on success, 0 when Roblox is not found.
GetRobloxHWND() {
    if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
        return hwnd

    if WinExist("Roblox ahk_exe ApplicationFrameHost.exe") {
        try
            return ControlGetHwnd("ApplicationFrameInputSinkWindow1")
        catch TargetError
            return 0
    }

    return 0
}

ActivateRoblox() {
    hwnd := GetRobloxHWND()
    if !hwnd
        return 0

    try {
        WinActivate("ahk_id " hwnd)
        return 1
    } catch {
        return 0
    }
}
