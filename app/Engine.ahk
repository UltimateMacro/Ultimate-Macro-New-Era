; Host side of the 1.3.3a-derived AutoHotkey engine. Ports LegacyHost, EngineController,
; EngineWorkspace, EngineHost and SettingsSchema from the 1.4 C# sources.
;
; IPC is WM_COPYDATA text with a per-launch session id, monotonically increasing
; sequence numbers and a fixed verb allowlist (see engine\lib\UM14Bridge.ahk).
; Nothing received from the engine is executed. Only processes started from this
; installation's bundled interpreter are ever terminated.

class Engine {
    static BUILD := "1.3.3a-um14.28-ahk3"
    static MAPS := ["Abandoned City", "Area 52", "Autumn Falling", "Badlands II", "Black Spot Exchange", "Candy Valley", "Cataclysm", "Chess Board"
        , "Construction Crazy", "Coral Deep", "Crossroads", "Crystal Cave", "Cyber City", "Dead Ahead", "Derelict Outpost", "Deserted Village", "Dusty Bridges"
        , "Enchanted Forest", "Farm Lands", "Forest Camp", "Forgetten Docks", "Four Seasons", "Fungi Island", "Grass Isle", "Happy Home of Robloxia", "Harbor", "Honey Valley"
        , "Hot Spot", "Iceville", "Infernal Abyss", "Lay By", "Lighthaos", "Marshlands", "Mason Arch", "Medieval Times", "Meltdown"
        , "Midnight Issue", "Moon Base", "Musaceae Kingdom", "Necropolis", "Nether", "Night Station", "Northern Lights", "Outskirts Commune", "Pier Pressure", "Pizza Party", "Polluted Wasteland II"
        , "Portland", "Retro Crossroads", "Retro Lighthouse", "Retro Rocket Arena", "Retro Stained Temple", "Retro The Heights", "Retro Zone", "Rocket Arena", "Ruby Escort", "Sacred Mountains"
        , "Sky Islands", "Simplicity", "Space City", "Spring Fever", "Stained Temple", "Sugar Rush", "The Heavens", "The Heights", "Toyboard", "Tropical Industries", "Tropical Isles", "U-Turn"
        , "Unknown Garden", "Winter Abyss", "Winter Bridges", "Winter Stronghold", "Wrecked Battlefield", "Wrecked Battlefield II", "Wretched Front"]
    static MODES := ["Easy", "Casual", "Intermediate", "Molten", "Fallen", "Frost", "Hardcore", "Voidcore", "Pizza Party", "Badlands II", "Polluted Wasteland II"]

    static phase := "offline", session := "", pid := 0, engineHwnd := 0, seqOut := 0, seqIn := 0
    static deadline := 0, missingSince := 0, stopRequested := false, fatal := false, startNotice := false
    static pending := "", stats := "", gameLaunch := "", gameLaunchNonces := Map(), recorded := ""
    static tools := [], inbox := [], lastError := "", stopReason := ""
    static data := "", interpreter := "", toolInterpreter := "", script := ""
    static onLog := "", onChange := "", onRecorded := "", onRecState := ""

    static Init() {
        Engine.data := Store.root "\engine-data"
        Engine.interpreter := App.engine "\submacros\AutoHotkey64.exe"
        Engine.toolInterpreter := App.engine "\submacros\UM14Tools64.exe"
        Engine.script := App.engine "\UM14Engine.ahk"
        OnMessage(0x004A, Engine.OnCopyData.Bind(Engine))
        ; A previous launcher crash may have left this installation's engine running.
        if (Engine.OwnedPids().Length) {
            Engine.KillOwned(true)
            Engine.Revoke()
        }
    }

    static Installed() => FileExist(Engine.interpreter) && FileExist(Engine.script)

    static Active => InArray(["launching", "starting", "running", "recording", "stopping"], Engine.phase) || Engine.ToolsRunning()

    static Log(text) {
        if (Engine.onLog)
            Engine.onLog.Call(text)
    }

    static Changed() {
        if (Engine.onChange)
            Engine.onChange.Call()
    }

