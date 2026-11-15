; Dashboard activity is opt-in: events are stored only while a Dashboard token exists.
; Uploads use the shared asynchronous transport and never run on a strategy action's network path.
class DashboardActivity {
    static dir := A_AppData "\Ultimate_Macro\Dashboard-Activity-141"
    static runId := "", sequence := 0, timer := "", receiptTimer := "", pending := "", sentPaths := []
    static retryMs := 1500
    static matchTimer := "", matchActive := false, bossSeen := false, bossAppeared := false
    static bossMisses := 0, bossHits := 0, resultCandidate := "", resultHits := 0, matchResult := ""

    static Start() {
        if !Dashboard.token
            return
        try {
            DirCreate(DashboardActivity.dir)
            DashboardActivity.sequence := Max(DashboardActivity.sequence
                , Integer(IniRead(DashboardActivity.dir "\queue.ini", "Queue", "Sequence", "0")))
            if !DashboardActivity.runId
                DashboardActivity.runId := IniRead(DashboardActivity.dir "\queue.ini", "Queue", "RunId", "")
            if !RegExMatch(DashboardActivity.runId, "i)\A[a-f0-9]{32}\z")
                DashboardActivity.runId := ""
        }
        if !DashboardActivity.timer
            DashboardActivity.timer := ObjBindMethod(DashboardActivity, "Pump")
        if !DashboardActivity.receiptTimer
            DashboardActivity.receiptTimer := ObjBindMethod(DashboardActivity, "ConsumeResultReceipt")
        SetTimer(DashboardActivity.receiptTimer, 1000)
        SetTimer(DashboardActivity.timer, -100)
    }

    static Stop() {
        if DashboardActivity.timer
            SetTimer(DashboardActivity.timer, 0)
        if DashboardActivity.receiptTimer
            SetTimer(DashboardActivity.receiptTimer, 0)
        if DashboardActivity.matchTimer
            SetTimer(DashboardActivity.matchTimer, 0)
        DashboardActivity.matchActive := false
        old := DashboardActivity.pending, DashboardActivity.pending := ""
        if (IsObject(old) && IsObject(old.req))
            try old.req.Abort()
        DashboardActivity.sentPaths := []
    }

    static Clear() {
        DashboardActivity.Stop()
        try {
            Loop Files, DashboardActivity.dir "\event-*.json", "F"
                FileDelete(A_LoopFileFullPath)
            if FileExist(DashboardActivity.dir "\queue.ini")
                FileDelete(DashboardActivity.dir "\queue.ini")
            if (Dashboard.file != "" && FileExist(Dashboard.file ".result.json"))
                FileDelete(Dashboard.file ".result.json")
            Loop Files, DashboardMatch.resultsDir "\result-*.json", "F"
                FileDelete(A_LoopFileFullPath)
        }
        DashboardActivity.runId := "", DashboardActivity.sequence := 0
    }

    static RunStarted() {
        if !Dashboard.token
            return
        DashboardActivity.runId := DashboardActivity.NewId()
        try {
            DirCreate(DashboardActivity.dir)
            IniWrite(DashboardActivity.runId, DashboardActivity.dir "\queue.ini", "Queue", "RunId")
        }
        DashboardActivity.Queue("run.started", "macro", "confirmed")
    }

    static RunStopped() {
        if !DashboardActivity.runId
            return
        DashboardActivity.matchActive := false
        if DashboardActivity.matchTimer
            SetTimer(DashboardActivity.matchTimer, 0)
        DashboardActivity.Queue("run.stopped", "macro", "confirmed")
        DashboardActivity.runId := ""
        try IniDelete(DashboardActivity.dir "\queue.ini", "Queue", "RunId")
    }

    static SessionStarted() {
        global gamemap, difficulty
        if !Dashboard.token
            return
        DashboardActivity.matchActive := true
        DashboardActivity.bossSeen := false, DashboardActivity.bossAppeared := false
        DashboardActivity.bossMisses := 0, DashboardActivity.bossHits := 0
        DashboardActivity.resultCandidate := "", DashboardActivity.resultHits := 0, DashboardActivity.matchResult := ""
        if !DashboardActivity.runId
            DashboardActivity.runId := DashboardActivity.NewId()
        mapName := Dashboard.SafeLabel(gamemap, 64)
        modeName := Dashboard.SafeLabel(difficulty, 64)
        DashboardActivity.Queue("mode.selected", "screen", "observed", Map("mode", modeName))
        DashboardActivity.Queue("game.joined", "screen", "observed", Map("map", mapName, "mode", modeName))
        DashboardActivity.Queue("match.started", "screen", "observed", Map("map", mapName, "mode", modeName))
        if Dashboard.token {
            if !DashboardActivity.matchTimer
                DashboardActivity.matchTimer := ObjBindMethod(DashboardActivity, "PollScreen")
            SetTimer(DashboardActivity.matchTimer, 2500)
        }
    }

