; Passive game-input playback. Part of Ultimate Macro's GPLv3 engine bridge.
; Fixed data grammar only: no Eval, external executable or arbitrary callback.
global UM14_ReplayHeld := Map()

UM14_InputFence() {
    global UM14_ReplayHeld
    if (!UM14_ReplayHeld.Count) {
        SetTimer(UM14_InputFence, 0)
        return
    }
    hwnd := GetRobloxHWND()
    root := hwnd ? DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") : 0
    if (!UM14_LauncherAlive() || !UM14_SessionCurrent() || !hwnd || !WinActive("ahk_id " (root ? root : hwnd))) {
        UM14_ReleaseInputs()
        UM14_Fatal("Recorded input stopped because its game or owner changed.")
    }
}

UM14_InputPoint(x, y) {
    global StrategyWidth, StrategyHeight
    if (StrategyWidth < 240 || StrategyWidth > 8192 || StrategyHeight < 240 || StrategyHeight > 8192
        || x < 0 || x >= StrategyWidth || y < 0 || y >= StrategyHeight)
        UM14_Fatal("Recorded input point is invalid.")
    UM14_RequireReadyFocus()
    hwnd := GetRobloxHWND()
    WinGetClientPos(&sx, &sy, &width, &height, "ahk_id " hwnd)
    px := Min(width-1, Round(x*width/StrategyWidth))
    py := Min(height-1, Round(y*height/StrategyHeight))
    CoordMode("Mouse", "Client")
    MouseMove(px, py, 0)
    UM14_RequireReadyFocus()
    point := (sx+px) & 0xFFFFFFFF | ((sy+py) << 32)
    under := DllCall("WindowFromPoint", "Int64", point, "Ptr")
    root := under ? DllCall("GetAncestor", "Ptr", under, "UInt", 2, "Ptr") : 0
    gameRoot := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (!under || (root ? root : under) != (gameRoot ? gameRoot : hwnd))
        UM14_Fatal("Recorded input was blocked by an overlapping window.")
}

UM14_InputEdge(key, edge) {
    global UM14_ReplayHeld
    key := StrUpper(key)
    if (edge = "down") {
        if (UM14_ReplayHeld.Has(key) || GetKeyState(key, "P"))
            UM14_Fatal("Recorded input cannot take a held control.")
        SendEvent("{" key " down}")
        UM14_ReplayHeld[key] := true
        SetTimer(UM14_InputFence, 25)
    } else {
        if !UM14_ReplayHeld.Has(key)
            UM14_Fatal("Recorded input has no matching down edge.")
        SendEvent("{" key " up}")
        UM14_ReplayHeld.Delete(key)
    }
}

UM14_ExecuteInputStep(step) {
    step := Trim(RegExReplace(step, "\s*;.*$", ""))
    if !RegExMatch(step, "i)^Input")
        return false
    UM14_RequireReadyFocus()
    if RegExMatch(step, 'i)^InputKey\s*\(\s*"([1-5WASDQERTFZXCVBJKLN]|Space|Left|Right|Up|Down|Shift)"\s*,\s*"(down|up)"\s*\)$', &m) {
        UM14_InputEdge(m[1], StrLower(m[2]))
        return true
    }
    if RegExMatch(step, 'i)^InputButton\s*\(\s*(\d{1,4})\s*,\s*(\d{1,4})\s*,\s*"(Left|Right)"\s*,\s*"(down|up)"\s*\)$', &m) {
        UM14_InputPoint(Integer(m[1]), Integer(m[2]))
        UM14_InputEdge(StrLower(m[3]) = "left" ? "LButton" : "RButton", StrLower(m[4]))
        return true
    }
    if RegExMatch(step, "i)^InputMove\s*\(\s*(\d{1,4})\s*,\s*(\d{1,4})\s*\)$", &m) {
        UM14_InputPoint(Integer(m[1]), Integer(m[2]))
        return true
    }
    if RegExMatch(step, "i)^InputWheel\s*\(\s*(\d{1,4})\s*,\s*(\d{1,4})\s*,\s*(-?\d{1,2})\s*\)$", &m) {
        ticks := Integer(m[3])
        if (Abs(ticks) < 1 || Abs(ticks) > 60)
            UM14_Fatal("Recorded wheel count is invalid.")
        UM14_InputPoint(Integer(m[1]), Integer(m[2]))
        SendEvent("{" (ticks > 0 ? "WheelUp" : "WheelDown") " " Abs(ticks) "}")
        return true
    }
    UM14_Fatal("Invalid recorded input instruction.")
}