    static Set(phase) {
        if (phase = Engine.phase)
            return
        Engine.phase := phase
        if InArray(["offline", "faulted", "idle", "stopping"], phase)
            Engine.gameLaunch := ""
        Engine.Changed()
    }

    ; ---- settings (SettingsSchema.All) -------------------------------------
    static Schema() {
        static list := ""
        if IsObject(list)
            return list
        list := [
            ["Options", "Strategy1", ""], ["Options", "Strategy2", ""], ["Options", "RotateStrategies", "0"], ["Options", "SwapAmount", "4"]
            , ["Options", "SwapUnit", "Runs"], ["Options", "AutoEquip", "0"], ["Options", "Repeat", "1"], ["Options", "ScrollDownForMap", "0"]
            , ["Options", "ScrollDownAmount", "5"], ["Options", "ScrollDelay", "1000"], ["Options", "UseRestartBtn", "1"], ["Options", "UsePlayAgainBtn", "1"]
            , ["Options", "CheckTheMap", "1"], ["Options", "UseNumbers", "1"], ["Options", "UseHotkeyForUpgrade", "1"], ["Options", "CollectPlaytimeRewards", "1"]
            , ["Options", "AutoCloseChat", "1"], ["Options", "DebugConsole", "1"], ["Options", "PotatoMode", "0"], ["Options", "AlwaysOnTop", "1"]
            , ["Options", "LegacyMode", "0"], ["Options", "UseVipServer", "0"], ["Options", "VipLink", ""], ["Options", "TimeScaleMode", "OFF"]
            , ["Options", "UpgradeDelay", "200"], ["Options", "DefaultMouseSpeed", "2"], ["Options", "MouseDelay", "10"], ["Options", "KeyDelay", "20"]
            , ["Options", "ExtraUiWait", "0"], ["Options", "PreJoinDelay", "0"]
            , ["Hotkeys", "Chain", "C"], ["Hotkeys", "Beat", "B"], ["Hotkeys", "Caravan", "J"], ["Hotkeys", "RaiseTheDead", "V"], ["Hotkeys", "Hologram", "K"]
            , ["Hotkeys", "Repo", "L"], ["Hotkeys", "CancelPlacement", "Q"], ["Hotkeys", "UpgradeTower", "E"], ["Hotkeys", "UpgradeBottom", "Z"]
            , ["RecordingHotkeys", "PlaceTowerKey", "f"], ["RecordingHotkeys", "UpgradeTowerKey", "^u"], ["RecordingHotkeys", "AlignCameraKey", "^t"]
            , ["RecordingHotkeys", "ChangeDJTrackKey", "^d"], ["RecordingHotkeys", "SellTowerKey", "^x"], ["RecordingHotkeys", "DeleteTowerRecordingKey", "^b"]
            , ["RecordingHotkeys", "RecordInputsKey", "^+e"], ["RecordingHotkeys", "HoloKey", "^!h"], ["RecordingHotkeys", "ChangeTargetsKey", "^vkC0"]
            , ["Multiplayer", "MultiplayerEnabled", "0"], ["Multiplayer", "PlayerRole", "Host"], ["Multiplayer", "LeaveCondition", "Any"]
            , ["Multiplayer", "HostName", "..."], ["Multiplayer", "PartyMembers", "someone, someone..."]
            , ["Webhook", "Enabled", "0"], ["Webhook", "Link", ""], ["Webhook", "Link2", ""], ["Webhook", "WebhookUserID", ""], ["Webhook", "SendCurrencies", "1"]
            , ["Webhook", "WebhookDebugLogs", "1"], ["Webhook", "WebhookScreenshots", "1"], ["Webhook", "WebhookTriumphScreenshots", "1"]
            , ["Webhook", "WebhookSepatateTriumphScreenshots", "0"]]
        return list
    }

