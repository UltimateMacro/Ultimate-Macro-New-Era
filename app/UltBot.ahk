; Official UltBot control, separate from both the legacy engine and Dashboard.
; Only a locally approved ULT1 code for the first-party relay can enable it.
class UltBot {
    static ORIGIN := "https://remote.ultmacro.xyz"
    static VAULT := "Ultimate Macro 1.4 UltBot v1: https://remote.ultmacro.xyz"
    static UUID := "\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z"
    static path := "", version := "", transport := Http, handler := "", onChange := ""
    static token := "", install := "", allowStart := false, allowScreenshot := false, pending := "", timer := ""
    static captureProvider := ShotClient, shot := ""
    static state := "disconnected", message := "Not linked to UltBot."
    static due := 0, backoff := 2000, generation := 0
    static CanLink => UltBot.path != "" && UltBot.token = "" && !IsObject(UltBot.pending)
    static CanUnlink => UltBot.token != ""

    static Init(root, version, handler, transport := Http, captureProvider := ShotClient) {
        UltBot.Stop()
        UltBot.path := root "\ultbot.dpapi", UltBot.version := version
        UltBot.transport := transport, UltBot.handler := handler, UltBot.backoff := 2000, UltBot.captureProvider := captureProvider
        try {
            text := PairingVault.Read(UltBot.path, UltBot.VAULT)
            if (text = "") {
                UltBot.SetState("disconnected", "Not linked to UltBot.")
                return
            }
            link := JSON.parse(text)
            if !(link is Map) || !UltBot.ValidToken(link.Get("token", ""))
                || !RegExMatch(link.Get("install", ""), UltBot.UUID)
                throw ValueError()
            UltBot.token := link["token"], UltBot.install := link["install"]
            UltBot.allowStart := link.Get("allowStart", 0) == 1
            UltBot.allowScreenshot := link.Get("allowScreenshot", 0) == 1
            UltBot.SetState("connecting", "Link saved. Checking UltBot connection…")
        } catch {
            UltBot.SetState("disconnected", "Couldn't read the saved UltBot link. Pair again.")
        }
    }

    static Restore() {
        if UltBot.token {
            UltBot.due := A_TickCount
            UltBot.Wake()
        }
    }

    static Stop(*) {
        UltBot.Cancel()
        UltBot.token := "", UltBot.install := "", UltBot.allowStart := false, UltBot.allowScreenshot := false
        UltBot.onChange := ""
    }

    static Cancel() {
        UltBot.generation += 1
        if UltBot.timer
            SetTimer(UltBot.timer, 0)
        old := UltBot.pending, UltBot.pending := ""
        if IsObject(old) && IsObject(old.handle)
            try old.handle.req.Abort()
        if IsObject(UltBot.shot) {
            oldShot := UltBot.shot, UltBot.shot := ""
            UltBot.captureProvider.Cancel(oldShot.task)
        }
    }

    static SetState(state, message) {
        UltBot.state := state, UltBot.message := message
        if UltBot.onChange
            try UltBot.onChange.Call()
    }

    static Code(value) {
        value := Trim(value, " `t`r`n")
        if !RegExMatch(value, "i)\AULT1\.([A-Za-z0-9_-]{12,100})\.([A-HJ-NP-Z2-9]{10})\z", &part)
            return ""
        encoded := StrReplace(StrReplace(part[1], "-", "+"), "_", "/")
        while Mod(StrLen(encoded), 4)
            encoded .= "="
        size := 0
        if !DllCall("crypt32\CryptStringToBinaryW", "WStr", encoded, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0)
            return ""
        bytes := Buffer(size + 1, 0)
        if !DllCall("crypt32\CryptStringToBinaryW", "WStr", encoded, "UInt", 0, "UInt", 1, "Ptr", bytes, "UInt*", &size, "Ptr", 0, "Ptr", 0)
            return ""
        relay := StrGet(bytes, size, "UTF-8")
        if (StrLen(relay) != size || !RegExMatch(relay, "i)\Ahttps://remote\.ultmacro\.xyz/?\z"))
            return ""
        return StrUpper(SubStr(part[2], 1, 5) "-" SubStr(part[2], 6))
    }

    static Guid() {
        id := Buffer(16), text := Buffer(39 * 2, 0)
        if DllCall("ole32\CoCreateGuid", "Ptr", id, "Int")
            throw Error("Couldn't create an installation ID.")
        if !DllCall("ole32\StringFromGUID2", "Ptr", id, "Ptr", text, "Int", 39, "Int")
            throw Error("Couldn't format the installation ID.")
        return StrLower(SubStr(StrGet(text, "UTF-16"), 2, 36))
    }

    static ValidToken(t) => (t is String) && RegExMatch(t, "\A[A-Za-z0-9_-]{43}\z")

