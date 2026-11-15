; A requested Roblox window capture only. No screen/desktop fallback, no WGC.
class ShotCapture {
    static Pick() {
        wins := WinGetList("ahk_exe RobloxPlayerBeta.exe")
        visible := []
        for hwnd in wins
            if DllCall("IsWindowVisible", "Ptr", hwnd) && WinGetClass("ahk_id " hwnd) = "WINDOWSCLIENT"
                visible.Push(hwnd)
        if (visible.Length != 1 || DllCall("GetForegroundWindow", "Ptr") != visible[1])
            return 0
        return visible[1]
    }

    static Stamp(hwnd) {
        if !hwnd || ShotCapture.Pick() != hwnd || WinGetMinMax("ahk_id " hwnd) = -1
            return ""
        pid := 0
        tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid, "UInt")
        process := DllCall("OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")
        if !process
            return ""
        born := dead := kernel := user := 0
        try ok := DllCall("GetProcessTimes", "Ptr", process, "Int64*", &born, "Int64*", &dead, "Int64*", &kernel, "Int64*", &user, "Int")
        finally DllCall("CloseHandle", "Ptr", process)
        if !ok
            return ""
        WinGetClientPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (w < 64 || h < 64 || w > 8192 || h > 8192 || w*h > 16777216)
            return ""
        return {key: hwnd "|" pid "|" tid "|" born "|" x "|" y "|" w "|" h, w: w, h: h}
    }

    static Capture() {
        context := DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
        if !context
            return false
        try {
            hwnd := ShotCapture.Pick()
            before := hwnd ? ShotCapture.Stamp(hwnd) : ""
            if !IsObject(before)
                return false
            bitmap := ShotCapture.Render(hwnd, before.w, before.h)
            if !bitmap
                return false
            try {
                after := ShotCapture.Stamp(hwnd)
                if !IsObject(after) || after.key != before.key
                    return false
                return ShotCapture.Png(bitmap, before.w, before.h)
            } finally Gdip_DisposeImage(bitmap)
        } finally DllCall("SetThreadDpiAwarenessContext", "Ptr", context, "Ptr")
    }

    static Render(hwnd, w, h) {
        dc := bitmap := previous := 0
        try {
            dc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
            if !dc
                return 0
            info := Buffer(40, 0)
            NumPut("UInt", 40, "Int", w, "Int", -h, "UShort", 1, "UShort", 32, info)
            bitmap := DllCall("CreateDIBSection", "Ptr", dc, "Ptr", info, "UInt", 0, "Ptr*", 0, "Ptr", 0, "UInt", 0, "Ptr")
            if !bitmap
                return 0
            previous := DllCall("SelectObject", "Ptr", dc, "Ptr", bitmap, "Ptr")
            if !previous || previous = -1
                return 0
            ; May block in a driver. This runs in a time-limited owned worker.
            if !DllCall("PrintWindow", "Ptr", hwnd, "Ptr", dc, "UInt", 3, "Int")
                return 0
            DllCall("SelectObject", "Ptr", dc, "Ptr", previous)
            previous := 0
            return Gdip_CreateBitmapFromHBITMAP(bitmap)
        } finally {
            if previous && previous != -1
                DllCall("SelectObject", "Ptr", dc, "Ptr", previous)
            if bitmap
                DllCall("DeleteObject", "Ptr", bitmap)
            if dc
                DllCall("DeleteDC", "Ptr", dc)
        }
    }

    static Png(bitmap, w, h) {
        visible := false
        Loop 8 {
            y := Floor((A_Index-.5)*h/8)
            Loop 8
                if Gdip_GetPixel(bitmap, Floor((A_Index-.5)*w/8), y) & 0xFCFCFC
                    visible := true
        }
        if !visible
            return false
        for edge in [1280, 960, 640, 480] {
            scale := Min(1, edge/w, edge/h)
            scaled := scale < 1 ? Gdip_ResizeBitmap(bitmap, Max(1, Round(w*scale)), Max(1, Round(h*scale)), 7) : bitmap
            if !scaled
                return false
            stream := 0
            try {
                stream := Gdip_SaveBitmapToStream(scaled)
                if stream <= 0
                    return false
                count := 0
                ComCall(5, stream, "Int64", 0, "UInt", 2, "Int64*", &count)
                if count < 8 || count > 700000
                    continue
                ComCall(5, stream, "Int64", 0, "UInt", 0, "Ptr", 0)
                bytes := Buffer(count), read := 0
                ComCall(3, stream, "Ptr", bytes, "UInt", count, "UInt*", &read)
                if read = count && NumGet(bytes, 0, "UInt64") = 0x0A1A0A0D474E5089
                    return bytes
            } finally {
                if stream > 0
                    ObjRelease(stream)
                if scaled != bitmap
                    Gdip_DisposeImage(scaled)
            }
        }
        return false
    }
}
