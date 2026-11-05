; Opt-in side-by-side layout (docking.py). Never reparents, injects into or
; resizes a fullscreen Roblox client. Original bounds are restored on undock/exit.

class Docking {
    static entries := [], active := false, restoring := false, settling := false
    static deadline := 0, attachFailed := false, partial := false
    static Busy => Docking.settling || Docking.restoring

    static WorkArea(hwnd) {
        mon := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
        mi := Buffer(40, 0)
        NumPut("UInt", 40, mi)
        if (!mon || !DllCall("GetMonitorInfoW", "Ptr", mon, "Ptr", mi))
            throw ValueError("The display work area could not be read.")
        l := NumGet(mi, 20, "Int"), t := NumGet(mi, 24, "Int"), r := NumGet(mi, 28, "Int"), b := NumGet(mi, 32, "Int")
        return {x: l, y: t, w: r - l, h: b - t}
    }

    static Bounds(hwnd) {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        return [x, y, w, h]
    }

    static Attach(game, app) {
        if Docking.active {
            if (Docking.entries.Length = 2 && Docking.entries[1].hwnd = game && Docking.entries[2].hwnd = app && Docking.IsCurrent())
                return "attached"
            throw ValueError("Undock the previous layout before arranging different windows.")
        }
        if (Roblox.Game() != game)
            throw ValueError("Open exactly one Roblox game window.")
        if !Roblox.IsWindowed(game)
            throw ValueError("Use the selected Roblox game in windowed mode.")
        if (WinGetMinMax("ahk_id " app) != 0)
            throw ValueError("Restore Roblox and the macro to windowed mode first.")
        s := Gfx.S, area := Docking.WorkArea(app)
        gap := Ceil(8 * s), appMin := Ceil(480 * s), gameMin := Ceil(640 * s)
        available := area.w - gap - gameMin
        if (available < appMin)
            throw ValueError("This display is too small for the side-by-side layout.")
        appBounds := Docking.Bounds(app)
        width := Min(Max(appBounds[3], appMin), available)
        gameW := area.w - width - gap
        if (gameW < gameMin || area.h < Ceil(480 * s) || gameW > 7680 || area.h > 4320)
            throw ValueError("This display is too small or too large for the side-by-side layout.")
        gameId := Roblox.Identity(game), appId := Roblox.Identity(app)
        if (!gameId || !appId)
            throw ValueError("Window identity could not be verified.")
        Docking.entries := [
            {hwnd: game, token: gameId, orig: Docking.Bounds(game), target: [area.x, area.y, gameW, area.h], moved: false, restoreSent: false},
            {hwnd: app, token: appId, orig: appBounds, target: [area.x + gameW + gap, area.y, width, area.h], moved: false, restoreSent: false}]
        Docking.active := Docking.settling := true
        Docking.deadline := A_TickCount + 2500
        for e in Docking.entries {
            if !Docking.Place(e, e.target)
                return Docking.BeginRestore(true)
            e.moved := true
        }
        return Docking.Poll()
    }

    static Same(entry) => Roblox.Identity(entry.hwnd) = entry.token

    static Near(a,b) => Abs(a[1]-b[1]) <= 2 && Abs(a[2]-b[2]) <= 2 && Abs(a[3]-b[3]) <= 2 && Abs(a[4]-b[4]) <= 2

    static Place(entry, b) {
        ; SWP_NOZORDER | SWP_NOACTIVATE | SWP_ASYNCWINDOWPOS: never block on a stalled game.
        return Docking.Same(entry) && DllCall("SetWindowPos", "Ptr", entry.hwnd, "Ptr", 0, "Int", b[1], "Int", b[2], "Int", b[3], "Int", b[4], "UInt", 0x4014)
    }

    static IsCurrent() {
        if (!Docking.active || Docking.restoring || Docking.entries.Length != 2)
            return false
        complete := true
        for e in Docking.entries {
            b := Docking.TryBounds(e)
            if (e.moved && IsObject(b) && Docking.Near(b,e.target))
                e.arrived := true
            else
                complete := false
        }
        return complete
    }

    static TryBounds(e) {
        if Docking.Same(e) {
            try return Docking.Bounds(e.hwnd)
        }
        return false
    }

    ; Restore only windows that still sit exactly where we placed them.
    static Detach() {
        if !Docking.active
            return "idle"
        return Docking.restoring ? Docking.Poll() : Docking.BeginRestore()
    }

    static BeginRestore(failed := false) {
        Docking.settling := false
        Docking.restoring := true
        Docking.attachFailed := failed
        Docking.partial := false
        Docking.deadline := A_TickCount + 2500
        return Docking.Poll()
    }

    static RestoreStep(e, bounds, timedOut) {
        if e.HasOwnProp("abandoned")
            return "partial"
        if !e.moved
            return "done"
        if !IsObject(bounds)
            return "partial"
        arrived := e.HasOwnProp("arrived")
        if Docking.Near(bounds,e.orig)
            return arrived || e.restoreSent || timedOut ? "done" : "wait"
        if timedOut
            return "partial"
        if Docking.Near(bounds,e.target)
            return e.restoreSent ? "wait" : "request"
        return arrived && !e.restoreSent ? "partial" : "wait"
    }

    static Poll() {
        if Docking.settling {
            if Docking.IsCurrent() {
                Docking.settling := false
                return "attached"
            }
            return A_TickCount >= Docking.deadline ? Docking.BeginRestore(true) : "pending"
        }
        if !Docking.restoring
            return ""
        timedOut := A_TickCount >= Docking.deadline
        pending := false
        for e in Docking.entries {
            step := Docking.RestoreStep(e,Docking.TryBounds(e),timedOut)
            if (step = "request") {
                e.arrived := true
                e.restoreSent := Docking.Place(e,e.orig)
                pending := true
            } else if (step = "wait") {
                pending := true
            } else if (step = "partial") {
                e.abandoned := true
                Docking.partial := true
            }
        }
        if pending
            return "pending"
        result := Docking.attachFailed ? (Docking.partial ? "attach-partial" : "attach-failed")
            : (Docking.partial ? "partial" : "restored")
        Docking.entries := [], Docking.active := false, Docking.restoring := false
        return result
    }

    ; After a game relaunch, place the replacement client into the saved game slot.
    static ReplaceGame(game) {
        if (!Docking.active || Docking.Busy || !game || Roblox.Game() != game || !Roblox.IsWindowed(game))
            return false
        token := Roblox.Identity(game)
        if !token
            return false
        old := Docking.entries[1]
        fresh := {hwnd:game, token:token, orig:Docking.Bounds(game), target:old.target, moved:false, restoreSent:false}
        if !Docking.Place(fresh,fresh.target)
            return false
        fresh.moved := true
        Docking.entries[1] := fresh
        Docking.settling := true
        Docking.deadline := A_TickCount + 2500
        return true
    }
}