    ; hybrid_client.profile(): UI options -> legacy settings ids.
    static Profile(opts) {
        s := Map()
        s["Options.AutoEquip"] := opts.autoEquip ? "1" : "0"
        s["Options.AutoCloseChat"] := !opts.HasOwnProp("autoCloseChat") || opts.autoCloseChat ? "1" : "0"
        s["Options.Repeat"] := opts.repeat ? "1" : "0"
        s["Options.TimeScaleMode"] := opts.timeScale
        s["Options.RotateStrategies"] := "0"
        lo := opts.legacy
        s["Options.ScrollDownForMap"] := lo["scrollModeList"] ? "1" : "0"
        s["Options.ScrollDownAmount"] := String(lo["scrollAmount"])
        s["Options.ScrollDelay"] := String(lo["scrollDelayMs"])
        rt := opts.runtime
        for src, dst in Map("cancelKey", "CancelPlacement", "raiseDeadKey", "RaiseTheDead", "chainKey", "Chain", "caravanKey", "Caravan"
            , "beatKey", "Beat", "hologramKey", "Hologram", "repositionKey", "Repo")
            s["Hotkeys." dst] := rt[src]
        s["Options.UpgradeDelay"] := String(rt["upgradeDelayMs"])
        s["Options.KeyDelay"] := String(rt.Has("keyDelayMs") ? rt["keyDelayMs"] : 20)
        s["Options.ExtraUiWait"] := String(rt.Has("extraUiWait") ? rt["extraUiWait"] : 0)
        s["Options.PreJoinDelay"] := String(rt.Has("preJoinDelay") ? rt["preJoinDelay"] : 0)
        b := opts.bindings
        for src, dst in Map("align", "AlignCameraKey", "place", "PlaceTowerKey", "upgrade", "UpgradeTowerKey", "sell", "SellTowerKey"
            , "clone", "HoloKey", "targets", "ChangeTargetsKey", "dj", "ChangeDJTrackKey")
            s["RecordingHotkeys." dst] := Store.AhkHotkey(b[src])
        if opts.HasOwnProp("rotation") && IsObject(opts.rotation) {
            s["Options.RotateStrategies"] := "1"
            s["Options.SwapAmount"] := String(opts.rotation.amount)
            s["Options.SwapUnit"] := opts.rotation.unit
            s["Options.AutoEquip"] := "1"
        }
        if opts.HasOwnProp("party") && IsObject(opts.party) {
            p := opts.party
            s["Multiplayer.MultiplayerEnabled"] := "1"
            s["Multiplayer.PlayerRole"] := StrTitle(p.role)
            s["Multiplayer.HostName"] := p.host
            members := ""
            for i, m in p.members
                members .= (i > 1 ? ", " : "") m
            s["Multiplayer.PartyMembers"] := members
            s["Multiplayer.LeaveCondition"] := StrTitle(p.leave)
        }
        ; Ability keys and recording hotkeys must stay distinct (CrossFieldProblems).
        seen := Map()
        for row in Engine.Schema() {
            if (row[1] != "Hotkeys" && row[1] != "RecordingHotkeys")
                continue
            id := row[1] "." row[2], v := StrLower(s.Has(id) ? s[id] : row[3])
            if seen.Has(v)
                throw ValueError("Duplicate hotkey: " seen[v] " and " row[2] ".")
            seen[v] := row[2]
        }
        return s
    }

    static RenderIni(values, sections) {
        out := "", current := ""
        for row in Engine.Schema() {
            if !InArray(sections, row[1])
                continue
            if (row[1] != current)
                out .= "[" row[1] "]`r`n", current := row[1]
            id := row[1] "." row[2]
            v := values.Has(id) ? values[id] : row[3]
            if RegExMatch(v, "[\r\n\x00]")
                throw ValueError("Line breaks are not allowed in settings.")
            out .= row[2] "=" v "`r`n"
        }
        return out
    }

    ; GetPrivateProfileString only reads Unicode from UTF-16 LE files with a BOM.
    static WriteUtf16(path, text) => AtomicWrite(path, text, "UTF-16")

    static NewId() {
        id := ""
        guid := Buffer(16, 0)
        DllCall("ole32\CoCreateGuid", "Ptr", guid)
        Loop 16
            id .= Format("{:02x}", NumGet(guid, A_Index - 1, "UChar"))
        return id
    }

