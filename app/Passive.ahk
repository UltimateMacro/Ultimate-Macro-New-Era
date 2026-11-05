; "Record as you play" (input_recording.py): explicitly opted-in, window-scoped
; physical game-input capture. Only an allowlist of game keys is kept, never text,
; scan codes or input from another window. Inputs are recorded, not outcomes.

class Passive {
    static target := 0, active := false, armed := false, incomplete := false, faultReason := ""
    static events := [], last := 0, width := 0, height := 0, keys := Map(), buttons := Map()
    static ih := "", moveFn := "", lastMove := 0, lx := -1, ly := -1, installed := false
    static NAMES := Map(0x31, "1", 0x32, "2", 0x33, "3", 0x34, "4", 0x35, "5", 0x57, "W", 0x41, "A", 0x53, "S", 0x44, "D"
        , 0x51, "Q", 0x45, "E", 0x52, "R", 0x54, "T", 0x46, "F", 0x5A, "Z", 0x58, "X", 0x43, "C", 0x56, "V", 0x42, "B"
        , 0x4A, "J", 0x4B, "K", 0x4C, "L", 0x4E, "N", 0x20, "Space", 0x25, "Left", 0x26, "Up", 0x27, "Right", 0x28, "Down"
        , 0x10, "Shift", 0xA0, "Shift", 0xA1, "Shift")

    static Install() {
        if Passive.installed
            return
        Passive.installed := true
        HotIf((*) => Passive.Scoped())
        for b in ["LButton", "RButton"] {
            Hotkey("~*" b, Passive.Button.Bind(Passive, b, "down"))
            Hotkey("~*" b " Up", Passive.Button.Bind(Passive, b, "up"))
        }
        Hotkey("~*WheelUp", Passive.Wheel.Bind(Passive, 1))
        Hotkey("~*WheelDown", Passive.Wheel.Bind(Passive, -1))
        HotIf()
        Passive.moveFn := ObjBindMethod(Passive, "PollMove")
    }

    static Prepare(hwnd) {
        Passive.Install()
        Passive.target := hwnd, Passive.active := true, Passive.armed := false, Passive.incomplete := false, Passive.faultReason := ""
        Passive.events := [], Passive.keys := Map(), Passive.buttons := Map(), Passive.width := 0, Passive.height := 0
    }

    static Scoped() => Passive.active && Passive.armed && Roblox.IsForeground(Passive.target)

    ; After the camera is aligned: record from here on, at the current client size.
    static Arm() {
        if (!Passive.active || Passive.armed || Passive.faultReason != "")
            return
        for vk, name in Passive.NAMES
            if GetKeyState(Format("vk{:02X}", vk), "P") {
                Passive.Fault("release game keys before aligning")
                return
            }
        try WinGetClientPos(, , &w, &h, "ahk_id " Passive.target)
        catch {
            Passive.Fault("game window closed")
            return
        }
        if (Min(w, h) < 320 || Max(w, h) > 8192) {
            Passive.Fault("unsupported window size")
            return
        }
        if (Passive.width && (w != Passive.width || h != Passive.height)) {
            Passive.Fault("window size changed")
            return
        }
        Passive.width := w, Passive.height := h
        Passive.armed := true, Passive.last := A_TickCount
        ih := InputHook("V L0")
        ih.MinSendLevel := 1
        ih.KeyOpt("{All}", "N")
        ih.OnKeyDown := (hook, vk, sc) => Passive.Key(vk, "down")
        ih.OnKeyUp := (hook, vk, sc) => Passive.Key(vk, "up")
        ih.Start()
        Passive.ih := ih
        SetTimer(Passive.moveFn, 16)
        MW.Log("Input capture started. Play normally in Roblox; F2 or Stop keeps the draft.")
    }

    static Stop() {
        if !Passive.active
            return
        if (Passive.keys.Count || Passive.buttons.Count)
            Passive.incomplete := true
        Passive.Disarm()
        Passive.active := false
    }

    static Disarm() {
        Passive.armed := false
        SetTimer(Passive.moveFn, 0)
        if IsObject(Passive.ih)
            try Passive.ih.Stop()
        Passive.ih := ""
    }

    static Fault(reason) {
        Passive.faultReason := reason, Passive.incomplete := true
        Passive.Disarm()
        MW.Log("Recorder: input capture stopped (" reason "). The draft is incomplete; review it before playback.")
    }

    static Push(instruction) {
        if (Passive.events.Length >= 8192) {
            Passive.Fault("capture overflow")
            return
        }
        delta := A_TickCount - Passive.last
        if (Passive.events.Length && delta >= 15)
            Passive.events.Push("Sleep(" Min(delta, 9999999) ")")
        Passive.last := A_TickCount
        Passive.events.Push(instruction)
    }

