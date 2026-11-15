; Paired dashboard: presence/activity and authenticated, user-requested controls.
class Dashboard {
    static RELEASE_ORIGIN := "https://ultmacro.xyz"
    static PREFIX := "/api/dashboard/v1/"
    static HEARTBEAT_MS := 20000
    static REQUEST_MS := 35000
    static origin := "", file := "", version := "", token := "", transport := Http
    static pending := "", pumpTimer := "", beatTimer := "", onChange := ""
    static state := "disconnected", message := "Disconnected."

    static ResolveOrigin(development := "") {
        if (development = "")
            return Dashboard.RELEASE_ORIGIN
        ; This argument comes only from an intentionally added, unshipped AHK
        ; source include. Plain HTTP is allowed only for the local test server.
        if (development == "http://127.0.0.1:4174"
            || RegExMatch(development, "i)\Ahttps://[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+(?:\:[0-9]{1,5})?\z"))
            return StrLower(development)
        return ""
    }

    static Init(root, version, development := "", transport := Http) {
        Dashboard.Stop()
        Dashboard.transport := transport, Dashboard.version := version
        Dashboard.origin := Dashboard.ResolveOrigin(development)
        Dashboard.file := root (development = "" ? "\dashboard.dpapi" : "\dashboard-dev.dpapi")
        if !Dashboard.origin {
            Dashboard.SetState("offline", "Offline. The development dashboard address is not allowed.")
            return
        }
        try Dashboard.token := Dashboard.ReadToken()
        catch {
            Dashboard.SetState("disconnected", "Disconnected. The saved link could not be read; pair again.")
            return
        }
        if Dashboard.token
            Dashboard.SetState("connecting", "Connecting to the dashboard…")
        else
            Dashboard.SetState("disconnected", "Disconnected.")
    }

    static Restore() {
        if Dashboard.token {
            DashboardHealth.Start()
            Dashboard.Beat()
        }
    }

    static Stop(*) {
        Dashboard.CancelTimers()
        DashboardHealth.Stop()
        Dashboard.token := "", Dashboard.onChange := ""
    }

    static CancelTimers() {
        if Dashboard.pumpTimer
            SetTimer(Dashboard.pumpTimer, 0)
        if Dashboard.beatTimer
            SetTimer(Dashboard.beatTimer, 0)
        old := Dashboard.pending, Dashboard.pending := ""
        if (IsObject(old) && IsObject(old.handle))
            try old.handle.req.Abort()
    }

    static SetState(state, message) {
        Dashboard.state := state, Dashboard.message := message
        if Dashboard.onChange
            try Dashboard.onChange.Call()
    }

    static CanConnect => Dashboard.origin != "" && !Dashboard.token && !IsObject(Dashboard.pending)
    static CanDisconnect => Dashboard.token != "" && (!IsObject(Dashboard.pending) || Dashboard.pending.kind = "heartbeat")

    static NormalizeCode(value) {
        value := Trim(value, " `t")
        return RegExMatch(value, "i)\A[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}\z") ? StrUpper(value) : ""
    }

    static Connect(value) {
        if !Dashboard.CanConnect
            return false
        code := Dashboard.NormalizeCode(value)
        if !code {
            Dashboard.SetState("disconnected", "Enter the dashboard code in XXXX-XXXX format.")
            return false
        }
        body := JSON.stringify(Map("code", code, "deviceName", "This PC", "appVersion", Dashboard.version), 0, "")
        Dashboard.Request("claim", "pairing/claim", body)
        Dashboard.SetState("connecting", "Connecting to the dashboard…")
        return true
    }

    static Disconnect() {
        if !Dashboard.CanDisconnect
            return false
        DashboardRemote.Stop()
        DashboardActivity.Stop()
        Dashboard.CancelTimers() ; a stale heartbeat cannot overwrite this result
        Dashboard.Request("disconnect", "device/disconnect", "{}", Dashboard.token)
        Dashboard.SetState("connecting", "Disconnecting from the dashboard…")
        return true
    }

    static Beat(*) {
        if (!Dashboard.token || IsObject(Dashboard.pending))
            return
        body := JSON.stringify(Map("appVersion", Dashboard.version, "snapshot", Dashboard.Snapshot()), 0, "")
        Dashboard.Request("heartbeat", "heartbeat", body, Dashboard.token)
    }