    static NewUuid() {
        h := Engine.NewId()
        return SubStr(h, 1, 8) "-" SubStr(h, 9, 4) "-4" SubStr(h, 14, 3) "-" Format("{:x}", 8 + Mod(Integer("0x" SubStr(h, 17, 1)), 4)) SubStr(h, 18, 3) "-" SubStr(h, 21, 12)
    }

    static Prepare(values, slot1 := "", slot2 := "") {
        d := Engine.data
        for sub in ["", "\Options", "\Recordings", "\Active", "\Logs"]
            DirCreate(d sub)
        values := Store.CopyMap(values)
        values["Options.Strategy1"] := slot1 != "" ? Engine.Snapshot(slot1, "slot1.strat") : ""
        values["Options.Strategy2"] := slot2 != "" ? Engine.Snapshot(slot2, "slot2.strat") : ""
        if (slot1 = "")
            try FileDelete(d "\Active\slot1.strat")
        if (slot2 = "")
            try FileDelete(d "\Active\slot2.strat")
        ; Secrets are never written: webhook/bot/VIP values stay blank.
        for id in ["Options.VipLink", "Webhook.Link", "Webhook.Link2", "Webhook.WebhookUserID"]
            values[id] := ""
        Engine.WriteUtf16(d "\Options\Settings.tds", Engine.RenderIni(values, ["Options", "Hotkeys", "RecordingHotkeys", "Multiplayer", "Webhook"]))
        Engine.WriteUtf16(d "\Options\Discord-Bot-Settings.ini", "[Settings]`r`nEnabled=0`r`nChannel=`r`nUserID=`r`n[Token]`r`nBotToken=`r`n")
        Engine.session := Engine.NewId()
        Engine.WriteUtf16(d "\state.ini", "[State]`r`nRunning=0`r`nIsFirstLaunch=0`r`nSession=" Engine.session "`r`n")
    }

    ; Run exactly the bytes that were inspected.
    static Snapshot(text, name) {
        target := Engine.data "\Active\" name
        Strategy.Parse(text)
        AtomicWrite(target, text)
        return target
    }

    static Revoke() {
        try Engine.WriteUtf16(Engine.data "\state.ini", "[State]`r`nRunning=0`r`nIsFirstLaunch=0`r`nSession=revoked-" Engine.NewId() "`r`n")
    }

    ; ---- process ownership -------------------------------------------------
    static ImagePath(pid) {
        h := DllCall("OpenProcess", "UInt", 0x1000, "Int", 0, "UInt", pid, "Ptr")
        if !h
            return ""
        size := 32768, buf := Buffer(size * 2, 0)
        ok := DllCall("QueryFullProcessImageNameW", "Ptr", h, "UInt", 0, "Ptr", buf, "UInt*", &size)
        DllCall("CloseHandle", "Ptr", h)
        return ok ? StrGet(buf, size, "UTF-16") : ""
    }

    static IsOurs(pid, interp := "") {
        p := Engine.ImagePath(pid)
        return p != "" && StrLower(p) = StrLower(interp = "" ? Engine.interpreter : interp)
    }

    static OwnedPids(interp := "") {
        interp := interp = "" ? Engine.interpreter : interp
        SplitPath(interp, &exe)
        out := []
        snap := DllCall("CreateToolhelp32Snapshot", "UInt", 2, "UInt", 0, "Ptr")
        if (snap = -1)
            return out
        pe := Buffer(A_PtrSize = 8 ? 568 : 556, 0)
        NumPut("UInt", pe.Size, pe)
        ok := DllCall("Process32FirstW", "Ptr", snap, "Ptr", pe)
        while ok {
            name := StrGet(pe.Ptr + (A_PtrSize = 8 ? 44 : 36), "UTF-16")
            pid := NumGet(pe, 8, "UInt")
            ; The launcher itself may run on the bundled interpreter: never count ourselves.
            if (name = exe && pid != DllCall("GetCurrentProcessId") && Engine.IsOurs(pid, interp))
                out.Push(pid)
            ok := DllCall("Process32NextW", "Ptr", snap, "Ptr", pe)
        }
        DllCall("CloseHandle", "Ptr", snap)
        return out
    }

