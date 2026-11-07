; Dashboard presence only. No game commands or links are accepted from responses.
class Dashboard {
    static RELEASE_ORIGIN := "https://ultmacro.xyz"
    static PREFIX := "/api/dashboard/v1/"
    static HEARTBEAT_MS := 20000
    static REQUEST_MS := 10000
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
        if Dashboard.token
            Dashboard.Beat()
    }

    static Stop(*) {
        Dashboard.CancelTimers()
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
        return RegExMatch(value, "\A[A-Za-z0-9]{4}-[A-Za-z0-9]{4}\z") ? StrUpper(value) : ""
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
        Dashboard.CancelTimers() ; a stale heartbeat cannot overwrite this result
        Dashboard.Request("disconnect", "device/disconnect", "{}", Dashboard.token)
        Dashboard.SetState("connecting", "Disconnecting from the dashboard…")
        return true
    }

    static Beat(*) {
        if (!Dashboard.token || IsObject(Dashboard.pending))
            return
        body := JSON.stringify(Map("appVersion", Dashboard.version), 0, "")
        Dashboard.Request("heartbeat", "heartbeat", body, Dashboard.token)
    }

    static ScheduleBeat(started) {
        if !Dashboard.token
            return
        if !Dashboard.beatTimer
            Dashboard.beatTimer := ObjBindMethod(Dashboard, "Beat")
        delay := Min(Dashboard.HEARTBEAT_MS, Max(1, Dashboard.HEARTBEAT_MS - (A_TickCount - started)))
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
            handle := Dashboard.transport.Begin("POST", Dashboard.origin Dashboard.PREFIX path, headers, json, 6000)
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
            default: Dashboard.SetState("offline", "Offline. Couldn't confirm pairing. Check your connection and try a new code.")
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
        Dashboard.token := "", erased := true
        try {
            if FileExist(Dashboard.file)
                FileDelete(Dashboard.file)
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

    static SaveToken(token) {
        raw := Dashboard.Utf8(token)
        try packed := Dashboard.Dpapi(raw, true)
        finally Dashboard.Wipe(raw)
        hex := ""
        Loop packed.Size
            hex .= Format("{:02X}", NumGet(packed, A_Index - 1, "UChar"))
        AtomicWrite(Dashboard.file, hex)
    }

    static ReadToken() {
        if !FileExist(Dashboard.file)
            return ""
        if (FileGetSize(Dashboard.file) > 8192)
            throw ValueError()
        hex := FileRead(Dashboard.file, "UTF-8")
        if (!RegExMatch(hex, "\A[0-9A-Fa-f]+\z") || Mod(StrLen(hex), 2))
            throw ValueError()
        packed := Buffer(StrLen(hex) // 2)
        Loop packed.Size
            NumPut("UChar", Integer("0x" SubStr(hex, A_Index * 2 - 1, 2)), packed, A_Index - 1)
        raw := Dashboard.Dpapi(packed, false)
        try {
            if (raw.Size < 2 || NumGet(raw, raw.Size - 1, "UChar") != 0)
                throw ValueError()
            token := StrGet(raw, raw.Size - 1, "UTF-8")
            if (!Dashboard.ValidToken(token) || StrLen(token) != raw.Size - 1)
                throw ValueError()
            return token
        } finally Dashboard.Wipe(raw)
    }

    static Utf8(value) {
        bytes := Buffer(StrPut(value, "UTF-8"))
        StrPut(value, bytes, "UTF-8")
        return bytes
    }

    static Blob(bytes) {
        blob := Buffer(2 * A_PtrSize, 0)
        NumPut("UInt", bytes.Size, blob)
        NumPut("Ptr", bytes.Ptr, blob, A_PtrSize)
        return blob
    }

    static Wipe(bytes) => DllCall("msvcrt\memset", "Ptr", bytes, "Int", 0, "UPtr", bytes.Size, "CDecl Ptr")

    static Dpapi(raw, protect) {
        ; No LOCAL_MACHINE flag: Windows seals this for the current user.
        ; Entropy binds it to this feature and exact origin (including dev).
        context := Dashboard.Utf8("Ultimate Macro dashboard v1: " Dashboard.origin)
        input := Dashboard.Blob(raw), entropy := Dashboard.Blob(context), output := Buffer(2 * A_PtrSize, 0)
        fn := protect ? "crypt32\CryptProtectData" : "crypt32\CryptUnprotectData"
        ok := DllCall(fn, "Ptr", input, "Ptr", 0, "Ptr", entropy, "Ptr", 0, "Ptr", 0, "UInt", 1, "Ptr", output, "Int")
        p := NumGet(output, A_PtrSize, "Ptr"), size := NumGet(output, 0, "UInt")
        try {
            if (!ok || !p || size < 1 || size > (protect ? 4096 : 1025))
                throw Error("Dashboard credential storage failed.")
            result := Buffer(size)
            DllCall("RtlMoveMemory", "Ptr", result, "Ptr", p, "UPtr", size)
            return result
        } finally {
            if p {
                if !protect
                    DllCall("msvcrt\memset", "Ptr", p, "Int", 0, "UPtr", size, "CDecl Ptr")
                DllCall("LocalFree", "Ptr", p, "Ptr")
            }
        }
    }
}
