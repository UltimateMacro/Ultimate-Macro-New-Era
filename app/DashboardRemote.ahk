; Authenticated commands are user-initiated in the Dashboard. Only existing,
; guarded macro handlers are called; unsupported actions are explicitly rejected.
class DashboardRemote {
    static pollTimer := "", pending := "", commandQueue := []
    static stopAfterMatch := false
    static cooldownTimer := "", cooldownFile := A_AppData "\Ultimate_Macro\Dashboard-cooldown.ini"
    static restored := false, resultBody := "", retries := 0
    static runAction := "", remoteStartPrompt := false
    static cooldown := Map("phase", "idle", "mode", "idle", "resumeAutomatically", false, "minutes", 0, "targetC", 0, "until", "")

    static Start() {
        if !Dashboard.token
            return
        if !DashboardRemote.restored {
            DashboardRemote.RestoreCooldown()
            DashboardRemote.stopAfterMatch := DashboardMatch.StopPending()
            DashboardRemote.restored := true
        }
        DashboardRemote.ApplyPendingStrategy()
        if !DashboardRemote.pollTimer
            DashboardRemote.pollTimer := ObjBindMethod(DashboardRemote, "Tick")
        if !IsObject(DashboardRemote.pending)
            SetTimer(DashboardRemote.pollTimer, -100)
    }

    static Stop() {
        if DashboardRemote.pollTimer
            SetTimer(DashboardRemote.pollTimer, 0)
        old := DashboardRemote.pending, DashboardRemote.pending := ""
        if (IsObject(old) && IsObject(old.req))
            try old.req.Abort()
        DashboardRemote.commandQueue := []
        DashboardRemote.resultBody := ""
        DashboardRemote.runAction := "", DashboardRemote.remoteStartPrompt := false
        DashboardRemote.restored := false
        if DashboardRemote.cooldownTimer
            SetTimer(DashboardRemote.cooldownTimer, 0)
    }

    static RestoreCooldown() {
        if !Dashboard.token
            return
        if (IniRead(DashboardRemote.cooldownFile, "Cooldown", "Active", "0") != "1")
            return
        DashboardRemote.cooldown["phase"] := IniRead(DashboardRemote.cooldownFile, "Cooldown", "Phase", "cooling")
        DashboardRemote.cooldown["mode"] := IniRead(DashboardRemote.cooldownFile, "Cooldown", "Mode", "minutes")
        DashboardRemote.cooldown["resumeAutomatically"] := IniRead(DashboardRemote.cooldownFile, "Cooldown", "Resume", "0") = "1"
        DashboardRemote.cooldown["minutes"] := Integer(IniRead(DashboardRemote.cooldownFile, "Cooldown", "Minutes", "0"))
        DashboardRemote.cooldown["targetC"] := Number(IniRead(DashboardRemote.cooldownFile, "Cooldown", "TargetC", "0"))
        DashboardRemote.cooldown["until"] := IniRead(DashboardRemote.cooldownFile, "Cooldown", "Until", "")
        if (DashboardRemote.cooldown["phase"] = "waiting_for_match" && !DashboardRemote.MatchRunning())
            DashboardRemote.BeginCooldown()
        if !DashboardRemote.cooldownTimer
            DashboardRemote.cooldownTimer := ObjBindMethod(DashboardRemote, "CooldownTick")
        SetTimer(DashboardRemote.cooldownTimer, 15000)
        DashboardRemote.CooldownTick()
    }

    static PersistCooldown() {
        try {
            DirCreate(A_AppData "\Ultimate_Macro")
            IniWrite(1, DashboardRemote.cooldownFile, "Cooldown", "Active")
            IniWrite(DashboardRemote.cooldown["phase"], DashboardRemote.cooldownFile, "Cooldown", "Phase")
            IniWrite(DashboardRemote.cooldown["mode"], DashboardRemote.cooldownFile, "Cooldown", "Mode")
            IniWrite(DashboardRemote.cooldown["resumeAutomatically"] ? 1 : 0, DashboardRemote.cooldownFile, "Cooldown", "Resume")
            IniWrite(DashboardRemote.cooldown["minutes"], DashboardRemote.cooldownFile, "Cooldown", "Minutes")
            IniWrite(DashboardRemote.cooldown["targetC"], DashboardRemote.cooldownFile, "Cooldown", "TargetC")
            IniWrite(DashboardRemote.cooldown["until"], DashboardRemote.cooldownFile, "Cooldown", "Until")
        }
    }