    static KillOwned(includeTools := false) {
        for pid in Engine.OwnedPids()
            try ProcessClose(pid)
        if includeTools
            Engine.KillTools()
        Engine.pid := 0, Engine.engineHwnd := 0
    }

    static KillTools() {
        if FileExist(Engine.toolInterpreter)
            for pid in Engine.OwnedPids(Engine.toolInterpreter)
                try ProcessClose(pid)
        Engine.tools := []
    }

    static ToolsRunning() {
        alive := []
        for pid in Engine.tools
            if ProcessExist(pid)
                alive.Push(pid)
        Engine.tools := alive
        return alive.Length > 0
    }

    ; UM14_ReleaseInputs: key-up for every key and mouse button that is down.
    static ReleaseInputs() {
        Loop 247 {
            key := Format("vk{:02X}", A_Index + 7)
            try {
                if GetKeyState(key)
                    SendEvent("{Blind}{" key " up}")
            }
        }
        for key in ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
            try {
                if GetKeyState(key)
                    SendEvent("{Blind}{" key " up}")
            }
    }

    ; ---- lifecycle ---------------------------------------------------------
    static Launch(values, slot1 := "", slot2 := "", then := "") {
        if !Engine.Installed()
            throw Error("The engine files are missing. Extract the whole Ultimate Macro folder again.")
        if (Engine.phase != "offline" && Engine.phase != "faulted")
            throw Error("The engine is already running.")
        if Engine.OwnedPids().Length {
            Engine.KillOwned()
            Sleep(150)
        }
        Engine.Prepare(values, slot1, slot2)
        Engine.seqOut := 0, Engine.seqIn := 0, Engine.missingSince := 0, Engine.fatal := false
        Engine.stats := "", Engine.gameLaunch := "", Engine.gameLaunchNonces := Map(), Engine.recorded := ""
        Engine.pending := then, Engine.stopRequested := false, Engine.lastError := "", Engine.stopReason := ""
        cmd := '"' Engine.interpreter '" "' Engine.script '" --um14-engine --session ' Engine.session
            . ' --data "' Engine.data '" --launcher-hwnd ' A_ScriptHwnd ' --launcher-pid ' ProcessExist()
        pid := 0
        Run(cmd, App.engine, , &pid)
        Engine.pid := pid
        Engine.deadline := A_TickCount + 25000
        Engine.Set("launching")
    }

    static Command(verb, args := "") {
        if (Engine.session = "" || !Engine.engineHwnd)
            return false
        Engine.seqOut += 1
        text := "UM14|1|" Engine.session "|" Engine.seqOut "|" verb "|"
        if IsObject(args) {
            keys := []
            for k in args
                keys.Push(k)
            SortStrings(keys)
            for i, k in keys {
                v := String(args[k])
                if RegExMatch(v, "[\t|\r\n\x00]")
                    return false
                text .= (i > 1 ? "`t" : "") k "=" v
            }
        }
        if (StrLen(text) > 4096)
            return false
        size := (StrLen(text) + 1) * 2
        buf := Buffer(size, 0)
        StrPut(text, buf, "UTF-16")
        cds := Buffer(3 * A_PtrSize, 0)
        NumPut("UPtr", 0x554D3134, cds, 0)
        NumPut("UInt", size, cds, A_PtrSize)
        NumPut("Ptr", buf.Ptr, cds, 2 * A_PtrSize)
        result := 0
        ok := DllCall("SendMessageTimeoutW", "Ptr", Engine.engineHwnd, "UInt", 0x004A, "Ptr", A_ScriptHwnd, "Ptr", cds.Ptr
            , "UInt", 0x0002, "UInt", 2000, "UPtr*", &result)
        return ok && result
    }

    static Start() {
        if (Engine.phase != "idle")
            return false
        if !Engine.Command("start")
            return false
        Engine.deadline := A_TickCount + 25000, Engine.startNotice := false
        Engine.Set("starting")
        return true
    }