    static Succeeded(action, detail := "") {
        action := StrLower(Trim(action))
        if !InStr("|spawntower|upgradetower|selltower|clonetower|changetargets|toggleautoskip|activateraisethedead|activateenforcervan|brawlerreposition|enforcerreposition|setdjtrack|", "|" action "|")
            return false
        data := Map("action", action)
        detail := Dashboard.SafeLabel(detail, 64)
        if (detail != "")
            data["detail"] := detail
        return DashboardActivity.Queue("strategy.action.succeeded", "macro", "confirmed", data)
    }

    static Queue(type, source, confidence, data := "", eventId := "", occurredAt := "") {
        if !Dashboard.token
            return false
        if (eventId != "" && !RegExMatch(eventId, "i)\A[a-f0-9]{32}\z"))
            return false
        if (occurredAt != "") {
            compactTime := RegExReplace(occurredAt, "\D")
            if (!RegExMatch(occurredAt, "\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z") || !IsTime(compactTime))
                return false
        }
        if !DashboardActivity.runId
            DashboardActivity.runId := DashboardActivity.NewId()
        try {
            DirCreate(DashboardActivity.dir)
            if (eventId != "") {
                Loop Files, DashboardActivity.dir "\event-*-" eventId ".json", "F"
                    return true ; Crash/restart replay must not queue a second copy.
            }
            count := 0
            Loop Files, DashboardActivity.dir "\event-*.json", "F"
                count++
            if (count >= 500)
                return false
            oldCritical := A_IsCritical
            Critical("On")
            try {
                DashboardActivity.sequence := Max(DashboardActivity.sequence
                    , Integer(IniRead(DashboardActivity.dir "\queue.ini", "Queue", "Sequence", "0"))) + 1
                IniWrite(DashboardActivity.sequence, DashboardActivity.dir "\queue.ini", "Queue", "Sequence")
                event := Map("eventId", eventId != "" ? StrLower(eventId) : DashboardActivity.NewId(), "sequence", DashboardActivity.sequence
                    , "type", type, "occurredAt", occurredAt != "" ? occurredAt : FormatTime(A_NowUTC, "yyyy-MM-dd") "T" FormatTime(A_NowUTC, "HH:mm:ss") "Z"
                    , "appVersion", Dashboard.version, "runId", DashboardActivity.runId
                    , "source", source, "confidence", confidence, "data", IsObject(data) ? data : Map())
                filename := DashboardActivity.dir "\event-" Format("{:09}", DashboardActivity.sequence) "-" event["eventId"] ".json"
                AtomicWrite(filename, JSON.stringify(event, 0, ""))
            } finally Critical(oldCritical)
            if !DashboardActivity.timer
                DashboardActivity.timer := ObjBindMethod(DashboardActivity, "Pump")
            SetTimer(DashboardActivity.timer, -250)
            return true
        } catch {
            return false
        }
    }

    static Pump(*) {
        if !Dashboard.token
            return
        if IsObject(DashboardActivity.pending) {
            response := Dashboard.transport.Check(DashboardActivity.pending)
            if !IsObject(response)
                return
            pending := DashboardActivity.pending
            DashboardActivity.pending := ""
            if (response.status >= 200 && response.status < 300) {
                for path in DashboardActivity.sentPaths
                    if FileExist(path)
                        try FileDelete(path)
                DashboardActivity.sentPaths := []
                DashboardActivity.retryMs := 1500
                SetTimer(DashboardActivity.timer, -DashboardActivity.retryMs)
                return
            }
            DashboardActivity.sentPaths := []
            if (response.status = 401) {
                Dashboard.Forget(true)
                return
            }
            DashboardActivity.retryMs := Min(30000, DashboardActivity.retryMs * 2)
            SetTimer(DashboardActivity.timer, -DashboardActivity.retryMs)
            return
        }

        ; Read offline results before selecting the upload batch. The watchdog
        ; can have restarted the macro while the dashboard was unreachable.
        DashboardActivity.ConsumeResultReceipt()

        paths := [], events := []
        Loop Files, DashboardActivity.dir "\event-*.json", "F" {
            path := A_LoopFileFullPath
            try {
                event := JSON.parse(FileRead(path, "UTF-8"))
                ; Older beta IDs could include an extra COM string character.
                ; One malformed local event must not block every later result.
                if (!(event is Map) || !event.Has("eventId") || !event.Has("runId")
                    || !RegExMatch(event["eventId"], "i)\A[a-f0-9]{32}\z")
                    || !RegExMatch(event["runId"], "i)\A[a-f0-9]{32}\z"))
                    throw ValueError()
                paths.Push(path), events.Push(event)
            } catch {
                try FileDelete(path)
            }
            if (events.Length >= 25)
                break
        }
        if !events.Length
            return
        headers := Map("Accept", "application/json", "Content-Type", "application/json; charset=utf-8"
            , "Authorization", "Bearer " Dashboard.token)
        body := JSON.stringify(Map("events", events), 0, "")
        try {
            DashboardActivity.pending := Dashboard.transport.Begin("POST", Dashboard.origin Dashboard.PREFIX "events", headers, body, 10000)
            DashboardActivity.sentPaths := paths
            SetTimer(DashboardActivity.timer, 250)
        } catch {
            DashboardActivity.retryMs := Min(30000, DashboardActivity.retryMs * 2)
            SetTimer(DashboardActivity.timer, -DashboardActivity.retryMs)
        }
    }

