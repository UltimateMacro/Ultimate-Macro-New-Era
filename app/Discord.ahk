; Optional, session-only Discord features (discord_webhook.py, discord_control.py,
; official_remote.py, economy.py). Nothing here is persisted; tokens and codes live
; in memory until disabled or the app closes. All requests are asynchronous.

class Http {
    static Begin(method, url, headers := "", body := "", receiveTimeout := 15000) {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open(method, url, true)
        req.Option[6] := false ; no redirects
        req.SetTimeouts(5000, 5000, 15000, receiveTimeout)
        if IsObject(headers)
            for k, v in headers
                req.SetRequestHeader(k, v)
        if (body = "")
            req.Send()
        else
            req.Send(body)
        return {req: req, started: A_TickCount, limit: receiveTimeout + 20000}
    }

    ; "" while pending; otherwise {status, text, headers} or {status: 0} on failure.
    static Check(h) {
        try {
            if !h.req.WaitForResponse(0) {
                if (A_TickCount - h.started > h.limit) {
                    try h.req.Abort()
                    return {status: 0, text: ""}
                }
                return ""
            }
            text := ""
            try text := h.req.ResponseText
            return {status: h.req.Status, text: SubStr(text, 1, 262144), req: h.req}
        } catch
            return {status: 0, text: ""}
    }

    static Bytes(text) {
        n := StrPut(text, "UTF-8") - 1
        arr := ComObjArray(0x11, n)
        if n {
            p := NumGet(ComObjValue(arr) + 8 + A_PtrSize, "Ptr")
            StrPut(text, p, n, "UTF-8")
        }
        return arr
    }

    ; multipart/form-data body with one JSON part and one PNG file.
    static Multipart(json, fileBytes, boundary) {
        head := "--" boundary "`r`nContent-Disposition: form-data; name=`"payload_json`"`r`nContent-Type: application/json`r`n`r`n" json
            . "`r`n--" boundary "`r`nContent-Disposition: form-data; name=`"files[0]`"; filename=`"roblox.png`"`r`nContent-Type: image/png`r`n`r`n"
        tail := "`r`n--" boundary "--`r`n"
        hn := StrPut(head, "UTF-8") - 1, tn := StrPut(tail, "UTF-8") - 1
        arr := ComObjArray(0x11, hn + fileBytes.Size + tn)
        p := NumGet(ComObjValue(arr) + 8 + A_PtrSize, "Ptr")
        StrPut(head, p, hn, "UTF-8")
        DllCall("RtlMoveMemory", "Ptr", p + hn, "Ptr", fileBytes, "UPtr", fileBytes.Size)
        StrPut(tail, p + hn + fileBytes.Size, tn, "UTF-8")
        return arr
    }

    static Base64(buf) {
        size := 0
        DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &size)
        out := Buffer(size * 2, 0)
        DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", out, "UInt*", &size)
        return StrGet(out, "UTF-16")
    }
}

; ---------------------------------------------------------------------------
class Webhook {
    static pumpBound := ""
    static PumpFn() => Webhook.pumpBound ? Webhook.pumpBound : (Webhook.pumpBound := ObjBindMethod(Webhook, "Pump"))
    static EVENTS := Map("test", "Ultimate Macro: notifications are connected.", "start", "Ultimate Macro: the macro started."
        , "match", "Ultimate Macro: a match finished.", "victory", "Ultimate Macro: match won.", "defeat", "Ultimate Macro: match lost."
        , "stopped", "Ultimate Macro: the macro stopped.", "error", "Ultimate Macro: the macro stopped; check the app for details.")
    static url := "", queue := [], inflight := "", last := 0, generation := 0, onResult := ""

    static Validate(value) {
        if (StrLen(value) < 1 || StrLen(value) > 512 || RegExMatch(value, "[\x00-\x20]"))
            throw ValueError("Enter a valid Discord webhook URL.")
        if !RegExMatch(value, "^https://(discord\.com|discordapp\.com|canary\.discord\.com|ptb\.discord\.com)/api(?:/v[0-9]{1,2})?/webhooks/[0-9]{17,20}/[A-Za-z0-9._-]{20,200}(?:\?thread_id=[0-9]{17,20})?$")
            throw ValueError("Enter a valid Discord webhook URL.")
        return value
    }