    static Record(args) {
        if (Engine.phase != "idle")
            return false
        if !Engine.Command("record", args)
            return false
        Engine.deadline := A_TickCount + 25000
        Engine.Set("starting")
        return true
    }

    static RecordStop(name, add := true) {
        if (Engine.phase != "recording")
            return false
        if !Engine.Command("recordstop", Map("name", name, "add", add ? "1" : "0"))
            return false
        Engine.stopRequested := true
        Engine.deadline := A_TickCount + 8000
        Engine.Set("stopping")
        return true
    }

    ; Graceful stop with an 8 s grace; emergency skips straight to termination.
    static Stop(emergency := false, reason := "stopped") {
        Engine.gameLaunch := "", Engine.pending := ""
        Engine.stopReason := reason
        if (Engine.phase = "offline") {
            if (emergency || Engine.ToolsRunning())
                Engine.KillTools()
            Engine.ReleaseInputs()
            return true
        }
        if (!emergency && InArray(["running", "starting", "recording", "stopping"], Engine.phase) && Engine.Command("stop")) {
            Engine.stopRequested := true
            if (Engine.phase != "stopping") {
                Engine.deadline := A_TickCount + 8000
                Engine.Set("stopping")
            }
            return true
        }
        if (!emergency && (Engine.phase = "idle" || Engine.phase = "launching")) {
            Engine.Shutdown()
            return true
        }
        Engine.ForceStop(emergency ? "Emergency stop: engine terminated." : "Engine did not respond to stop; terminated.")
        return true
    }

    static Shutdown() {
        Engine.gameLaunch := "", Engine.pending := ""
        if (Engine.phase = "offline")
            return
        if (Engine.phase = "idle")
            Engine.Command("shutdown")
        Engine.KillOwned()
        Engine.Revoke()
        Engine.ReleaseInputs()
        Engine.Set("offline")
    }

    static ForceStop(message) {
        Engine.KillOwned(true)
        Engine.Revoke()
        Engine.ReleaseInputs()
        Engine.Log(message)
        Engine.deadline := 0, Engine.stopRequested := false
        Engine.Set("offline")
    }