    static Point(&x, &y) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&sx, &sy)
        try WinGetClientPos(&cx, &cy, &w, &h, "ahk_id " Passive.target)
        catch
            return false
        if (w != Passive.width || h != Passive.height) {
            Passive.Fault("window size changed")
            return false
        }
        x := sx - cx, y := sy - cy
        if (x < 0 || y < 0 || x >= w || y >= h) {
            Passive.Fault("pointer left the game")
            return false
        }
        return true
    }

    static Key(vk, edge) {
        if !Passive.Scoped()
            return
        if (vk = 0x71 || vk = 0x77)
            return
        if !Passive.NAMES.Has(vk) {
            ; Modifier chords used for the macro's own shortcuts are not game input.
            if (vk = 0x11 || vk = 0xA2 || vk = 0xA3 || vk = 0x12 || vk = 0xA4 || vk = 0xA5 || vk = 0x5B || vk = 0x5C)
                return
            Passive.Fault("unsupported key " Format("vk{:02X}", vk))
            return
        }
        if (GetKeyState("Ctrl") || GetKeyState("Alt"))
            return
        name := Passive.NAMES[vk]
        if (edge = "down") {
            if Passive.keys.Has(name)
                return
            Passive.keys[name] := 1
        } else {
            if !Passive.keys.Has(name)
                return
            Passive.keys.Delete(name)
        }
        Passive.Push('InputKey("' name '", "' edge '")')
    }

    static Button(name, edge, *) {
        if !Passive.Scoped()
            return
        title := name = "LButton" ? "Left" : "Right"
        if !Passive.Point(&x, &y)
            return
        if (edge = "down") {
            if Passive.buttons.Has(title)
                return
            Passive.buttons[title] := 1
        } else {
            if !Passive.buttons.Has(title)
                return
            ; Finish a drag at the release point even if the last poll missed it.
            if (x != Passive.lx || y != Passive.ly)
                Passive.Push("InputMove(" x ", " y ")")
            Passive.buttons.Delete(title)
        }
        Passive.lx := x, Passive.ly := y
        Passive.Push("InputButton(" x ", " y ', "' title '", "' edge '")')
    }

    static Wheel(direction, *) {
        if !Passive.Scoped() || !Passive.Point(&x, &y)
            return
        Passive.Push("InputWheel(" x ", " y ", " direction ")")
    }

    ; Camera drags: pointer motion only while a mouse button is held.
    static PollMove() {
        if (!Passive.armed || !Passive.buttons.Count || !Roblox.IsForeground(Passive.target))
            return
        if !Passive.Point(&x, &y)
            return
        if (x = Passive.lx && y = Passive.ly)
            return
        Passive.lx := x, Passive.ly := y
        Passive.Push("InputMove(" x ", " y ")")
    }

    ; Build the draft text in the 1.4 recording format (client-v1 coordinates).
    static Draft(meta, towers, mods) {
        if !Passive.events.Length
            return ""
        steps := Passive.events.Clone()
        for name in Passive.keys
            steps.Push('InputKey("' name '", "up")')
        for name in Passive.buttons
            steps.Push("InputButton(" Max(0, Passive.lx) ", " Max(0, Passive.ly) ', "' name '", "up")')
        text := "[Settings]`nmap=" meta.map "`ndifficulty=" meta.mode "`nrequiredTowers=" towers "`nmodifiers=" mods
            . "`nautoChain=OFF`nautoCaravan=OFF`nautoDropTheBeat=OFF`nautoSkip=OFF`nabilitySpam=OFF`nmoveEnabled=0`nmoveDirection=W`nmoveDuration=1000"
            . "`n[DO NOT EDIT]`nwidth=" Passive.width "`nheight=" Passive.height "`ncoordinateSpace=client-v1`n[Steps]`n"
        for s in steps
            text .= s "`n"
        return text
    }
}

; Launcher hotkeys (window.tick/nativeEvent): F1 start and F2 stop only while the
; selected Roblox game is foreground; F8 emergency stop anywhere while active.
class Hotkeys {
    static installed := false, alignKey := "", f8 := false

    static Install() {
        if Hotkeys.installed
            return
        Hotkeys.installed := true
        HotIf((*) => Hotkeys.GameShortcuts())
        Hotkey("F1", (*) => MW.StartRun(true))
        Hotkey("F2", (*) => MW.StopRun())
        HotIf((*) => Hotkeys.SlotShortcuts())
        Loop 5
            Hotkey("^" A_Index, Hotkeys.Slot.Bind(Hotkeys, A_Index))
        HotIf()
        Hotkey("F8", (*) => MW.StopRun(true), "Off")
        Hotkeys.Rebind()
    }

    static GameShortcuts() => !MW.booting && MW.engineReady && !MW.LaunchBusy() && MW.ShortcutGame() != 0

    static SlotShortcuts() => MW.rec.active && !MW.rec.passive && Engine.phase = "recording" && MW.ShortcutGame(MW.recordingWindow) != 0

    static PassiveAlign() => MW.rec.active && MW.rec.passive && Engine.phase = "recording" && MW.ShortcutGame(MW.recordingWindow) != 0

    static Slot(n, *) {
        MW.recordSlot.Choose(n)
        Engine.RecordSlot(n)
    }

    ; In "Record as you play" the engine's own shortcuts are off, so the launcher owns Align.
    static Rebind() {
        HotIf((*) => Hotkeys.PassiveAlign())
        if (Hotkeys.alignKey != "")
            try Hotkey(Hotkeys.alignKey, "Off")
        try {
            Hotkeys.alignKey := Store.AhkHotkey(Store.settings["recordBindings"]["align"])
            Hotkey(Hotkeys.alignKey, (*) => (Passive.Disarm(), MW.RecordAction("align")), "On")
        }
        HotIf()
    }

    static Update() {
        want := MW.Active || MW.busy || MW.stopPending || Engine.ToolsRunning()
        if (want != Hotkeys.f8) {
            Hotkeys.f8 := want
            try Hotkey("F8", want ? "On" : "Off")
        }
    }

    static ClearAll() {
        try Hotkey("F8", "Off")
        Hotkeys.f8 := false
    }
}
