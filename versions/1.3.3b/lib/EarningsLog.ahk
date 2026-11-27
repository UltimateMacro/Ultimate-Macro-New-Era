EarningsDirectory() => A_AppData "\Ultimate_Macro\Earnings"

EarningsWrite(entry, id := "") {
    directory := EarningsDirectory()
    DirCreate(directory)
    if !entry.Has("date")
        entry["date"] := A_NowUTC
    if id = ""
        id := entry["date"] "-" DllCall("GetCurrentProcessId", "UInt") "-" A_TickCount
    path := directory "\" id ".json"
    if FileExist(path)
        return
    temp := path ".tmp"
    handle := FileOpen(temp, "w", "UTF-8-RAW")
    try handle.Write(JSON.Stringify(entry))
    finally handle.Close()
    FileMove(temp, path)
}

EarningsImportLegacy(state) {
    try EarningsImportSavedSessions()
    try EarningsImportMatchArchives()
    marker := EarningsDirectory() "\legacy.done"
    if FileExist(marker)
        return
    entry := Map("kind", "Imported session")
    for key, field in Map("Coins", "coins", "Gems", "gems", "Timescale", "timescaleUsed", "TotalTimeSeconds", "duration") {
        value := IniRead(state, "State", key, "")
        if IsInteger(value) && Integer(value) > 0
            entry[field] := Integer(value)
    }
    if entry.Count > 1
        EarningsWrite(entry, "legacy-session")
    DirCreate(EarningsDirectory())
    FileAppend("1", marker, "UTF-8-RAW")
}

EarningsImportSavedSessions() {
    path := A_AppData "\Ultimate_Macro\session-history.json"
    if !FileExist(path)
        return
    sessions := JSON.Parse(FileRead(path, "UTF-8"))
    if !(sessions is Array)
        return
    for session in sessions {
        if !(session is Map)
            continue
        id := session.Get("id", "")
        if !RegExMatch(id, "^(\d{14})-\d{1,20}$", &stamp)
            continue
        entry := Map("kind", "Imported session", "date", stamp[1], "strategy", session.Get("strategy", ""))
        for field, source in Map("coins", "coins", "gems", "gems", "playerXP", "exp", "duration", "runtimeSeconds", "matches", "matches") {
            value := session.Get(source, "")
            if IsInteger(value) && Integer(value) >= 0
                entry[field] := Integer(value)
        }
        try EarningsWrite(entry, "saved-session-" id)
    }
}

EarningsImportMatchArchives() {
    root := A_AppData "\Ultimate_Macro"
    tsv := root "\History\session-history-136.tsv"
    if FileExist(tsv) {
        Loop Read tsv {
            columns := StrSplit(A_LoopReadLine, Chr(9))
            if columns.Length < 4
                continue
            entry := EarningsArchivedMatch(columns[1], columns[2], columns[4])
            if !entry
                continue
            for index, field in Map(3, "duration", 5, "coins", 6, "gems", 7, "playerXP") {
                if columns.Has(index) && IsInteger(columns[index]) && Integer(columns[index]) >= 0
                    entry[field] := Integer(columns[index])
            }
            try EarningsWrite(entry, "archived-match-" entry["date"])
        }
    }

    log := root "\Logs\reward_debug.log"
    entry := false
    if FileExist(log) {
        Loop Read log {
            if RegExMatch(A_LoopReadLine, "^([\d-]+ [\d:]+) \[(Triumph|Loss)\] Mode: (.*?) \| Map: (.*)$", &header) {
                entry := EarningsArchivedMatch(header[1], header[2], header[4])
            } else if entry && RegExMatch(A_LoopReadLine, "^\s*Final Result: \+([\d,]+) EXP, \+([\d,]+) Coins, \+([\d,]+) Gems\s*$", &reward) {
                entry["playerXP"] := Integer(StrReplace(reward[1], ","))
                entry["coins"] := Integer(StrReplace(reward[2], ","))
                entry["gems"] := Integer(StrReplace(reward[3], ","))
                try EarningsWrite(entry, "archived-match-" entry["date"])
                entry := false
            }
        }
    }
}

EarningsArchivedMatch(stamp, result, mapName) {
    if !RegExMatch(stamp, "^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$") || !(result = "Triumph" || result = "Loss")
        return false
    return Map("kind", "Imported match", "date", RegExReplace(stamp, "\D"), "result", result, "map", mapName)
}
