; Ultimate Macro 1.4 engine mode — launcher bridge for UM14Engine.ahk.
; Part of a modified version of "Ultimate Macro" by Darksen, licensed GNU GPLv3.
;
; IPC: WM_COPYDATA text from the owning launcher window only, fixed command allowlist,
; bounded sizes, monotonically increasing sequence numbers, matching session id.
; The handler returns immediately; work runs on timers so a long run never blocks Stop.

#Include "%A_LineFile%\..\UM14Shared.ahk"
#Include "%A_LineFile%\..\UM14Match.ahk"

global UM14_Maps := ["Abandoned City", "Area 52", "Autumn Falling", "Badlands II", "Black Spot Exchange", "Candy Valley", "Cataclysm", "Chess Board"
    , "Construction Crazy", "Coral Deep", "Crossroads", "Crystal Cave", "Cyber City", "Dead Ahead", "Derelict Outpost", "Deserted Village", "Dusty Bridges"
    , "Enchanted Forest", "Farm Lands", "Forest Camp", "Forgetten Docks", "Four Seasons", "Fungi Island", "Grass Isle", "Happy Home of Robloxia", "Harbor", "Honey Valley"
    , "Hot Spot", "Iceville", "Infernal Abyss", "Lay By", "Lighthaos", "Marshlands", "Mason Arch", "Medieval Times", "Meltdown"
    , "Midnight Issue", "Moon Base", "Musaceae Kingdom", "Necropolis", "Nether", "Night Station", "Northern Lights", "Outskirts Commune", "Pier Pressure", "Pizza Party", "Polluted Wasteland II"
    , "Portland", "Retro Crossroads", "Retro Lighthouse", "Retro Rocket Arena", "Retro Stained Temple", "Retro The Heights", "Retro Zone", "Rocket Arena", "Ruby Escort", "Sacred Mountains"
    , "Sky Islands", "Simplicity", "Space City", "Spring Fever", "Stained Temple", "Sugar Rush", "The Heavens", "The Heights", "Toyboard", "Tropical Industries", "Tropical Isles", "U-Turn"
    , "Unknown Garden", "Winter Abyss", "Winter Bridges", "Winter Stronghold", "Wrecked Battlefield", "Wrecked Battlefield II", "Wretched Front"]
global UM14_Modes := ["Easy", "Casual", "Intermediate", "Molten", "Fallen", "Frost", "Hardcore", "Voidcore", "Pizza Party", "Badlands II", "Polluted Wasteland II"]
global UM14_Modifiers := ["Broke", "Exploding", "Flying", "Fog", "Glass", "Healthy", "Hidden", "Inflation", "Jailed", "Limitation", "Committed", "Quarantine", "Speedy", "Foggy", "Armored", "Regeneration", "Slow", "Strong"]

UM14_Init() {
    global UM14
    out := UM14_ParseArgs(A_Args)
    if !IsObject(out) {
        MsgBox("This engine is started by Ultimate Macro 1.4. Open Ultimate Macro instead.", "Ultimate Macro engine", 0x10)
        ExitApp(2)
    }
    UM14_Apply(out)
    if !UM14_LauncherAlive()
        ExitApp(3)
    ; A revoked or replaced session never runs or resumes (see EngineWorkspace.Revoke).
    if !UM14_SessionCurrent()
        ExitApp(4)
    UM14.active := true
    OnMessage(0x004A, UM14_OnCopyData)
    SetTimer(UM14_Heartbeat, 2000)
    SetTimer(UM14_LocalStats, 5000)
    UM14.matchRun := IniRead(UM14.data "\state.ini", "State", "MatchRun", "")
}

; Local counters already maintained by the original watchdog. This does not
; capture additional pixels or send network requests. The launcher separately
; requires an explicit sharing opt-in before transmitting aggregate deltas.
UM14_BeginStats() {
    global StateFile
    for name in ["Coins", "Gems", "EXP"]
        IniWrite(1, StateFile, "State", "UM14StatsKnown" name)
    UM14_Emit("stats", Map("coins", 0, "gems", 0, "xp", 0, "matches", 0))
}