    static StartCooldown(payload) {
        global RunningStrategy
        if !(payload is Map) || !payload.Has("mode") || !payload.Has("resumeAutomatically")
            return false
        mode := payload["mode"], resume := payload["resumeAutomatically"]
        if (mode != "minutes" && mode != "temperature")
            return false
        if (resume != JSON.true && resume != JSON.false && resume != 0 && resume != 1)
            return false
        minutes := 0, targetC := 0
        if (mode = "minutes") {
            if !payload.Has("minutes") || !(payload["minutes"] is Integer) || payload["minutes"] < 5 || payload["minutes"] > 240
                return false
            minutes := payload["minutes"]
        } else {
            if !payload.Has("targetC") || !(payload["targetC"] is Number) || payload["targetC"] < 45 || payload["targetC"] > 80
                return false
            if (DashboardRemote.CpuTemperature() = "")
                return false
            targetC := payload["targetC"]
        }
        if (DashboardRemote.cooldown["phase"] != "idle" && DashboardRemote.cooldown["phase"] != "ready")
            return false
        if RunningStrategy && !DashboardMatch.SetStop(true)
            return false
        DashboardRemote.cooldown["phase"] := RunningStrategy ? "waiting_for_match" : "cooling"
        DashboardRemote.cooldown["mode"] := mode
        DashboardRemote.cooldown["resumeAutomatically"] := resume = JSON.true || ((resume is Integer) && resume = 1)
        DashboardRemote.cooldown["minutes"] := minutes
        DashboardRemote.cooldown["targetC"] := targetC
        DashboardRemote.cooldown["until"] := ""
        if RunningStrategy {
            DashboardRemote.stopAfterMatch := true
        } else DashboardRemote.BeginCooldown()
        DashboardRemote.PersistCooldown()
        if !DashboardRemote.cooldownTimer
            DashboardRemote.cooldownTimer := ObjBindMethod(DashboardRemote, "CooldownTick")
        SetTimer(DashboardRemote.cooldownTimer, 15000)
        Dashboard.Beat()
        return true
    }

    static BeginCooldown() {
        DashboardRemote.cooldown["phase"] := "cooling"
        if (DashboardRemote.cooldown["mode"] = "minutes") {
            minutes := DashboardRemote.cooldown["minutes"]
            DashboardRemote.cooldown["until"] := FormatTime(DateAdd(A_NowUTC, minutes, "Minutes"), "yyyyMMddHHmmss")
        }
        DashboardRemote.PersistCooldown()
    }

    static MatchFinishedForCooldown() {
        DashboardRemote.stopAfterMatch := false
        if (DashboardRemote.cooldown["phase"] = "waiting_for_match")
            DashboardRemote.BeginCooldown()
        Dashboard.Beat()
    }

    static CancelCooldown(notify := true) {
        DashboardRemote.stopAfterMatch := false
        DashboardMatch.SetStop(false)
        DashboardRemote.cooldown := Map("phase", "idle", "mode", "idle", "resumeAutomatically", false, "minutes", 0, "targetC", 0, "until", "")
        if DashboardRemote.cooldownTimer
            SetTimer(DashboardRemote.cooldownTimer, 0)
        try IniDelete(DashboardRemote.cooldownFile, "Cooldown")
        if notify
            Dashboard.Beat()
        return true
    }