    static Configure(url) {
        Webhook.url := Webhook.Validate(url)
        Webhook.generation += 1, Webhook.queue := []
        SetTimer(Webhook.PumpFn(), 250)
    }

    static Disable() {
        Webhook.url := "", Webhook.queue := [], Webhook.generation += 1
    }

    static Submit(event) {
        if (Webhook.url = "" || !Webhook.EVENTS.Has(event) || Webhook.queue.Length >= 8)
            return false
        Webhook.queue.Push([Webhook.generation, event])
        return true
    }

    static Pump() {
        if IsObject(Webhook.inflight) {
            r := Http.Check(Webhook.inflight.h)
            if (r = "")
                return
            item := Webhook.inflight, Webhook.inflight := "", Webhook.last := A_TickCount
            if (item.gen = Webhook.generation && Webhook.onResult)
                Webhook.onResult.Call(item.event, r.status >= 200 && r.status < 300)
            return
        }
        if (Webhook.url = "") {
            SetTimer(Webhook.PumpFn(), 0)
            return
        }
        if (!Webhook.queue.Length || A_TickCount - Webhook.last < 2000)
            return
        item := Webhook.queue.RemoveAt(1)
        if (item[1] != Webhook.generation)
            return
        body := '{"content":"' Webhook.EVENTS[item[2]] '","allowed_mentions":{"parse":[]}}'
        try {
            h := Http.Begin("POST", Webhook.url, Map("Content-Type", "application/json", "User-Agent", "UltimateMacro/1.4"), Http.Bytes(body))
            Webhook.inflight := {h: h, gen: item[1], event: item[2]}
        } catch {
            if Webhook.onResult
                Webhook.onResult.Call(item[2], false)
        }
    }
}

; ---------------------------------------------------------------------------
; Opt-in personal bot STOP/STATUS (plus START/SCREENSHOT when allowed).
class BotRemote {
    static pumpBound := ""
    static PumpFn() => BotRemote.pumpBound ? BotRemote.pumpBound : (BotRemote.pumpBound := ObjBindMethod(BotRemote, "Pump"))
    static STOP_REPLY := "Ultimate Macro: stop requested. Check the app to confirm cleanup."
    static STOP_REFUSED := "Ultimate Macro: could not queue the stop request. Check the app."
    static START_REPLY := "Ultimate Macro: start requested. Check the app to confirm."
    static START_REFUSED := "Ultimate Macro: start unavailable. Select a strategy and open Roblox in the app."
    static SCREENSHOT_REPLY := "Ultimate Macro: Roblox client screenshot."
    static SCREENSHOT_REFUSED := "Ultimate Macro: screenshot unavailable. Keep Roblox foreground and unobscured."
    static token := "", owner := "", channel := "", enabled := false, generation := 0
    static ops := Map(), high := "0", baseline := false, inflight := "", replies := [], nextPoll := 0, waitUntil := 0
    static onCommand := "", onState := "", seen := Map()

    static Validate(token, owner, channel) {
        if !RegExMatch(token, "^[A-Za-z0-9._-]{40,256}$")
            throw ValueError("Enter your personal bot token, without the Bot prefix.")
        for v in [owner, channel]
            if !RegExMatch(v, "^[1-9][0-9]{16,19}$")
                throw ValueError("Enter a valid Discord user or channel ID.")
    }

    static Configure(token, owner, channel, allowStart, allowScreenshot) {
        BotRemote.Validate(token, owner, channel)
        BotRemote.token := token, BotRemote.owner := owner, BotRemote.channel := channel
        BotRemote.ops := Map("!stop", "stop", "!status", "status")
        if allowStart
            BotRemote.ops["!start"] := "start"
        if allowScreenshot
            BotRemote.ops["!screenshot"] := "screenshot"
        BotRemote.enabled := true, BotRemote.baseline := false, BotRemote.high := "0", BotRemote.replies := []
        BotRemote.generation += 1, BotRemote.nextPoll := 0, BotRemote.waitUntil := 0, BotRemote.inflight := "", BotRemote.seen := Map()
        SetTimer(BotRemote.PumpFn(), 250)
    }