UM14_LocalStats() {
    global UM14, StateFile, RunningStrategy
    if (!UM14.active || !UM14.helloSent)
        return
    fields := Map()
    for output, name in Map("coins", "Coins", "gems", "Gems", "xp", "EXP") {
        value := IniRead(StateFile, "State", name, RunningStrategy ? "0" : "unknown")
        known := IniRead(StateFile, "State", "UM14StatsKnown" name, "1") == "1"
        fields[output] := (known && RegExMatch(value, "^\d{1,13}$") && value <= 1000000000000) ? value : "unknown"
    }
    wins := IniRead(StateFile, "State", "TotalTriumphs", "unknown")
    losses := IniRead(StateFile, "State", "TotalLosses", "unknown")
    if (wins == "unknown" && (losses != "unknown" || RunningStrategy))
        wins := "0"
    if (losses == "unknown" && (wins != "unknown" || RunningStrategy))
        losses := "0"
    fields["matches"] := (RegExMatch(wins, "^\d{1,9}$") && RegExMatch(losses, "^\d{1,9}$")) ? wins + losses : "unknown"
    UM14_Emit("stats", fields)
}

UM14_IndexOf(list, value) {
    for i, item in list
        if (item == value)
            return i
    return 0
}

UM14_Emit(verb, args := "") {
    global UM14
    if (!UM14.active)
        return false
    if (!UM14.helloSent && verb != "hello") {
        if (UM14.early.Length < 50)
            UM14.early.Push([verb, args])
        return false
    }
    UM14.seqOut += 1
    text := "UM14|1|" UM14.session "|" UM14.seqOut "|" verb "|"
    if IsObject(args) {
        first := true
        for k, v in args {
            v := RegExReplace(String(v), "[\t|\r\n\x00]", " ")
            if (StrLen(v) > 1000)
                v := SubStr(v, 1, 1000)
            text .= (first ? "" : "`t") k "=" v
            first := false
        }
    }
    size := StrPut(text, "UTF-16")
    buf := Buffer(size, 0)
    StrPut(text, buf, "UTF-16")
    cds := Buffer(3 * A_PtrSize, 0)
    NumPut("UPtr", 0x554D3134, cds, 0)
    NumPut("UInt", size, cds, A_PtrSize)
    NumPut("Ptr", buf.Ptr, cds, 2 * A_PtrSize)
    result := 0
    ; SMTO_ABORTIFHUNG, 1 s: a busy launcher never stalls gameplay.
    return DllCall("SendMessageTimeoutW", "Ptr", UM14.hwnd, "UInt", 0x004A, "Ptr", A_ScriptHwnd, "Ptr", cds.Ptr
        , "UInt", 0x0002, "UInt", 1000, "UPtr*", &result) != 0
}

UM14_Hello(resumed) {
    global UM14
    UM14_Emit("hello", Map("pid", DllCall("GetCurrentProcessId"), "hwnd", A_ScriptHwnd, "build", "1.3.3a-um14.26-ahk3", "resumed", resumed ? 1 : 0))
    UM14.helloSent := true
    early := UM14.early
    UM14.early := []
    for item in early
        UM14_Emit(item[1], item[2])
}

UM14_State(value) {
    UM14_Emit("state", Map("value", value))
}

UM14_CurrentState() {
    global RunningStrategy, Recording
    return RunningStrategy ? "running" : (Recording ? "recording" : "idle")
}

UM14_Fatal(text) {
    global RunningStrategy, StateFile
    RunningStrategy := false
    if (IsSet(StateFile) && StateFile != "")
        try IniWrite(0, StateFile, "State", "Running")
    ; A terminal error must not leave the guard authorized to resume the run.
    try KillSubmacros()
    UM14_Emit("error", Map("text", text))
    UM14_ReleaseInputs()
    ExitApp(6)
}

