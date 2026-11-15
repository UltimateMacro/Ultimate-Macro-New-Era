; Local, bounded handoff between the existing watchdog and the paired dashboard.
; No network, game input, or process control is performed by this class.
class DashboardMatch {
    static root := A_AppData "\Ultimate_Macro\Connections-14"
    static tokenFile => DashboardMatch.root "\dashboard.dpapi"
    static controlFile => DashboardMatch.root "\dashboard-match.ini"
    static resultsDir => DashboardMatch.root "\Dashboard-results"

    static Linked() {
        try return FileExist(DashboardMatch.tokenFile) && FileGetSize(DashboardMatch.tokenFile) > 0
        catch
            return false
    }

    static Id() {
        guid := Buffer(16), text := Buffer(78, 0)
        if DllCall("ole32\CoCreateGuid", "Ptr", guid, "Int") != 0
            throw OSError()
        DllCall("ole32\StringFromGUID2", "Ptr", guid, "Ptr", text, "Int", 39)
        return StrLower(RegExReplace(StrGet(text), "[^a-fA-F0-9]"))
    }

    static SetStop(enabled) {
        try {
            if enabled {
                if !DashboardMatch.Linked()
                    return false
                DirCreate(DashboardMatch.root)
                IniWrite(1, DashboardMatch.controlFile, "Match", "StopAfterMatch")
            } else if FileExist(DashboardMatch.controlFile)
                IniDelete(DashboardMatch.controlFile, "Match", "StopAfterMatch")
            return true
        } catch
            return false
    }

    static StopPending() => DashboardMatch.Linked()
        && IniRead(DashboardMatch.controlFile, "Match", "StopAfterMatch", "0") = "1"

    static ApplyStop(state) {
        if !DashboardMatch.StopPending()
            return false
        ; RestartMain still uses the original owned-parent lifecycle. Clearing
        ; this flag BEFORE that restart prevents it from starting another game.
        IniWrite(0, state, "State", "Running")
        DashboardMatch.SetStop(false)
        return true
    }

    static Started(state) {
        if !DashboardMatch.Linked()
            return ""
        id := DashboardMatch.Id()
        IniWrite(id, state, "State", "DashboardMatchId")
        return id
    }

    static Publish(result, state, details := "") {
        if !DashboardMatch.Linked() || (result != "Triumph" && result != "Loss")
            return false
        try {
            id := IniRead(state, "State", "DashboardMatchId", "")
            if !RegExMatch(id, "i)\A[a-f0-9]{32}\z") {
                id := DashboardMatch.Id()
                IniWrite(id, state, "State", "DashboardMatchId")
            }
            if (IniRead(state, "State", "DashboardResultId", "") = id)
                return true
            DirCreate(DashboardMatch.resultsDir)
            count := 0
            Loop Files, DashboardMatch.resultsDir "\result-*.json", "F"
                count++
            if (count >= 500)
                return false ; Never overwrite older offline results.
            receipt := Map("resultId", id, "result", result = "Triumph" ? "match.victory" : "match.loss"
                , "occurredAt", FormatTime(A_NowUTC, "yyyy-MM-dd") "T" FormatTime(A_NowUTC, "HH:mm:ss") "Z"
                , "map", SubStr(IniRead(state, "State", "Map", "Unknown"), 1, 64))
            if (details is Map) {
                for key in ["map", "coins", "gems", "towerXp", "durationSeconds"] {
                    if !details.Has(key)
                        continue
                    value := details[key]
                    if (key = "map")
                        receipt[key] := SubStr(Trim(RegExReplace(String(value), "[\r\n\x00]", " ")), 1, 64)
                    else if (value is Integer && value >= 0 && value <= (key = "durationSeconds" ? 86400 : 1000000000))
                        receipt[key] := value
                }
            }
            path := DashboardMatch.resultsDir "\result-" id ".json"
            temp := path ".tmp"
            if FileExist(temp)
                FileDelete(temp)
            FileAppend(JSON.stringify(receipt, 0, ""), temp, "UTF-8-RAW")
            FileMove(temp, path, 1)
            IniWrite(id, state, "State", "DashboardResultId")
            return true
        } catch
            return false
    }
}