    static PollScreen(*) {
        if (!Dashboard.token || !DashboardActivity.matchActive)
            return
        DashboardActivity.DetectBoss()
    }

    static ConsumeResultReceipt(*) {
        if (!Dashboard.token || Dashboard.file = "")
            return false
        consumed := false
        Loop Files, DashboardMatch.resultsDir "\result-*.json", "F" {
            if DashboardActivity.ConsumeOneReceipt(A_LoopFileFullPath)
                consumed := true
        }
        ; Accept receipts produced by an earlier compatible desktop build too.
        return DashboardActivity.ConsumeOneReceipt(Dashboard.file ".result.json") || consumed
    }

    static ConsumeOneReceipt(path) {
        global StateFile
        if !FileExist(path)
            return false
        try {
            if FileGetSize(path) > 16384
                return false
            receipt := JSON.parse(FileRead(path, "UTF-8"))
            if !(receipt is Map) || !receipt.Has("resultId") || !receipt.Has("result") || !receipt.Has("occurredAt")
                return false
            resultId := receipt["resultId"]
            result := receipt["result"]
            if !RegExMatch(resultId, "i)\A[a-f0-9]{32}\z") || (result != "match.victory" && result != "match.loss")
                return false
            if (IniRead(DashboardActivity.dir "\queue.ini", "Queue", "LastResultId", "") = resultId) {
                try FileDelete(path)
                return false
            }
            data := Map()
            for key in ["map", "coins", "gems", "towerXp", "durationSeconds"] {
                if !receipt.Has(key)
                    continue
                value := receipt[key]
                if (key = "map") {
                    data[key] := Dashboard.SafeLabel(value, 64)
                } else if (value is Integer && value >= 0 && value <= (key = "durationSeconds" ? 86400 : 1000000000)) {
                    data[key] := value
                }
            }
            if !DashboardActivity.Queue(result, "screen", "observed", data, resultId, receipt["occurredAt"])
                return false
            DashboardActivity.matchResult := result
            DashboardActivity.matchActive := false
            if DashboardActivity.matchTimer
                SetTimer(DashboardActivity.matchTimer, 0)
            DashboardRemote.MatchFinishedForCooldown()
            if (IniRead(StateFile, "State", "Running", "0") = "0")
                DashboardActivity.RunStopped()
            IniWrite(resultId, DashboardActivity.dir "\queue.ini", "Queue", "LastResultId")
            try FileDelete(path)
            return true
        } catch {
            return false
        }
    }

    static DetectBoss() {
        hit := DashboardActivity.SearchSignal("Resources\boss_appeared.png", 0.90)
        if (hit = "hit") {
            DashboardActivity.bossMisses := 0
            DashboardActivity.bossHits += 1
            if (DashboardActivity.bossHits >= 2)
                DashboardActivity.bossSeen := true
            if (DashboardActivity.bossSeen && !DashboardActivity.bossAppeared) {
                DashboardActivity.bossAppeared := DashboardActivity.Queue("boss.appeared", "screen", "observed")
            }
            return
        }
        DashboardActivity.bossHits := 0
        if (hit = "miss" && DashboardActivity.bossSeen && DashboardActivity.matchResult != "match.loss") {
            DashboardActivity.bossMisses += 1
            if (DashboardActivity.bossMisses >= 4) {
                if DashboardActivity.Queue("boss.defeated", "screen", "observed") {
                    DashboardActivity.bossSeen := false, DashboardActivity.bossAppeared := false
                    DashboardActivity.bossMisses := 0
                }
            }
        }
    }

    static SearchSignal(imagePath, minimumScore) {
        fullPath := A_ScriptDir "\" imagePath
        if !FileExist(fullPath)
            return "error"
        try {
            getRobloxPos(,, &width, &height)
            if (width < 1 || height < 1)
                return "error"
            result := AdvancedImageSearch(fullPath, 0, 0, width, height)
            if (result.status = "success")
                return result.score >= minimumScore ? "hit" : "miss"
            if (result.status = "failed")
                return "miss"
            if (result.status = "error" && (result.message = "image not found via multi-scale GDI+ fallback"
                || result.message = "Native image search returned code 0"))
                return "miss"
        } catch {
            return "error"
        }
        return "error"
    }

    static NewId() {
        return DashboardMatch.Id()
    }
}