UM14_ResumeAllowed(path) {
    global UM14
    ; Only the launcher's validated snapshots may be resumed after a relaunch.
    return InStr(path, UM14.data "\Active\") == 1 && UM14_SessionCurrent()
}

UM14_OnCopyData(wParam, lParam, msg, hwnd) {
    global UM14
    if (!UM14.active || hwnd != A_ScriptHwnd || wParam != UM14.hwnd)
        return 0
    if (NumGet(lParam, 0, "UPtr") != 0x554D3134)
        return 0
    size := NumGet(lParam, A_PtrSize, "UInt")
    if (size < 4 || size > 8194 || Mod(size, 2))
        return 0
    text := StrGet(NumGet(lParam, 2 * A_PtrSize, "Ptr"), size // 2, "UTF-16")
    cmd := UM14_Parse(text)
    if (!IsObject(cmd) || UM14.queue.Length >= 16)
        return 0
    UM14.queue.Push(cmd)
    SetTimer(UM14_Dispatch, -1)
    return 1
}

UM14_Parse(text) {
    global UM14
    if (StrLen(text) < 1 || StrLen(text) > 4096 || RegExMatch(text, "[\r\n\x00]"))
        return ""
    parts := StrSplit(text, "|", , 6)
    if (parts.Length != 6 || !(parts[1] == "UM14") || !(parts[2] == "1") || !(parts[3] == UM14.session))
        return ""
    if !RegExMatch(parts[4], "^[1-9]\d{0,17}$")
        return ""
    seq := Integer(parts[4])
    if (seq <= UM14.seqIn)
        return ""
    verb := parts[5]
    allowed := Map("ping", "", "start", "", "stop", "", "shutdown", ""
        , "record", "map mode towers modifiers chain caravan beat skip spam move dir ms passive clicks sales", "recordstop", "name add", "gameack", "id ok"
        , "recordslot", "slot", "recordalign", "", "recordstep", "text")
    if !allowed.Has(verb)
        return ""
    args := Map()
    if (parts[6] != "") {
        for pair in StrSplit(parts[6], "`t") {
            eq := InStr(pair, "=")
            if (eq < 2)
                return ""
            k := SubStr(pair, 1, eq - 1)
            v := SubStr(pair, eq + 1)
            if (!RegExMatch(k, "^[a-z]{1,16}$") || args.Has(k) || !InStr(" " allowed[verb] " ", " " k " ", true))
                return ""
            args[k] := v
        }
    }
    if (verb == "record" && !UM14_ValidRecord(args))
        return ""
    if (verb == "recordstop") {
        if !(args.Has("add") && (args["add"] == "0" || args["add"] == "1"))
            return ""
        if (args.Has("name") && args["name"] != "" && !RegExMatch(args["name"], "^[A-Za-z0-9][A-Za-z0-9 _()-]{0,63}$"))
            return ""
    }
    if (verb == "recordslot" && !(args.Count == 1 && args.Has("slot") && RegExMatch(args["slot"], "^[1-5]$")))
        return ""
    if (verb == "recordstep" && !(args.Count == 1 && args.Has("text") && StrLen(args["text"]) <= 512
        && !RegExMatch(args["text"], "[\x00-\x1F]") && RegExMatch(args["text"], "i)^(SpawnTower|UpgradeTower|CloneTower|SellTower|ChangeTargets|SetDJTrack|ToggleAutoskip|ActivateRaiseTheDead|ActivateEnforcerVan|BrawlerReposition|EnforcerReposition|Sleep|Click)\s*\(")))
        return ""
    if (verb == "gameack" && (args.Count != 2 || !args.Has("id") || !args.Has("ok")
        || !RegExMatch(args["id"],"^[a-f0-9]{32}$") || !(args["ok"] == "0" || args["ok"] == "1")))
        return ""
    UM14.seqIn := seq
    return {verb: verb, args: args}
}

UM14_ValidRecord(args) {
    global UM14_Maps, UM14_Modes, UM14_Modifiers
    for k in ["map", "mode", "towers", "modifiers", "chain", "caravan", "beat", "skip", "spam", "move", "dir", "ms"]
        if !args.Has(k)
            return false
    if (!UM14_IndexOf(UM14_Maps, args["map"]) || !UM14_IndexOf(UM14_Modes, args["mode"]))
        return false
    if !RegExMatch(args["towers"], "^[A-Za-z0-9][A-Za-z0-9 ,'-]{0,255}$")
        return false
    if (args["modifiers"] != "")
        for m in StrSplit(args["modifiers"], ",")
            if !UM14_IndexOf(UM14_Modifiers, m)
                return false
    for k in ["chain", "caravan", "beat", "skip", "spam", "move"]
        if !(args[k] == "0" || args[k] == "1")
            return false
    if !UM14_IndexOf(["W", "A", "S", "D"], args["dir"])
        return false
    for k in ["passive", "clicks", "sales"]
        if (args.Has(k) && !(args[k] == "0" || args[k] == "1"))
            return false
    return RegExMatch(args["ms"], "^\d{1,5}$") && Integer(args["ms"]) <= 60000
}

UM14_Ready() {
    global UM14
    UM14.ready := true
    if (!UM14.helloSent)
        UM14_Hello(0)
    if (UM14.queue.Length)
        SetTimer(UM14_Dispatch, -1)
}

UM14_Dispatch() {
    global UM14, RunningStrategy, Recording
    while (UM14.queue.Length) {
        cmd := UM14.queue[1]
        verb := cmd.verb
        if (verb == "stop") {
            UM14.queue.RemoveAt(1)
            StopStrategy()
        } else if (verb == "shutdown") {
            UM14.queue.RemoveAt(1)
            if (!RunningStrategy && !Recording)
                ExitApp()
        } else if (verb == "ping") {
            UM14.queue.RemoveAt(1)
            UM14_State(UM14_CurrentState())
        } else if (verb == "gameack") {
            UM14.queue.RemoveAt(1)
            if (UM14.HasOwnProp("launchId") && UM14.launchId != "" && UM14.launchResult = "" && cmd.args["id"] == UM14.launchId)
                UM14.launchResult := cmd.args["ok"]
        } else if (!UM14.ready) {
            ; The hidden legacy window is still being built; try again shortly.
            SetTimer(UM14_Dispatch, -250)
            return
        } else if (verb == "start") {
            UM14.queue.RemoveAt(1)
            ; A run never returns; give it its own thread so this dispatcher stays free for Stop.
            SetTimer(UM14_DoStart, -1)
        } else if (verb == "record") {
            UM14.queue.RemoveAt(1)
            if (!RunningStrategy && !Recording) {
                UM14_ApplyRecord(cmd.args)
                StartRecording(0)
            }
            UM14_State(UM14_CurrentState())
        } else if (verb == "recordslot") {
            UM14.queue.RemoveAt(1)
            if (Recording)
                UM14.recordSlot := Integer(cmd.args["slot"])
        } else if (verb == "recordalign") {
            UM14.queue.RemoveAt(1)
            if (Recording)
                SetTimer(UM14_DoAlign, -1)
        } else if (verb == "recordstep") {
            UM14.queue.RemoveAt(1)
            if (Recording && !UM14.recordPassive)
                SetTimer(UM14_DoRecordStep.Bind(cmd.args["text"]), -1)
        } else if (verb == "recordstop") {
            UM14.queue.RemoveAt(1)
            if (Recording) {
                UM14.recordStop := true
                UM14.recordName := cmd.args.Has("name") ? cmd.args["name"] : ""
                UM14.recordAdd := cmd.args["add"] == "1"
                try StopRecord(0)
                UM14.recordStop := false
            }
            UM14_State(UM14_CurrentState())
        } else {
            UM14.queue.RemoveAt(1)
        }
    }
}

UM14_DoStart() {
    global RunningStrategy, Recording
    if (RunningStrategy || Recording)
        return
    UM14_ApplyGameInput()
    StartStrategy()
    if (!RunningStrategy)
        UM14_State("idle")
}

; No URI/path/command is sent to the host. The launcher selects the join target.
; The outside-job launcher validates and closes only the selected client,
; uses its existing trusted opener, then sends the session-authenticated ack.
UM14_RequestGameLaunch() {
    global UM14, UseVipServer, RunningStrategy
    if (UseVipServer = "1" || UseVipServer = 1)
        UM14_Fatal("Set private server links in the launcher, not the legacy engine settings. Roblox was not closed.")
    UM14_RequireReadyFocus()
    hwnd := GetRobloxHWND()
    if (!hwnd || !RunningStrategy || !UM14_LauncherAlive() || !UM14_SessionCurrent()
        || (UM14.HasOwnProp("launchId") && UM14.launchId != ""))
        UM14_Fatal("The selected Roblox client or relaunch owner could not be verified.")
    token := Buffer(16,0)
    if (DllCall("ole32\CoCreateGuid","Ptr",token) != 0)
        UM14_Fatal("A game relaunch request could not be created.")
    id := ""
    Loop 16
        id .= Format("{:02x}",NumGet(token,A_Index-1,"UChar"))
    UM14.launchId := id, UM14.launchResult := ""
    result := "", reason := "The trusted game launcher did not confirm a relaunch within 90 seconds."
    started := A_TickCount
    try {
        if (!UM14_Emit("gamelaunch",Map("id",id,"hwnd",hwnd)))
            reason := "The owning launcher did not accept the game relaunch request."
        else {
            Loop {
                if (!RunningStrategy || !UM14_LauncherAlive() || !UM14_SessionCurrent()) {
                    reason := "The run stopped or the game relaunch owner/session changed."
                    break
                }
                if (UM14.launchResult != "") {
                    result := UM14.launchResult
                    reason := "The trusted game launcher refused or could not complete the Roblox relaunch."
                    break
                }
                if (A_TickCount-started >= 90000)
                    break
                Sleep(50)
            }
        }
    } finally {
        UM14.launchId := "", UM14.launchResult := ""
    }
    if (result != "1")
        UM14_Fatal(reason)
    return true
}

UM14_ApplyRecord(args) {
    global UM14_Maps, UM14_Modes, UM14_Modifiers
    global RecMapsD, RecDiffCtrl, RecTowersCtrl, RecModifiersCtrl, RecAutoChainCtrl, RecAutoCaravanCtrl
    global RecAutoDropCtrl, RecAutoSkipCtrl, RecAbilitySpamCtrl, RecMoveCtrl, RecMoveDirCtrl, RecMoveDurCtrl
    RecMapsD.Choose(UM14_IndexOf(UM14_Maps, args["map"]))
    RecDiffCtrl.Choose(UM14_IndexOf(UM14_Modes, args["mode"]))
    RecTowersCtrl.Value := args["towers"]
    RecModifiersCtrl.Choose(0)
    if (args["modifiers"] != "")
        for m in StrSplit(args["modifiers"], ",")
            RecModifiersCtrl.Choose(UM14_IndexOf(UM14_Modifiers, m))
    RecAutoChainCtrl.Value := Integer(args["chain"])
    RecAutoCaravanCtrl.Value := Integer(args["caravan"])
    RecAutoDropCtrl.Value := Integer(args["beat"])
    RecAutoSkipCtrl.Value := Integer(args["skip"])
    RecAbilitySpamCtrl.Value := Integer(args["spam"])
    RecMoveCtrl.Value := Integer(args["move"])
    RecMoveDirCtrl.Choose(UM14_IndexOf(["W", "A", "S", "D"], args["dir"]))
    RecMoveDurCtrl.Value := args["ms"]
    UM14.recordPassive := args.Has("passive") && args["passive"] == "1"
    UM14.recordClicks := !args.Has("clicks") || args["clicks"] == "1"
    UM14.recordSales := args.Has("sales") && args["sales"] == "1"
    UM14.recordSlot := 0, UM14.recordAligned := false, UM14.recSteps := -1
    SetTimer(UM14_RecState, 400)
}

; AutoHotkey edition: launcher-driven recorder actions (no blocking dialogs).
UM14_RecState(force := false) {
    global UM14, Recording, RecordedSteps
    if (!Recording) {
        SetTimer(UM14_RecState, 0)
        return
    }
    n := IsSet(RecordedSteps) && IsObject(RecordedSteps) ? RecordedSteps.Length : 0
    if (!force && n == UM14.recSteps)
        return
    UM14.recSteps := n
    UM14_Emit("recstate", Map("steps", n, "aligned", UM14.recordAligned ? 1 : 0))
}

UM14_DoAlign() {
    global UM14, Recording, gamemap, SpecialMaps
    if (!Recording)
        return
    ActivateRoblox()
    Sleep(80)
    if (InArray(SpecialMaps, gamemap)) {
        functionName := gamemap . "Path"
        %functionName%()
    } else
        AlignCamera()
    UM14.recordAligned := true
    LogToConsole("Camera aligned.")
    UM14_RecState(true)
}

UM14_DoRecordStep(text) {
    global UM14, Recording, RecordedSteps, Towers
    if (!Recording || UM14.recordPassive)
        return
    ActivateRoblox()
    Sleep(80)
    try {
        ExecuteStep(text)
    } catch as e {
        LogToConsole("Action was not recorded: " SubStr(e.Message, 1, 120))
        return
    }
    if RegExMatch(text, "i)^SpawnTower\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*([1-9])\s*,\s*(.+?)\s*\)$", &m)
        Towers[m[4]] := {x: Integer(m[1]), y: Integer(m[2]), slot: m[3], level: 0, path: 0, pathLevel: 0, target: "First Enemy"}
    RecordedSteps.Push(text)
    LogToConsole("Recorded action: " text)
}

; Sell-button clicks after a recorded placement or selection (opt-in).
UM14_DetectSell(towerID, mx, my) {
    global RecordedSteps, Towers, ActiveRTowerID
    res := AdvancedImageSearch("Resources\Sell.png", mx - 120, my - 45, 240, 90)
    if !(IsObject(res) && res.HasProp("status") && res.status == "success" && res.score >= 0.7)
        return false
    RecordedSteps.Push("SellTower(" towerID ")")
    if (Towers.Has(towerID))
        Towers.Delete(towerID)
    ActiveRTowerID := ""
    try DeleteAllIndicators()
    LogToConsole("Recorded sell tower " towerID)
    return true
}

; Used by the patched StopRecord: launcher-provided answers, or the legacy dialogs for F2.
UM14_RecordName() {
    global UM14
    if (UM14.recordStop)
        return UM14.recordName
    ; AutoHotkey edition: F2 in Roblox keeps a draft for the launcher; never a blocking dialog.
    return "UMDraft-" A_TickCount
}

UM14_AskAdd() {
    global UM14
    if (UM14.recordStop)
        return UM14.recordAdd
    return true
}

UM14_Relaunch() {
    global UM14
    UM14_Emit("bye", Map("reason", "relaunch"))
    UM14_ReleaseInputs()
    if (!UM14_LauncherAlive() || !UM14_SessionCurrent())
        ExitApp(5)
    ; Reload() would drop these arguments; relaunch explicitly with the same session.
    Run('"' A_AhkPath '" /restart "' A_ScriptFullPath '" ' UM14_ArgString())
    ExitApp()
}

UM14_Heartbeat() {
    global UM14, StateFile
    if (UM14_LauncherAlive() && UM14_SessionCurrent())
        return
    ; Launcher closed or session revoked: stop safely and never resume this session.
    SetTimer(UM14_Heartbeat, 0)
    UM14_ReleaseInputs()
    try KillSubmacros()
    try IniWrite(0, StateFile, "State", "Running")
    ExitApp(5)
}

UM14_BeginMatchRun() {
    global UM14, StateFile
    token := Buffer(16, 0)
    if (DllCall("ole32\CoCreateGuid", "Ptr", token) != 0)
        UM14_Fatal("The match session could not be created.")
    UM14.matchRun := ""
    Loop 16
        UM14.matchRun .= Format("{:02x}", NumGet(token, A_Index - 1, "UChar"))
    try IniDelete(StateFile, "State", "MatchCompletion")
    try IniDelete(StateFile, "State", "GameUnavailable")
    IniWrite(UM14.matchRun, StateFile, "State", "MatchRun")
    SetTimer(UM14_CheckMatchCompletion, 500)
}

UM14_CheckMatchCompletion() {
    global UM14, StateFile, SettingsFile, RunningStrategy
    if (!IsSet(RunningStrategy) || !IsSet(StateFile) || !IsSet(SettingsFile)
        || !RunningStrategy || !UM14.HasOwnProp("matchRun") || UM14.matchRun == ""
        || !UM14_LauncherAlive() || !UM14_SessionCurrent())
        return
    if (IniRead(StateFile,"State","GameUnavailable","") == (UM14.session "|" UM14.matchRun)) {
        try IniDelete(StateFile,"State","GameUnavailable")
        UM14_Fatal("The Roblox window closed or crashed. The launcher stayed open; rejoin TDS and press Start.")
    }
    if (IniRead(SettingsFile, "Options", "Repeat", "1") != "0")
        return
    result := UM14_ValidMatchCompletion(IniRead(StateFile, "State", "MatchCompletion", ""), UM14.session, UM14.matchRun)
    if (result == "")
        return
    UM14.matchRun := ""
    SetTimer(UM14_CheckMatchCompletion, 0)
    try IniDelete(StateFile, "State", "MatchCompletion")
    try UM14_LocalStats() ; Preserve measured totals before the original Stop clears them.
    catch
        LogToConsole("Final measured stats could not be read; stopping the completed match.")
    LogToConsole("Match finished. Repeat is off; automation stopped.")
    StopStrategy() ; Existing release/owned-tool cleanup and idle relaunch, not app exit.
}

UM14_ResumeMatchRun() {
    global StateFile
    ; A crash/disconnect resume is not a fresh observed game start. Never let
    ; the previous attempt's timestamp certify a leftover end screen.
    UM14_CheckMatchCompletion()
    try IniDelete(StateFile, "State", "TimeWhenStartedPlaying")
    SetTimer(UM14_CheckMatchCompletion, 500)
}