    static CooldownTick(*) {
        global RunningStrategy, Recording, MacroRecording, Strategy1Path
        if !Dashboard.token
            return
        phase := DashboardRemote.cooldown["phase"]
        if (phase = "waiting_for_match" && !DashboardRemote.MatchRunning()) {
            DashboardRemote.BeginCooldown()
            phase := "cooling"
        }
        if (phase != "cooling")
            return
        complete := false
        if (DashboardRemote.cooldown["mode"] = "minutes") {
            cooldownUntil := DashboardRemote.cooldown["until"]
            complete := cooldownUntil != "" && FormatTime(A_NowUTC, "yyyyMMddHHmmss") >= cooldownUntil
        } else if (DashboardRemote.cooldown["mode"] = "temperature") {
            temperature := DashboardRemote.CpuTemperature()
            complete := temperature != "" && temperature <= DashboardRemote.cooldown["targetC"]
        }
        if !complete
            return
        DashboardRemote.cooldown["phase"] := "ready"
        DashboardRemote.PersistCooldown()
        Dashboard.Beat()
        if (DashboardRemote.cooldown["resumeAutomatically"] && !RunningStrategy && !Recording && !MacroRecording && Strategy1Path != "" && FileExist(Strategy1Path)) {
            DashboardRemote.CancelCooldown()
            SetTimer(ObjBindMethod(DashboardRemote, "StartFromRemote"), -1)
        }
    }

    static CooldownSnapshot() {
        phase := DashboardRemote.cooldown["phase"], mode := DashboardRemote.cooldown["mode"]
        remaining := JSON.null, current := JSON.null, target := JSON.null
        if (phase = "cooling" && mode = "minutes" && DashboardRemote.cooldown["until"] != "")
            remaining := Max(0, DateDiff(DashboardRemote.cooldown["until"], FormatTime(A_NowUTC, "yyyyMMddHHmmss"), "Seconds"))
        if (mode = "temperature") {
            target := DashboardRemote.cooldown["targetC"]
            temperature := DashboardRemote.CpuTemperature()
            if (temperature != "")
                current := temperature
        }
        return Map("phase", phase, "mode", mode, "resumeAutomatically", DashboardRemote.cooldown["resumeAutomatically"] ? JSON.true : JSON.false
            , "remainingSeconds", remaining, "targetC", target, "currentC", current)
    }

    static CpuTemperature() {
        health := DashboardHealth.Read(), hottest := ""
        if (health is Map) && health.Has("temperatures") && (health["temperatures"] is Array)
            for sensor in health["temperatures"]
                if ((sensor is Map) && sensor.Has("label") && RegExMatch(sensor["label"], "i)CPU Package|CPU Core")
                    && sensor.Has("celsius") && (sensor["celsius"] is Number) && sensor["celsius"] >= 0 && sensor["celsius"] < 130)
                    hottest := hottest = "" ? sensor["celsius"] : Max(hottest, sensor["celsius"])
        return hottest
    }

    static MatchRunning() {
        global RunningStrategy, StateFile
        ; Connections restore before the legacy autorun branch on launch.
        return RunningStrategy || IniRead(StateFile, "State", "Running", "0") = "1"
    }

    static Tick(*) {
        if !Dashboard.token
            return
        if IsObject(DashboardRemote.pending) {
            response := Dashboard.transport.Check(DashboardRemote.pending)
            if !IsObject(response) {
                SetTimer(DashboardRemote.pollTimer, -100)
                return
            }
            kind := DashboardRemote.pending.kind
            DashboardRemote.pending := ""
            if (response.status = 401) {
                Dashboard.Forget(true)
                return
            }
            if (kind = "result") {
                ; A 409 means the server already completed/expired the command
                ; (for example, its successful reply was lost). Never let that
                ; acknowledgement stall every later dashboard command.
                if ((response.status >= 200 && response.status < 300) || response.status = 409 || response.status = 400) {
                    DashboardRemote.resultBody := "", DashboardRemote.retries := 0
                    action := DashboardRemote.runAction, DashboardRemote.runAction := ""
                    ; StopStrategy reloads the macro. Finish its acknowledgement
                    ; first so the browser is not left waiting for a dead client.
                    if (response.status != 400 && action != "")
                        SetTimer(action = "start" ? ObjBindMethod(DashboardRemote, "StartFromRemote") : StopStrategy, -1)
                } else {
                    DashboardRemote.retries++
                    SetTimer(DashboardRemote.pollTimer, -Min(30000, 1000 * 2 ** Min(5, DashboardRemote.retries)))
                    return
                }
            } else if (kind = "poll") {
                if (response.status >= 200 && response.status < 300) {
                    try {
                        result := JSON.parse(response.text)
                        if ((result is Map) && result.Has("commands") && (result["commands"] is Array))
                            for command in result["commands"] {
                                if DashboardRemote.commandQueue.Length >= 25
                                    break
                                DashboardRemote.commandQueue.Push(command)
                            }
                    }
                }
            }
            SetTimer(DashboardRemote.pollTimer, response.status >= 200 && response.status < 300 ? -250 : -5000)
            return
        }

        if (DashboardRemote.resultBody != "") {
            DashboardRemote.SendResult()
            return
        }
        if (DashboardRemote.commandQueue.Length) {
            command := DashboardRemote.commandQueue.RemoveAt(1)
            DashboardRemote.Execute(command)
            return
        }

        headers := DashboardRemote.Headers()
        try {
            request := Dashboard.transport.Begin("POST", Dashboard.origin Dashboard.PREFIX "remote/commands/poll", headers, "{}", 8000)
            request.kind := "poll"
            DashboardRemote.pending := request
            SetTimer(DashboardRemote.pollTimer, -100)
        } catch {
            SetTimer(DashboardRemote.pollTimer, -5000)
        }
    }

