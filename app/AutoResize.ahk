class AutoResize {
    static WIDTH := 1680, HEIGHT := 945, busy := false
    static notes := Map("resized", "Resized Roblox and moved it to the top left corner."
        , "fullscreen", "Roblox is in fullscreen, so it was not resized. Press F11 in Roblox to use windowed mode."
        , "timed-out", "Roblox did not finish resizing. Starting with its current window size."
        , "failed", "Roblox could not be resized. Starting with its current window size.")

    static Target(area, inset := 0) {
        scale := Min(1, area.w/AutoResize.WIDTH, area.h/AutoResize.HEIGHT)
        w := Floor(AutoResize.WIDTH*scale), h := Floor(AutoResize.HEIGHT*scale)
        return [area.x - inset, area.y, w, h]
    }

    static LeftInset(game) {
        frame := Buffer(16, 0)
        if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", game, "UInt", 9, "Ptr", frame, "UInt", 16)
            return 0
        return Max(0, NumGet(frame, 0, "Int") - Docking.Bounds(game)[1])
    }

    static Apply(game) {
        if (!game || Docking.active || AutoResize.busy)
            return "skipped"
        AutoResize.busy := true
        try
            return AutoResize.Resize(game)
        catch
            return "failed"
        finally
            AutoResize.busy := false
    }

    static Resize(game) {
        if !(WinGetStyle("ahk_id " game) & 0x00C00000)
            return "fullscreen"
        if (WinGetMinMax("ahk_id " game) != 0)
            WinRestore("ahk_id " game)
        b := AutoResize.Target(Docking.WorkArea(game), AutoResize.LeftInset(game))
        if Docking.Near(Docking.Bounds(game), b)
            return "ready"
        if !DllCall("SetWindowPos", "Ptr", game, "Ptr", 0, "Int", b[1], "Int", b[2], "Int", b[3], "Int", b[4], "UInt", 0x4014)
            return "failed"
        deadline := A_TickCount + 1500
        while (A_TickCount < deadline) {
            Sleep(50)
            if Docking.Near(Docking.Bounds(game), b)
                return "resized"
        }
        return "timed-out"
    }
}