    ; ---- receive -------------------------------------------------------------
    static OnCopyData(wParam, lParam, msg, hwnd) {
        if (hwnd != A_ScriptHwnd || Engine.session = "")
            return
        if (NumGet(lParam, 0, "UPtr") != 0x554D3134)
            return 0
        size := NumGet(lParam, A_PtrSize, "UInt")
        if (size < 4 || size > 8194 || Mod(size, 2))
            return 0
        text := StrGet(NumGet(lParam, 2 * A_PtrSize, "Ptr"), size // 2, "UTF-16")
        senderPid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", wParam, "UInt*", &senderPid)
        if (Engine.inbox.Length >= 256)
            return 0
        Engine.inbox.Push([text, senderPid, wParam])
        SetTimer(Engine.Drain.Bind(Engine), -1)
        return 1
    }

    static Drain() {
        while Engine.inbox.Length {
            item := Engine.inbox.RemoveAt(1)
            try Engine.Receive(item[1], item[2], item[3])
        }
    }

    static Decode(text) {
        if (StrLen(text) = 0 || StrLen(text) > 4096 || RegExMatch(text, "[\r\n\x00]"))
            return ""
        parts := StrSplit(text, "|", , 6)
        if (parts.Length != 6 || parts[1] !== "UM14" || parts[2] !== "1" || parts[3] !== Engine.session)
            return ""
        if !RegExMatch(parts[4], "^[1-9]\d{0,17}$")
            return ""
        args := Map()
        if (parts[6] != "")
            for pair in StrSplit(parts[6], "`t") {
                eq := InStr(pair, "=")
                k := SubStr(pair, 1, eq - 1)
                if (eq < 2 || !RegExMatch(k, "^[a-z]{1,16}$") || args.Has(k))
                    return ""
                args[k] := SubStr(pair, eq + 1)
            }
        allowed := Map("hello", "pid hwnd build resumed", "state", "value", "log", "text", "recorded", "file", "error", "text"
            , "bye", "reason", "stats", "coins gems xp matches", "gamelaunch", "id hwnd", "recstate", "steps aligned")
        if !allowed.Has(parts[5])
            return ""
        for k in args
            if !InStr(" " allowed[parts[5]] " ", " " k " ")
                return ""
        return {seq: Integer(parts[4]), verb: parts[5], args: args}
    }

    static Arg(m, k) => m.args.Has(k) ? m.args[k] : ""

    static Receive(text, senderPid, senderHwnd) {
        m := Engine.Decode(text)
        if !IsObject(m)
            return
        if (m.verb = "hello") {
            pid := Engine.Arg(m, "pid"), hwnd := Engine.Arg(m, "hwnd")
            if (!RegExMatch(pid, "^\d+$") || Integer(pid) != senderPid || !RegExMatch(hwnd, "^\d+$")
                || Integer(hwnd) != senderHwnd || !Engine.IsOurs(senderPid)) {
                Engine.Log("Ignored engine hello from an unverified process.")
                return
            }
            if (Engine.Arg(m, "build") != Engine.BUILD) {
                Engine.ForceStop("Engine build mismatch. Extract the complete Ultimate Macro folder again; no strategy was started.")
                return
            }
            Engine.pid := senderPid, Engine.engineHwnd := senderHwnd
            Engine.seqIn := m.seq, Engine.missingSince := 0, Engine.gameLaunch := ""
            resumed := Engine.Arg(m, "resumed") = "1"
            if !resumed
                Engine.stopRequested := false
            if (Engine.phase = "running" && resumed) {
                Engine.Log("Engine recovered and resumed the run.")
                return
            }
            if InArray(["stopping", "launching", "starting", "running", "faulted"], Engine.phase) {
                if (Engine.phase = "running")
                    Engine.Log("Engine relaunched without resuming.")
                Engine.deadline := 0
                Engine.Set("idle")
                Engine.RunPending()
            }
            return
        }
        if (senderPid != Engine.pid)
            return
        if (m.seq <= Engine.seqIn)
            return
        Engine.seqIn := m.seq
        switch m.verb {
            case "gamelaunch":
                id := Engine.Arg(m, "id"), hwnd := Engine.Arg(m, "hwnd")
                if (!InArray(["running", "starting", "recording"], Engine.phase) || IsObject(Engine.gameLaunch)
                    || !RegExMatch(id, "^[0-9a-f]{32}$") || !RegExMatch(hwnd, "^[1-9]\d{0,18}$") || Engine.gameLaunchNonces.Has(id))
                    return
                Engine.gameLaunchNonces[id] := 1
                Engine.gameLaunch := {id: id, hwnd: Integer(hwnd), deadline: A_TickCount + 75000}
                Engine.Changed()
            case "stats":
                s := Map()
                for k in ["coins", "gems", "xp", "matches"] {
                    v := Engine.Arg(m, k)
                    s[k] := RegExMatch(v, "^\d{1,13}$") ? Integer(v) : ""
                }
                Engine.stats := s
                Engine.Changed()
            case "log":
                Engine.Log(SubStr(Engine.Arg(m, "text"), 1, 1000))
            case "error":
                Engine.fatal := true, Engine.lastError := SubStr(Engine.Arg(m, "text"), 1, 1000)
                Engine.Log("Engine: " Engine.lastError)
            case "recorded":
                f := Engine.Arg(m, "file")
                if RegExMatch(f, "^[A-Za-z0-9][A-Za-z0-9 _()-]{0,63}\.strat$") {
                    Engine.recorded := f
                    if (Engine.onRecorded)
                        Engine.onRecorded.Call(Engine.data "\Recordings\" f)
                }
            case "bye":
                Engine.gameLaunch := ""
            case "recstate":
                steps := Engine.Arg(m, "steps")
                if (Engine.onRecState && RegExMatch(steps, "^\d{1,6}$"))
                    Engine.onRecState.Call(Integer(steps), Engine.Arg(m, "aligned") = "1")
            case "state":
                v := Engine.Arg(m, "value")
                if !InArray(["idle", "running", "recording", "stopping"], v)
                    return
                if (Engine.phase = "stopping" && (v = "running" || v = "recording"))
                    return
                Engine.deadline := 0
                Engine.Set(v)
                if (v = "stopping" && Engine.stopRequested)
                    Engine.deadline := A_TickCount + 8000
                if (v = "idle" || v = "running" || v = "recording")
                    Engine.stopRequested := false
                if (v = "idle")
                    Engine.RunPending()
        }
    }

    static RunPending() {
        p := Engine.pending
        Engine.pending := ""
        if !IsObject(p)
            return
        if (p.kind = "start") {
            if !Engine.Start()
                Engine.ForceStop("The engine did not accept the start request.")
        } else if (p.kind = "record") {
            if !Engine.Record(p.args)
                Engine.ForceStop("The engine did not accept the recording request.")
        }
    }

    static Tick() {
        if (Engine.phase = "offline")
            return
        alive := Engine.pid && ProcessExist(Engine.pid)
        if !alive {
            if !Engine.missingSince
                Engine.missingSince := A_TickCount
            ; A terminal engine error exits on purpose: no relaunch is coming.
            grace := Engine.fatal ? 1500 : 30000
            if (A_TickCount - Engine.missingSince >= grace) {
                wasActive := InArray(["running", "recording", "starting"], Engine.phase)
                Engine.ReleaseInputs()
                Engine.deadline := 0
                Engine.KillOwned()
                Engine.Revoke()
                if (Engine.phase = "stopping" || Engine.phase = "idle") {
                    Engine.Set("offline")
                } else {
                    if !Engine.fatal
                        Engine.Log(wasActive ? "The engine exited unexpectedly." : "The engine is not running.")
                    Engine.stopReason := "fault"
                    Engine.Set("offline")
                }
                return
            }
        } else
            Engine.missingSince := 0
        if (!Engine.deadline || A_TickCount < Engine.deadline)
            return
        switch Engine.phase {
            case "stopping":
                Engine.ForceStop("Engine did not confirm stop in time; terminated.")
            case "launching":
                Engine.KillOwned()
                Engine.Revoke()
                Engine.Log("The engine did not start in time. Check that the folder is fully extracted and not blocked by antivirus.")
                Engine.stopReason := "fault"
                Engine.Set("offline")
            case "starting":
                Engine.Log("The engine has not confirmed the start yet; it may be waiting for Roblox.")
                Engine.deadline := 0
        }
    }

    static AckGameLaunch(ok) {
        g := Engine.gameLaunch
        Engine.gameLaunch := ""
        if IsObject(g)
            Engine.Command("gameack", Map("id", g.id, "ok", ok ? "1" : "0"))
    }

    ; ---- extended recorder verbs (engine\lib\UM14Bridge.ahk, AHK edition) ----
    static RecordSlot(slot) => Engine.phase = "recording" && Engine.Command("recordslot", Map("slot", String(slot)))
    static RecordAlign() => Engine.phase = "recording" && Engine.Command("recordalign")
    static RecordStep(text) => Engine.phase = "recording" && Engine.Command("recordstep", Map("text", text))

    ; ---- standalone crate utility --------------------------------------------
    static LaunchTool(script := "auto_open_consumable.ahk") {
        if (Engine.phase != "offline" || Engine.ToolsRunning())
            throw Error("Stop existing work before opening a tool.")
        if !FileExist(Engine.toolInterpreter)
            FileCopy(Engine.interpreter, Engine.toolInterpreter)
        root := Engine.data "\tool-data"
        DirCreate(root "\Options")
        Engine.WriteUtf16(root "\Options\Settings.tds", Engine.RenderIni(Map(), ["Options", "Hotkeys", "RecordingHotkeys", "Multiplayer", "Webhook"]))
        pid := 0
        Run('"' Engine.toolInterpreter '" "' App.engine '\submacros\' script '" --data "' root '"', App.engine "\submacros", , &pid)
        Engine.tools.Push(pid)
        Engine.Changed()
    }
}