    static Headers() => Map("Accept", "application/json", "Content-Type", "application/json; charset=utf-8"
        , "Authorization", "Bearer " Dashboard.token)

    static Execute(command) {
        global RunningStrategy
        if !(command is Map) || !command.Has("id") || !RegExMatch(command["id"], "i)^[a-f0-9-]{36}$") || !command.Has("action") {
            SetTimer(DashboardRemote.pollTimer, -100)
            return
        }
        action := command["action"], payload := command.Has("payload") && (command["payload"] is Map) ? command["payload"] : Map()
        accepted := false, message := "This action is not supported by this version."
        data := JSON.null

        switch action {
            case "start", "stop":
                accepted := DashboardRemote.QueueRunAction(action)
                message := accepted ? (action = "start" ? "Start requested." : "Stop requested.") : "The macro cannot run that action in its current state."
            case "pause", "resume":
                message := "Pause and resume are not available in this macro version."
            case "stop_after_match":
                if (RunningStrategy && !DashboardRemote.stopAfterMatch && DashboardMatch.SetStop(true)) {
                    DashboardRemote.stopAfterMatch := true
                    Dashboard.Beat()
                    accepted := true
                }
                message := accepted ? "The macro will stop after this match." : "The macro is not in a running match."
            case "cancel_stop_after_match":
                if (DashboardRemote.stopAfterMatch && DashboardMatch.SetStop(false)) {
                    DashboardRemote.stopAfterMatch := false
                    if (DashboardRemote.cooldown["phase"] = "waiting_for_match")
                        DashboardRemote.CancelCooldown(false)
                    Dashboard.Beat()
                    accepted := true
                }
                message := accepted ? "The safe stop was cancelled." : "There is no safe stop waiting."
            case "start_cooldown":
                accepted := DashboardRemote.StartCooldown(payload)
                message := accepted ? "Cooldown started." : "Cooldown could not start. Check the timer or CPU sensor and try again."
            case "cancel_cooldown":
                accepted := DashboardRemote.cooldown["phase"] != "idle"
                if accepted
                    DashboardRemote.CancelCooldown()
                message := accepted ? "Cooldown cancelled." : "There is no cooldown to cancel."
            case "close_selected_process":
                accepted := DashboardHealth.CloseSelected(payload)
                message := accepted ? "Close request sent to the selected app." : "That app is no longer available to close safely."
            case "select_strategy_1":
                accepted := DashboardRemote.SelectStrategy(payload)
                queuedForRestart := IsObject(payload) && payload.Has("applyWhen") && payload["applyWhen"] = "next_restart"
                message := !accepted ? "That strategy is not available on this PC." : queuedForRestart ? "Strategy will switch after the macro restarts." : "Strategy selected for the next run."
            case "select_strategy_2":
                message := "This macro version uses one strategy at a time."
            case "read_strategy_2":
                message := "This macro version uses one strategy at a time."
            case "read_strategy_1":
                data := DashboardRemote.ReadStrategy(payload)
                accepted := IsObject(data) && data != JSON.null
                message := accepted ? "Strategy loaded from the PC." : "The strategy file could not be read."
            case "stage_strategy_edit":
                accepted := DashboardRemote.SaveStrategy(payload)
                message := accepted ? "Saved to the strategy file. It will load for the next game." : "Could not save. Load the strategy from the PC and try again."
            case "install_library_strategy":
                accepted := DashboardRemote.InstallLibraryStrategy(payload)
                message := accepted ? "Added to this PC's Strategies folder." : "Could not add that strategy to this PC."
        }

        status := accepted ? "succeeded" : "failed"
        result := Map("id", command["id"], "status", status, "message", SubStr(message, 1, 120))
        if (accepted && IsObject(data) && data != JSON.null)
            result["data"] := data
        DashboardRemote.resultBody := JSON.stringify(result, 0, "")
        DashboardRemote.SendResult()
    }