    static Disable() {
        BotRemote.enabled := false, BotRemote.token := "", BotRemote.replies := [], BotRemote.generation += 1
        if IsObject(BotRemote.inflight)
            try BotRemote.inflight.h.req.Abort()
        BotRemote.inflight := ""
    }

    static State(s) {
        if (BotRemote.onState)
            BotRemote.onState.Call(BotRemote.generation, s)
    }

    static Headers(withJson := true) {
        h := Map("Authorization", "Bot " BotRemote.token, "User-Agent", "DiscordBot (https://ultmacro.xyz, 1.4)")
        if withJson
            h["Content-Type"] := "application/json"
        return h
    }

    static Root => "https://discord.com/api/v10/channels/" BotRemote.channel "/messages"

    static Reply(text, png := "") {
        if !BotRemote.enabled
            return
        BotRemote.replies.Push({text: text, png: png, expires: A_TickCount + 10000})
    }

    static Pump() {
        if !BotRemote.enabled {
            SetTimer(BotRemote.PumpFn(), 0)
            return
        }
        if IsObject(BotRemote.inflight) {
            r := Http.Check(BotRemote.inflight.h)
            if (r = "")
                return
            kind := BotRemote.inflight.kind, gen := BotRemote.inflight.gen
            BotRemote.inflight := ""
            if (gen != BotRemote.generation)
                return
            BotRemote.Handle(kind, r)
            return
        }
        if (A_TickCount < BotRemote.waitUntil)
            return
        while BotRemote.replies.Length {
            item := BotRemote.replies.RemoveAt(1)
            if (A_TickCount > item.expires)
                continue
            payload := '{"content":"' item.text '","allowed_mentions":{"parse":[]}}'
            try {
                if (item.png != "") {
                    boundary := "um14" Engine.NewId()
                    h := BotRemote.Headers(false)
                    h["Content-Type"] := "multipart/form-data; boundary=" boundary
                    body := Http.Multipart('{"content":"' item.text '","allowed_mentions":{"parse":[]},"attachments":[{"id":0,"filename":"roblox.png"}]}', item.png, boundary)
                    BotRemote.inflight := {h: Http.Begin("POST", BotRemote.Root, h, body), kind: "reply", gen: BotRemote.generation}
                } else
                    BotRemote.inflight := {h: Http.Begin("POST", BotRemote.Root, BotRemote.Headers(), Http.Bytes(payload)), kind: "reply", gen: BotRemote.generation}
            } catch
                BotRemote.State("unavailable")
            return
        }
        if (A_TickCount < BotRemote.nextPoll)
            return
        url := BotRemote.baseline ? BotRemote.Root "?after=" BotRemote.high "&limit=25" : BotRemote.Root "?limit=1"
        try BotRemote.inflight := {h: Http.Begin("GET", url, BotRemote.Headers(false)), kind: "poll", gen: BotRemote.generation}
        catch
            BotRemote.Fail()
    }

    static Fail() {
        BotRemote.Disable()
        BotRemote.State("unavailable")
    }