    static Snapshot() {
        global RunningStrategy, Strategy1Path, gamemap, difficulty
        health := DashboardHealth.Read()
        selectedPath := Trim(Strategy1Path)
        selectedName := ""
        if (selectedPath != "" && FileExist(selectedPath) && !InStr(FileExist(selectedPath), "D")) {
            SplitPath(selectedPath, , , , &selectedName)
            selectedName := Dashboard.SafeLabel(IniRead(selectedPath, "Settings", "title", selectedName), 80)
        }
        slots := []
        if (selectedName != "")
            slots.Push(Map("slot", 1, "name", selectedName))

        available := [], seen := Map()
        Loop Files, A_ScriptDir "\Strategies\*.strat", "F" {
            if (available.Length >= 200)
                break
            try {
                size := FileGetSize(A_LoopFileFullPath)
                if (size > 2 * 1024 * 1024)
                    continue
                id := A_LoopFileName
                if seen.Has(StrLower(id))
                    continue
                seen[StrLower(id)] := true
                name := Dashboard.SafeLabel(IniRead(A_LoopFileFullPath, "Settings", "title", A_LoopFileName), 80)
                available.Push(Map("id", id, "name", name, "modified", FileGetTime(A_LoopFileFullPath, "M"), "size", size))
            }
        }
        capabilities := ["strategy_library_install", "safe_match_stop", "cooldown_mode_v1"]
        if IsObject(health) && health != JSON.null
            capabilities.Push("device_health_v1", "process_close")
        return Map("runState", RunningStrategy ? "running" : "stopped"
            , "activeStrategy", selectedName != "" ? selectedName : JSON.null
            , "activeSlot", 1, "rotationEnabled", JSON.false
            , "stopAfterMatch", DashboardRemote.stopAfterMatch ? JSON.true : JSON.false
            , "cooldown", DashboardRemote.CooldownSnapshot()
            , "map", Dashboard.SafeLabel(gamemap, 64), "mode", Dashboard.SafeLabel(difficulty, 32)
            , "health", health
            , "strategySlots", slots, "availableStrategies", available
            , "capabilities", capabilities)
    }

    static SafeLabel(value, limit) => SubStr(Trim(RegExReplace(String(value), "[\r\n\x00]", " ")), 1, limit)

    static ScheduleBeat(started) {
        if !Dashboard.token
            return
        if !Dashboard.beatTimer
            Dashboard.beatTimer := ObjBindMethod(Dashboard, "Beat")
        delay := Min(Dashboard.HEARTBEAT_MS, Max(1000, Dashboard.HEARTBEAT_MS - (A_TickCount - started)))
        SetTimer(Dashboard.beatTimer, -delay)
    }

    static Request(kind, path, json, token := "") {
        handle := "", started := A_TickCount
        try {
            headers := Map("Accept", "application/json", "Content-Type", "application/json; charset=utf-8")
            if token
                headers["Authorization"] := "Bearer " token
            ; Reuse the async WinHTTP helper, which rejects redirects and uses
            ; normal Windows TLS/certificate validation. Never log responses.
            handle := Dashboard.transport.Begin("POST", Dashboard.origin Dashboard.PREFIX path, headers, json, 15000)
            handle.limit := Dashboard.REQUEST_MS
        }
        Dashboard.pending := {kind: kind, handle: handle, started: started}
        if !Dashboard.pumpTimer
            Dashboard.pumpTimer := ObjBindMethod(Dashboard, "Pump")
        SetTimer(Dashboard.pumpTimer, 200)
    }

    static Pump(*) {
        item := Dashboard.pending
        if !IsObject(item)
            return
        r := {status: 0, text: ""}
        if IsObject(item.handle)
            try r := Dashboard.transport.Check(item.handle)
        if !IsObject(r)
            return
        Critical("On")
        try {
            if (Dashboard.pending != item)
                return
            Dashboard.pending := ""
            switch item.kind {
                case "claim": Dashboard.Claimed(r)
                case "heartbeat": Dashboard.HeartbeatResult(r.status, item.started)
                case "disconnect": Dashboard.DisconnectResult(r.status, item.started)
                ; Best-effort cleanup of a claimed token that couldn't be saved.
                case "cleanup": Dashboard.SetState("disconnected", Dashboard.message)
            }
        } finally {
            ; A claim can immediately queue a heartbeat in this same timer.
            ; Keep its poller registered until that request has also finished.
            if !IsObject(Dashboard.pending)
                SetTimer(Dashboard.pumpTimer, 0)
            Critical("Off")
        }
    }