    static SendResult() {
        try {
            request := Dashboard.transport.Begin("POST", Dashboard.origin Dashboard.PREFIX "remote/commands/result"
                , DashboardRemote.Headers(), DashboardRemote.resultBody, 10000)
            request.kind := "result"
            DashboardRemote.pending := request
        } catch {
            DashboardRemote.pending := ""
        }
        SetTimer(DashboardRemote.pollTimer, -250)
    }

    static StartFromRemote(*) {
        ; Only the informational towers prompt gets a short timeout. All normal
        ; start guards and first-run instructions still belong to StartStrategy.
        DashboardRemote.remoteStartPrompt := true
        try StartStrategy()
        finally DashboardRemote.remoteStartPrompt := false
    }

    static QueueRunAction(action) {
        global RunningStrategy, Recording, MacroRecording, RestartLock, Strategy1Path, StateFile
        if (action = "start") {
            if (RunningStrategy || Recording || MacroRecording || RestartLock || !FileExist(Strategy1Path)
                || !StrategyRotationValid()
                || IniRead(StateFile, "State", "IsFirstLaunch", "1") = "1")
                return false
            DashboardRemote.runAction := "start"
            return true
        }
        if (!RunningStrategy || RestartLock)
            return false
        DashboardRemote.runAction := "stop"
        return true
    }