    static Link(value, allowStart := false, allowScreenshot := false) {
        if !UltBot.CanLink
            return false
        code := UltBot.Code(value)
        if !code {
            UltBot.SetState("disconnected", "Paste a private /remote link code from the official ULT Bot.")
            return false
        }
        try UltBot.install := UltBot.Guid()
        catch {
            UltBot.SetState("disconnected", "Windows couldn't create the link. Try again.")
            return false
        }
        UltBot.allowStart := !!allowStart
        UltBot.allowScreenshot := !!allowScreenshot
        UltBot.Request("link", JSON.stringify(Map("code", code, "deviceName", "Windows PC"
            , "clientVersion", UltBot.version, "installId", UltBot.install), 0, ""))
        UltBot.SetState("connecting", "Linking with UltBot…")
        return true
    }

    static Save() => PairingVault.Save(UltBot.path, UltBot.VAULT, JSON.stringify(
        Map("token", UltBot.token, "install", UltBot.install, "allowStart", UltBot.allowStart
            , "allowScreenshot", UltBot.allowScreenshot), 0, ""))

    static SetAllowStart(value) {
        if !UltBot.token
            return
        UltBot.allowStart := !!value
        try UltBot.Save()
        catch {
            UltBot.Unlink()
        }
    }

    static SetAllowScreenshot(value) {
        if !UltBot.token
            return
        UltBot.allowScreenshot := !!value
        if !value && IsObject(UltBot.shot) {
            shot := UltBot.shot, UltBot.shot := ""
            UltBot.captureProvider.Cancel(shot.task)
            UltBot.Complete(shot.job, Map("error", "Local screenshot permission was turned off."))
        }
        try UltBot.Save()
        catch
            UltBot.Unlink()
    }

    static Forget() {
        UltBot.token := "", UltBot.install := "", UltBot.allowStart := false, UltBot.allowScreenshot := false
        try {
            PairingVault.Forget(UltBot.path)
            return true
        } catch {
            return false
        }
    }

    static Unlink() {
        if !UltBot.token
            return
        UltBot.Cancel() ; Cancels polling and any acknowledged-but-not-run action.
        token := UltBot.token, id := UltBot.install, erased := UltBot.Forget()
        UltBot.Request("unlink", "{}", "", 0, token, id, erased)
        UltBot.SetState("connecting", "Disconnecting from UltBot…")
    }

    static Wake() {
        if !UltBot.timer
            UltBot.timer := ObjBindMethod(UltBot, "Pump")
        SetTimer(UltBot.timer, 200)
    }

    static Request(kind, body := "", action := "", expiry := 0, token := UltBot.token, id := UltBot.install, erased := true) {
        handle := ""
        try {
            headers := Map("Accept", "application/json", "Content-Type", "application/json; charset=utf-8"
                , "X-ULT-Version", UltBot.version, "X-ULT-Install-ID", id)
            if token
                headers["Authorization"] := "Bearer " token
            handle := UltBot.transport.Begin(kind = "poll" ? "GET" : "POST", UltBot.ORIGIN "/v1/remote/" kind
                , headers, body, kind = "poll" ? 35000 : 10000)
        }
        UltBot.pending := {kind: kind, handle: handle, action: action, expiry: expiry, erased: erased}
        UltBot.Wake()
    }

    static Retry(status := 0) {
        UltBot.due := A_TickCount + (status = 429 ? Max(15000, UltBot.backoff) : UltBot.backoff)
        UltBot.backoff := Min(60000, 2 * UltBot.backoff)
        UltBot.SetState("offline", "UltBot is offline or busy. The link is saved; retrying.")
    }

    static Pump(*) {
        if IsObject(UltBot.shot) {
            shot := UltBot.shot
            reply := UltBot.captureProvider.Poll(shot.task)
            if !IsObject(reply)
                return
            if shot != UltBot.shot
                return
            UltBot.shot := ""
            if !UltBot.token || shot.generation != UltBot.generation
                return
            if !UltBot.allowScreenshot || shot.job["expires_at"] <= UltBot.Now()
                reply := Map("error", "The screenshot request expired or local permission was removed.")
            UltBot.Complete(shot.job, reply)
            return
        }
        item := UltBot.pending
        if !IsObject(item) {
            wasCritical := A_IsCritical
            Critical("On")
            try {
                if !IsObject(UltBot.pending) && UltBot.token && A_TickCount >= UltBot.due
                    UltBot.Request("poll")
            } finally Critical(wasCritical ? wasCritical : "Off")
            return
        }
        r := {status: 0, text: ""}
        if IsObject(item.handle)
            try r := UltBot.transport.Check(item.handle)
        if !IsObject(r)
            return
        wasCritical := A_IsCritical
        Critical("On")
        try {
            if (item != UltBot.pending)
                return
            UltBot.pending := ""
            UltBot.Handle(item, r)
        } catch {
            if UltBot.token
                UltBot.Retry()
            else
                UltBot.SetState("disconnected", "UltBot couldn't confirm the request. Try again.")
        } finally {
            if !UltBot.token && !IsObject(UltBot.pending)
                SetTimer(UltBot.timer, 0)
            Critical(wasCritical ? wasCritical : "Off")
        }
    }