    static ValidToken(token) => (token is String) && StrLen(token) <= 1024
        && RegExMatch(token, "\A[A-Za-z0-9._~+/-]+={0,2}\z")

    static Claimed(r) {
        switch r.status {
            case 201:
                token := ""
                try {
                    if (StrLen(r.text) > 8192)
                        throw ValueError()
                    v := JSON.parse(r.text)
                    if (!(v is Map) || !v.Has("deviceId") || !(v["deviceId"] is String)
                        || StrLen(v["deviceId"]) < 1 || StrLen(v["deviceId"]) > 256
                        || !v.Has("deviceToken") || !Dashboard.ValidToken(v["deviceToken"])
                        || !v.Has("heartbeatSeconds") || !(v["heartbeatSeconds"] is Integer) || v["heartbeatSeconds"] < 1)
                        throw ValueError()
                    token := v["deviceToken"]
                } catch {
                    Dashboard.SetState("disconnected", "Disconnected. The dashboard returned an invalid response. Generate a new code and try again.")
                    return
                }
                try Dashboard.SaveToken(token)
                catch {
                    Dashboard.Request("cleanup", "device/disconnect", "{}", token)
                    Dashboard.SetState("disconnected", "Disconnected. Windows couldn't save the dashboard link. Try again with a new code.")
                    return
                }
                Dashboard.token := token
                ; Claiming does not mean online; the first heartbeat must succeed.
                Dashboard.Beat()
                Dashboard.SetState("connecting", "Paired. Confirming the connection…")
            case 400: Dashboard.SetState("disconnected", "The dashboard rejected the request. Check the code and try again.")
            case 410: Dashboard.SetState("expired", "Code expired, invalid, or already used. Generate a new code on the website.")
            case 429: Dashboard.SetState("disconnected", "Too many attempts. Wait a moment before trying again.")
            case 0: Dashboard.SetState("offline", "Couldn't reach the dashboard from this PC. Check its internet connection, then get a new code.")
            default: Dashboard.SetState("offline", "Dashboard couldn't confirm pairing (HTTP " r.status "). Try again with a new code.")
        }
    }

    static HeartbeatResult(status, started) {
        if (status = 401) {
            Dashboard.Forget(true)
            return
        }
        if (status >= 200 && status < 300)
            Dashboard.SetState("connected", "Connected to the dashboard.")
        else
            Dashboard.SetState("offline", "Offline. The link is saved; retrying automatically.")
        if (status >= 200 && status < 300) {
            DashboardHealth.Start()
            DashboardActivity.Start()
            DashboardRemote.Start()
        }
        Dashboard.ScheduleBeat(started)
    }

    static DisconnectResult(status, started) {
        if (status = 401 || (status >= 200 && status < 300)) {
            Dashboard.Forget(false)
            return
        }
        Dashboard.SetState("offline", "Offline. Couldn't disconnect; the link is still saved. Try again.")
        Dashboard.ScheduleBeat(started)
    }

    static Forget(expired) {
        Dashboard.CancelTimers()
        DashboardActivity.Clear()
        DashboardRemote.CancelCooldown(false)
        DashboardRemote.Stop()
        DashboardHealth.Stop()
        Dashboard.token := "", erased := true
        try {
            PairingVault.Forget(Dashboard.file)
        } catch {
            erased := false
        }
        if !erased
            Dashboard.SetState(expired ? "expired" : "disconnected", "The dashboard link is no longer valid, but Windows couldn't remove the saved credential. Pair again to replace it.")
        else if expired
            Dashboard.SetState("expired", "Dashboard connection expired or was revoked. Pair again.")
        else
            Dashboard.SetState("disconnected", "Disconnected.")
    }

    static VaultPurpose => "Ultimate Macro dashboard v1: " Dashboard.origin

    static SaveToken(token) => PairingVault.Save(Dashboard.file, Dashboard.VaultPurpose, token)

    static ReadToken() {
        token := PairingVault.Read(Dashboard.file, Dashboard.VaultPurpose)
        if (token != "" && !Dashboard.ValidToken(token))
            throw ValueError()
        return token
    }
}