    static ResolveStrategy(id) {
        if (!(id is String) || StrLen(id) > 180 || InStr(id, "\") || InStr(id, "/") || InStr(id, ":")
            || !RegExMatch(id, "i)\A[^\x00-\x1f]+\.strat\z"))
            return ""
        base := A_ScriptDir "\Strategies\"
        path := base id
        if (!FileExist(path) || InStr(FileExist(path), "D"))
            return ""
        return path
    }

    static InstallLibraryStrategy(payload) {
        if (!payload.Has("fileName") || !payload.Has("strategyText") || !(payload["fileName"] is String)
            || !(payload["strategyText"] is String) || StrPut(payload["strategyText"], "UTF-8") > 2 * 1024 * 1024 + 1)
            return false

        fileName := RegExReplace(payload["fileName"], "[<>:`"/\\|?*\x00-\x1f]", "")
        fileName := Trim(fileName, " .")
        if (fileName = "" || !RegExMatch(fileName, "i)\.strat\z"))
            return false
        SplitPath(fileName, , , , &stem)
        if (StrLen(fileName) > 180)
            fileName := SubStr(stem, 1, 174) ".strat"

        SplitPath(fileName, , , , &stem)
        if RegExMatch(stem, "i)\A(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\z")
            fileName := "Strategy - " fileName

        folder := A_ScriptDir "\Strategies"
        path := folder "\" fileName
        try {
            if FileExist(path) {
                if (FileGetSize(path) <= 2 * 1024 * 1024 && FileRead(path, "UTF-8") == payload["strategyText"]) {
                    Dashboard.Beat()
                    return true
                }
                Loop 999 {
                    candidate := folder "\" stem " (" (A_Index + 1) ").strat"
                    if !FileExist(candidate) {
                        path := candidate
                        break
                    }
                    if (FileGetSize(candidate) <= 2 * 1024 * 1024 && FileRead(candidate, "UTF-8") == payload["strategyText"]) {
                        Dashboard.Beat()
                        return true
                    }
                    if (A_Index = 999)
                        return false
                }
            }
            AtomicWrite(path, payload["strategyText"])
            Dashboard.Beat()
            return true
        } catch {
            return false
        }
    }

    static SelectStrategy(payload) {
        global Strategy1Path, Strategy1Ctrl, SettingsFile, RunningStrategy
        if (!IsObject(payload) || !payload.Has("strategyId"))
            return false
        path := DashboardRemote.ResolveStrategy(payload["strategyId"])
        if !path
            return false
        applyWhen := payload.Has("applyWhen") ? payload["applyWhen"] : "next_run"
        if (applyWhen = "next_restart") {
            IniWrite(payload["strategyId"], SettingsFile, "Dashboard", "PendingStrategy")
            return true
        }
        if (applyWhen != "next_run" || RunningStrategy)
            return false
        Strategy1Path := path
        Strategy1Ctrl.Value := path
        IniWrite(path, SettingsFile, "Options", "Strategy1")
        try {
            LoadStrategyFile(path)
        } catch {
            return false
        }
        Dashboard.Beat()
        return true
    }

    static ApplyPendingStrategy() {
        global Strategy1Path, Strategy1Ctrl, SettingsFile
        id := IniRead(SettingsFile, "Dashboard", "PendingStrategy", "")
        if (id = "")
            return
        path := DashboardRemote.ResolveStrategy(id)
        IniDelete(SettingsFile, "Dashboard", "PendingStrategy")
        if !path
            return
        Strategy1Path := path
        Strategy1Ctrl.Value := path
        IniWrite(path, SettingsFile, "Options", "Strategy1")
        try LoadStrategyFile(path)
    }

    static ReadStrategy(payload) {
        global Strategy1Path
        if !payload.Has("strategyId") && Strategy1Path != "" {
            SplitPath(Strategy1Path, &selectedId)
            payload := Map("strategyId", selectedId)
        }
        if !payload.Has("strategyId")
            return JSON.null
        path := DashboardRemote.ResolveStrategy(payload["strategyId"])
        if !path
            return JSON.null
        try {
            size := FileGetSize(path)
            if (size > 2 * 1024 * 1024)
                return JSON.null
            SplitPath(path, , , , &name)
            name := Dashboard.SafeLabel(IniRead(path, "Settings", "title", name), 80)
            return Map("strategyId", payload["strategyId"], "name", name
                , "strategyText", FileRead(path, "UTF-8"), "modified", FileGetTime(path, "M"), "size", size)
        } catch {
            return JSON.null
        }
    }

    static SaveStrategy(payload) {
        global RunningStrategy, Strategy1Path
        if !payload.Has("strategyId") && payload.Has("slot") && payload["slot"] = 1 && Strategy1Path != "" {
            payload := payload.Clone()
            SplitPath(Strategy1Path, &selectedId)
            payload["strategyId"] := selectedId
        }
        if (!payload.Has("strategyId") || !payload.Has("strategyText") || !payload.Has("baseModified") || !payload.Has("baseSize")
            || !(payload["strategyText"] is String) || StrPut(payload["strategyText"], "UTF-8") > 2 * 1024 * 1024 + 1)
            return false
        path := DashboardRemote.ResolveStrategy(payload["strategyId"])
        if !path
            return false
        try {
            if (FileGetTime(path, "M") != payload["baseModified"] || FileGetSize(path) != payload["baseSize"])
                return false
            oldCritical := A_IsCritical
            Critical("On")
            try AtomicWrite(path, payload["strategyText"])
            finally Critical(oldCritical)
            if (StrLower(path) = StrLower(Strategy1Path) && !RunningStrategy)
                LoadStrategyFile(path)
            Dashboard.Beat()
            return true
        } catch {
            return false
        }
    }
}