    static Handle(item, r) {
        switch item.kind {
            case "link": UltBot.Linked(r)
            case "unlink":
                ok := r.status = 200 || r.status = 401
                UltBot.SetState("disconnected", ok && item.erased ? "Disconnected from UltBot."
                    : "Local control stopped. If it still shows linked, run /remote unlink in Discord.")
            default:
                if (r.status = 401 || r.status = 403) {
                    UltBot.Forget()
                    UltBot.SetState("expired", "UltBot link expired, was revoked, or isn't allowed for this build. Pair again if eligible.")
                    return
                }
                if (r.status != 200 && !(item.kind = "result" && r.status = 409)) {
                    UltBot.Retry(r.status)
                    return
                }
                UltBot.backoff := 2000, UltBot.due := A_TickCount + 400
                UltBot.SetState("connected", "Connected to UltBot.")
                if (item.kind = "poll")
                    UltBot.Polled(r.text)
                else if r.status = 200 && item.action {
                    reply := JSON.parse(r.text)
                    if (reply is Map) && reply.Get("ok", 0) == 1 {
                        generation := UltBot.generation
                        SetTimer(() => UltBot.Dispatch(item, generation), -1)
                    }
                }
        }
    }

    static Linked(r) {
        if (r.status != 200) {
            UltBot.install := "", UltBot.allowStart := false, UltBot.allowScreenshot := false
            switch r.status {
                case 401, 410: UltBot.SetState("expired", "Code expired, invalid, or already used. Run /remote link again.")
                case 403: UltBot.SetState("disconnected", "UltBot denied access. This local build requires prerelease access.")
                case 429: UltBot.SetState("disconnected", "Too many attempts. Wait before trying another code.")
                default: UltBot.SetState("offline", "Couldn't reach UltBot. Check your connection and try a new code.")
            }
            return
        }
        link := JSON.parse(r.text)
        if !(link is Map) || !UltBot.ValidToken(link.Get("token", "")) {
            UltBot.SetState("disconnected", "UltBot returned an invalid link response. Generate a new code.")
            return
        }
        UltBot.token := link["token"]
        try UltBot.Save()
        catch {
            UltBot.Unlink()
            UltBot.SetState("connecting", "Couldn't save the credential. Revoking the new link…")
            return
        }
        UltBot.Restore()
        UltBot.SetState("connecting", "Linked. Checking UltBot connection…")
    }

    static Now() => DateDiff(A_NowUTC, "19700101000000", "Seconds")

    static Polled(text) {
        response := JSON.parse(text)
        if !(response is Map) || !response.Has("job")
            throw ValueError()
        rotated := response.Get("rotateToken", "")
        if rotated {
            if !UltBot.ValidToken(rotated)
                throw ValueError()
            UltBot.token := rotated
            try UltBot.Save()
            catch {
                UltBot.Unlink()
                return
            }
        }
        job := response["job"]
        if !IsObject(job)
            return
        if !(job is Map) || !(job.Get("id", "") is String) || !RegExMatch(job["id"], UltBot.UUID)
            return
        op := job.Get("command", ""), expiry := job.Get("expires_at", 0), action := ""
        if !(expiry is Integer) || expiry <= UltBot.Now()
            reply := Map("error", "The request expired. Try again.")
        else if (op == "start" && !UltBot.allowStart)
            reply := Map("error", "Enable Allow remote Start in the macro's Discord tab.")
        else if (op == "screenshot") {
            if !UltBot.allowScreenshot
                reply := Map("error", "Enable requested Roblox screenshots in the macro's Discord tab first.")
            else {
                try {
                    task := UltBot.captureProvider.Start()
                    UltBot.shot := {task: task, job: job, generation: UltBot.generation}
                    return
                } catch
                    reply := Map("error", "The Roblox capture helper couldn't start.")
            }
        }
        else if (op == "status" || op == "stop" || op == "start") {
            try reply := UltBot.handler.Call(op, false)
            catch
                reply := Map("error", "The macro could not accept the request.")
            if !reply.Has("error") && op != "status"
                action := op
        } else
            reply := Map("error", "Unsupported remote command.")
        UltBot.Complete(job, reply, action)
    }

    static Complete(job, reply, action := "") {
        result := reply.Has("imageBase64") ? Map("message", "Requested Roblox screenshot.") : reply
        payload := Map("jobId", job["id"], "ok", result.Has("error") ? JSON.false : JSON.true, "result", result)
        if reply.Has("imageBase64") {
            payload["imageBase64"] := reply["imageBase64"]
            payload["mime"] := "image/png"
        }
        UltBot.Request("result", JSON.stringify(payload, 0, ""), action, job["expires_at"])
    }

    static Dispatch(item, generation) {
        if generation != UltBot.generation || !UltBot.token || item.expiry <= UltBot.Now()
            || (item.action = "start" && !UltBot.allowStart)
            return
        ; A separate AHK timer thread is essential: legacy Start owns its
        ; thread until gameplay ends, and legacy Stop reloads the whole app.
        try UltBot.handler.Call(item.action, true)
    }
}
