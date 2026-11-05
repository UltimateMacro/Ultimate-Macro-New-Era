; Roblox window identity, the fixed TDS protocol launch and scoped game recovery
; (platform.py, roblox_launcher.py, game_recovery.py).

class Roblox {
    static URI := "roblox://placeID=3260590327"
    static waiting := false, deadline := 0, onStatus := ""

    ; Visible top-level windows whose process image is RobloxPlayerBeta.exe.
    static Windows() {
        out := []
        prev := A_DetectHiddenWindows
        DetectHiddenWindows(false)
        try {
            for hwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe") {
                try {
                    if !DllCall("IsWindowVisible", "Ptr", hwnd)
                        continue
                    if (WinGetTitle("ahk_id " hwnd) = "" && WinGetClass("ahk_id " hwnd) != "WINDOWSCLIENT")
                        continue
                    out.Push(hwnd)
                }
            }
        } finally
            DetectHiddenWindows(prev)
        return out
    }

    ; Exactly one game window, else 0 (ambiguity never guesses).
    static Game() {
        try {
            w := Roblox.Windows()
            return w.Length = 1 ? w[1] : 0
        }
        return 0
    }

    static IsForeground(hwnd := 0) {
        hwnd := hwnd ? hwnd : Roblox.Game()
        if !hwnd
            return false
        fg := DllCall("GetForegroundWindow", "Ptr")
        root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
        return fg && (fg = hwnd || fg = root)
    }

    static Focus(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            throw ValueError("Switch to the selected Roblox window first.")
        if (WinGetMinMax("ahk_id " hwnd) = -1)
            WinRestore("ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
        try WinWaitActive("ahk_id " hwnd, , 2)
        if !Roblox.IsForeground(hwnd)
            throw ValueError("Switch to the selected Roblox window first.")
    }

    ; Fullscreen/borderless games cannot be docked or safely resized.
    static IsWindowed(hwnd) {
        style := WinGetStyle("ahk_id " hwnd)
        if !(style & 0x00C00000)
            return false
        return WinGetMinMax("ahk_id " hwnd) = 0
    }

    ; ---- explicit launch ----------------------------------------------------
    static Launch() {
        if Roblox.waiting
            return "waiting"
        w := Roblox.Windows()
        if (w.Length > 1)
            return "multiple"
        if (w.Length = 1)
            return "ready"
        try Run(Roblox.URI)
        catch
            return "unavailable"
        Roblox.waiting := true, Roblox.deadline := A_TickCount + 90000
        return "waiting"
    }

    static Poll() {
        if !Roblox.waiting
            return ""
        w := Roblox.Windows()
        if (w.Length > 1) {
            Roblox.waiting := false
            return "multiple"
        }
        if (w.Length = 1) {
            Roblox.waiting := false
            return "ready"
        }
        if (A_TickCount >= Roblox.deadline) {
            Roblox.waiting := false
            return "timed-out"
        }
        return "waiting"
    }

    static Cancel() => (Roblox.waiting := false)

    static Identity(hwnd) {
        pid := 0
        thread := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid, "UInt")
        if (!thread || !pid)
            return ""
        proc := DllCall("OpenProcess", "UInt", 0x1000, "Int", false, "UInt", pid, "Ptr")
        if !proc
            return ""
        created := exited := kernel := user := 0
        try ok := DllCall("GetProcessTimes", "Ptr", proc, "Int64*", &created, "Int64*", &exited, "Int64*", &kernel, "Int64*", &user)
        finally DllCall("CloseHandle", "Ptr", proc)
        return ok && created ? hwnd "|" thread "|" pid "|" created : ""
    }

    static CaptureStamp(hwnd) {
        if (Roblox.Game() != hwnd || !Roblox.IsForeground(hwnd) || WinGetMinMax("ahk_id " hwnd) = -1)
            return ""
        token := Roblox.Identity(hwnd)
        WinGetClientPos(&x, &y, &w, &h, "ahk_id " hwnd)
        if (!token || w < 64 || h < 64 || w > 8192 || h > 8192 || w*h > 33554432)
            return ""
        return {token: token, x: x, y: y, w: w, h: h, key: token "|" x "|" y "|" w "|" h}
    }

    static Intersects(s, l, t, r, b) => l < s.x+s.w && r > s.x && t < s.y+s.h && b > s.y

    static Uncovered(hwnd, s) {
        rect := Buffer(16), visited := Map()
        current := DllCall("GetTopWindow", "Ptr", 0, "Ptr")
        Loop 512 {
            if (current = hwnd)
                return true
            if (!current || visited.Has(current))
                return false
            visited[current] := true
            if DllCall("IsWindowVisible", "Ptr", current) {
                cloaked := 0
                hidden := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", current, "UInt", 14, "UInt*", &cloaked, "UInt", 4, "Int") = 0 && cloaked
                if !hidden {
                    if !DllCall("GetWindowRect", "Ptr", current, "Ptr", rect)
                        return false
                    if Roblox.Intersects(s, NumGet(rect,0,"Int"), NumGet(rect,4,"Int"), NumGet(rect,8,"Int"), NumGet(rect,12,"Int"))
                        return false
                }
            }
            current := DllCall("GetWindow", "Ptr", current, "UInt", 2, "Ptr")
        }
        return false
    }

    static Screenshot() {
        dpi := DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
        if !dpi
            return false
        src := dc := bitmap := previous := bmp := 0
        try {
            hwnd := Roblox.Game()
            s := hwnd ? Roblox.CaptureStamp(hwnd) : ""
            if (!IsObject(s) || !Roblox.Uncovered(hwnd, s))
                return false
            src := DllCall("GetDC", "Ptr", 0, "Ptr")
            if !src
                return false
            dc := DllCall("CreateCompatibleDC", "Ptr", src, "Ptr")
            bitmap := DllCall("CreateCompatibleBitmap", "Ptr", src, "Int", s.w, "Int", s.h, "Ptr")
            if (!dc || !bitmap)
                return false
            previous := DllCall("SelectObject", "Ptr", dc, "Ptr", bitmap, "Ptr")
            if (!previous || previous = -1)
                return false
            ; Capture from the Roblox window. Never fall back to desktop pixels.
            if !DllCall("PrintWindow", "Ptr", hwnd, "Ptr", dc, "UInt", 3)
                return false
            DllCall("SelectObject", "Ptr", dc, "Ptr", previous)
            previous := 0
            after := Roblox.CaptureStamp(hwnd)
            if (!IsObject(after) || after.key != s.key || !Roblox.Uncovered(hwnd, s))
                return false
            bmp := Gdip_CreateBitmapFromHBITMAP(bitmap)
            return bmp && Roblox.HasVisiblePixels(bmp,s.w,s.h) ? Roblox.ScreenshotPng(bmp,s.w,s.h) : false
        } catch {
            return false
        } finally {
            if (previous && previous != -1 && dc)
                DllCall("SelectObject", "Ptr", dc, "Ptr", previous)
            if bmp
                Gdip_DisposeImage(bmp)
            if bitmap
                DllCall("DeleteObject", "Ptr", bitmap)
            if dc
                DllCall("DeleteDC", "Ptr", dc)
            if src
                DllCall("ReleaseDC", "Ptr", 0, "Ptr", src)
            DllCall("SetThreadDpiAwarenessContext", "Ptr", dpi, "Ptr")
        }
    }

    static HasVisiblePixels(bmp,w,h) {
        Loop 8 {
            y := Floor((A_Index-.5)*h/8)
            Loop 8 {
                x := Floor((A_Index-.5)*w/8)
                if (Gdip_GetPixel(bmp,x,y) & 0xFCFCFC)
                    return true
            }
        }
        return false
    }

    static ScreenshotPng(bmp,w,h) {
        for limit in [1920,1280,960,640,480] {
            scale := Min(1,limit/w,limit/h,1080/h)
            out := scale < 1 ? Gdip_ResizeBitmap(bmp,Max(1,Round(w*scale)),Max(1,Round(h*scale)),7) : bmp
            if !out
                return false
            stream := 0
            try {
                stream := Gdip_SaveBitmapToStream(out)
                if (stream <= 0)
                    return false
                count := 0
                ComCall(5,stream,"Int64",0,"UInt",2,"Int64*",&count)
                if (count < 1 || count > 700000)
                    continue
                ComCall(5,stream,"Int64",0,"UInt",0,"Ptr",0)
                png := Buffer(count), read := 0
                ComCall(3,stream,"Ptr",png,"UInt",count,"UInt*",&read)
                return read = count ? png : false
            } finally {
                if (stream > 0)
                    ObjRelease(stream)
                if (out != bmp)
                    Gdip_DisposeImage(out)
            }
        }
        return false
    }
}

