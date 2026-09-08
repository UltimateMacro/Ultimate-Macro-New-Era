#Requires AutoHotkey v2.0

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

EnsureRobloxEnglishInput(hwnd := 0) {
    if !hwnd
        hwnd := GetRobloxHWND()
    if !hwnd
        return 0

    threadId := DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if !threadId
        return 0

    hkl := DllCall("user32\LoadKeyboardLayoutW", "Str", "00000409", "UInt", 0, "Ptr")
    if !hkl
        return 0

    try {
        PostMessage(0x0050, 0, hkl, , "ahk_id " hwnd)
        return 1
    } catch {
        return 0
    }
}

CaptureRobloxClientBitmap(hwnd := 0) {
    if !hwnd
        hwnd := GetRobloxHWND()
    if !hwnd
        return 0

    if !GetRobloxScreenClientRect(&x, &y, &width, &height, hwnd)
        return 0

    if (width <= 0 || height <= 0)
        return 0

    return Gdip_BitmapFromScreen(x "|" y "|" width "|" height)
}

ActivateRoblox() {
    hwnd := GetRobloxHWND()
    if !hwnd
        return 0

    try {
        WinActivate("ahk_id " hwnd)
        EnsureRobloxEnglishInput(hwnd)
        return 1
    } catch {
        return 0
    }
}