    static Handle(kind, r) {
        if (r.status = 429) {
            delay := 5000
            try {
                v := JSON.parse(r.text)
                if v.Has("retry_after")
                    delay := Min(60000, Max(1000, Round(v["retry_after"] * 1000)))
            }
            BotRemote.waitUntil := A_TickCount + delay
            BotRemote.State("rate-limited")
            return
        }
        if (r.status = 401 || r.status = 403 || r.status = 404 || r.status = 0 && kind = "poll" && !BotRemote.baseline) {
            BotRemote.Fail()
            return
        }
        if (kind = "reply")
            return
        BotRemote.nextPoll := A_TickCount + 7500
        if (r.status != 200)
            return
        try messages := JSON.parse(r.text)
        catch
            return
        if !(messages is Array)
            return
        if !BotRemote.baseline {
            BotRemote.baseline := true
            if messages.Length && messages[1].Has("id")
                BotRemote.high := messages[1]["id"]
            BotRemote.State("connected")
            return
        }
        ; Oldest first; ignore anything older than 30 seconds.
        ordered := []
        i := messages.Length
        while (i >= 1)
            ordered.Push(messages[i--])
        for msg in ordered {
            if !(msg is Map) || !msg.Has("id") || !RegExMatch(msg["id"], "^[1-9][0-9]{16,19}$")
                continue
            if (StrLen(msg["id"]) > StrLen(BotRemote.high) || (StrLen(msg["id"]) = StrLen(BotRemote.high) && StrCompare(msg["id"], BotRemote.high) > 0))
                BotRemote.high := msg["id"]
            author := msg.Has("author") && msg["author"] is Map && msg["author"].Has("id") ? msg["author"]["id"] : ""
            content := msg.Has("content") && msg["content"] is String ? StrLower(Trim(msg["content"])) : ""
            if (author != BotRemote.owner || !BotRemote.ops.Has(content) || BotRemote.seen.Has(msg["id"]))
                continue
            BotRemote.seen[msg["id"]] := 1
            created := (Integer(msg["id"]) >> 22) + 1420070400000
            if (Abs(UnixMs() - created) > 30000)
                continue
            if BotRemote.onCommand
                BotRemote.onCommand.Call(BotRemote.ops[content])
        }
        BotRemote.State(messages.Length = 25 ? "busy" : "connected")
    }

    static StatusText(state, matches) {
        static names := Map("idle", "idle", "running", "running", "recording", "recording", "stopping", "stopping")
        if !names.Has(state)
            return "Ultimate Macro: status unavailable. Check the app."
        return "Ultimate Macro: " names[state] ". Completed matches: " matches "."
    }
}

UnixMs() {
    ft := 0
    DllCall("GetSystemTimeAsFileTime", "Int64*", &ft)
    return (ft - 116444736000000000) // 10000
}

; ---------------------------------------------------------------------------
; Opt-in aggregate deltas for the official UltBot economy view.
class Economy {
    static enabled := false, session := "", sequence := 0, source := "", previous := Map(), totals := Map(), seconds := 0, last := 0, activeRun := false
    static LIMITS := Map("coins", 5000000, "gems", 1000000, "xp", 100000000, "matches", 1000)

    static SetEnabled(v) {
        if (v = Economy.enabled)
            return
        Economy.enabled := v, Economy.session := Engine.NewUuid(), Economy.sequence := 0, Economy.source := ""
        Economy.previous := Map(), Economy.totals := Map("coins", "", "gems", "", "xp", "", "matches", ""), Economy.seconds := 0, Economy.last := 0
    }

    static Observe(running, stats, source) {
        if !Economy.enabled
            return
        now := A_TickCount
        if (Economy.last && Economy.activeRun && running && now - Economy.last <= 30000)
            Economy.seconds += (now - Economy.last) / 1000
        Economy.last := now, Economy.activeRun := running
        if (!IsObject(stats) || source = "")
            return
        if (Economy.source != source)
            Economy.previous := Map(), Economy.source := source
        for key in ["coins", "gems", "xp", "matches"] {
            v := stats.Has(key) ? stats[key] : ""
            if !IsInteger(v)
                continue
            old := Economy.previous.Has(key) ? Economy.previous[key] : ""
            Economy.previous[key] := v
            if (Economy.totals[key] = "")
                Economy.totals[key] := 0
            if (old != "" && v - old >= 0 && v - old <= Economy.LIMITS[key])
                Economy.totals[key] += v - old
        }
    }

    static Payload() {
        Economy.sequence += 1
        if !Economy.enabled
            return '{"sharing":false}'
        m := ""
        for key in ["coins", "gems", "xp", "matches"]
            m .= '"' key '":' (Economy.totals[key] = "" ? "null" : Economy.totals[key]) ","
        return '{"sharing":true,"session":"' Economy.session '","sequence":' Economy.sequence ',"metrics":{' m '"activeSeconds":' Floor(Economy.seconds) '}}'
    }
}

; ---------------------------------------------------------------------------
; Official UltBot relay link (/remote link). One worker state machine.
class OfficialRemote {
    static pumpBound := ""
    static PumpFn() => OfficialRemote.pumpBound ? OfficialRemote.pumpBound : (OfficialRemote.pumpBound := ObjBindMethod(OfficialRemote, "Pump"))
    static relay := "", pair := "", token := "", install := "", generation := 0, active := false
    static state := "idle", inflight := "", job := "", seen := Map(), sharing := true, reply := "", jobAt := 0
    static onCommand := "", onState := ""