; One claimed relaunch for the engine's disconnect recovery. Only the selected game
; process is closed; the fixed TDS protocol URI is the only thing opened.
class GameRecovery {
    static state := "idle", request := "", deadline := 0, pid := 0, stamp := 0
    static candidateKey := "", candidateSince := 0
    static originalMode := "", originalBounds := [], replacement := 0, replacementToken := ""

    static Busy => GameRecovery.state != "idle"

    static InputStamp() {
        lii := Buffer(8, 0)
        NumPut("UInt", 8, lii)
        DllCall("GetLastInputInfo", "Ptr", lii)
        return NumGet(lii, 4, "UInt")
    }

    static Begin(request) {
        if GameRecovery.Busy
            throw Error("Another recovery is pending")
        w := Roblox.Windows()
        if (w.Length != 1 || w[1] != request.hwnd || !Roblox.IsForeground(request.hwnd))
            throw ValueError("The selected game must remain foreground")
        GameRecovery.CandidateStable("", A_TickCount)
        GameRecovery.originalMode := Docking.active ? "" : WinGetMinMax("ahk_id " request.hwnd)
        WinGetPos(&x,&y,&w,&h,"ahk_id " request.hwnd)
        GameRecovery.originalBounds := [x,y,w,h]
        GameRecovery.pid := WinGetPID("ahk_id " request.hwnd)
        GameRecovery.request := request, GameRecovery.stamp := GameRecovery.InputStamp()
        ; WM_CLOSE can spawn a Roblox Home client; end only the verified game process.
        ProcessClose(GameRecovery.pid)
        GameRecovery.state := "closing", GameRecovery.deadline := A_TickCount + 3000
    }

