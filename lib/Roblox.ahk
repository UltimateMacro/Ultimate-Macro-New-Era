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

; Request the English-US keyboard layout only for Roblox. This does not change
; the user's Windows display language and does not globally force the layout.
EnsureRobloxEnglishInput(hwnd := 0) {
    if !hwnd
        hwnd := GetRobloxHWND()
    if !hwnd
        return 0

    ; Keep the process-id pointer null: we only need the target window thread.
    threadId := DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    if !threadId
        return 0

    ; 00000409 = English (United States). Load without KLF_ACTIVATE so the
    ; macro's own input language is not changed. Roblox receives the request.
    hkl := DllCall("user32\LoadKeyboardLayoutW", "Str", "00000409", "UInt", 0, "Ptr")
    if !hkl
        return 0

    try {
        ; WM_INPUTLANGCHANGEREQUEST
        PostMessage(0x0050, 0, hkl, , "ahk_id " hwnd)
        return 1
    } catch {
        return 0
    }
}

; Capture only the Roblox CLIENT area, never the full desktop. Returns a GDI+
; bitmap pointer or 0 when Roblox/client geometry cannot be resolved.
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

; Roblox exposes a persisted Maximum Frame Rate setting. For deterministic macro
; timing v1.3.4 standardizes on 60 FPS through that setting rather than an FPS
; unlocker or a target-FPS FastFlag. Roblox reads the XML at client launch.
;
; Return codes:
;   1  explicitly configured at target FPS
;   2  setting changed successfully (applies next Roblox launch)
;   3  Roblox is currently using its Default (-1), which is effectively 60 FPS
;  -1  Roblox settings file does not exist yet
;  -2  Roblox is running with a different persisted cap; restart is required
;  -3  settings file could not be parsed or written safely
RobloxFpsSettingsPath() {
    localAppData := EnvGet("LOCALAPPDATA")
    if (localAppData = "")
        return ""
    return RTrim(localAppData, "\/") "\Roblox\GlobalBasicSettings_13.xml"
}

RobloxFpsCapPattern() {
    ; Accept either single or double quotes around the XML attribute value.
    return "i)<int\s+name=[`"']FramerateCap[`"']\s*>\s*(-?\d+)\s*</int>"
}

ReadRobloxFpsCapFromPath(path, &fps := "") {
    fps := ""
    if (path = "" || !FileExist(path))
        return 0

    try text := FileRead(path, "UTF-8")
    catch {
        try text := FileRead(path)
        catch
            return 0
    }

    if !RegExMatch(text, RobloxFpsCapPattern(), &match)
        return 0

    try fps := Integer(match[1])
    catch
        return 0
    return 1
}

ReadRobloxFpsCap(&fps := "") {
    return ReadRobloxFpsCapFromPath(RobloxFpsSettingsPath(), &fps)
}

EnsureRobloxFpsCap(targetFps := 60) {
    targetFps := Integer(targetFps)
    if (targetFps < 30 || targetFps > 240)
        return -3

    path := RobloxFpsSettingsPath()
    if (path = "" || !FileExist(path))
        return -1

    if !ReadRobloxFpsCap(&currentFps)
        return -3

    if (currentFps = targetFps)
        return 1

    robloxRunning := GetRobloxHWND() || ProcessExist("RobloxPlayerBeta.exe")

    ; Roblox's "Default" persisted value is -1 and currently means 60 FPS. It
    ; is safe for the current session. When Roblox is closed, we still replace
    ; it with an explicit 60 so future QA/run conditions are deterministic.
    if (currentFps = -1 && targetFps = 60 && robloxRunning)
        return 3

    ; Roblox can overwrite GlobalBasicSettings_13.xml on exit. Never claim a
    ; live edit is locked in; require one clean client restart instead.
    if robloxRunning
        return -2

    try {
        text := FileRead(path, "UTF-8")
    } catch {
        try text := FileRead(path)
        catch
            return -3
    }

    ; Single-quoted AHK string avoids ambiguous nested double-quote escaping.
    replacement := '<int name="FramerateCap">' targetFps '</int>'
    updated := RegExReplace(
        text,
        RobloxFpsCapPattern(),
        replacement,
        &count,
        1
    )
    if (count != 1)
        return -3

    tempPath := path ".ultimate-macro.tmp"
    backupPath := path ".ultimate-macro.bak"
    try {
        if FileExist(tempPath)
            FileDelete(tempPath)
        FileAppend(updated, tempPath, "UTF-8-RAW")

        if !ReadRobloxFpsCapFromPath(tempPath, &tempFps) || tempFps != targetFps
            throw Error("Temporary Roblox FPS settings verification failed")

        FileCopy(path, backupPath, 1)
        FileMove(tempPath, path, 1)

        if !ReadRobloxFpsCap(&verifiedFps) || verifiedFps != targetFps
            throw Error("Roblox FPS settings verification failed after replacement")

        return 2
    } catch {
        try {
            if FileExist(tempPath)
                FileDelete(tempPath)
        }
        try {
            if FileExist(backupPath)
                FileCopy(backupPath, path, 1)
        }
        return -3
    }
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