    static Code(code) {
        code := Trim(code)
        if (StrLen(code) < 20 || StrLen(code) > 1024 || !RegExMatch(code, "^ULT1\.([A-Za-z0-9_-]+)\.([A-HJ-NP-Z2-9]{10})$", &m))
            throw ValueError("Paste the connection code from /remote link.")
        b64 := StrReplace(StrReplace(m[1], "-", "+"), "_", "/")
        while Mod(StrLen(b64), 4)
            b64 .= "="
        size := 0
        DllCall("crypt32\CryptStringToBinaryW", "WStr", b64, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0)
        if !size
            throw ValueError("This is not an official secure Ultimate Macro relay address.")
        buf := Buffer(size, 0)
        DllCall("crypt32\CryptStringToBinaryW", "WStr", b64, "UInt", 0, "UInt", 1, "Ptr", buf, "UInt*", &size, "Ptr", 0, "Ptr", 0)
        raw := StrGet(buf, size, "UTF-8")
        if !RegExMatch(raw, "^https://((?:[a-z0-9-]+\.)*ultmacro\.xyz)((?:/[A-Za-z0-9_-]+)*/?)$", &u) || InStr(u[1], "..")
            throw ValueError("This is not an official secure Ultimate Macro relay address.")
        return [RTrim(raw, "/"), SubStr(m[2], 1, 5) "-" SubStr(m[2], 6)]
    }

    static Link(code, generation) {
        parts := OfficialRemote.Code(code)
        if OfficialRemote.active
            throw ValueError("Disconnect and wait for the previous session to close.")
        OfficialRemote.relay := parts[1], OfficialRemote.pair := parts[2], OfficialRemote.token := ""
        OfficialRemote.install := Engine.NewUuid(), OfficialRemote.generation := generation
        OfficialRemote.active := true, OfficialRemote.state := "link", OfficialRemote.seen := Map(), OfficialRemote.sharing := true
        OfficialRemote.job := "", OfficialRemote.reply := ""
        OfficialRemote.Send("POST", "/v1/remote/link", '{"code":"' OfficialRemote.pair '","deviceName":"Windows PC","clientVersion":"' App.RELEASE '","installId":"' OfficialRemote.install '"}')
        SetTimer(OfficialRemote.PumpFn(), 200)
    }

    static Send(method, path, body := "", receive := 15000) {
        h := Map("Accept", "application/json", "Content-Type", "application/json", "X-ULT-Install-ID", OfficialRemote.install, "X-ULT-Version", App.RELEASE)
        if (OfficialRemote.token != "")
            h["Authorization"] := "Bearer " OfficialRemote.token
        OfficialRemote.inflight := {h: Http.Begin(method, OfficialRemote.relay path, h, body = "" ? "" : Http.Bytes(body), receive), path: path, gen: OfficialRemote.generation}
    }

    static Close() {
        if !OfficialRemote.active
            return
        OfficialRemote.active := false
        if IsObject(OfficialRemote.inflight)
            try OfficialRemote.inflight.h.req.Abort()
        OfficialRemote.inflight := ""
        if (OfficialRemote.token != "") {
            ; Best-effort revoke; never blocks the UI or persists the token.
            try Http.Begin("POST", OfficialRemote.relay "/v1/remote/unlink", Map("Content-Type", "application/json", "Authorization", "Bearer " OfficialRemote.token
                , "X-ULT-Install-ID", OfficialRemote.install, "X-ULT-Version", App.RELEASE), Http.Bytes("{}"))
        }
        OfficialRemote.token := "", OfficialRemote.pair := "", OfficialRemote.state := "idle", OfficialRemote.job := ""
    }

    static Fail() {
        gen := OfficialRemote.generation
        OfficialRemote.Close()
        if OfficialRemote.onState
            OfficialRemote.onState.Call(gen, "disconnected")
    }