    ; Returns "" while busy, else true/false for the final outcome.
    static Poll(allowed) {
        if !GameRecovery.Busy
            return ""
        if (!allowed || GameRecovery.InputStamp() != GameRecovery.stamp)
            return GameRecovery.Finish(false)
        w := Roblox.Windows()
        if (GameRecovery.state = "closing") {
            if (ProcessExist(GameRecovery.pid) || w.Length) {
                if (A_TickCount >= GameRecovery.deadline)
                    return GameRecovery.Finish(false)
                return ""
            }
            try Run(Roblox.URI)
            catch
                return GameRecovery.Finish(false)
            GameRecovery.state := "opening", GameRecovery.deadline := A_TickCount + 60000
            return ""
        }
        if (w.Length > 1)
            return GameRecovery.Finish(false)
        if (A_TickCount >= GameRecovery.deadline)
            return GameRecovery.Finish(false)
        if (GameRecovery.state = "restoring") {
            if (w.Length != 1 || w[1] != GameRecovery.replacement
                || Roblox.Identity(w[1]) != GameRecovery.replacementToken)
                return GameRecovery.Finish(false)
            WinGetPos(&x,&y,&width,&height,"ahk_id " w[1])
            mode := WinGetMinMax("ahk_id " w[1])
            if !GameRecovery.LayoutMatches(GameRecovery.originalMode,GameRecovery.originalBounds,mode,[x,y,width,height])
                return ""
            key := GameRecovery.replacementToken "|" mode "|" x "|" y "|" width "|" height
            return GameRecovery.CandidateStable(key,A_TickCount) ? GameRecovery.Finish(true) : ""
        }
        if (w.Length = 1) {
            ; The first visible Roblox HWND can still be a boot/loading window.
            ; It may overwrite an early docking move with its saved bounds.
            if GameRecovery.ReplacementReady(w[1]) {
                if (GameRecovery.originalMode = "")
                    return GameRecovery.Finish(true)
                return GameRecovery.RestoreReplacement(w[1]) ? "" : GameRecovery.Finish(false)
            }
        } else
            GameRecovery.CandidateStable("", A_TickCount)
        return ""
    }

    static CandidateStable(key, now) {
        if (key = "" || key != GameRecovery.candidateKey) {
            GameRecovery.candidateKey := key, GameRecovery.candidateSince := now
            return false
        }
        return now-GameRecovery.candidateSince >= 2000
    }

    static ReplacementReady(hwnd) {
        try {
            if (WinGetClass("ahk_id " hwnd) != "WINDOWSCLIENT" || WinGetMinMax("ahk_id " hwnd) = -1
                || !(WinGetStyle("ahk_id " hwnd) & 0x00C00000)
                || DllCall("IsHungAppWindow", "Ptr", hwnd))
                return GameRecovery.CandidateStable("", A_TickCount)
            token := Roblox.Identity(hwnd)
            WinGetClientPos(&x,&y,&w,&h,"ahk_id " hwnd)
            if (!token || w < 640 || h < 480)
                return GameRecovery.CandidateStable("", A_TickCount)
            return GameRecovery.CandidateStable(token "|" x "|" y "|" w "|" h, A_TickCount)
        }
        return GameRecovery.CandidateStable("", A_TickCount)
    }

    static LayoutMatches(mode, target, currentMode, current) => mode = 1 ? currentMode = 1
        : mode = 0 && currentMode = 0 && Docking.Near(target,current)

    static RestoreReplacement(hwnd) {
        token := Roblox.Identity(hwnd)
        if (!token || Roblox.Game() != hwnd || !InArray([0,1],GameRecovery.originalMode))
            return false
        try {
            if (GameRecovery.originalMode = 1)
                WinMaximize("ahk_id " hwnd)
            else {
                if (WinGetMinMax("ahk_id " hwnd) != 0)
                    WinRestore("ahk_id " hwnd)
                b := GameRecovery.originalBounds
                if !DllCall("SetWindowPos","Ptr",hwnd,"Ptr",0,"Int",b[1],"Int",b[2],"Int",b[3],"Int",b[4],"UInt",0x4014)
                    return false
            }
            GameRecovery.replacement := hwnd, GameRecovery.replacementToken := token
            GameRecovery.CandidateStable("",A_TickCount)
            GameRecovery.state := "restoring", GameRecovery.deadline := A_TickCount+5000
            return true
        }
        return false
    }

    static Finish(ok) {
        GameRecovery.state := "idle", GameRecovery.request := "", GameRecovery.pid := 0
        GameRecovery.CandidateStable("", A_TickCount)
        GameRecovery.originalMode := "", GameRecovery.originalBounds := []
        GameRecovery.replacement := 0, GameRecovery.replacementToken := ""
        return ok
    }

    static Cancel() => GameRecovery.Finish(false)
}