    static Respond(ok, resultJson, png := "") {
        if !IsObject(OfficialRemote.job)
            return false
        body := '{"jobId":"' OfficialRemote.job.id '","ok":' (ok ? "true" : "false") ',"result":' resultJson
        if (png != "")
            body .= ',"imageBase64":"' Http.Base64(png) '","mime":"image/png"'
        OfficialRemote.reply := body "}"
        return true
    }

    static Pump() {
        if !OfficialRemote.active {
            SetTimer(OfficialRemote.PumpFn(), 0)
            return
        }
        if IsObject(OfficialRemote.inflight) {
            r := Http.Check(OfficialRemote.inflight.h)
            if (r = "")
                return
            path := OfficialRemote.inflight.path
            OfficialRemote.inflight := ""
            if (r.status = 401 || r.status = 403 || r.status = 0 && path != "/v1/remote/telemetry") {
                OfficialRemote.Fail()
                return
            }
            if (path = "/v1/remote/telemetry" && r.status = 404) {
                OfficialRemote.sharing := false
                if OfficialRemote.onState
                    OfficialRemote.onState.Call(OfficialRemote.generation, "stats-unavailable")
            } else if (r.status != 200 && path != "/v1/remote/telemetry") {
                OfficialRemote.Fail()
                return
            }
            try value := (r.text != "") ? JSON.parse(r.text) : Map()
            catch {
                OfficialRemote.Fail()
                return
            }
            if (path = "/v1/remote/link") {
                t := (value is Map && value.Has("token")) ? value["token"] : ""
                if !RegExMatch(t, "^[A-Za-z0-9_-]{30,128}$") {
                    OfficialRemote.Fail()
                    return
                }
                OfficialRemote.token := t, OfficialRemote.pair := ""
                if OfficialRemote.onState
                    OfficialRemote.onState.Call(OfficialRemote.generation, "linked")
                OfficialRemote.state := "telemetry"
            } else if InStr(path, "/v1/remote/poll") {
                if (value is Map && value.Has("rotateToken")) {
                    if !RegExMatch(value["rotateToken"], "^[A-Za-z0-9_-]{30,128}$") {
                        OfficialRemote.Fail()
                        return
                    }
                    OfficialRemote.token := value["rotateToken"]
                }
                job := (value is Map && value.Has("job")) ? value["job"] : ""
                if (job is Map) {
                    id := job.Has("id") ? job["id"] : ""
                    if (!RegExMatch(id, "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$") || OfficialRemote.seen.Has(id)) {
                        OfficialRemote.Fail()
                        return
                    }
                    OfficialRemote.seen[id] := 1
                    op := job.Has("command") ? job["command"] : ""
                    if !InArray(["stop", "status", "start", "screenshot"], op) {
                        OfficialRemote.Send("POST", "/v1/remote/result", '{"jobId":"' id '","ok":false,"result":{"error":"This command is not permitted in the app."}}')
                        return
                    }
                    OfficialRemote.job := {id: id, op: op}, OfficialRemote.reply := "", OfficialRemote.jobAt := A_TickCount
                    OfficialRemote.state := "job"
                    if OfficialRemote.onCommand
                        OfficialRemote.onCommand.Call(op)
                    return
                }
                OfficialRemote.state := "telemetry"
            } else {
                OfficialRemote.state := "telemetry"
            }
            return
        }
        switch OfficialRemote.state {
            case "telemetry":
                if OfficialRemote.sharing
                    OfficialRemote.Send("POST", "/v1/remote/telemetry", Economy.Payload())
                OfficialRemote.state := "poll"
            case "poll":
                OfficialRemote.Send("GET", "/v1/remote/poll?telemetry=1", "", 35000)
            case "job":
                if (OfficialRemote.reply = "" && A_TickCount - OfficialRemote.jobAt < 12000)
                    return
                body := OfficialRemote.reply != "" ? OfficialRemote.reply : '{"jobId":"' OfficialRemote.job.id '","ok":false,"result":{"error":"The app could not handle the request."}}'
                OfficialRemote.job := "", OfficialRemote.reply := ""
                OfficialRemote.Send("POST", "/v1/remote/result", body)
                OfficialRemote.state := "telemetry"
        }
    }
}
